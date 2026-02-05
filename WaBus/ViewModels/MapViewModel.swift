import MapKit
import SwiftUI

@Observable
@MainActor
final class MapViewModel {
    // MARK: - State

    var vehicles: [String: Vehicle] = [:]
    var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    var visibleRegion: MKCoordinateRegion?
    var showBuses = true
    var showTrams = true
    var selectedVehicle: Vehicle?
    var connectionState: ConnectionState = .disconnected
    var selectedLines: Set<String> = []
    var showLineList = false
    var headings: [String: Double] = [:]
    let favouritesStore = FavouritesStore()

    // MARK: - Computed

    var filteredVehicles: [Vehicle] {
        let favLines = Set(favouritesStore.lines.map(\.line))
        return vehicles.values.filter { vehicle in
            // Type filter
            switch vehicle.type {
            case .bus: guard showBuses else { return false }
            case .tram: guard showTrams else { return false }
            }
            // Line filter: if lines selected, show selected + favourites
            if !selectedLines.isEmpty {
                return selectedLines.contains(vehicle.line) || favLines.contains(vehicle.line)
            }
            return true
        }
    }

    var availableLines: [(line: String, type: VehicleType)] {
        var seen = Set<String>()
        var result: [(line: String, type: VehicleType)] = []
        for vehicle in vehicles.values {
            let key = "\(vehicle.type.rawValue)-\(vehicle.line)"
            if seen.insert(key).inserted {
                result.append((line: vehicle.line, type: vehicle.type))
            }
        }
        return result.sorted { lhs, rhs in
            if lhs.type != rhs.type { return lhs.type.rawValue < rhs.type.rawValue }
            // Numeric sort, then alphabetical
            let lNum = Int(lhs.line)
            let rNum = Int(rhs.line)
            if let l = lNum, let r = rNum { return l < r }
            if lNum != nil { return true }
            if rNum != nil { return false }
            return lhs.line < rhs.line
        }
    }

    // MARK: - Private

    private let wsService = WebSocketService()
    private var regionDebounceTask: Task<Void, Never>?
    private var wsMessageTask: Task<Void, Never>?
    private var wsStateTask: Task<Void, Never>?
    private var favouriteRefreshTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func start() {
        wsMessageTask = Task {
            let stream = await wsService.messageStream
            for await message in stream {
                handleMessage(message)
            }
        }

        wsStateTask = Task {
            let stream = await wsService.stateStream
            for await state in stream {
                connectionState = state
            }
        }

        Task { await wsService.connect() }

        startFavouriteRefresh()
    }

    // MARK: - Map Region

    func onMapRegionChanged(_ region: MKCoordinateRegion) {
        visibleRegion = region
        regionDebounceTask?.cancel()
        regionDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let tiles = TileCalculator.visibleTileIds(for: region)
            await wsService.updateSubscriptions(tileIds: tiles)
        }
    }

    // MARK: - Line Selection

    func selectLine(_ line: String) {
        selectedLines.insert(line)
    }

    func deselectLine(_ line: String) {
        selectedLines.remove(line)
    }

    func toggleLine(_ line: String) {
        if selectedLines.contains(line) {
            selectedLines.remove(line)
        } else {
            selectedLines.insert(line)
        }
    }

    // MARK: - Message Handling

    private func handleMessage(_ message: WSInboundMessage) {
        switch message {
        case .snapshot(let snapshot):
            handleSnapshot(snapshot)
        case .delta(let updates, let removes):
            handleDelta(updates: updates, removes: removes)
        case .pong:
            break
        }
    }

    private func handleSnapshot(_ snapshot: [Vehicle]) {
        for vehicle in snapshot {
            updateHeading(for: vehicle)
            vehicles[vehicle.key] = vehicle
        }
    }

    private func handleDelta(updates: [Vehicle], removes: [String]) {
        for vehicle in updates {
            updateHeading(for: vehicle)
            vehicles[vehicle.key] = vehicle
        }
        for key in removes {
            vehicles.removeValue(forKey: key)
            headings.removeValue(forKey: key)
        }
    }

    private func updateHeading(for vehicle: Vehicle) {
        guard let old = vehicles[vehicle.key] else { return }
        let dlat = vehicle.lat - old.lat
        let dlon = vehicle.lon - old.lon
        // Skip if position hasn't changed (avoid stale heading)
        guard abs(dlat) > 1e-6 || abs(dlon) > 1e-6 else { return }

        let lat1 = old.lat * .pi / 180
        let lat2 = vehicle.lat * .pi / 180
        let dLon = (vehicle.lon - old.lon) * .pi / 180

        let x = sin(dLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(x, y) * 180 / .pi
        headings[vehicle.key] = (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Favourite Refresh

    private func startFavouriteRefresh() {
        favouriteRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                await refreshFavouriteVehicles()
            }
        }
    }

    private func refreshFavouriteVehicles() async {
        let favLines = favouritesStore.lines
        guard !favLines.isEmpty else { return }

        for fav in favLines {
            do {
                let fetched = try await VehicleAPIService.fetchVehicles(line: fav.line)
                for vehicle in fetched {
                    vehicles[vehicle.key] = vehicle
                }
            } catch {
                // Silently skip failed fetches
            }
        }
    }
}
