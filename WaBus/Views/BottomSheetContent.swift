import SwiftUI

struct BottomSheetContent: View {
    @Bindable var viewModel: MapViewModel

    var body: some View {
        if let vehicle = viewModel.selectedVehicle {
            VehicleSheetContent(viewModel: viewModel, vehicle: vehicle)
        } else if let stop = viewModel.selectedStop {
            StopSheetContent(viewModel: viewModel, stop: stop)
        } else {
            DefaultSheetContent(viewModel: viewModel)
        }
    }
}

// MARK: - Default Sheet Content

private struct DefaultSheetContent: View {
    @Bindable var viewModel: MapViewModel
    @State private var searchText = ""
    @State private var selectedType: VehicleType?

    private var filteredLines: [(line: String, type: VehicleType)] {
        var result = viewModel.availableLines
        if !searchText.isEmpty {
            result = result.filter { $0.line.localizedCaseInsensitiveContains(searchText) }
        }
        if let selectedType {
            result = result.filter { $0.type == selectedType }
        }
        return result
    }

    private var groupedLines: [VehicleType: [String]] {
        var result: [VehicleType: [String]] = [:]
        for item in filteredLines {
            result[item.type, default: []].append(item.line)
        }
        return result
    }

    private var busLineCount: Int {
        viewModel.availableLines.filter { $0.type == .bus }.count
    }

    private var tramLineCount: Int {
        viewModel.availableLines.filter { $0.type == .tram }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Filter pills — always visible at collapsed
                filterPills
                    .padding(.top, DS.Spacing.lg)

                // Title — visible at half+
                HStack {
                    Text("Lines")
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        withAnimation(DS.spring) {
                            viewModel.selectedDetent = .large
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.gray, Color(.tertiarySystemFill))
                    }
                    .accessibilityLabel("Browse all lines")
                }
                .padding(.horizontal, 20)
                .padding(.top, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.md)

