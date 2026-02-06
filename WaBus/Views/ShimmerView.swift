import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
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

struct ShimmerBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .modifier(ShimmerModifier())
    }
}

struct ScheduleSkeletonView: View {
    var body: some View {
        List {
            Section("Lines at this stop") {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in
                        ShimmerBlock(width: 44, height: 32)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Upcoming Arrivals") {
                ForEach(0..<6, id: \.self) { _ in
                    HStack {
                        ShimmerBlock(width: 44, height: 28)
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
