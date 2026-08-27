import Foundation
import SwiftData

/// One-way primitive. `fromPerson` is the subject: A `parent` B means A is a parent of B.
/// Child is never stored; it is the inverse of parent / adoptiveParent / stepParent.
@Model
public final class KinRelationship {
    public var id: UUID = UUID()
    public var kind: KinRelationshipKind = KinRelationshipKind.parent

    public var fromPerson: Person?
    public var toPerson: Person?

    public init(
        id: UUID = UUID(),
        kind: KinRelationshipKind,
        fromPerson: Person? = nil,
        toPerson: Person? = nil
    ) {
        self.id = id
        self.kind = kind
        self.fromPerson = fromPerson
        self.toPerson = toPerson
    }

    public func asEdge() -> KinEdge? {
        guard let fromID = fromPerson?.id, let toID = toPerson?.id else { return nil }
        return KinEdge(fromID: fromID, toID: toID, kind: kind)
    }
}