                // Search bar
                HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    TextField("Search lines", text: $searchText)
                        .font(.body)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemFill))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, DS.Spacing.lg)

                // Type filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        lineFilterPill(
                            label: "All",
                            count: viewModel.availableLines.count,
                            color: .blue,
                            isSelected: selectedType == nil
                        ) {
                            selectedType = nil
                        }

                        lineFilterPill(
                            label: "Buses",
                            count: busLineCount,
                            color: VehicleType.bus.color,
                            isSelected: selectedType == .bus,
                            icon: "bus.fill"
                        ) {
                            selectedType = selectedType == .bus ? nil : .bus
                        }

                        lineFilterPill(
                            label: "Trams",
                            count: tramLineCount,
                            color: VehicleType.tram.color,
                            isSelected: selectedType == .tram,
                            icon: "tram.fill"
                        ) {
                            selectedType = selectedType == .tram ? nil : .tram
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, DS.Spacing.lg)

                // Line list
                let grouped = groupedLines
                if let buses = grouped[.bus], !buses.isEmpty {
                    lineSection(title: "Buses", lines: buses, type: .bus)
                }
                if let trams = grouped[.tram], !trams.isEmpty {
                    lineSection(title: "Trams", lines: trams, type: .tram)
                }

                if viewModel.availableLines.isEmpty {
                    ContentUnavailableView(
                        "No Lines Available",
                        systemImage: "bus",
                        description: Text("Waiting for vehicle data...")
                    )
                    .padding(.top, 60)
                }
            }
        }
    }

    // MARK: - Filter Pills (collapsed bar)

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                typePill(
                    type: .bus,
                    isActive: viewModel.showBuses,
                    count: viewModel.busCount
                ) {
                    viewModel.showBuses.toggle()
                }

                typePill(
                    type: .tram,
                    isActive: viewModel.showTrams,
                    count: viewModel.tramCount
                ) {
                    viewModel.showTrams.toggle()
                }

                if !viewModel.favouritesStore.lines.isEmpty {
                    Divider()
                        .frame(height: 32)
                        .overlay(Color(.separator))
                }

                ForEach(viewModel.favouritesStore.lines) { fav in
                    let isSelected = viewModel.selectedLines.contains(fav.line)
                    favouritePill(fav: fav, isSelected: isSelected)
                }

                if viewModel.favouritesStore.lines.isEmpty {
                    Text("Tap + to add lines")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, DS.Spacing.xs)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Type Pill

    private func typePill(type: VehicleType, isActive: Bool, count: Int, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(DS.spring) {
                action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: type.systemImage)
                    .font(.subheadline.weight(.semibold))
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minWidth: 70)
            .background {
                if isActive {
                    Capsule().fill(type.color)
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .foregroundStyle(isActive ? .white : .secondary)
        }
        .frame(minHeight: DS.Size.minTapTarget)
        .sensoryFeedback(.selection, trigger: isActive)
        .accessibilityLabel("\(count) \(type.label.lowercased())s")
        .accessibilityValue(isActive ? "active" : "inactive")
    }

    // MARK: - Favourite Pill

    private func favouritePill(fav: FavouriteLine, isSelected: Bool) -> some View {
        Button {
            withAnimation(DS.spring) {
                viewModel.toggleLine(fav.line)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: fav.type.systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(fav.line)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: DS.Size.minTapTarget)
            .background {
                if isSelected {
                    Capsule().fill(fav.type.color)
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .sensoryFeedback(.selection, trigger: isSelected)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.removeFavourite(fav)
                viewModel.selectedLines.remove(fav.line)
            } label: {
                Label("Remove from Favourites", systemImage: "star.slash")
            }
        }
        .accessibilityLabel("\(fav.type.label) line \(fav.line)")
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }

    // MARK: - Line Filter Pill

    private func lineFilterPill(label: String, count: Int, color: Color, isSelected: Bool, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(DS.spring) {
                action()
            }
        } label: {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                }
                Text("\(label) (\(count))")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? color : color.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }

    // MARK: - Line Section

    private func lineSection(title: String, lines: [String], type: VehicleType) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(title.uppercased())
                    .font(.footnote.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(lines.count)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)

            LazyVStack(spacing: 0) {
                ForEach(lines, id: \.self) { line in
                    lineRow(line: line, type: type)
                    if line != lines.last {
                        Divider()
                            .padding(.leading, 20 + 48 + 14)
                    }
                }
            }
        }
        .padding(.bottom, DS.Spacing.lg)
    }

    // MARK: - Line Row

    private func lineRow(line: String, type: VehicleType) -> some View {
        let isSelected = viewModel.selectedLines.contains(line)
        let isFav = viewModel.favouritesStore.isFavourite(line: line, type: type)

        return HStack(spacing: 14) {
            Text(line)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 48, height: 36)
                .background(viewModel.lineColors[line] ?? type.color, in: RoundedRectangle(cornerRadius: 8))
                .minimumScaleFactor(0.6)

            VStack(alignment: .leading, spacing: 3) {
                Text(type.label)
                    .font(.body)
                if isSelected {
                    Text("Selected")
                        .font(.subheadline)
                        .foregroundStyle(type.color)
                }
            }

            Spacer()

            Button {
                let fav = FavouriteLine(line: line, type: type)
                if isFav {
                    viewModel.removeFavourite(fav)
                } else {
                    viewModel.addFavourite(fav)
                }
            } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isFav ? .yellow : Color(.systemGray3))
                    .animation(DS.spring, value: isFav)
            }
            .buttonStyle(.plain)
            .frame(minWidth: DS.Size.minTapTarget, minHeight: DS.Size.minTapTarget)
            .accessibilityLabel(isFav ? "Remove \(line) from favourites" : "Add \(line) to favourites")

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? type.color : Color(.systemGray3))
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(DS.spring) {
                viewModel.toggleLine(line)
            }
        }
        .accessibilityLabel("\(type.label) line \(line)")
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }
}

// MARK: - Vehicle Sheet Content

private struct VehicleSheetContent: View {
    @Bindable var viewModel: MapViewModel
    let vehicle: Vehicle
    @State private var starScale: CGFloat = 1.0

