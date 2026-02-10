import SwiftUI

struct StopAnnotationView: View {
    let stop: Stop
    var color: Color = .blue
    var isSelected: Bool = false

    private var dotSize: CGFloat {
        isSelected ? DS.Size.stopDotSelected : DS.Size.stopDot
    }

    private var borderWidth: CGFloat {
        isSelected ? 3 : 2
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: dotSize, height: dotSize)
            .overlay(
                Circle()
                    .strokeBorder(.white, lineWidth: borderWidth)
            )
            .shadow(color: .black.opacity(0.3), radius: 3, y: 0)
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .animation(DS.spring, value: isSelected)
            .frame(minWidth: DS.Size.minTapTarget, minHeight: DS.Size.minTapTarget)
            .contentShape(Rectangle())
            .accessibilityLabel("Stop: \(stop.name)")
            .accessibilityHint("Double tap to view schedule.")
    }
}
