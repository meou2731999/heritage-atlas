import Foundation
import SwiftData
import Testing
@testable import HeritageAtlasCore

@Suite("Watch snapshot")
struct WatchSnapshotTests {
    @Test @MainActor func packFromPhoneAndApplyOnWatch() throws {
        let phone = PersistenceController.makeInMemoryPhoneContainer()
        let context = ModelContext(phone)
        let me = Person(fullName: "Nguyễn Văn Quân", gender: .male, birthDate: Date())
        context.insert(me)
        let settings = AppSettings.current(in: context)
        settings.mePersonID = me.id
        settings.favoritePersonIDs = [me.id]
        try context.save()

        let graph = try RelationshipGraphBuilder.make(from: context)
        let cache = RelationshipCache.rebuild(meID: me.id, graph: graph, locale: .vi)
        let snapshot = try WatchSnapshotPackager.pack(from: context, cache: cache)

        #expect(snapshot.mePersonID == me.id)
        #expect(snapshot.favorites.map(\.id) == [me.id])
        #expect(snapshot.people?.map(\.id).contains(me.id) == true)
        #expect(snapshot.relationshipCache.contains { $0.personID == me.id && $0.code == .self })

        let watch = PersistenceController.makeInMemoryWatchContainer()
        let watchContext = ModelContext(watch)
        try WatchSnapshotApplier.apply(snapshot, to: watchContext)
        let loaded = try WatchSnapshotApplier.load(from: watchContext)
        #expect(loaded?.mePersonID == me.id)
        #expect(loaded?.favorites.count == 1)
        #expect(loaded?.people?.count == 1)
        #expect(snapshot.nearbyPlaces.isEmpty)
        #expect(snapshot.cemeteryPins.isEmpty)
        #expect(snapshot.featuredMemories.isEmpty)
        #expect(snapshot.timelineMoments?.isEmpty == false)
        #expect(snapshot.timelineMoments?.contains { $0.kind == .born && $0.personID == me.id } == true)
    }

    @Test @MainActor func packIncludesNearbyAndCemeteryPinsFromPlaces() throws {
        let phone = PersistenceController.makeInMemoryPhoneContainer()
        let context = ModelContext(phone)
        let me = Person(fullName: "Nguyễn Văn Quân", gender: .male)
        let grandfather = Person(fullName: "Ông Nội", gender: .male)
        context.insert(me)
        context.insert(grandfather)

        let home = Place(name: "Nhà Hà Nội", latitude: 21.0285, longitude: 105.8542)
        let cemetery = Place(name: "Nghĩa trang Văn Điển", latitude: 20.9476, longitude: 105.8608)
        let unnamed = Place(name: "Huế", notes: "Name only, no coordinates")
        context.insert(home)
        context.insert(cemetery)
        context.insert(unnamed)
        context.insert(PersonPlace(role: .home, person: me, place: home, yearFrom: 1995))
        context.insert(PersonPlace(role: .burial, person: grandfather, place: cemetery, yearFrom: 2005))

        let settings = AppSettings.current(in: context)
        settings.mePersonID = me.id
        try context.save()

        let graph = try RelationshipGraphBuilder.make(from: context)
        let cache = RelationshipCache.rebuild(meID: me.id, graph: graph, locale: .vi)
        let snapshot = try WatchSnapshotPackager.pack(from: context, cache: cache)

        #expect(snapshot.nearbyPlaces.map(\.name).sorted() == ["Nghĩa trang Văn Điển", "Nhà Hà Nội"])
        #expect(snapshot.nearbyPlaces.contains { $0.name == "Huế" } == false)
        #expect(snapshot.cemeteryPins.count == 1)
        #expect(snapshot.burialPlaces.count == 1)
        #expect(snapshot.cemeteryPins.first?.role == .burial)
        #expect(snapshot.cemeteryPins.first?.personIDs == [grandfather.id])
        #expect(snapshot.nearbyPlaces.first { $0.name == "Nhà Hà Nội" }?.role == .home)
    }

