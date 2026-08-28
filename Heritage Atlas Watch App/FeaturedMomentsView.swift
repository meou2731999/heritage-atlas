import HeritageAtlasCore
import SwiftUI
import UIKit

struct FeaturedMomentsView: View {
    let snapshot: WatchSnapshot

    private var memories: [WatchMemory] { snapshot.featuredMemories }
    private var moments: [WatchTimelineMoment] {
        WatchSnapshotExplorer.timelineMoments(in: snapshot)
    }

    var body: some View {
        if memories.isEmpty && moments.isEmpty {
            ContentUnavailableView {
                Label("No moments yet", systemImage: "star")
            } description: {
                Text("Record a story, or feature a memory on iPhone.")
            }
        } else {
            TabView {
                ForEach(memories) { memory in
                    featuredCard(memory)
                }
                ForEach(moments) { moment in
                    momentCard(moment)
                }
            }
            .tabViewStyle(.verticalPage)
            .navigationTitle("Moments")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func featuredCard(_ memory: WatchMemory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Featured", systemImage: memory.kind.systemImageName)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(memory.title)
                .font(.headline)
            if let jpeg = memory.thumbnailJPEG, let image = UIImage(data: jpeg) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            if let audio = memory.audioPreview, audio.isEmpty == false {
                WatchClipPlayer(data: audio)
            }
            if let name = memory.personName, name.isEmpty == false {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let preview = memory.bodyPreview, preview.isEmpty == false {
                Text(preview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            if let seconds = memory.durationSeconds {
                Text(WatchVoiceRecorder.formatElapsed(seconds))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func momentCard(_ moment: WatchTimelineMoment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(moment.kind.localizedName(snapshot.localeKinship), systemImage: moment.kind.systemImageName)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(moment.title)
                .font(.headline)
            Text(moment.personName)
                .font(.caption)
            if let place = moment.placeName {
                Text(place)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let memoryTitle = moment.memoryTitle {
                Label(memoryTitle, systemImage: "waveform")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(MemoryDateGlance.string(moment.date))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

enum MemoryDateGlance {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func string(_ date: Date) -> String {
        formatter.locale = HeritageLocale.locale
        return formatter.string(from: date)
    }
}
