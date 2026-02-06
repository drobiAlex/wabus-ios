import SwiftUI

struct VehicleRouteBar: View {
    let vehicle: Vehicle
    @Environment(MapViewModel.self) private var viewModel
    @State private var starScale: CGFloat = 1.0

    private var isFavourite: Bool {
        viewModel.favouritesStore.isFavourite(line: vehicle.line, type: vehicle.type)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Line badge
            ZStack {
                Circle()
                    .fill(vehicle.type.color)
                    .frame(width: 44, height: 44)

                VStack(spacing: 1) {
                    Image(systemName: vehicle.type.systemImage)
                        .font(.system(size: 12, weight: .bold))
                    Text(vehicle.line)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
            }

            // Vehicle info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Line \(vehicle.line)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    if viewModel.isLoadingRoute {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                Text(vehicle.vehicleNumber)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    starScale = 1.3
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.15)) {
                    starScale = 1.0
                }
            } label: {
                Image(systemName: isFavourite ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isFavourite ? .yellow : .secondary)
                    .scaleEffect(starScale)
                    .frame(width: 36, height: 36)
            }
            .sensoryFeedback(.selection, trigger: isFavourite)

            // More info button
            Button {
                viewModel.showVehicleDetail = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }

            // Close button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.deselectVehicle()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
}
