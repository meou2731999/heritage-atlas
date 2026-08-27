import Foundation
import HeritageAtlasCore

struct WatchDistantPlace: Identifiable, Equatable {
    var id: UUID { place.id }
    var place: WatchPlace
    var distanceMeters: Double?
    var bearingDegrees: Double?
    var relativeBearingDegrees: Double?
}

/// Watch-side queries over a packed iPhone snapshot. Never runs BFS.
enum WatchSnapshotExplorer {
    static func indexedPeople(in snapshot: WatchSnapshot) -> [WatchPerson] {
        var byID: [UUID: WatchPerson] = [:]
        if let people = snapshot.people {
            for person in people {
                byID[person.id] = person
            }
        }
        for person in snapshot.favorites + snapshot.recents {
            byID[person.id] = person
        }
        return byID.values.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    static func person(id: UUID, in snapshot: WatchSnapshot) -> WatchPerson? {
        indexedPeople(in: snapshot).first { $0.id == id }
    }

    static func people(for place: WatchPlace, in snapshot: WatchSnapshot) -> [WatchPerson] {
        place.personIDs.compactMap { person(id: $0, in: snapshot) }
    }

    static func rankedPlaces(
        _ places: [WatchPlace],
        from point: GeoPoint?,
        headingDegrees: Double?
    ) -> [WatchDistantPlace] {
        places.compactMap { place -> WatchDistantPlace? in
            guard place.hasCoordinates, let target = place.geoPoint else { return nil }
            let distance = point.map { GeoMath.distanceMeters(from: $0, to: target) }
            let bearing = point.map { GeoMath.bearingDegrees(from: $0, to: target) }
            let relative: Double?
            if let bearing, let headingDegrees {
                relative = GeoMath.relativeBearingDegrees(targetBearing: bearing, deviceHeading: headingDegrees)
            } else {
                relative = nil
            }
            return WatchDistantPlace(
                place: place,
                distanceMeters: distance,
                bearingDegrees: bearing,
                relativeBearingDegrees: relative
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.distanceMeters, rhs.distanceMeters) {
            case (let left?, let right?) where left != right:
                return left < right
            default:
                return lhs.place.name.localizedStandardCompare(rhs.place.name) == .orderedAscending
            }
        }
    }

    static func relationship(for personID: UUID, in snapshot: WatchSnapshot) -> WatchRelationship? {
        snapshot.relationshipCache.first { $0.personID == personID }
    }

    static func timelineMoments(in snapshot: WatchSnapshot) -> [WatchTimelineMoment] {
        snapshot.timelineMoments ?? []
    }

    static func featuredMemory(for personID: UUID, in snapshot: WatchSnapshot) -> WatchMemory? {
        snapshot.featuredMemories.first { $0.personID == personID }
    }

    static func walkStops(in snapshot: WatchSnapshot) -> [WatchPlace] {
        guard let walk = snapshot.currentWalk else { return [] }
        if let stops = walk.stops, stops.isEmpty == false {
            return stops
        }
        let byID = Dictionary(uniqueKeysWithValues: snapshot.nearbyPlaces.map { ($0.id, $0) })
        return walk.stopIDs.compactMap { byID[$0] }
    }

    static func walkMemory(for placeID: UUID?, in snapshot: WatchSnapshot) -> WatchMemory? {
        guard let placeID else { return nil }
        if let packed = snapshot.currentWalk?.stopMemories?.first(where: { $0.placeID == placeID }) {
            return packed
        }
        return snapshot.featuredMemories.first { $0.placeID == placeID }
    }

    static func todayEvents(in snapshot: WatchSnapshot, now: Date = Date()) -> [WatchCalendarEvent] {
        guard snapshot.memorialRemindersEnabled == true else { return [] }
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        return (snapshot.todayEvents ?? []).filter { $0.month == month && $0.day == day }
    }

    static func timelineMoments(for personID: UUID, in snapshot: WatchSnapshot) -> [WatchTimelineMoment] {
        timelineMoments(in: snapshot).filter { $0.personID == personID }
    }

    static func search(_ query: String, in snapshot: WatchSnapshot) -> [WatchPerson] {
        let people = indexedPeople(in: snapshot)
        let needle = normalized(query)
        guard !needle.isEmpty else { return people }
        let cacheByID = Dictionary(uniqueKeysWithValues: snapshot.relationshipCache.map { ($0.personID, $0) })
        return people.filter { person in
            matches(person, needle: needle, relationship: cacheByID[person.id])
        }
    }

    /// Splits `YOU ↑ Father ↑ Grandfather` into stacked rows for a glance list.
    static func pathGlanceLines(_ glance: String) -> [String] {
        let trimmed = glance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var lines: [String] = []
        var current = ""
        for character in trimmed {
            if character == "↑" || character == "↓" || character == "↔" {
                let piece = current.trimmingCharacters(in: .whitespaces)
                if !piece.isEmpty {
                    lines.append(piece)
                }
                current = String(character)
            } else {
                current.append(character)
            }
        }
        let piece = current.trimmingCharacters(in: .whitespaces)
        if !piece.isEmpty {
            lines.append(piece)
        }
        return lines
    }

    static func sample() -> WatchSnapshot {
        let meID = UUID(uuidString: "00000000-0000-4000-8000-0000000000AA")!
        let fatherID = UUID(uuidString: "00000000-0000-4000-8000-0000000000BB")!
        let grandfatherID = UUID(uuidString: "00000000-0000-4000-8000-0000000000CC")!
        let motherID = UUID(uuidString: "00000000-0000-4000-8000-0000000000DD")!

        let me = WatchPerson(id: meID, fullName: "Nguyễn Văn Quân", nickname: "Quân", gender: .male, isFavorite: true)
        let father = WatchPerson(id: fatherID, fullName: "Nguyễn Văn Ba", gender: .male, isFavorite: true)
        let grandfather = WatchPerson(id: grandfatherID, fullName: "Ông Nội", gender: .male, isFavorite: false)
        let mother = WatchPerson(id: motherID, fullName: "Trần Thị Mẹ", gender: .female, isFavorite: false)

        return WatchSnapshot(
            mePersonID: meID,
            localeKinship: .vi,
            favorites: [me, father],
            recents: [mother],
            people: [me, father, grandfather, mother],
            relationshipCache: [
                WatchRelationship(
                    personID: meID,
                    pathGlance: "YOU",
                    pathExplanation: "Bạn",
                    term: "Bạn",
                    youCallThem: "Bạn",
                    theyCallYou: "Bạn",
                    code: .self
                ),
                WatchRelationship(
                    personID: fatherID,
                    pathGlance: "YOU ↑ Father",
                    pathExplanation: "bố của bạn",
                    term: "Bố",
                    youCallThem: "Bố",
                    theyCallYou: "Con",
                    code: .father
                ),
                WatchRelationship(
                    personID: grandfatherID,
                    pathGlance: "YOU ↑ Father ↑ Grandfather",
                    pathExplanation: "ông nội của bạn",
                    term: "Ông nội",
                    youCallThem: "Ông",
                    theyCallYou: "Cháu",
                    code: .paternalGrandfather
                ),
                WatchRelationship(
                    personID: motherID,
                    pathGlance: "YOU ↑ Mother",
                    pathExplanation: "mẹ của bạn",
                    term: "Mẹ",
                    youCallThem: "Mẹ",
                    theyCallYou: "Con",
                    code: .mother
                ),
            ],
            nearbyPlaces: [
                WatchPlace(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!,
                    name: "Nhà Hà Nội",
                    latitude: 21.0285,
                    longitude: 105.8542,
                    role: .home,
                    personIDs: [meID]
                ),
                WatchPlace(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000102")!,
                    name: "Nghĩa trang Văn Điển",
                    latitude: 20.9476,
                    longitude: 105.8608,
                    role: .burial,
                    personIDs: [grandfatherID]
                ),
                WatchPlace(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000103")!,
                    name: "Nhà Huế",
                    latitude: 16.4637,
                    longitude: 107.5909,
                    role: .childhoodHome,
                    personIDs: [fatherID]
                ),
            ],
            burialPlaces: [
                WatchPlace(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000102")!,
                    name: "Nghĩa trang Văn Điển",
                    latitude: 20.9476,
                    longitude: 105.8608,
                    role: .burial,
                    personIDs: [grandfatherID]
                ),
            ],
            cemeteryPins: [
                WatchPlace(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000102")!,
                    name: "Nghĩa trang Văn Điển",
                    latitude: 20.9476,
                    longitude: 105.8608,
                    role: .burial,
                    personIDs: [grandfatherID]
                ),
            ],
            currentWalk: WatchFamilyWalk(
                id: UUID(uuidString: "00000000-0000-4000-8000-000000000401")!,
                title: "Huế to Hà Nội",
                stopIDs: [
                    UUID(uuidString: "00000000-0000-4000-8000-000000000103")!,
                    UUID(uuidString: "00000000-0000-4000-8000-000000000101")!,
                    UUID(uuidString: "00000000-0000-4000-8000-000000000102")!,
                ],
                stops: nil,
                stopMemories: [
                    WatchMemory(
                        id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!,
                        personID: grandfatherID,
                        title: "Ông Nội kể chuyện Huế",
                        kind: .story,
                        personName: "Ông Nội",
                        bodyPreview: "Sông Hương lúc sương sớm.",
                        placeID: UUID(uuidString: "00000000-0000-4000-8000-000000000103")!
                    )
                ]
            ),
            featuredMemories: [
                WatchMemory(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!,
                    personID: grandfatherID,
                    title: "Ông Nội kể chuyện Huế",
                    kind: .story,
                    occurredOn: Date(),
                    personName: "Ông Nội",
                    bodyPreview: "Sông Hương lúc sương sớm."
                ),
            ],
            timelineMoments: [
                WatchTimelineMoment(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000301")!,
                    personID: grandfatherID,
                    personName: "Ông Nội",
                    date: Date(timeIntervalSince1970: -1_262_304_000),
                    title: "Sinh ở Huế",
                    kind: .born,
                    placeName: "Nhà Huế"
                ),
                WatchTimelineMoment(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000302")!,
                    personID: fatherID,
                    personName: "Ba",
                    date: Date(timeIntervalSince1970: 740_448_000),
                    title: "Kết hôn",
                    kind: .married,
                    placeName: "Thủy Tạ"
                ),
            ],
            todayEvents: [
                WatchCalendarEvent(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000501")!,
                    kind: .birthday,
                    personID: meID,
                    personName: "Quân",
                    title: "Quân",
                    month: 8,
                    day: 27,
                    years: 31
                )
            ],
            insightsGlance: WatchInsightsGlance(livingCount: 3, generationCount: 3),
            memorialRemindersEnabled: true
        )
    }

    private static func matches(_ person: WatchPerson, needle: String, relationship: WatchRelationship?) -> Bool {
        if normalized(person.fullName).contains(needle) { return true }
        if let nickname = person.nickname, normalized(nickname).contains(needle) { return true }
        if let relationship {
            if normalized(relationship.term).contains(needle) { return true }
            if normalized(relationship.youCallThem).contains(needle) { return true }
            if normalized(relationship.theyCallYou).contains(needle) { return true }
        }
        return false
    }

    private static func normalized(_ string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
