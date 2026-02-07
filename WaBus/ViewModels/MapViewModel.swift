import MapKit
import os
import SwiftUI

@Observable
@MainActor
final class MapViewModel {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WaBus", category: "MapVM")
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
    private(set) var lineColors: [String: Color] = [:]

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
    private var routeShapesCache: [String: (shapes: [RouteShape], fetchedAt: Date)] = [:]
    private var routeStopsCache: [String: (stops: [Stop], fetchedAt: Date)] = [:]
    private var routeFetchTasks: [String: Task<Void, Never>] = [:]
    private var selectedVehicleShapes: [RouteShape]?
    private let routeCacheTTL: TimeInterval = 600 // 10 minutes

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
            fetchVehicleRouteData(for: vehicle.line)
        }
    }

    func deselectVehicle() {
        if let line = selectedVehicle?.line, !selectedLines.contains(line) {
            routeFetchTasks[line]?.cancel()
            routeFetchTasks[line] = nil
        }
        selectedVehicle = nil
        selectedVehicleShapes = nil
        showVehicleDetail = false
        rebuildRouteOverlays()
    }

    // MARK: - Cluster Zoom

    func zoomToCluster(_ cluster: VehicleCluster) {
        guard let region = visibleRegion else { return }
        let newSpan = MKCoordinateSpan(
            latitudeDelta: region.span.latitudeDelta / 2.5,
            longitudeDelta: region.span.longitudeDelta / 2.5
        )
        withAnimation(DS.springHeavy) {
            cameraPosition = .region(MKCoordinateRegion(center: cluster.coordinate, span: newSpan))
        }
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
        if let cached = routeShapesCache[line], Date().timeIntervalSince(cached.fetchedAt) < routeCacheTTL {
            rebuildRouteOverlays()
            return
        }
        isLoadingRoute = true
        routeFetchTasks[line] = Task {
            do {
                async let shapesReq = WaBusClient.shared.getRouteShape(line: line)
                async let stopsReq = WaBusClient.shared.getRouteStops(line: line)
                let (shapes, stops) = try await (shapesReq, stopsReq)
                guard !Task.isCancelled else { return }
                routeShapesCache[line] = (shapes, Date())
                routeStopsCache[line] = (stops, Date())
                rebuildRouteOverlays()
            } catch {
                logger.warning("Failed to fetch route data for line \(line): \(error.localizedDescription)")
            }
            isLoadingRoute = false
        }
    }

    private func fetchVehicleRouteData(for line: String) {
        isLoadingRoute = true
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: Date())
        routeFetchTasks[line] = Task {
            do {
                async let shapesReq = WaBusClient.shared.getRouteShape(line: line, time: timeStr)
                async let stopsReq = WaBusClient.shared.getRouteStops(line: line)
                let (shapes, stops) = try await (shapesReq, stopsReq)
                guard !Task.isCancelled else { return }
                selectedVehicleShapes = shapes
                routeStopsCache[line] = (stops, Date())
                rebuildRouteOverlays()
            } catch {
                logger.warning("Failed to fetch vehicle route for line \(line): \(error.localizedDescription)")
            }
            isLoadingRoute = false
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
            let shapes: [RouteShape]?
            if line == selectedVehicle?.line, let vehicleShapes = selectedVehicleShapes {
                shapes = vehicleShapes
            } else {
                shapes = routeShapesCache[line]?.shapes
            }
            if let shapes {
                for shape in shapes {
                    polylines.append(RoutePolyline(
                        id: shape.id,
                        coordinates: shape.coordinates,
                        color: lineColors[line] ?? type?.color ?? .blue
                    ))
                }
            }
            if stopsOnlyForLine == nil || line == stopsOnlyForLine {
                if let lineStops = routeStopsCache[line]?.stops {
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
        // When a vehicle is selected, only show that one vehicle
        if let selected = selectedVehicle, let current = vehicles[selected.key] {
            selectedVehicle = current
            filteredVehicles = [current]
            singleVehicles = [current]
            vehicleClusters = []
            updateCounts()
            return
        }

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

        updateCounts(from: all)

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

    private func updateCounts(from list: [Vehicle]? = nil) {
        let source = list ?? Array(vehicles.values)
        var bc = 0
        var tc = 0
        for v in source {
            switch v.type {
            case .bus: bc += 1
            case .tram: tc += 1
            }
        }
        busCount = bc
        tramCount = tc
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

        // Fetch per-line colors from GTFS route data
        let newLines = result.map(\.line)
        Task {
            var colors: [String: Color] = [:]
            for lineName in newLines {
                if let route = await GTFSSyncManager.shared.getRoute(byLine: lineName) {
                    colors[lineName] = route.displayColor
                }
            }
            self.lineColors = colors
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
                try? await Task.sleep(for: .seconds(60))
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
                logger.debug("Failed to refresh favourite line \(fav.line): \(error.localizedDescription)")
            }
        }
        vehicles = updated
        recomputeFiltered()
        recomputeAvailableLines()
    }
}
