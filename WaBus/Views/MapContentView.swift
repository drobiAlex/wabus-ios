import MapKit
import SwiftUI

struct MapContentView: View {
    @Bindable var viewModel: MapViewModel

    var body: some View {
        Map(position: $viewModel.cameraPosition) {
            ForEach(viewModel.filteredVehicles, id: \.key) { vehicle in
                Annotation(vehicle.line, coordinate: vehicle.coordinate) {
                    VehicleAnnotationView(vehicle: vehicle, heading: viewModel.headings[vehicle.key])
                        .onTapGesture {
                            viewModel.selectedVehicle = vehicle
                        }
                }
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            viewModel.onMapRegionChanged(context.region)
        }
    }
}
