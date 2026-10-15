import SwiftUI

extension BrewMode {
    var gradient: LinearGradient {
        let colors: [Color] = switch self {
        case .espresso: [Color(red: 0.42, green: 0.24, blue: 0.13), Color(red: 0.80, green: 0.52, blue: 0.27)]
        case .coldBrew: [Color(red: 0.11, green: 0.16, blue: 0.33), Color(red: 0.29, green: 0.44, blue: 0.70)]
        }
        return LinearGradient(colors: colors, startPoint: .bottomLeading, endPoint: .topTrailing)
    }

    var tint: Color {
        switch self {
        case .espresso: Color(red: 0.80, green: 0.52, blue: 0.27)
        case .coldBrew: Color(red: 0.38, green: 0.56, blue: 0.86)
        }
    }
}

struct MenuView: View {
    @ObservedObject var brewer: Brewer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            VStack(spacing: 8) {
                ForEach(BrewMode.allCases) { mode in
                    ModeCard(mode: mode, isActive: brewer.mode == mode) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { brewer.toggle(mode) }
                    }
                }
            }
            durationPicker
            Divider().opacity(0.5)
            footer
        }
        .padding(16)
        .frame(width: 312)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(brewer.mode?.gradient ?? LinearGradient(colors: [.gray.opacity(0.35), .gray.opacity(0.2)], startPoint: .bottom, endPoint: .top))
                Image(systemName: brewer.mode?.menuBarSymbol ?? "cup.and.saucer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Brew")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(status(at: context.date))
                        .font(.system(size: 11.5))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            Spacer()
        }
    }

    private func status(at now: Date) -> String {
        guard let mode = brewer.mode else { return "Le Mac s'endort normalement" }
        if let end = brewer.endDate {
            return "\(mode.title) · encore \(format(end.timeIntervalSince(now)))"
        }
        if let start = brewer.startDate {
            return "\(mode.title) · depuis \(format(now.timeIntervalSince(start)))"
        }
        return mode.title
    }

    private func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    // MARK: Duration

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DURÉE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
            HStack(spacing: 6) {
                ForEach(BrewDuration.allCases) { duration in
                    Chip(label: duration.label,
                         isSelected: brewer.duration == duration,
                         tint: brewer.mode?.tint ?? .accentColor) {
                        withAnimation(.easeOut(duration: 0.15)) { brewer.duration = duration }
                    }
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 2) {
            FooterRow(symbol: "moon.fill", title: "Éteindre l'écran maintenant") {
                brewer.sleepDisplayNow()
            }
            HStack {
                Label("Ouvrir au démarrage", systemImage: "power")
                    .labelStyle(FooterLabelStyle())
                Spacer()
                Toggle("", isOn: Binding(get: { brewer.launchAtLogin }, set: { brewer.setLaunchAtLogin($0) }))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            FooterRow(symbol: "xmark.circle", title: "Quitter Brew", shortcut: "⌘Q") {
                brewer.stop()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

// MARK: - Components

private struct ModeCard: View {
    let mode: BrewMode
    let isActive: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isActive ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(mode.tint.opacity(0.16)))
                    Image(systemName: mode.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isActive ? .white : mode.tint)
                        .symbolEffect(.pulse, options: .repeating, isActive: isActive)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    Text(mode.subtitle)
                        .font(.system(size: 11.5))
                        .opacity(isActive ? 0.85 : 0.6)
                }
                .foregroundStyle(isActive ? .white : .primary)

                Spacer(minLength: 0)

                Capsule()
                    .fill(isActive ? .white.opacity(0.25) : .primary.opacity(0.08))
                    .frame(width: 30, height: 18)
                    .overlay(alignment: isActive ? .trailing : .leading) {
                        Circle()
                            .fill(isActive ? .white : .primary.opacity(0.35))
                            .frame(width: 14, height: 14)
                            .padding(2)
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? AnyShapeStyle(mode.gradient) : AnyShapeStyle(.primary.opacity(isHovered ? 0.08 : 0.045)))
                    .shadow(color: isActive ? mode.tint.opacity(0.35) : .clear, radius: 8, y: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(isActive ? 0.15 : 0.04), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct Chip: View {
    let label: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(tint.opacity(0.22)) : AnyShapeStyle(.primary.opacity(isHovered ? 0.08 : 0.045)))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? tint.opacity(0.55) : .clear, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct FooterRow: View {
    let symbol: String
    let title: String
    var shortcut: String?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol)
                    .labelStyle(FooterLabelStyle())
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.primary.opacity(isHovered ? 0.07 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct FooterLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            configuration.title
                .font(.system(size: 12.5))
        }
    }
}
