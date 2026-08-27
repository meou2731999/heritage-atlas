import Foundation
import HeritageAtlasCore
import Observation
import SwiftData
import UIKit

@Observable
final class FamilySession {
    var graph = RelationshipGraph(people: [], edges: [])
    var lastErrorMessage: String?
    var selectedTab: AppTab = .home
    var treeFocusID: UUID?
    var mapMode: FamilyMapMode = .family
    var mapFocusPlaceID: UUID?

    private let cacheController = RelationshipCacheController()
    let mediaStore: MediaStore
    private let mediaSync: MediaSyncService
    var photoDataByID: [UUID: Data] = [:]
    var mediaPathByID: [UUID: String] = [:]

    var relationshipCache: RelationshipCache { cacheController.cache }

    init() {
        let store = MediaStore()
        mediaStore = store
        mediaSync = MediaSyncService(store: store)
    }

    func refresh(context: ModelContext) {
        do {
            try cacheController.rebuild(from: context)
            graph = try RelationshipGraphBuilder.make(from: context)
            let media = try context.fetch(FetchDescriptor<MediaRef>())
            mediaPathByID = Dictionary(uniqueKeysWithValues: media.map { ($0.id, $0.relativePath) })
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func persistGraphChange(context: ModelContext) {
        do {
            try context.save()
            refresh(context: context)
            pushWatchSnapshot(context: context)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func persistDataChange(context: ModelContext) {
        do {
            try context.save()
            pushWatchSnapshot(context: context)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func persistSettingsChange(context: ModelContext, rebuildCache: Bool) {
        do {
            try context.save()
            if rebuildCache {
                refresh(context: context)
            }
            pushWatchSnapshot(context: context)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func exploreFamily(focus: UUID?) {
        treeFocusID = focus
        selectedTab = .tree
    }

    func openFamilyMap(focusPlaceID: UUID? = nil) {
        mapMode = .family
        mapFocusPlaceID = focusPlaceID
        selectedTab = .map
    }

    func openCemeteryMap(focusPlaceID: UUID? = nil) {
        mapMode = .cemetery
        mapFocusPlaceID = focusPlaceID
        selectedTab = .map
    }

    @discardableResult
    func savePlace(
        existing: Place?,
        name: String,
        latitude: Double?,
        longitude: Double?,
        notes: String?,
        context: ModelContext
    ) -> UUID {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesValue = (trimmedNotes?.isEmpty == false) ? trimmedNotes : nil
        let place: Place
        if let existing {
            place = existing
            place.name = trimmedName
            place.latitude = latitude
            place.longitude = longitude
            place.notes = notesValue
        } else {
            place = Place(name: trimmedName, latitude: latitude, longitude: longitude, notes: notesValue)
            context.insert(place)
        }
        persistDataChange(context: context)
        return place.id
    }

    func deletePlace(_ place: Place, context: ModelContext) {
        if mapFocusPlaceID == place.id {
            mapFocusPlaceID = nil
        }
        let placeID = place.id
        if let memories = try? context.fetch(FetchDescriptor<Memory>()) {
            for memory in memories {
                memory.placeIDs.removeAll { $0 == placeID }
            }
        }
        if let walks = try? context.fetch(FetchDescriptor<FamilyWalk>()) {
            for walk in walks {
                walk.stopIDs.removeAll { $0 == placeID }
            }
        }
        context.delete(place)
        persistDataChange(context: context)
    }

    func savePersonPlace(
        existing: PersonPlace?,
        person: Person,
        place: Place,
        role: PlaceRole,
        yearFrom: Int?,
        yearTo: Int?,
        context: ModelContext
    ) {
        if let existing {
            existing.person = person
            existing.place = place
            existing.role = role
            existing.yearFrom = yearFrom
            existing.yearTo = yearTo
        } else {
            context.insert(
                PersonPlace(role: role, person: person, place: place, yearFrom: yearFrom, yearTo: yearTo)
            )
        }
        persistDataChange(context: context)
    }

    func deletePersonPlace(_ link: PersonPlace, context: ModelContext) {
        context.delete(link)
        persistDataChange(context: context)
    }

    func recordRecent(personID: UUID, context: ModelContext) {
        let settings = AppSettings.current(in: context)
        var recents = settings.recentPersonIDs.filter { $0 != personID }
        recents.insert(personID, at: 0)
        settings.recentPersonIDs = Array(recents.prefix(12))
        persistSettingsChange(context: context, rebuildCache: false)
    }

    func setMe(personID: UUID?, context: ModelContext) {
        let settings = AppSettings.current(in: context)
        settings.mePersonID = personID
        persistSettingsChange(context: context, rebuildCache: true)
    }

    func setKinshipLocale(_ locale: KinshipLocale, context: ModelContext) {
        let settings = AppSettings.current(in: context)
        settings.localeKinship = locale
        persistSettingsChange(context: context, rebuildCache: true)
    }

    @discardableResult
    func savePerson(
        existing: Person?,
        draft: PersonDraft,
        context: ModelContext
    ) async -> UUID? {
        let tags = draft.parsedTags
        let person: Person
        if let existing {
            person = existing
            person.fullName = draft.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            person.nickname = draft.trimmedNickname
            person.gender = draft.gender
            person.birthDate = draft.hasBirthDate ? draft.birthDate : nil
            person.deathDate = draft.hasDeathDate ? draft.deathDate : nil
            person.occupation = draft.trimmedOccupation
            person.notes = draft.trimmedNotes
            person.tags = tags
        } else {
            person = Person(
                fullName: draft.fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                nickname: draft.trimmedNickname,
                gender: draft.gender,
                birthDate: draft.hasBirthDate ? draft.birthDate : nil,
                deathDate: draft.hasDeathDate ? draft.deathDate : nil,
                occupation: draft.trimmedOccupation,
                notes: draft.trimmedNotes,
                tags: tags
            )
            context.insert(person)
            let settings = AppSettings.current(in: context)
            if settings.mePersonID == nil {
                settings.mePersonID = person.id
            }
        }

        if draft.removePhoto, let oldID = person.photoMediaID {
            await deleteMedia(id: oldID, context: context)
            person.photoMediaID = nil
        } else if let photoData = draft.photoData {
            if let oldID = person.photoMediaID {
                await deleteMedia(id: oldID, context: context)
            }
            do {
                let write = try await mediaStore.save(photoData, fileExtension: "jpg")
                let ref = MediaRef(
                    id: write.id,
                    kind: .photo,
                    relativePath: write.relativePath,
                    byteSize: write.byteSize,
                    checksum: write.checksum
                )
                context.insert(ref)
                person.photoMediaID = write.id
                photoDataByID[write.id] = photoData
                mediaPathByID[write.id] = write.relativePath
                await mediaSync.enqueueUpload(id: write.id)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }

        upsertLifeEvents(for: person, context: context)
        persistGraphChange(context: context)
        return person.id
    }

    func toggleFavorite(personID: UUID, context: ModelContext) {
        let settings = AppSettings.current(in: context)
        if settings.favoritePersonIDs.contains(personID) {
            settings.favoritePersonIDs.removeAll { $0 == personID }
        } else {
            settings.favoritePersonIDs.append(personID)
        }
        persistSettingsChange(context: context, rebuildCache: false)
    }

    func isFavorite(personID: UUID, context: ModelContext) -> Bool {
        AppSettings.current(in: context).favoritePersonIDs.contains(personID)
    }

    func deletePerson(_ person: Person, context: ModelContext) async {
        let id = person.id
        let settings = AppSettings.current(in: context)
        if settings.mePersonID == id {
            settings.mePersonID = nil
        }
        settings.recentPersonIDs.removeAll { $0 == id }
        settings.favoritePersonIDs.removeAll { $0 == id }

        if let photoID = person.photoMediaID {
            await deleteMedia(id: photoID, context: context)
        }

        if let relationships = try? context.fetch(FetchDescriptor<KinRelationship>()) {
            for rel in relationships where rel.fromPerson?.id == id || rel.toPerson?.id == id {
                context.delete(rel)
            }
        }

        if let memories = try? context.fetch(FetchDescriptor<Memory>()) {
            for memory in memories {
                memory.personIDs.removeAll { $0 == id }
            }
        }

        context.delete(person)
        if treeFocusID == id {
            treeFocusID = settings.mePersonID
        }
        persistGraphChange(context: context)
    }

    func addRelationship(
        from: Person,
        to: Person,
        kind: KinRelationshipKind,
        context: ModelContext
    ) {
        guard from.id != to.id else { return }
        if relationshipExists(from: from, to: to, kind: kind, context: context) {
            return
        }
        context.insert(KinRelationship(kind: kind, fromPerson: from, toPerson: to))
        persistGraphChange(context: context)
    }

    func deleteRelationship(_ relationship: KinRelationship, context: ModelContext) {
        context.delete(relationship)
        persistGraphChange(context: context)
    }

    func photoData(for mediaID: UUID) async -> Data? {
        if let cached = photoDataByID[mediaID] {
            return cached
        }
        let data = try? await mediaStore.load(id: mediaID, relativePath: mediaPathByID[mediaID])
        if let data {
            photoDataByID[mediaID] = data
        }
        return data
    }

    func seedDemoFamily(context: ModelContext) {
        do {
            let meID = try DemoFamilySeeder.seed(into: context)
            treeFocusID = meID
            persistGraphChange(context: context)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func relationshipExists(
        from: Person,
        to: Person,
        kind: KinRelationshipKind,
        context: ModelContext
    ) -> Bool {
        let relationships = (try? context.fetch(FetchDescriptor<KinRelationship>())) ?? []
        let bidirectional = kind == .spouse || kind == .partner
        return relationships.contains { rel in
            guard rel.kind == kind else { return false }
            let same = rel.fromPerson?.id == from.id && rel.toPerson?.id == to.id
            if same { return true }
            if bidirectional {
                return rel.fromPerson?.id == to.id && rel.toPerson?.id == from.id
            }
            return false
        }
    }

    private func pushWatchSnapshot(context: ModelContext) {
        let media = (try? context.fetch(FetchDescriptor<MediaRef>())) ?? []
        let byID = Dictionary(uniqueKeysWithValues: media.map { ($0.id, $0) })
        guard let snapshot = try? WatchSnapshotPackager.pack(
            from: context,
            cache: cacheController.cache,
            mediaByID: byID
        ) else { return }
        try? WatchConnectivityService.shared.sendSnapshot(snapshot)
    }

    func enqueueMediaUpload(id: UUID) async {
        await mediaSync.enqueueUpload(id: id)
    }

    func deleteMedia(id: UUID, context: ModelContext) async {
        try? await mediaStore.delete(id: id, relativePath: mediaPathByID[id])
        if let refs = try? context.fetch(FetchDescriptor<MediaRef>()) {
            for ref in refs where ref.id == id {
                context.delete(ref)
            }
        }
        photoDataByID[id] = nil
        mediaPathByID[id] = nil
    }
}

struct PersonDraft {
    var fullName: String = ""
    var nickname: String = ""
    var gender: Gender = .unknown
    var hasBirthDate = false
    var birthDate = Date()
    var hasDeathDate = false
    var deathDate = Date()
    var occupation: String = ""
    var notes: String = ""
    var tagsText: String = ""
    var photoData: Data?
    var removePhoto = false

    init() {}

    init(person: Person) {
        fullName = person.fullName
        nickname = person.nickname ?? ""
        gender = person.gender
        if let birth = person.birthDate {
            hasBirthDate = true
            birthDate = birth
        }
        if let death = person.deathDate {
            hasDeathDate = true
            deathDate = death
        }
        occupation = person.occupation ?? ""
        notes = person.notes ?? ""
        tagsText = person.tags.joined(separator: ", ")
    }

    var trimmedNickname: String? {
        let value = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var trimmedOccupation: String? {
        let value = occupation.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var trimmedNotes: String? {
        let value = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
