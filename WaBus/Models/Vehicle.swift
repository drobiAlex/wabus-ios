import CoreLocation
import Foundation

struct Vehicle: Codable, Identifiable, Sendable {
    let key: String
    let vehicleNumber: String
    let type: VehicleType
    let line: String
    let brigade: String
    let lat: Double
    let lon: Double
    let timestamp: Date
    let tileId: String
    let updatedAt: Date

    var id: String { key }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
