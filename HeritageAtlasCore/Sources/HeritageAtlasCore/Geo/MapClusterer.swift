import Foundation

public struct CoordinateCluster: Identifiable, Hashable, Sendable, Equatable {
    public var id: String
    public var coordinate: GeoPoint
    public var memberIDs: [UUID]

    public init(id: String, coordinate: GeoPoint, memberIDs: [UUID]) {
        self.id = id
        self.coordinate = coordinate
        self.memberIDs = memberIDs
    }

    public var count: Int { memberIDs.count }
    public var isCluster: Bool { memberIDs.count > 1 }
}

public enum MapClusterer: Sendable {
    /// Grid clustering. `cellDegrees` is the latitude height of a bucket; longitude is scaled by `cos(latitude)`.
    /// Zoom the map in (smaller span → smaller cell) to split clusters into individual pins.
    public static func cluster(
        idsAndCoordinates: [(id: UUID, point: GeoPoint)],
        cellDegrees: Double
    ) -> [CoordinateCluster] {
        let cell = max(cellDegrees, 0.00004)
        var buckets: [BucketKey: [UUID]] = [:]
        var pointsByID: [UUID: GeoPoint] = [:]

        for item in idsAndCoordinates {
            pointsByID[item.id] = item.point
            let key = BucketKey(point: item.point, cellDegrees: cell)
            buckets[key, default: []].append(item.id)
        }

        return buckets.keys.sorted { lhs, rhs in
            if lhs.latIndex != rhs.latIndex { return lhs.latIndex < rhs.latIndex }
            return lhs.lonIndex < rhs.lonIndex
        }.compactMap { key in
            guard let ids = buckets[key], !ids.isEmpty else { return nil }
            let points = ids.compactMap { pointsByID[$0] }
            guard !points.isEmpty else { return nil }
            let center = GeoPoint(
                latitude: points.map(\.latitude).reduce(0, +) / Double(points.count),
                longitude: points.map(\.longitude).reduce(0, +) / Double(points.count)
            )
            let id = ids.count == 1
                ? ids[0].uuidString
                : "cluster-\(key.latIndex)-\(key.lonIndex)-\(ids.count)"
            return CoordinateCluster(id: id, coordinate: center, memberIDs: ids)
        }
    }

    /// Convert a visible map latitude span into a cell size. About 10 cells fit vertically.
    public static func cellDegrees(forLatitudeSpan span: Double, divisions: Double = 10) -> Double {
        let safeSpan = span.isFinite && span > 0 ? span : 0.2
        return max(safeSpan / max(divisions, 1), 0.00004)
    }
}

private struct BucketKey: Hashable {
    var latIndex: Int
    var lonIndex: Int

    init(point: GeoPoint, cellDegrees: Double) {
        latIndex = Int(floor(point.latitude / cellDegrees))
        let cosLat = max(cos(point.latitude * .pi / 180), 0.2)
        lonIndex = Int(floor(point.longitude / (cellDegrees / cosLat)))
    }
}
