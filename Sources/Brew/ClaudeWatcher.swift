import Darwin
import Foundation

/// Détecte si Claude Code est en train de travailler.
///
/// Un process `claude` au repos (en attente d'un prompt) tourne autour de 0,5 % de CPU
/// (pics à ~2 %) ; dès qu'il travaille — réflexion, streaming, attente d'un outil — il anime
/// son spinner et reste au-dessus de ~4 %. On échantillonne le temps CPU de chaque process
/// `claude` et on compte ceux qui dépassent `threshold` en moyenne sur une fenêtre glissante
/// (`window` échantillons), pour lisser les pics isolés.
final class ClaudeWatcher {
    private let threshold = 0.03
    private let window = 3
    private let nanosPerTick: Double
    private var history: [(date: Date, ticks: [pid_t: UInt64])] = []

    init() {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        nanosPerTick = Double(timebase.numer) / Double(timebase.denom)
    }

    /// Nombre de sessions Claude actives sur la fenêtre glissante.
    func activeSessions() -> Int {
        let now = Date.now
        var sample: [pid_t: UInt64] = [:]
        for pid in claudePIDs() {
            if let ticks = cpuTicks(of: pid) { sample[pid] = ticks }
        }
        let oldest = history.first
        history.append((now, sample))
        if history.count > window { history.removeFirst() }
        guard let oldest else { return 0 }
        let elapsed = now.timeIntervalSince(oldest.date)
        guard elapsed > 0 else { return 0 }
        return sample.filter { pid, ticks in
            guard let before = oldest.ticks[pid], ticks >= before else { return false }
            let cpuSeconds = Double(ticks - before) * nanosPerTick / 1_000_000_000
            return cpuSeconds / elapsed > threshold
        }.count
    }

    private func claudePIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) * 2)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard filled > 0 else { return [] }
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        return pids.prefix(Int(filled)).filter { pid in
            pid > 0 && proc_pidpath(pid, &path, UInt32(path.count)) > 0 && Self.isClaude(String(cString: path))
        }
    }

    /// L'installeur natif lance `~/.local/share/claude/versions/<version>` : le nom du process
    /// est donc la version, pas `claude`. On reconnaît aussi un binaire nommé `claude`.
    private static func isClaude(_ path: String) -> Bool {
        path.contains("/claude/versions/") || (path as NSString).lastPathComponent == "claude"
    }

    private func cpuTicks(of pid: pid_t) -> UInt64? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { return nil }
        return info.pti_total_user + info.pti_total_system
    }
}