    @Test @MainActor func packIncludesFeaturedMemoryAndPlaceLinkedCountsStayOnPhone() throws {
        let phone = PersistenceController.makeInMemoryPhoneContainer()
        let context = ModelContext(phone)
        let me = Person(fullName: "Nguyễn Văn Quân", gender: .male, birthDate: Date())
        context.insert(me)
        let home = Place(name: "Nhà Hà Nội", latitude: 21.0285, longitude: 105.8542)
        context.insert(home)
        let story = Memory(
            kind: .story,
            title: "Kitchen stories",
            body: "We cooked together.",
            personIDs: [me.id],
            placeIDs: [home.id],
            isFeatured: true
        )
        context.insert(story)
        context.insert(
            TimelineEvent(person: me, date: Date(), title: "Born", kind: .born, place: home, memoryIDs: [story.id])
        )
        let settings = AppSettings.current(in: context)
        settings.mePersonID = me.id
        settings.favoritePersonIDs = [me.id]
        try context.save()

        let graph = try RelationshipGraphBuilder.make(from: context)
        let cache = RelationshipCache.rebuild(meID: me.id, graph: graph, locale: .vi)
        let snapshot = try WatchSnapshotPackager.pack(from: context, cache: cache)

        #expect(snapshot.featuredMemories.map(\.title) == ["Kitchen stories"])
        #expect(snapshot.featuredMemories.first?.personID == me.id)
        #expect(snapshot.timelineMoments?.contains { $0.kind == .born && $0.memoryTitle == "Kitchen stories" } == true)
        #expect(snapshot.insightsGlance?.livingCount == 1)
        #expect(snapshot.insightsGlance?.generationCount == 1)
        #expect(snapshot.memorialRemindersEnabled == false)
        #expect(snapshot.todayEvents == nil)
    }

    @Test @MainActor func packIncludesCurrentWalkStopsAndOptInCalendar() throws {
        let phone = PersistenceController.makeInMemoryPhoneContainer()
        let context = ModelContext(phone)
        let me = Person(fullName: "Nguyễn Văn Quân", gender: .male, birthDate: Date())
        context.insert(me)
        let home = Place(name: "Nhà Hà Nội", latitude: 21.0285, longitude: 105.8542)
        let hue = Place(name: "Nhà Huế", latitude: 16.4637, longitude: 107.5909)
        context.insert(home)
        context.insert(hue)
        let walk = FamilyWalk(title: "Huế to Hà Nội", stopIDs: [hue.id, home.id])
        context.insert(walk)
        let settings = AppSettings.current(in: context)
        settings.mePersonID = me.id
        settings.currentFamilyWalkID = walk.id
        settings.memorialRemindersEnabled = true
        try context.save()

        let graph = try RelationshipGraphBuilder.make(from: context)
        let cache = RelationshipCache.rebuild(meID: me.id, graph: graph, locale: .vi)
        let snapshot = try WatchSnapshotPackager.pack(from: context, cache: cache)

        #expect(snapshot.currentWalk?.title == "Huế to Hà Nội")
        #expect(snapshot.currentWalk?.stopIDs == [hue.id, home.id])
        #expect(snapshot.currentWalk?.stops?.map(\.name) == ["Nhà Huế", "Nhà Hà Nội"])
        #expect(snapshot.memorialRemindersEnabled == true)
        #expect(snapshot.todayEvents != nil)
        #expect(snapshot.insightsGlance?.livingCount == 1)
    }

    @Test func olderSnapshotsWithoutPeopleStillDecode() throws {
        struct Legacy: Encodable {
            var generatedAt: Date
            var mePersonID: UUID?
            var localeKinship: KinshipLocale
            var favorites: [WatchPerson]
            var recents: [WatchPerson]
            var relationshipCache: [WatchRelationship]
            var nearbyPlaces: [WatchPlace]
            var burialPlaces: [WatchPlace]
            var cemeteryPins: [WatchPlace]
            var currentWalk: WatchFamilyWalk?
            var featuredMemories: [WatchMemory]
        }
        let data = try JSONEncoder().encode(
            Legacy(
                generatedAt: Date(),
                mePersonID: nil,
                localeKinship: .vi,
                favorites: [],
                recents: [],
                relationshipCache: [],
                nearbyPlaces: [],
                burialPlaces: [],
                cemeteryPins: [],
                currentWalk: nil,
                featuredMemories: []
            )
        )
        let snapshot = try JSONDecoder().decode(WatchSnapshot.self, from: data)
        #expect(snapshot.people == nil)
    }
}
