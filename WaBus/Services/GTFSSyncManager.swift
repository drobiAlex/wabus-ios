import CoreLocation
import Foundation
import os

/// Manages GTFS data synchronization and local caching.
/// Downloads bulk data once daily and caches locally for offline access.
actor GTFSSyncManager {
    static let shared = GTFSSyncManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WaBus", category: "GTFSSync")
    private let fileManager = FileManager.default

    // UserDefaults keys
    private let syncVersionKey = "gtfs_sync_version"
    private let lastSyncKey = "gtfs_last_sync"
    private let etagKey = "gtfs_etag"

    // In-memory cache (loaded from disk)
    private var routes: [String: Route] = [:]
    private var routesByLine: [String: Route] = [:]
    private var stops: [String: Stop] = [:]
    private var calendars: [String: GTFSCalendar] = [:]
    private var calendarDates: [String: [CalendarDate]] = [:]

    private var isLoaded = false

    private init() {}

    // MARK: - Public API

    /// Returns true if data is loaded and ready to use
    var isReady: Bool { isLoaded }

    /// Call on app launch to ensure data is fresh.
    /// Loads from disk first, then syncs with server if needed.
    func syncIfNeeded() async {
        // Load cached data from disk first
        await loadFromDisk()

        // Check if we need to sync
        let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        let currentVersion = UserDefaults.standard.string(forKey: syncVersionKey)

        // Sync if never synced, no data loaded, or more than 6 hours old
        let shouldSync = lastSync == nil ||
            !isLoaded ||
            Date().timeIntervalSince(lastSync!) > 6 * 3600

        if shouldSync {
            await syncWithRetry(currentVersion: currentVersion, maxRetries: 5)
        } else {
            logger.info("Using cached GTFS data (last sync: \(lastSync?.description ?? "never"))")
        }
    }

    private func syncWithRetry(currentVersion: String?, maxRetries: Int) async {
        for attempt in 1...maxRetries {
            do {
                let hasUpdates = try await checkForUpdates(since: currentVersion)
                if hasUpdates || !isLoaded {
                    try await performFullSync()
                } else {
                    logger.info("GTFS data is up to date (version: \(currentVersion ?? "unknown"))")
                    UserDefaults.standard.set(Date(), forKey: lastSyncKey)
                }
                return  // Success, exit retry loop
            } catch SyncError.serverLoading {
                logger.info("Server still loading GTFS data, retry \(attempt)/\(maxRetries) in 5s...")
                if attempt < maxRetries {
                    try? await Task.sleep(for: .seconds(5))
                }
            } catch {
                logger.error("Sync failed: \(error.localizedDescription)")
                if !isLoaded {
                    logger.warning("No cached data available, app may have limited functionality")
                }
                return  // Non-retryable error
            }
        }
        logger.error("Sync failed after \(maxRetries) retries - server still loading")
    }

    /// Force a full sync regardless of cache state
    func forceSync() async throws {
        try await performFullSync()
    }

    // MARK: - Route Accessors

    /// Get route by line number (e.g., "175")
    func getRoute(byLine line: String) -> Route? {
        routesByLine[line]
    }

    /// Get route by ID
    func getRoute(byId id: String) -> Route? {
        routes[id]
    }

    /// Get all routes sorted by line number
    func getAllRoutes() -> [Route] {
        Array(routes.values).sorted { r1, r2 in
            // Try numeric sort first
            if let n1 = Int(r1.shortName), let n2 = Int(r2.shortName) {
                return n1 < n2
            }
            return r1.shortName < r2.shortName
        }
    }

    /// Get routes filtered by type
    func getRoutes(ofType type: RouteType) -> [Route] {
        getAllRoutes().filter { $0.type == type }
    }

    // MARK: - Stop Accessors

    /// Get stop by ID
    func getStop(byId id: String) -> Stop? {
        stops[id]
    }

    /// Get all stops
    func getAllStops() -> [Stop] {
        Array(stops.values)
    }

    /// Get stops near a location
    func getStopsNear(coordinate: CLLocationCoordinate2D, radiusMeters: Double = 500) -> [Stop] {
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return stops.values
            .map { stop -> (Stop, CLLocationDistance) in
                let stopLocation = CLLocation(latitude: stop.lat, longitude: stop.lon)
                return (stop, userLocation.distance(from: stopLocation))
            }
            .filter { $0.1 <= radiusMeters }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    /// Search stops by name
    func searchStops(query: String) -> [Stop] {
        guard !query.isEmpty else { return [] }
        let lowercased = query.lowercased()
        return stops.values.filter { stop in
            stop.name.lowercased().contains(lowercased) ||
            stop.code.lowercased().contains(lowercased)
        }
    }

    // MARK: - Calendar Accessors

    /// Get active service IDs for a given date
    func getActiveServiceIds(for date: Date) -> Set<String> {
        let dateString = formatDateForGTFS(date)
        let weekday = Calendar.current.component(.weekday, from: date)

        var activeServices = Set<String>()

        // Check regular calendars
        for (serviceId, calendar) in calendars {
            guard dateString >= calendar.startDate && dateString <= calendar.endDate else {
                continue
            }

            let isActive: Bool = switch weekday {
                case 1: calendar.sunday
                case 2: calendar.monday
                case 3: calendar.tuesday
                case 4: calendar.wednesday
                case 5: calendar.thursday
                case 6: calendar.friday
                case 7: calendar.saturday
                default: false
            }

            if isActive {
                activeServices.insert(serviceId)
            }
        }

        // Apply calendar date exceptions
        for (serviceId, dates) in calendarDates {
            for calendarDate in dates where calendarDate.date == dateString {
                if calendarDate.exceptionType == 1 {
                    activeServices.insert(serviceId)
                } else if calendarDate.exceptionType == 2 {
                    activeServices.remove(serviceId)
                }
            }
        }

        return activeServices
    }

    // MARK: - Stats

    var syncVersion: String? {
        UserDefaults.standard.string(forKey: syncVersionKey)
    }

    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }

    var stats: (routes: Int, stops: Int, calendars: Int) {
        (routes.count, stops.count, calendars.count)
    }

    // MARK: - Private Methods

    private func checkForUpdates(since version: String?) async throws -> Bool {
        var components = URLComponents(
            url: AppConfig.baseURL.appendingPathComponent("/v1/sync/check"),
            resolvingAgainstBaseURL: false
        )!

        if let version {
            components.queryItems = [URLQueryItem(name: "since", value: version)]
        }

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        // Handle 503 - server still loading GTFS data
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 503 {
            throw SyncError.serverLoading
        }

        let checkResponse = try AppConfig.jsonDecoder.decode(SyncCheckResponse.self, from: data)

        logger.info("Sync check: version=\(checkResponse.version), hasUpdates=\(checkResponse.hasUpdates)")
        return checkResponse.hasUpdates
    }

    private func performFullSync() async throws {
        logger.info("Starting full GTFS sync...")
        let startTime = Date()

        var request = URLRequest(url: AppConfig.baseURL.appendingPathComponent("/v1/sync"))
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        // Add ETag for conditional request
        if let etag = UserDefaults.standard.string(forKey: etagKey) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }

        // Not modified - our cache is current
        if httpResponse.statusCode == 304 {
            logger.info("GTFS data not modified (304), using cache")
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)
            return
        }

        // Server still loading GTFS data
        if httpResponse.statusCode == 503 {
            throw SyncError.serverLoading
        }

        guard httpResponse.statusCode == 200 else {
            throw SyncError.httpError(httpResponse.statusCode)
        }

        // Save new ETag
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            UserDefaults.standard.set(etag, forKey: etagKey)
        }

        // Parse response
        let syncData = try AppConfig.jsonDecoder.decode(SyncResponse.self, from: data)

        // Update in-memory cache
        routes = Dictionary(uniqueKeysWithValues: syncData.routes.map { ($0.id, $0) })
        routesByLine = Dictionary(uniqueKeysWithValues: syncData.routes.map { ($0.shortName, $0) })
        stops = Dictionary(uniqueKeysWithValues: syncData.stops.map { ($0.id, $0) })
        calendars = Dictionary(uniqueKeysWithValues: syncData.calendars.map { ($0.serviceId, $0) })
        calendarDates = Dictionary(grouping: syncData.calendarDates) { $0.serviceId }

        isLoaded = true

        // Persist to disk
        try saveToDisk(syncData)

        // Update metadata
        UserDefaults.standard.set(syncData.version, forKey: syncVersionKey)
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)

        let elapsed = Date().timeIntervalSince(startTime)
        logger.info("GTFS sync completed in \(String(format: "%.2f", elapsed))s: \(syncData.routes.count) routes, \(syncData.stops.count) stops")
    }

    private func saveToDisk(_ data: SyncResponse) throws {
        let cacheDir = getCacheDirectory()
        try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let encoder = AppConfig.jsonEncoder

        try encoder.encode(data.routes).write(to: cacheDir.appendingPathComponent("routes.json"))
        try encoder.encode(data.stops).write(to: cacheDir.appendingPathComponent("stops.json"))
        try encoder.encode(data.calendars).write(to: cacheDir.appendingPathComponent("calendars.json"))
        try encoder.encode(data.calendarDates).write(to: cacheDir.appendingPathComponent("calendar_dates.json"))

        logger.debug("Saved GTFS data to disk")
    }

    private func loadFromDisk() async {
        let cacheDir = getCacheDirectory()
        let decoder = AppConfig.jsonDecoder

        do {
            var loadedRoutes: [Route] = []
            var loadedStops: [Stop] = []
            var loadedCalendars: [GTFSCalendar] = []
            var loadedCalendarDates: [CalendarDate] = []

            if let data = try? Data(contentsOf: cacheDir.appendingPathComponent("routes.json")) {
                loadedRoutes = try decoder.decode([Route].self, from: data)
            }

            if let data = try? Data(contentsOf: cacheDir.appendingPathComponent("stops.json")) {
                loadedStops = try decoder.decode([Stop].self, from: data)
            }

            if let data = try? Data(contentsOf: cacheDir.appendingPathComponent("calendars.json")) {
                loadedCalendars = try decoder.decode([GTFSCalendar].self, from: data)
            }

            if let data = try? Data(contentsOf: cacheDir.appendingPathComponent("calendar_dates.json")) {
                loadedCalendarDates = try decoder.decode([CalendarDate].self, from: data)
            }

            // Only mark as loaded if we have essential data
            if !loadedRoutes.isEmpty && !loadedStops.isEmpty {
                routes = Dictionary(uniqueKeysWithValues: loadedRoutes.map { ($0.id, $0) })
                routesByLine = Dictionary(uniqueKeysWithValues: loadedRoutes.map { ($0.shortName, $0) })
                stops = Dictionary(uniqueKeysWithValues: loadedStops.map { ($0.id, $0) })
                calendars = Dictionary(uniqueKeysWithValues: loadedCalendars.map { ($0.serviceId, $0) })
                calendarDates = Dictionary(grouping: loadedCalendarDates) { $0.serviceId }

                isLoaded = true
                logger.info("Loaded GTFS cache from disk: \(loadedRoutes.count) routes, \(loadedStops.count) stops")
            }
        } catch {
            logger.warning("Failed to load GTFS cache from disk: \(error.localizedDescription)")
        }
    }

    private func getCacheDirectory() -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("gtfs")
    }

    private func formatDateForGTFS(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}

// MARK: - Errors

enum SyncError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case noData
    case serverLoading

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .noData:
            return "No data received"
        case .serverLoading:
            return "Server is still loading GTFS data"
        }
    }
}
