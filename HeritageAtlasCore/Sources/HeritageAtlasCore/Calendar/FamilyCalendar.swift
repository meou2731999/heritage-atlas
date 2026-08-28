import Foundation

public enum FamilyCalendarKind: String, Codable, Sendable, CaseIterable {
    case birthday
    case deathAnniversary
    case wedding

    public func localizedName(_ locale: KinshipLocale) -> String {
        switch (self, locale) {
        case (.birthday, .vi): "Sinh nhật"
        case (.birthday, .en): "Birthday"
        case (.deathAnniversary, .vi): "Giỗ"
        case (.deathAnniversary, .en): "Memorial"
        case (.wedding, .vi): "Ngày cưới"
        case (.wedding, .en): "Wedding"
        }
    }

    public var systemImageName: String {
        switch self {
        case .birthday: "gift"
        case .deathAnniversary: "leaf"
        case .wedding: "heart"
        }
    }
}

public struct FamilyCalendarEvent: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var kind: FamilyCalendarKind
    public var personID: UUID?
    public var personName: String
    public var originalDate: Date
    public var nextDate: Date
    public var years: Int?
    public var placeName: String?
    public var title: String
    public var subtitle: String

    public init(
        id: UUID = UUID(),
        kind: FamilyCalendarKind,
        personID: UUID? = nil,
        personName: String,
        originalDate: Date,
        nextDate: Date,
        years: Int? = nil,
        placeName: String? = nil,
        title: String,
        subtitle: String
    ) {
        self.id = id
        self.kind = kind
        self.personID = personID
        self.personName = personName
        self.originalDate = originalDate
        self.nextDate = nextDate
        self.years = years
        self.placeName = placeName
        self.title = title
        self.subtitle = subtitle
    }

    public var month: Int {
        Calendar(identifier: .gregorian).component(.month, from: originalDate)
    }

    public var day: Int {
        Calendar(identifier: .gregorian).component(.day, from: originalDate)
    }

    public var watchEvent: WatchCalendarEvent {
        WatchCalendarEvent(
            id: id,
            kind: kind,
            personID: personID,
            personName: personName,
            title: title,
            month: month,
            day: day,
            years: years
        )
    }
}

public struct FamilyMemorialSummary: Sendable, Equatable {
    public var personID: UUID
    public var personName: String
    public var deathDate: Date?
    public var burialPlaceName: String?
    public var rememberedByCount: Int
    public var storyCount: Int

    public init(
        personID: UUID,
        personName: String,
        deathDate: Date?,
        burialPlaceName: String?,
        rememberedByCount: Int,
        storyCount: Int
    ) {
        self.personID = personID
        self.personName = personName
        self.deathDate = deathDate
        self.burialPlaceName = burialPlaceName
        self.rememberedByCount = rememberedByCount
        self.storyCount = storyCount
    }
}

public struct FamilyCalendarSource: Sendable {
    public var people: [PersonNode]
    public var weddingDates: [(personID: UUID, date: Date, placeName: String?)]
    public var burialPlaceNameByPersonID: [UUID: String]
    public var memoryCountByPersonID: [UUID: Int]
    public var storyCountByPersonID: [UUID: Int]
    public var locale: KinshipLocale

    public init(
        people: [PersonNode],
        weddingDates: [(personID: UUID, date: Date, placeName: String?)] = [],
        burialPlaceNameByPersonID: [UUID: String] = [:],
        memoryCountByPersonID: [UUID: Int] = [:],
        storyCountByPersonID: [UUID: Int] = [:],
        locale: KinshipLocale = .en
    ) {
        self.people = people
        self.weddingDates = weddingDates
        self.burialPlaceNameByPersonID = burialPlaceNameByPersonID
        self.memoryCountByPersonID = memoryCountByPersonID
        self.storyCountByPersonID = storyCountByPersonID
        self.locale = locale
    }
}

