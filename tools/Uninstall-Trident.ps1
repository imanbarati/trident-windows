#Requires -Version 5.1
# Uninstall-Trident — best-effort removal. NEW additive file, does NOT alter
# the install core. Supports -WhatIf preview and -DryRun.
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File tools\Uninstall-Trident.ps1 -Only zeroclaw -WhatIf
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string[]]$Only = @(),
  [switch]$DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$here = Split-Path $MyInvocation.MyCommand.Path -Parent
$src = Join-Path (Split-Path $here -Parent) 'src'
. (Join-Path $src 'Trident.Core.ps1')
. (Join-Path $src 'Trident.Core.Part2.ps1')
. (Join-Path $src 'Trident.Core.Part3.ps1')

$script:Wanted = Resolve-TridentWanted -Raw $Only
Write-Host ('Trident uninstall; selected: ' + ($script:Wanted -join ', '))
if ($DryRun) { Write-Host 'Dry run: no changes will be made.' }

function Remove-TridentPackage {
  param([hashtable]$Pkg, [bool]$Dry)
  $id = $Pkg.Id
  if ($Pkg.Kind -eq 'winget') {
    $cmd = 'winget uninstall -e --id ' + $Pkg.WingetId
    Write-Host (' -> ' + $cmd)
    if ($Dry) { return 'dry-run' }
    try {
      $o = & winget uninstall -e --id $Pkg.WingetId 2>&1 | Out-String
      Write-Host $o
      return 'done'
    } catch { return ('failed: ' + $_.Exception.Message) }
  }
  if ($id -eq 'zeroclaw') {
    $dir = Join-Path $env:USERPROFILE '.zeroclaw\bin'
    $exe = Join-Path $dir 'zeroclaw.exe'
    Write-Host (' -> remove ' + $exe)
    if ($Dry) { return 'dry-run' }
    try {
      if (Test-Path $exe) { Remove-Item -Force $exe }
      return 'done (config in ~/.zeroclaw kept)'
    } catch { return ('failed: ' + $_.Exception.Message) }
  }
  if ($Pkg.Kind -eq 'github-nsis') {
    $names = $Pkg.ExeNames -join ', '
    $msg = 'manual step: use Add/Remove Programs for ' + $names + '; NSIS silent uninstall varies per vendor'
    Write-Host (' -> ' + $msg)
    return 'manual'
  }
  $cli = $Pkg.Cmd
  if ($cli) {
    $msg2 = 'manual step: no vendor uninstaller known; remove ' + $cli + ' via its own docs'
    Write-Host (' -> ' + $msg2)
    return 'manual'
  }
  return 'manual'
}

foreach ($p in $script:Catalog) {
  if ($script:Wanted -notcontains $p.Id) { continue }
  $label = $p.Name + ' ... '
  $res = Remove-TridentPackage -Pkg $p -Dry ([bool]$DryRun)
  Write-Host ($label + $res)
}
Write-Host 'Done. Re-run Detect to confirm.'
