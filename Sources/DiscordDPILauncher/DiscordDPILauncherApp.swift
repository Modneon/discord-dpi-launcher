import AppKit
import SwiftUI

@main
struct DiscordDPILauncherApp: App {
    @StateObject private var controller = LauncherController()

    var body: some Scene {
        WindowGroup {
            ContentView(controller: controller)
                .frame(minWidth: 440, idealWidth: 440, maxWidth: 440,
                       minHeight: 380, idealHeight: 380, maxHeight: 380)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct ContentView: View {
    @ObservedObject var controller: LauncherController

    var body: some View {
        VStack(spacing: 20) {
            appLogo

            VStack(spacing: 6) {
                Text("Discord DPI Launcher")
                    .font(.title2.bold())
                Text("SpoofDPI'yi hazırlar ve Discord'u doğru proxy ayarlarıyla açar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            statusPill

            Button(action: controller.openDiscord) {
                Label(controller.isLaunchingDiscord ? "Discord açılıyor…" : "Discord'u Aç",
                      systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.indigo)
            .disabled(!controller.canOpenDiscord || controller.isLaunchingDiscord)

            HStack {
                Button("Yeniden Başlat", action: controller.restartSpoofDPI)
                    .disabled(controller.status == .starting)
                Button("Durdur", action: controller.stopSpoofDPI)
                    .disabled(!controller.ownsSpoofProcess)
            }

            Text(controller.detailMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(minHeight: 32)
        }
        .padding(28)
        .background(
            LinearGradient(
                colors: [Color.indigo.opacity(0.10), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .task {
            controller.startSpoofDPIIfNeeded()
        }
    }

    @ViewBuilder
    private var appLogo: some View {
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
           let icon = NSImage(contentsOfFile: iconPath) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .indigo.opacity(0.24), radius: 12, y: 6)
        } else {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 54, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.indigo)
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(controller.status.color)
                .frame(width: 9, height: 9)
            Text(controller.status.title)
                .font(.callout.weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(controller.status.color.opacity(0.12), in: Capsule())
    }
}

enum SpoofStatus: Equatable {
    case checking
    case starting
    case running
    case stopped
    case failed

    var title: String {
        switch self {
        case .checking: return "Kontrol ediliyor"
        case .starting: return "SpoofDPI başlatılıyor"
        case .running: return "SpoofDPI çalışıyor"
        case .stopped: return "SpoofDPI durdu"
        case .failed: return "Başlatılamadı"
        }
    }

    var color: Color {
        switch self {
        case .checking, .starting: return .orange
        case .running: return .green
        case .stopped: return .secondary
        case .failed: return .red
        }
    }
}
