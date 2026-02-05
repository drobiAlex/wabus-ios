import SwiftUI

enum VehicleType: Int, Codable, Sendable {
    case bus = 1
    case tram = 2

    var label: String {
        switch self {
        case .bus: "Bus"
        case .tram: "Tram"
        }
    }

    var color: Color {
        switch self {
        case .bus: .blue
        case .tram: .red
        }
    }

    var systemImage: String {
        switch self {
        case .bus: "bus.fill"
        case .tram: "tram.fill"
        }
    }
}
