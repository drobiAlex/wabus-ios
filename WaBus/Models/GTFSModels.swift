import CoreLocation
import Foundation
import SwiftUI

struct ShapePoint: Codable, Sendable {
    let lat: Double
    let lon: Double
    let sequence: Int
}

struct RouteShape: Codable, Identifiable, Sendable {
    let id: String
    let points: [ShapePoint]
}

struct ShapesResponse: Codable {
    let shapes: [RouteShape]
    let count: Int
    let serverTime: Date

    enum CodingKeys: String, CodingKey {
        case shapes, count
        case serverTime = "server_time"
    }
}

struct Stop: Codable, Identifiable, Sendable {
    let id: String
    let code: String
    let name: String
    let lat: Double
    let lon: Double
    let zone: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct StopsResponse: Codable {
    let stops: [Stop]
    let count: Int
    let serverTime: Date

    enum CodingKeys: String, CodingKey {
        case stops, count
        case serverTime = "server_time"
    }
}

struct RoutePolyline: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}
