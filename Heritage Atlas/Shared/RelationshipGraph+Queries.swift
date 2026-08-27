import Foundation
import HeritageAtlasCore

extension RelationshipGraph {
    func hops(from id: UUID, matching: (GraphHop) -> Bool) -> [PersonNode] {
        (adjacency[id] ?? [])
            .filter { matching($0.hop) }
            .compactMap { people[$0.neighborID] }
    }

    func parents(of id: UUID) -> [PersonNode] {
        uniqueNodes(hops(from: id) { $0.axis == .up })
    }

    func children(of id: UUID) -> [PersonNode] {
        uniqueNodes(hops(from: id) { $0.axis == .down })
    }

    func spousesAndPartners(of id: UUID) -> [PersonNode] {
        uniqueNodes(hops(from: id) { $0 == .spouse || $0 == .partner })
    }

    func siblings(of id: UUID) -> [PersonNode] {
        var result: [PersonNode] = []
        var seen: Set<UUID> = [id]
        for parent in parents(of: id) {
            for child in children(of: parent.id) where seen.insert(child.id).inserted {
                result.append(child)
            }
        }
        return result
    }

    func hop(from: UUID, to: UUID) -> GraphHop? {
        adjacency[from]?.first { $0.neighborID == to }?.hop
    }

    func sortedByBirth(_ nodes: [PersonNode]) -> [PersonNode] {
        nodes.sorted { lhs, rhs in
            switch (lhs.birthDate, rhs.birthDate) {
            case (let left?, let right?) where left != right:
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
            }
        }
    }

    func sortedParents(_ nodes: [PersonNode]) -> [PersonNode] {
        nodes.sorted { lhs, rhs in
            let leftRank = genderRank(lhs.gender)
            let rightRank = genderRank(rhs.gender)
            if leftRank != rightRank { return leftRank < rightRank }
            return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        }
    }

    private func uniqueNodes(_ nodes: [PersonNode]) -> [PersonNode] {
        var seen = Set<UUID>()
        return nodes.filter { seen.insert($0.id).inserted }
    }

    private func genderRank(_ gender: Gender) -> Int {
        switch gender {
        case .male: 0
        case .female: 1
        case .unknown: 2
        }
    }
}

enum FamilyMetrics {
    static func generationCount(in graph: RelationshipGraph) -> Int {
        guard !graph.people.isEmpty else { return 0 }

        func parentIDs(of id: UUID) -> [UUID] {
            graph.parents(of: id).map(\.id)
        }
        func childIDs(of id: UUID) -> [UUID] {
            graph.children(of: id).map(\.id)
        }

        var generation: [UUID: Int] = [:]
        var roots = graph.people.keys.filter { parentIDs(of: $0).isEmpty }
        if roots.isEmpty {
            roots = Array(graph.people.keys)
        }
        for root in roots {
            generation[root] = 0
        }
        var queue = Array(roots)
        var index = 0
        while index < queue.count {
            let id = queue[index]
            index += 1
            let current = generation[id] ?? 0
            for child in childIDs(of: id) {
                let next = current + 1
                if let existing = generation[child], existing >= next { continue }
                generation[child] = next
                queue.append(child)
            }
        }
        for id in graph.people.keys where generation[id] == nil {
            generation[id] = 0
        }
        guard let minG = generation.values.min(), let maxG = generation.values.max() else {
            return 1
        }
        return max(1, maxG - minG + 1)
    }
}
