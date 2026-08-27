import Foundation

public struct FamilySearchPerson: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var fullName: String
    public var nickname: String?
    public var occupation: String?
    public var tags: [String]
    public var kinshipTerm: String?
    public var youCallThem: String?
    public var theyCallYou: String?
    public var kinshipCode: KinshipCode?

    public init(
        id: UUID,
        fullName: String,
        nickname: String? = nil,
        occupation: String? = nil,
        tags: [String] = [],
        kinshipTerm: String? = nil,
        youCallThem: String? = nil,
        theyCallYou: String? = nil,
        kinshipCode: KinshipCode? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.nickname = nickname
        self.occupation = occupation
        self.tags = tags
        self.kinshipTerm = kinshipTerm
        self.youCallThem = youCallThem
        self.theyCallYou = theyCallYou
        self.kinshipCode = kinshipCode
    }

    public var displayName: String {
        if let nickname, nickname.isEmpty == false { return nickname }
        return fullName
    }
}

public struct FamilySearchPlace: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var notes: String?

    public init(id: UUID, name: String, notes: String? = nil) {
        self.id = id
        self.name = name
        self.notes = notes
    }
}

public struct FamilySearchLink: Sendable, Equatable {
    public var personID: UUID
    public var placeID: UUID
    public var role: PlaceRole

    public init(personID: UUID, placeID: UUID, role: PlaceRole) {
        self.personID = personID
        self.placeID = placeID
        self.role = role
    }
}

public struct FamilySearchMemory: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var title: String
    public var body: String
    public var personIDs: [UUID]
    public var placeIDs: [UUID]

    public init(id: UUID, title: String, body: String = "", personIDs: [UUID] = [], placeIDs: [UUID] = []) {
        self.id = id
        self.title = title
        self.body = body
        self.personIDs = personIDs
        self.placeIDs = placeIDs
    }
}

public struct FamilySearchContext: Sendable {
    public var people: [FamilySearchPerson]
    public var places: [FamilySearchPlace]
    public var links: [FamilySearchLink]
    public var memories: [FamilySearchMemory]
    public var herePlaceID: UUID?

    public init(
        people: [FamilySearchPerson],
        places: [FamilySearchPlace] = [],
        links: [FamilySearchLink] = [],
        memories: [FamilySearchMemory] = [],
        herePlaceID: UUID? = nil
    ) {
        self.people = people
        self.places = places
        self.links = links
        self.memories = memories
        self.herePlaceID = herePlaceID
    }
}

public enum FamilySearchHitKind: String, Sendable {
    case person
    case place
    case memory
}

public struct FamilySearchHit: Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: FamilySearchHitKind
    public var title: String
    public var subtitle: String
    public var personID: UUID?
    public var placeID: UUID?
    public var memoryID: UUID?

    public init(
        kind: FamilySearchHitKind,
        title: String,
        subtitle: String,
        personID: UUID? = nil,
        placeID: UUID? = nil,
        memoryID: UUID? = nil
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.personID = personID
        self.placeID = placeID
        self.memoryID = memoryID
        switch kind {
        case .person: self.id = "person-\(personID?.uuidString ?? title)"
        case .place: self.id = "place-\(placeID?.uuidString ?? title)"
        case .memory: self.id = "memory-\(memoryID?.uuidString ?? title)"
        }
    }
}

public struct FamilySearchResult: Sendable, Equatable {
    public var answerTitle: String?
    public var answerHits: [FamilySearchHit]
    public var people: [FamilySearchHit]
    public var places: [FamilySearchHit]
    public var memories: [FamilySearchHit]

    public init(
        answerTitle: String? = nil,
        answerHits: [FamilySearchHit] = [],
        people: [FamilySearchHit] = [],
        places: [FamilySearchHit] = [],
        memories: [FamilySearchHit] = []
    ) {
        self.answerTitle = answerTitle
        self.answerHits = answerHits
        self.people = people
        self.places = places
        self.memories = memories
    }

    public var isEmpty: Bool {
        answerHits.isEmpty && people.isEmpty && places.isEmpty && memories.isEmpty
    }
}

public enum FamilySearch: Sendable {
    private static let liveRoles: Set<PlaceRole> = [.home, .childhoodHome, .born]
    private static let burialRoles: Set<PlaceRole> = [.burial]

