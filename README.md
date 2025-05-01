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

2. WhisperKit is configured as a local dependency. Ensure the `whisperkit` directory is present at the same level as the `WhisperTranscriber` directory.

3. Open the project in Xcode:
   ```bash
   open WhisperTranscriber.xcodeproj
   ```

3. Build and run the project in Xcode.

## Building WhisperKit

WhisperKit is configured as a local dependency. To build WhisperKit, follow these steps:

1. Ensure you have the necessary tools installed, such as Xcode and Swift.
2. Clone the WhisperKit repository:
   ```bash
   git clone https://github.com/argmaxinc/WhisperKit.git
   ```
3. Navigate to the WhisperKit directory:
   ```bash
   cd WhisperKit
   ```
4. Build the WhisperKit package:
   ```bash
   swift build
   ```
5. Ensure the `whisperkit` directory is at the same level as the `WhisperTranscriber` directory for the local dependency to work correctly.

## Usage

- Launch the application.
- Use the configured hotkey (default: ⌥⌘S) to start and stop recording.
- The application will transcribe the audio and copy the text to the clipboard.

## License

This project is licensed under... a license. See the LICENSE file for details.
