import Foundation

enum RecorderActivity: Equatable {
    case idle
    case downloading
    case preparing
    case recording
    case recordingLive
    case transcribing

    var isRecording: Bool {
        self == .recording || self == .recordingLive
    }

    var canToggleRecording: Bool {
        self == .idle || isRecording
    }

    var title: String {
        switch self {
        case .idle: "Ready"
        case .downloading: "Downloading model…"
        case .preparing: "Loading model…"
        case .recording: "Recording"
        case .recordingLive: "Recording · Live"
        case .transcribing: "Transcribing…"
        }
    }

    var symbol: String {
        switch self {
        case .idle: "mic"
        case .downloading: "arrow.down.circle"
        case .preparing: "hourglass"
        case .recording: "record.circle.fill"
        case .recordingLive: "waveform.circle.fill"
        case .transcribing: "text.bubble"
        }
    }
}