    public static func search(
        query: String,
        in context: FamilySearchContext,
        locale: KinshipLocale = .en
    ) -> FamilySearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return FamilySearchResult(
                people: context.people.map(personHit)
            )
        }

        if let structured = structuredQuery(trimmed, in: context, locale: locale) {
            return structured
        }

        let needle = TextNormalize.folded(trimmed)
        let people = context.people.filter { matches($0, needle: needle) }.map(personHit)
        let places = context.places.filter { matches($0, needle: needle) }.map(placeHit)
        let memories = context.memories.filter { matches($0, needle: needle) }.map(memoryHit)
        return FamilySearchResult(people: people, places: places, memories: memories)
    }

    private static func structuredQuery(
        _ query: String,
        in context: FamilySearchContext,
        locale: KinshipLocale
    ) -> FamilySearchResult? {
        let folded = TextNormalize.folded(query)

        if let placeHint = livingQueryPlace(from: folded) {
            return answer(
                title: locale == .vi ? "Ai sống ở đây?" : "Who lives here?",
                roles: liveRoles,
                placeHint: placeHint,
                in: context,
                empty: locale == .vi ? "Không thấy ai gắn với nơi này." : "No one is linked to this place."
            )
        }

        if let placeHint = burialQueryPlace(from: folded) {
            return answer(
                title: locale == .vi ? "Ai được chôn ở đây?" : "Who is buried here?",
                roles: burialRoles,
                placeHint: placeHint,
                in: context,
                empty: locale == .vi ? "Chưa có chỗ an táng khớp." : "No burial matches this place."
            )
        }

        if let kinship = kinshipMatches(folded, in: context) {
            let title = locale == .vi ? "Xưng hô" : "Kinship"
            return FamilySearchResult(
                answerTitle: title,
                answerHits: kinship,
                people: kinship
            )
        }

        return nil
    }

    private static func answer(
        title: String,
        roles: Set<PlaceRole>,
        placeHint: String,
        in context: FamilySearchContext,
        empty: String
    ) -> FamilySearchResult {
        let places = matchingPlaces(hint: placeHint, in: context)
        let placeIDs = Set(places.map(\.id))
        let peopleByID = Dictionary(uniqueKeysWithValues: context.people.map { ($0.id, $0) })
        var seen = Set<UUID>()
        var hits: [FamilySearchHit] = []
        for link in context.links where roles.contains(link.role) && placeIDs.contains(link.placeID) {
            guard seen.insert(link.personID).inserted, let person = peopleByID[link.personID] else { continue }
            let placeName = places.first { $0.id == link.placeID }?.name ?? ""
            hits.append(
                FamilySearchHit(
                    kind: .person,
                    title: person.displayName,
                    subtitle: "\(link.role.localizedName(.en)) · \(placeName)",
                    personID: person.id
                )
            )
        }
        if hits.isEmpty {
            hits = [
                FamilySearchHit(kind: .person, title: empty, subtitle: "")
            ]
        }
        return FamilySearchResult(
            answerTitle: title,
            answerHits: hits.filter { $0.personID != nil },
            people: hits.filter { $0.personID != nil },
            places: places.map(placeHit)
        )
    }

    private static func matchingPlaces(hint: String, in context: FamilySearchContext) -> [FamilySearchPlace] {
        if hint == "here" || hint == "day" || hint == "nay" {
            if let here = context.herePlaceID {
                return context.places.filter { $0.id == here }
            }
            return context.places
        }
        return context.places.filter { TextNormalize.contains($0.name, needle: hint) }
    }

    private static func livingQueryPlace(from folded: String) -> String? {
        let patterns = [
            "ai song o ",
            "ai song tai ",
            "song o ",
            "who lives in ",
            "who lived in ",
            "who lives at ",
            "who lived at ",
        ]
        return capturePlace(from: folded, prefixes: patterns)
    }

    private static func burialQueryPlace(from folded: String) -> String? {
        let patterns = [
            "ai duoc chon o ",
            "ai duoc chon tai ",
            "ai chon o ",
            "ai an tang o ",
            "chon o ",
            "who is buried in ",
            "who is buried at ",
            "who was buried in ",
            "who was buried at ",
            "buried in ",
            "buried at ",
            "buried here",
        ]
        if folded.contains("buried here") || folded.contains("chon o day") || folded.contains("an tang o day") {
            return "here"
        }
        return capturePlace(from: folded, prefixes: patterns)
    }

    private static func capturePlace(from folded: String, prefixes: [String]) -> String? {
        for prefix in prefixes {
            guard let range = folded.range(of: prefix) else { continue }
            let rest = String(folded[range.upperBound...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "?¿. "))
            if rest.isEmpty { return "here" }
            if rest.hasPrefix("day") || rest == "here" { return "here" }
            return rest
        }
        return nil
    }

    private static func kinshipMatches(_ folded: String, in context: FamilySearchContext) -> [FamilySearchHit]? {
        let aliases = kinshipAliases
        var codes: Set<KinshipCode> = []
        for (alias, code) in aliases where folded == alias || folded.contains(alias) && alias.count >= 3 {
            codes.insert(code)
        }
        let hits = context.people.compactMap { person -> FamilySearchHit? in
            if let term = person.kinshipTerm, TextNormalize.folded(term) == folded {
                return personHit(person)
            }
            if let you = person.youCallThem, TextNormalize.folded(you) == folded {
                return personHit(person)
            }
            if let code = person.kinshipCode, codes.contains(code) {
                return personHit(person)
            }
            return nil
        }
        return hits.isEmpty ? nil : hits
    }

    private static var kinshipAliases: [(String, KinshipCode)] {
        [
            ("ong noi", .paternalGrandfather),
            ("ba noi", .paternalGrandmother),
            ("ong ngoai", .maternalGrandfather),
            ("ba ngoai", .maternalGrandmother),
            ("grandfather", .grandfather),
            ("grandmother", .grandmother),
            ("paternal grandfather", .paternalGrandfather),
            ("bo", .father),
            ("ba", .father),
            ("father", .father),
            ("me", .mother),
            ("mother", .mother),
            ("chu", .paternalUncleYounger),
            ("bac", .paternalUncleOlder),
            ("cau", .maternalUncle),
            ("co", .paternalAunt),
            ("di", .maternalAunt),
            ("uncle", .uncle),
            ("aunt", .aunt),
            ("anh", .olderBrother),
            ("chi", .olderSister),
            ("em", .sibling),
        ]
    }

    private static func matches(_ person: FamilySearchPerson, needle: String) -> Bool {
        if TextNormalize.folded(person.fullName).contains(needle) { return true }
        if let nickname = person.nickname, TextNormalize.folded(nickname).contains(needle) { return true }
        if let occupation = person.occupation, TextNormalize.folded(occupation).contains(needle) { return true }
        if person.tags.contains(where: { TextNormalize.folded($0).contains(needle) }) { return true }
        if let term = person.kinshipTerm, TextNormalize.folded(term).contains(needle) { return true }
        if let you = person.youCallThem, TextNormalize.folded(you).contains(needle) { return true }
        return false
    }

    private static func matches(_ place: FamilySearchPlace, needle: String) -> Bool {
        if TextNormalize.folded(place.name).contains(needle) { return true }
        if let notes = place.notes, TextNormalize.folded(notes).contains(needle) { return true }
        return false
    }

    private static func matches(_ memory: FamilySearchMemory, needle: String) -> Bool {
        TextNormalize.folded(memory.title).contains(needle)
            || TextNormalize.folded(memory.body).contains(needle)
    }

    private static func personHit(_ person: FamilySearchPerson) -> FamilySearchHit {
        FamilySearchHit(
            kind: .person,
            title: person.displayName,
            subtitle: person.kinshipTerm ?? person.occupation ?? person.fullName,
            personID: person.id
        )
    }

    private static func placeHit(_ place: FamilySearchPlace) -> FamilySearchHit {
        FamilySearchHit(
            kind: .place,
            title: place.name,
            subtitle: place.notes ?? "",
            placeID: place.id
        )
    }

    private static func memoryHit(_ memory: FamilySearchMemory) -> FamilySearchHit {
        FamilySearchHit(
            kind: .memory,
            title: memory.title.isEmpty ? "Untitled" : memory.title,
            subtitle: String(memory.body.prefix(80)),
            memoryID: memory.id
        )
    }
}
