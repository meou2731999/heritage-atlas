import Foundation
import SwiftData

public struct WatchSnapshot: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var mePersonID: UUID?
    public var localeKinship: KinshipLocale
    public var favorites: [WatchPerson]
    public var recents: [WatchPerson]
    /// All named people in the family. Optional so snapshots packed before this field still decode.
    public var people: [WatchPerson]?
    public var relationshipCache: [WatchRelationship]
    public var nearbyPlaces: [WatchPlace]
    public var burialPlaces: [WatchPlace]
    public var cemeteryPins: [WatchPlace]
    public var currentWalk: WatchFamilyWalk?
    public var featuredMemories: [WatchMemory]
    /// A few important life moments for swipe-glance. Optional so older snapshots still decode.
    public var timelineMoments: [WatchTimelineMoment]?
    /// Packed only when memorial reminders are opted in. Watch filters to today's month/day.
    public var todayEvents: [WatchCalendarEvent]?
    public var insightsGlance: WatchInsightsGlance?
    public var memorialRemindersEnabled: Bool?

    public init(
        generatedAt: Date = Date(),
        mePersonID: UUID? = nil,
        localeKinship: KinshipLocale = .vi,
        favorites: [WatchPerson] = [],
        recents: [WatchPerson] = [],
        people: [WatchPerson]? = nil,
        relationshipCache: [WatchRelationship] = [],
        nearbyPlaces: [WatchPlace] = [],
        burialPlaces: [WatchPlace] = [],
        cemeteryPins: [WatchPlace] = [],
        currentWalk: WatchFamilyWalk? = nil,
        featuredMemories: [WatchMemory] = [],
        timelineMoments: [WatchTimelineMoment]? = nil,
        todayEvents: [WatchCalendarEvent]? = nil,
        insightsGlance: WatchInsightsGlance? = nil,
        memorialRemindersEnabled: Bool? = nil
    ) {
        self.generatedAt = generatedAt
        self.mePersonID = mePersonID
        self.localeKinship = localeKinship
        self.favorites = favorites
        self.recents = recents
        self.people = people
        self.relationshipCache = relationshipCache
        self.nearbyPlaces = nearbyPlaces
        self.burialPlaces = burialPlaces
        self.cemeteryPins = cemeteryPins
        self.currentWalk = currentWalk
        self.featuredMemories = featuredMemories
        self.timelineMoments = timelineMoments
        self.todayEvents = todayEvents
        self.insightsGlance = insightsGlance
        self.memorialRemindersEnabled = memorialRemindersEnabled
    }
}

public struct WatchInsightsGlance: Codable, Sendable, Equatable {
    public var livingCount: Int
    public var generationCount: Int

    public init(livingCount: Int, generationCount: Int) {
        self.livingCount = livingCount
        self.generationCount = generationCount
    }
}

public struct WatchCalendarEvent: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var kind: FamilyCalendarKind
    public var personID: UUID?
    public var personName: String
    public var title: String
    public var month: Int
    public var day: Int
    public var years: Int?

    public init(
        id: UUID,
        kind: FamilyCalendarKind,
        personID: UUID? = nil,
        personName: String,
        title: String,
        month: Int,
        day: Int,
        years: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.personID = personID
        self.personName = personName
        self.title = title
        self.month = month
        self.day = day
        self.years = years
    }
}

public struct WatchPerson: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var fullName: String
    public var nickname: String?
    public var gender: Gender
    public var isFavorite: Bool
    public var thumbnailRelativePath: String?

    public init(
        id: UUID,
        fullName: String,
        nickname: String? = nil,
        gender: Gender = .unknown,
        isFavorite: Bool = false,
        thumbnailRelativePath: String? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.nickname = nickname
        self.gender = gender
        self.isFavorite = isFavorite
        self.thumbnailRelativePath = thumbnailRelativePath
    }

    public var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        return fullName
    }
}

public struct WatchRelationship: Codable, Sendable, Equatable, Identifiable {
    public var personID: UUID
    public var pathGlance: String
    public var pathExplanation: String
    public var term: String
    public var youCallThem: String
    public var theyCallYou: String
    public var code: KinshipCode

    public var id: UUID { personID }

