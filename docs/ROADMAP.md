# Trident roadmap — after fine-MVP

## v1.1 — robustness

- Uninstall (`winget uninstall`, remove `%USERPROFILE%\.zeroclaw\bin`, NSIS `Uninstall.exe /S` discovery).
- Retry with backoff for GitHub API rate limits + optional `GITHUB_TOKEN`.
- Checksum verify for GitHub zips (compare `sha256` asset when present).
- `winget upgrade` path for antigravity packages.

## v1.2 — UX

- Rust egui parity: reuse Core via sidecar (`Trident.Core.ps1 -Only ... -NonInteractive`).
- Dark titlebar, toast on completion, "Open new terminal & verify" button.
- Export report (`trident-report.md`) for bug posts.

## v1.3 — release engineering

- `windows-gui-release.yml`: build `.cmd`+`ps1` zip + tag `win-v*`, attach log sample.
- Pester tests in CI (`tools/Smoke-Test.ps1` + Pester wrapper).
- Signed scripts (Authenticode) when cert available.

## Non-goals (kept)

- No mirrors / repackaging — official sources only.
- No silent Hermes onboard — user runs `hermes setup` / `zeroclaw onboard` themselves.
- No Android installer changes in Windows MVP track.
