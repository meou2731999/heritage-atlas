import HeritageAtlasCore
import Testing
@testable import Heritage_Atlas

struct Heritage_AtlasTests {
    @Test func fatherAndPaternalUncleVietnameseAndEnglish() {
        let me = PersonNode(fullName: "Quân", gender: .male)
        let father = PersonNode(fullName: "Ba", gender: .male)
        let uncle = PersonNode(fullName: "Chú", gender: .male)
        let grandfather = PersonNode(fullName: "Ông", gender: .male)
        let graph = RelationshipGraph(
            people: [me, father, uncle, grandfather],
            edges: [
                KinEdge(fromID: father.id, toID: me.id, kind: .parent),
                KinEdge(fromID: grandfather.id, toID: father.id, kind: .parent),
                KinEdge(fromID: grandfather.id, toID: uncle.id, kind: .parent),
            ]
        )

        let fatherPath = graph.shortestPath(from: me.id, to: father.id)!
        #expect(KinshipClassifier.classify(path: fatherPath, graph: graph).code == .father)
        let fatherVI = KinshipNamer.name(path: fatherPath, graph: graph, locale: .vi)
        #expect(fatherVI.youCallThem == "Bố")
        #expect(fatherVI.theyCallYou == "Con")
        let fatherEN = KinshipNamer.name(path: fatherPath, graph: graph, locale: .en)
        #expect(fatherEN.term == "Father")
        #expect(fatherEN.youCallThem == "Dad")

        let unclePath = graph.shortestPath(from: me.id, to: uncle.id)!
        #expect(KinshipClassifier.classify(path: unclePath, graph: graph).code == .paternalUncle)
        let uncleVI = KinshipNamer.name(path: unclePath, graph: graph, locale: .vi)
        #expect(uncleVI.youCallThem == "Chú")
        #expect(uncleVI.theyCallYou == "Cháu")
        let uncleEN = KinshipNamer.name(path: unclePath, graph: graph, locale: .en)
        #expect(uncleEN.youCallThem == "Uncle")
        #expect(uncleEN.theyCallYou == "Nephew")
    }

    @Test func mapPinsCountMemoriesLinkedToPlace() {
        let place = Place(name: "Huế", latitude: 16.4637, longitude: 107.5909)
        let other = Place(name: "Hà Nội", latitude: 21.0285, longitude: 105.8542)
        let linked = Memory(kind: .story, title: "Kitchen", placeIDs: [place.id])
        let unrelated = Memory(kind: .text, title: "Note", placeIDs: [other.id])
        let pins = PlacePin.build(
            places: [place, other],
            links: [],
            memories: [linked, unrelated],
            burialOnly: false
        )
        #expect(pins.first { $0.name == "Huế" }?.memoryCount == 1)
        #expect(pins.first { $0.name == "Hà Nội" }?.memoryCount == 1)
    }
}
