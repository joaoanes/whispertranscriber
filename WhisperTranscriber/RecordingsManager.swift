import Foundation

@MainActor
class RecordingsManager: ObservableObject {
    static let shared = RecordingsManager()

    @Published var recordings: [URL] = []
    @Published var transcriptions: [URL: String] = [:]

    private let fileManager = FileManager.default
    private var cacheDirectory: URL? {
        // Using a helper to get the app-specific cache directory
        return try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.joaoanes.WhisperTranscriber")
    }

    private init() {
        scanForRecordings()
    }

    func scanForRecordings() {
        guard let cacheDirectory = cacheDirectory else {
            print("Error: Could not determine cache directory.")
            self.recordings = []
            return
        }

        do {
            let allFiles = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            // Filter for .wav files and sort by creation date, newest first
            self.recordings = allFiles
                .filter { $0.pathExtension == "wav" }
                .sorted(by: {
                    let date1 = try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate
                    let date2 = try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate
                    return date1 ?? .distantPast > date2 ?? .distantPast
                })
        } catch {
            print("Error scanning for recordings: \(error)")
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
