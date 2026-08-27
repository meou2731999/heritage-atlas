import Foundation
@testable import HeritageAtlasCore

struct SampleFamily {
    let paternalGrandfather: PersonNode
    let paternalGrandmother: PersonNode
    let maternalGrandfather: PersonNode
    let maternalGrandmother: PersonNode
    let uncleOlder: PersonNode
    let father: PersonNode
    let uncleYounger: PersonNode
    let auntPaternal: PersonNode
    let mother: PersonNode
    let uncleMaternal: PersonNode
    let auntMaternal: PersonNode
    let me: PersonNode
    let sister: PersonNode
    let cousin: PersonNode
    let stranger: PersonNode

    let graph: RelationshipGraph

    init() {
        func date(_ year: Int) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = 6
            components.day = 15
            return Calendar(identifier: .gregorian).date(from: components)!
        }

        paternalGrandfather = PersonNode(fullName: "Ông Nội", gender: .male, birthDate: date(1930))
        paternalGrandmother = PersonNode(fullName: "Bà Nội", gender: .female, birthDate: date(1932))
        maternalGrandfather = PersonNode(fullName: "Ông Ngoại", gender: .male, birthDate: date(1931))
        maternalGrandmother = PersonNode(fullName: "Bà Ngoại", gender: .female, birthDate: date(1933))
        uncleOlder = PersonNode(fullName: "Bác Trai", gender: .male, birthDate: date(1955))
        father = PersonNode(fullName: "Nguyễn Văn Ba", gender: .male, birthDate: date(1960))
        uncleYounger = PersonNode(fullName: "Chú Năm", gender: .male, birthDate: date(1965))
        auntPaternal = PersonNode(fullName: "Cô Sáu", gender: .female, birthDate: date(1963))
        mother = PersonNode(fullName: "Trần Thị Mẹ", gender: .female, birthDate: date(1962))
        uncleMaternal = PersonNode(fullName: "Cậu Bảy", gender: .male, birthDate: date(1958))
        auntMaternal = PersonNode(fullName: "Dì Tám", gender: .female, birthDate: date(1966))
        me = PersonNode(fullName: "Nguyễn Văn Quân", gender: .male, birthDate: date(1995))
        sister = PersonNode(fullName: "Nguyễn Thị Em", gender: .female, birthDate: date(1998))
        cousin = PersonNode(fullName: "Nguyễn Văn Họ", gender: .male, birthDate: date(1990))
        stranger = PersonNode(fullName: "Người Lạ", gender: .unknown)

        func parent(_ a: PersonNode, _ b: PersonNode) -> KinEdge {
            KinEdge(fromID: a.id, toID: b.id, kind: .parent)
        }

        let people = [
            paternalGrandfather, paternalGrandmother,
            maternalGrandfather, maternalGrandmother,
            uncleOlder, father, uncleYounger, auntPaternal,
            mother, uncleMaternal, auntMaternal,
            me, sister, cousin, stranger,
        ]

        let edges: [KinEdge] = [
            parent(paternalGrandfather, father),
            parent(paternalGrandmother, father),
            parent(paternalGrandfather, uncleOlder),
            parent(paternalGrandmother, uncleOlder),
            parent(paternalGrandfather, uncleYounger),
            parent(paternalGrandmother, uncleYounger),
            parent(paternalGrandfather, auntPaternal),
            parent(paternalGrandmother, auntPaternal),
            parent(maternalGrandfather, mother),
            parent(maternalGrandmother, mother),
            parent(maternalGrandfather, uncleMaternal),
            parent(maternalGrandmother, uncleMaternal),
            parent(maternalGrandfather, auntMaternal),
            parent(maternalGrandmother, auntMaternal),
            parent(father, me),
            parent(mother, me),
            parent(father, sister),
            parent(mother, sister),
            parent(uncleYounger, cousin),
            KinEdge(fromID: father.id, toID: mother.id, kind: .spouse),
        ]

        graph = RelationshipGraph(people: people, edges: edges)
    }

    func classify(to person: PersonNode) -> ClassifiedRelationship {
        let path = graph.shortestPath(from: me.id, to: person.id)!
        return KinshipClassifier.classify(path: path, graph: graph)
    }

    func naming(to person: PersonNode, locale: KinshipLocale) -> KinshipNaming {
        let path = graph.shortestPath(from: me.id, to: person.id)!
        return KinshipNamer.name(path: path, graph: graph, locale: locale)
    }
}
