import SwiftUI

struct StopAnnotationView: View {
    let stop: Stop

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .strokeBorder(Color.secondary, lineWidth: 1.5)
            )
            .frame(minWidth: 24, minHeight: 24)
    }
}
