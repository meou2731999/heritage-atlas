import Foundation
import Testing
@testable import HeritageAtlasCore

@Suite("Phase 4 engines")
struct Phase4EngineTests {
    private func date(_ year: Int, month: Int = 6, day: Int = 15) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    @Test func insightsCountLivingDeceasedAndOldestAncestor() {
        let family = SampleFamily()
        let insights = FamilyInsightsEngine.compute(
            people: Array(family.graph.people.values),
            graph: family.graph,
            mePersonID: family.me.id,
            placeCount: 4,
            burialCount: 2,
            memoryCount: 3,
            storyCount: 1
        )
        #expect(insights.peopleCount == 15)
        #expect(insights.livingCount == 15)
        #expect(insights.deceasedCount == 0)
        #expect(insights.generationCount >= 3)
        #expect(insights.oldestAncestor?.id == family.paternalGrandfather.id)
        #expect(insights.largestGeneration != nil)
        #expect(insights.watchGlance.livingCount == 15)
        #expect(insights.watchGlance.generationCount == insights.generationCount)
    }

    @Test func calendarBirthdayGiỗAndWedding() {
        let calendar = Calendar(identifier: .gregorian)
        let now = date(2026, month: 8, day: 27)
        let living = PersonNode(fullName: "Quân", nickname: "Quân", gender: .male, birthDate: date(1995, month: 8, day: 27))
        let elder = PersonNode(fullName: "Ông Nội", gender: .male, birthDate: date(1930), deathDate: date(2005, month: 3, day: 8))
        let source = FamilyCalendarSource(
            people: [living, elder],
            weddingDates: [(living.id, date(2020, month: 9, day: 1), "Thủy Tạ")],
            burialPlaceNameByPersonID: [elder.id: "Văn Điển"],
            memoryCountByPersonID: [elder.id: 2],
            storyCountByPersonID: [elder.id: 1],
            locale: .vi
        )
        let events = FamilyCalendar.events(from: source, now: now, calendar: calendar)
        #expect(events.contains { $0.kind == .birthday && $0.personID == living.id })
        #expect(events.contains { $0.kind == .deathAnniversary && $0.personID == elder.id })
        #expect(events.contains { $0.kind == .wedding && $0.personID == living.id })

        let today = FamilyCalendar.occurring(on: now, in: events, calendar: calendar)
        #expect(today.contains { $0.kind == .birthday })

        let summaries = FamilyCalendar.memorialSummaries(from: source)
        #expect(summaries.count == 1)
        #expect(summaries.first?.rememberedByCount == 2)
        #expect(summaries.first?.burialPlaceName == "Văn Điển")
    }

    @Test func memoryGapCoverageAndPromptsPreferEldersWithoutStories() {
        let elder = MemoryGapPerson(
            id: UUID(),
            name: "Ông Nội",
            isLiving: false,
            birthDate: date(1930),
            childhoodHomeName: "Huế",
            burialPlaceName: "Văn Điển",
            hasStory: false,
            memoryCount: 1
        )
        let me = MemoryGapPerson(
            id: UUID(),
            name: "Quân",
            isLiving: true,
            birthDate: date(1995),
            hasStory: true,
            memoryCount: 2
        )
        let cousin = MemoryGapPerson(
            id: UUID(),
            name: "Anh Họ",
            isLiving: true,
            birthDate: date(1990),
            occupation: "Teacher",
            hasStory: false,
            memoryCount: 0
        )
        let report = MemoryGapAnalyzer.report(people: [elder, me, cousin], locale: .en)
        #expect(report.peopleTotal == 3)
        #expect(report.peopleWithStory == 1)
        #expect(report.coveragePercent == 33)
        #expect(report.missingStories.map(\.name) == ["Ông Nội", "Anh Họ"])
        #expect(report.prompts.first?.question.contains("childhood home") == true)
    }

    @Test func archiveOCRSuggestsNamesWithoutInventingPeople() {
        let ong = ArchivePersonName(id: UUID(), fullName: "Nguyễn Văn Sơn", nickname: "Ông Nội")
        let me = ArchivePersonName(id: UUID(), fullName: "Nguyễn Văn Quân", nickname: "Quân")
        let stranger = ArchivePersonName(id: UUID(), fullName: "Phạm Thị Lan", nickname: "Bà Ngoại")
        let hits = ArchiveNameSuggester.suggest(
            ocrLines: ["Giấy khai sinh", "Họ tên: Nguyễn Văn Sơn", "Sinh tại Huế"],
            people: [ong, me, stranger]
        )
        #expect(hits.map(\.personID) == [ong.id])
        #expect(hits.contains { $0.personID == stranger.id } == false)
    }

    @Test func graphSearchAnswersHueAndBurialQueries() {
        let hue = FamilySearchPlace(id: UUID(), name: "Nhà thời thơ ấu — Huế")
        let cemetery = FamilySearchPlace(id: UUID(), name: "Nghĩa trang Văn Điển")
        let father = FamilySearchPerson(
            id: UUID(),
            fullName: "Nguyễn Văn Ba",
            nickname: "Ba",
            kinshipTerm: "Bố",
            youCallThem: "Bố",
            kinshipCode: .father
        )
        let grandfather = FamilySearchPerson(
            id: UUID(),
            fullName: "Nguyễn Văn Sơn",
            nickname: "Ông Nội",
            kinshipTerm: "Ông nội",
            youCallThem: "Ông",
            kinshipCode: .paternalGrandfather
        )
        let context = FamilySearchContext(
            people: [father, grandfather],
            places: [hue, cemetery],
            links: [
                FamilySearchLink(personID: father.id, placeID: hue.id, role: .childhoodHome),
                FamilySearchLink(personID: grandfather.id, placeID: cemetery.id, role: .burial),
            ],
            memories: [
                FamilySearchMemory(id: UUID(), title: "Ông Nội kể chuyện Huế", body: "Sông Hương")
            ]
        )

        let lives = FamilySearch.search(query: "ai sống ở Huế?", in: context, locale: .vi)
        #expect(lives.answerHits.map(\.personID) == [father.id])

        let buried = FamilySearch.search(query: "who is buried at Văn Điển", in: context, locale: .en)
        #expect(buried.answerHits.map(\.personID) == [grandfather.id])

        let kinship = FamilySearch.search(query: "ông nội", in: context, locale: .vi)
        #expect(kinship.people.map(\.personID) == [grandfather.id])

        let place = FamilySearch.search(query: "Huế", in: context, locale: .vi)
        #expect(place.places.map(\.placeID).contains(hue.id))
        #expect(place.memories.isEmpty == false)
    }

    @Test func walkNavigatorAdvancesAfterArrival() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let first = FamilyWalkNavigator.progress(
            stopIDs: [a, b, c],
            distances: [a: 80, b: 400, c: 900]
        )
        #expect(first.currentStopID == a)
        #expect(first.isComplete == false)

        let arrived = FamilyWalkNavigator.progress(
            stopIDs: [a, b, c],
            distances: [a: 10, b: 120, c: 800]
        )
        #expect(arrived.arrivedIDs.contains(a))
        #expect(arrived.currentStopID == b)
        #expect(arrived.nextStopID == c)

        let done = FamilyWalkNavigator.progress(
            stopIDs: [a, b, c],
            distances: [a: 5, b: 8, c: 12]
        )
        #expect(done.isComplete)
        #expect(done.currentStopID == c)
    }
}
