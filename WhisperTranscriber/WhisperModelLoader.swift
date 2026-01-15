import Foundation
import WhisperKit

struct WhisperModelLoader {
    static func ensureModelsAreThere(selectedModel: String, progressCallback: @escaping (Double) -> Void) async throws -> String {
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("hf/models/argmaxinc/whisperkit-coreml/\(selectedModel)") {
             if FileManager.default.fileExists(atPath: bundlePath.path) {
                 Log.general.info("✅ Found models in app bundle at \(bundlePath.path)")
                 return bundlePath.path
             }
        }
        return try await setupLiteModels(selectedModel: selectedModel, progressCallback: progressCallback)
    }

    private static func setupLiteModels(selectedModel: String, progressCallback: @escaping (Double) -> Void) async throws -> String {
        let fm = FileManager.default
        let modelsURL = try getModelsDirectoryInternal()

        let modelPathURL = modelsURL.appendingPathComponent("hf/models/argmaxinc/whisperkit-coreml/\(selectedModel)")
        let tokenizerPathURL = modelsURL.appendingPathComponent("hf/")

        // Check for models in old cache directory and migrate if possible
        migrateOldModels(to: modelPathURL, fileManager: fm, selectedModel: selectedModel)
        
        if fm.fileExists(atPath: modelPathURL.path) {
            Log.general.info("✅ Models already exist at \(modelPathURL.path)")
            return modelPathURL.path
        }
        
        Log.general.info("⬇️ Downloading models...")
        
        try await downloadAndInstallModels(to: modelPathURL, tokenizerPath: tokenizerPathURL, fileManager: fm, selectedModel: selectedModel, progressCallback: progressCallback)
        
        return modelPathURL.path
    }

    private static func getModelsDirectoryInternal() throws -> URL {
        guard let modelsDir = getModelsDirectory() else {
            throw NSError(domain: "AppError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not get models directory."])
        }
        return modelsDir
    }

    private static func migrateOldModels(to newModelURL: URL, fileManager fm: FileManager, selectedModel: String) {
        guard let cacheURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let oldAppCacheURL = cacheURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.joaoanes.WhisperTranscriberLite")

        let oldModelPathURL = oldAppCacheURL.appendingPathComponent("hf/models/argmaxinc/whisperkit-coreml/\(selectedModel)")

        if fm.fileExists(atPath: oldModelPathURL.path) && !fm.fileExists(atPath: newModelURL.path) {
            Log.general.info("📦 Migrating models from Cache to Application Support...")
            do {
                try fm.createDirectory(at: newModelURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                try fm.moveItem(at: oldModelPathURL, to: newModelURL)
                Log.general.info("✅ Migration successful.")
            } catch {
                Log.general.error("❌ Migration failed: \(error.localizedDescription)")
            }
        }
    }

    private static func getTokenizerVariant(for model: String) -> ModelVariant {
        if model.contains("large-v3") {
            return .largev3
        } else if model.contains("large-v2") {
            return .largev2
        } else if model.contains("medium") {
            return .medium
        } else if model.contains("small") {
            return .small
        } else if model.contains("base") {
            return .base
        } else if model.contains("tiny") {
            return .tiny
        } else if model.contains("distil-large-v3") {
            return .largev3
        } else {
            return .largev3
        }
    }

    private static func downloadAndInstallModels(to modelURL: URL, tokenizerPath: URL, fileManager fm: FileManager, selectedModel: String, progressCallback: @escaping (Double) -> Void) async throws {
        // Download model
        let downloadedModelURL = try await WhisperKit.download(variant: selectedModel) { progress in
            progressCallback(progress.fractionCompleted)
        }
        
        let tokenizerVariant = getTokenizerVariant(for: selectedModel)

        // Download tokenizer
        _ = try await ModelUtilities.loadTokenizer(for: tokenizerVariant)
        
        // Move model to destination
        if fm.fileExists(atPath: modelURL.path) {
            try fm.removeItem(at: modelURL)
        }
        try fm.createDirectory(at: modelURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: downloadedModelURL, to: modelURL)
        Log.general.info("✅ Models downloaded and installed.")
    }
}
