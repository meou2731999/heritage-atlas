import Foundation
import SwiftData

@Model
public final class PersonPlace {
    public var id: UUID = UUID()
    public var role: PlaceRole = PlaceRole.home
    public var yearFrom: Int?
    public var yearTo: Int?

    public var person: Person?
    public var place: Place?

    public init(
        id: UUID = UUID(),
        role: PlaceRole,
        person: Person? = nil,
        place: Place? = nil,
        yearFrom: Int? = nil,
        yearTo: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.person = person
        self.place = place
        self.yearFrom = yearFrom
        self.yearTo = yearTo
    }
}
