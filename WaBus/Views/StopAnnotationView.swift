import SwiftUI

struct StopAnnotationView: View {
    let stop: Stop

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)

            Circle()
                .strokeBorder(Color.blue, lineWidth: 2.5)
                .frame(width: 24, height: 24)

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.blue)
        }
        .frame(minWidth: DS.Size.minTapTarget, minHeight: DS.Size.minTapTarget)
        .contentShape(Rectangle())
        .accessibilityLabel("Stop: \(stop.name)")
        .accessibilityHint("Double tap to view schedule.")
    }
}
