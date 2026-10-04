#Requires -Version 5.1
<#
.SYNOPSIS
  Trident — install Hermes, ZCode, Antigravity, and Claude Code on Windows.

.DESCRIPTION
  Official Windows builds only:
    - Hermes Agent   https://hermes-agent.nousresearch.com
    - Hermes IDE     https://github.com/hermes-hq/hermes-ide
    - ZCode          https://github.com/zai-org/ZCode
    - Antigravity    https://antigravity.google
    - Claude Code    https://code.claude.com/docs/en/quickstart

.EXAMPLE
  irm https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1 | iex
#>
[CmdletBinding()]
param(
    [ValidateSet("auto", "x64", "arm64")]
    [string]$Arch = "auto",
    [switch]$SkipHermesAgent,
    [switch]$SkipHermesIde,
    [switch]$SkipZCode,
    [switch]$SkipAntigravity,
    [switch]$SkipAntigravityCli,
    [switch]$SkipAntigravityIde,
    [switch]$SkipClaudeCode,
    [switch]$SkipGit,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$TridentVersion = "1.1.0"
$WorkDir = Join-Path $env:TEMP "trident-windows"
$Results = New-Object System.Collections.Generic.List[object]

function Write-Banner {
    Write-Host ""
    Write-Host "  TRIDENT  $TridentVersion" -ForegroundColor White
    Write-Host "  Hermes  ·  ZCode  ·  Antigravity  ·  Claude Code" -ForegroundColor DarkGray
    Write-Host ""
}
function Write-Step { param([string]$Message) Write-Host ("  ->  " + $Message) -ForegroundColor Gray }
function Write-Ok { param([string]$Message) Write-Host ("  OK  " + $Message) -ForegroundColor Green }
function Write-WarnLine { param([string]$Message) Write-Host ("  !   " + $Message) -ForegroundColor Yellow }
function Write-Fail { param([string]$Message) Write-Host ("  X   " + $Message) -ForegroundColor Red }

function Add-Result {
    param(
        [string]$Name,
        [ValidateSet("installed", "skipped", "already", "failed")]
        [string]$Status,
        [string]$Detail = ""
    )
    $Results.Add([pscustomobject]@{ Name = $Name; Status = $Status; Detail = $Detail }) | Out-Null
}

function Get-MachineArch {
    if ($Arch -ne "auto") { return $Arch }
    $pn = [Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE", "Machine")
    if ($pn -eq "ARM64") { return "arm64" }
    try {
        if ($null -ne (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            $cim = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($cim -and $cim.OSArchitecture -match "ARM") { return "arm64" }
        }
    } catch { }
    return "x64"
}

function Test-AppCommand {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-Winget { return [bool](Get-Command winget -ErrorAction SilentlyContinue) }

function Invoke-WingetInstall {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$DisplayName
    )
    if (-not (Test-Winget)) { return $false }
    Write-Step "winget install $Id"
    if ($DryRun) { return $true }
    $wingetArgs = @(
        "install", "-e", "--id", $Id,
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
    )
    $p = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -eq 0 -or $p.ExitCode -eq -1978335189) { return $true }
    Write-WarnLine "$DisplayName winget exit $($p.ExitCode) — trying next method"
    return $false
}

function Get-GitHubLatestAsset {
    param(
        [Parameter(Mandatory = $true)][string]$Owner,
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string[]]$NamePatterns
    )
    $api = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
    Write-Step "Query $Owner/$Repo latest release"
    $headers = @{
        "User-Agent" = "trident-windows/$TridentVersion"
        "Accept"     = "application/vnd.github+json"
    }
    $release = Invoke-RestMethod -Uri $api -Headers $headers -UseBasicParsing
    foreach ($pattern in $NamePatterns) {
        $asset = $release.assets | Where-Object { $_.name -like $pattern } | Select-Object -First 1
        if ($asset) {
            return [pscustomobject]@{
                Name = $asset.name
                Url  = $asset.browser_download_url
                Tag  = $release.tag_name
            }
        }
    }
    throw "No asset matching $($NamePatterns -join ', ') in $Owner/$Repo $($release.tag_name)"
}

function Save-Url {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    Write-Step "Download $(Split-Path $Destination -Leaf)"
    if ($DryRun) { return }
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    if (-not (Test-Path $Destination)) { throw "Download failed: $Url" }
}

function Invoke-SetupExe {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string[]]$Arguments = @("/S")
    )
    Write-Step "Run $(Split-Path $Path -Leaf)"
    if ($DryRun) { return 0 }
    $p = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru
    return $p.ExitCode
}

