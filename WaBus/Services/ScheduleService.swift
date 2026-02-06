import Foundation
import os

/// Service for fetching and caching stop schedules.
/// Provides in-memory caching with 5-minute TTL.
actor ScheduleService {
    static let shared = ScheduleService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WaBus", category: "Schedule")
    private let client = WaBusClient.shared
    private let cacheTTL: TimeInterval = 300  // 5 minutes

    // In-memory cache
    private var scheduleCache: [String: CachedSchedule] = [:]
    private var linesCache: [String: CachedLines] = [:]

    private init() {}

    // MARK: - Schedule Methods

    /// Get schedule for a stop for today
    func getTodaySchedule(stopId: String) async throws -> [StopTime] {
        try await getSchedule(stopId: stopId, date: "today")
    }

    /// Get schedule for a stop for tomorrow
    func getTomorrowSchedule(stopId: String) async throws -> [StopTime] {
        try await getSchedule(stopId: stopId, date: "tomorrow")
    }

    /// Get schedule for a specific date
    func getSchedule(stopId: String, date: String) async throws -> [StopTime] {
        let cacheKey = "\(stopId)_\(date)"

        // Check cache
        if let cached = scheduleCache[cacheKey],
           Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            logger.debug("Schedule cache hit for \(stopId) date=\(date)")
            return cached.stopTimes
        }

        // Fetch from server
        logger.debug("Fetching schedule for \(stopId) date=\(date)")
        let schedule = try await client.getStopSchedule(id: stopId, date: date)

        // Cache result
        scheduleCache[cacheKey] = CachedSchedule(stopTimes: schedule)

        return schedule
    }

    /// Get upcoming arrivals for the next N minutes
    func getUpcomingArrivals(stopId: String, minutes: Int = 60) async throws -> [StopTime] {
        let schedule = try await getTodaySchedule(stopId: stopId)
        let now = Date()

        return schedule.filter { stopTime in
            guard let arrivalDate = stopTime.arrivalDate else { return false }
            let diff = arrivalDate.timeIntervalSince(now)
            return diff >= -60 && diff <= Double(minutes * 60)  // Include arrivals in last minute
        }
        .sorted { st1, st2 in
            (st1.arrivalDate ?? .distantFuture) < (st2.arrivalDate ?? .distantFuture)
        }
    }

    /// Get next arrival for a specific line at a stop
    func getNextArrival(stopId: String, line: String) async throws -> StopTime? {
        let arrivals = try await getUpcomingArrivals(stopId: stopId, minutes: 120)
        return arrivals.first { $0.line == line }
    }

    // MARK: - Lines Methods

    /// Get lines serving a stop
    func getStopLines(stopId: String) async throws -> [StopLine] {
        // Check cache
        if let cached = linesCache[stopId],
           Date().timeIntervalSince(cached.fetchedAt) < cacheTTL * 2 {  // 10 min for lines
            logger.debug("Lines cache hit for \(stopId)")
            return cached.lines
        }

        // Fetch from server
        logger.debug("Fetching lines for \(stopId)")
        let lines = try await client.getStopLines(id: stopId)

        // Cache result
        linesCache[stopId] = CachedLines(lines: lines)

        return lines
    }

    // MARK: - Cache Management

    /// Clear all cached data
    func clearCache() {
        scheduleCache.removeAll()
        linesCache.removeAll()
        logger.info("Schedule cache cleared")
    }

    /// Clear cache for a specific stop
    func clearCache(for stopId: String) {
        scheduleCache = scheduleCache.filter { !$0.key.hasPrefix(stopId) }
        linesCache.removeValue(forKey: stopId)
    }

    /// Preload schedules for nearby stops
    func preloadSchedules(stopIds: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for stopId in stopIds.prefix(5) {  // Limit concurrent requests
                group.addTask {
                    _ = try? await self.getTodaySchedule(stopId: stopId)
                }
            }
        }
    }
}

// MARK: - Cache Types

private struct CachedSchedule {
    let stopTimes: [StopTime]
    let fetchedAt: Date

    init(stopTimes: [StopTime]) {
        self.stopTimes = stopTimes
        self.fetchedAt = Date()
    }
}

private struct CachedLines {
    let lines: [StopLine]
    let fetchedAt: Date

    init(lines: [StopLine]) {
        self.lines = lines
        self.fetchedAt = Date()
    }
}
