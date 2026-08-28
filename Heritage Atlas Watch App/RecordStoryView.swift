import AVFoundation
import HeritageAtlasCore
import SwiftUI

struct RecordStoryView: View {
    let snapshot: WatchSnapshot
    var personID: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = WatchVoiceRecorder()
    @State private var sent = false
    @State private var sending = false

    private var person: WatchPerson? {
        personID.flatMap { WatchSnapshotExplorer.person(id: $0, in: snapshot) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: recorder.isRecording ? "mic.fill" : "mic")
                    .font(.title)
                    .foregroundStyle(recorder.isRecording ? .red : .accentColor)
                Text(statusTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if let person {
                    Text(person.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if recorder.isRecording {
                    Text(WatchVoiceRecorder.formatElapsed(recorder.elapsedSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let message = recorder.errorMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                if sent {
                    Text("Sent to iPhone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if recorder.isRecording {
                    Button("Stop") {
                        recorder.stop()
                    }
                    .tint(.red)
                } else if recorder.recordedURL != nil, sent == false {
                    Button("Done") {
                        Task { await send() }
                    }
                    .disabled(sending)
                    Button("Record again", role: .destructive) {
                        recorder.discard()
                        Task { _ = await recorder.start() }
                    }
                } else if sent == false {
                    Button("Record") {
                        Task { _ = await recorder.start() }
                    }
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle("Record story")
        .task {
            if recorder.recordedURL == nil, recorder.isRecording == false, sent == false {
                _ = await recorder.start()
            }
        }
        .onDisappear {
            if sent == false, recorder.isRecording {
                recorder.stop()
            }
        }
    }

    private var statusTitle: LocalizedStringKey {
        if sent { return "Sent" }
        if recorder.isRecording { return "Recording…" }
        if recorder.recordedURL != nil { return "Ready to send" }
        return "Tap to record"
    }

    private func send() async {
        guard let url = recorder.recordedURL else { return }
        sending = true
        let message = WatchAudioRecordingMessage(
            fileName: url.lastPathComponent,
            personID: personID,
            recordedAt: Date()
        )
        do {
            _ = try WatchConnectivityService.shared.sendAudioRecording(fileURL: url, message: message)
            sent = true
            try? WatchConnectivityService.shared.sendAudioRecordingMessage(message)
            try? await Task.sleep(for: .milliseconds(600))
            dismiss()
        } catch {
            recorder.errorMessage = error.localizedDescription
            sending = false
        }
    }
}

@Observable
final class WatchVoiceRecorder {
    var isRecording = false
    var recordedURL: URL?
    var elapsedSeconds: TimeInterval = 0
    var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var startedAt: Date?

    func start() async -> Bool {
        errorMessage = nil
        let granted = await Self.requestPermission()
        guard granted else {
            errorMessage = HeritageLocale.string("Microphone is off")
            return false
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio)
            try session.setActive(true)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appending(path: "heritage-watch-\(UUID().uuidString).m4a")
            let recorder = try AVAudioRecorder(url: url, settings: Self.settings)
            recorder.record()
            self.recorder = recorder
            recordedURL = url
            startedAt = Date()
            elapsedSeconds = 0
            isRecording = true
            Task { await tickElapsed() }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        if let startedAt {
            elapsedSeconds = Date().timeIntervalSince(startedAt)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func discard() {
        stop()
        if let recordedURL {
            try? FileManager.default.removeItem(at: recordedURL)
        }
        recordedURL = nil
        elapsedSeconds = 0
    }

    static func formatElapsed(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    private func tickElapsed() async {
        while isRecording {
            try? await Task.sleep(for: .milliseconds(400))
            if let startedAt {
                elapsedSeconds = Date().timeIntervalSince(startedAt)
            }
        }
    }

    private static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private static var settings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
    }
}
