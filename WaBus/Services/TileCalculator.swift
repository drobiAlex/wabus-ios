import MapKit
import Foundation

enum TileCalculator {
    static let zoom = 14

    static func tileId(for coordinate: CLLocationCoordinate2D) -> String {
        let n = pow(2.0, Double(zoom))
        let x = Int(floor((coordinate.longitude + 180.0) / 360.0 * n))
        let latRad = coordinate.latitude * .pi / 180.0
        let y = Int(floor((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0 * n))
        return "\(zoom)/\(x)/\(y)"
    }

    static func visibleTileIds(for region: MKCoordinateRegion) -> Set<String> {
        let center = region.center
        let span = region.span

        let minLat = center.latitude - span.latitudeDelta / 2.0
        let maxLat = center.latitude + span.latitudeDelta / 2.0
        let minLon = center.longitude - span.longitudeDelta / 2.0
        let maxLon = center.longitude + span.longitudeDelta / 2.0

        let n = pow(2.0, Double(zoom))

        let xMin = Int(floor((minLon + 180.0) / 360.0 * n))
        let xMax = Int(floor((maxLon + 180.0) / 360.0 * n))

        let latRadMin = max(minLat, -85.0511) * .pi / 180.0
        let latRadMax = min(maxLat, 85.0511) * .pi / 180.0

        let yMax = Int(floor((1.0 - log(tan(latRadMin) + 1.0 / cos(latRadMin)) / .pi) / 2.0 * n))
        let yMin = Int(floor((1.0 - log(tan(latRadMax) + 1.0 / cos(latRadMax)) / .pi) / 2.0 * n))

        let maxTiles = 100
        let tileCount = (xMax - xMin + 1) * (yMax - yMin + 1)
        guard tileCount > 0, tileCount <= maxTiles else {
            // If too many tiles, just use center tile and neighbors
            let centerTile = tileId(for: center)
            return [centerTile]
        }

        var tiles = Set<String>()
        for x in xMin...xMax {
            for y in yMin...yMax {
                tiles.insert("\(zoom)/\(x)/\(y)")
            }
        }
        return tiles
    }
}
