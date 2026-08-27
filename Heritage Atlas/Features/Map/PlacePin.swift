import Foundation
import HeritageAtlasCore
import MapKit

struct PlacePin: Identifiable, Hashable {
    let id: UUID
    var name: String
    var point: GeoPoint
    var roles: [PlaceRole]
    var personIDs: [UUID]
    var memoryCount: Int

    var primaryRole: PlaceRole { roles.first ?? .home }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    static func build(
        places: [Place],
        links: [PersonPlace],
        memories: [Memory],
        burialOnly: Bool
    ) -> [PlacePin] {
        let linksByPlace = Dictionary(grouping: links.filter { $0.place != nil }) { $0.place!.id }
        return places.compactMap { place in
            guard let latitude = place.latitude, let longitude = place.longitude else { return nil }
            let placeLinks = linksByPlace[place.id] ?? []
            let burialLinks = placeLinks.filter { $0.role == .burial }
            if burialOnly, burialLinks.isEmpty { return nil }
            let usedLinks = burialOnly ? burialLinks : placeLinks
            var roles: [PlaceRole] = []
            var seen = Set<PlaceRole>()
            for link in usedLinks where seen.insert(link.role).inserted {
                roles.append(link.role)
            }
            if roles.isEmpty { roles = burialOnly ? [.burial] : [.home] }
            let personIDs = uniqued(usedLinks.compactMap { $0.person?.id })
            let memoryCount = memories.filter { $0.placeIDs.contains(place.id) }.count
            return PlacePin(
                id: place.id,
                name: place.name,
                point: GeoPoint(latitude: latitude, longitude: longitude),
                roles: roles,
                personIDs: personIDs,
                memoryCount: memoryCount
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func uniqued(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }
}

struct MapGlyph: Identifiable {
    var id: String
    var title: String
    var coordinate: CLLocationCoordinate2D
    var isCluster: Bool
    var count: Int
    var pinID: UUID?
    var memberIDs: [UUID]
    var role: PlaceRole
}

enum PlaceMapRegion {
    static func region(fitting points: [GeoPoint]) -> MKCoordinateRegion {
        if let box = GeoMath.boundingBox(points: points) {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: box.center.latitude, longitude: box.center.longitude),
                span: MKCoordinateSpan(latitudeDelta: box.latitudeDelta, longitudeDelta: box.longitudeDelta)
            )
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 16.47, longitude: 107.59),
            span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
        )
    }

    static func region(around point: GeoPoint, span: Double = 0.04) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }
}
