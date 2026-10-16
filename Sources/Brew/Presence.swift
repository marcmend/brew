import AppKit
import CoreGraphics

/// Garde le système en état « utilisateur présent » tant qu'un mode est actif.
///
/// macOS ne remet son compteur d'inactivité à zéro que sur un vrai événement d'entrée
/// (`IOPMAssertionDeclareUserActivity` n'y touche pas). Dès que le compteur dépasse
/// `threshold`, on poste donc un aller-retour de souris d'un pixel au niveau de la session,
/// ce qui ne demande aucune autorisation. Rien n'est envoyé tant que l'utilisateur est actif.
///
/// Ces événements repoussent aussi l'extinction de l'écran. En Cold Brew, on éteint donc
/// l'écran soi-même après le délai `displaysleep` du système, compté sur l'inactivité réelle.
/// Écran éteint, on continue d'envoyer des événements ; si l'un d'eux rallume l'écran, on le
/// rééteint et on arrête d'en envoyer tant qu'il reste éteint.
@MainActor
final class PresenceKeeper {
    private let threshold: TimeInterval = 50
    private var timer: Timer?
    private var mode: BrewMode?
    private var lastNudge = Date.distantPast
    private var lastRealInput = Date.now
    private var displaySleepDelay: TimeInterval?
    private var nudgeWhileAsleep = true

    func start(_ mode: BrewMode) {
        self.mode = mode
        lastNudge = .distantPast
        lastRealInput = .now.addingTimeInterval(-Self.idleSeconds())
        displaySleepDelay = Self.systemDisplaySleepDelay()
        nudgeWhileAsleep = true
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        mode = nil
    }

    private func tick() {
        let now = Date.now
        let idle = Self.idleSeconds()
        // Le compteur est reparti de zéro après notre dernier événement : c'est une vraie saisie.
        if idle < now.timeIntervalSince(lastNudge) - 1 {
            lastRealInput = now.addingTimeInterval(-idle)
        }
        let asleep = Self.displayIsAsleep
        if !asleep { nudgeWhileAsleep = true }

        if mode == .coldBrew, !asleep, let delay = displaySleepDelay,
           now.timeIntervalSince(lastRealInput) >= delay {
            Self.sleepDisplay()
            return
        }
        guard idle >= threshold, !asleep || nudgeWhileAsleep else { return }
        nudge()
        lastNudge = now
        if asleep, mode == .coldBrew {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, !Self.displayIsAsleep else { return }
                self.nudgeWhileAsleep = false
                Self.sleepDisplay()
            }
        }
    }

    private func nudge() {
        guard let location = CGEvent(source: nil)?.location else { return }
        for point in [CGPoint(x: location.x + 1, y: location.y), location] {
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
                .post(tap: .cgSessionEventTap)
        }
    }

    private static var displayIsAsleep: Bool { CGDisplayIsAsleep(CGMainDisplayID()) != 0 }

    private static func idleSeconds() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    private static func sleepDisplay() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }

    /// Délai d'extinction de l'écran réglé dans macOS (`pmset -g`), `nil` si jamais.
    private static func systemDisplaySleepDelay() -> TimeInterval? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return 600 }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        for line in output.split(separator: "\n") {
            let fields = line.split(whereSeparator: \.isWhitespace)
            if fields.first == "displaysleep", fields.count > 1, let minutes = Double(fields[1]) {
                return minutes > 0 ? minutes * 60 : nil
            }
        }
        return 600
    }
}
