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
    case indefinite = 0
    case quarter = 900
    case oneHour = 3600
    case twoHours = 7200
    case fourHours = 14400

    var id: Int { rawValue }

    var label: String {
        switch self {
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

    private var assertionID: IOPMAssertionID = 0
    private var expirationTimer: Timer?

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
        guard duration != .indefinite else {
            endDate = nil
            return
        }
        let end = Date.now.addingTimeInterval(TimeInterval(duration.rawValue))
        endDate = end
        let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        RunLoop.main.add(timer, forMode: .common)
        expirationTimer = timer
    }

    private func releaseAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
}