function Install-HermesAgent {
    if ($SkipHermesAgent) { Add-Result -Name "Hermes Agent" -Status "skipped" -Detail "flag"; return }
    if (Test-AppCommand "hermes") {
        Write-Ok "Hermes Agent already on PATH"
        Add-Result -Name "Hermes Agent" -Status "already" -Detail (Get-Command hermes).Source
        return
    }
    Write-Host ""
    Write-Host "  HERMES AGENT" -ForegroundColor White
    try {
        Write-Step "Official installer  hermes-agent.nousresearch.com"
        if ($DryRun) { Add-Result -Name "Hermes Agent" -Status "installed" -Detail "dry-run"; return }
        $installer = Invoke-WebRequest -Uri "https://hermes-agent.nousresearch.com/install.ps1" -UseBasicParsing
        & ([scriptblock]::Create($installer.Content)) -NonInteractive
        if (Test-AppCommand "hermes") {
            Write-Ok "Hermes Agent ready"
            Add-Result -Name "Hermes Agent" -Status "installed" -Detail "official installer"
        } else {
            Write-WarnLine "Installer finished; open a new terminal so PATH refreshes"
            Add-Result -Name "Hermes Agent" -Status "installed" -Detail "open a new terminal"
        }
    } catch {
        Write-Fail $_.Exception.Message
        Add-Result -Name "Hermes Agent" -Status "failed" -Detail $_.Exception.Message
    }
}

function Install-HermesIde {
    param([string]$MachineArch)
    if ($SkipHermesIde) { Add-Result -Name "Hermes IDE" -Status "skipped" -Detail "flag"; return }
    $existing = @(
        "$env:LOCALAPPDATA\HERMES IDE\HERMES IDE.exe",
        "$env:LOCALAPPDATA\Programs\HERMES IDE\HERMES IDE.exe",
        "${env:ProgramFiles}\HERMES IDE\HERMES IDE.exe"
    ) | Where-Object { Test-Path $_ }
    if ($existing) {
        Write-Ok "Hermes IDE already installed"
        Add-Result -Name "Hermes IDE" -Status "already" -Detail $existing[0]
        return
    }
    Write-Host ""
    Write-Host "  HERMES IDE" -ForegroundColor White
    try {
        if (Invoke-WingetInstall -Id "Hermes.IDE" -DisplayName "Hermes IDE") {
            Add-Result -Name "Hermes IDE" -Status "installed" -Detail "winget"
            Write-Ok "Hermes IDE via winget"
            return
        }
        $pattern = if ($MachineArch -eq "arm64") {
            @("*arm64-setup.exe", "*aarch64*setup.exe")
        } else {
            @("*x64-setup.exe", "*x86_64*setup.exe")
        }
        $asset = Get-GitHubLatestAsset -Owner "hermes-hq" -Repo "hermes-ide" -NamePatterns $pattern
        $out = Join-Path $WorkDir $asset.Name
        Save-Url -Url $asset.Url -Destination $out
        $code = Invoke-SetupExe -Path $out -Arguments @("/S")
        if ($code -eq 0) {
            Write-Ok "Hermes IDE $($asset.Tag)"
            Add-Result -Name "Hermes IDE" -Status "installed" -Detail $asset.Tag
        } else {
            Write-WarnLine "Silent install returned $code — launching interactive setup"
            if (-not $DryRun) { Start-Process -FilePath $out | Out-Null }
            Add-Result -Name "Hermes IDE" -Status "installed" -Detail "interactive setup launched"
        }
    } catch {
        Write-Fail $_.Exception.Message
        Add-Result -Name "Hermes IDE" -Status "failed" -Detail $_.Exception.Message
    }
}

