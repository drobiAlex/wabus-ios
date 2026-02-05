import Foundation

enum GTFSAPIService {
    static func fetchRouteShape(line: String) async throws -> [RouteShape] {
        let url = AppConfig.baseURL.appendingPathComponent("/v1/routes/\(line)/shape")
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try AppConfig.jsonDecoder.decode(ShapesResponse.self, from: data)
        return response.shapes
    }

    static func fetchAllStops() async throws -> [Stop] {
        let url = AppConfig.baseURL.appendingPathComponent("/v1/stops")
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try AppConfig.jsonDecoder.decode(StopsResponse.self, from: data)
        return response.stops
    }
}
