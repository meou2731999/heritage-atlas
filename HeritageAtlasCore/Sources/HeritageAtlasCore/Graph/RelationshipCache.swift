import Foundation
import Observation
import SwiftData

public struct RelationshipCacheEntry: Sendable, Equatable, Codable, Identifiable {
    public var personID: UUID
    public var pathPersonIDs: [UUID]
    public var hops: [GraphHop]
    public var code: KinshipCode
    public var naming: KinshipNaming
    public var pathGlance: String

    public var id: UUID { personID }

    public init(
        personID: UUID,
        pathPersonIDs: [UUID],
        hops: [GraphHop],
        code: KinshipCode,
        naming: KinshipNaming,
        pathGlance: String
    ) {
        self.personID = personID
        self.pathPersonIDs = pathPersonIDs
        self.hops = hops
        self.code = code
        self.naming = naming
        self.pathGlance = pathGlance
    }
}

public struct RelationshipCache: Sendable, Equatable {
    public var mePersonID: UUID?
    public var generatedAt: Date
    public var locale: KinshipLocale
    public var entriesByPersonID: [UUID: RelationshipCacheEntry]

    public static let empty = RelationshipCache(
        mePersonID: nil,
        generatedAt: .distantPast,
        locale: .vi,
        entriesByPersonID: [:]
    )

    public init(
        mePersonID: UUID?,
        generatedAt: Date = Date(),
        locale: KinshipLocale,
        entriesByPersonID: [UUID: RelationshipCacheEntry]
    ) {
        self.mePersonID = mePersonID
        self.generatedAt = generatedAt
        self.locale = locale
        self.entriesByPersonID = entriesByPersonID
    }

    public func entry(for personID: UUID) -> RelationshipCacheEntry? {
        entriesByPersonID[personID]
    }

    /// Precomputes me → every reachable person. Call again whenever the graph or Me / locale changes.
    public static func rebuild(
        meID: UUID,
        graph: RelationshipGraph,
        locale: KinshipLocale,
        now: Date = Date()
    ) -> RelationshipCache {
        let paths = graph.shortestPathFrom(meID)
        var entries: [UUID: RelationshipCacheEntry] = [:]
        entries.reserveCapacity(paths.count)
        for (personID, path) in paths {
            let forward = KinshipClassifier.classify(path: path, graph: graph)
            let reverse = KinshipClassifier.classify(path: path.reversed, graph: graph)
            let naming = KinshipNamer.name(forward, locale: locale, reverse: reverse)
            entries[personID] = RelationshipCacheEntry(
                personID: personID,
                pathPersonIDs: path.personIDs,
                hops: path.hops,
                code: forward.code,
                naming: naming,
                pathGlance: Self.pathGlance(path: path, graph: graph)
            )
        }
        return RelationshipCache(
            mePersonID: meID,
            generatedAt: now,
            locale: locale,
            entriesByPersonID: entries
        )
    }

    public static func pathGlance(path: KinPath, graph: RelationshipGraph) -> String {
        if path.hops.isEmpty { return "YOU" }
        var parts = ["YOU"]
        for index in path.hops.indices {
            guard let person = graph.person(path.personIDs[index + 1]) else { continue }
            let role = EnglishKinshipNamer.shortRole(hop: path.hops[index], person: person)
            parts.append("\(path.hops[index].glanceArrow) \(role)")
        }
        return parts.joined(separator: " ")
    }
}

@MainActor
@Observable
public final class RelationshipCacheController {
    public private(set) var cache: RelationshipCache = .empty

    public init() {}

    public func rebuild(from context: ModelContext) throws {
        let settings = AppSettings.current(in: context)
        guard let meID = settings.mePersonID else {
            cache = .empty
            return
        }
        let graph = try RelationshipGraphBuilder.make(from: context)
        cache = RelationshipCache.rebuild(meID: meID, graph: graph, locale: settings.localeKinship)
    }
}

@MainActor
public enum RelationshipGraphBuilder {
    public static func make(from context: ModelContext) throws -> RelationshipGraph {
        let people = try context.fetch(FetchDescriptor<Person>()).map { $0.asNode() }
        let edges = try context.fetch(FetchDescriptor<KinRelationship>()).compactMap { $0.asEdge() }
        return RelationshipGraph(people: people, edges: edges)
    }
}
