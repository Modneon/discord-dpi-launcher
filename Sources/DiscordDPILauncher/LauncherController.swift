import AppKit
import CoreGraphics
import Foundation

final class LauncherController: ObservableObject {
    @Published private(set) var status: SpoofStatus = .checking
    @Published private(set) var detailMessage = "SpoofDPI bağlantısı kontrol ediliyor…"
    @Published private(set) var ownsSpoofProcess = false
    @Published private(set) var isLaunchingDiscord = false

    private var spoofProcess: Process?
    private var discordProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var terminationObserver: NSObjectProtocol?
    private var hasStartedInitialCheck = false

    private let proxyAddress = "http://127.0.0.1:8080"
    private let discordExecutable = "/Applications/Discord.app/Contents/MacOS/Discord"
    private let screenCapturePermissionRequestedKey = "screenCapturePermissionRequested"

    var canOpenDiscord: Bool { status == .running }

    init() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.terminateOwnedSpoofProcess()
        }
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }

    func startSpoofDPIIfNeeded() {
        guard !hasStartedInitialCheck else { return }
        hasStartedInitialCheck = true
        checkPort { [weak self] isOpen in
            guard let self else { return }
            if isOpen {
                self.status = .running
                self.detailMessage = "127.0.0.1:8080 üzerinde çalışan SpoofDPI bulundu."
            } else {
                self.startSpoofDPI()
            }
        }
    }

    func restartSpoofDPI() {
        if ownsSpoofProcess {
            terminateOwnedSpoofProcess()
            status = .starting
            detailMessage = "SpoofDPI yeniden başlatılıyor…"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.startSpoofDPI()
            }
        } else {
            checkPort { [weak self] isOpen in
                guard let self else { return }
                if isOpen {
                    self.status = .running
                    self.detailMessage = "8080 portundaki harici süreç çalışıyor; uygulama onu yeniden başlatmadı."
                } else {
                    self.startSpoofDPI()
                }
            }
        }
    }

    func stopSpoofDPI() {
        guard ownsSpoofProcess else {
            detailMessage = "SpoofDPI bu uygulama tarafından başlatılmadığı için durdurulmadı."
            return
        }
        terminateOwnedSpoofProcess()
        status = .stopped
        detailMessage = "SpoofDPI durduruldu."
    }

    func openDiscord() {
        guard status == .running, !isLaunchingDiscord else { return }
        guard FileManager.default.isExecutableFile(atPath: discordExecutable) else {
            status = .failed
            detailMessage = "Discord /Applications klasöründe bulunamadı."
            return
        }
        guard requestScreenCaptureAccessIfNeeded() else { return }

        isLaunchingDiscord = true
        detailMessage = "Discord güvenli biçimde yeniden başlatılıyor…"

        let existingApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.hnc.Discord")
        existingApps.forEach { $0.terminate() }

        waitForDiscordToExit(attemptsRemaining: 20) { [weak self] in
            self?.launchDiscordProcess()
        }
    }

    private func requestScreenCaptureAccessIfNeeded() -> Bool {
        guard !CGPreflightScreenCaptureAccess() else { return true }

        let hasRequestedAccess = UserDefaults.standard.bool(forKey: screenCapturePermissionRequestedKey)
        UserDefaults.standard.set(true, forKey: screenCapturePermissionRequestedKey)

        detailMessage = "Ekran paylaşımı için macOS ekran kaydı izni isteniyor…"
        if CGRequestScreenCaptureAccess() {
            return true
        }

        detailMessage = "Ekran paylaşımı için Sistem Ayarları'nda ekran kaydı izni verin, sonra yeniden deneyin."
        if hasRequestedAccess {
            openScreenCapturePrivacySettings()
        }
        return false
    }

    private func openScreenCapturePrivacySettings() {
        guard let settingsURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(settingsURL)
    }

    private func startSpoofDPI() {
        guard spoofProcess?.isRunning != true else { return }
        guard let executable = locateSpoofDPI() else {
            status = .failed
            detailMessage = "SpoofDPI bulunamadı. Homebrew ile kurulduğundan emin olun."
            return
        }

        status = .starting
        detailMessage = "DoH, IPv4, chunk=1 ve disorder ayarları uygulanıyor…"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [
            "--app-mode", "http",
            "--listen-addr", "127.0.0.1:8080",
            "--dns-mode", "https",
            "--dns-qtype", "ipv4",
            "--auto-configure-network",
            "--no-tui",
            "--https-split-mode", "chunk",
            "--https-chunk-size", "1",
            "--https-disorder"
        ]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        outputPipe = output
        errorPipe = error

        let handleData: (FileHandle) -> Void = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.consumeSpoofOutput(text)
            }
        }
        output.fileHandleForReading.readabilityHandler = handleData
        error.fileHandleForReading.readabilityHandler = handleData

        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self, self.spoofProcess === process else { return }
                self.ownsSpoofProcess = false
                self.spoofProcess = nil
                self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self.errorPipe?.fileHandleForReading.readabilityHandler = nil
                if self.status != .stopped {
                    self.status = process.terminationStatus == 0 ? .stopped : .failed
                    self.detailMessage = "SpoofDPI kapandı (kod: \(process.terminationStatus))."
                }
            }
        }

        do {
            try process.run()
            spoofProcess = process
            ownsSpoofProcess = true
            verifySpoofDPI(attemptsRemaining: 20)
        } catch {
            status = .failed
            detailMessage = "SpoofDPI başlatılamadı: \(error.localizedDescription)"
        }
    }

    private func consumeSpoofOutput(_ text: String) {
        if text.localizedCaseInsensitiveContains("server started") {
            status = .running
            detailMessage = "SpoofDPI 127.0.0.1:8080 üzerinde hazır."
        } else if text.localizedCaseInsensitiveContains("application failed") ||
                    text.localizedCaseInsensitiveContains("address already in use") {
            status = .failed
            detailMessage = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func verifySpoofDPI(attemptsRemaining: Int) {
        checkPort { [weak self] isOpen in
            guard let self else { return }
            if isOpen {
                self.status = .running
                self.detailMessage = "SpoofDPI 127.0.0.1:8080 üzerinde hazır."
            } else if attemptsRemaining > 0, self.spoofProcess?.isRunning == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.verifySpoofDPI(attemptsRemaining: attemptsRemaining - 1)
                }
            } else if self.status == .starting {
                self.status = .failed
                self.detailMessage = "SpoofDPI başladı ancak 8080 portu açılamadı."
            }
        }
    }

    private func checkPort(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let checker = Process()
            checker.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
            checker.arguments = ["-z", "-w", "1", "127.0.0.1", "8080"]
            checker.standardOutput = FileHandle.nullDevice
            checker.standardError = FileHandle.nullDevice
            do {
                try checker.run()
                checker.waitUntilExit()
                let isOpen = checker.terminationStatus == 0
                DispatchQueue.main.async { completion(isOpen) }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    private func waitForDiscordToExit(attemptsRemaining: Int, completion: @escaping () -> Void) {
        let isStillRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.hnc.Discord").isEmpty
        if !isStillRunning || attemptsRemaining <= 0 {
            completion()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.waitForDiscordToExit(attemptsRemaining: attemptsRemaining - 1, completion: completion)
        }
    }

    private func launchDiscordProcess() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: discordExecutable)
        process.arguments = [
            "--proxy-server=\(proxyAddress)",
            "--disable-quic"
        ]

        var environment = ProcessInfo.processInfo.environment
        environment["HTTPS_PROXY"] = proxyAddress
        environment["HTTP_PROXY"] = proxyAddress
        environment["ALL_PROXY"] = proxyAddress
        environment["NO_PROXY"] = "localhost,127.0.0.1"
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.discordProcess = nil
            }
        }

        do {
            try process.run()
            discordProcess = process
            detailMessage = "Discord proxy üzerinden başlatıldı."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self else { return }
                self.isLaunchingDiscord = false
                NSRunningApplication.runningApplications(withBundleIdentifier: "com.hnc.Discord")
                    .first?
                    .activate(options: [.activateAllWindows])
            }
        } catch {
            isLaunchingDiscord = false
            detailMessage = "Discord başlatılamadı: \(error.localizedDescription)"
        }
    }

    private func terminateOwnedSpoofProcess() {
        guard let process = spoofProcess, process.isRunning else { return }
        process.terminate()
        ownsSpoofProcess = false
        spoofProcess = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
    }

    private func locateSpoofDPI() -> String? {
        let candidates = [
            "/opt/homebrew/bin/spoofdpi",
            "/usr/local/bin/spoofdpi"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
