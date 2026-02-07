import SwiftUI

enum RouteType: Int, Codable, Sendable {
    case tram = 0
    case bus = 3

    var displayName: String {
        switch self {
        case .tram: "Tram"
        case .bus: "Bus"
        }
    }

    var icon: String {
        switch self {
        case .tram: "tram.fill"
        case .bus: "bus.fill"
        }
    }

    var color: Color {
        switch self {
        case .bus: Color(red: 0.20, green: 0.48, blue: 1.0)
        case .tram: Color(red: 1.0, green: 0.27, blue: 0.35)
        }
    }
}

struct Route: Codable, Identifiable, Sendable {
    let id: String
    let shortName: String
    let longName: String
    let type: RouteType
    let color: String
    let textColor: String

    enum CodingKeys: String, CodingKey {
        case id
        case shortName = "short_name"
        case longName = "long_name"
        case type, color
        case textColor = "text_color"
    }

    var displayColor: Color {
        Color(hex: color) ?? .blue
    }

    var displayTextColor: Color {
        Color(hex: textColor) ?? .white
    }
}

struct RoutesResponse: Codable {
    let routes: [Route]
    let count: Int
    let serverTime: Date

    enum CodingKeys: String, CodingKey {
        case routes, count
        case serverTime = "server_time"
    }
}
