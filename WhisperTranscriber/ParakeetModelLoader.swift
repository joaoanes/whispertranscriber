import CoreML
import FluidAudio
import Foundation

struct ParakeetModelLoader {
    static let asrFolderName = "parakeet-tdt-0.6b-v3"
    static let vadFolderName = "silero-vad"
    static let diarizerFolderName = "speaker-diarization"
    static let vadModelFileName = "silero-vad-unified-256ms-v6.2.1.mlmodelc"
    private static let vendorPath = "hf/models/FluidInference"

    static func loadASR(progressCallback: @escaping (Double) -> Void) async throws -> AsrModels {
        if let bundled = bundledDirectory(for: asrFolderName), AsrModels.modelsExist(at: bundled) {
            Log.general.info("✅ Found Parakeet models in app bundle at \(bundled.path)")
            return try await AsrModels.load(from: bundled, version: .v3)
        }

        let cached = try cacheDirectory(for: asrFolderName)
        if AsrModels.modelsExist(at: cached) {
            Log.general.info("✅ Parakeet models already exist at \(cached.path)")
            return try await AsrModels.load(from: cached, version: .v3)
        }

        Log.general.info("⬇️ Downloading Parakeet models to \(cached.path)...")
        let models = try await AsrModels.downloadAndLoad(to: cached, version: .v3) { progress in
            progressCallback(progress.fractionCompleted)
        }
        Log.general.info("✅ Parakeet models downloaded and installed.")
        return models
    }

    static func loadVAD() async throws -> VadManager {
        if let bundled = bundledDirectory(for: vadFolderName)?
            .appendingPathComponent(vadModelFileName),
            FileManager.default.fileExists(atPath: bundled.path) {
            Log.general.info("✅ Found Silero VAD in app bundle at \(bundled.path)")
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuOnly
            let model = try MLModel(contentsOf: bundled, configuration: configuration)
            return VadManager(config: .default, vadModel: model)
        }

        let base = try appSupportDirectoryInternal()
        Log.general.info("⬇️ Loading Silero VAD from \(base.path)...")
        return try await VadManager(config: .default, modelDirectory: base)
    }

    static func loadDiarizer(progressCallback: @escaping @Sendable (Double) -> Void) async throws -> DiarizerModels {
        if let bundled = bundledDirectory(for: diarizerFolderName),
           FileManager.default.fileExists(atPath: bundled.path) {
            Log.general.info("✅ Found speaker models in app bundle at \(bundled.path)")
            return try await DiarizerModels.load(from: bundled)
        }

        let cached = try cacheDirectory(for: diarizerFolderName)
        Log.general.info("⬇️ Loading speaker models from \(cached.path)...")
        return try await DiarizerModels.downloadIfNeeded(to: cached) { progress in
            progressCallback(progress.fractionCompleted)
        }
    }

    private static func bundledDirectory(for folderName: String) -> URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent(vendorPath)
            .appendingPathComponent(folderName)
    }

    private static func cacheDirectory(for folderName: String) throws -> URL {
        guard let modelsDir = getModelsDirectory() else {
            throw NSError(
                domain: "AppError",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Could not get models directory."]
            )
        }
        return modelsDir.appendingPathComponent(folderName)
    }

    private static func appSupportDirectoryInternal() throws -> URL {
        guard let appSupport = getAppSupportDirectory() else {
            throw NSError(
                domain: "AppError",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Could not get application support directory."]
            )
        }
        return appSupport
    }
}
