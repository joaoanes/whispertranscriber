import SwiftUI

struct AboutView: View {
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "WhisperTranscriber"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }

    var body: some View {
        VStack(spacing: 10) {
            if let nsImage = NSImage(named: "AppIcon") {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 64, height: 64)
            }
            Text(appName)
                .font(.title)
            Text("Version \(appVersion) (Build \(buildNumber))")
                .foregroundColor(.secondary)

            Link("Powered by WhisperKit", destination: URL(string: "https://github.com/argmaxinc/whisperkit")!)
                .foregroundColor(.blue)

            Button("Close") {
                // This assumes the window is key, which it should be when shown.
                NSApplication.shared.keyWindow?.close()
            }
            .padding(.top)
        }
        .padding(20)
        .frame(minWidth: 300)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
