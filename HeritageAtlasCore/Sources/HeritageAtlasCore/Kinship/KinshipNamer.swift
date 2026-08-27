import Foundation

public struct KinshipNaming: Sendable, Equatable, Codable {
    public var locale: KinshipLocale
    public var pathExplanation: String
    public var term: String
    public var youCallThem: String
    public var theyCallYou: String

    public init(
        locale: KinshipLocale,
        pathExplanation: String,
        term: String,
        youCallThem: String,
        theyCallYou: String
    ) {
        self.locale = locale
        self.pathExplanation = pathExplanation
        self.term = term
        self.youCallThem = youCallThem
        self.theyCallYou = theyCallYou
    }
}

public enum KinshipNamer: Sendable {
    public static func name(_ classified: ClassifiedRelationship, locale: KinshipLocale, reverse: ClassifiedRelationship) -> KinshipNaming {
        switch locale {
        case .vi:
            return VietnameseKinshipNamer.name(classified, reverse: reverse)
        case .en:
            return EnglishKinshipNamer.name(classified, reverse: reverse)
        }
    }

    public static func name(path: KinPath, graph: RelationshipGraph, locale: KinshipLocale) -> KinshipNaming {
        let forward = KinshipClassifier.classify(path: path, graph: graph)
        let reverse = KinshipClassifier.classify(path: path.reversed, graph: graph)
        return name(forward, locale: locale, reverse: reverse)
    }
}

enum EnglishKinshipNamer {
    static func name(_ classified: ClassifiedRelationship, reverse: ClassifiedRelationship) -> KinshipNaming {
        KinshipNaming(
            locale: .en,
            pathExplanation: pathExplanation(classified),
            term: term(classified.code),
            youCallThem: address(classified.code, person: classified.toPerson),
            theyCallYou: address(reverse.code, person: reverse.toPerson)
        )
    }

    static func shortRole(hop: GraphHop, person: PersonNode) -> String {
        hopNoun(hop, person: person).capitalized
    }

    private static func pathExplanation(_ classified: ClassifiedRelationship) -> String {
        if classified.hops.isEmpty { return "You" }
        var parts: [String] = []
        for index in classified.hops.indices {
            let person = classified.people[index + 1]
            parts.append(hopNoun(classified.hops[index], person: person))
        }
        guard let first = parts.first else { return "Relative" }
        if parts.count == 1 {
            return "Your \(first)"
        }
        return "Your " + first + parts.dropFirst().map { "'s \($0)" }.joined()
    }

    private static func hopNoun(_ hop: GraphHop, person: PersonNode) -> String {
        switch hop {
        case .parent:
            return gendered(person.gender, "father", "mother", "parent")
        case .child:
            return gendered(person.gender, "son", "daughter", "child")
        case .adoptiveParent:
            return gendered(person.gender, "adoptive father", "adoptive mother", "adoptive parent")
        case .adoptedChild:
            return gendered(person.gender, "adopted son", "adopted daughter", "adopted child")
        case .stepParent:
            return gendered(person.gender, "stepfather", "stepmother", "step-parent")
        case .stepChild:
            return gendered(person.gender, "stepson", "stepdaughter", "step-child")
        case .spouse:
            return gendered(person.gender, "husband", "wife", "spouse")
        case .partner:
            return "partner"
        }
    }

