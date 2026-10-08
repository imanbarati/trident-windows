#Requires -Version 5.1
<#
.SYNOPSIS
  Trident MVP CLI entry — loads Core parts then runs detect/install/verify.
#>
[CmdletBinding()]
param(
  [ValidateSet('auto','x64','arm64')]
  [string]$Arch = 'auto',
  [string[]]$Only = @(),
  [switch]$DryRun,
  [switch]$DetectOnly,
  [switch]$VerifyOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$here = Split-Path $MyInvocation.MyCommand.Path -Parent
. (Join-Path $here 'Trident.Core.ps1')
. (Join-Path $here 'Trident.Core.Part2.ps1')
. (Join-Path $here 'Trident.Core.Part3.ps1')

$script:Wanted = Resolve-TridentWanted -Raw $Only
$machineArch = Get-TridentArch -Wanted $Arch

Write-Host ''
Write-Host ('  TRIDENT  ' + $script:TridentVersion) -ForegroundColor White
Write-Host '  Hermes - ZCode - Antigravity - Claude - ZeroClaw' -ForegroundColor DarkGray
Write-TridentLog "Trident $($script:TridentVersion) start. Arch=$machineArch Wanted=$($script:Wanted -join ',')" 'INFO'
Write-TStep "Architecture $machineArch"
Write-TStep ("Selected  " + ($script:Wanted -join ', '))
Write-TStep "Log  $($script:LogFile)"
if ($DryRun) { Write-TWarn 'Dry run - no installers will execute' }

if ($DetectOnly) {
  $rows = @()
  foreach ($p in $script:Catalog) {
    if ($script:Wanted -notcontains $p.Id) { continue }
    $d = Detect-TridentPackage -Pkg $p
    $rows += $d
    $msg = "{0}: {1}  {2}" -f $p.Name, $d.Status, $d.Detail
    if ($d.Status -eq 'installed') { Write-TOk $msg } elseif ($d.Status -eq 'unknown') { Write-TWarn $msg } else { Write-TStep $msg }
  }
  Show-TridentSummary -Rows $rows
  exit 0
}

if ($VerifyOnly) {
  $rows = Verify-TridentInstall -WantedIds $script:Wanted
  Show-TridentSummary -Rows $rows
  $failed = @($rows | Where-Object { $_.Status -eq 'failed' })
  if ($failed.Count -gt 0) { exit 1 }
  exit 0
}

$rows = @()
foreach ($p in $script:Catalog) {
  if ($script:Wanted -notcontains $p.Id) {
    $rows += [pscustomobject]@{ Name=$p.Name; Status='skipped'; Detail='not selected' }
    continue
  }
  $pre = Detect-TridentPackage -Pkg $p
  if ($pre.Status -eq 'installed' -and -not $DryRun) {
    Write-TOk "$($p.Name) already installed: $($pre.Detail)"
    $rows += [pscustomobject]@{ Name=$p.Name; Status='already'; Detail=$pre.Detail }
    continue
  }
  $r = Install-TridentPackage -Pkg $p -MachineArch $machineArch -Dry:([bool]$DryRun)
  if ($r.Status -eq 'installed') { Write-TOk "$($r.Name) done: $($r.Detail)" }
  elseif ($r.Status -eq 'skipped') { Write-TWarn "$($r.Name) skipped (dry-run)" }
  else { Write-TFail "$($r.Name) FAILED: $($r.Detail)" }
  $rows += $r
}

Write-Host ''
Write-Host '  VERIFY' -ForegroundColor White
if ($DryRun) { Write-TWarn 'Dry run - skipping verify' }
else {
  foreach ($p in $script:Catalog) {
    if ($script:Wanted -notcontains $p.Id) { continue }
    $d = Detect-TridentPackage -Pkg $p
    if ($d.Status -eq 'installed') { Write-TOk "$($p.Name): $($d.Detail)" }
    else { Write-TWarn "$($p.Name): not detected yet (open a NEW terminal, PATH may need refresh)" }
  }
}

Show-TridentSummary -Rows $rows
Write-TStep "Full log: $($script:LogFile)"
$failed = @($rows | Where-Object { $_.Status -eq 'failed' })
if ($failed.Count -gt 0) { exit 1 }
exit 0
