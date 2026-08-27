import Foundation

extension RelationshipGraph {
    public func hops(from id: UUID, matching: (GraphHop) -> Bool) -> [PersonNode] {
        uniqueNodes(
            (adjacency[id] ?? [])
                .filter { matching($0.hop) }
                .compactMap { people[$0.neighborID] }
        )
    }

    public func parents(of id: UUID) -> [PersonNode] {
        hops(from: id) { $0.axis == .up }
    }

    public func children(of id: UUID) -> [PersonNode] {
        hops(from: id) { $0.axis == .down }
    }

    public func spousesAndPartners(of id: UUID) -> [PersonNode] {
        hops(from: id) { $0 == .spouse || $0 == .partner }
    }

    public func siblings(of id: UUID) -> [PersonNode] {
        var result: [PersonNode] = []
        var seen: Set<UUID> = [id]
        for parent in parents(of: id) {
            for child in children(of: parent.id) where seen.insert(child.id).inserted {
                result.append(child)
            }
        }
        return result
    }

    public func hop(from: UUID, to: UUID) -> GraphHop? {
        adjacency[from]?.first { $0.neighborID == to }?.hop
    }

    public func ancestors(of id: UUID) -> [PersonNode] {
        var seen: Set<UUID> = [id]
        var queue = parents(of: id)
        var result: [PersonNode] = []
        var index = 0
        while index < queue.count {
            let node = queue[index]
            index += 1
            if seen.insert(node.id).inserted == false { continue }
            result.append(node)
            queue.append(contentsOf: parents(of: node.id))
        }
        return result
    }

    public func sortedByBirth(_ nodes: [PersonNode]) -> [PersonNode] {
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

    public func sortedParents(_ nodes: [PersonNode]) -> [PersonNode] {
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

public enum GenerationIndex: Sendable {
    /// Generation 0 is the oldest parental generation (people with no parents in the graph).
    public static func generations(in graph: RelationshipGraph) -> [UUID: Int] {
        guard !graph.people.isEmpty else { return [:] }

        var generation: [UUID: Int] = [:]
        var roots = graph.people.keys.filter { graph.parents(of: $0).isEmpty }
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
            for child in graph.children(of: id) {
                let next = current + 1
                if let existing = generation[child.id], existing >= next { continue }
                generation[child.id] = next
                queue.append(child.id)
            }
        }
        for id in graph.people.keys where generation[id] == nil {
            generation[id] = 0
        }
        return generation
    }

    public static func count(in graph: RelationshipGraph) -> Int {
        let generation = generations(in: graph)
        guard let minG = generation.values.min(), let maxG = generation.values.max() else {
            return 0
        }
        return max(1, maxG - minG + 1)
    }
}

public enum FamilyMetrics: Sendable {
    public static func generationCount(in graph: RelationshipGraph) -> Int {
        GenerationIndex.count(in: graph)
    }
}
