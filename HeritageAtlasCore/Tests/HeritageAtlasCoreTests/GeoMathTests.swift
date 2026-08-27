import Foundation
import Testing
@testable import HeritageAtlasCore

@Suite("Geo math")
struct GeoMathTests {
    @Test func northAndEastBearings() {
        let north = GeoMath.bearingDegrees(
            fromLatitude: 10,
            fromLongitude: 0,
            toLatitude: 11,
            toLongitude: 0
        )
        #expect(abs(north - 0) < 1)

        let east = GeoMath.bearingDegrees(
            fromLatitude: 0,
            fromLongitude: 0,
            toLatitude: 0,
            toLongitude: 1
        )
        #expect(abs(east - 90) < 1)
    }

    @Test func hanoiToHueDistanceIsHundredsOfKilometers() {
        let hanoi = GeoPoint(latitude: 21.0285, longitude: 105.8542)
        let hue = GeoPoint(latitude: 16.4637, longitude: 107.5909)
        let meters = GeoMath.distanceMeters(from: hanoi, to: hue)
        #expect(meters > 500_000 && meters < 700_000)
    }

    @Test func relativeBearingPutsTargetAheadAtZero() {
        let delta = GeoMath.relativeBearingDegrees(targetBearing: 90, deviceHeading: 90)
        #expect(abs(delta) < 0.01)

        let right = GeoMath.relativeBearingDegrees(targetBearing: 90, deviceHeading: 0)
        #expect(abs(right - 90) < 0.01)

        let wrap = GeoMath.relativeBearingDegrees(targetBearing: 10, deviceHeading: 350)
        #expect(abs(wrap - 20) < 0.01)
    }

    @Test func formatDistance() {
        #expect(GeoMath.formatDistanceMeters(12) == "12 m")
        #expect(GeoMath.formatDistanceMeters(1500) == "1.5 km")
        #expect(GeoMath.formatDistanceMeters(12_400) == "12 km")
    }
}

@Suite("Map clustering")
struct MapClustererTests {
    @Test func nearbyPinsMergeWhenZoomedOut() {
        let hanoiHome = UUID()
        let hanoiSchool = UUID()
        let hueHome = UUID()
        let clusters = MapClusterer.cluster(
            idsAndCoordinates: [
                (hanoiHome, GeoPoint(latitude: 21.0285, longitude: 105.8542)),
                (hanoiSchool, GeoPoint(latitude: 21.0278, longitude: 105.8320)),
                (hueHome, GeoPoint(latitude: 16.4637, longitude: 107.5909)),
            ],
            cellDegrees: MapClusterer.cellDegrees(forLatitudeSpan: 8)
        )
        #expect(clusters.count == 2)
        let counts = Set(clusters.map(\.count))
        #expect(counts.contains(2))
        #expect(counts.contains(1))
    }

    @Test func zoomedInCellsKeepPinsSeparate() {
        let a = UUID()
        let b = UUID()
        let clusters = MapClusterer.cluster(
            idsAndCoordinates: [
                (a, GeoPoint(latitude: 21.0285, longitude: 105.8542)),
                (b, GeoPoint(latitude: 21.0278, longitude: 105.8320)),
            ],
            cellDegrees: MapClusterer.cellDegrees(forLatitudeSpan: 0.002)
        )
        #expect(clusters.count == 2)
        #expect(clusters.allSatisfy { $0.isCluster == false })
    }
}

@Suite("Approach haptics")
struct ApproachHapticTrackerTests {
    @Test func firesOncePerCloserBandAndResetsWhenLeaving() {
        let place = UUID()
        var tracker = ApproachHapticTracker()

        let far = tracker.events(for: [place: 400])
        #expect(far.isEmpty)

        let approaching = tracker.events(for: [place: 120])
        #expect(approaching.map(\.band) == [.approaching])

        let stillApproaching = tracker.events(for: [place: 90])
        #expect(stillApproaching.isEmpty)

        let arrived = tracker.events(for: [place: 10])
        #expect(arrived.map(\.band) == [.arrived])

        _ = tracker.events(for: [place: 400])
        let again = tracker.events(for: [place: 40])
        #expect(again.map(\.band) == [.near])
    }
}
