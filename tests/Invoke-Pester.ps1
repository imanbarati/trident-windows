#Requires -Version 5.1
# Invoke-Pester — wraps Smoke-Test assertions as Pester tests when Pester is
# available; falls back to Smoke-Test.ps1 otherwise. NEW additive file.
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File tests\Invoke-Pester.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$here = Split-Path $MyInvocation.MyCommand.Path -Parent
$root = Split-Path $here -Parent
$src = Join-Path $root 'src'

$pesterAvail = 0
try {
  $found = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -ge 5 }
  if ($found) { $pesterAvail = @($found).Count }
} catch { $pesterAvail = 0 }
if ($pesterAvail -eq 0) {
  Write-Host 'Pester not installed; running Smoke-Test.ps1 fallback.'
  $smoke = Join-Path $root 'tools\Smoke-Test.ps1'
  powershell -NoProfile -ExecutionPolicy Bypass -File $smoke
  exit $LASTEXITCODE
}

Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
$core = Join-Path $src 'Trident.Core.ps1'
$p2 = Join-Path $src 'Trident.Core.Part2.ps1'
$p3 = Join-Path $src 'Trident.Core.Part3.ps1'
$cli = Join-Path $src 'Trident.Cli.ps1'

$container = New-PesterContainer -Path (Join-Path $here 'Trident.Tests.ps1') -Data @{ Core=$core; Part2=$p2; Part3=$p3; Cli=$cli; Src=$src }
Invoke-Pester -Container $container -Output Detailed
