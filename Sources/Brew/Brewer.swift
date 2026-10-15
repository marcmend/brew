import Foundation
import IOKit.pwr_mgt
import ServiceManagement

enum BrewMode: String, CaseIterable, Identifiable {
    /// Écran allumé, aucune veille — le même verrou que pose un lecteur vidéo en plein écran.
    case espresso
    /// L'écran peut s'éteindre, mais le Mac ne s'endort pas : les process continuent.
    case coldBrew

    var id: String { rawValue }

    var title: String {
        switch self {
        case .espresso: "Espresso"
        case .coldBrew: "Cold Brew"
        }
    }

    var subtitle: String {
        switch self {
        case .espresso: "Écran allumé, aucune veille"
        case .coldBrew: "Écran éteint, le Mac travaille"
        }
    }

    var symbol: String {
        switch self {
        case .espresso: "cup.and.heat.waves.fill"
        case .coldBrew: "snowflake"
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .espresso: "cup.and.heat.waves.fill"
        case .coldBrew: "cup.and.saucer.fill"
        }
    }

    /// Types d'assertion IOKit (les macros CFSTR ne sont pas importées en Swift).
    var assertionType: String {
        switch self {
        case .espresso: "PreventUserIdleDisplaySleep"
        case .coldBrew: "PreventUserIdleSystemSleep"
        }
    }
}

enum BrewDuration: Int, CaseIterable, Identifiable {
    /// Reste actif tant qu'une session Claude Code travaille.
    case whileClaude = -1
    case indefinite = 0
    case quarter = 900
    case oneHour = 3600
    case twoHours = 7200
    case fourHours = 14400

    var id: Int { rawValue }

    /// Durées proposées sous forme de pastilles.
    static let timed: [BrewDuration] = [.indefinite, .quarter, .oneHour, .twoHours, .fourHours]

    var label: String {
        switch self {
        case .whileClaude: "Claude"
        case .indefinite: "∞"
        case .quarter: "15 min"
        case .oneHour: "1 h"
        case .twoHours: "2 h"
        case .fourHours: "4 h"
        }
    }
}

@MainActor
final class Brewer: ObservableObject {
    @Published private(set) var mode: BrewMode?
    @Published private(set) var startDate: Date?
    @Published private(set) var endDate: Date?
    @Published var duration: BrewDuration {
        didSet {
            UserDefaults.standard.set(duration.rawValue, forKey: "duration")
            if mode != nil { scheduleExpiration() }
        }
    }
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    /// Sessions Claude en train de travailler (mode `.whileClaude`).
    @Published private(set) var claudeSessions = 0
    /// Depuis quand plus aucune session Claude ne travaille.
    @Published private(set) var claudeIdleSince: Date?

    /// Délai sans activité Claude avant de relâcher la veille.
    let claudeGracePeriod: TimeInterval = 120

    private var assertionID: IOPMAssertionID = 0
    private var expirationTimer: Timer?
    private var claudeTimer: Timer?
    private let claudeWatcher = ClaudeWatcher()

    init() {
        duration = BrewDuration(rawValue: UserDefaults.standard.integer(forKey: "duration")) ?? .indefinite
    }

    func toggle(_ newMode: BrewMode) {
        if mode == newMode { stop() } else { start(newMode) }
    }

    func start(_ newMode: BrewMode) {
        releaseAssertion()
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            newMode.assertionType as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Brew — \(newMode.title)" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else { return }
        assertionID = id
        mode = newMode
        startDate = .now
        scheduleExpiration()
    }

    func stop() {
        releaseAssertion()
        expirationTimer?.invalidate()
        expirationTimer = nil
        stopWatchingClaude()
        mode = nil
        startDate = nil
        endDate = nil
    }

    /// Éteint l'écran immédiatement (équivalent de `pmset displaysleepnow`).
    func sleepDisplayNow() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Brew: launch at login failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func scheduleExpiration() {
        expirationTimer?.invalidate()
        expirationTimer = nil
        stopWatchingClaude()
        switch duration {
        case .indefinite:
            endDate = nil
            return
        case .whileClaude:
            endDate = nil
            startWatchingClaude()
            return
        default:
            break
        }
        let end = Date.now.addingTimeInterval(TimeInterval(duration.rawValue))
        endDate = end
        let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        RunLoop.main.add(timer, forMode: .common)
        expirationTimer = timer
    }

    private func startWatchingClaude() {
        _ = claudeWatcher.activeSessions() // premier échantillon de référence
        claudeIdleSince = .now
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollClaude() }
        }
        RunLoop.main.add(timer, forMode: .common)
        claudeTimer = timer
    }

    private func stopWatchingClaude() {
        claudeTimer?.invalidate()
        claudeTimer = nil
        claudeSessions = 0
        claudeIdleSince = nil
    }

    private func pollClaude() {
        claudeSessions = claudeWatcher.activeSessions()
        if claudeSessions > 0 {
            claudeIdleSince = nil
        } else if let idleSince = claudeIdleSince {
            if Date.now.timeIntervalSince(idleSince) >= claudeGracePeriod { stop() }
        } else {
            claudeIdleSince = .now
        }
    }

    private func releaseAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
}
