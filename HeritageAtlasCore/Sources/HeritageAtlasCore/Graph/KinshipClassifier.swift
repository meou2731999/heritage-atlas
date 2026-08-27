import Foundation

public enum KinshipCode: String, Codable, Sendable, CaseIterable {
    case `self`

    case father, mother, parent
    case adoptiveFather, adoptiveMother, adoptiveParent
    case stepFather, stepMother, stepParent

    case son, daughter, child
    case adoptedSon, adoptedDaughter, adoptedChild
    case stepSon, stepDaughter, stepChild

    case husband, wife, spouse, partner

    case olderBrother, youngerBrother, brother
    case olderSister, youngerSister, sister
    case sibling

    case paternalGrandfather, paternalGrandmother
    case maternalGrandfather, maternalGrandmother
    case grandfather, grandmother, grandparent

    case grandson, granddaughter, grandchild

    case greatGrandfather, greatGrandmother, greatGrandparent
    case greatGrandson, greatGranddaughter, greatGrandchild

    case paternalUncleOlder, paternalUncleYounger, paternalUncle
    case paternalAunt
    case maternalUncle
    case maternalAunt
    case uncle, aunt

    case paternalUncleWifeOlder
    case paternalUncleWifeYounger
    case paternalAuntHusband
    case maternalUncleWife
    case maternalAuntHusband

    case nephew, niece, nibling

    case firstCousin
    case firstCousinOnceRemoved
    case secondCousin
    case cousin

    case fatherInLaw, motherInLaw
    case sonInLaw, daughterInLaw
    case brotherInLaw, sisterInLaw
    case siblingInLaw

    case stepSibling
    case greatUncle, greatAunt
    case distantRelative
    case unknown
}

public struct ClassifiedRelationship: Sendable, Equatable {
    public var fromID: UUID
    public var toID: UUID
    public var path: KinPath
    public var people: [PersonNode]
    public var hops: [GraphHop]
    public var code: KinshipCode
    public var generationDelta: Int
    public var isPaternal: Bool?
    public var isMaternal: Bool?
    public var targetIsOlder: Bool?

    public var fromPerson: PersonNode? { people.first }
    public var toPerson: PersonNode? { people.last }
}

public enum KinshipClassifier: Sendable {
    public static func classify(path: KinPath, graph: RelationshipGraph) -> ClassifiedRelationship {
        let people = path.personIDs.compactMap { graph.person($0) }
        let hops = path.hops
        let fromID = path.personIDs.first ?? UUID()
        let toID = path.personIDs.last ?? fromID
        let generation = hops.reduce(0) { partial, hop in
            switch hop.axis {
            case .up: partial + 1
            case .down: partial - 1
            case .over: partial
            }
        }
        let paternal = isPaternal(people: people, hops: hops)
        let maternal = paternal.map { !$0 }
        let older: Bool? = {
            guard let from = people.first, let to = people.last else { return nil }
            return isOlder(to, than: from)
        }()

        let code = classifyCode(
            hops: hops,
            people: people,
            isPaternal: paternal,
            targetIsOlder: older
        )

        return ClassifiedRelationship(
            fromID: fromID,
            toID: toID,
            path: path,
            people: people,
            hops: hops,
            code: code,
            generationDelta: generation,
            isPaternal: paternal,
            isMaternal: maternal,
            targetIsOlder: older
        )
    }

    private static func classifyCode(
        hops: [GraphHop],
        people: [PersonNode],
        isPaternal: Bool?,
        targetIsOlder: Bool?
    ) -> KinshipCode {
        let target = people.last
        let gender = target?.gender ?? .unknown
        let axes = hops.map(\.axis)

        if hops.isEmpty { return .self }

        if axes == [.up] {
            return parentCode(hop: hops[0], gender: gender)
        }
        if axes == [.down] {
            return childCode(hop: hops[0], gender: gender)
        }
        if axes == [.over] {
            return hops[0] == .partner ? .partner : spouseCode(gender: gender)
        }

        if axes == [.up, .down] {
            return siblingCode(target: target, linkingParent: people.count > 1 ? people[1] : nil, targetIsOlder: targetIsOlder)
        }

        if axes == [.up, .up] {
            return grandparentCode(people: people, gender: gender, hops: hops)
        }
        if axes == [.down, .down] {
            return gendered(gender, male: .grandson, female: .granddaughter, unknown: .grandchild)
        }

        if axes == [.up, .up, .up] {
            return gendered(gender, male: .greatGrandfather, female: .greatGrandmother, unknown: .greatGrandparent)
        }
        if axes == [.down, .down, .down] {
            return gendered(gender, male: .greatGrandson, female: .greatGranddaughter, unknown: .greatGrandchild)
        }

        if axes == [.up, .over] {
            return parentCode(hop: .stepParent, gender: gender)
        }
        if axes == [.over, .down] {
            return childCode(hop: .stepChild, gender: gender)
        }
        if axes == [.over, .up] {
            return gendered(gender, male: .fatherInLaw, female: .motherInLaw, unknown: .fatherInLaw)
        }
        if axes == [.down, .over] {
            return gendered(gender, male: .sonInLaw, female: .daughterInLaw, unknown: .sonInLaw)
        }
        if axes == [.up, .down, .over] || axes == [.over, .up, .down] {
            return gendered(gender, male: .brotherInLaw, female: .sisterInLaw, unknown: .siblingInLaw)
        }
        if axes == [.up, .over, .down] {
            return .stepSibling
        }

        if axes == [.up, .up, .down] {
            return uncleAuntCode(people: people, gender: gender, byMarriage: false)
        }
        if axes == [.up, .up, .down, .over] {
            return uncleAuntCode(people: people, gender: gender, byMarriage: true)
        }
        if axes == [.up, .down, .down] {
            return gendered(gender, male: .nephew, female: .niece, unknown: .nibling)
        }
        if axes == [.up, .up, .up, .down] {
            return gendered(gender, male: .greatUncle, female: .greatAunt, unknown: .greatUncle)
        }

        if let blood = bloodCousin(axes: axes, gender: gender) {
            return blood
        }

        return .distantRelative
    }

