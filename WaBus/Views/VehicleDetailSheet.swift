import SwiftUI

struct VehicleDetailSheet: View {
    let vehicle: Vehicle
    @Environment(MapViewModel.self) private var viewModel
    @State private var starScale: CGFloat = 1.0

    private var isFavourite: Bool {
        viewModel.favouritesStore.isFavourite(line: vehicle.line, type: vehicle.type)
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Header badge
            VStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(vehicle.type.color)
                        .frame(width: DS.Size.detailBadge, height: DS.Size.detailBadge)

                    VStack(spacing: 2) {
                        Image(systemName: vehicle.type.systemImage)
                            .font(.system(size: 20, weight: .bold))
                        Text(vehicle.line)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                }

                Text(vehicle.type.label)
                    .font(DS.small)
                    .foregroundStyle(.secondary)
            }

            // Key info
            VStack(spacing: DS.Spacing.sm) {
                infoRow(title: "Vehicle", value: vehicle.vehicleNumber, icon: "number")
                infoRow(title: "Updated", value: vehicle.updatedAt.formatted(.relative(presentation: .named)), icon: "clock")
            }

            // Favourite button — icon-only star, consistent with route bar
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
                        .font(DS.bodyBold)
                }
                .foregroundStyle(isFavourite ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
                .background {
                    if isFavourite {
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(vehicle.type.color)
                    } else {
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color(.quaternarySystemFill))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .strokeBorder(vehicle.type.color.opacity(0.4), lineWidth: 1.5)
                            )
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: isFavourite)
            .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")
        }
        .padding(DS.Spacing.lg)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }

    private func infoRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(DS.captionBold)
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)
                Text(value)
                    .font(DS.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(DS.Spacing.sm + DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(Color(.quaternarySystemFill))
        )
    }
}
