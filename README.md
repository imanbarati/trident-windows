# Trident

Selective installer for **Hermes**, **ZeroClaw**, **Claude Code**, **ZCode**, and **Google Antigravity**.

- **Windows** — PowerShell (`install.ps1`)
- **Android** — Termux (`install.sh`)
- **Native GUI** — [egui](https://github.com/emilk/egui) crate in `native/egui`

Official sources only. No mirrors, no bundled binaries.

## Windows

Open **PowerShell** on Windows 10 or 11:

```powershell
irm https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1 | iex
```

Or download this repo and double-click `install.cmd`.

### Selective install

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1'))) -Only claude,zeroclaw
```

```powershell
.\install.ps1 -Only hermes,zcode,zeroclaw
.\install.ps1 -Only claude -Arch x64
$env:TRIDENT_ONLY = 'claude,zeroclaw'
irm https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1 | iex
```

## Android / Termux

What actually runs on a phone:

| Package | Android |
| --- | --- |
| Hermes Agent | Official Termux APT (aarch64). Nous currently flags the package as broken; Trident still uses that repo. |
| ZeroClaw | Official `zeroclaw-aarch64-linux-android.tar.gz` |
| Claude Code | No official Android binary. Script prints Termux `proot-distro` Ubuntu + [claude.ai/install.sh](https://claude.ai/install.sh) |
| Hermes IDE, ZCode, Antigravity | Windows-only desktop apps |

Install **Termux from F-Droid or GitHub**. The Play Store build is stale.

```bash
curl -fsSL https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.sh | bash -s -- --only hermes,zeroclaw
```

```bash
./install.sh --only hermes,zeroclaw
./install.sh --only claude
TRIDENT_ONLY=hermes,zeroclaw ./install.sh
```

Default (no `--only`) installs Hermes + ZeroClaw.

ZeroClaw’s interactive onboard and Hermes setup are left for you after install.

## Native GUI (egui)

```sh
cd native/egui
cargo run --release
```

Windows: Install launches the PowerShell one-liner. Android: the GUI copies the Termux command (an APK cannot install Termux packages). See `native/egui/README.md`.

### Package flags

| Flag | Package | Windows | Android |
| --- | --- | --- | --- |
| `hermes` | Hermes Agent | official `install.ps1` | Termux APT |
| `hermes-ide` | Hermes IDE | GitHub NSIS | — |
| `zcode` | ZCode | GitHub NSIS | — |
| `antigravity` | Antigravity | WinGet `Google.Antigravity` | — |
| `antigravity-cli` | Antigravity CLI | WinGet `Google.AntigravityCLI` | — |
| `claude` | Claude Code | `claude.ai/install.ps1` | official Linux installer inside proot Ubuntu |
| `zeroclaw` | ZeroClaw | Windows msvc zip | aarch64 Android tarball |

## After install

Windows (new terminal):

```powershell
hermes --version
claude --version
zeroclaw --version
```

Termux:

```bash
hermes --version
zeroclaw --version
```

## License

MIT. The third-party apps keep their own licenses.
