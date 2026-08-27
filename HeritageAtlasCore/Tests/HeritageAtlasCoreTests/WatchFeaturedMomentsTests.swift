import Foundation
import SwiftData
import Testing
@testable import HeritageAtlasCore

@Suite("Watch featured moments")
struct WatchFeaturedMomentsTests {
    @Test @MainActor func prefersFeaturedHearableMemoriesForFavorites() throws {
        let phone = PersistenceController.makeInMemoryPhoneContainer()
        let context = ModelContext(phone)
        let me = Person(fullName: "Quân", nickname: "Quân", gender: .male)
        let father = Person(fullName: "Ba", gender: .male)
        context.insert(me)
        context.insert(father)

        let featured = Memory(
            kind: .story,
            title: "Ông Nội kể chuyện Huế",
            body: "A story",
            personIDs: [father.id],
            isFeatured: true
        )
        let other = Memory(kind: .text, title: "Note", personIDs: [me.id])
        context.insert(featured)
        context.insert(other)
        try context.save()

        let picked = WatchFeaturedMoments.selectFeaturedMemories(
            memories: [featured, other],
            favoritePersonIDs: [father.id],
            mePersonID: me.id
        )
        #expect(picked.map(\.title) == ["Ông Nội kể chuyện Huế"])
    }

    @Test @MainActor func picksImportantTimelineEventsAndFillsBornDied() throws {
        let phone = PersistenceController.makeInMemoryPhoneContainer()
        let context = ModelContext(phone)
        let me = Person(fullName: "Quân", gender: .male, birthDate: date(1995))
        let father = Person(fullName: "Ba", gender: .male, birthDate: date(1960), deathDate: date(2020))
        context.insert(me)
        context.insert(father)

        let wedding = TimelineEvent(
            person: father,
            date: date(1993),
            title: "Married",
            kind: .married
        )
        let moved = TimelineEvent(
            person: me,
            date: date(2001),
            title: "Moved to Hà Nội",
            kind: .moved
        )
        context.insert(wedding)
        context.insert(moved)
        try context.save()

        let moments = WatchFeaturedMoments.selectTimelineMoments(
            events: [wedding, moved],
            people: [me, father],
            memories: [],
            favoritePersonIDs: [father.id],
            mePersonID: me.id,
            locale: .en
        )
        #expect(moments.count <= WatchFeaturedMoments.maxTimelineMoments)
        #expect(moments.contains { $0.kind == .married && $0.title == "Married" })
        #expect(moments.contains { $0.kind == .born && $0.personID == me.id && $0.isSynthesized })
        #expect(moments.contains { $0.kind == .died && $0.personID == father.id && $0.isSynthesized })
        let dates = moments.map(\.date)
        #expect(dates == dates.sorted())
    }

    @Test func synthesizedIDsAreStable() {
        let personID = UUID(uuidString: "00000000-0000-4000-8000-0000000000AA")!
        let first = WatchFeaturedMoments.synthesizedMomentID(personID: personID, kind: .born)
        let second = WatchFeaturedMoments.synthesizedMomentID(personID: personID, kind: .born)
        let died = WatchFeaturedMoments.synthesizedMomentID(personID: personID, kind: .died)
        #expect(first == second)
        #expect(first != died)
    }

    private func date(_ year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 6
        components.day = 15
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
