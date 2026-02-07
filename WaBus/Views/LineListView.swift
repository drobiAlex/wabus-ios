import SwiftUI

struct LineListView: View {
    @Environment(MapViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
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

    private var busCount: Int {
        viewModel.availableLines.filter { $0.type == .bus }.count
    }

    private var tramCount: Int {
        viewModel.availableLines.filter { $0.type == .tram }.count
    }

    var body: some View {
        NavigationStack {
            List {
                // Type filter pills
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            filterPill(
                                label: "All",
                                count: viewModel.availableLines.count,
                                color: .blue,
                                isSelected: selectedType == nil
                            ) {
                                selectedType = nil
                            }

                            filterPill(
                                label: "Buses",
                                count: busCount,
                                color: VehicleType.bus.color,
                                isSelected: selectedType == .bus,
                                icon: "bus.fill"
                            ) {
                                selectedType = selectedType == .bus ? nil : .bus
                            }

                            filterPill(
                                label: "Trams",
                                count: tramCount,
                                color: VehicleType.tram.color,
                                isSelected: selectedType == .tram,
                                icon: "tram.fill"
                            ) {
                                selectedType = selectedType == .tram ? nil : .tram
                            }
                        }
                        .padding(.vertical, DS.Spacing.xs)
                    }
                } header: {
                    Text("Filter by type")
                }

                // Line rows
                let grouped = groupedLines
                if let buses = grouped[.bus], !buses.isEmpty {
                    Section {
                        ForEach(buses, id: \.self) { line in
                            lineRow(line: line, type: .bus)
                        }
                    } header: {
                        HStack {
                            Text("Buses")
                                .font(DS.captionBold)
                                .tracking(1.0)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(buses.count)")
                                .font(DS.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                if let trams = grouped[.tram], !trams.isEmpty {
                    Section {
                        ForEach(trams, id: \.self) { line in
                            lineRow(line: line, type: .tram)
                        }
                    } header: {
                        HStack {
                            Text("Trams")
                                .font(DS.captionBold)
                                .tracking(1.0)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(trams.count)")
                                .font(DS.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: DS.Spacing.sm, leading: DS.Spacing.md, bottom: DS.Spacing.sm, trailing: DS.Spacing.md))
            .searchable(text: $searchText, prompt: "Search lines")
            .navigationTitle("Lines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.body.bold())
                }
            }
        }
    }

    // MARK: - Filter Pill

    private func filterPill(label: String, count: Int, color: Color, isSelected: Bool, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(DS.spring) {
                action()
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                }
                Text("\(label) (\(count))")
                    .font(DS.smallBold)
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xs)
            .padding(.vertical, 6)
            .background(
                isSelected ? color : color.opacity(0.15),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }

    // MARK: - Line Row

    private func lineRow(line: String, type: VehicleType) -> some View {
        let isSelected = viewModel.selectedLines.contains(line)
        let isFav = viewModel.favouritesStore.isFavourite(line: line, type: type)

        return HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
            Text(line)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: DS.Size.minTapTarget)
                .padding(.vertical, DS.Spacing.xs)
                .background(viewModel.lineColors[line] ?? type.color, in: RoundedRectangle(cornerRadius: 6))
                .minimumScaleFactor(0.6)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.label)
                    .font(.subheadline)
                if isSelected {
                    Text("Selected")
                        .font(DS.small)
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
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isFav ? .yellow : .secondary)
                    .scaleEffect(isFav ? 1.0 : 0.85)
                    .animation(DS.spring, value: isFav)
            }
            .buttonStyle(.plain)
            .frame(minWidth: DS.Size.minTapTarget, minHeight: DS.Size.minTapTarget)
            .accessibilityLabel(isFav ? "Remove \(line) from favourites" : "Add \(line) to favourites")

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? type.color : Color(.systemGray3))
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(DS.spring) {
                viewModel.toggleLine(line)
            }
        }
        .accessibilityLabel("\(type.label) line \(line)")
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityHint("Double tap to toggle selection.")
    }

    // MARK: - Grouped Data

    private var groupedLines: [VehicleType: [String]] {
        var result: [VehicleType: [String]] = [:]
        for item in filteredLines {
            result[item.type, default: []].append(item.line)
        }
        return result
    }
}
