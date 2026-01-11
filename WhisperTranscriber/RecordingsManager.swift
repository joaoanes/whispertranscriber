import Foundation

@MainActor
class RecordingsManager: ObservableObject {
    static let shared = RecordingsManager()

    @Published var recordings: [URL] = []
    @Published var transcriptions: [URL: String] = [:]

    private let fileManager = FileManager.default
    var recordingsDirectory: URL? {
        // Recordings are saved to Application Support/WhisperTranscriber/Recordings
        return getRecordingsDirectory()
    }

    private init() {
        migrateOldRecordings()
        scanForRecordings()
    }

    private func migrateOldRecordings() {
        guard let newDir = recordingsDirectory,
              let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            let wavFiles = files.filter { $0.pathExtension == "wav" && $0.lastPathComponent.starts(with: "recording_") }

            for file in wavFiles {
                let destination = newDir.appendingPathComponent(file.lastPathComponent)
                if !fileManager.fileExists(atPath: destination.path) {
                    do {
                        try fileManager.moveItem(at: file, to: destination)
                        Log.recording.info("Migrated recording: \(file.lastPathComponent))")
                    } catch {
                        Log.recording.error("Failed to migrate recording \(file.lastPathComponent)): \(error.localizedDescription))")
                    }
                }
            }
        } catch {
            Log.recording.error("Error checking old cache directory for migration: \(error.localizedDescription))")
        }
    }

    func scanForRecordings() {
        guard let recordingsDirectory = recordingsDirectory else {
            Log.recording.error("Error: Could not determine recordings directory.")
            self.recordings = []
            return
        }

        do {
            let allFiles = try fileManager.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            // Filter for .wav files and sort by creation date, newest first
            self.recordings = allFiles
                .filter { $0.pathExtension == "wav" }
                .sorted(by: {
                    let date1 = try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate
                    let date2 = try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate
                    return date1 ?? .distantPast > date2 ?? .distantPast
                })
        } catch {
            Log.recording.error("Error scanning for recordings: \(error.localizedDescription))")
            self.recordings = []
        }
    }

    func addTranscription(for url: URL, text: String) {
        transcriptions[url] = text
        // Check if the URL is already in the recordings list, if not, re-scan to add it.
        if !recordings.contains(url) {
            scanForRecordings()
        }
    }
}
