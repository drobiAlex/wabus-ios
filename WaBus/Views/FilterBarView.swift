import SwiftUI

struct FilterBarView: View {
    @Bindable var viewModel: MapViewModel
    var dimmed: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
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
                        .frame(height: 28)
                        .overlay(Color.white.opacity(0.3))
                }

                ForEach(viewModel.favouritesStore.lines) { fav in
                    let isSelected = viewModel.selectedLines.contains(fav.line)
                    favouritePill(fav: fav, isSelected: isSelected)
                }

                if viewModel.favouritesStore.lines.isEmpty {
                    Text("Tap + to add lines")
                        .font(DS.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.sm)
                }

                // Lines button
                Button {
                    viewModel.showLineList = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Lines")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.primary)
                    .frame(width: DS.Size.minTapTarget, height: DS.Size.minTapTarget)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .sensoryFeedback(.selection, trigger: viewModel.showLineList)
                .accessibilityLabel("Browse all lines")
                .accessibilityHint("Opens line list.")
            }
            .padding(.horizontal, DS.Spacing.md)
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, DS.Spacing.md)
        .opacity(dimmed ? 0.5 : 1.0)
        .animation(DS.spring, value: dimmed)
    }

    // MARK: - Type Pill

    private func typePill(type: VehicleType, isActive: Bool, count: Int, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(DS.spring) {
                action()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: type.systemImage)
                    .font(DS.smallBold)
                Text("\(count)")
                    .font(DS.smallBold)
            }
            .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.sm)
            .frame(minWidth: 60)
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
        .accessibilityHint("Double tap to toggle \(type.label.lowercased()) filter.")
        .accessibilityValue(isActive ? "active" : "inactive")
    }

    // MARK: - Favourite Pill

    private func favouritePill(fav: FavouriteLine, isSelected: Bool) -> some View {
        Button {
            withAnimation(DS.spring) {
                viewModel.toggleLine(fav.line)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: fav.type.systemImage)
                    .font(DS.smallBold)
                Text(fav.line)
                    .font(DS.smallBold)
            }
            .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.sm)
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
        .accessibilityHint("Long press to remove from favourites.")
    }
}
