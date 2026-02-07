import SwiftUI

struct ConnectionStatusView: View {
    let state: ConnectionState
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: state == .connected ? 12 : 8, height: state == .connected ? 12 : 8)
                .opacity(state == .connecting ? (pulsing ? 0.3 : 1.0) : 1.0)
                .animation(
                    state == .connecting
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: pulsing
                )

            if state == .connected {
                Text("Live")
                    .font(DS.captionBold)
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            if state == .disconnected {
                Text("Reconnecting...")
                    .font(DS.captionBold)
                    .foregroundStyle(.white)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .padding(.horizontal, state == .connected ? DS.Spacing.sm + DS.Spacing.xs : (state == .disconnected ? DS.Spacing.sm + DS.Spacing.xs : 6))
        .padding(.vertical, 6)
        .background {
            if state == .disconnected {
                Capsule().fill(Color.orange.opacity(0.85))
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .clipShape(Capsule())
        .animation(DS.springHeavy, value: state)
        .frame(minWidth: DS.Size.minTapTarget, minHeight: DS.Size.minTapTarget)
        .onAppear { pulsing = true }
        .accessibilityLabel("Connection status")
        .accessibilityValue(accessibilityStateValue)
    }

    private var dotColor: Color {
        switch state {
        case .connected: .green
        case .connecting: .yellow
        case .disconnected: .white
        }
    }

    private var accessibilityStateValue: String {
        switch state {
        case .connected: "connected"
        case .connecting: "connecting"
        case .disconnected: "reconnecting"
        }
    }
}
