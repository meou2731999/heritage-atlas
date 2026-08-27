import Foundation
import Testing
@testable import HeritageAtlasCore

@Suite("Relationship graph")
struct RelationshipGraphTests {
    let family = SampleFamily()

    @Test func selfPath() {
        let path = family.graph.shortestPath(from: family.me.id, to: family.me.id)
        #expect(path?.personIDs == [family.me.id])
        #expect(path?.hops.isEmpty == true)
        #expect(KinshipClassifier.classify(path: path!, graph: family.graph).code == .self)
    }

    @Test func parentIsOneHopUp() {
        let path = family.graph.shortestPath(from: family.me.id, to: family.father.id)
        #expect(path?.hops == [.parent])
        #expect(family.classify(to: family.father).code == .father)
        #expect(family.classify(to: family.mother).code == .mother)
    }

    @Test func childIsInverseOfParent() {
        let path = family.graph.shortestPath(from: family.father.id, to: family.me.id)
        #expect(path?.hops == [.child])
        let classified = KinshipClassifier.classify(path: path!, graph: family.graph)
        #expect(classified.code == .son)
    }

    @Test func grandparentsArePaternalOrMaternal() {
        #expect(family.classify(to: family.paternalGrandfather).code == .paternalGrandfather)
        #expect(family.classify(to: family.paternalGrandmother).code == .paternalGrandmother)
        #expect(family.classify(to: family.maternalGrandfather).code == .maternalGrandfather)
        #expect(family.classify(to: family.maternalGrandmother).code == .maternalGrandmother)
    }

    @Test func paternalUnclesDistinguishAge() {
        #expect(family.classify(to: family.uncleOlder).code == .paternalUncleOlder)
        #expect(family.classify(to: family.uncleYounger).code == .paternalUncleYounger)
        #expect(family.classify(to: family.auntPaternal).code == .paternalAunt)
    }

    @Test func maternalUncleAndAunt() {
        #expect(family.classify(to: family.uncleMaternal).code == .maternalUncle)
        #expect(family.classify(to: family.auntMaternal).code == .maternalAunt)
    }

    @Test func firstCousinViaPaternalUncle() {
        #expect(family.classify(to: family.cousin).code == .firstCousin)
        let path = family.graph.shortestPath(from: family.me.id, to: family.cousin.id)
        #expect(path?.hops == [.parent, .parent, .child, .child])
    }

    @Test func youngerSister() {
        #expect(family.classify(to: family.sister).code == .youngerSister)
    }

    @Test func disconnectedPersonHasNoPath() {
        #expect(family.graph.shortestPath(from: family.me.id, to: family.stranger.id) == nil)
    }

    @Test func spouseIsBidirectional() {
        let forward = family.graph.shortestPath(from: family.father.id, to: family.mother.id)
        let back = family.graph.shortestPath(from: family.mother.id, to: family.father.id)
        #expect(forward?.hops == [.spouse])
        #expect(back?.hops == [.spouse])
    }

    @Test func cacheCoversEveryReachablePerson() {
        let cache = RelationshipCache.rebuild(meID: family.me.id, graph: family.graph, locale: .vi)
        #expect(cache.entry(for: family.me.id)?.code == .self)
        #expect(cache.entry(for: family.father.id)?.code == .father)
        #expect(cache.entry(for: family.uncleYounger.id)?.code == .paternalUncleYounger)
        #expect(cache.entry(for: family.cousin.id)?.code == .firstCousin)
        #expect(cache.entry(for: family.stranger.id) == nil)
        #expect(cache.entriesByPersonID.count == 14)
    }

    @Test func pathGlanceUsesArrows() {
        let path = family.graph.shortestPath(from: family.me.id, to: family.paternalGrandfather.id)!
        let glance = RelationshipCache.pathGlance(path: path, graph: family.graph)
        #expect(glance.contains("YOU"))
        #expect(glance.contains("↑"))
        #expect(glance.contains("Father"))
        #expect(glance.contains("Grandfather") || glance.contains("Father"))
    }

    @Test func adoptiveAndStepAreDistinctHops() {
        let child = PersonNode(fullName: "Con", gender: .female)
        let adoptive = PersonNode(fullName: "Cha nuôi", gender: .male)
        let step = PersonNode(fullName: "Mẹ kế", gender: .female)
        let graph = RelationshipGraph(
            people: [child, adoptive, step],
            edges: [
                KinEdge(fromID: adoptive.id, toID: child.id, kind: .adoptiveParent),
                KinEdge(fromID: step.id, toID: child.id, kind: .stepParent),
            ]
        )
        let toAdoptive = graph.shortestPath(from: child.id, to: adoptive.id)!
        let toStep = graph.shortestPath(from: child.id, to: step.id)!
        #expect(KinshipClassifier.classify(path: toAdoptive, graph: graph).code == .adoptiveFather)
        #expect(KinshipClassifier.classify(path: toStep, graph: graph).code == .stepMother)
    }
}
