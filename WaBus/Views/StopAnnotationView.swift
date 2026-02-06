import SwiftUI

struct StopAnnotationView: View {
    let stop: Stop

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)

            Circle()
                .strokeBorder(Color.blue, lineWidth: 2.5)
                .frame(width: 22, height: 22)

            Image(systemName: "bus.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.blue)
        }
        .frame(minWidth: 32, minHeight: 32)
    }
}
