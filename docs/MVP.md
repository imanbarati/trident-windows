# Trident fine-MVP — scope & acceptance

## In scope

- [x] `src/Trident.Core.ps1` — manifest, alias resolution, `Detect-TridentPackage`, `Install-TridentPackage`, `Verify-TridentInstall`, file logging, `-Only`, `-Arch`, `-DryRun`, `-VerifyOnly`, `-DetectOnly`.
- [x] `src/Trident.Gui.ps1` — WPF, zero-dependency: checkboxes, arch combo, DryRun toggle, Detect/Install/Verify/Copy/Open-Logs, status pills, live log, progress.
- [x] `Trident.cmd` — double-click GUI launcher.
- [x] `tools/Smoke-Test.ps1` — dry-run + detect sanity, runs on stock Win 10/11 PowerShell 5.1.

## Acceptance

1. `powershell -File src\Trident.Core.ps1 -DryRun` exits 0, prints banner + selected list + per-package DRY lines, writes a log under `%TEMP%\trident\`.
2. `powershell -File src\Trident.Core.ps1 -DetectOnly` prints `installed|missing` per package, never downloads.
3. `Trident.cmd` opens GUI with 7 packages, each showing a status pill after Detect.
4. GUI Install streams log lines + progress bar, writes same log file, Copy Command copies the exact CLI equivalent.
5. No mirrors: all URLs are `hermes-agent.nousresearch.com`, `claude.ai`, `github.com/<owner>/<repo>`, or `winget`.

## Manual test matrix

| Case | Command | Expect |
|---|---|---|
| Dry all | `...Cli.ps1 -DryRun` | 0, 7 DRY lines |
| Selective dry | `...Cli.ps1 -Only claude,zeroclaw -DryRun` | only those two attempt |
| Detect | `...Cli.ps1 -DetectOnly` | table, no network except none |
| Verify | `...Cli.ps1 -VerifyOnly` | version probes, non-zero only if you want strict |
| GUI | double-click `Trident.cmd` | window, Detect fills pills |