    private var isFavourite: Bool {
        viewModel.favouritesStore.isFavourite(line: vehicle.line, type: vehicle.type)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Mini bar — always visible at collapsed
                vehicleMiniBar
                    .padding(.top, DS.Spacing.lg)

                // Title
                HStack {
                    Text("Line \(vehicle.line)")
                        .font(.title2.bold())
                    Spacer()
                }
                .padding(.horizontal, 20)

                // Detail content
                VStack(spacing: 10) {
                    infoRow(title: "Vehicle", value: vehicle.vehicleNumber, icon: "number")
                    infoRow(title: "Updated", value: vehicle.updatedAt.formatted(.relative(presentation: .named)), icon: "clock")
                }
                .padding(.horizontal, 20)

                // Favourite button
                Button {
                    let fav = FavouriteLine(line: vehicle.line, type: vehicle.type)
                    if isFavourite {
                        viewModel.removeFavourite(fav)
                    } else {
                        viewModel.addFavourite(fav)
                    }
                    withAnimation(DS.spring) {
                        starScale = 1.3
                    }
                    withAnimation(DS.spring.delay(0.15)) {
                        starScale = 1.0
                    }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: isFavourite ? "star.fill" : "star")
                            .scaleEffect(starScale)
                        Text(isFavourite ? "Favourited" : "Add to Favourites")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(isFavourite ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        if isFavourite {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(vehicle.type.color)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.quaternarySystemFill))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(vehicle.type.color.opacity(0.4), lineWidth: 1.5)
                                )
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: isFavourite)
                .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")
                .padding(.horizontal, 20)

                // Route stops
                if !viewModel.activeRouteStops.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("ROUTE STOPS")
                            .font(.footnote.weight(.semibold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.activeRouteStops) { stop in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(vehicle.type.color)
                                        .frame(width: 10, height: 10)
                                    Text(stop.name)
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedStop = stop
                                    viewModel.selectedDetent = .medium
                                }
                                if stop.id != viewModel.activeRouteStops.last?.id {
                                    Divider()
                                        .padding(.leading, 20 + 10 + 12)
                                }
                            }
                        }
                    }
                    .padding(.top, DS.Spacing.sm)
                }
            }
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    // MARK: - Mini Bar

    private var vehicleMiniBar: some View {
        HStack(spacing: 14) {
            // Line badge
            ZStack {
                Circle()
                    .fill(vehicle.type.color)
                    .frame(width: 48, height: 48)

                VStack(spacing: 1) {
                    Image(systemName: vehicle.type.systemImage)
                        .font(.system(size: 13, weight: .bold))
                    Text(vehicle.line)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Line \(vehicle.line)")
                        .font(.body.weight(.semibold))
                    if viewModel.isLoadingRoute {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                Text(vehicle.vehicleNumber)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Favourite button
            Button {
                let fav = FavouriteLine(line: vehicle.line, type: vehicle.type)
                if isFavourite {
                    viewModel.removeFavourite(fav)
                } else {
                    viewModel.addFavourite(fav)
                }
                withAnimation(DS.spring) {
                    starScale = 1.3
                }
                withAnimation(DS.spring.delay(0.15)) {
                    starScale = 1.0
                }
            } label: {
                Image(systemName: isFavourite ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isFavourite ? .yellow : .secondary)
                    .scaleEffect(starScale)
                    .frame(width: DS.Size.minTapTarget, height: DS.Size.minTapTarget)
            }
            .sensoryFeedback(.selection, trigger: isFavourite)
            .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")

            // Close button
            Button {
                withAnimation(DS.springHeavy) {
                    viewModel.deselectVehicle()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.gray, Color(.tertiarySystemFill))
                    .frame(width: DS.Size.minTapTarget, height: DS.Size.minTapTarget)
            }
            .accessibilityLabel("Deselect vehicle")
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Info Row

    private func infoRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)
                Text(value)
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.quaternarySystemFill))
        )
    }
}

// MARK: - Stop Sheet Content

private struct StopSheetContent: View {
    @Bindable var viewModel: MapViewModel
    let stop: Stop

    @State private var lines: [StopLine] = []
    @State private var allArrivals: [StopTime] = []
    @State private var isLoading = true
    @State private var selectedLine: String?

    private var filteredArrivals: [StopTime] {
        guard let selectedLine else { return allArrivals }
        return allArrivals.filter { $0.line == selectedLine }
    }