    static func term(_ code: KinshipCode) -> String {
        switch code {
        case .self: "You"
        case .father: "Father"
        case .mother: "Mother"
        case .parent: "Parent"
        case .adoptiveFather: "Adoptive father"
        case .adoptiveMother: "Adoptive mother"
        case .adoptiveParent: "Adoptive parent"
        case .stepFather: "Stepfather"
        case .stepMother: "Stepmother"
        case .stepParent: "Step-parent"
        case .son: "Son"
        case .daughter: "Daughter"
        case .child: "Child"
        case .adoptedSon: "Adopted son"
        case .adoptedDaughter: "Adopted daughter"
        case .adoptedChild: "Adopted child"
        case .stepSon: "Stepson"
        case .stepDaughter: "Stepdaughter"
        case .stepChild: "Step-child"
        case .husband: "Husband"
        case .wife: "Wife"
        case .spouse: "Spouse"
        case .partner: "Partner"
        case .olderBrother: "Older brother"
        case .youngerBrother: "Younger brother"
        case .brother: "Brother"
        case .olderSister: "Older sister"
        case .youngerSister: "Younger sister"
        case .sister: "Sister"
        case .sibling: "Sibling"
        case .paternalGrandfather: "Paternal grandfather"
        case .paternalGrandmother: "Paternal grandmother"
        case .maternalGrandfather: "Maternal grandfather"
        case .maternalGrandmother: "Maternal grandmother"
        case .grandfather: "Grandfather"
        case .grandmother: "Grandmother"
        case .grandparent: "Grandparent"
        case .grandson: "Grandson"
        case .granddaughter: "Granddaughter"
        case .grandchild: "Grandchild"
        case .greatGrandfather: "Great-grandfather"
        case .greatGrandmother: "Great-grandmother"
        case .greatGrandparent: "Great-grandparent"
        case .greatGrandson: "Great-grandson"
        case .greatGranddaughter: "Great-granddaughter"
        case .greatGrandchild: "Great-grandchild"
        case .paternalUncleOlder, .paternalUncleYounger, .paternalUncle: "Paternal uncle"
        case .paternalAunt: "Paternal aunt"
        case .maternalUncle: "Maternal uncle"
        case .maternalAunt: "Maternal aunt"
        case .uncle: "Uncle"
        case .aunt: "Aunt"
        case .paternalUncleWifeOlder, .paternalUncleWifeYounger: "Aunt"
        case .paternalAuntHusband, .maternalAuntHusband: "Uncle"
        case .maternalUncleWife: "Aunt"
        case .nephew: "Nephew"
        case .niece: "Niece"
        case .nibling: "Nibling"
        case .firstCousin: "First cousin"
        case .firstCousinOnceRemoved: "First cousin once removed"
        case .secondCousin: "Second cousin"
        case .cousin: "Cousin"
        case .fatherInLaw: "Father-in-law"
        case .motherInLaw: "Mother-in-law"
        case .sonInLaw: "Son-in-law"
        case .daughterInLaw: "Daughter-in-law"
        case .brotherInLaw: "Brother-in-law"
        case .sisterInLaw: "Sister-in-law"
        case .siblingInLaw: "Sibling-in-law"
        case .stepSibling: "Step-sibling"
        case .greatUncle: "Great-uncle"
        case .greatAunt: "Great-aunt"
        case .distantRelative: "Relative"
        case .unknown: "Relative"
        }
    }

    static func address(_ code: KinshipCode, person: PersonNode?) -> String {
        switch code {
        case .self: "You"
        case .father, .adoptiveFather, .stepFather, .fatherInLaw: "Dad"
        case .mother, .adoptiveMother, .stepMother, .motherInLaw: "Mom"
        case .parent, .adoptiveParent, .stepParent: "Parent"
        case .son, .adoptedSon, .stepSon, .sonInLaw, .daughter, .adoptedDaughter, .stepDaughter, .daughterInLaw, .child, .adoptedChild, .stepChild:
            gendered(person?.gender ?? .unknown, "Son", "Daughter", "Child")
        case .husband: "Husband"
        case .wife: "Wife"
        case .spouse: "Spouse"
        case .partner: "Partner"
        case .olderBrother, .youngerBrother, .brother: "Brother"
        case .olderSister, .youngerSister, .sister: "Sister"
        case .sibling, .stepSibling: "Sibling"
        case .paternalGrandfather, .maternalGrandfather, .grandfather, .greatGrandfather:
            "Grandfather"
        case .paternalGrandmother, .maternalGrandmother, .grandmother, .greatGrandmother:
            "Grandmother"
        case .grandparent, .greatGrandparent: "Grandparent"
        case .grandson, .greatGrandson: "Grandson"
        case .granddaughter, .greatGranddaughter: "Granddaughter"
        case .grandchild, .greatGrandchild: "Grandchild"
        case .paternalUncleOlder, .paternalUncleYounger, .paternalUncle, .maternalUncle, .uncle, .paternalAuntHusband, .maternalAuntHusband, .greatUncle:
            "Uncle"
        case .paternalAunt, .maternalAunt, .aunt, .paternalUncleWifeOlder, .paternalUncleWifeYounger, .maternalUncleWife, .greatAunt:
            "Aunt"
        case .nephew: "Nephew"
        case .niece: "Niece"
        case .nibling: gendered(person?.gender ?? .unknown, "Nephew", "Niece", "Nibling")
        case .firstCousin, .firstCousinOnceRemoved, .secondCousin, .cousin:
            "Cousin"
        case .brotherInLaw: "Brother-in-law"
        case .sisterInLaw: "Sister-in-law"
        case .siblingInLaw: "In-law"
        case .distantRelative, .unknown: "Relative"
        }
    }
}

