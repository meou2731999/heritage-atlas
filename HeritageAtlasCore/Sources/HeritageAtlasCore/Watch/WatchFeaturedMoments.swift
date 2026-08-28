import CryptoKit
import Foundation

/// Picks the handful of memories and life moments that fit on Apple Watch.
/// Watch never receives a full timeline or gallery.
public enum WatchFeaturedMoments {
    public static let maxFeaturedMemories = 2
    public static let maxTimelineMoments = 5
    public static let maxMomentsPerPerson = 2

    public static func selectFeaturedMemories(
        memories: [Memory],
        favoritePersonIDs: [UUID],
        mePersonID: UUID?
    ) -> [Memory] {
        let favoriteSet = Set(favoritePersonIDs)
        let ranked = memories.sorted { lhs, rhs in
            let left = featuredScore(lhs, favorites: favoriteSet, mePersonID: mePersonID)
            let right = featuredScore(rhs, favorites: favoriteSet, mePersonID: mePersonID)
            if left != right { return left > right }
            return (lhs.occurredOn ?? .distantPast) > (rhs.occurredOn ?? .distantPast)
        }
        let featured = ranked.filter(\.isFeatured)
        if featured.isEmpty == false {
            return Array(featured.prefix(maxFeaturedMemories))
        }
        let hearable = ranked.filter { $0.kind.isHearable || $0.kind == .photo }
        return Array(hearable.prefix(maxFeaturedMemories))
    }

    public static func selectTimelineMoments(
        events: [TimelineEvent],
        people: [Person],
        memories: [Memory],
        favoritePersonIDs: [UUID],
        mePersonID: UUID?,
        locale: KinshipLocale
    ) -> [WatchTimelineMoment] {
        let focusIDs = focusPersonIDs(
            favorites: favoritePersonIDs,
            mePersonID: mePersonID,
            people: people
        )
        let memoriesByID = Dictionary(uniqueKeysWithValues: memories.map { ($0.id, $0) })
        let featuredMemoryIDs = Set(memories.filter(\.isFeatured).map(\.id))

        var scored: [(event: TimelineEvent, score: Int)] = []
        for event in events {
            guard let personID = event.person?.id, focusIDs.contains(personID) else { continue }
            var score = event.kind.watchMomentWeight
            if favoritePersonIDs.contains(personID) { score += 12 }
            if personID == mePersonID { score += 6 }
            if event.memoryIDs.contains(where: featuredMemoryIDs.contains) { score += 20 }
            if event.memoryIDs.isEmpty == false { score += 8 }
            scored.append((event, score))
        }

        var picked: [TimelineEvent] = []
        var countByPerson: [UUID: Int] = [:]
        for item in scored.sorted(by: { $0.score > $1.score }) {
            guard picked.count < maxTimelineMoments else { break }
            let personID = item.event.person?.id ?? UUID()
            let used = countByPerson[personID, default: 0]
            if used >= maxMomentsPerPerson { continue }
            picked.append(item.event)
            countByPerson[personID] = used + 1
        }

        var moments = picked.map { event in
            let person = event.person
            let linkedTitle = event.memoryIDs.compactMap { memoriesByID[$0]?.title }.first
            return WatchTimelineMoment(
                id: event.id,
                personID: person?.id ?? UUID(),
                personName: displayName(for: person),
                date: event.date,
                title: event.kind.resolvedTitle(event.title, locale: locale),
                kind: event.kind,
                placeName: event.place?.name,
                memoryTitle: linkedTitle,
                isSynthesized: false
            )
        }

        if moments.count < maxTimelineMoments {
            let existingKeys = Set(moments.map { "\($0.personID)-\($0.kind.rawValue)" })
            let fillers = synthesizedMoments(
                people: people.filter { focusIDs.contains($0.id) },
                existingKeys: existingKeys,
                locale: locale,
                remaining: maxTimelineMoments - moments.count
            )
            moments.append(contentsOf: fillers)
        }

        return moments.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    public static func synthesizedMomentID(personID: UUID, kind: TimelineEventKind) -> UUID {
        let string = "heritage.atlas.moment.\(personID.uuidString).\(kind.rawValue)"
        let digest = SHA256.hash(data: Data(string.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x40
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func featuredScore(
        _ memory: Memory,
        favorites: Set<UUID>,
        mePersonID: UUID?
    ) -> Int {
        var score = 0
        if memory.isFeatured { score += 100 }
        if memory.kind.isHearable { score += 20 }
        if memory.kind == .photo { score += 6 }
        if memory.personIDs.contains(where: favorites.contains) { score += 15 }
        if let mePersonID, memory.personIDs.contains(mePersonID) { score += 8 }
        return score
    }

    private static func focusPersonIDs(
        favorites: [UUID],
        mePersonID: UUID?,
        people: [Person]
    ) -> Set<UUID> {
        var ids = Set(favorites)
        if let mePersonID {
            ids.insert(mePersonID)
        }
        if ids.isEmpty {
            ids = Set(people.map(\.id))
        }
        return ids
    }

    private static func synthesizedMoments(
        people: [Person],
        existingKeys: Set<String>,
        locale: KinshipLocale,
        remaining: Int
    ) -> [WatchTimelineMoment] {
        var result: [WatchTimelineMoment] = []
        for person in people.sorted(by: { ($0.birthDate ?? .distantFuture) < ($1.birthDate ?? .distantFuture) }) {
            guard result.count < remaining else { break }
            if let birth = person.birthDate {
                let key = "\(person.id)-\(TimelineEventKind.born.rawValue)"
                if existingKeys.contains(key) == false {
                    result.append(
                        WatchTimelineMoment(
                            id: synthesizedMomentID(personID: person.id, kind: .born),
                            personID: person.id,
                            personName: displayName(for: person),
                            date: birth,
                            title: TimelineEventKind.born.localizedName(locale),
                            kind: .born,
                            isSynthesized: true
                        )
                    )
                }
            }
            guard result.count < remaining else { break }
            if let death = person.deathDate {
                let key = "\(person.id)-\(TimelineEventKind.died.rawValue)"
                if existingKeys.contains(key) == false {
                    result.append(
                        WatchTimelineMoment(
                            id: synthesizedMomentID(personID: person.id, kind: .died),
                            personID: person.id,
                            personName: displayName(for: person),
                            date: death,
                            title: TimelineEventKind.died.localizedName(locale),
                            kind: .died,
                            isSynthesized: true
                        )
                    )
                }
            }
        }
        return result
    }

    private static func displayName(for person: Person?) -> String {
        guard let person else { return "" }
        if let nickname = person.nickname, nickname.isEmpty == false {
            return nickname
        }
        return person.fullName
    }
}
