import SwiftUI

struct FilterBarView: View {
    @Bindable var viewModel: MapViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Bus toggle
                Toggle(isOn: $viewModel.showBuses) {
                    Label("Bus", systemImage: "bus.fill")
                }
                .toggleStyle(.button)
                .tint(.blue)

                // Tram toggle
                Toggle(isOn: $viewModel.showTrams) {
                    Label("Tram", systemImage: "tram.fill")
                }
                .toggleStyle(.button)
                .tint(.red)

                Divider()
                    .frame(height: 24)

                // Favourite chips
                ForEach(viewModel.favouritesStore.lines) { fav in
                    Button {
                        viewModel.toggleLine(fav.line)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: fav.type.systemImage)
                                .font(.caption2)
                            Text(fav.line)
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(viewModel.selectedLines.contains(fav.line) ? fav.type.color : fav.type.color.opacity(0.2))
                        .foregroundStyle(viewModel.selectedLines.contains(fav.line) ? .white : fav.type.color)
                        .clipShape(Capsule())
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.favouritesStore.remove(fav)
                            viewModel.selectedLines.remove(fav.line)
                        } label: {
                            Label("Remove from Favourites", systemImage: "star.slash")
                        }
                    }
                }

                // Add line button
                Button {
                    viewModel.showLineList = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
