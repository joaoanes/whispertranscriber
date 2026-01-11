import AVFoundation
import Foundation
import Dispatch
import WhisperKit
import AppKit
import SwiftUI
import Carbon

var getAudioAuthStatus: () -> AVAuthorizationStatus = {
    AVCaptureDevice.authorizationStatus(for: .audio)
}

var requestAudioAccess: (@escaping (Bool) -> Void) -> Void = { cb in
    AVCaptureDevice.requestAccess(for: .audio, completionHandler: cb)
}

func requestMicPermission(_ cb: @escaping (Bool) -> Void) {
    switch getAudioAuthStatus() {
    case .authorized:
        cb(true)
    case .notDetermined:
        requestAudioAccess(cb)
    default:
        cb(false)
    }
}

func getRecordingsDirectory() -> URL? {
    guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        return nil
    }
    let recordingsDirectory = applicationSupport
        .appendingPathComponent("WhisperTranscriber")
        .appendingPathComponent("Recordings")

    if !FileManager.default.fileExists(atPath: recordingsDirectory.path) {
        do {
            try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Log.general.error("Error creating recordings directory: \(error.localizedDescription))")
            return nil
        }
    }
    return recordingsDirectory
}

func getModelsDirectory() -> URL? {
    guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        return nil
    }
    let modelsDirectory = applicationSupport
        .appendingPathComponent("WhisperTranscriber")
        .appendingPathComponent("Models")

    if !FileManager.default.fileExists(atPath: modelsDirectory.path) {
        do {
            try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Log.general.error("Error creating models directory: \(error.localizedDescription))")
            return nil
        }
    }
    return modelsDirectory
}

func tempURL() -> URL {
    guard let recordingsDir = getRecordingsDirectory() else {
        // Fallback to temp directory if Application Support is unavailable
        return FileManager.default.temporaryDirectory.appendingPathComponent("recording_\(Int(Date().timeIntervalSince1970)).wav")
    }
    let name = "recording_\(Int(Date().timeIntervalSince1970)).wav"
    return recordingsDir.appendingPathComponent(name)
}

func UTGetOSTypeFromString(_ str: String) -> OSType {
    precondition(str.utf8.count == 4, "Must be 4 chars")
    var result: OSType = 0
    for char in str.utf8 {
        result = (result << 8) | OSType(char)
    }
    return result
}
