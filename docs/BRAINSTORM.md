# Trident brainstorm — from selective script to fine MVP

Source repo: https://github.com/imanbarati/trident-windows/ (v1.1.0 ps1 / v1.2.0 sh + egui picker).

## What exists today

- `install.ps1` — selective Windows installer, `-Only` / `TRIDENT_ONLY`, `-Arch auto|x64|arm64`, `-DryRun`, per-package try/catch + summary table.
- `install.sh` — Termux installer (hermes APT, zeroclaw tarball, claude via proot Ubuntu note).
- `install.cmd` — double-click wrapper.
- `native/egui` — checkbox picker; Windows launches one-liner, Android copies Termux command.
- Workflows: `apk-release.yml`, `windows-gui-release.yml`.

## Official sources (verified Oct 2026)

| Flag | Package | Windows source | Detect |
|---|---|---|---|
| `hermes` | Hermes Agent (Nous Research) | `iex (irm https://hermes-agent.nousresearch.com/install.ps1)` — supports `-NonInteractive` | `hermes --version` |
| `hermes-ide` | Hermes IDE (hermes-hq/hermes-ide) | GitHub latest NSIS `.exe` | exe present / `winget list` / Start-Menu shortcut |
| `zcode` | ZCode (zai-org/ZCode) | GitHub latest NSIS `.exe` | same as above |
| `antigravity` | Antigravity (Google) | `winget install -e --id Google.Antigravity` | `winget list --id Google.Antigravity` |
| `antigravity-cli` | Antigravity CLI (Google) | `winget install -e --id Google.AntigravityCLI` | `winget list --id Google.AntigravityCLI` |
| `claude` | Claude Code (Anthropic) | `https://claude.ai/install.ps1` (downloads + SHA256 manifest) | `claude --version` |
| `zeroclaw` | ZeroClaw (zeroclaw-labs/zeroclaw) | `zeroclaw-x86_64-pc-windows-msvc.zip` → `%USERPROFILE%\.zeroclaw\bin` + User PATH | `zeroclaw --version` / exe path |

## Pain points → MVP answers

1. Silent NSIS / winget failures → capture exit codes, try `/S /VERYSILENT /quiet` fallback, log full stdout to file.
2. "Did it work?" → `Detect` (pre-flight) + `Verify` (post-flight: `--version`, `winget list`, path probe in fresh process).
3. PATH confusion → `Add-UserPath` + `WM_SETTINGCHANGE` broadcast + verify via `cmd /c where`.
4. No log to paste on failure → `%TEMP%\trident\trident-<ts>.log`, GUI `Open Logs` button.
5. Bare CLI/GUI → WPF GUI: per-package cards (name, maker, status pill, description), arch selector, DryRun toggle, live log, progress, copy-command, install/verify/detect buttons.
6. Risky `irm|iex` → show exact command before running, Copy Command button, `-DryRun` default preview in GUI log.

## Out of MVP scope

- Android/Termux changes, APK signing, auto-updates, uninstallers, Hermes onboard wizard, winget `--uninstall` cleanup.
- See `ROADMAP.md`.
