import MapKit
import SwiftUI

@Observable
@MainActor
final class MapViewModel {
    // MARK: - State

    private var vehicles: [String: Vehicle] = [:]
    var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    var visibleRegion: MKCoordinateRegion?
    var showBuses = true { didSet { recomputeFiltered() } }
    var showTrams = true { didSet { recomputeFiltered() } }
    var selectedVehicle: Vehicle?
    var connectionState: ConnectionState = .disconnected
    var selectedLines: Set<String> = [] { didSet { recomputeFiltered() } }
    var showLineList = false
    var headings: [String: Double] = [:]
    let favouritesStore = FavouritesStore()

    // MARK: - Cached

    private(set) var filteredVehicles: [Vehicle] = []
    private(set) var busCount: Int = 0
    private(set) var tramCount: Int = 0
    private(set) var availableLines: [(line: String, type: VehicleType)] = []

    // MARK: - Route & Stops

    private(set) var activeRoutePolylines: [RoutePolyline] = []
    private(set) var activeRouteStops: [Stop] = []

    private static let maxAnnotations = 150

    // MARK: - Private

    private let wsService = WebSocketService()
    private var regionDebounceTask: Task<Void, Never>?
    private var wsMessageTask: Task<Void, Never>?
    private var wsStateTask: Task<Void, Never>?
    private var favouriteRefreshTask: Task<Void, Never>?
    private var _lineTypeKeys: Set<String> = []
    private var allStops: [Stop] = []
    private var routeShapesCache: [String: [RouteShape]] = [:]
    private var routeStopsCache: [String: [Stop]] = [:]
    private var routeFetchTasks: [String: Task<Void, Never>] = [:]

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

    // MARK: - Favourites

    func addFavourite(_ fav: FavouriteLine) {
        favouritesStore.add(fav)
        recomputeFiltered()
    }

    func removeFavourite(_ fav: FavouriteLine) {
        favouritesStore.remove(fav)
        recomputeFiltered()
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
        fetchRouteDataIfNeeded(for: line)
    }

    func deselectLine(_ line: String) {
        selectedLines.remove(line)
        routeFetchTasks[line]?.cancel()
        routeFetchTasks[line] = nil
        rebuildRouteOverlays()
    }

    func toggleLine(_ line: String) {
        if selectedLines.contains(line) {
            selectedLines.remove(line)
            routeFetchTasks[line]?.cancel()
            routeFetchTasks[line] = nil
            rebuildRouteOverlays()
        } else {
            selectedLines.insert(line)
            fetchRouteDataIfNeeded(for: line)
        }
    }

    // MARK: - Route Data

    private func fetchRouteDataIfNeeded(for line: String) {
        guard routeShapesCache[line] == nil else {
            rebuildRouteOverlays()
            return
        }
        routeFetchTasks[line] = Task {
            await loadAllStopsIfNeeded()
            do {
                let shapes = try await GTFSAPIService.fetchRouteShape(line: line)
                guard !Task.isCancelled else { return }
                routeShapesCache[line] = shapes
                routeStopsCache[line] = stopsNearShapes(shapes)
                rebuildRouteOverlays()
            } catch {
                // Silently skip failed fetches
            }
        }
    }

    private func loadAllStopsIfNeeded() async {
        guard allStops.isEmpty else { return }
        do {
            allStops = try await GTFSAPIService.fetchAllStops()
        } catch {
            // Silently skip
        }
    }

    private func stopsNearShapes(_ shapes: [RouteShape]) -> [Stop] {
        guard !allStops.isEmpty else { return [] }
        var shapeLocations: [CLLocation] = []
        for shape in shapes {
            let pts = shape.points
            let step = max(1, pts.count / 200)
            for i in stride(from: 0, to: pts.count, by: step) {
                shapeLocations.append(CLLocation(latitude: pts[i].lat, longitude: pts[i].lon))
            }
            if let last = pts.last {
                shapeLocations.append(CLLocation(latitude: last.lat, longitude: last.lon))
            }
        }
        return allStops.filter { stop in
            let stopLoc = CLLocation(latitude: stop.lat, longitude: stop.lon)
            return shapeLocations.contains { $0.distance(from: stopLoc) <= 80 }
        }
    }

    private func rebuildRouteOverlays() {
        var polylines: [RoutePolyline] = []
        var stops: [Stop] = []
        var seenStopIds = Set<String>()

        for line in selectedLines {
            let type = vehicleTypeForLine(line)
            if let shapes = routeShapesCache[line] {
                for shape in shapes {
                    let coords = shape.points
                        .sorted { $0.sequence < $1.sequence }
                        .map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                    polylines.append(RoutePolyline(
                        id: shape.id,
                        coordinates: coords,
                        color: type?.color ?? .blue
                    ))
                }
            }
            if let lineStops = routeStopsCache[line] {
                for stop in lineStops {
                    if seenStopIds.insert(stop.id).inserted {
                        stops.append(stop)
                    }
                }
            }
        }

        activeRoutePolylines = polylines
        activeRouteStops = stops
    }

    private func vehicleTypeForLine(_ line: String) -> VehicleType? {
        for v in vehicles.values where v.line == line {
            return v.type
        }
        return nil
    }

