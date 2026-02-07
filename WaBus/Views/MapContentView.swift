import MapKit
import SwiftUI

struct MapContentView: View {
    @Bindable var viewModel: MapViewModel

    var body: some View {
        Map(position: $viewModel.cameraPosition) {
            ForEach(viewModel.activeRoutePolylines) { polyline in
                MapPolyline(coordinates: polyline.coordinates)
                    .stroke(polyline.color.opacity(0.8), lineWidth: 4)
            }

            ForEach(viewModel.activeRouteStops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    StopAnnotationView(stop: stop)
                        .onTapGesture {
                            viewModel.selectedStop = stop
                        }
                }
            }

            ForEach(viewModel.vehicleClusters) { cluster in
                Annotation("\(cluster.count)", coordinate: cluster.coordinate) {
                    ClusterAnnotationView(cluster: cluster)
                        .onTapGesture {
                            viewModel.zoomToCluster(cluster)
                        }
                }
            }

            ForEach(viewModel.singleVehicles, id: \.key) { vehicle in
                Annotation(vehicle.line, coordinate: vehicle.coordinate) {
                    VehicleAnnotationView(
                        vehicle: vehicle,
                        heading: viewModel.headings[vehicle.key],
                        isSelected: viewModel.selectedVehicle?.key == vehicle.key
                    )
                    .onTapGesture {
                        viewModel.selectVehicle(vehicle)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onMapCameraChange(frequency: .onEnd) { context in
            viewModel.onMapRegionChanged(context.region)
        }
    }
}
