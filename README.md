# WhisperTranscriber

WhisperTranscriber is a macOS application that allows users to record audio and transcribe it into text using WhisperKit. The transcribed text is automatically copied to the clipboard for easy access.

<img width="338" alt="Screenshot 2025-05-01 at 22 40 40" src="https://github.com/user-attachments/assets/0870c8ac-a7e2-448f-b44b-77a055abe092" />

## Features

- Utilizes [WhisperKit](https://github.com/argmaxinc/WhisperKit) for transcription.
- Record audio using the system microphone.
- Transcribe audio to text locally.
- Copy transcribed text to the clipboard.
- Configure a global hotkey to toggle recording.

## Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd WhisperTranscriber
   ```

2. Dependencies are fetched automatically from Swift Package Manager, including the remote [WhisperKit](https://github.com/argmaxinc/WhisperKit) package maintained by Argmax.

3. Open the project in Xcode:
   ```bash
   open WhisperTranscriber.xcodeproj
   ```

3. Build and run the project in Xcode.

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
