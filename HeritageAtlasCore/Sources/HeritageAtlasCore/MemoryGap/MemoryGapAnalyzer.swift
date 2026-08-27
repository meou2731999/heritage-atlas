import Foundation

public struct MemoryGapPerson: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var isLiving: Bool
    public var birthDate: Date?
    public var deathDate: Date?
    public var occupation: String?
    public var childhoodHomeName: String?
    public var burialPlaceName: String?
    public var hasStory: Bool
    public var memoryCount: Int

    public init(
        id: UUID,
        name: String,
        isLiving: Bool,
        birthDate: Date? = nil,
        deathDate: Date? = nil,
        occupation: String? = nil,
        childhoodHomeName: String? = nil,
        burialPlaceName: String? = nil,
        hasStory: Bool,
        memoryCount: Int
    ) {
        self.id = id
        self.name = name
        self.isLiving = isLiving
        self.birthDate = birthDate
        self.deathDate = deathDate
        self.occupation = occupation
        self.childhoodHomeName = childhoodHomeName
        self.burialPlaceName = burialPlaceName
        self.hasStory = hasStory
        self.memoryCount = memoryCount
    }
}

public struct MemoryPrompt: Sendable, Equatable, Identifiable {
    public var id: UUID { personID }
    public var personID: UUID
    public var personName: String
    public var question: String

    public init(personID: UUID, personName: String, question: String) {
        self.personID = personID
        self.personName = personName
        self.question = question
    }
}

public struct MemoryGapReport: Sendable, Equatable {
    public var peopleTotal: Int
    public var peopleWithStory: Int
    public var coveragePercent: Int
    public var missingStories: [MemoryGapPerson]
    public var prompts: [MemoryPrompt]

    public init(
        peopleTotal: Int,
        peopleWithStory: Int,
        coveragePercent: Int,
        missingStories: [MemoryGapPerson],
        prompts: [MemoryPrompt]
    ) {
        self.peopleTotal = peopleTotal
        self.peopleWithStory = peopleWithStory
        self.coveragePercent = coveragePercent
        self.missingStories = missingStories
        self.prompts = prompts
    }
}

public enum MemoryGapAnalyzer: Sendable {
    public static func report(
        people: [MemoryGapPerson],
        locale: KinshipLocale = .en,
        promptLimit: Int = 6
    ) -> MemoryGapReport {
        let withStory = people.filter(\.hasStory)
        let missing = people
            .filter { $0.hasStory == false }
            .sorted { lhs, rhs in
                switch (lhs.isLiving, rhs.isLiving) {
                case (false, true): return true
                case (true, false): return false
                default: break
                }
                switch (lhs.birthDate, rhs.birthDate) {
                case (let left?, let right?) where left != right:
                    return left < right
                default:
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            }
        let percent: Int
        if people.isEmpty {
            percent = 0
        } else {
            percent = Int((Double(withStory.count) / Double(people.count) * 100).rounded())
        }
        let prompts = missing.prefix(promptLimit).map { person in
            MemoryPrompt(
                personID: person.id,
                personName: person.name,
                question: prompt(for: person, locale: locale)
            )
        }
        return MemoryGapReport(
            peopleTotal: people.count,
            peopleWithStory: withStory.count,
            coveragePercent: percent,
            missingStories: missing,
            prompts: Array(prompts)
        )
    }

    public static func prompt(for person: MemoryGapPerson, locale: KinshipLocale) -> String {
        if let home = person.childhoodHomeName, home.isEmpty == false {
            return locale == .vi
                ? "Nhà thời thơ ấu của \(person.name) ở \(home) như thế nào?"
                : "What was \(person.name)’s childhood home in \(home) like?"
        }
        if let occupation = person.occupation, occupation.isEmpty == false {
            return locale == .vi
                ? "Kể một chuyện về thời \(person.name) làm \(occupation)."
                : "Tell a story from when \(person.name) was a \(occupation)."
        }
        if person.isLiving == false, let burial = person.burialPlaceName, burial.isEmpty == false {
            return locale == .vi
                ? "Bạn nhớ gì mỗi lần ra \(burial) thăm \(person.name)?"
                : "What do you remember from visits to \(burial) for \(person.name)?"
        }
        if person.isLiving == false {
            return locale == .vi
                ? "Câu chuyện nào về \(person.name) chỉ bạn mới biết?"
                : "What’s a story only you know about \(person.name)?"
        }
        return locale == .vi
            ? "Ghi một câu chuyện về \(person.name) trước khi quên."
            : "Record a story about \(person.name) before it’s forgotten."
    }
}
