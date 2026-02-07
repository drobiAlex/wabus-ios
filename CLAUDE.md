# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

- Open `WaBus.xcodeproj` in Xcode. No SPM dependencies or CocoaPods.
- iOS deployment target: 26.2, Swift 5
- Build: `xcodebuild -project WaBus.xcodeproj -scheme WaBus -sdk iphonesimulator build`
- Debug base URL points to `https://wabus-api.lokki.space`, release uses localhost (see `Config/AppConfig.swift`)

## Architecture

SwiftUI iOS app for real-time Warsaw public transit (buses & trams) tracking. Uses MVVM with Swift concurrency (`actor`, `async/await`, `@Observable`).

### Data Flow

1. **App launch** → `GTFSSyncManager.syncIfNeeded()` downloads static GTFS data (routes, stops, calendars) via `/v1/sync` bulk endpoint. Shows `SyncLoadingView` until complete.
2. **Map display** → `MapViewModel` connects to WebSocket (`/v1/ws`) for real-time vehicle positions. Subscribes/unsubscribes to map tiles (zoom 14) as the user pans.
3. **WebSocket messages** → `snapshot` (full tile data) and `delta` (incremental updates/removes) messages update the vehicle dictionary. Headings are computed from position deltas.
4. **Schedules** → fetched on-demand per stop via `ScheduleService` with 5-min in-memory cache.

### Key Services (all singletons)

- **`GTFSSyncManager`** (actor) — Bulk GTFS sync with disk cache (`~/Library/Caches/WaBus/gtfs/*.json`), ETag/304 support, retry logic for 503 (server loading). Syncs if data >6h old.
- **`ScheduleService`** (actor) — On-demand stop schedule/lines queries with in-memory TTL cache (5 min schedules, 10 min lines).
- **`WaBusClient`** — HTTP client wrapping all REST endpoints. Shared `URLSession` with 30s timeout.
- **`WebSocketService`** (actor) — Tile-based vehicle subscriptions, auto-reconnect with exponential backoff (2s→30s), 25s ping keep-alive.

### Map Performance

- Vehicle annotations capped at 150 (`maxAnnotations`). Priority given to selected/favourite lines.
- Grid-based clustering (10x10 grid over visible region) to reduce annotation count.
- Region changes debounced 300ms before updating tile subscriptions.

### Key Patterns

- JSON uses `snake_case` keys decoded via custom `CodingKeys` (not `.convertFromSnakeCase` strategy)
- `VehicleType`: `.tram = 0`, `.bus = 3` (GTFS route type values)
- GTFS times can exceed 24:00 for overnight trips (e.g., "25:30:00" = 1:30 AM next day)
- Favourites stored in UserDefaults, GTFS metadata in UserDefaults keys: `gtfs_sync_version`, `gtfs_last_sync`, `gtfs_etag`

### API

Backend REST API at `/v1/` with endpoints for vehicles, routes (with shapes/stops), stops (with schedule/lines), and sync. WebSocket at `/v1/ws` using JSON envelope messages with `type` field (`subscribe`, `unsubscribe`, `ping` outbound; `snapshot`, `delta`, `pong` inbound).
