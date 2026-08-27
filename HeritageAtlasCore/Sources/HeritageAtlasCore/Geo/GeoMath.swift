import Foundation

public struct GeoPoint: Hashable, Sendable, Codable, Equatable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
    }
}

public enum GeoMath: Sendable {
    public static let earthRadiusMeters = 6_371_000.0

    public static func distanceMeters(from: GeoPoint, to: GeoPoint) -> Double {
        distanceMeters(
            fromLatitude: from.latitude,
            fromLongitude: from.longitude,
            toLatitude: to.latitude,
            toLongitude: to.longitude
        )
    }

    public static func distanceMeters(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double
    ) -> Double {
        let phi1 = fromLatitude * .pi / 180
        let phi2 = toLatitude * .pi / 180
        let deltaPhi = (toLatitude - fromLatitude) * .pi / 180
        let deltaLambda = (toLongitude - fromLongitude) * .pi / 180
        let a = sin(deltaPhi / 2) * sin(deltaPhi / 2)
            + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        let c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
        return earthRadiusMeters * c
    }

    /// Initial bearing in degrees clockwise from true north, in `0..<360`.
    public static func bearingDegrees(from: GeoPoint, to: GeoPoint) -> Double {
        bearingDegrees(
            fromLatitude: from.latitude,
            fromLongitude: from.longitude,
            toLatitude: to.latitude,
            toLongitude: to.longitude
        )
    }

    public static func bearingDegrees(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double
    ) -> Double {
        let phi1 = fromLatitude * .pi / 180
        let phi2 = toLatitude * .pi / 180
        let deltaLambda = (toLongitude - fromLongitude) * .pi / 180
        let y = sin(deltaLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda)
        let radians = atan2(y, x)
        var degrees = radians * 180 / .pi
        degrees = degrees.truncatingRemainder(dividingBy: 360)
        if degrees < 0 { degrees += 360 }
        return degrees
    }

    /// Signed turn from device heading to target bearing, in `-180...180`.
    /// Zero means the target is ahead of the watch face (12 o'clock).
    public static func relativeBearingDegrees(targetBearing: Double, deviceHeading: Double) -> Double {
        var delta = targetBearing - deviceHeading
        delta = delta.truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta <= -180 { delta += 360 }
        return delta
    }

    public static func formatDistanceMeters(_ meters: Double) -> String {
        if meters.isNaN || meters.isInfinite { return "—" }
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        let km = meters / 1000
        if km < 10 {
            return String(format: "%.1f km", km)
        }
        return "\(Int(km.rounded())) km"
    }

    /// Returns a padded bounding box suitable for a map camera. Single points get a minimum span.
    public static func boundingBox(
        points: [GeoPoint],
        paddingFactor: Double = 1.35,
        minimumSpan: Double = 0.02
    ) -> (center: GeoPoint, latitudeDelta: Double, longitudeDelta: Double)? {
        guard let first = points.first else { return nil }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for point in points.dropFirst() {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        let center = GeoPoint(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let latDelta = max((maxLat - minLat) * paddingFactor, minimumSpan)
        let lonDelta = max((maxLon - minLon) * paddingFactor, minimumSpan)
        return (center, latDelta, lonDelta)
    }
}

extension WatchPlace {
    public var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    public var geoPoint: GeoPoint? {
        guard let latitude, let longitude else { return nil }
        return GeoPoint(latitude: latitude, longitude: longitude)
    }
}
