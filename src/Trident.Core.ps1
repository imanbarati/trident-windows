#Requires -Version 5.1
<#
.SYNOPSIS
  Trident MVP core — selective Windows installer with detect + install + verify.
.DESCRIPTION
  Official sources only. Dot-sourceable library: entry points (Trident.Cli.ps1,
  Trident.Gui.ps1) load this file and call its functions.
#>
# Trident MVP core library — DOT-SOURCE ONLY, no param block here.
# (Entry points Trident.Cli.ps1 / Trident.Gui.ps1 own the parameters.)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TridentVersion = '0.1.0-mvp'
$script:GuiLogBox = $null
$script:LogDir = Join-Path $env:TEMP 'trident'
$script:LogFile = Join-Path $script:LogDir ('trident-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:Results = New-Object System.Collections.Generic.List[object]

$script:Catalog = @(
  @{ Id='hermes-agent';    Flag='hermes';          Name='Hermes Agent';    Maker='Nous Research';  Kind='ps1-script'; Desc='CLI agent runtime. Official install.ps1.'; Url='https://hermes-agent.nousresearch.com/install.ps1'; Cmd='hermes'; VerArgs='--version' },
  @{ Id='hermes-ide';      Flag='hermes-ide';      Name='Hermes IDE';      Maker='hermes-hq';       Kind='github-nsis'; Desc='Desktop IDE (GitHub NSIS).'; Owner='hermes-hq'; Repo='hermes-ide'; Patterns=@('*-Setup.exe','*.exe'); ExeNames=@('Hermes IDE','HermesIDE','Hermes') },
  @{ Id='zcode';           Flag='zcode';           Name='ZCode';           Maker='Z.AI';            Kind='github-nsis'; Desc='ZCode editor (GitHub NSIS).'; Owner='zai-org'; Repo='ZCode'; Patterns=@('*-Setup.exe','*.exe'); ExeNames=@('ZCode') },
  @{ Id='antigravity';     Flag='antigravity';     Name='Antigravity';     Maker='Google';          Kind='winget';      Desc='Google Antigravity IDE via WinGet.'; WingetId='Google.Antigravity'; Cmd=$null },
  @{ Id='antigravity-cli'; Flag='antigravity-cli'; Name='Antigravity CLI'; Maker='Google';          Kind='winget';      Desc='Antigravity CLI via WinGet.'; WingetId='Google.AntigravityCLI'; Cmd='antigravity' },
  @{ Id='claude';          Flag='claude';          Name='Claude Code';     Maker='Anthropic';       Kind='ps1-script'; Desc='Claude Code CLI. Official claude.ai installer.'; Url='https://claude.ai/install.ps1'; Cmd='claude'; VerArgs='--version' },
  @{ Id='zeroclaw';        Flag='zeroclaw';        Name='ZeroClaw';        Maker='zeroclaw-labs';   Kind='github-zip';  Desc='ZeroClaw agent CLI (msvc zip -> ~/.zeroclaw/bin).'; Owner='zeroclaw-labs'; Repo='zeroclaw'; Cmd='zeroclaw'; VerArgs='--version' }
)

$script:AliasMap = @{
  'hermes'='hermes-agent'; 'hermes-agent'='hermes-agent'; 'agent'='hermes-agent';
  'hermes-ide'='hermes-ide'; 'ide'='hermes-ide';
  'zcode'='zcode';
  'antigravity'='antigravity'; 'agy'='antigravity';
  'antigravity-cli'='antigravity-cli'; 'agy-cli'='antigravity-cli';
  'claude'='claude'; 'claude-code'='claude';
  'zeroclaw'='zeroclaw'; 'claw'='zeroclaw'; 'zero-claw'='zeroclaw'
}

function Write-TridentLog {
  param([string]$Message, [string]$Level = 'INFO')
  $ts = Get-Date -Format 'HH:mm:ss'
  $line = '[{0}] [{1}] {2}' -f $ts, $Level, $Message
  try {
    if (-not (Test-Path $script:LogDir)) { New-Item -ItemType Directory -Force -Path $script:LogDir | Out-Null }
    Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
  } catch {}
  if ($script:GuiLogBox -ne $null) {
    try {
      $script:GuiLogBox.Dispatcher.Invoke([action]{ $script:GuiLogBox.AppendText($line + [Environment]::NewLine); $script:GuiLogBox.ScrollToEnd() })
    } catch {}
  }
}

function Write-TStep { param([string]$m) Write-Host "  ->  $m" -ForegroundColor Gray; Write-TridentLog $m 'STEP' }
function Write-TOk   { param([string]$m) Write-Host "  OK  $m" -ForegroundColor Green; Write-TridentLog $m 'OK' }
function Write-TWarn { param([string]$m) Write-Host "  !!  $m" -ForegroundColor Yellow; Write-TridentLog $m 'WARN' }
function Write-TFail { param([string]$m) Write-Host "  XX  $m" -ForegroundColor Red; Write-TridentLog $m 'FAIL' }

function Get-TridentArch {
  param([string]$Wanted = 'auto')
  if ($Wanted -ne 'auto') { return $Wanted }
  $pn = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE','Machine')
  if ($pn -eq 'ARM64') { return 'arm64' }
  return 'x64'
}

function Resolve-TridentWanted {
  param([string[]]$Raw = @())
  $tokens = @()
  if ($env:TRIDENT_ONLY -and $Raw.Count -eq 0) { $tokens = @($env:TRIDENT_ONLY -split '[,\s]+') }
  elseif ($Raw.Count -gt 0) {
    foreach ($r in $Raw) { $tokens += ($r -split '[,\s]+') }
  }
  $tokens = @($tokens | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLower() } )
  if ($tokens.Count -eq 0) { return @($script:Catalog | ForEach-Object { $_.Id }) }
  $out = @()
  foreach ($t in $tokens) {
    if (-not $script:AliasMap.ContainsKey($t)) { throw "Unknown package flag: $t" }
    $out += $script:AliasMap[$t]
  }
  return @($out | Select-Object -Unique)
}

function Test-TridentWanted { param([string]$Id) return ($script:Wanted -contains $Id) }

function Get-CommandVersion {
  param([string]$Cmd, [string]$VerArgs = '--version')
  try {
    $c = Get-Command $Cmd -ErrorAction SilentlyContinue
    if ($null -eq $c) { return $null }
    $o = & $c.Source $VerArgs 2>&1 | Select-Object -First 1
    return "$o".Trim()
  } catch { return $null }
}
