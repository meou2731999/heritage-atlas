import Foundation
import SwiftData

@Model
public final class Place {
    public var id: UUID = UUID()
    public var name: String = ""
    public var latitude: Double?
    public var longitude: Double?
    public var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \PersonPlace.place)
    public var personPlaces: [PersonPlace]?

    @Relationship(deleteRule: .nullify, inverse: \TimelineEvent.place)
    public var timelineEvents: [TimelineEvent]?

    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.notes = notes
        self.personPlaces = []
        self.timelineEvents = []
    }

    public var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }
}
