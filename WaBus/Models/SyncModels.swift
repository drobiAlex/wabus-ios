import Foundation

// MARK: - Calendar Models

struct GTFSCalendar: Codable, Identifiable, Sendable {
    let serviceId: String
    let monday: Bool
    let tuesday: Bool
    let wednesday: Bool
    let thursday: Bool
    let friday: Bool
    let saturday: Bool
    let sunday: Bool
    let startDate: String
    let endDate: String

    var id: String { serviceId }

    enum CodingKeys: String, CodingKey {
        case serviceId = "service_id"
        case monday, tuesday, wednesday, thursday, friday, saturday, sunday
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct CalendarDate: Codable, Sendable {
    let serviceId: String
    let date: String
    let exceptionType: Int  // 1 = service added, 2 = service removed

    enum CodingKeys: String, CodingKey {
        case serviceId = "service_id"
        case date
        case exceptionType = "exception_type"
    }
}

// MARK: - Sync Response

struct SyncResponse: Codable, Sendable {
    let routes: [Route]
    let stops: [Stop]
    let calendars: [GTFSCalendar]
    let calendarDates: [CalendarDate]
    let version: String
    let generatedAt: Date

    enum CodingKeys: String, CodingKey {
        case routes, stops, calendars, version
        case calendarDates = "calendar_dates"
        case generatedAt = "generated_at"
    }
}

struct SyncCheckResponse: Codable, Sendable {
    let version: String
    let hasUpdates: Bool
    let lastUpdate: Date

    enum CodingKeys: String, CodingKey {
        case version
        case hasUpdates = "has_updates"
        case lastUpdate = "last_update"
    }
}