    private var lineColors: [String: Color] {
        Dictionary(uniqueKeysWithValues: lines.map { ($0.line, $0.displayColor) })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Stop header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stop.name)
                            .font(.title2.bold())
                        Text("Stop schedule")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        withAnimation(DS.springHeavy) {
                            viewModel.deselectStop()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.gray, Color(.tertiarySystemFill))
                            .frame(width: DS.Size.minTapTarget, height: DS.Size.minTapTarget)
                    }
                    .accessibilityLabel("Close schedule")
                }
                .padding(.horizontal, 20)
                .padding(.top, DS.Spacing.lg)

                if isLoading {
                    stopSkeletonContent
                        .padding(.top, DS.Spacing.lg)
                } else {
                    // Line filter pills
                    if !lines.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                Button {
                                    withAnimation(DS.spring) {
                                        selectedLine = nil
                                    }
                                } label: {
                                    Text("All")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selectedLine == nil ? .white : .secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedLine == nil ? Color.blue : Color.blue.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Show all lines")
                                .accessibilityValue(selectedLine == nil ? "selected" : "not selected")

                                ForEach(lines) { line in
                                    let isSelected = selectedLine == line.line
                                    Button {
                                        withAnimation(DS.spring) {
                                            selectedLine = isSelected ? nil : line.line
                                        }
                                    } label: {
                                        Text(line.line)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(isSelected ? .white : line.displayColor)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                isSelected ? line.displayColor : line.displayColor.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 10)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Line \(line.line)")
                                    .accessibilityValue(isSelected ? "selected" : "not selected")
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.lg)
                    }

                    // Arrivals
                    if !filteredArrivals.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack {
                                if let selectedLine {
                                    Text("ARRIVALS FOR \(selectedLine)")
                                        .font(.footnote.weight(.semibold))
                                        .tracking(0.8)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Clear") {
                                        withAnimation(DS.spring) {
                                            self.selectedLine = nil
                                        }
                                    }
                                    .font(.subheadline)
                                } else {
                                    Text("UPCOMING ARRIVALS")
                                        .font(.footnote.weight(.semibold))
                                        .tracking(0.8)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 20)

                            LazyVStack(spacing: 0) {
                                ForEach(filteredArrivals) { arrival in
                                    arrivalRow(arrival)
                                    if arrival.id != filteredArrivals.last?.id {
                                        Divider()
                                            .padding(.leading, 20 + 48 + 14)
                                    }
                                }
                            }
                        }
                    }

                    if lines.isEmpty && allArrivals.isEmpty {
                        ContentUnavailableView(
                            "No Upcoming Arrivals",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("No scheduled arrivals in the next 2 hours for this stop.")
                        )
                        .padding(.top, 60)
                    } else if filteredArrivals.isEmpty && selectedLine != nil {
                        ContentUnavailableView(
                            "No Arrivals for Line \(selectedLine!)",
                            systemImage: "bus",
                            description: Text("No upcoming arrivals for this line. Try selecting a different line.")
                        )
                        .padding(.top, 60)
                    }
                }
            }
            .padding(.bottom, DS.Spacing.xl)
        }
        .task(id: stop.id) {
            isLoading = true
            selectedLine = nil
            await loadData()
        }
    }

    // MARK: - Arrival Row

    private func arrivalRow(_ arrival: StopTime) -> some View {
        HStack(spacing: 14) {
            Text(arrival.line)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 48, height: 36)
                .background(lineColors[arrival.line] ?? .blue, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(arrival.headsign)
                    .font(.body)
                Text(arrival.displayTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let date = arrival.arrivalDate {
                let totalMinutes = Int(date.timeIntervalSinceNow / 60)
                if totalMinutes <= 0 {
                    Text("Now")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.green)
                } else if totalMinutes <= 15 {
                    Text("\(totalMinutes) min")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.blue)
                } else if totalMinutes < 60 {
                    Text("\(totalMinutes) min")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    let h = totalMinutes / 60
                    let m = totalMinutes % 60
                    Text("\(h)h \(m)m")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .accessibilityLabel("Line \(arrival.line) to \(arrival.headsign)")
        .accessibilityValue(arrivalAccessibilityValue(arrival))
    }

    private func arrivalAccessibilityValue(_ arrival: StopTime) -> String {
        guard let date = arrival.arrivalDate else { return arrival.displayTime }
        let totalMinutes = Int(date.timeIntervalSinceNow / 60)
        if totalMinutes <= 0 { return "arriving now" }
        if totalMinutes < 60 { return "in \(totalMinutes) minutes" }
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "in \(h) hour\(h > 1 ? "s" : "") \(m) minutes"
    }

    // MARK: - Skeleton

    private var stopSkeletonContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    ShimmerBlock(width: 48, height: 36)
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            VStack(spacing: 14) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 14) {
                        ShimmerBlock(width: 48, height: 36)
                        VStack(alignment: .leading, spacing: 8) {
                            ShimmerBlock(width: 140, height: 16)
                            ShimmerBlock(width: 60, height: 12)
                        }
                        Spacer()
                        ShimmerBlock(width: 50, height: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        async let fetchedLines: [StopLine] = {
            do { return try await ScheduleService.shared.getStopLines(stopId: stop.id) }
            catch { return [] }
        }()
        async let fetchedSchedule: [StopTime] = {
            do { return try await ScheduleService.shared.getUpcomingArrivals(stopId: stop.id, minutes: 120) }
            catch { return [] }
        }()

        let (linesResult, scheduleResult) = await (fetchedLines, fetchedSchedule)

        var seenLines = Set<String>()
        let uniqueLines = linesResult.filter { seenLines.insert($0.line).inserted }

        var seenTrips = Set<String>()
        let uniqueArrivals = scheduleResult
            .filter { seenTrips.insert($0.tripId).inserted }
            .prefix(30)

        lines = uniqueLines
        allArrivals = Array(uniqueArrivals)
        isLoading = false
    }
}

// MARK: - Previews

#Preview("Default - Collapsed") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            BottomSheetContent(viewModel: MapViewModel())
                .presentationDetents([.height(90), .medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(44)
        }
}

#Preview("Default - Half") {
    let vm = MapViewModel()
    Color.clear
        .sheet(isPresented: .constant(true)) {
            BottomSheetContent(viewModel: vm)
                .presentationDetents([.height(90), .medium, .large], selection: .constant(.medium))
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(44)
        }
}

#Preview("Default - Full") {
    let vm = MapViewModel()
    Color.clear
        .sheet(isPresented: .constant(true)) {
            BottomSheetContent(viewModel: vm)
                .presentationDetents([.height(90), .medium, .large], selection: .constant(.large))
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(44)
        }
}
