import SwiftUI

struct VehicleDetailSheet: View {
    let vehicle: Vehicle
    @Environment(MapViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: vehicle.type.systemImage)
                    .font(.title2)
                    .foregroundStyle(vehicle.type.color)
                VStack(alignment: .leading) {
                    Text("Line \(vehicle.line)")
                        .font(.title2.bold())
                    Text(vehicle.type.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    let fav = FavouriteLine(line: vehicle.line, type: vehicle.type)
                    if viewModel.favouritesStore.isFavourite(line: vehicle.line, type: vehicle.type) {
                        viewModel.favouritesStore.remove(fav)
                    } else {
                        viewModel.favouritesStore.add(fav)
                    }
                } label: {
                    Image(systemName: viewModel.favouritesStore.isFavourite(line: vehicle.line, type: vehicle.type) ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }
            }

            Divider()

            LabeledContent("Vehicle Number", value: vehicle.vehicleNumber)
            LabeledContent("Brigade", value: vehicle.brigade)
            LabeledContent("Last Update", value: vehicle.updatedAt, format: .relative(presentation: .named))
            LabeledContent("Coordinates", value: String(format: "%.4f, %.4f", vehicle.lat, vehicle.lon))
        }
        .padding()
        .presentationDetents([.height(250)])
    }
}
