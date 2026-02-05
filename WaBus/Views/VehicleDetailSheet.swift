import SwiftUI

struct VehicleDetailSheet: View {
    let vehicle: Vehicle
    @Environment(MapViewModel.self) private var viewModel
    @State private var starScale: CGFloat = 1.0

    private var isFavourite: Bool {
        viewModel.favouritesStore.isFavourite(line: vehicle.line, type: vehicle.type)
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(vehicle.type.color)
                        .frame(width: 72, height: 72)

                    VStack(spacing: 2) {
                        Image(systemName: vehicle.type.systemImage)
                            .font(.system(size: 20, weight: .bold))
                        Text(vehicle.line)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                }

                Text(vehicle.type.label)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                infoCard(title: "Vehicle", value: vehicle.vehicleNumber)
                infoCard(title: "Brigade", value: vehicle.brigade)
                infoCard(title: "Updated", value: vehicle.updatedAt.formatted(.relative(presentation: .named)))
                infoCard(title: "Coordinates", value: String(format: "%.4f, %.4f", vehicle.lat, vehicle.lon))
            }

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
                HStack(spacing: 8) {
                    Image(systemName: isFavourite ? "star.fill" : "star")
                        .scaleEffect(starScale)
                    Text(isFavourite ? "Favourited" : "Add to Favourites")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(isFavourite ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    if isFavourite {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(vehicle.type.color)
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.quaternarySystemFill))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(vehicle.type.color.opacity(0.4), lineWidth: 1.5)
                            )
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: isFavourite)
        }
        .padding(20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func infoCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.quaternarySystemFill))
        )
    }
}
