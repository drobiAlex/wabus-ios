import SwiftUI

struct VehicleAnnotationView: View {
    let vehicle: Vehicle
    var heading: Double?

    var body: some View {
        VStack(spacing: 0) {
            // Direction arrow (only when heading is known)
            if let heading {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(vehicle.type.color)
                    .rotationEffect(.degrees(heading))
            }

            HStack(spacing: 4) {
                Image(systemName: vehicle.type.systemImage)
                    .font(.system(size: 10))
                Text(vehicle.line)
                    .font(.system(size: 12, weight: .bold))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(vehicle.type.color)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
    }
}
