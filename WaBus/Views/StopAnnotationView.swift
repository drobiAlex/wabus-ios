import SwiftUI

struct StopAnnotationView: View {
    let stop: Stop
    var color: Color = .blue

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .frame(minWidth: DS.Size.minTapTarget, minHeight: DS.Size.minTapTarget)
            .contentShape(Rectangle())
            .accessibilityLabel("Stop: \(stop.name)")
            .accessibilityHint("Double tap to view schedule.")
    }
}
