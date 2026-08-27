import CoreGraphics
import Foundation
import HeritageAtlasCore

struct TreeNodeFrame: Identifiable, Equatable {
    var id: UUID
    var person: PersonNode
    var center: CGPoint
    var isFocus: Bool
    var isCollapsed: Bool
    var canCollapse: Bool
}

struct TreeEdge: Hashable {
    var from: UUID
    var to: UUID
    var hop: GraphHop
}

struct TreeLayout: Equatable {
    var nodes: [UUID: TreeNodeFrame]
    var edges: [TreeEdge]
    var bounds: CGRect

    static let empty = TreeLayout(nodes: [:], edges: [], bounds: CGRect(x: 0, y: 0, width: 320, height: 240))

    var nodeList: [TreeNodeFrame] {
        nodes.values.sorted { lhs, rhs in
            if lhs.center.y != rhs.center.y { return lhs.center.y < rhs.center.y }
            return lhs.center.x < rhs.center.x
        }
    }
}

enum TreeLayoutEngine {
    static let cardSize = CGSize(width: 152, height: 82)
    static let horizontalSpacing: CGFloat = 22
    static let verticalSpacing: CGFloat = 108
    static let coupleSpacing: CGFloat = 14
    static let padding: CGFloat = 48

    static func layout(
        graph: RelationshipGraph,
        focusID: UUID,
        collapsedIDs: Set<UUID>
    ) -> TreeLayout {
        guard graph.person(focusID) != nil else { return .empty }
        return Builder(graph: graph, focusID: focusID, collapsedIDs: collapsedIDs).build()
    }

    private final class Builder {
        let graph: RelationshipGraph
        let focusID: UUID
        let collapsedIDs: Set<UUID>
        var positions: [UUID: CGPoint] = [:]

        init(graph: RelationshipGraph, focusID: UUID, collapsedIDs: Set<UUID>) {
            self.graph = graph
            self.focusID = focusID
            self.collapsedIDs = collapsedIDs
        }

        func build() -> TreeLayout {
            _ = assignDescendants(id: focusID, left: 0, y: 0, visiting: [])
            placeSiblings()
            assignAncestors(of: focusID, at: positions[focusID] ?? .zero, visiting: [focusID])

            var frames: [UUID: TreeNodeFrame] = [:]
            for (id, center) in positions {
                guard let person = graph.person(id) else { continue }
                let childCount = graph.children(of: id).count
                frames[id] = TreeNodeFrame(
                    id: id,
                    person: person,
                    center: center,
                    isFocus: id == focusID,
                    isCollapsed: collapsedIDs.contains(id),
                    canCollapse: childCount > 0
                )
            }

            let edges = makeEdges(visible: Set(frames.keys))
            let bounds = boundsOf(frames.values.map(\.center))
            return TreeLayout(nodes: frames, edges: edges, bounds: bounds)
        }

        private func coupleMembers(_ id: UUID) -> [UUID] {
            var members = [id]
            let spouses = graph.sortedByBirth(graph.spousesAndPartners(of: id))
            for spouse in spouses where !members.contains(spouse.id) {
                members.append(spouse.id)
            }
            return members
        }

        private func coupleWidth(_ id: UUID) -> CGFloat {
            let count = CGFloat(coupleMembers(id).count)
            return count * TreeLayoutEngine.cardSize.width
                + max(0, count - 1) * TreeLayoutEngine.coupleSpacing
        }

        private func familyChildren(_ id: UUID) -> [PersonNode] {
            guard !collapsedIDs.contains(id) else { return [] }
            var seen = Set<UUID>()
            var children: [PersonNode] = []
            for member in coupleMembers(id) {
                for child in graph.children(of: member) where seen.insert(child.id).inserted {
                    children.append(child)
                }
            }
            return graph.sortedByBirth(children)
        }

        private func subtreeWidth(_ id: UUID, visiting: Set<UUID>) -> CGFloat {
            var visiting = visiting
            if !visiting.insert(id).inserted {
                return TreeLayoutEngine.cardSize.width
            }
            let own = coupleWidth(id)
            let children = familyChildren(id).filter { !visiting.contains($0.id) }
            guard !children.isEmpty else { return own }
            let childrenWidth = children.reduce(CGFloat(0)) { partial, child in
                partial + subtreeWidth(child.id, visiting: visiting)
            } + TreeLayoutEngine.horizontalSpacing * CGFloat(children.count - 1)
            return max(own, childrenWidth)
        }

        @discardableResult
        private func assignDescendants(id: UUID, left: CGFloat, y: CGFloat, visiting: Set<UUID>) -> CGFloat {
            var visiting = visiting
            if !visiting.insert(id).inserted { return TreeLayoutEngine.cardSize.width }
            if positions[id] != nil { return coupleWidth(id) }

            let width = subtreeWidth(id, visiting: [])
            let members = coupleMembers(id).filter { positions[$0] == nil || $0 == id }
            let own = coupleWidth(id)
            var memberX = left + (width - own) / 2 + TreeLayoutEngine.cardSize.width / 2
            for member in members where positions[member] == nil {
                positions[member] = CGPoint(x: memberX, y: y)
                memberX += TreeLayoutEngine.cardSize.width + TreeLayoutEngine.coupleSpacing
            }

            let children = familyChildren(id).filter { positions[$0.id] == nil }
            guard !children.isEmpty else { return width }

            let childrenWidth = children.reduce(CGFloat(0)) { partial, child in
                partial + subtreeWidth(child.id, visiting: visiting)
            } + TreeLayoutEngine.horizontalSpacing * CGFloat(max(0, children.count - 1))
            var childLeft = left + (width - childrenWidth) / 2
            let childY = y + TreeLayoutEngine.verticalSpacing
            for child in children {
                let childWidth = subtreeWidth(child.id, visiting: visiting)
                assignDescendants(id: child.id, left: childLeft, y: childY, visiting: visiting)
                childLeft += childWidth + TreeLayoutEngine.horizontalSpacing
            }
            return width
        }

