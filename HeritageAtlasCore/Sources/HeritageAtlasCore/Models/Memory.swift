import Foundation
import SwiftData

@Model
public final class Memory {
    public var id: UUID = UUID()
    public var kind: MemoryKind = MemoryKind.text
    public var title: String = ""
    public var occurredOn: Date?
    public var body: String = ""
    /// CloudKit-safe many-to-many: store IDs instead of a relationship.
    public var personIDs: [UUID] = []
    public var placeIDs: [UUID] = []
    public var timelineEventID: UUID?
    public var mediaIDs: [UUID] = []
    public var isFeatured: Bool = false
    /// Set when the audio arrived from Apple Watch so iPhone can ask for a person if needed.
    public var isFromWatch: Bool = false

    public init(
        id: UUID = UUID(),
        kind: MemoryKind,
        title: String,
        occurredOn: Date? = nil,
        body: String = "",
        personIDs: [UUID] = [],
        placeIDs: [UUID] = [],
        timelineEventID: UUID? = nil,
        mediaIDs: [UUID] = [],
        isFeatured: Bool = false,
        isFromWatch: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.occurredOn = occurredOn
        self.body = body
        self.personIDs = personIDs
        self.placeIDs = placeIDs
        self.timelineEventID = timelineEventID
        self.mediaIDs = mediaIDs
        self.isFeatured = isFeatured
        self.isFromWatch = isFromWatch
    }
}
