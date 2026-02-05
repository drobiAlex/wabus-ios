import SwiftUI

struct ConnectionStatusView: View {
    let state: ConnectionState
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .opacity(state == .connecting ? (pulsing ? 0.3 : 1.0) : 1.0)
                .animation(
                    state == .connecting
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: pulsing
                )

            if state == .disconnected {
                Text("Reconnecting...")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .padding(.horizontal, state == .disconnected ? 12 : 6)
        .padding(.vertical, state == .disconnected ? 6 : 6)
        .background {
            if state == .disconnected {
                Capsule().fill(Color.red.opacity(0.85))
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .clipShape(Capsule())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state)
        .onAppear { pulsing = true }
    }

    private var dotColor: Color {
        switch state {
        case .connected: .green
        case .connecting: .yellow
        case .disconnected: .white
        }
    }
}