        private func placeSiblings() {
            guard let focusPoint = positions[focusID] else { return }
            let siblings = graph.sortedByBirth(graph.siblings(of: focusID)).filter { positions[$0.id] == nil }
            guard !siblings.isEmpty else { return }

            let coupleMinX = coupleMembers(focusID).compactMap { positions[$0]?.x }.min()
                ?? focusPoint.x
            let leftEdge = coupleMinX - TreeLayoutEngine.cardSize.width / 2

            var units: [(id: UUID, width: CGFloat)] = []
            for sibling in siblings {
                units.append((sibling.id, coupleWidth(sibling.id)))
            }
            let total = units.reduce(CGFloat(0)) { $0 + $1.width }
                + TreeLayoutEngine.horizontalSpacing * CGFloat(max(0, units.count - 1))
            var cursor = leftEdge - TreeLayoutEngine.horizontalSpacing - total
            for unit in units {
                let members = coupleMembers(unit.id).filter { positions[$0] == nil }
                var x = cursor + TreeLayoutEngine.cardSize.width / 2
                for member in members {
                    positions[member] = CGPoint(x: x, y: focusPoint.y)
                    x += TreeLayoutEngine.cardSize.width + TreeLayoutEngine.coupleSpacing
                }
                cursor += unit.width + TreeLayoutEngine.horizontalSpacing
            }
        }

        private func ancestorWidth(_ id: UUID, visiting: Set<UUID>) -> CGFloat {
            var visiting = visiting
            if !visiting.insert(id).inserted {
                return TreeLayoutEngine.cardSize.width
            }
            let parents = graph.sortedParents(graph.parents(of: id))
            let own = TreeLayoutEngine.cardSize.width
            guard !parents.isEmpty else { return own }
            let width = parents.reduce(CGFloat(0)) { partial, parent in
                partial + ancestorWidth(parent.id, visiting: visiting)
            } + TreeLayoutEngine.horizontalSpacing * CGFloat(parents.count - 1)
            return max(own, width)
        }

        private func assignAncestors(of id: UUID, at point: CGPoint, visiting: Set<UUID>) {
            var visiting = visiting
            visiting.insert(id)
            let parents = graph.sortedParents(graph.parents(of: id)).filter { !visiting.contains($0.id) }
            guard !parents.isEmpty else { return }

            let widths = parents.map { ancestorWidth($0.id, visiting: visiting) }
            let total = widths.reduce(0, +)
                + TreeLayoutEngine.horizontalSpacing * CGFloat(max(0, parents.count - 1))
            var left = point.x - total / 2
            let parentY = point.y - TreeLayoutEngine.verticalSpacing

            for (parent, width) in zip(parents, widths) {
                let midX = left + width / 2
                if positions[parent.id] == nil {
                    positions[parent.id] = CGPoint(x: midX, y: parentY)
                }
                if let placed = positions[parent.id] {
                    assignAncestors(of: parent.id, at: placed, visiting: visiting)
                }
                left += width + TreeLayoutEngine.horizontalSpacing
            }
        }

        private func makeEdges(visible: Set<UUID>) -> [TreeEdge] {
            var edges: [TreeEdge] = []
            var seen = Set<TreeEdge>()
            for id in visible {
                for neighbor in graph.adjacency[id] ?? [] where visible.contains(neighbor.neighborID) {
                    let hop = neighbor.hop
                    let edge: TreeEdge
                    if hop.axis == .down {
                        edge = TreeEdge(from: id, to: neighbor.neighborID, hop: hop)
                    } else if hop.axis == .up {
                        edge = TreeEdge(from: neighbor.neighborID, to: id, hop: hop.inverse)
                    } else if hop == .spouse || hop == .partner {
                        let pair = ordered(id, neighbor.neighborID)
                        edge = TreeEdge(from: pair.0, to: pair.1, hop: hop)
                    } else {
                        continue
                    }
                    if seen.insert(edge).inserted {
                        edges.append(edge)
                    }
                }
            }
            return edges
        }

        private func ordered(_ a: UUID, _ b: UUID) -> (UUID, UUID) {
            a.uuidString < b.uuidString ? (a, b) : (b, a)
        }

        private func boundsOf(_ points: [CGPoint]) -> CGRect {
            let pad = TreeLayoutEngine.padding
            let halfW = TreeLayoutEngine.cardSize.width / 2
            let halfH = TreeLayoutEngine.cardSize.height / 2
            guard let first = points.first else {
                return CGRect(x: -160, y: -120, width: 320, height: 240)
            }
            var minX = first.x
            var maxX = first.x
            var minY = first.y
            var maxY = first.y
            for point in points {
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
            return CGRect(
                x: minX - halfW - pad,
                y: minY - halfH - pad,
                width: (maxX - minX) + TreeLayoutEngine.cardSize.width + pad * 2,
                height: (maxY - minY) + TreeLayoutEngine.cardSize.height + pad * 2
            )
        }
    }
}
