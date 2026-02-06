# iOS GTFS Sync Implementation

## Overview

The iOS app uses a two-tier caching strategy:
1. **Bulk sync** - Routes, stops, and calendars downloaded once daily via `/v1/sync`
2. **On-demand** - Schedules and stop lines fetched as needed with short TTL cache

## Optimization Phases

### Phase 1: Bulk Sync Endpoint
Instead of making separate API calls for routes, stops, and calendars, the app downloads everything in one request.

| Before | After |
|--------|-------|
| `GET /v1/routes` | `GET /v1/sync` (single request) |
| `GET /v1/stops` | |
| `GET /v1/calendars` | |

**Bandwidth saved:** 3 requests → 1 request

### Phase 2: Gzip Compression
All API responses are gzip compressed. The `/v1/sync` endpoint returns ~500KB compressed instead of ~2MB raw.

```
Request:  Accept-Encoding: gzip
Response: Content-Encoding: gzip
```

**Bandwidth saved:** ~75% reduction

### Phase 3: ETag Caching
The sync endpoint supports conditional requests. If data hasn't changed, server returns 304 Not Modified with empty body.

```
First request:
  Response: ETag: "abc123"

Subsequent requests:
  Request:  If-None-Match: "abc123"
  Response: 304 Not Modified (0 bytes)
```

**Bandwidth saved:** 100% when data unchanged

### Phase 4: Redis Cache Warming
Backend pre-computes and caches frequently accessed data:

| Data | Cache Key | TTL |
|------|-----------|-----|
| Full sync data | `sync:full` | 24h |
| Today's schedule per stop | `schedule:today:{stopId}` | 24h |
| Tomorrow's schedule per stop | `schedule:tomorrow:{stopId}` | 24h |
| Lines per stop | `stop_lines:{stopId}` | 24h |

Cache is warmed:
- After each GTFS data update
- At midnight for new day's schedules

**Response time:** <10ms for cached data vs ~100ms for computed

## API Endpoints

### Sync Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /v1/sync/check?since={version}` | Check if updates available |
| `GET /v1/sync` | Bulk download all static GTFS data |

### Route Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /v1/routes` | List all routes |
| `GET /v1/routes/{line}` | Get route by line number |
| `GET /v1/routes/{line}/shape` | Get route polyline coordinates |
| `GET /v1/routes/{line}/stops` | Get stops along a route |

### Stop Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /v1/stops` | List all stops |
| `GET /v1/stops/{id}` | Get stop by ID |
| `GET /v1/stops/{id}/schedule?date=today` | Get stop schedule for date |
| `GET /v1/stops/{id}/lines` | Get lines serving this stop |

### Vehicle Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /v1/vehicles` | List all vehicles |
| `GET /v1/vehicles/{key}` | Get vehicle by key |
| `WebSocket /v1/ws` | Real-time vehicle updates |

## Data Models

### SyncResponse
```swift
struct SyncResponse: Codable {
    let routes: [Route]
    let stops: [Stop]
    let calendars: [GTFSCalendar]
    let calendarDates: [CalendarDate]
    let version: String           // e.g., "2024-01-16"
    let generatedAt: Date
}
```

### SyncCheckResponse
```swift
struct SyncCheckResponse: Codable {
    let version: String
    let hasUpdates: Bool
    let lastUpdate: Date
}
```

### Route
```swift
struct Route: Codable, Identifiable {
    let id: String
    let shortName: String      // Line number (e.g., "175")
    let longName: String       // Full route name
    let type: RouteType        // .tram (0) or .bus (3)
    let color: String          // Hex color
    let textColor: String      // Hex text color
}
```

### Stop
```swift
struct Stop: Codable, Identifiable {
    let id: String
    let code: String
    let name: String
    let lat: Double
    let lon: Double
    let zone: String
}
```

### StopTime (Schedule Entry)
```swift
struct StopTime: Codable, Identifiable {
    let tripId: String
    let routeId: String
    let line: String
    let headsign: String
    let arrivalTime: String     // GTFS format: "14:30:00" or "25:30:00"
    let departureTime: String
    let stopSequence: Int
}
```

### StopLine
```swift
struct StopLine: Codable, Identifiable {
    let routeId: String
    let line: String
    let longName: String
    let type: RouteType
    let color: String
    let headsigns: [String]
}
```

### GTFSCalendar
```swift
struct GTFSCalendar: Codable, Identifiable {
    let serviceId: String
    let monday: Bool
    let tuesday: Bool
    let wednesday: Bool
    let thursday: Bool
    let friday: Bool
    let saturday: Bool
    let sunday: Bool
    let startDate: String       // YYYYMMDD
    let endDate: String         // YYYYMMDD
}
```

### CalendarDate (Exceptions)
```swift
struct CalendarDate: Codable {
    let serviceId: String
    let date: String            // YYYYMMDD
    let exceptionType: Int      // 1 = added, 2 = removed
}
```

## Services

### GTFSSyncManager

Singleton actor that manages GTFS data synchronization and local caching.

