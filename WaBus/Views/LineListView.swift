import SwiftUI

struct LineListView: View {
    @Environment(MapViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                let grouped = groupedLines
                if let buses = grouped[.bus], !buses.isEmpty {
                    Section {
                        ForEach(buses, id: \.self) { line in
                            lineRow(line: line, type: .bus)
                        }
                    } header: {
                        Text("Buses")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .tracking(1.0)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                    }
                }
                if let trams = grouped[.tram], !trams.isEmpty {
                    Section {
                        ForEach(trams, id: \.self) { line in
                            lineRow(line: line, type: .tram)
                        }
                    } header: {
                        Text("Trams")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .tracking(1.0)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .searchable(text: $searchText, prompt: "Search lines")
            .navigationTitle("Lines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.body.bold())
                }
            }
        }
    }

    private func lineRow(line: String, type: VehicleType) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(type.color)
                    .frame(width: 38, height: 38)
                Text(line)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
            }

            Text(type.label)
                .font(.system(size: 16, weight: .medium, design: .rounded))

            Spacer()

            Button {
                let fav = FavouriteLine(line: line, type: type)
                if viewModel.favouritesStore.isFavourite(line: line, type: type) {
                    viewModel.removeFavourite(fav)
                } else {
                    viewModel.addFavourite(fav)
                }
            } label: {
                Image(systemName: viewModel.favouritesStore.isFavourite(line: line, type: type) ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.yellow)
                    .scaleEffect(viewModel.favouritesStore.isFavourite(line: line, type: type) ? 1.0 : 0.85)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: viewModel.favouritesStore.isFavourite(line: line, type: type))
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleLine(line)
            dismiss()
        }
    }

    private var groupedLines: [VehicleType: [String]] {
        let all = viewModel.availableLines
        let filtered: [(line: String, type: VehicleType)]
        if searchText.isEmpty {
            filtered = all
        } else {
            filtered = all.filter { $0.line.localizedCaseInsensitiveContains(searchText) }
        }
        var result: [VehicleType: [String]] = [:]
        for item in filtered {
            result[item.type, default: []].append(item.line)
        }
        return result
    }
}
