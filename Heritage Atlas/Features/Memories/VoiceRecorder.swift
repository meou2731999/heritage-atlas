import AVFoundation
import Foundation
import HeritageAtlasCore
import Observation
import SwiftUI

@Observable
final class VoiceRecorder {
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
            errorMessage = HeritageLocale.string("Microphone access is off. Enable it in Settings to record a story.")
            return false
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appending(path: "heritage-story-\(UUID().uuidString).m4a")
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

struct MemoryAudioPlayer: View {
    let url: URL
    var durationSeconds: Double?

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false

    var body: some View {
        Button {
            toggle()
        } label: {
            Label(isPlaying ? LocalizedStringKey("Pause") : LocalizedStringKey("Play"), systemImage: isPlaying ? "pause.fill" : "play.fill")
        }
        .onDisappear {
            player?.stop()
            isPlaying = false
        }
    }

    private func toggle() {
        if isPlaying {
            player?.pause()
            isPlaying = false
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            if player == nil {
                player = try AVAudioPlayer(contentsOf: url)
            }
            player?.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }
}