function Install-ZCode {
    param([string]$MachineArch)
    if ($SkipZCode) { Add-Result -Name "ZCode" -Status "skipped" -Detail "flag"; return }
    $existing = @(
        "$env:LOCALAPPDATA\Programs\ZCode\ZCode.exe",
        "${env:ProgramFiles}\ZCode\ZCode.exe",
        "$env:LOCALAPPDATA\ZCode\ZCode.exe"
    ) | Where-Object { Test-Path $_ }
    if ($existing) {
        Write-Ok "ZCode already installed"
        Add-Result -Name "ZCode" -Status "already" -Detail $existing[0]
        return
    }
    Write-Host ""
    Write-Host "  ZCODE" -ForegroundColor White
    try {
        $patterns = if ($MachineArch -eq "arm64") {
            @("*win-arm64.exe", "*win-arm64.msi", "*win-x64.exe")
        } else {
            @("*win-x64.exe", "*win-x64.msi")
        }
        $asset = Get-GitHubLatestAsset -Owner "zai-org" -Repo "ZCode" -NamePatterns $patterns
        $out = Join-Path $WorkDir $asset.Name
        Save-Url -Url $asset.Url -Destination $out
        $code = Invoke-SetupExe -Path $out -Arguments @("/S")
        if ($code -eq 0) {
            Write-Ok "ZCode $($asset.Tag)"
            Add-Result -Name "ZCode" -Status "installed" -Detail $asset.Tag
        } else {
            Write-WarnLine "Silent install returned $code — launching interactive setup"
            if (-not $DryRun) { Start-Process -FilePath $out | Out-Null }
            Add-Result -Name "ZCode" -Status "installed" -Detail "interactive setup launched"
        }
    } catch {
        Write-Fail $_.Exception.Message
        Write-WarnLine "Manual download: https://zcode.z.ai/en/docs/install"
        Add-Result -Name "ZCode" -Status "failed" -Detail $_.Exception.Message
    }
}

function Install-Antigravity {
    param([string]$MachineArch)
    if ($SkipAntigravity) { Add-Result -Name "Antigravity" -Status "skipped" -Detail "flag"; return }
    Write-Host ""
    Write-Host "  ANTIGRAVITY" -ForegroundColor White

    $desktopOk = $false
    if (Invoke-WingetInstall -Id "Google.Antigravity" -DisplayName "Antigravity") {
        Write-Ok "Antigravity desktop via winget"
        Add-Result -Name "Antigravity" -Status "installed" -Detail "winget Google.Antigravity"
        $desktopOk = $true
    }

    if (-not $desktopOk) {
        try {
            $exeName = if ($MachineArch -eq "arm64") { "Antigravity-arm64.exe" } else { "Antigravity-x64.exe" }
            $page = Invoke-WebRequest -Uri "https://antigravity.google/download" -UseBasicParsing
            $hrefs = @()
            if ($page.Links) { $hrefs = @($page.Links | ForEach-Object { $_.href }) }
            $match = $hrefs | Where-Object {
                $_ -and ($_ -match [regex]::Escape($exeName) -or $_ -match "windows-$MachineArch" -or $_ -match "windows-x64")
            } | Select-Object -First 1
            if ($match) {
                if ($match -notmatch "^https?://") {
                    $match = [Uri]::new([Uri]"https://antigravity.google/download", $match).AbsoluteUri
                }
                $out = Join-Path $WorkDir $exeName
                Save-Url -Url $match -Destination $out
                $code = Invoke-SetupExe -Path $out -Arguments @("/S")
                if ($code -ne 0 -and -not $DryRun) { Start-Process -FilePath $out | Out-Null }
                Add-Result -Name "Antigravity" -Status "installed" -Detail "direct download"
                $desktopOk = $true
            }
        } catch { Write-WarnLine $_.Exception.Message }
    }

    if (-not $desktopOk) {
        Write-WarnLine "Opening official download page for Antigravity desktop"
        if (-not $DryRun) { Start-Process "https://antigravity.google/download" | Out-Null }
        Add-Result -Name "Antigravity" -Status "skipped" -Detail "opened antigravity.google/download"
    }

    if (-not $SkipAntigravityCli) {
        if (Test-AppCommand "agy" -or Test-AppCommand "antigravity") {
            Write-Ok "Antigravity CLI already on PATH"
            Add-Result -Name "Antigravity CLI" -Status "already"
        } elseif (Invoke-WingetInstall -Id "Google.AntigravityCLI" -DisplayName "Antigravity CLI") {
            Write-Ok "Antigravity CLI via winget"
            Add-Result -Name "Antigravity CLI" -Status "installed" -Detail "winget"
        } else {
            try {
                Write-Step "Official CLI installer  antigravity.google/cli/install.ps1"
                if (-not $DryRun) {
                    $cli = Invoke-WebRequest -Uri "https://antigravity.google/cli/install.ps1" -UseBasicParsing
                    Invoke-Expression $cli.Content
                }
                Add-Result -Name "Antigravity CLI" -Status "installed" -Detail "official script"
                Write-Ok "Antigravity CLI"
            } catch {
                Write-Fail $_.Exception.Message
                Add-Result -Name "Antigravity CLI" -Status "failed" -Detail $_.Exception.Message
            }
        }
    }

    if (-not $SkipAntigravityIde) {
        if (Invoke-WingetInstall -Id "Google.AntigravityIDE" -DisplayName "Antigravity IDE") {
            Write-Ok "Antigravity IDE via winget"
            Add-Result -Name "Antigravity IDE" -Status "installed" -Detail "winget"
        } else {
            Add-Result -Name "Antigravity IDE" -Status "skipped" -Detail "optional"
        }
    }
}

