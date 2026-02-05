import SwiftUI

struct FilterBarView: View {
    @Bindable var viewModel: MapViewModel

    var body: some View {
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
                        .overlay(Color.white.opacity(0.15))
                }

                ForEach(viewModel.favouritesStore.lines) { fav in
                    let isSelected = viewModel.selectedLines.contains(fav.line)
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            viewModel.toggleLine(fav.line)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: fav.type.systemImage)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Text(fav.line)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
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
                }

                Button {
                    viewModel.showLineList = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .sensoryFeedback(.selection, trigger: viewModel.showLineList)
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    private func typePill(type: VehicleType, isActive: Bool, count: Int, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                action()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
        .sensoryFeedback(.selection, trigger: isActive)
    }
}
