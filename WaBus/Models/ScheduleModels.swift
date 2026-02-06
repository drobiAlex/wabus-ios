import SwiftUI

struct StopTime: Codable, Identifiable, Sendable {
    let tripId: String
    let routeId: String
    let line: String
    let headsign: String
    let arrivalTime: String
    let departureTime: String
    let stopSequence: Int

    var id: String { "\(tripId)-\(stopSequence)" }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case routeId = "route_id"
        case line, headsign
        case arrivalTime = "arrival_time"
        case departureTime = "departure_time"
        case stopSequence = "stop_sequence"
    }

    /// Arrival time without seconds, e.g. "14:30" or "25:30" → "1:30".
    var displayTime: String {
        let parts = arrivalTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return arrivalTime }
        var h = parts[0]
        if h >= 24 { h -= 24 }
        return String(format: "%d:%02d", h, parts[1])
    }

    /// Parses GTFS time strings that may exceed 24:00:00 (e.g. "25:30:00").
    /// Returns a Date for today (or tomorrow if hours >= 24).
    var arrivalDate: Date? {
        Self.parseGTFSTime(arrivalTime)
    }

    static func parseGTFSTime(_ timeString: String) -> Date? {
        let parts = timeString.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        var hours = parts[0]
        let minutes = parts[1]
        let seconds = parts[2]

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())

        if hours >= 24 {
            hours -= 24
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) {
                components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            }
        }

        components.hour = hours
        components.minute = minutes
        components.second = seconds

        return calendar.date(from: components)
    }
}

struct StopScheduleResponse: Codable {
    let stopTimes: [StopTime]
    let count: Int
    let serverTime: Date

    enum CodingKeys: String, CodingKey {
        case stopTimes = "stop_times"
        case count
        case serverTime = "server_time"
    }
}

struct StopLine: Codable, Identifiable, Sendable {
    let routeId: String
    let line: String
    let longName: String
    let type: RouteType
    let color: String
    let headsigns: [String]

    var id: String { routeId }

    enum CodingKeys: String, CodingKey {
        case routeId = "route_id"
        case line
        case longName = "long_name"
        case type, color, headsigns
    }

    var displayColor: Color {
        Color(hex: color) ?? .blue
    }
}

struct StopLinesResponse: Codable {
    let lines: [StopLine]
    let count: Int
    let serverTime: Date

    enum CodingKeys: String, CodingKey {
        case lines, count
        case serverTime = "server_time"
    }
}

struct GTFSStats: Codable, Sendable {
    let routeCount: Int
    let stopCount: Int
    let tripCount: Int
    let lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case routeCount = "route_count"
        case stopCount = "stop_count"
        case tripCount = "trip_count"
        case lastUpdated = "last_updated"
    }
}
