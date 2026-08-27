import Foundation
import SwiftData

@MainActor
public enum WatchSnapshotPackager {
    public static func pack(
        from context: ModelContext,
        cache: RelationshipCache,
        mediaByID: [UUID: MediaRef] = [:]
    ) throws -> WatchSnapshot {
        let settings = AppSettings.current(in: context)
        let people = try context.fetch(FetchDescriptor<Person>())
        let peopleByID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
        let favoriteIDs = settings.favoritePersonIDs
        let recentIDs = settings.recentPersonIDs

        func watchPerson(id: UUID, favorite: Bool) -> WatchPerson? {
            guard let person = peopleByID[id] else { return nil }
            let thumb = person.photoMediaID.flatMap { mediaByID[$0]?.thumbnailRelativePath ?? mediaByID[$0]?.relativePath }
            return WatchPerson(
                id: person.id,
                fullName: person.fullName,
                nickname: person.nickname,
                gender: person.gender,
                isFavorite: favorite,
                thumbnailRelativePath: thumb
            )
        }

        let favorites = favoriteIDs.compactMap { watchPerson(id: $0, favorite: true) }
        let recents = recentIDs.compactMap { watchPerson(id: $0, favorite: favoriteIDs.contains($0)) }
        let watchPeople = people.compactMap { person in
            watchPerson(id: person.id, favorite: favoriteIDs.contains(person.id))
        }

        let relationshipCache = cache.entriesByPersonID.values
            .sorted { ($0.naming.term, $0.personID.uuidString) < ($1.naming.term, $1.personID.uuidString) }
            .map { entry in
                WatchRelationship(
                    personID: entry.personID,
                    pathGlance: entry.pathGlance,
                    pathExplanation: entry.naming.pathExplanation,
                    term: entry.naming.term,
                    youCallThem: entry.naming.youCallThem,
                    theyCallYou: entry.naming.theyCallYou,
                    code: entry.code
                )
            }

        let personPlaces = try context.fetch(FetchDescriptor<PersonPlace>())
        let places = try context.fetch(FetchDescriptor<Place>())
        let linksByPlaceID = Dictionary(grouping: personPlaces.filter { $0.place != nil }) { $0.place!.id }

        var nearbyPlaces: [WatchPlace] = []
        var burialPlaces: [WatchPlace] = []
        var cemeteryPins: [WatchPlace] = []

        for place in places where place.hasCoordinates {
            let links = linksByPlaceID[place.id] ?? []
            let personIDs = uniqued(links.compactMap { $0.person?.id })
            nearbyPlaces.append(
                WatchPlace(
                    id: place.id,
                    name: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    role: primaryRole(in: links),
                    personIDs: personIDs
                )
            )

            let burialPersonIDs = uniqued(links.filter { $0.role == .burial }.compactMap { $0.person?.id })
            if !burialPersonIDs.isEmpty {
                let burial = WatchPlace(
                    id: place.id,
                    name: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    role: .burial,
                    personIDs: burialPersonIDs
                )
                burialPlaces.append(burial)
                cemeteryPins.append(burial)
            }
        }

        nearbyPlaces.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        burialPlaces.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        cemeteryPins.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        var currentWalk: WatchFamilyWalk?
        if let walkID = settings.currentFamilyWalkID {
            let walks = try context.fetch(FetchDescriptor<FamilyWalk>())
            if let walk = walks.first(where: { $0.id == walkID }) {
                currentWalk = WatchFamilyWalk(id: walk.id, title: walk.title, stopIDs: walk.stopIDs)
            }
        }

        let memories = try context.fetch(FetchDescriptor<Memory>())
        let events = try context.fetch(FetchDescriptor<TimelineEvent>())
        let selectedMemories = WatchFeaturedMoments.selectFeaturedMemories(
            memories: memories,
            favoritePersonIDs: favoriteIDs,
            mePersonID: settings.mePersonID
        )
        let featured = selectedMemories.map { memory in
            let firstMedia = memory.mediaIDs.first.flatMap { mediaByID[$0] }
            let personID = memory.personIDs.first
            let preview = memory.body.trimmingCharacters(in: .whitespacesAndNewlines)
            return WatchMemory(
                id: memory.id,
                personID: personID,
                title: memory.title,
                kind: memory.kind,
                thumbnailRelativePath: firstMedia?.thumbnailRelativePath ?? (firstMedia?.kind == .photo ? firstMedia?.relativePath : nil),
                audioRelativePath: firstMedia?.kind == .audio ? firstMedia?.relativePath : nil,
                durationSeconds: firstMedia?.durationSeconds,
                occurredOn: memory.occurredOn,
                personName: personID.flatMap { peopleByID[$0] }.map { person in
                    if let nickname = person.nickname, nickname.isEmpty == false { return nickname }
                    return person.fullName
                },
                bodyPreview: preview.isEmpty ? nil : String(preview.prefix(140))
            )
        }

        let timelineMoments = WatchFeaturedMoments.selectTimelineMoments(
            events: events,
            people: people,
            memories: memories,
            favoritePersonIDs: favoriteIDs,
            mePersonID: settings.mePersonID,
            locale: settings.localeKinship
        )

        return WatchSnapshot(
            generatedAt: Date(),
            mePersonID: settings.mePersonID,
            localeKinship: settings.localeKinship,
            favorites: favorites,
            recents: recents,
            people: watchPeople,
            relationshipCache: relationshipCache,
            nearbyPlaces: nearbyPlaces,
            burialPlaces: burialPlaces,
            cemeteryPins: cemeteryPins,
            currentWalk: currentWalk,
            featuredMemories: featured,
            timelineMoments: timelineMoments
        )
    }

    private static func primaryRole(in links: [PersonPlace]) -> PlaceRole? {
        let priority: [PlaceRole] = [.home, .childhoodHome, .born, .school, .workplace, .wedding, .hospital, .burial]
        let roles = Set(links.map(\.role))
        return priority.first { roles.contains($0) } ?? links.first?.role
    }

    private static func uniqued(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }
}

@MainActor
public enum WatchSnapshotApplier {
    public static func apply(_ snapshot: WatchSnapshot, to context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<WatchSnapshotEnvelope>())
        for row in existing {
            context.delete(row)
        }
        context.insert(WatchSnapshotEnvelope(snapshot: snapshot))
        try context.save()
    }

    public static func load(from context: ModelContext) throws -> WatchSnapshot? {
        try context.fetch(FetchDescriptor<WatchSnapshotEnvelope>()).first?.snapshot()
    }
}