enum VietnameseKinshipNamer {
    static func name(_ classified: ClassifiedRelationship, reverse: ClassifiedRelationship) -> KinshipNaming {
        KinshipNaming(
            locale: .vi,
            pathExplanation: pathExplanation(classified),
            term: term(classified.code),
            youCallThem: address(classified.code, person: classified.toPerson, older: classified.targetIsOlder),
            theyCallYou: address(reverse.code, person: reverse.toPerson, older: reverse.targetIsOlder)
        )
    }

    private static func pathExplanation(_ classified: ClassifiedRelationship) -> String {
        if classified.hops.isEmpty { return "Bạn" }
        var parts: [String] = []
        for index in classified.hops.indices {
            let person = classified.people[index + 1]
            parts.append(hopNoun(classified.hops[index], person: person))
        }
        return parts.reversed().joined(separator: " của ") + " của bạn"
    }

    private static func hopNoun(_ hop: GraphHop, person: PersonNode) -> String {
        switch hop {
        case .parent:
            return gendered(person.gender, "bố", "mẹ", "cha/mẹ")
        case .child:
            return gendered(person.gender, "con trai", "con gái", "con")
        case .adoptiveParent:
            return gendered(person.gender, "cha nuôi", "mẹ nuôi", "cha/mẹ nuôi")
        case .adoptedChild:
            return gendered(person.gender, "con nuôi trai", "con nuôi gái", "con nuôi")
        case .stepParent:
            return gendered(person.gender, "dượng", "mẹ kế", "cha/mẹ kế")
        case .stepChild:
            return gendered(person.gender, "con riêng trai", "con riêng gái", "con riêng")
        case .spouse:
            return gendered(person.gender, "chồng", "vợ", "vợ/chồng")
        case .partner:
            return "bạn đời"
        }
    }

    static func term(_ code: KinshipCode) -> String {
        switch code {
        case .self: "Bạn"
        case .father: "Bố"
        case .mother: "Mẹ"
        case .parent: "Cha/mẹ"
        case .adoptiveFather: "Cha nuôi"
        case .adoptiveMother: "Mẹ nuôi"
        case .adoptiveParent: "Cha/mẹ nuôi"
        case .stepFather: "Dượng"
        case .stepMother: "Mẹ kế"
        case .stepParent: "Cha/mẹ kế"
        case .son: "Con trai"
        case .daughter: "Con gái"
        case .child: "Con"
        case .adoptedSon: "Con nuôi trai"
        case .adoptedDaughter: "Con nuôi gái"
        case .adoptedChild: "Con nuôi"
        case .stepSon: "Con riêng trai"
        case .stepDaughter: "Con riêng gái"
        case .stepChild: "Con riêng"
        case .husband: "Chồng"
        case .wife: "Vợ"
        case .spouse: "Vợ/chồng"
        case .partner: "Bạn đời"
        case .olderBrother: "Anh"
        case .youngerBrother: "Em trai"
        case .brother: "Anh/em trai"
        case .olderSister: "Chị"
        case .youngerSister: "Em gái"
        case .sister: "Chị/em gái"
        case .sibling: "Anh chị em"
        case .paternalGrandfather: "Ông nội"
        case .paternalGrandmother: "Bà nội"
        case .maternalGrandfather: "Ông ngoại"
        case .maternalGrandmother: "Bà ngoại"
        case .grandfather: "Ông"
        case .grandmother: "Bà"
        case .grandparent: "Ông/bà"
        case .grandson: "Cháu trai"
        case .granddaughter: "Cháu gái"
        case .grandchild: "Cháu"
        case .greatGrandfather: "Cụ ông"
        case .greatGrandmother: "Cụ bà"
        case .greatGrandparent: "Cụ"
        case .greatGrandson, .greatGranddaughter, .greatGrandchild: "Chắt"
        case .paternalUncleOlder: "Bác"
        case .paternalUncleYounger: "Chú"
        case .paternalUncle: "Chú/Bác"
        case .paternalAunt: "Cô"
        case .maternalUncle: "Cậu"
        case .maternalAunt: "Dì"
        case .uncle: "Chú"
        case .aunt: "Cô"
        case .paternalUncleWifeOlder: "Bác"
        case .paternalUncleWifeYounger: "Thím"
        case .paternalAuntHusband: "Dượng"
        case .maternalUncleWife: "Mợ"
        case .maternalAuntHusband: "Dượng"
        case .nephew, .niece, .nibling: "Cháu"
        case .firstCousin: "Anh chị em họ"
        case .firstCousinOnceRemoved: "Cậu/cháu họ"
        case .secondCousin: "Họ hàng đời hai"
        case .cousin: "Họ hàng"
        case .fatherInLaw: "Bố chồng/vợ"
        case .motherInLaw: "Mẹ chồng/vợ"
        case .sonInLaw: "Con rể"
        case .daughterInLaw: "Con dâu"
        case .brotherInLaw: "Anh/em rể"
        case .sisterInLaw: "Chị/em dâu"
        case .siblingInLaw: "Anh chị em dâu rể"
        case .stepSibling: "Anh chị em cùng cha/mẹ khác"
        case .greatUncle: "Ông chú/bác"
        case .greatAunt: "Bà cô"
        case .distantRelative, .unknown: "Họ hàng"
        }
    }

