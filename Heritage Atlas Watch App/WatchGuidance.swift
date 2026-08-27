import HeritageAtlasCore
import SwiftUI
import WatchKit
import AVFoundation

enum WatchApproachHaptics {
    static func play(_ band: ApproachBand) {
        let device = WKInterfaceDevice.current()
        switch band {
        case .approaching:
            device.play(.directionUp)
        case .near:
            device.play(.notification)
        case .arrived:
            device.play(.success)
        }
    }
}

enum WatchMaps {
    static func navigate(to place: WatchPlace) {
        guard let latitude = place.latitude, let longitude = place.longitude else { return }
        var components = URLComponents(string: "maps://")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: place.name),
        ]
        if let url = components?.url {
            WKApplication.shared().openSystemURL(url)
        }
    }
}

struct HeadingCompass: View {
    var relativeDegrees: Double?

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.45), lineWidth: 2)
            if let relativeDegrees {
                Image(systemName: "location.north.fill")
                    .font(.title3)
                    .rotationEffect(.degrees(relativeDegrees))
            } else {
                Image(systemName: "location.slash")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel(relativeDegrees == nil ? "Heading unavailable" : "Heading to place")
    }
}

struct WatchClipPlayer: View {
    let data: Data

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false

    var body: some View {
        Button {
            toggle()
        } label: {
            Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                .font(.caption)
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
                player = try AVAudioPlayer(data: data)
            }
            player?.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }
}
