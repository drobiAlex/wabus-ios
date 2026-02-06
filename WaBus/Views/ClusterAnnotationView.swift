import SwiftUI

struct ClusterAnnotationView: View {
    let cluster: VehicleCluster

    var body: some View {
        ZStack {
            Circle()
                .fill(cluster.type.color.opacity(0.85))
                .frame(width: 40, height: 40)
            Text("\(cluster.count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Circle())
    }
}
