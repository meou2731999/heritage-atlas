import HeritageAtlasCore
import SwiftUI

struct WatchPersonRow: View {
    let person: WatchPerson
    let relationship: WatchRelationship?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(person.displayName)
                    .lineLimit(1)
                if person.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                }
            }
            if let relationship {
                Text(relationship.term)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
