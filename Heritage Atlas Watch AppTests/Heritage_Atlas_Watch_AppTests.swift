import Foundation
import HeritageAtlasCore
import SwiftData
import Testing
@testable import Heritage_Atlas_Watch_App

struct Heritage_Atlas_Watch_AppTests {
    @Test func searchMatchesNameNicknameAndKinshipTerm() {
        let snapshot = WatchSnapshotExplorer.sample()
        let byNickname = WatchSnapshotExplorer.search("Quân", in: snapshot)
        #expect(byNickname.contains { $0.nickname == "Quân" })

        let byFatherTerm = WatchSnapshotExplorer.search("Bố", in: snapshot)
        #expect(byFatherTerm.contains { $0.fullName.contains("Ba") })

        let byName = WatchSnapshotExplorer.search("ong noi", in: snapshot)
        #expect(byName.contains { $0.fullName.contains("Ông Nội") })
    }

    @Test func whoIsThisReadsPrecomputedCache() {
        let snapshot = WatchSnapshotExplorer.sample()
        let grandfather = snapshot.people!.first { $0.fullName.contains("Ông Nội") }!
        let relationship = WatchSnapshotExplorer.relationship(for: grandfather.id, in: snapshot)
        #expect(relationship?.youCallThem == "Ông")
        #expect(relationship?.theyCallYou == "Cháu")
        #expect(relationship?.term == "Ông nội")
        #expect(relationship?.pathGlance == "YOU ↑ Father ↑ Grandfather")
    }

    @Test func pathGlanceStacksParents() {
        let lines = WatchSnapshotExplorer.pathGlanceLines("YOU ↑ Father ↑ Grandfather")
        #expect(lines == ["YOU", "↑ Father", "↑ Grandfather"])
        #expect(WatchSnapshotExplorer.pathGlanceLines("YOU") == ["YOU"])
        #expect(WatchSnapshotExplorer.pathGlanceLines("YOU ↓ Daughter") == ["YOU", "↓ Daughter"])
        #expect(WatchSnapshotExplorer.pathGlanceLines("YOU ↔ Spouse") == ["YOU", "↔ Spouse"])
    }

    @Test func indexedPeopleFallsBackToFavoritesWhenPeopleMissing() {
        let favorite = WatchPerson(id: UUID(), fullName: "Chỉ yêu thích", isFavorite: true)
        let snapshot = WatchSnapshot(
            favorites: [favorite],
            recents: [],
            people: nil,
            relationshipCache: []
        )
        #expect(WatchSnapshotExplorer.indexedPeople(in: snapshot).map(\.id) == [favorite.id])
        #expect(WatchSnapshotExplorer.search("yeu", in: snapshot).count == 1)
    }

    @Test func nearbyPlacesRankByDistanceFromHanoi() {
        let snapshot = WatchSnapshotExplorer.sample()
        let hanoi = GeoPoint(latitude: 21.0285, longitude: 105.8542)
        let ranked = WatchSnapshotExplorer.rankedPlaces(
            snapshot.nearbyPlaces,
            from: hanoi,
            headingDegrees: 0
        )
        #expect(ranked.first?.place.name == "Nhà Hà Nội")
        #expect(ranked.last?.place.name.contains("Huế") == true)
        #expect(snapshot.cemeteryPins.contains { $0.role == .burial })
    }

    @Test @MainActor func applyingSnapshotMakesEnvelopeReadable() throws {
        let container = PersistenceController.makeInMemoryWatchContainer()
        let context = ModelContext(container)
        #expect(try WatchSnapshotApplier.load(from: context) == nil)

        try WatchSnapshotApplier.apply(WatchSnapshotExplorer.sample(), to: context)
        let loaded = try WatchSnapshotApplier.load(from: context)
        #expect(loaded?.favorites.isEmpty == false)
        #expect(loaded?.relationshipCache.isEmpty == false)
    }

    @Test func featuredMomentsAreGlanceableNotAFullTimeline() {
        let snapshot = WatchSnapshotExplorer.sample()
        let moments = WatchSnapshotExplorer.timelineMoments(in: snapshot)
        #expect(snapshot.featuredMemories.count == 1)
        #expect(moments.count == 2)
        #expect(moments.count <= 5)
        let grandfather = snapshot.people!.first { $0.fullName.contains("Ông Nội") }!
        #expect(WatchSnapshotExplorer.featuredMemory(for: grandfather.id, in: snapshot)?.kind == .story)
        #expect(WatchSnapshotExplorer.timelineMoments(for: grandfather.id, in: snapshot).contains { $0.kind == .born })
    }
}
