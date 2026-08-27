import Foundation

public struct FamilyInsightPerson: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var birthDate: Date?

    public init(id: UUID, name: String, birthDate: Date? = nil) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
    }
}

public struct FamilyGenerationBucket: Sendable, Equatable, Identifiable {
    public var id: Int { generation }
    public var generation: Int
    public var people: [FamilyInsightPerson]

    public var count: Int { people.count }

    public init(generation: Int, people: [FamilyInsightPerson]) {
        self.generation = generation
        self.people = people
    }
}

public struct FamilyInsights: Sendable, Equatable {
    public var peopleCount: Int
    public var livingCount: Int
    public var deceasedCount: Int
    public var placeCount: Int
    public var burialCount: Int
    public var memoryCount: Int
    public var storyCount: Int
    public var generationCount: Int
    public var oldestAncestor: FamilyInsightPerson?
    public var largestGeneration: FamilyGenerationBucket?
    public var generations: [FamilyGenerationBucket]

    public init(
        peopleCount: Int,
        livingCount: Int,
        deceasedCount: Int,
        placeCount: Int,
        burialCount: Int,
        memoryCount: Int,
        storyCount: Int,
        generationCount: Int,
        oldestAncestor: FamilyInsightPerson?,
        largestGeneration: FamilyGenerationBucket?,
        generations: [FamilyGenerationBucket]
    ) {
        self.peopleCount = peopleCount
        self.livingCount = livingCount
        self.deceasedCount = deceasedCount
        self.placeCount = placeCount
        self.burialCount = burialCount
        self.memoryCount = memoryCount
        self.storyCount = storyCount
        self.generationCount = generationCount
        self.oldestAncestor = oldestAncestor
        self.largestGeneration = largestGeneration
        self.generations = generations
    }

    public var watchGlance: WatchInsightsGlance {
        WatchInsightsGlance(livingCount: livingCount, generationCount: generationCount)
    }
}

public enum FamilyInsightsEngine: Sendable {
    public static func compute(
        people: [PersonNode],
        graph: RelationshipGraph,
        mePersonID: UUID?,
        placeCount: Int,
        burialCount: Int,
        memoryCount: Int,
        storyCount: Int
    ) -> FamilyInsights {
        let living = people.filter(\.isLiving)
        let generationMap = GenerationIndex.generations(in: graph)
        let peopleByGeneration = Dictionary(grouping: people) { generationMap[$0.id] ?? 0 }
        let buckets: [FamilyGenerationBucket] = peopleByGeneration.keys.sorted().map { generation in
            let members = graph.sortedByBirth(peopleByGeneration[generation] ?? []).map {
                FamilyInsightPerson(id: $0.id, name: $0.displayName, birthDate: $0.birthDate)
            }
            return FamilyGenerationBucket(generation: generation, people: members)
        }
        let largest = buckets.max { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count < rhs.count }
            return lhs.generation > rhs.generation
        }

        return FamilyInsights(
            peopleCount: people.count,
            livingCount: living.count,
            deceasedCount: people.count - living.count,
            placeCount: placeCount,
            burialCount: burialCount,
            memoryCount: memoryCount,
            storyCount: storyCount,
            generationCount: GenerationIndex.count(in: graph),
            oldestAncestor: oldestAncestor(in: graph, mePersonID: mePersonID),
            largestGeneration: largest,
            generations: buckets
        )
    }

    private static func oldestAncestor(in graph: RelationshipGraph, mePersonID: UUID?) -> FamilyInsightPerson? {
        let candidates: [PersonNode]
        if let mePersonID {
            let ancestors = graph.ancestors(of: mePersonID)
            candidates = ancestors.isEmpty ? Array(graph.people.values) : ancestors
        } else {
            candidates = Array(graph.people.values)
        }
        let withBirth = candidates.filter { $0.birthDate != nil }
        let pool = withBirth.isEmpty ? candidates : withBirth
        guard let oldest = graph.sortedByBirth(pool).first else { return nil }
        return FamilyInsightPerson(id: oldest.id, name: oldest.displayName, birthDate: oldest.birthDate)
    }
}

extension PersonNode {
    public var isLiving: Bool { deathDate == nil }
}
