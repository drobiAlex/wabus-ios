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
                    Section("Buses") {
                        ForEach(buses, id: \.self) { line in
                            lineRow(line: line, type: .bus)
                        }
                    }
                }
                if let trams = grouped[.tram], !trams.isEmpty {
                    Section("Trams") {
                        ForEach(trams, id: \.self) { line in
                            lineRow(line: line, type: .tram)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search lines")
            .navigationTitle("Lines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func lineRow(line: String, type: VehicleType) -> some View {
        HStack {
            Image(systemName: type.systemImage)
                .foregroundStyle(type.color)
            Text(line)
                .font(.body.bold())
            Spacer()
            Button {
                let fav = FavouriteLine(line: line, type: type)
                if viewModel.favouritesStore.isFavourite(line: line, type: type) {
                    viewModel.favouritesStore.remove(fav)
                } else {
                    viewModel.favouritesStore.add(fav)
                }
            } label: {
                Image(systemName: viewModel.favouritesStore.isFavourite(line: line, type: type) ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
            }
            .buttonStyle(.plain)
        }
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
