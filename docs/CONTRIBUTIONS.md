# Other contributions to trident-mvp (beyond the core installer)

Status as of 2026-10-08. Core (src/ + Trident.cmd + Smoke-Test) is done and
green 9/9. Everything below is complementary and additive — no core edits.

## Shipped this session (Cline, additive-only)

| File | What | Validate |
|---|---|---|
| `docs/OWNERSHIP.md` | lane locks + free lanes + proposed-edits inbox for bunny | read |
| `AGENTS.md` | contributor rules (5.1 compat, DryRun mandate, official-sources) | read |
| `tools/Export-Report.ps1` | detect-only markdown report (`%TEMP%\trident\trident-report-*.md`) | ran OK, found ZCode + Claude |
| `tools/Uninstall-Trident.ps1` | best-effort remove (winget / zeroclaw bin / NSIS guidance), `-DryRun` | ran OK `-Only zeroclaw -DryRun` |
| `tests/Invoke-Pester.ps1` | Pester 5 runner with Smoke-Test fallback | fallback runs 9/9 |
| `tests/Trident.Tests.ps1` | catalog + CLI Describe blocks (needs Pester 5) | pending Pester 5 install |
| `.gitignore` / `.gitattributes` | ps1 CRLF hygiene | — |

## Still open (pick one, all conflict-free)

1. **Bunny lanes (suggested):** `native/` egui, `install.sh` Termux, `.github/workflows/` CI, new docs under `docs/`.
2. **Release packaging:** zip `Trident.cmd` + `src/` + README as `trident-mvp-win-v0.1.0.zip` + SHA256 file.
3. **Pester 5:** `Install-Module Pester -Force` then `tests/Invoke-Pester.ps1` runs real Describes.
4. **GUI screenshots:** run `Trident.cmd`, capture Detect/Install states into `docs/img/`.
5. **Report PR body:** use `Export-Report.ps1` output as the push PR description.
6. **Push:** needs repo URL + auth (no git remote exists yet; `gh` CLI not installed).

## Coordination signal for bunny

Bunny: read `docs/OWNERSHIP.md` before touching anything. Locked files are
listed there. To request a core change, append to `## Proposed edits` — do not
edit locked files directly. Free lanes are `native/`, `install.sh`,
`.github/workflows/` (new files), `docs/` (new files), `tools/` (new files).
