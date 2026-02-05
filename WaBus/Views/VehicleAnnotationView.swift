import SwiftUI

struct VehicleAnnotationView: View {
    let vehicle: Vehicle
    var heading: Double?

    var body: some View {
        HStack(spacing: 5) {
            if let heading {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .rotationEffect(.degrees(heading - 90))
            }

            Image(systemName: vehicle.type.systemImage)
                .font(.system(size: 13, weight: .heavy, design: .rounded))

            Text(vehicle.line)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(vehicle.type.color)
        .clipShape(Capsule())
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
}
