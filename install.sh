#!/usr/bin/env bash
# Trident 1.2.0 — Termux / Android installer
# Official sources only. Hermes (Termux APT), ZeroClaw (Android tarball),
# Claude Code (Anthropic install.sh inside a glibc Linux / proot Ubuntu).
set -euo pipefail

VERSION="1.2.0"
ONLY_RAW="${TRIDENT_ONLY:-}"
ARCH="auto"
DRY=0

usage() {
  cat <<'EOF'
Trident Android / Termux installer

  curl -fsSL https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.sh | bash

  curl -fsSL .../install.sh | bash -s -- --only hermes,zeroclaw
  ./install.sh --only claude --arch aarch64
  TRIDENT_ONLY=hermes,zeroclaw ./install.sh

Flags:
  --only LIST   comma list: hermes, zeroclaw, claude
  --arch ARCH   auto | aarch64 | armv7
  --dry-run     print steps without installing
  -h, --help    this text

Default (no --only): hermes + zeroclaw.
Claude Code has no official Android binary; --only claude prints
proot-distro Ubuntu + https://claude.ai/install.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)
      ONLY_RAW="${2:-}"
      shift 2
      ;;
    --only=*)
      ONLY_RAW="${1#--only=}"
      shift
      ;;
    --arch)
      ARCH="${2:-auto}"
      shift 2
      ;;
    --arch=*)
      ARCH="${1#--arch=}"
      shift
      ;;
    --dry-run)
      DRY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

is_termux() {
  [[ -n "${TERMUX_VERSION:-}" ]] && return 0
  [[ -n "${PREFIX:-}" && -d "${PREFIX}" && "${PREFIX}" == *com.termux* ]] && return 0
  [[ -d /data/data/com.termux/files/usr ]] && return 0
  return 1
}

in_glibc_linux() {
  if is_termux; then
    return 1
  fi
  [[ "$(uname -s 2>/dev/null || true)" == "Linux" ]] || return 1
  command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1
}

resolve_arch() {
  local m
  m="$(uname -m 2>/dev/null || echo unknown)"
  case "${ARCH}" in
    auto)
      case "$m" in
        aarch64|arm64) echo aarch64 ;;
        armv7l|armv8l|armv7*) echo armv7 ;;
        *) echo "$m" ;;
      esac
      ;;
    aarch64|arm64) echo aarch64 ;;
    armv7|armv7l) echo armv7 ;;
    *) echo "${ARCH}" ;;
  esac
}

WANTED_ARCH="$(resolve_arch)"

declare -A ALIAS=(
  [hermes]=hermes
  [hermes-agent]=hermes
  [agent]=hermes
  [zeroclaw]=zeroclaw
  [claw]=zeroclaw
  [claude]=claude
  [claude-code]=claude
  [hermes-ide]=skip
  [ide]=skip
  [zcode]=skip
  [antigravity]=skip
  [agy]=skip
  [antigravity-cli]=skip
  [agy-cli]=skip
)

declare -A WANT=()

if [[ -n "${ONLY_RAW}" ]]; then
  IFS=', ' read -ra TOKENS <<< "${ONLY_RAW}"
  for raw in "${TOKENS[@]}"; do
    token="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
    [[ -z "$token" ]] && continue
    mapped="${ALIAS[$token]:-}"
    if [[ -z "$mapped" ]]; then
      echo "Unknown package: $raw" >&2
      exit 2
    fi
    if [[ "$mapped" == "skip" ]]; then
      echo "skip  $raw  (Windows only)"
      continue
    fi
    WANT[$mapped]=1
  done
else
  WANT[hermes]=1
  WANT[zeroclaw]=1
fi

