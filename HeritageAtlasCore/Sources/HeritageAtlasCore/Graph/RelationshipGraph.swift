import Foundation

public enum GraphHop: String, Codable, Sendable, CaseIterable {
    case parent
    case child
    case adoptiveParent
    case adoptedChild
    case stepParent
    case stepChild
    case spouse
    case partner

    public var inverse: GraphHop {
        switch self {
        case .parent: .child
        case .child: .parent
        case .adoptiveParent: .adoptedChild
        case .adoptedChild: .adoptiveParent
        case .stepParent: .stepChild
        case .stepChild: .stepParent
        case .spouse: .spouse
        case .partner: .partner
        }
    }

    public var axis: GraphAxis {
        switch self {
        case .parent, .adoptiveParent, .stepParent: .up
        case .child, .adoptedChild, .stepChild: .down
        case .spouse, .partner: .over
        }
    }

    public var glanceArrow: String {
        switch axis {
        case .up: "↑"
        case .down: "↓"
        case .over: "↔"
        }
    }
}

public enum GraphAxis: String, Sendable {
    case up
    case down
    case over
}

public struct PersonNode: Sendable, Hashable, Codable, Identifiable {
    public var id: UUID
    public var fullName: String
    public var nickname: String?
    public var gender: Gender
    public var birthDate: Date?
    public var deathDate: Date?

    public init(
        id: UUID = UUID(),
        fullName: String,
        nickname: String? = nil,
        gender: Gender = .unknown,
        birthDate: Date? = nil,
        deathDate: Date? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.nickname = nickname
        self.gender = gender
        self.birthDate = birthDate
        self.deathDate = deathDate
    }

    public var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        return fullName
    }
}

public struct KinEdge: Sendable, Hashable, Codable {
    public var fromID: UUID
    public var toID: UUID
    public var kind: KinRelationshipKind

    public init(fromID: UUID, toID: UUID, kind: KinRelationshipKind) {
        self.fromID = fromID
        self.toID = toID
        self.kind = kind
    }
}

public struct KinPath: Sendable, Equatable {
    public var personIDs: [UUID]
    public var hops: [GraphHop]

    public init(personIDs: [UUID], hops: [GraphHop]) {
        self.personIDs = personIDs
        self.hops = hops
    }

    public var reversed: KinPath {
        KinPath(
            personIDs: Array(personIDs.reversed()),
            hops: hops.reversed().map(\.inverse)
        )
    }
}

public struct AdjacencyHop: Sendable, Hashable {
    public var neighborID: UUID
    public var hop: GraphHop
}

public struct RelationshipGraph: Sendable {
    public let people: [UUID: PersonNode]
    public let adjacency: [UUID: [AdjacencyHop]]

    public init(people: [PersonNode], edges: [KinEdge]) {
        var peopleMap: [UUID: PersonNode] = [:]
        peopleMap.reserveCapacity(people.count)
        for person in people {
            peopleMap[person.id] = person
        }
        self.people = peopleMap

        var adj: [UUID: [AdjacencyHop]] = [:]
        func add(_ from: UUID, _ to: UUID, _ hop: GraphHop) {
            let candidate = AdjacencyHop(neighborID: to, hop: hop)
            if adj[from, default: []].contains(candidate) { return }
            adj[from, default: []].append(candidate)
        }

        for edge in edges {
            switch edge.kind {
            case .parent:
                add(edge.fromID, edge.toID, .child)
                add(edge.toID, edge.fromID, .parent)
            case .adoptiveParent:
                add(edge.fromID, edge.toID, .adoptedChild)
                add(edge.toID, edge.fromID, .adoptiveParent)
            case .stepParent:
                add(edge.fromID, edge.toID, .stepChild)
                add(edge.toID, edge.fromID, .stepParent)
            case .spouse:
                add(edge.fromID, edge.toID, .spouse)
                add(edge.toID, edge.fromID, .spouse)
            case .partner:
                add(edge.fromID, edge.toID, .partner)
                add(edge.toID, edge.fromID, .partner)
            }
        }
        self.adjacency = adj
    }

    public func person(_ id: UUID) -> PersonNode? {
        people[id]
    }

