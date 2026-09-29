# WhisperTranscriber

WhisperTranscriber is a macOS application that allows users to record audio and transcribe it into text locally. The transcribed text is automatically copied to the clipboard for easy access.

<img width="338" alt="Screenshot 2025-05-01 at 22 40 40" src="https://github.com/user-attachments/assets/0870c8ac-a7e2-448f-b44b-77a055abe092" />

## Features

- Uses Parakeet TDT v3 on the Neural Engine via [FluidAudio](https://github.com/FluidInference/FluidAudio) for transcription.
- Record audio using the system microphone.
- Transcribe audio to text locally, in 25 European languages.
- Live transcription in the menu bar popover while you speak, with the record's transcript growing as each phrase lands.
- Silero VAD trims silence before the final pass and skips recordings with no speech in them.
- Optional speaker detection, labelling each turn in the final transcript for conversations recorded off the microphone.
- Deterministic text cleanup: filler removal and whitespace/punctuation tidying, with no LLM involved.
- Copy the finished transcript to the clipboard.
- Configure a global hotkey to toggle recording.

## Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd WhisperTranscriber
   ```

2. Dependencies are fetched automatically from Swift Package Manager, including the remote [FluidAudio](https://github.com/FluidInference/FluidAudio) package maintained by Fluid Inference.

3. Open the project in Xcode 26.0.1 or newer:
   ```bash
   open WhisperTranscriber.xcodeproj
   ```

3. Build and run the project in Xcode.

### Model assets

The Xcode project copies the contents of `~/Documents/hf` into the application bundle. The `WhisperTranscriber` target expects
the Core ML bundles to be staged there before archiving; the `WhisperTranscriberLite` target ships without them and downloads
them into `~/Library/Application Support/WhisperTranscriber` on first launch instead.

The expected layout is:

```
~/Documents/hf/models/FluidInference
├── parakeet-tdt-0.6b-v3
│   ├── Preprocessor.mlmodelc
│   ├── Encoder.mlmodelc
│   ├── Decoder.mlmodelc
│   ├── JointDecisionv3.mlmodelc
│   ├── parakeet_vocab.json
│   └── parakeet_v3_vocab.json
└── silero-vad
    └── silero-vad-unified-256ms-v6.2.1.mlmodelc
```

The folder names matter and are **not** the Hugging Face repo names: FluidAudio resolves models by its own local cache name,
which is the repo name with `-coreml` stripped. The simplest way to stage them is to run the Lite target once and copy the two
populated folders out of `~/Library/Application Support/WhisperTranscriber/Models`, which are already named correctly.

To fetch them by hand instead, clone and drop the `-coreml` suffix:

```bash
git lfs install
git clone https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml ~/Documents/hf/models/FluidInference/parakeet-tdt-0.6b-v3
git clone https://huggingface.co/FluidInference/silero-vad-coreml ~/Documents/hf/models/FluidInference/silero-vad
```

CI builds create an empty directory at `/Users/runner/work/Documents/hf` so the resource copy phase succeeds without bundling
large model artifacts.

## Usage

- Launch the application.
- Use the configured hotkey (default: ⌥⌘S) to start and stop recording.
- The application will transcribe the audio and copy the text to the clipboard.

## CI Code Signing Settings

The GitHub Actions workflow builds the macOS app without access to signing certificates. To keep those CI builds green, the workflow sets two Xcode build settings to `NO`:

- `CODE_SIGNING_ALLOWED` tells Xcode whether it should attempt to sign any produced binaries. Disabling it skips the signing phase entirely.
- `CODE_SIGNING_REQUIRED` controls whether a build should fail if signing cannot happen. Disabling it lets the build finish even when no signing identities are present.

When you build locally with a valid signing identity you can leave both settings at their defaults (`YES`) so Xcode signs the products as usual.

## License

This project is licensed under... a license. See the LICENSE file for details.
