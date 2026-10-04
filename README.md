# Trident

Windows installer for **Hermes**, **ZCode**, and **Google Antigravity**.

Official sources only. No mirrors, no bundled binaries.

## Install

Open **PowerShell** on Windows 10 or 11:

```powershell
irm https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1 | iex
```

Or download this repo and double-click `install.cmd`.

## What it installs

| Package | Source |
| --- | --- |
| Hermes Agent | [hermes-agent.nousresearch.com](https://hermes-agent.nousresearch.com) |
| Hermes IDE | [hermes-hq/hermes-ide](https://github.com/hermes-hq/hermes-ide) |
| ZCode | [zai-org/ZCode](https://github.com/zai-org/ZCode) |
| Antigravity | WinGet `Google.Antigravity` or [antigravity.google/download](https://antigravity.google/download) |
| Antigravity CLI | WinGet `Google.AntigravityCLI` or the official CLI script |

Architecture is detected automatically (`x64` or `ARM64`).

## Options

```powershell
.\install.ps1 -Arch x64
.\install.ps1 -SkipHermesIde
.\install.ps1 -SkipZCode
.\install.ps1 -SkipAntigravity
.\install.ps1 -DryRun
```

## After install

Open a **new** terminal:

```powershell
hermes --version
```

Then launch ZCode and Antigravity from the Start menu.

## License

MIT. The third-party apps keep their own licenses.
