import SwiftUI

struct ClusterAnnotationView: View {
    let cluster: VehicleCluster

    var body: some View {
        ZStack {
            Circle()
                .fill(cluster.type.color)
                .frame(width: 40, height: 40)
            Text(cluster.count > 99 ? "99+" : "\(cluster.count)")
                .font(DS.smallBold)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
        }
        .frame(minWidth: DS.Size.minTapTarget, minHeight: DS.Size.minTapTarget)
        .contentShape(Circle())
        .accessibilityLabel("\(cluster.count) vehicles clustered")
        .accessibilityHint("Double tap to zoom in.")
    }
}
