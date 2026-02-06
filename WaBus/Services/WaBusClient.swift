import Foundation

enum WaBusError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int)
    case decodingError(Error)
    case notModified

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .httpError(let statusCode):
            return "HTTP \(statusCode)"
        case .decodingError(let error):
            return "Decoding: \(error.localizedDescription)"
        case .notModified:
            return "Not Modified (304)"
        }
    }
}

final class WaBusClient: Sendable {
    static let shared = WaBusClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        decoder = AppConfig.jsonDecoder
    }

    // MARK: - Endpoints

    private enum Endpoint {
        case vehicles
        case vehicle(key: String)
        case routes
        case route(id: String)
        case routeShape(line: String)
        case routeStops(line: String)
        case stops
        case stop(id: String)
        case stopSchedule(id: String)
        case stopLines(id: String)
        case gtfsStats
        case sync
        case syncCheck

        var path: String {
            switch self {
            case .vehicles: "/v1/vehicles"
            case .vehicle(let key): "/v1/vehicles/\(key)"
            case .routes: "/v1/routes"
            case .route(let id): "/v1/routes/\(id)"
            case .routeShape(let line): "/v1/routes/\(line)/shape"
            case .routeStops(let line): "/v1/routes/\(line)/stops"
            case .stops: "/v1/stops"
            case .stop(let id): "/v1/stops/\(id)"
            case .stopSchedule(let id): "/v1/stops/\(id)/schedule"
            case .stopLines(let id): "/v1/stops/\(id)/lines"
            case .gtfsStats: "/v1/gtfs/stats"
            case .sync: "/v1/sync"
            case .syncCheck: "/v1/sync/check"
            }
        }
    }

    // MARK: - Generic Fetch

    private func fetch<T: Decodable>(_ endpoint: Endpoint, queryItems: [URLQueryItem]? = nil) async throws -> T {
        var components = URLComponents(url: AppConfig.baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        if let queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else { throw WaBusError.invalidURL }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw WaBusError.httpError(statusCode: http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw WaBusError.decodingError(error)
        }
    }

    // MARK: - Vehicles

    func getVehicles(type: VehicleType? = nil, line: String? = nil, bbox: String? = nil) async throws -> [Vehicle] {
        var queryItems: [URLQueryItem] = []
        if let type { queryItems.append(URLQueryItem(name: "type", value: String(type.rawValue))) }
        if let line { queryItems.append(URLQueryItem(name: "line", value: line)) }
        if let bbox { queryItems.append(URLQueryItem(name: "bbox", value: bbox)) }

        let response: VehiclesResponse = try await fetch(.vehicles, queryItems: queryItems)
        return response.vehicles
    }

    func getVehicle(key: String) async throws -> Vehicle {
        try await fetch(.vehicle(key: key))
    }

    // MARK: - Routes

    func getRoutes() async throws -> [Route] {
        let response: RoutesResponse = try await fetch(.routes)
        return response.routes
    }

    func getRoute(id: String) async throws -> Route {
        try await fetch(.route(id: id))
    }

    func getRouteShape(line: String, time: String? = nil) async throws -> [RouteShape] {
        var queryItems: [URLQueryItem] = []
        if let time { queryItems.append(URLQueryItem(name: "time", value: time)) }
        let response: ShapesResponse = try await fetch(.routeShape(line: line), queryItems: queryItems.isEmpty ? nil : queryItems)
        return response.shapes
    }

    func getRouteStops(line: String) async throws -> [Stop] {
        let response: StopsResponse = try await fetch(.routeStops(line: line))
        return response.stops
    }

    // MARK: - Stops

    func getStops() async throws -> [Stop] {
        let response: StopsResponse = try await fetch(.stops)
        return response.stops
    }

    func getStop(id: String) async throws -> Stop {
        try await fetch(.stop(id: id))
    }

    func getStopSchedule(id: String, date: String? = "today") async throws -> [StopTime] {
        var queryItems: [URLQueryItem] = []
        if let date { queryItems.append(URLQueryItem(name: "date", value: date)) }
        let response: StopScheduleResponse = try await fetch(.stopSchedule(id: id), queryItems: queryItems)
        return response.stopTimes
    }

    func getStopLines(id: String) async throws -> [StopLine] {
        let response: StopLinesResponse = try await fetch(.stopLines(id: id))
        return response.lines
    }

    // MARK: - Stats

    func getGTFSStats() async throws -> GTFSStats {
        try await fetch(.gtfsStats)
    }

    // MARK: - Sync

    func checkSync(since version: String?) async throws -> SyncCheckResponse {
        var queryItems: [URLQueryItem] = []
        if let version {
            queryItems.append(URLQueryItem(name: "since", value: version))
        }
        return try await fetch(.syncCheck, queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    func getSync(etag: String? = nil) async throws -> (SyncResponse, String?) {
        var components = URLComponents(
            url: AppConfig.baseURL.appendingPathComponent(Endpoint.sync.path),
            resolvingAgainstBaseURL: false
        )
        guard let url = components?.url else { throw WaBusError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 304 {
                throw WaBusError.notModified
            }
            if !(200...299).contains(http.statusCode) {
                throw WaBusError.httpError(statusCode: http.statusCode)
            }
        }

        let newEtag = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")

        do {
            let syncResponse = try decoder.decode(SyncResponse.self, from: data)
            return (syncResponse, newEtag)
        } catch {
            throw WaBusError.decodingError(error)
        }
    }
}

// MARK: - Private Response Types

private struct VehiclesResponse: Decodable {
    let vehicles: [Vehicle]
}
