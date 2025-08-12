import Foundation

@MainActor
class RecordingsManager: ObservableObject {
    static let shared = RecordingsManager()

    @Published var recordings: [URL] = []
    @Published var transcriptions: [URL: String] = [:]

    private let fileManager = FileManager.default
    private var cacheDirectory: URL {
        // Using the same logic as tempURL() to find the cache directory
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    private init() {
        scanForRecordings()
    }

    func scanForRecordings() {
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
        // Check if the URL is already in the recordings list, if not, add it and resort
        if !recordings.contains(url) {
            recordings.insert(url, at: 0) // Assume it's the newest
            // A full re-scan and sort might be better for consistency
            scanForRecordings()
        }
    }
}
