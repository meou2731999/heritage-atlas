import HeritageAtlasCore
import SwiftUI
import UIKit

struct PersonGlanceView: View {
    let snapshot: WatchSnapshot
    let person: WatchPerson

    private var relationship: WatchRelationship? {
        WatchSnapshotExplorer.relationship(for: person.id, in: snapshot)
    }

    private var isMe: Bool {
        person.id == snapshot.mePersonID || relationship?.code == .self
    }

    private var pathLines: [String] {
        WatchSnapshotExplorer.pathGlanceLines(relationship?.pathGlance ?? "")
    }

    private var featured: WatchMemory? {
        WatchSnapshotExplorer.featuredMemory(for: person.id, in: snapshot)
    }

    private var moments: [WatchTimelineMoment] {
        Array(WatchSnapshotExplorer.timelineMoments(for: person.id, in: snapshot).prefix(2))
    }

    var body: some View {
        List {
            Section {
                Text(person.displayName)
                    .font(.headline)
                if let nickname = person.nickname, nickname != person.fullName {
                    Text(person.fullName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let term = relationship?.term {
                    Text(term)
                        .font(.title3)
                }
            }

            if isMe {
                Section {
                    Text(snapshot.localeKinship == .vi ? "Đây là bạn" : "This is you")
                }
            } else if let relationship {
                Section(snapshot.localeKinship == .vi ? "Đây là ai?" : "Who is this?") {
                    glanceLabeled(
                        title: snapshot.localeKinship == .vi ? "Bạn gọi" : "You call",
                        value: relationship.youCallThem
                    )
                    if !relationship.pathExplanation.isEmpty {
                        Text(relationship.pathExplanation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(snapshot.localeKinship == .vi ? "Mình là ai với \(person.displayName)?" : "Who am I to \(person.displayName)?") {
                    glanceLabeled(
                        title: snapshot.localeKinship == .vi ? "Họ gọi bạn" : "They call you",
                        value: relationship.theyCallYou
                    )
                }
            } else {
                Section {
                    Text(snapshot.localeKinship == .vi ? "Chưa có quan hệ trong cache" : "No relationship on file")
                        .foregroundStyle(.secondary)
                }
            }

            if !pathLines.isEmpty {
                Section(snapshot.localeKinship == .vi ? "Đường đi" : "Path") {
                    ForEach(Array(pathLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(line == "YOU" || line == "Bạn" ? .headline : .body)
                            .monospaced()
                    }
                }
            }

            if let featured {
                Section(snapshot.localeKinship == .vi ? "Kỷ niệm" : "Memory") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(featured.title)
                            .font(.headline)
                        if let jpeg = featured.thumbnailJPEG, let image = UIImage(data: jpeg) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxHeight: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        if let preview = featured.bodyPreview, preview.isEmpty == false {
                            Text(preview)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        if let audio = featured.audioPreview, audio.isEmpty == false {
                            WatchClipPlayer(data: audio)
                        }
                    }
                }
            }

            if moments.isEmpty == false {
                Section(snapshot.localeKinship == .vi ? "Khoảnh khắc" : "Moments") {
                    ForEach(moments) { moment in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(moment.title)
                                .font(.headline)
                            Text(moment.kind.localizedName(snapshot.localeKinship))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                NavigationLink {
                    RecordStoryView(snapshot: snapshot, personID: person.id)
                } label: {
                    Label(snapshot.localeKinship == .vi ? "Ghi chuyện" : "Record story", systemImage: "mic.fill")
                }
            }
        }
        .navigationTitle(person.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func glanceLabeled(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let snapshot = WatchSnapshotExplorer.sample()
    NavigationStack {
        PersonGlanceView(snapshot: snapshot, person: snapshot.favorites[1])
    }
}