if [[ ${#WANT[@]} -eq 0 ]]; then
  echo "Nothing to install. Pass --only hermes,zeroclaw,claude" >&2
  exit 2
fi

say() { printf '%s\n' "$*"; }
run() {
  if [[ "$DRY" -eq 1 ]]; then
    say "dry  $*"
    return 0
  fi
  eval "$@"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_termux_tools() {
  if is_termux; then
    if ! need_cmd curl || ! need_cmd tar; then
      say "▸ installing curl tar"
      run "pkg install -y curl tar"
    fi
  fi
}

install_hermes() {
  say "▸ Hermes Agent"
  if is_termux; then
    say "    official Termux APT (stable)"
    say "    note: Nous currently flags the Termux package as broken; using that repo anyway"
    if [[ "$DRY" -eq 1 ]]; then
      say "dry  pkg install hermes-agent"
      return 0
    fi
    pkg install -y curl gnupg
    mkdir -p "$PREFIX/etc/apt/keyrings"
    curl -fsSL \
      https://hermes-assets.nousresearch.com/releases/termux/stable/key.asc \
      -o "$PREFIX/etc/apt/keyrings/hermes-agent.asc"
    printf '%s\n' \
      "deb [signed-by=$PREFIX/etc/apt/keyrings/hermes-agent.asc] https://hermes-assets.nousresearch.com/releases/termux/stable hermes-stable main" \
      > "$PREFIX/etc/apt/sources.list.d/hermes-agent.list"
    pkg update -y
    pkg install -y hermes-agent
    say "    done"
    return 0
  fi
  if in_glibc_linux; then
    say "    official Linux installer"
    run "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
    say "    done"
    return 0
  fi
  say "    skip — Hermes Termux APT needs Termux, or the Linux installer needs glibc Linux"
}

install_zeroclaw() {
  say "▸ ZeroClaw"
  if [[ "$WANTED_ARCH" != "aarch64" ]]; then
    say "    skip — official Android binary is aarch64 only (this device: ${WANTED_ARCH})"
    say "    https://github.com/zeroclaw-labs/zeroclaw/releases/latest"
    return 0
  fi
  local url tmp dest bin
  url="https://github.com/zeroclaw-labs/zeroclaw/releases/latest/download/zeroclaw-aarch64-linux-android.tar.gz"
  say "    GET zeroclaw-aarch64-linux-android.tar.gz"
  if [[ "$DRY" -eq 1 ]]; then
    say "dry  curl $url"
    return 0
  fi
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL -o "$tmp/zc.tgz" "$url"
  tar -xzf "$tmp/zc.tgz" -C "$tmp"
  bin="$(find "$tmp" -type f -name zeroclaw | head -n 1)"
  if [[ -z "$bin" ]]; then
    echo "ZeroClaw binary missing from archive" >&2
    return 1
  fi
  chmod +x "$bin"
  if is_termux; then
    dest="$PREFIX/bin/zeroclaw"
    mkdir -p "$PREFIX/bin"
  else
    dest="${HOME}/.zeroclaw/bin/zeroclaw"
    mkdir -p "$(dirname "$dest")"
  fi
  mv -f "$bin" "$dest"
  say "    wrote $dest"
  if ! is_termux; then
    say "    add ~/.zeroclaw/bin to PATH if it is not already"
  fi
  say "    done (run zeroclaw onboard yourself)"
}

install_claude() {
  say "▸ Claude Code"
  if in_glibc_linux; then
    say "    official https://claude.ai/install.sh"
    run "curl -fsSL https://claude.ai/install.sh | bash"
    say "    done"
    return 0
  fi
  say "    no official Android binary — not installing a third-party patcher"
  cat <<'EOF'
    On Termux (F-Droid), use Anthropic's Linux installer inside Ubuntu:

      pkg install proot-distro
      proot-distro install ubuntu
      proot-distro login ubuntu
      curl -fsSL https://claude.ai/install.sh | bash

EOF
}

say "Trident ${VERSION}"
say "Platform     $(is_termux && echo termux || uname -s)"
say "Architecture ${WANTED_ARCH}"
say "Selected     ${!WANT[*]}"
say ""

ensure_termux_tools

[[ -n "${WANT[hermes]:-}" ]] && install_hermes
[[ -n "${WANT[zeroclaw]:-}" ]] && install_zeroclaw
[[ -n "${WANT[claude]:-}" ]] && install_claude

say ""
say "Open a new session and check:"
[[ -n "${WANT[hermes]:-}" ]] && say "  hermes --version"
[[ -n "${WANT[zeroclaw]:-}" ]] && say "  zeroclaw --version"
[[ -n "${WANT[claude]:-}" ]] && say "  claude --version"
