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
                    Text("This is you")
                }
            } else if let relationship {
                Section("Who is this?") {
                    glanceLabeled(
                        title: "You call",
                        value: relationship.youCallThem
                    )
                    if !relationship.pathExplanation.isEmpty {
                        Text(relationship.pathExplanation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    glanceLabeled(
                        title: "They call you",
                        value: relationship.theyCallYou
                    )
                } header: {
                    Text("Who am I to \(person.displayName)?")
                }
            } else {
                Section {
                    Text("No relationship on file")
                        .foregroundStyle(.secondary)
                }
            }

            if !pathLines.isEmpty {
                Section("Path") {
                    ForEach(Array(pathLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(line == "YOU" || line == "Bạn" ? .headline : .body)
                            .monospaced()
                    }
                }
            }

            if let featured {
                Section("Memory") {
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
                Section("Moments") {
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
                    Label("Record story", systemImage: "mic.fill")
                }
            }
        }
        .navigationTitle(person.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func glanceLabeled(title: LocalizedStringKey, value: String) -> some View {
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