    /// Bidirectional BFS. Returns nil when `from` and `to` are disconnected.
    public func shortestPath(from start: UUID, to goal: UUID) -> KinPath? {
        guard people[start] != nil, people[goal] != nil else { return nil }
        if start == goal {
            return KinPath(personIDs: [start], hops: [])
        }

        var frontierF = [start]
        var frontierB = [goal]
        var cameFromF: [UUID: (UUID, GraphHop)] = [:]
        var cameFromB: [UUID: (UUID, GraphHop)] = [:]
        var visitedF: Set<UUID> = [start]
        var visitedB: Set<UUID> = [goal]

        while !frontierF.isEmpty && !frontierB.isEmpty {
            if frontierF.count <= frontierB.count {
                if let meeting = expand(
                    frontier: &frontierF,
                    visited: &visitedF,
                    cameFrom: &cameFromF,
                    otherVisited: visitedB
                ) {
                    return reconstruct(
                        meeting: meeting,
                        start: start,
                        goal: goal,
                        cameFromF: cameFromF,
                        cameFromB: cameFromB
                    )
                }
            } else if let meeting = expand(
                frontier: &frontierB,
                visited: &visitedB,
                cameFrom: &cameFromB,
                otherVisited: visitedF
            ) {
                return reconstruct(
                    meeting: meeting,
                    start: start,
                    goal: goal,
                    cameFromF: cameFromF,
                    cameFromB: cameFromB
                )
            }
        }
        return nil
    }

    public func shortestPathFrom(_ start: UUID) -> [UUID: KinPath] {
        var result: [UUID: KinPath] = [:]
        guard people[start] != nil else { return result }
        result[start] = KinPath(personIDs: [start], hops: [])

        var cameFrom: [UUID: (UUID, GraphHop)] = [:]
        var visited: Set<UUID> = [start]
        var queue: [UUID] = [start]
        var index = 0
        while index < queue.count {
            let node = queue[index]
            index += 1
            for adj in adjacency[node] ?? [] {
                if visited.contains(adj.neighborID) { continue }
                visited.insert(adj.neighborID)
                cameFrom[adj.neighborID] = (node, adj.hop)
                queue.append(adj.neighborID)
                result[adj.neighborID] = reconstructUnidirectional(to: adj.neighborID, start: start, cameFrom: cameFrom)
            }
        }
        return result
    }

    private func expand(
        frontier: inout [UUID],
        visited: inout Set<UUID>,
        cameFrom: inout [UUID: (UUID, GraphHop)],
        otherVisited: Set<UUID>
    ) -> UUID? {
        let level = frontier
        frontier = []
        for node in level {
            for adj in adjacency[node] ?? [] {
                if visited.contains(adj.neighborID) { continue }
                visited.insert(adj.neighborID)
                cameFrom[adj.neighborID] = (node, adj.hop)
                if otherVisited.contains(adj.neighborID) {
                    return adj.neighborID
                }
                frontier.append(adj.neighborID)
            }
        }
        return nil
    }

    private func reconstruct(
        meeting: UUID,
        start: UUID,
        goal: UUID,
        cameFromF: [UUID: (UUID, GraphHop)],
        cameFromB: [UUID: (UUID, GraphHop)]
    ) -> KinPath {
        var ids: [UUID] = [meeting]
        var hops: [GraphHop] = []

        var current = meeting
        while current != start {
            guard let (prev, hop) = cameFromF[current] else { break }
            ids.insert(prev, at: 0)
            hops.insert(hop, at: 0)
            current = prev
        }

        current = meeting
        while current != goal {
            guard let (prevTowardGoal, hopFromPrevToCurrent) = cameFromB[current] else { break }
            hops.append(hopFromPrevToCurrent.inverse)
            ids.append(prevTowardGoal)
            current = prevTowardGoal
        }

        return KinPath(personIDs: ids, hops: hops)
    }

    private func reconstructUnidirectional(
        to node: UUID,
        start: UUID,
        cameFrom: [UUID: (UUID, GraphHop)]
    ) -> KinPath {
        var ids: [UUID] = [node]
        var hops: [GraphHop] = []
        var current = node
        while current != start {
            guard let (prev, hop) = cameFrom[current] else { break }
            ids.insert(prev, at: 0)
            hops.insert(hop, at: 0)
            current = prev
        }
        return KinPath(personIDs: ids, hops: hops)
    }
}
