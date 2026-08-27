import HeritageAtlasCore
import SwiftUI

struct PersonRowView: View {
    let person: Person
    var subtitle: String?
    var showMeBadge = false

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatarView(person: person, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(person.displayName)
                        .font(.body.weight(.medium))
                    if showMeBadge {
                        Text("Me")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                if person.nickname != nil, person.nickname != person.fullName {
                    Text(person.fullName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !person.lifeYearsText.isEmpty {
                    Text(person.lifeYearsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
