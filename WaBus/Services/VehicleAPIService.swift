import Foundation

enum VehicleAPIService {
    static func fetchVehicles(type: VehicleType? = nil, line: String? = nil, bbox: String? = nil) async throws -> [Vehicle] {
        var components = URLComponents(url: AppConfig.baseURL.appendingPathComponent("/v1/vehicles"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []
        if let type { queryItems.append(URLQueryItem(name: "type", value: String(type.rawValue))) }
        if let line { queryItems.append(URLQueryItem(name: "line", value: line)) }
        if let bbox { queryItems.append(URLQueryItem(name: "bbox", value: bbox)) }
        if !queryItems.isEmpty { components.queryItems = queryItems }

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try AppConfig.jsonDecoder.decode(VehiclesResponse.self, from: data)
        return response.vehicles
    }

    static func fetchVehicle(key: String) async throws -> Vehicle {
        let url = AppConfig.baseURL.appendingPathComponent("/v1/vehicles/\(key)")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try AppConfig.jsonDecoder.decode(Vehicle.self, from: data)
    }

    private struct VehiclesResponse: Decodable {
        let vehicles: [Vehicle]
    }
}
