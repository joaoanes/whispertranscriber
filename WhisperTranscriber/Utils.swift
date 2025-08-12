import AVFoundation
import Foundation
import Dispatch
import AVFoundation
import WhisperKit
import AppKit
import SwiftUI
import Carbon

 func requestMicPermission(_ cb: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            cb(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                cb(granted)
            }
        default:
            cb(false)
        }
    }

    func tempURL() -> URL {
        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first!
        let name = "recording_\(Int(Date().timeIntervalSince1970)).wav"
        return caches.appendingPathComponent(name)
    }

func UTGetOSTypeFromString(_ str: String) -> OSType {
    precondition(str.utf8.count == 4, "Must be 4 chars")
    var result: OSType = 0
    for char in str.utf8 {
        result = (result << 8) | OSType(char)
    }
    return result
}