function Install-ClaudeCode {
    if ($SkipClaudeCode) { Add-Result -Name "Claude Code" -Status "skipped" -Detail "flag"; return }

    Write-Host ""
    Write-Host "  CLAUDE CODE" -ForegroundColor White

    if (-not $SkipGit -and -not (Test-AppCommand "git")) {
        if (Invoke-WingetInstall -Id "Git.Git" -DisplayName "Git") {
            Write-Ok "Git for Windows (needed by Claude Code)"
            Add-Result -Name "Git" -Status "installed" -Detail "winget Git.Git"
        } else {
            Write-WarnLine "Git not installed. Claude Code will use PowerShell as its shell."
            Add-Result -Name "Git" -Status "skipped" -Detail "winget unavailable"
        }
    } elseif (-not $SkipGit -and (Test-AppCommand "git")) {
        Add-Result -Name "Git" -Status "already"
    }

    if (Test-AppCommand "claude") {
        Write-Ok "Claude Code already on PATH"
        Add-Result -Name "Claude Code" -Status "already" -Detail (Get-Command claude).Source
        return
    }

    try {
        if (Invoke-WingetInstall -Id "Anthropic.ClaudeCode" -DisplayName "Claude Code") {
            Write-Ok "Claude Code via winget"
            Add-Result -Name "Claude Code" -Status "installed" -Detail "winget Anthropic.ClaudeCode"
            return
        }
        Write-Step "Official installer  claude.ai/install.ps1"
        if ($DryRun) { Add-Result -Name "Claude Code" -Status "installed" -Detail "dry-run"; return }
        $installer = Invoke-WebRequest -Uri "https://claude.ai/install.ps1" -UseBasicParsing
        Invoke-Expression $installer.Content
        if (Test-AppCommand "claude") {
            Write-Ok "Claude Code ready"
            Add-Result -Name "Claude Code" -Status "installed" -Detail "official installer"
        } else {
            Write-WarnLine "Installer finished; open a new terminal so PATH refreshes"
            Add-Result -Name "Claude Code" -Status "installed" -Detail "open a new terminal"
        }
    } catch {
        Write-Fail $_.Exception.Message
        Write-WarnLine "Manual: irm https://claude.ai/install.ps1 | iex"
        Add-Result -Name "Claude Code" -Status "failed" -Detail $_.Exception.Message
    }
}

function Write-Summary {
    Write-Host ""
    Write-Host "  SUMMARY" -ForegroundColor White
    Write-Host "  -------" -ForegroundColor DarkGray
    foreach ($row in $Results) {
        $mark = switch ($row.Status) {
            "installed" { "OK" }
            "already" { ".." }
            "skipped" { "--" }
            "failed" { "X " }
        }
        $color = switch ($row.Status) {
            "installed" { "Green" }
            "already" { "DarkGray" }
            "skipped" { "DarkGray" }
            "failed" { "Red" }
        }
        $line = "  $mark  $($row.Name.PadRight(18)) $($row.Status)"
        if ($row.Detail) { $line += "  $($row.Detail)" }
        Write-Host $line -ForegroundColor $color
    }
    Write-Host ""
    Write-Host "  Open a new terminal, then:" -ForegroundColor Gray
    Write-Host "    hermes --version" -ForegroundColor White
    Write-Host "    claude --version" -ForegroundColor White
    Write-Host ""
}

Write-Banner
$machineArch = Get-MachineArch
Write-Step "Windows $([Environment]::OSVersion.VersionString)"
Write-Step "Architecture $machineArch"
if ($DryRun) { Write-WarnLine "Dry run — no installers will execute" }

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

Install-HermesAgent
Install-HermesIde -MachineArch $machineArch
Install-ZCode -MachineArch $machineArch
Install-Antigravity -MachineArch $machineArch
Install-ClaudeCode

Write-Summary

$failed = @($Results | Where-Object { $_.Status -eq "failed" })
if ($failed.Count -gt 0) { exit 1 }
exit 0
