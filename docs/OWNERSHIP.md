# Coordination — concurrent agents on trident-mvp

Date: 2026-10-08. Two agents active: **Cline (this lane)** + **opencode bunny model**.

## Locked by Cline (do not touch without updating this file)

- `src/Trident.Core.ps1`
- `src/Trident.Core.Part2.ps1`
- `src/Trident.Core.Part3.ps1`
- `src/Trident.Cli.ps1`
- `src/Trident.Gui.ps1`
- `src/Trident.Gui.Part1.ps1`
- `src/Trident.Gui.Part2.ps1`
- `tools/Smoke-Test.ps1`
- `Trident.cmd`

These pass all 9 smoke checks on Win PowerShell 5.1 as of 2026-10-08. If bunny
needs a change inside them, add a note under `## Proposed edits` below instead
of editing directly.

## Free lanes for bunny (no conflict with Cline)

1. `native/` Rust egui work (separate stack, separate files).
2. `install.sh` / Termux-Android lane (Cline is Windows-only).
3. `.github/workflows/` CI (additive new files only).
4. New docs under `docs/` (new files only, do not rewrite BRAINSTORM/MVP/ROADMAP).
5. `tools/` new helpers (new files only, do not edit Smoke-Test.ps1).

## Cline in-progress (complementary, additive-only)

- `docs/AGENT-LANES.md` (this file's sibling) + `docs/CONTRIBUTIONS.md` menu.
- `tools/Export-Report.ps1` (NEW file, reads Detect output, writes markdown report).
- `tools/Uninstall-Trident.ps1` (NEW file, best-effort remove, does not alter install core).
- `tests/Invoke-Pester.ps1` + Pester Describe blocks (NEW, wraps Smoke-Test assertions).
- `AGENTS.md` at mvp root (NEW, contributor rules + lane protocol).
- `.gitignore` + `.gitattributes` (NEW, safe additive).

## Proposed edits (either agent may append, newest at bottom)

- (none yet)
