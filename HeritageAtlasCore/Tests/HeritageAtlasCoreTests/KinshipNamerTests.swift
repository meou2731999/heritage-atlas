import Testing
@testable import HeritageAtlasCore

@Suite("Kinship namer VI/EN")
struct KinshipNamerTests {
    let family = SampleFamily()

    @Test func vietnameseImmediateFamily() {
        let father = family.naming(to: family.father, locale: .vi)
        #expect(father.term == "Bố")
        #expect(father.youCallThem == "Bố")
        #expect(father.theyCallYou == "Con")
        #expect(father.pathExplanation.contains("bố"))

        let mother = family.naming(to: family.mother, locale: .vi)
        #expect(mother.youCallThem == "Mẹ")
        #expect(mother.theyCallYou == "Con")
    }

    @Test func vietnameseGrandparentsNoiNgoai() {
        #expect(family.naming(to: family.paternalGrandfather, locale: .vi).term == "Ông nội")
        #expect(family.naming(to: family.paternalGrandmother, locale: .vi).term == "Bà nội")
        #expect(family.naming(to: family.maternalGrandfather, locale: .vi).term == "Ông ngoại")
        #expect(family.naming(to: family.maternalGrandmother, locale: .vi).term == "Bà ngoại")
        #expect(family.naming(to: family.paternalGrandfather, locale: .vi).youCallThem == "Ông")
        #expect(family.naming(to: family.paternalGrandfather, locale: .vi).theyCallYou == "Cháu")
    }

    @Test func vietnameseUnclesAndAunts() {
        let bac = family.naming(to: family.uncleOlder, locale: .vi)
        #expect(bac.youCallThem == "Bác")
        #expect(bac.theyCallYou == "Cháu")

        let chu = family.naming(to: family.uncleYounger, locale: .vi)
        #expect(chu.youCallThem == "Chú")
        #expect(chu.theyCallYou == "Cháu")
        #expect(chu.pathExplanation.contains("bố"))

        #expect(family.naming(to: family.auntPaternal, locale: .vi).youCallThem == "Cô")
        #expect(family.naming(to: family.uncleMaternal, locale: .vi).youCallThem == "Cậu")
        #expect(family.naming(to: family.auntMaternal, locale: .vi).youCallThem == "Dì")
    }

    @Test func vietnameseSisterAndCousin() {
        let sister = family.naming(to: family.sister, locale: .vi)
        #expect(sister.youCallThem == "Em")
        #expect(sister.theyCallYou == "Anh")

        let cousin = family.naming(to: family.cousin, locale: .vi)
        #expect(cousin.term == "Anh chị em họ")
        #expect(cousin.youCallThem == "Anh")
    }

    @Test func englishImmediateAndExtended() {
        let father = family.naming(to: family.father, locale: .en)
        #expect(father.term == "Father")
        #expect(father.pathExplanation == "Your father")
        #expect(father.youCallThem == "Dad")
        #expect(father.theyCallYou == "Son")

        let uncle = family.naming(to: family.uncleYounger, locale: .en)
        #expect(uncle.term == "Paternal uncle")
        #expect(uncle.youCallThem == "Uncle")
        #expect(uncle.theyCallYou == "Nephew")
        #expect(uncle.pathExplanation.contains("father"))
        #expect(uncle.pathExplanation.contains("brother") || uncle.pathExplanation.contains("son"))

        let aunt = family.naming(to: family.auntPaternal, locale: .en)
        #expect(aunt.youCallThem == "Aunt")
        #expect(aunt.term == "Paternal aunt")

        let cousin = family.naming(to: family.cousin, locale: .en)
        #expect(cousin.term == "First cousin")
        #expect(cousin.pathExplanation.contains("father"))
        #expect(cousin.youCallThem == "Cousin")
    }

    @Test func englishGrandfatherPath() {
        let naming = family.naming(to: family.paternalGrandfather, locale: .en)
        #expect(naming.term == "Paternal grandfather")
        #expect(naming.pathExplanation == "Your father's father")
        #expect(naming.youCallThem == "Grandfather")
        #expect(naming.theyCallYou == "Grandson")
    }

    @Test func twoPersonLookupRewritesYouToSpeakerName() {
        let path = family.graph.shortestPath(from: family.father.id, to: family.paternalGrandfather.id)!
        let fromFather = KinshipNamer.name(path: path, graph: family.graph, locale: .en)
        #expect(fromFather.spokenPathExplanation(speakerIsUser: true, speakerName: "Ba") == fromFather.pathExplanation)
        #expect(fromFather.spokenPathExplanation(speakerIsUser: false, speakerName: "Ba") == "Ba’s father")

        let vi = KinshipNamer.name(path: path, graph: family.graph, locale: .vi)
        let rewritten = vi.spokenPathExplanation(speakerIsUser: false, speakerName: "Ba")
        #expect(rewritten.contains("của Ba"))
        #expect(rewritten.contains("của bạn") == false)
    }
}
