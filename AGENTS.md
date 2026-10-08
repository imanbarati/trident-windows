# trident-mvp contributor rules (Cline + bunny + humans)

## Lane protocol

1. Read `docs/OWNERSHIP.md` first. Files listed under "Locked by Cline" are
   owned and green (9/9 smoke). Do not edit them directly.
2. Need a change inside a locked file? Append to `## Proposed edits` in
   `docs/OWNERSHIP.md` with date + rationale; the owner applies it.
3. Prefer NEW files over edits: `tools/<Name>.ps1`, `docs/<Topic>.md`,
   `tests/*.Tests.ps1`. New files never conflict.
4. One concern per file. Keep PowerShell 5.1 compat (no `?.`, no `??`,
   avoid `$()"` interpolation — use concatenation; it broke the 5.1 parser
   twice already, see Check-Syntax history).
5. Every new tool must support `-DryRun` or `-WhatIf` and must never install
   or delete without an explicit flag.
6. Official sources only. No mirrors, no bundled binaries, no credential
   harvesting. Report exporter must stay detect-only.

## Style

- ASCII-safe in `.ps1` (unicode dashes render as mojibake in WinPS 5.1
  console). Unicode is fine in `.md` and WPF XAML.
- Hashtable catalog entries: Id, Flag, Name, Maker, Kind, Desc + kind fields.
- Log via `Write-TridentLog` so GUI + file stay in sync.

## Validate

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Smoke-Test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File src\Trident.Cli.ps1 -DetectOnly
```
