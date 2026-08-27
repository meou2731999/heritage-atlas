import Foundation
import SwiftData

@Model
public final class FamilyWalk {
    public var id: UUID = UUID()
    public var title: String = ""
    /// Ordered place IDs. Stored as an array so CloudKit does not need an ordered relationship.
    public var stopIDs: [UUID] = []
    public var notes: String?

    public init(
        id: UUID = UUID(),
        title: String,
        stopIDs: [UUID] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.stopIDs = stopIDs
        self.notes = notes
    }
}