    private static func parentCode(hop: GraphHop, gender: Gender) -> KinshipCode {
        switch hop {
        case .adoptiveParent:
            return gendered(gender, male: .adoptiveFather, female: .adoptiveMother, unknown: .adoptiveParent)
        case .stepParent:
            return gendered(gender, male: .stepFather, female: .stepMother, unknown: .stepParent)
        default:
            return gendered(gender, male: .father, female: .mother, unknown: .parent)
        }
    }

    private static func childCode(hop: GraphHop, gender: Gender) -> KinshipCode {
        switch hop {
        case .adoptedChild:
            return gendered(gender, male: .adoptedSon, female: .adoptedDaughter, unknown: .adoptedChild)
        case .stepChild:
            return gendered(gender, male: .stepSon, female: .stepDaughter, unknown: .stepChild)
        default:
            return gendered(gender, male: .son, female: .daughter, unknown: .child)
        }
    }

    private static func spouseCode(gender: Gender) -> KinshipCode {
        gendered(gender, male: .husband, female: .wife, unknown: .spouse)
    }

    private static func siblingCode(target: PersonNode?, linkingParent: PersonNode?, targetIsOlder: Bool?) -> KinshipCode {
        _ = linkingParent
        switch target?.gender ?? .unknown {
        case .male:
            if targetIsOlder == true { return .olderBrother }
            if targetIsOlder == false { return .youngerBrother }
            return .brother
        case .female:
            if targetIsOlder == true { return .olderSister }
            if targetIsOlder == false { return .youngerSister }
            return .sister
        case .unknown:
            return .sibling
        }
    }

    private static func grandparentCode(people: [PersonNode], gender: Gender, hops: [GraphHop]) -> KinshipCode {
        _ = hops
        let linkingParent = people.count > 1 ? people[1] : nil
        switch linkingParent?.gender {
        case .male:
            return gendered(gender, male: .paternalGrandfather, female: .paternalGrandmother, unknown: .grandfather)
        case .female:
            return gendered(gender, male: .maternalGrandfather, female: .maternalGrandmother, unknown: .grandmother)
        default:
            return gendered(gender, male: .grandfather, female: .grandmother, unknown: .grandparent)
        }
    }

    private static func uncleAuntCode(people: [PersonNode], gender: Gender, byMarriage: Bool) -> KinshipCode {
        let linkingParent = people.count > 1 ? people[1] : nil
        let siblingOfParent = people.count > 3 ? people[3] : nil
        let olderThanParent = isOlder(siblingOfParent, than: linkingParent)

        if byMarriage {
            switch linkingParent?.gender {
            case .male:
                if gender == .male { return .paternalAuntHusband }
                if olderThanParent == true { return .paternalUncleWifeOlder }
                return .paternalUncleWifeYounger
            case .female:
                if gender == .male { return .maternalAuntHusband }
                return .maternalUncleWife
            default:
                return gendered(gender, male: .uncle, female: .aunt, unknown: .uncle)
            }
        }

        switch linkingParent?.gender {
        case .male:
            if gender == .female { return .paternalAunt }
            if olderThanParent == true { return .paternalUncleOlder }
            if olderThanParent == false { return .paternalUncleYounger }
            return .paternalUncle
        case .female:
            if gender == .female { return .maternalAunt }
            return .maternalUncle
        default:
            return gendered(gender, male: .uncle, female: .aunt, unknown: .uncle)
        }
    }

    private static func bloodCousin(axes: [GraphAxis], gender: Gender) -> KinshipCode? {
        _ = gender
        guard let firstDown = axes.firstIndex(of: .down) else { return nil }
        let ups = axes.prefix(firstDown)
        let downs = axes.suffix(from: firstDown)
        guard ups.allSatisfy({ $0 == .up }), downs.allSatisfy({ $0 == .down }) else { return nil }
        let upCount = ups.count
        let downCount = downs.count
        guard upCount >= 1, downCount >= 1 else { return nil }

        if upCount == 1, downCount == 1 { return nil } // sibling, handled
        if upCount >= 2, downCount == 1 { return nil } // uncle, handled
        if upCount == 1, downCount >= 2 { return nil } // nibling, handled

        let degree = min(upCount, downCount) - 1
        let removed = abs(upCount - downCount)
        if degree == 1, removed == 0 { return .firstCousin }
        if degree == 1, removed >= 1 { return .firstCousinOnceRemoved }
        if degree == 2, removed == 0 { return .secondCousin }
        if degree >= 1 { return .cousin }
        return .distantRelative
    }

    private static func isPaternal(people: [PersonNode], hops: [GraphHop]) -> Bool? {
        guard let firstUp = hops.firstIndex(where: { $0.axis == .up }), firstUp + 1 < people.count else {
            return nil
        }
        switch people[firstUp + 1].gender {
        case .male: return true
        case .female: return false
        case .unknown: return nil
        }
    }

    private static func isOlder(_ a: PersonNode?, than b: PersonNode?) -> Bool? {
        guard let a, let b, let da = a.birthDate, let db = b.birthDate else { return nil }
        if da < db { return true }
        if da > db { return false }
        return nil
    }

    private static func gendered(_ gender: Gender, male: KinshipCode, female: KinshipCode, unknown: KinshipCode) -> KinshipCode {
        switch gender {
        case .male: male
        case .female: female
        case .unknown: unknown
        }
    }
}
