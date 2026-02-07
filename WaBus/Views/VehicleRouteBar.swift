import SwiftUI

struct VehicleRouteBar: View {
    let vehicle: Vehicle
    @Environment(MapViewModel.self) private var viewModel
    @State private var starScale: CGFloat = 1.0

    private var isFavourite: Bool {
        viewModel.favouritesStore.isFavourite(line: vehicle.line, type: vehicle.type)
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
            // Line badge
            ZStack {
                Circle()
                    .fill(vehicle.type.color)
                    .frame(width: DS.Size.annotationBadge, height: DS.Size.annotationBadge)

                VStack(spacing: 1) {
                    Image(systemName: vehicle.type.systemImage)
                        .font(.system(size: 12, weight: .bold))
                    Text(vehicle.line)
                        .font(DS.smallBold)
                }
                .foregroundStyle(.white)
            }

            // Vehicle info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Line \(vehicle.line)")
                        .font(DS.bodyBold)
                    if viewModel.isLoadingRoute {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                Text(vehicle.vehicleNumber)
                    .font(DS.caption)
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isFavourite ? .yellow : .secondary)
                    .scaleEffect(starScale)
                    .frame(width: DS.Size.minTapTarget, height: DS.Size.minTapTarget)
            }
            .sensoryFeedback(.selection, trigger: isFavourite)
            .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")

            // More info button
            Button {
                viewModel.showVehicleDetail = true
            } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: DS.Size.minTapTarget, height: DS.Size.minTapTarget)
            }
            .accessibilityLabel("Vehicle details")
            .accessibilityHint("Opens detail sheet.")

            // Close button
            Button {
                withAnimation(DS.springHeavy) {
                    viewModel.deselectVehicle()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(DS.display)
                    .foregroundStyle(.secondary)
                    .frame(width: DS.Size.minTapTarget, height: DS.Size.minTapTarget)
            }
            .accessibilityLabel("Deselect vehicle")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(.thickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .strokeBorder(vehicle.type.color.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .padding(.horizontal, DS.Spacing.md)
    }
}
