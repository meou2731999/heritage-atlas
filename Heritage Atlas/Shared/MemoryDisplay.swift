import HeritageAtlasCore
import SwiftUI
import UIKit

extension MemoryKind {
    var displayName: String { localizedName(.en) }
}

extension TimelineEventKind {
    var displayName: String { localizedName(.en) }
}

enum MemoryQueries {
    static func forPerson(_ id: UUID, in memories: [Memory]) -> [Memory] {
        sorted(memories.filter { $0.personIDs.contains(id) })
    }

    static func forPlace(_ id: UUID, in memories: [Memory]) -> [Memory] {
        sorted(memories.filter { $0.placeIDs.contains(id) })
    }

    static func hearable(in memories: [Memory]) -> [Memory] {
        sorted(memories.filter { $0.kind.isHearable })
    }

    static func stories(in memories: [Memory]) -> [Memory] {
        sorted(memories.filter { $0.kind == .story })
    }

    static func photos(for personID: UUID, in memories: [Memory]) -> [Memory] {
        sorted(memories.filter { $0.kind == .photo && $0.personIDs.contains(personID) })
    }

    static func unassignedWatch(in memories: [Memory]) -> [Memory] {
        sorted(memories.filter { $0.isFromWatch && $0.personIDs.isEmpty })
    }

    static func sorted(_ memories: [Memory]) -> [Memory] {
        memories.sorted { lhs, rhs in
            switch (lhs.occurredOn, rhs.occurredOn) {
            case (let left?, let right?) where left != right:
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }
}

enum MemoryDateText {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func short(_ date: Date?) -> String? {
        guard let date else { return nil }
        return formatter.string(from: date)
    }
}

struct MemoryRowView: View {
    let memory: Memory
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: memory.kind.systemImageName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(memory.title.isEmpty ? "Untitled" : memory.title)
                        .font(.body.weight(.medium))
                    if memory.isFeatured {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(defaultSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var defaultSubtitle: String {
        var parts = [memory.kind.displayName]
        if let date = MemoryDateText.short(memory.occurredOn) {
            parts.append(date)
        }
        if memory.isFromWatch {
            parts.append("Watch")
        }
        return parts.joined(separator: " · ")
    }
}

struct MediaImageView: View {
    let mediaID: UUID
    var cornerRadius: CGFloat = 10

    @Environment(FamilySession.self) private var session
    @State private var imageData: Data?

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.tertiarySystemFill)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: mediaID) {
            imageData = await session.mediaData(for: mediaID)
        }
    }
}
