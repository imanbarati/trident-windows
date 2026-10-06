# Trident

Selective Windows installer for **Hermes**, **ZCode**, **Google Antigravity**, **Claude Code**, and **ZeroClaw**.

Official sources only. No mirrors, no bundled binaries.

## Install everything

Open **PowerShell** on Windows 10 or 11:

```powershell
irm https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1 | iex
```

Or download this repo and double-click `install.cmd`.

## Selective install

Tick only the tools you want. `-Only` accepts a comma-separated list:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1'))) -Only claude,zeroclaw
```

Same flags on a local copy:

```powershell
.\install.ps1 -Only hermes,zcode,zeroclaw
.\install.ps1 -Only claude -Arch x64
.\install.ps1 -SkipZCode -SkipHermesIde
.\install.ps1 -DryRun
```

Piped one-liners can also use an environment variable:

```powershell
$env:TRIDENT_ONLY = 'claude,zeroclaw'
irm https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1 | iex
```

### Package flags

| Flag | Package | Source |
| --- | --- | --- |
| `hermes` | Hermes Agent | [hermes-agent.nousresearch.com](https://hermes-agent.nousresearch.com) |
| `hermes-ide` | Hermes IDE | [hermes-hq/hermes-ide](https://github.com/hermes-hq/hermes-ide) |
| `zcode` | ZCode | [zai-org/ZCode](https://github.com/zai-org/ZCode) |
| `antigravity` | Antigravity | WinGet `Google.Antigravity` or [antigravity.google/download](https://antigravity.google/download) |
| `antigravity-cli` | Antigravity CLI | WinGet `Google.AntigravityCLI` |
| `claude` | Claude Code | [claude.ai/install.ps1](https://claude.ai/install.ps1) or WinGet `Anthropic.ClaudeCode` |
| `zeroclaw` | ZeroClaw | [zeroclaw-labs/zeroclaw](https://github.com/zeroclaw-labs/zeroclaw) prebuilt zip |

Architecture is detected automatically (`x64` or `ARM64`). Omit `-Only` to install the full stack.

ZeroClaw’s interactive `quickstart` is left for you to run after install.

## After install

Open a **new** terminal:

```powershell
hermes --version
claude --version
zeroclaw --version
```

Then launch ZCode and Antigravity from the Start menu.

## License

MIT. The third-party apps keep their own licenses.
