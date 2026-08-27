import Foundation
import SwiftData

public enum FamilyCalendarSourceBuilder {
    @MainActor
    public static func make(
        people: [Person],
        personPlaces: [PersonPlace],
        memories: [Memory],
        events: [TimelineEvent],
        locale: KinshipLocale
    ) -> FamilyCalendarSource {
        var burialNames: [UUID: String] = [:]
        for link in personPlaces where link.role == .burial {
            if let personID = link.person?.id, let name = link.place?.name {
                burialNames[personID] = name
            }
        }

        var memoryCounts: [UUID: Int] = [:]
        var storyCounts: [UUID: Int] = [:]
        for memory in memories {
            for personID in memory.personIDs {
                memoryCounts[personID, default: 0] += 1
                if memory.kind == .story {
                    storyCounts[personID, default: 0] += 1
                }
            }
        }

        let weddings: [(personID: UUID, date: Date, placeName: String?)] = events.compactMap { event in
            guard event.kind == .married, let personID = event.person?.id else { return nil }
            return (personID, event.date, event.place?.name)
        }

        return FamilyCalendarSource(
            people: people.map { $0.asNode() },
            weddingDates: weddings,
            burialPlaceNameByPersonID: burialNames,
            memoryCountByPersonID: memoryCounts,
            storyCountByPersonID: storyCounts,
            locale: locale
        )
    }

    @MainActor
    public static func memoryGapPeople(
        people: [Person],
        personPlaces: [PersonPlace],
        memories: [Memory]
    ) -> [MemoryGapPerson] {
        people.map { person in
            let links = personPlaces.filter { $0.person?.id == person.id }
            let linkedMemories = memories.filter { $0.personIDs.contains(person.id) }
            return MemoryGapPerson(
                id: person.id,
                name: person.asNode().displayName,
                isLiving: person.isLiving,
                birthDate: person.birthDate,
                deathDate: person.deathDate,
                occupation: person.occupation,
                childhoodHomeName: links.first { $0.role == .childhoodHome }?.place?.name,
                burialPlaceName: links.first { $0.role == .burial }?.place?.name,
                hasStory: linkedMemories.contains { $0.kind == .story },
                memoryCount: linkedMemories.count
            )
        }
    }
}