```swift
// Sync on app launch
await GTFSSyncManager.shared.syncIfNeeded()

// Force sync
try await GTFSSyncManager.shared.forceSync()

// Access cached data (no network calls)
let routes = await GTFSSyncManager.shared.getAllRoutes()
let route = await GTFSSyncManager.shared.getRoute(byLine: "175")
let stops = await GTFSSyncManager.shared.getAllStops()
let nearbyStops = await GTFSSyncManager.shared.getStopsNear(
    coordinate: userLocation,
    radiusMeters: 500
)
let searchResults = await GTFSSyncManager.shared.searchStops(query: "Centrum")

// Calendar filtering
let activeServices = await GTFSSyncManager.shared.getActiveServiceIds(for: Date())
```

**Caching behavior:**
- Data persisted to `Caches/gtfs/*.json`
- Syncs if data is >6 hours old or missing
- Uses ETag for conditional requests (304 Not Modified)
- Loads from disk first, then syncs in background

### ScheduleService

Singleton actor for schedule queries with in-memory caching.

```swift
// Get today's schedule (cached for 5 min)
let schedule = try await ScheduleService.shared.getTodaySchedule(stopId: "1001")

// Get upcoming arrivals
let arrivals = try await ScheduleService.shared.getUpcomingArrivals(
    stopId: "1001",
    minutes: 60
)

// Get next arrival for specific line
let next = try await ScheduleService.shared.getNextArrival(
    stopId: "1001",
    line: "175"
)

// Get lines at stop (cached for 10 min)
let lines = try await ScheduleService.shared.getStopLines(stopId: "1001")

// Clear cache
await ScheduleService.shared.clearCache()
await ScheduleService.shared.clearCache(for: "1001")

// Preload for nearby stops
await ScheduleService.shared.preloadSchedules(stopIds: ["1001", "1002", "1003"])
```

### WaBusClient

HTTP client for all API calls.

```swift
// Vehicles
let vehicles = try await WaBusClient.shared.getVehicles(type: .bus, line: "175")
let vehicle = try await WaBusClient.shared.getVehicle(key: "bus-175-1234")

// Routes
let routes = try await WaBusClient.shared.getRoutes()
let route = try await WaBusClient.shared.getRoute(id: "route_175")
let shapes = try await WaBusClient.shared.getRouteShape(line: "175")
let routeStops = try await WaBusClient.shared.getRouteStops(line: "175")

// Stops
let stops = try await WaBusClient.shared.getStops()
let stop = try await WaBusClient.shared.getStop(id: "1001")
let schedule = try await WaBusClient.shared.getStopSchedule(id: "1001", date: "today")
let lines = try await WaBusClient.shared.getStopLines(id: "1001")

// Sync
let check = try await WaBusClient.shared.checkSync(since: "2024-01-15")
let (syncData, etag) = try await WaBusClient.shared.getSync(etag: previousEtag)
```

## App Lifecycle Integration

```swift
@main
struct WaBusApp: App {
    @State private var isSyncing = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isSyncing {
                    SyncLoadingView()
                } else {
                    ContentView()
                }
            }
            .task {
                await GTFSSyncManager.shared.syncIfNeeded()
                isSyncing = false
            }
        }
    }
}
```

## File Structure

```
WaBus/
├── Models/
│   ├── GTFSModels.swift        # Stop, RouteShape, ShapePoint
│   ├── RouteModels.swift       # Route, RouteType
│   ├── ScheduleModels.swift    # StopTime, StopLine, StopScheduleResponse
│   └── SyncModels.swift        # SyncResponse, GTFSCalendar, CalendarDate
├── Services/
│   ├── GTFSSyncManager.swift   # Bulk sync + disk caching
│   ├── ScheduleService.swift   # Schedule queries + memory caching
│   └── WaBusClient.swift       # HTTP client
└── Config/
    └── AppConfig.swift         # Base URL, JSON coders
```

## Disk Cache Location

```
~/Library/Caches/WaBus/gtfs/
├── routes.json
├── stops.json
├── calendars.json
└── calendar_dates.json
```

UserDefaults keys:
- `gtfs_sync_version` - Current data version (e.g., "2024-01-16")
- `gtfs_last_sync` - Last sync timestamp
- `gtfs_etag` - ETag for conditional requests

## HTTP Headers

Requests:
```
Accept-Encoding: gzip
If-None-Match: "abc123"    (for sync endpoint)
```

Responses:
```
Content-Encoding: gzip
ETag: "abc123"
Cache-Control: public, max-age=3600
```

## GTFS Time Handling

GTFS times can exceed 24:00 for overnight trips (e.g., "25:30:00" = 1:30 AM next day).

```swift
extension StopTime {
    var arrivalDate: Date? {
        let parts = arrivalTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        var hours = parts[0]
        let minutes = parts[1]
        let seconds = parts[2]

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())

        if hours >= 24 {
            hours -= 24
            if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                components = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
            }
        }

        components.hour = hours
        components.minute = minutes
        components.second = seconds

        return Calendar.current.date(from: components)
    }
}
```

## Bandwidth Optimization

| Data | Strategy | Typical Size |
|------|----------|--------------|
| Routes, Stops, Calendars | Daily bulk sync with gzip | ~500KB compressed |
| Stop Schedule | On-demand with `?date=today` | ~5-20KB per stop |
| Route Shape | Cached in memory per session | ~50-100KB per route |
| Vehicles | WebSocket real-time stream | ~1KB per update |
