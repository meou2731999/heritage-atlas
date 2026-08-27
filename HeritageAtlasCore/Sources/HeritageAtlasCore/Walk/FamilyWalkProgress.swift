import Foundation

public struct FamilyWalkStopState: Sendable, Equatable, Identifiable {
    public var id: UUID { placeID }
    public var placeID: UUID
    public var index: Int
    public var isCurrent: Bool
    public var isArrived: Bool
    public var isUpcoming: Bool
    public var distanceMeters: Double?

    public init(
        placeID: UUID,
        index: Int,
        isCurrent: Bool,
        isArrived: Bool,
        isUpcoming: Bool,
        distanceMeters: Double?
    ) {
        self.placeID = placeID
        self.index = index
        self.isCurrent = isCurrent
        self.isArrived = isArrived
        self.isUpcoming = isUpcoming
        self.distanceMeters = distanceMeters
    }
}

public struct FamilyWalkProgress: Sendable, Equatable {
    public var currentIndex: Int
    public var arrivedIDs: Set<UUID>
    public var isComplete: Bool
    /// Stop the wearer is standing in (within arrived radius). Independent of the nav target.
    public var hereStopID: UUID?
    public var stops: [FamilyWalkStopState]

    public init(
        currentIndex: Int,
        arrivedIDs: Set<UUID>,
        isComplete: Bool,
        hereStopID: UUID? = nil,
        stops: [FamilyWalkStopState]
    ) {
        self.currentIndex = currentIndex
        self.arrivedIDs = arrivedIDs
        self.isComplete = isComplete
        self.hereStopID = hereStopID
        self.stops = stops
    }

    public var currentStopID: UUID? {
        guard stops.indices.contains(currentIndex) else { return nil }
        return stops[currentIndex].placeID
    }

    public var nextStopID: UUID? {
        let next = currentIndex + 1
        guard stops.indices.contains(next) else { return nil }
        return stops[next].placeID
    }

    public var youAreHere: Bool { hereStopID != nil }

    /// Stop to walk to next: the nav target while standing here, otherwise the stop after current.
    public var upcomingStopID: UUID? {
        if let hereStopID, currentStopID != hereStopID {
            return currentStopID
        }
        return nextStopID
    }
}

public enum FamilyWalkNavigator: Sendable {
    public static let arrivedRadiusMeters = ApproachBand.arrived.radiusMeters

    public static func progress(
        stopIDs: [UUID],
        distances: [UUID: Double],
        arrivedRadiusMeters: Double = arrivedRadiusMeters
    ) -> FamilyWalkProgress {
        guard stopIDs.isEmpty == false else {
            return FamilyWalkProgress(currentIndex: 0, arrivedIDs: [], isComplete: true, hereStopID: nil, stops: [])
        }

        var arrived: Set<UUID> = []
        var hereIndex: Int?
        var firstUnarrived: Int?
        for (index, id) in stopIDs.enumerated() {
            let meters = distances[id]
            let isArrived = meters.map { $0 <= arrivedRadiusMeters } ?? false
            if isArrived {
                arrived.insert(id)
                hereIndex = index
            } else if firstUnarrived == nil {
                firstUnarrived = index
            }
        }
        let complete = arrived.count == stopIDs.count
        let currentIndex: Int
        if complete {
            currentIndex = stopIDs.count - 1
        } else {
            currentIndex = firstUnarrived ?? (stopIDs.count - 1)
        }
        let hereStopID = hereIndex.map { stopIDs[$0] }

        let stops = stopIDs.enumerated().map { index, id in
            FamilyWalkStopState(
                placeID: id,
                index: index,
                isCurrent: index == currentIndex && complete == false,
                isArrived: arrived.contains(id),
                isUpcoming: index > currentIndex,
                distanceMeters: distances[id]
            )
        }
        return FamilyWalkProgress(
            currentIndex: currentIndex,
            arrivedIDs: arrived,
            isComplete: complete,
            hereStopID: hereStopID,
            stops: stops
        )
    }
}
