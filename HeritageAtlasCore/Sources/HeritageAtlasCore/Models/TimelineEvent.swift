import Foundation
import SwiftData

@Model
public final class TimelineEvent {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var title: String = ""
    public var kind: TimelineEventKind = TimelineEventKind.custom
    public var memoryIDs: [UUID] = []

    public var person: Person?
    public var place: Place?

    public init(
        id: UUID = UUID(),
        person: Person? = nil,
        date: Date,
        title: String,
        kind: TimelineEventKind,
        place: Place? = nil,
        memoryIDs: [UUID] = []
    ) {
        self.id = id
        self.person = person
        self.date = date
        self.title = title
        self.kind = kind
        self.place = place
        self.memoryIDs = memoryIDs
    }
}
