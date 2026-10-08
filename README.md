# Trident MVP — Fine MVP (Windows-first)

Polished selective Windows installer for **Hermes Agent, Hermes IDE, ZCode, Antigravity, Antigravity CLI, Claude Code, ZeroClaw**.

> Location: `C:\Users\Pas18\.cline\data\workspaces\chat\trident-mvp`
> Stack: **PowerShell 5.1+ core + WPF GUI (no new dependencies)** — same official-source policy as [`imanbarati/trident-windows`](https://github.com/imanbarati/trident-windows/).

## Why this is "fine" vs original

| Gap in original | MVP fix |
|---|---|
| Silent failures, no log file | File log `%TEMP%\trident\trident-<ts>.log` + on-screen log |
| No idea what's installed | **Detect** step — per-package status: `installed / missing / unknown` + version string |
| No post-check | **Verify** step — runs `--version` / `winget list` / path check |
| NSIS installers fire-and-forget | Silent-args fallback (`/S`, `/VERYSILENT`, `/quiet`), exit-code capture |
| PATH changes need reboot confusion | `Add-UserPath` + `WM_SETTINGCHANGE` broadcast, verify in fresh process |
| GUI was bare picker | Polished WPF: checkboxes + descriptions, arch selector, DryRun, progress, copy-command, open-logs |

## Quick start

```powershell
# CLI — install all (default) with detection + verify
powershell -NoProfile -ExecutionPolicy Bypass -File src\Trident.Cli.ps1

# Selective
powershell -NoProfile -ExecutionPolicy Bypass -File src\Trident.Cli.ps1 -Only claude,zeroclaw

# Dry run (no changes)
powershell -NoProfile -ExecutionPolicy Bypass -File src\Trident.Cli.ps1 -Only hermes,claude -DryRun

# Verify only
powershell -NoProfile -ExecutionPolicy Bypass -File src\Trident.Cli.ps1 -VerifyOnly

# Detect only (no downloads)
powershell -NoProfile -ExecutionPolicy Bypass -File src\Trident.Cli.ps1 -DetectOnly

# GUI (double-click)
Trident.cmd
# or
powershell -NoProfile -ExecutionPolicy Bypass -File src\Trident.Gui.ps1
```

## Layout

```
trident-mvp/
  Trident.cmd            double-click launcher (GUI)
  README.md              this file
  docs/
    BRAINSTORM.md        full brainstorm
    MVP.md               MVP scope / acceptance
    ROADMAP.md           what comes after MVP
  src/
    Trident.Core.ps1       manifest + detect + logging + alias resolution (dot-source library)
    Trident.Core.Part2.ps1 detect per-package + download + GitHub API + PATH helper
    Trident.Core.Part3.ps1 install per-package + verify + summary
    Trident.Cli.ps1        CLI entry (detect/install/verify/dry-run)
    Trident.Gui.ps1        GUI entry (loads Part1+Part2)
    Trident.Gui.Part1.ps1  WPF shell + package cards
    Trident.Gui.Part2.ps1  GUI actions (detect/install/verify/copy/logs)
  tools/
    Smoke-Test.ps1       dry-run + detect sanity (runs on Win PowerShell 5.1)
```

## Policy

- Official sources only. No mirrors, no bundled binaries.
- Same package flags as upstream: `hermes hermes-ide zcode antigravity antigravity-cli claude zeroclaw` (+ aliases).
- See `docs/BRAINSTORM.md` for source URLs per package.
