import SwiftUI
import UIKit

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    private let reduceMotion = UIAccessibility.isReduceMotionEnabled

    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .opacity(0.6)
        } else {
            content
                .overlay(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.4), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: phase * 200)
                    .mask(content)
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

struct ShimmerBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: DS.Spacing.xs)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .modifier(ShimmerModifier())
    }
}

struct ScheduleSkeletonView: View {
    var body: some View {
        List {
            Section("Lines at this stop") {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(0..<4, id: \.self) { _ in
                        ShimmerBlock(width: DS.Size.minTapTarget, height: DS.Spacing.xl)
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            }

            Section("Upcoming Arrivals") {
                ForEach(0..<6, id: \.self) { _ in
                    HStack {
                        ShimmerBlock(width: DS.Size.minTapTarget, height: 28)
                        VStack(alignment: .leading, spacing: 6) {
                            ShimmerBlock(width: 140, height: 14)
                            ShimmerBlock(width: 60, height: 10)
                        }
                        Spacer()
                        ShimmerBlock(width: 50, height: 18)
                    }
                }
            }
        }
    }
}
