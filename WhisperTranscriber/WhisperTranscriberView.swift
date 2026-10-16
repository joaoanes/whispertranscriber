import SwiftUI

extension Color {
    static let darkOrange = Color(red: 0.72, green: 0.28, blue: 0.0)
}

extension RecorderActivity {
    var tint: Color {
        switch self {
        case .recording: .orange
        case .recordingLive: .darkOrange
        default: .primary
        }
    }
}

struct Tile<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
    }
}

struct WhisperTranscriberView: View {
    @StateObject private var vm = RecorderViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Group {
            if vm.isPrewarming {
                PrewarmingView(isDownloading: vm.isDownloading, downloadProgress: vm.downloadProgress)
            } else {
                PopoverView(
                    settings: settings,
                    activity: vm.activity,
                    liveSegments: vm.liveSegments,
                    toggleRecording: vm.toggleRecording
                )
            }
        }
        .alert(isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(vm.errorMessage ?? "An unexpected error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct PrewarmingView: View {
    var isDownloading: Bool
    var downloadProgress: Double

    var body: some View {
        VStack(spacing: 8) {
            Tile {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        isDownloading ? "Downloading Parakeet…" : "Loading Parakeet…",
                        systemImage: isDownloading ? "arrow.down.circle" : "hourglass"
                    )
                    .font(.headline)

                    if isDownloading {
                        ProgressView(value: downloadProgress, total: 1.0)
                        Text("This happens once per install. The full version of WhisperTranscriber ships with the model.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                        Text("This takes about a second on the Neural Engine.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Spacer()
                QuitButton()
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 320)
    }
}

struct QuitButton: View {
    var body: some View {
        Button("Quit WhisperTranscriber", systemImage: "power") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
            .help("Quit WhisperTranscriber")
    }
}

struct MicrophonePicker: View {
    @Binding var selection: String
    var devices: [AudioInputDevice]

    private var selectionIsDisconnected: Bool {
        selection != SettingsManager.systemDefaultInput && !devices.contains { $0.uid == selection }
    }

    var body: some View {
        Picker("Microphone", selection: $selection) {
            Text("System Default").tag(SettingsManager.systemDefaultInput)
            Divider()
            ForEach(devices) { device in
                Text(device.name).tag(device.uid)
            }
            if selectionIsDisconnected {
                Text("Disconnected (using default)").tag(selection)
            }
        }
        .help("Pick a built-in mic to keep Bluetooth headphones in high-quality playback mode.")
    }
}

struct PopoverView: View {
    @ObservedObject var settings: SettingsManager
    @StateObject private var microphones = AudioInputDeviceCatalog()
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    let activity: RecorderActivity
    let liveSegments: [LiveSegment]
    let toggleRecording: () -> Void

    private var showsTranscript: Bool {
        activity == .recordingLive || !liveSegments.isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            header

            if showsTranscript {
                Tile { LiveTranscriptView(segments: liveSegments) }
            }

            Tile {
                VStack(spacing: 8) {
                    Toggle("Live Transcription", isOn: $settings.liveTranscriptionEnabled)
                        .help("Locked in when a recording starts. Off records silently and transcribes once at the end.")
                    Toggle("Detect Speakers", isOn: $settings.speakerDetectionEnabled)
                        .help("Labels each turn in the final transcript. For conversations, not dictation. Downloads ~130MB the first time.")
                    LabeledContent("Microphone") {
                        MicrophonePicker(selection: $settings.inputDeviceUID, devices: microphones.devices)
                            .labelsHidden()
                            .fixedSize()
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(activity.isRecording)
            }

            footer
        }
        .padding(12)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack {
            Label(activity.title, systemImage: activity.symbol)
                .font(.headline)
                .foregroundStyle(activity.tint)
                .symbolEffect(.pulse, isActive: activity.isRecording)
            Spacer()
            Button(activity.isRecording ? "Stop" : "Record", action: toggleRecording)
                .buttonStyle(.borderedProminent)
                .tint(activity.isRecording ? activity.tint : .accentColor)
                .controlSize(.large)
                .disabled(!activity.canToggleRecording)
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(settings.hotkey)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .help("Recording shortcut")
            Spacer()
            Button("Records", systemImage: "list.bullet.rectangle") {
                openWindow(id: RecordsView.windowID)
                NSApp.activate()
            }
            .help("Records")
            Button("Settings", systemImage: "gearshape") {
                openSettings()
                NSApp.activate()
            }
            .help("Settings")
            QuitButton()
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .padding(.horizontal, 4)
    }
}

#Preview("Prewarming") {
    PrewarmingView(isDownloading: true, downloadProgress: 0.4)
}

#Preview("Idle") {
    PopoverView(settings: .shared, activity: .idle, liveSegments: [], toggleRecording: {})
}

#Preview("Live") {
    PopoverView(
        settings: .shared,
        activity: .recordingLive,
        liveSegments: [
            LiveSegment(startsAt: 0, text: "This is what a live transcript looks like."),
            LiveSegment(startsAt: 7, text: "Older sentences shrink. The newest one stays large.")
        ],
        toggleRecording: {}
    )
}
