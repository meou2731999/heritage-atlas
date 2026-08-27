import Foundation
import SwiftData

@Model
public final class Person {
    public var id: UUID = UUID()
    public var fullName: String = ""
    public var nickname: String?
    public var gender: Gender = Gender.unknown
    public var birthDate: Date?
    public var deathDate: Date?
    public var occupation: String?
    public var notes: String?
    public var tags: [String] = []
    public var photoMediaID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \KinRelationship.fromPerson)
    public var outgoingRelationships: [KinRelationship]?

    @Relationship(deleteRule: .nullify, inverse: \KinRelationship.toPerson)
    public var incomingRelationships: [KinRelationship]?

    @Relationship(deleteRule: .cascade, inverse: \PersonPlace.person)
    public var personPlaces: [PersonPlace]?

    @Relationship(deleteRule: .nullify, inverse: \TimelineEvent.person)
    public var timelineEvents: [TimelineEvent]?

    public init(
        id: UUID = UUID(),
        fullName: String,
        nickname: String? = nil,
        gender: Gender = .unknown,
        birthDate: Date? = nil,
        deathDate: Date? = nil,
        occupation: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        photoMediaID: UUID? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.nickname = nickname
        self.gender = gender
        self.birthDate = birthDate
        self.deathDate = deathDate
        self.occupation = occupation
        self.notes = notes
        self.tags = tags
        self.photoMediaID = photoMediaID
        self.outgoingRelationships = []
        self.incomingRelationships = []
        self.personPlaces = []
        self.timelineEvents = []
    }

    public var isLiving: Bool { deathDate == nil }

    public func asNode() -> PersonNode {
        PersonNode(
            id: id,
            fullName: fullName,
            nickname: nickname,
            gender: gender,
            birthDate: birthDate,
            deathDate: deathDate
        )
    }
}