public enum FamilyCalendar: Sendable {
    public static func events(
        from source: FamilyCalendarSource,
        now: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [FamilyCalendarEvent] {
        var events: [FamilyCalendarEvent] = []
        let peopleByID = Dictionary(uniqueKeysWithValues: source.people.map { ($0.id, $0) })

        for person in source.people {
            if let birth = person.birthDate, person.isLiving {
                events.append(
                    makeEvent(
                        kind: .birthday,
                        person: person,
                        original: birth,
                        now: now,
                        calendar: calendar,
                        locale: source.locale,
                        placeName: nil
                    )
                )
            }
            if let death = person.deathDate {
                events.append(
                    makeEvent(
                        kind: .deathAnniversary,
                        person: person,
                        original: death,
                        now: now,
                        calendar: calendar,
                        locale: source.locale,
                        placeName: source.burialPlaceNameByPersonID[person.id]
                    )
                )
            }
        }

        for wedding in source.weddingDates {
            guard let person = peopleByID[wedding.personID] else { continue }
            events.append(
                makeEvent(
                    kind: .wedding,
                    person: person,
                    original: wedding.date,
                    now: now,
                    calendar: calendar,
                    locale: source.locale,
                    placeName: wedding.placeName
                )
            )
        }

        return events.sorted { lhs, rhs in
            if lhs.nextDate != rhs.nextDate { return lhs.nextDate < rhs.nextDate }
            return lhs.personName.localizedStandardCompare(rhs.personName) == .orderedAscending
        }
    }

    public static func occurring(
        on day: Date,
        in events: [FamilyCalendarEvent],
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [FamilyCalendarEvent] {
        events.filter { calendar.isDate($0.nextDate, inSameDayAs: day) }
    }

    public static func upcoming(
        from now: Date,
        days: Int,
        in events: [FamilyCalendarEvent],
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [FamilyCalendarEvent] {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: days, to: start) else { return [] }
        return events.filter { $0.nextDate >= start && $0.nextDate < end }
    }

    public static func memorialSummaries(from source: FamilyCalendarSource) -> [FamilyMemorialSummary] {
        source.people
            .filter { $0.isLiving == false }
            .map { person in
                FamilyMemorialSummary(
                    personID: person.id,
                    personName: person.displayName,
                    deathDate: person.deathDate,
                    burialPlaceName: source.burialPlaceNameByPersonID[person.id],
                    rememberedByCount: source.memoryCountByPersonID[person.id] ?? 0,
                    storyCount: source.storyCountByPersonID[person.id] ?? 0
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.deathDate, rhs.deathDate) {
                case (let left?, let right?) where left != right:
                    return left > right
                default:
                    return lhs.personName.localizedStandardCompare(rhs.personName) == .orderedAscending
                }
            }
    }

    public static func nextOccurrence(
        of original: Date,
        from now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date {
        let monthDay = calendar.dateComponents([.month, .day], from: original)
        var components = calendar.dateComponents([.year], from: now)
        components.month = monthDay.month
        components.day = monthDay.day
        let today = calendar.startOfDay(for: now)
        if let candidate = calendar.date(from: components) {
            let start = calendar.startOfDay(for: candidate)
            if calendar.compare(start, to: today, toGranularity: .day) != .orderedAscending {
                return start
            }
        }
        components.year = (components.year ?? 0) + 1
        return calendar.startOfDay(for: calendar.date(from: components) ?? now)
    }

    private static func makeEvent(
        kind: FamilyCalendarKind,
        person: PersonNode,
        original: Date,
        now: Date,
        calendar: Calendar,
        locale: KinshipLocale,
        placeName: String?
    ) -> FamilyCalendarEvent {
        let next = nextOccurrence(of: original, from: now, calendar: calendar)
        let years = calendar.dateComponents([.year], from: original, to: next).year
        let title: String
        let subtitle: String
        switch kind {
        case .birthday:
            title = person.displayName
            if let years {
                subtitle = HeritageLocale.string("Birthday · turns \(years)", locale: locale)
            } else {
                subtitle = kind.localizedName(locale)
            }
        case .deathAnniversary:
            title = person.displayName
            if let years {
                subtitle = HeritageLocale.string("Memorial · \(years) years", locale: locale)
            } else {
                subtitle = kind.localizedName(locale)
            }
        case .wedding:
            title = person.displayName
            if let years {
                subtitle = HeritageLocale.string("Wedding · \(years) years", locale: locale)
            } else {
                subtitle = kind.localizedName(locale)
            }
        }
        let extra = placeName.map { subtitle + " · " + $0 } ?? subtitle
        return FamilyCalendarEvent(
            kind: kind,
            personID: person.id,
            personName: person.displayName,
            originalDate: original,
            nextDate: next,
            years: years,
            placeName: placeName,
            title: title,
            subtitle: extra
        )
    }
}
