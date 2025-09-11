import Foundation
import AppKit

class AudioFade {
    static let shared = AudioFade()
    private var originalVolume: Int?
    private var fadeTimer: Timer?

    private func runAppleScript(command: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getCurrentVolume() -> Int? {
        if let volumeStr = runAppleScript(command: "output volume of (get volume settings)"), let volume = Int(volumeStr) {
            return volume
        }
        return nil
    }

    func setVolume(_ volume: Int) {
        let clampedVolume = max(0, min(100, volume))
        _ = runAppleScript(command: "set volume output volume \(clampedVolume)")
    }

    func fadeOut(duration: TimeInterval) {
        guard let currentVolume = getCurrentVolume() else { return }
        originalVolume = currentVolume

        let steps = 20
        let stepInterval = duration / Double(steps)
        let volumeDecrement = Double(currentVolume) / Double(steps)
        var currentStep = 0

        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentStep += 1
            if currentStep >= steps {
                self.setVolume(0)
                timer.invalidate()
            } else {
                let newVolume = Int(Double(currentVolume) - (Double(currentStep) * volumeDecrement))
                self.setVolume(newVolume)
            }
        }
    }

    func fadeIn(duration: TimeInterval) {
        guard let targetVolume = originalVolume else { return }

        let steps = 20
        let stepInterval = duration / Double(steps)
        let volumeIncrement = Double(targetVolume) / Double(steps)
        var currentStep = 0

        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentStep += 1
            if currentStep >= steps {
                self.setVolume(targetVolume)
                timer.invalidate()
            } else {
                let newVolume = Int(Double(currentStep) * volumeIncrement)
                self.setVolume(newVolume)
            }
        }
    }
}
