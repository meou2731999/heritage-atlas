import Foundation

/// Distance bands used to fire a haptic once as the wearer walks toward a place.
public enum ApproachBand: Int, Sendable, Comparable, Equatable {
    case approaching = 0
    case near = 1
    case arrived = 2

    public var radiusMeters: Double {
        switch self {
        case .approaching: 150
        case .near: 50
        case .arrived: 25
        }
    }

    public static func < (lhs: ApproachBand, rhs: ApproachBand) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func band(forDistanceMeters meters: Double) -> ApproachBand? {
        if meters <= ApproachBand.arrived.radiusMeters { return .arrived }
        if meters <= ApproachBand.near.radiusMeters { return .near }
        if meters <= ApproachBand.approaching.radiusMeters { return .approaching }
        return nil
    }
}

public struct ApproachEvent: Equatable, Sendable {
    public var placeID: UUID
    public var band: ApproachBand

    public init(placeID: UUID, band: ApproachBand) {
        self.placeID = placeID
        self.band = band
    }
}

/// Tracks the closest band already announced per place so haptics do not repeat every GPS tick.
public struct ApproachHapticTracker: Sendable, Equatable {
    private var lastBandByPlace: [UUID: ApproachBand]

    public init(lastBandByPlace: [UUID: ApproachBand] = [:]) {
        self.lastBandByPlace = lastBandByPlace
    }

    public mutating func reset() {
        lastBandByPlace.removeAll()
    }

    /// Returns events for newly entered (or closer) bands. Leaving a radius clears the place so a return can fire again.
    public mutating func events(for distances: [UUID: Double]) -> [ApproachEvent] {
        var events: [ApproachEvent] = []
        for (placeID, meters) in distances {
            let newBand = ApproachBand.band(forDistanceMeters: meters)
            let previous = lastBandByPlace[placeID]
            if let newBand {
                if previous == nil || newBand > previous! {
                    events.append(ApproachEvent(placeID: placeID, band: newBand))
                }
                lastBandByPlace[placeID] = newBand
            } else {
                lastBandByPlace[placeID] = nil
            }
        }
        return events.sorted { lhs, rhs in
            if lhs.band != rhs.band { return lhs.band > rhs.band }
            return lhs.placeID.uuidString < rhs.placeID.uuidString
        }
    }
}
