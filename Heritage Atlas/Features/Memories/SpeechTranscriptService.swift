import Foundation
import Speech

enum SpeechTranscriptError: LocalizedError {
    case unavailable
    case notAuthorized
    case empty

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "On-device speech recognition isn’t available on this iPhone. You can type the transcript instead."
        case .notAuthorized:
            "Speech recognition is off. Enable it in Settings, or type the transcript."
        case .empty:
            "No speech was recognized. Try again or type the transcript."
        }
    }
}

enum SpeechTranscriptService {
    static func transcribe(url: URL, localeIdentifier: String) async throws -> String {
        let locale = Locale(identifier: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            throw SpeechTranscriptError.unavailable
        }
        guard recognizer.isAvailable else {
            throw SpeechTranscriptError.unavailable
        }

        let status = await requestAuthorization()
        guard status == .authorized else {
            throw SpeechTranscriptError.notAuthorized
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        } else {
            throw SpeechTranscriptError.unavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                if finished { return }
                if let error {
                    finished = true
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                finished = true
                let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    continuation.resume(throwing: SpeechTranscriptError.empty)
                } else {
                    continuation.resume(returning: text)
                }
            }
        }
    }

    private static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