    public init(
        personID: UUID,
        pathGlance: String,
        pathExplanation: String,
        term: String,
        youCallThem: String,
        theyCallYou: String,
        code: KinshipCode
    ) {
        self.personID = personID
        self.pathGlance = pathGlance
        self.pathExplanation = pathExplanation
        self.term = term
        self.youCallThem = youCallThem
        self.theyCallYou = theyCallYou
        self.code = code
    }
}

public struct WatchPlace: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var latitude: Double?
    public var longitude: Double?
    public var role: PlaceRole?
    public var personIDs: [UUID]

    public init(
        id: UUID,
        name: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        role: PlaceRole? = nil,
        personIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.role = role
        self.personIDs = personIDs
    }
}

public struct WatchFamilyWalk: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var title: String
    public var stopIDs: [UUID]
    /// Resolved places in walk order. Optional so older snapshots still decode.
    public var stops: [WatchPlace]?
    /// One story or memory per stop when iPhone had one linked.
    public var stopMemories: [WatchMemory]?

    public init(
        id: UUID,
        title: String,
        stopIDs: [UUID],
        stops: [WatchPlace]? = nil,
        stopMemories: [WatchMemory]? = nil
    ) {
        self.id = id
        self.title = title
        self.stopIDs = stopIDs
        self.stops = stops
        self.stopMemories = stopMemories
    }
}

public struct WatchMemory: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var personID: UUID?
    public var title: String
    public var kind: MemoryKind
    public var thumbnailRelativePath: String?
    public var audioRelativePath: String?
    public var durationSeconds: Double?
    public var occurredOn: Date?
    public var personName: String?
    public var bodyPreview: String?
    public var placeID: UUID?

    public init(
        id: UUID,
        personID: UUID? = nil,
        title: String,
        kind: MemoryKind,
        thumbnailRelativePath: String? = nil,
        audioRelativePath: String? = nil,
        durationSeconds: Double? = nil,
        occurredOn: Date? = nil,
        personName: String? = nil,
        bodyPreview: String? = nil,
        placeID: UUID? = nil
    ) {
        self.id = id
        self.personID = personID
        self.title = title
        self.kind = kind
        self.thumbnailRelativePath = thumbnailRelativePath
        self.audioRelativePath = audioRelativePath
        self.durationSeconds = durationSeconds
        self.occurredOn = occurredOn
        self.personName = personName
        self.bodyPreview = bodyPreview
        self.placeID = placeID
    }
}

/// A compact life-moment card. Watch never receives a full timeline.
public struct WatchTimelineMoment: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var personID: UUID
    public var personName: String
    public var date: Date
    public var title: String
    public var kind: TimelineEventKind
    public var placeName: String?
    public var memoryTitle: String?
    public var isSynthesized: Bool

    public init(
        id: UUID,
        personID: UUID,
        personName: String,
        date: Date,
        title: String,
        kind: TimelineEventKind,
        placeName: String? = nil,
        memoryTitle: String? = nil,
        isSynthesized: Bool = false
    ) {
        self.id = id
        self.personID = personID
        self.personName = personName
        self.date = date
        self.title = title
        self.kind = kind
        self.placeName = placeName
        self.memoryTitle = memoryTitle
        self.isSynthesized = isSynthesized
    }
}

/// Watch → iPhone inbound (Phase 3 wiring; schema exists now).
public struct WatchAudioRecordingMessage: Codable, Sendable, Equatable {
    public var fileName: String
    public var personID: UUID?
    public var recordedAt: Date

    public init(fileName: String, personID: UUID? = nil, recordedAt: Date = Date()) {
        self.fileName = fileName
        self.personID = personID
        self.recordedAt = recordedAt
    }
}

@Model
public final class WatchSnapshotEnvelope {
    public var id: UUID = UUID()
    public var generatedAt: Date = Date()
    public var payload: Data = Data()

    public init(id: UUID = UUID(), snapshot: WatchSnapshot) {
        self.id = id
        self.generatedAt = snapshot.generatedAt
        self.payload = (try? JSONEncoder().encode(snapshot)) ?? Data()
    }

    public func snapshot() throws -> WatchSnapshot {
        try JSONDecoder().decode(WatchSnapshot.self, from: payload)
    }
}
