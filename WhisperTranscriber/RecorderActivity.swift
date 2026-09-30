import Foundation

enum RecorderActivity: Equatable {
    case idle
    case downloading
    case preparing
    case recording
    case recordingLive
    case transcribing
}