    // MARK: - Recompute

    private func recomputeFiltered() {
        let favLines = Set(favouritesStore.lines.map(\.line))
        let showB = showBuses
        let showT = showTrams
        let selLines = selectedLines

        var all = vehicles.values.filter { vehicle in
            switch vehicle.type {
            case .bus: guard showB else { return false }
            case .tram: guard showT else { return false }
            }
            if !selLines.isEmpty {
                return selLines.contains(vehicle.line)
            }
            return true
        }

        // Counts before capping
        var bc = 0
        var tc = 0
        for v in all {
            switch v.type {
            case .bus: bc += 1
            case .tram: tc += 1
            }
        }
        busCount = bc
        tramCount = tc

        // Cap annotations for map performance
        if all.count > Self.maxAnnotations {
            if !selLines.isEmpty || !favLines.isEmpty {
                let priority = all.filter { selLines.contains($0.line) || favLines.contains($0.line) }
                let rest = all.filter { !selLines.contains($0.line) && !favLines.contains($0.line) }
                all = Array(priority.prefix(Self.maxAnnotations))
                if all.count < Self.maxAnnotations {
                    all.append(contentsOf: rest.prefix(Self.maxAnnotations - all.count))
                }
            } else {
                all = Array(all.prefix(Self.maxAnnotations))
            }
        }

        filteredVehicles = all
    }

    private func recomputeAvailableLines() {
        var seen = Set<String>()
        var result: [(line: String, type: VehicleType)] = []
        for vehicle in vehicles.values {
            let key = "\(vehicle.type.rawValue)-\(vehicle.line)"
            if seen.insert(key).inserted {
                result.append((line: vehicle.line, type: vehicle.type))
            }
        }

        guard seen != _lineTypeKeys else { return }
        _lineTypeKeys = seen

        availableLines = result.sorted { lhs, rhs in
            if lhs.type != rhs.type { return lhs.type.rawValue < rhs.type.rawValue }
            let lNum = Int(lhs.line)
            let rNum = Int(rhs.line)
            if let l = lNum, let r = rNum { return l < r }
            if lNum != nil { return true }
            if rNum != nil { return false }
            return lhs.line < rhs.line
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
        var updatedVehicles = vehicles
        var updatedHeadings = headings

        for vehicle in snapshot {
            if let old = updatedVehicles[vehicle.key] {
                let dlat = vehicle.lat - old.lat
                let dlon = vehicle.lon - old.lon
                if abs(dlat) > 1e-6 || abs(dlon) > 1e-6 {
                    let lat1 = old.lat * .pi / 180
                    let lat2 = vehicle.lat * .pi / 180
                    let dLon = dlon * .pi / 180
                    let x = sin(dLon) * cos(lat2)
                    let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
                    let bearing = atan2(x, y) * 180 / .pi
                    updatedHeadings[vehicle.key] = (bearing + 360).truncatingRemainder(dividingBy: 360)
                }
            }
            updatedVehicles[vehicle.key] = vehicle
        }

        vehicles = updatedVehicles
        headings = updatedHeadings
        recomputeFiltered()
        recomputeAvailableLines()
    }

    private func handleDelta(updates: [Vehicle], removes: [String]) {
        var updatedVehicles = vehicles
        var updatedHeadings = headings
        var linesChanged = false

        for vehicle in updates {
            if let old = updatedVehicles[vehicle.key] {
                let dlat = vehicle.lat - old.lat
                let dlon = vehicle.lon - old.lon
                if abs(dlat) > 1e-6 || abs(dlon) > 1e-6 {
                    let lat1 = old.lat * .pi / 180
                    let lat2 = vehicle.lat * .pi / 180
                    let dLon = dlon * .pi / 180
                    let x = sin(dLon) * cos(lat2)
                    let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
                    let bearing = atan2(x, y) * 180 / .pi
                    updatedHeadings[vehicle.key] = (bearing + 360).truncatingRemainder(dividingBy: 360)
                }
            } else {
                let lineKey = "\(vehicle.type.rawValue)-\(vehicle.line)"
                if !_lineTypeKeys.contains(lineKey) {
                    linesChanged = true
                }
            }
            updatedVehicles[vehicle.key] = vehicle
        }

        for key in removes {
            updatedVehicles.removeValue(forKey: key)
            updatedHeadings.removeValue(forKey: key)
        }

        vehicles = updatedVehicles
        headings = updatedHeadings
        recomputeFiltered()

        if linesChanged || !removes.isEmpty {
            recomputeAvailableLines()
        }
    }

    // MARK: - Favourite Refresh

    private func startFavouriteRefresh() {
        favouriteRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await refreshFavouriteVehicles()
            }
        }
    }

    private func refreshFavouriteVehicles() async {
        let favLines = favouritesStore.lines
        guard !favLines.isEmpty else { return }

        var updated = vehicles
        for fav in favLines {
            do {
                let fetched = try await VehicleAPIService.fetchVehicles(line: fav.line)
                for vehicle in fetched {
                    updated[vehicle.key] = vehicle
                }
            } catch {
                // Silently skip failed fetches
            }
        }
        vehicles = updated
        recomputeFiltered()
        recomputeAvailableLines()
    }
}
