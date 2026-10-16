<p align="center">
  <img src="docs/icon.png" width="128" alt="Brew icon">
</p>

<h1 align="center">Brew</h1>

<p align="center">
  <strong>Keep your Mac awake, one cup at a time.</strong><br>
  A tiny, native menu bar app for macOS. No dependencies, no Dock icon, no fuss.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/size-~300%20KB-8B5A2B" alt="~300 KB">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT license">
</p>

<p align="center">
  <a href="https://github.com/marcmend/brew/releases/download/v1.0.0/Brew-1.0.0-arm64.dmg">
    <img src="https://img.shields.io/badge/Download_for_Mac-v1.0.0-8B5A2B?style=for-the-badge&logo=apple&logoColor=white" alt="Download for Mac">
  </a>
  <br>
  <sub>Apple Silicon (M1 and later) · macOS 14+ · <a href="https://github.com/marcmend/brew/releases">all releases</a></sub>
</p>

<p align="center">
  <img src="docs/screenshot.png" width="340" alt="Brew menu">
</p>

---

## Two brews ☕

| | Mode | Screen | Mac | Perfect for |
|---|---|---|---|---|
| ☕ | **Espresso** | stays on | never sleeps | presentations, dashboards, reading, anything you're *looking at* |
| ❄️ | **Cold Brew** | can turn off | keeps running | long builds, downloads, AI agents and scripts working while you're away |

**Espresso** holds the same power assertion a video player takes in full screen (`PreventUserIdleDisplaySleep`), so your Mac behaves exactly as if you were watching YouTube.

**Cold Brew** steeps quietly in the dark: the display is free to sleep, but the system isn't (`PreventUserIdleSystemSleep`). Your processes keep going and your screen stays dark.

## ✳️ While Claude works

Flip **While Claude works** and Brew stays awake exactly as long as [Claude Code](https://claude.com/claude-code) is busy, then lets your Mac sleep **2 minutes after the last task ends**. Start a long refactor, switch on Cold Brew, lock your screen and walk away: no wasted night of battery, no agent killed halfway.

It works across every open session, and the menu shows how many are running or the countdown before Brew lets go.

<details>
<summary>How does it know?</summary>

An idle `claude` process waiting for a prompt sits around 0.5% CPU. While it works (thinking, streaming, waiting on a tool), its animated spinner keeps it above ~4%. Brew samples the CPU time of every Claude Code process every 5 s over a 15 s sliding window, and treats anything above 3% as busy. There are no hooks to install and no config to touch.
</details>

## Features

- **One click** to toggle a mode, and one more to turn it off
- **Timers**: ∞, 15 min, 1 h, 2 h, 4 h. Brew stops on its own when time's up
- **While Claude works**: stays awake until your Claude Code sessions are done
- **Live status** shows how long it's been brewing, or how long is left
- **Turn off the display now**, the perfect companion to Cold Brew
- **Open at login**
- Menu bar icon changes with the active mode
- Native SwiftUI with light & dark mode, all in ~300 KB

## Install

### Download

1. Download **[Brew-1.0.0-arm64.dmg](https://github.com/marcmend/brew/releases/download/v1.0.0/Brew-1.0.0-arm64.dmg)**, open it and drag **Brew** into **Applications**.
2. Launch Brew from Applications. A ☕ appears in your menu bar.

> **First launch:** Brew isn't notarized by Apple yet, so macOS blocks it the first time ("Apple could not verify Brew…"). Click **Done**, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**. You only need to do this once.
>
> Or, from a terminal: `xattr -dr com.apple.quarantine /Applications/Brew.app`

### Build from source

Requires macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/marcmend/brew.git
cd brew
./build.sh install   # builds Brew.app, copies it to /Applications and launches it
```

`./build.sh` alone builds `build/Brew.app` without installing it, and `scripts/create-dmg.sh <version>` packages it into `dist/`.

## Good to know

- **Lid closed = sleep.** macOS always sleeps a MacBook when you close the lid, whatever app asks it not to. The only exception is clamshell mode (power plus an external display). To keep things running on a laptop, leave the lid open and use **Turn off the display now**.
- Brew releases its assertion on quit, on timer end, or when you switch modes. You can check what's active with:
  ```bash
  pmset -g assertions | grep Brew
  ```

## How it works

```
Sources/Brew/
├── BrewApp.swift        # MenuBarExtra entry point
├── Brewer.swift         # IOKit power assertions, timer, login item
├── ClaudeWatcher.swift  # detects busy Claude Code sessions
└── MenuView.swift       # the UI
```

Brew is a thin layer over `IOPMAssertionCreateWithName`, which is the same API `caffeinate` uses, wrapped in a nicer cup.

## License

[MIT](LICENSE): take it, fork it, ship it, sell it. Do whatever you want with it, just keep the copyright notice.

---

<p align="center"><sub>Made with ☕ in France</sub></p>
