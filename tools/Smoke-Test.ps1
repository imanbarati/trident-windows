#Requires -Version 5.1
# Trident MVP smoke test — dry-run + detect sanity. No installs, no network writes.
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File tools\Smoke-Test.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$here = Split-Path $MyInvocation.MyCommand.Path -Parent
$root = Split-Path $here -Parent
$src = Join-Path $root 'src'

function Invoke-TridentCli { param([string]$CliArgs) $cli = Join-Path $src 'Trident.Cli.ps1'; $parts = @($CliArgs.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)); return (powershell -NoProfile -ExecutionPolicy Bypass -File $cli @parts 2>&1 | Out-String) }

$script:fail = 0
function Check { param([string]$Name, [scriptblock]$Body) try { & $Body; Write-Host "  PASS  $Name" -ForegroundColor Green } catch { Write-Host "  FAIL  $Name : $($_.Exception.Message)" -ForegroundColor Red; $script:fail++ } }

Write-Host 'Trident MVP smoke test' -ForegroundColor White

Check 'all source files exist' {
  foreach ($f in @('Trident.Core.ps1','Trident.Core.Part2.ps1','Trident.Core.Part3.ps1','Trident.Cli.ps1','Trident.Gui.Part1.ps1','Trident.Gui.Part2.ps1','Trident.Gui.ps1')) {
    if (-not (Test-Path (Join-Path $src $f))) { throw "missing $f" }
  }
}

Check 'core dot-sources without error' {
  powershell -NoProfile -ExecutionPolicy Bypass -Command ". '$src\Trident.Core.ps1'; . '$src\Trident.Core.Part2.ps1'; . '$src\Trident.Core.Part3.ps1'; Write-Output 'ok'" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'dot-source failed' }
}

Check 'catalog has 7 packages' {
  $out = powershell -NoProfile -ExecutionPolicy Bypass -Command ". '$src\Trident.Core.ps1'; Write-Output `$script:Catalog.Count" 2>&1 | Out-String
  if ($out.Trim() -notmatch '7') { throw "expected 7, got: $out" }
}

Check 'dry-run all exits 0' {
  $o = Invoke-TridentCli '-DryRun'
  if ($o -notmatch 'TRIDENT') { throw 'no banner in dry-run output' }
}

Check 'dry-run selective claude,zeroclaw' {
  $o = Invoke-TridentCli '-Only claude,zeroclaw -DryRun'
  if ($o -notmatch 'claude') { throw 'selective output missing claude' }
}

Check 'detect-only exits 0, no downloads' {
  $o = Invoke-TridentCli '-DetectOnly'
  if ($o -notmatch 'SUMMARY') { throw 'detect output missing SUMMARY' }
}

Check 'verify-only runs' {
  $o = Invoke-TridentCli '-VerifyOnly'
  if ($o -notmatch 'SUMMARY') { throw 'verify output missing SUMMARY' }
}

Check 'unknown flag rejected' {
  $cli = Join-Path $src 'Trident.Cli.ps1'
  $o = ''
  try { $o = powershell -NoProfile -ExecutionPolicy Bypass -File $cli -Only nope -DryRun 2>&1 | Out-String } catch { $o = [string]$_ }
  if ($o -notmatch 'Unknown package flag') { throw 'expected rejection, got no match' }
}

Check 'log file written' {
  $logs = Get-ChildItem (Join-Path $env:TEMP 'trident') -Filter 'trident-*.log' -ErrorAction SilentlyContinue
  if (-not $logs) { throw 'no log under %TEMP%\trident' }
}

Write-Host ''
if ($script:fail -gt 0) { Write-Host "$($script:fail) check(s) FAILED" -ForegroundColor Red; exit 1 }
Write-Host 'All smoke checks passed.' -ForegroundColor Green
exit 0
