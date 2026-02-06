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
    var showVehicleDetail = false
    var isLoadingRoute = false
    var selectedStop: Stop?
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

    // MARK: - Clustering

    private(set) var singleVehicles: [Vehicle] = []
    private(set) var vehicleClusters: [VehicleCluster] = []

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

    // MARK: - Vehicle Selection

    func selectVehicle(_ vehicle: Vehicle) {
        let previousLine = selectedVehicle?.line
        selectedVehicle = vehicle

        // Load route for this vehicle's line
        if vehicle.line != previousLine {
            // Clear previous vehicle route if it wasn't in selectedLines
            if let prev = previousLine, !selectedLines.contains(prev) {
                routeFetchTasks[prev]?.cancel()
                routeFetchTasks[prev] = nil
            }
            fetchRouteDataIfNeeded(for: vehicle.line)
        }
    }

    func deselectVehicle() {
        if let line = selectedVehicle?.line, !selectedLines.contains(line) {
            routeFetchTasks[line]?.cancel()
            routeFetchTasks[line] = nil
        }
        selectedVehicle = nil
        showVehicleDetail = false
        rebuildRouteOverlays()
    }

    // MARK: - Map Region

    func onMapRegionChanged(_ region: MKCoordinateRegion) {
        visibleRegion = region
        clusterVehicles(filteredVehicles)
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
        isLoadingRoute = true
        routeFetchTasks[line] = Task {
            await loadAllStopsIfNeeded()
            do {
                let shapes = try await WaBusClient.shared.getRouteShape(line: line)
                guard !Task.isCancelled else { return }
                routeShapesCache[line] = shapes
                routeStopsCache[line] = stopsNearShapes(shapes)
                rebuildRouteOverlays()
            } catch {
                // Silently skip failed fetches
            }
            isLoadingRoute = false
        }
    }

    private func loadAllStopsIfNeeded() async {
        guard allStops.isEmpty else { return }
        do {
            allStops = try await WaBusClient.shared.getStops()
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

        // Collect lines to show: selectedLines + selected vehicle's line
        var linesToShow = selectedLines
        if let vehicleLine = selectedVehicle?.line {
            linesToShow.insert(vehicleLine)
        }

        // When a vehicle is selected, only show stops for its line
        let stopsOnlyForLine = selectedVehicle?.line

        for line in linesToShow {
            let type = vehicleTypeForLine(line)
            if let shapes = routeShapesCache[line] {
                for shape in shapes {
                    polylines.append(RoutePolyline(
                        id: shape.id,
                        coordinates: shape.coordinates,
                        color: type?.color ?? .blue
                    ))
                }
            }
            if stopsOnlyForLine == nil || line == stopsOnlyForLine {
                if let lineStops = routeStopsCache[line] {
                    for stop in lineStops {
                        if seenStopIds.insert(stop.id).inserted {
                            stops.append(stop)
                        }
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
        clusterVehicles(all)
    }

    private func clusterVehicles(_ vehicles: [Vehicle]) {
        guard let region = visibleRegion else {
            singleVehicles = vehicles
            vehicleClusters = []
            return
        }

        let gridSize = 10
        let cellW = region.span.longitudeDelta / Double(gridSize)
        let cellH = region.span.latitudeDelta / Double(gridSize)
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2

        var grid: [Int: [Vehicle]] = [:]
        for v in vehicles {
            let col = min(gridSize - 1, max(0, Int((v.lon - minLon) / cellW)))
            let row = min(gridSize - 1, max(0, Int((v.lat - minLat) / cellH)))
            grid[row * gridSize + col, default: []].append(v)
        }

        var singles: [Vehicle] = []
        var clusters: [VehicleCluster] = []
        for (key, cell) in grid {
            if cell.count == 1 {
                singles.append(cell[0])
            } else {
                let avgLat = cell.reduce(0.0) { $0 + $1.lat } / Double(cell.count)
                let avgLon = cell.reduce(0.0) { $0 + $1.lon } / Double(cell.count)
                var bc = 0
                for v in cell where v.type == .bus { bc += 1 }
                clusters.append(VehicleCluster(
                    id: "cl-\(key)",
                    coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                    count: cell.count,
                    type: bc >= cell.count - bc ? .bus : .tram
                ))
            }
        }
        singleVehicles = singles
        vehicleClusters = clusters
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
        withAnimation(.easeInOut(duration: 0.8)) {
            recomputeFiltered()
        }
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
        withAnimation(.easeInOut(duration: 0.8)) {
            recomputeFiltered()
        }

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
                let fetched = try await WaBusClient.shared.getVehicles(line: fav.line)
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
