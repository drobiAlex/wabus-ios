import SwiftUI

struct VehicleAnnotationView: View {
    let vehicle: Vehicle
    var heading: Double?
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let heading {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(heading - 90))
            }

            Image(systemName: vehicle.type.systemImage)
                .font(.system(size: 13, weight: .heavy, design: .rounded))

            Text(vehicle.line)
                .font(DS.bodyBold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(vehicle.type.color)
        .clipShape(Capsule())
        .overlay {
            if isSelected {
                Capsule()
                    .strokeBorder(.white, lineWidth: 2.5)
            }
        }
        .shadow(color: isSelected ? vehicle.type.color.opacity(0.6) : .black.opacity(0.15), radius: isSelected ? 8 : 2, y: isSelected ? 0 : 1)
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(DS.spring, value: isSelected)
        .frame(minWidth: DS.Size.minTapTarget, minHeight: DS.Size.minTapTarget)
        .contentShape(Rectangle())
        .accessibilityLabel("\(vehicle.type.label) line \(vehicle.line)")
        .accessibilityHint(isSelected ? "Selected. Double tap for details." : "Double tap to select.")
    }
}