    static func address(_ code: KinshipCode, person: PersonNode?, older: Bool?) -> String {
        switch code {
        case .self:
            return "Bạn"
        case .father, .adoptiveFather:
            return "Bố"
        case .mother, .adoptiveMother:
            return "Mẹ"
        case .parent, .adoptiveParent:
            return "Bố/Mẹ"
        case .stepFather:
            return "Dượng"
        case .stepMother:
            return "Mẹ"
        case .stepParent:
            return "Dượng"
        case .son, .daughter, .child, .adoptedSon, .adoptedDaughter, .adoptedChild, .stepSon, .stepDaughter, .stepChild, .sonInLaw, .daughterInLaw:
            return "Con"
        case .husband:
            return "Anh"
        case .wife:
            return "Em"
        case .spouse, .partner:
            return "Mình"
        case .olderBrother:
            return "Anh"
        case .youngerBrother:
            return "Em"
        case .brother:
            return older == true ? "Anh" : "Em"
        case .olderSister:
            return "Chị"
        case .youngerSister:
            return "Em"
        case .sister:
            return older == true ? "Chị" : "Em"
        case .sibling, .stepSibling:
            if older == true {
                return gendered(person?.gender ?? .unknown, "Anh", "Chị", "Anh/Chị")
            }
            return "Em"
        case .paternalGrandfather, .maternalGrandfather, .grandfather, .greatGrandfather:
            return "Ông"
        case .paternalGrandmother, .maternalGrandmother, .grandmother, .greatGrandmother:
            return "Bà"
        case .grandparent, .greatGrandparent:
            return "Ông/Bà"
        case .grandson, .granddaughter, .grandchild, .greatGrandson, .greatGranddaughter, .greatGrandchild, .nephew, .niece, .nibling:
            return "Cháu"
        case .paternalUncleOlder, .paternalUncleWifeOlder:
            return "Bác"
        case .paternalUncleYounger:
            return "Chú"
        case .paternalUncle:
            return "Chú"
        case .paternalAunt:
            return "Cô"
        case .maternalUncle:
            return "Cậu"
        case .maternalAunt:
            return "Dì"
        case .uncle:
            return "Chú"
        case .aunt:
            return "Cô"
        case .paternalUncleWifeYounger:
            return "Thím"
        case .paternalAuntHusband, .maternalAuntHusband:
            return "Dượng"
        case .maternalUncleWife:
            return "Mợ"
        case .firstCousin:
            if older == true {
                return gendered(person?.gender ?? .unknown, "Anh", "Chị", "Anh/Chị")
            }
            if older == false {
                return "Em"
            }
            return "Anh/Chị họ"
        case .firstCousinOnceRemoved, .secondCousin, .cousin, .distantRelative, .unknown:
            return "Họ"
        case .fatherInLaw:
            return "Bố"
        case .motherInLaw:
            return "Mẹ"
        case .brotherInLaw:
            return older == true ? "Anh" : "Em"
        case .sisterInLaw:
            return older == true ? "Chị" : "Em"
        case .siblingInLaw:
            return "Anh/Chị"
        case .greatUncle:
            return "Ông"
        case .greatAunt:
            return "Bà"
        }
    }
}

private func gendered(_ gender: Gender, _ male: String, _ female: String, _ unknown: String) -> String {
    switch gender {
    case .male: male
    case .female: female
    case .unknown: unknown
    }
}
