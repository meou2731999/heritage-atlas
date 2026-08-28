import HeritageAtlasCore
import SwiftUI

struct PlaceRowView: View {
    let place: Place
    var subtitle: String?
    var role: PlaceRole?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: (role ?? .home).systemImageName)
                .font(.body.weight(.semibold))
                .foregroundStyle((role ?? .home).mapTint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if place.name.isEmpty {
                        Text("Unnamed place")
                    } else {
                        Text(place.name)
                    }
                }
                .font(.body.weight(.medium))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if place.hasCoordinates {
                    Text("On the map")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No coordinates")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
