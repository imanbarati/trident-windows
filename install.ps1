#Requires -Version 5.1
<#
.SYNOPSIS
  Trident — selective Windows installer for Hermes, ZCode, Antigravity, Claude Code, and ZeroClaw.

.DESCRIPTION
  Downloads and installs official Windows builds only. Tick packages with -Only
  (or $env:TRIDENT_ONLY). Unlisted packages are skipped.

    hermes          Hermes Agent     https://hermes-agent.nousresearch.com
    hermes-ide      Hermes IDE       https://github.com/hermes-hq/hermes-ide
    zcode           ZCode            https://github.com/zai-org/ZCode
    antigravity     Antigravity      https://antigravity.google
    antigravity-cli Antigravity CLI
    claude          Claude Code      https://claude.ai/install.ps1
    zeroclaw        ZeroClaw         https://github.com/zeroclaw-labs/zeroclaw

.EXAMPLE
  irm https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1 | iex

.EXAMPLE
  & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1'))) -Only claude,zeroclaw

.EXAMPLE
  $env:TRIDENT_ONLY = 'hermes,zcode,zeroclaw'
  irm https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1 | iex

.EXAMPLE
  .\install.ps1 -Only claude,zeroclaw -Arch x64
#>
[CmdletBinding()]
param(
    [ValidateSet("auto", "x64", "arm64")]
    [string]$Arch = "auto",

    [string[]]$Only = @(),

    [switch]$SkipHermesAgent,
    [switch]$SkipHermesIde,
    [switch]$SkipZCode,
    [switch]$SkipAntigravity,
    [switch]$SkipAntigravityCli,
    [switch]$SkipClaude,
    [switch]$SkipZeroClaw,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$TridentVersion = "1.1.0"
$WorkDir = Join-Path $env:TEMP "trident-windows"
$Results = New-Object System.Collections.Generic.List[object]

$CatalogIds = @(
    "hermes-agent",
    "hermes-ide",
    "zcode",
    "antigravity",
    "antigravity-cli",
    "claude",
    "zeroclaw"
)

$AliasMap = @{
    "hermes-agent"      = "hermes-agent"
    "hermes"            = "hermes-agent"
    "agent"             = "hermes-agent"
    "hermes-ide"        = "hermes-ide"
    "ide"               = "hermes-ide"
    "zcode"             = "zcode"
    "antigravity"       = "antigravity"
    "agy"               = "antigravity"
    "antigravity-cli"   = "antigravity-cli"
    "agy-cli"           = "antigravity-cli"
    "claude"            = "claude"
    "claude-code"       = "claude"
    "zeroclaw"          = "zeroclaw"
    "claw"              = "zeroclaw"
    "zero-claw"         = "zeroclaw"
}

function Write-Banner {
    Write-Host ""
    Write-Host "  TRIDENT  $TridentVersion" -ForegroundColor White
    Write-Host "  Hermes  ·  ZCode  ·  Antigravity  ·  Claude  ·  ZeroClaw" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host ("  →  " + $Message) -ForegroundColor Gray
}

function Write-Ok {
    param([string]$Message)
    Write-Host ("  ✓  " + $Message) -ForegroundColor Green
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host ("  !  " + $Message) -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host ("  ×  " + $Message) -ForegroundColor Red
}

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

function Test-Winget {
    return [bool](Get-Command winget -ErrorAction SilentlyContinue)
}

function Add-UserPath {
    param([Parameter(Mandatory = $true)][string]$Directory)
    if ($DryRun) { return }
    $dir = $Directory.TrimEnd("\")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) { $userPath = "" }
    $parts = @($userPath -split ";" | ForEach-Object { $_.TrimEnd("\") } | Where-Object { $_ })
    if ($parts -notcontains $dir) {
        $joined = if ($userPath) { "$dir;$userPath" } else { $dir }
        [Environment]::SetEnvironmentVariable("Path", $joined, "User")
    }
    if (($env:Path -split ";" | ForEach-Object { $_.TrimEnd("\") }) -notcontains $dir) {
        $env:Path = "$dir;$env:Path"
    }
}

function Invoke-WingetInstall {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$DisplayName
    )
    if (-not (Test-Winget)) { return $false }
    Write-Step "winget install $Id"
    if ($DryRun) { return $true }
    $args = @(
        "install", "-e", "--id", $Id,
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
    )
    $p = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -eq 0 -or $p.ExitCode -eq -1978335189) {
        return $true
    }
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
    if (-not (Test-Path $Destination)) {
        throw "Download failed: $Url"
    }
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

function Resolve-Wanted {
    $tokens = New-Object System.Collections.Generic.List[string]
    foreach ($item in @($Only)) {
        if ($item) {
            foreach ($piece in ($item -split "[,\s]+")) {
                if ($piece) { $tokens.Add($piece.Trim()) | Out-Null }
            }
        }
    }
    if ($env:TRIDENT_ONLY) {
        foreach ($piece in ($env:TRIDENT_ONLY -split "[,\s]+")) {
            if ($piece) { $tokens.Add($piece.Trim()) | Out-Null }
        }
    }

    $wanted = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    if ($tokens.Count -eq 0) {
        foreach ($id in $CatalogIds) { [void]$wanted.Add($id) }
    } else {
        foreach ($token in $tokens) {
            $key = $token.ToLowerInvariant()
            if ($AliasMap.ContainsKey($key)) {
                [void]$wanted.Add($AliasMap[$key])
            } else {
                Write-WarnLine "Unknown package '$token' — ignored"
            }
        }
    }

    if ($SkipHermesAgent) { [void]$wanted.Remove("hermes-agent") }
    if ($SkipHermesIde) { [void]$wanted.Remove("hermes-ide") }
    if ($SkipZCode) { [void]$wanted.Remove("zcode") }
    if ($SkipAntigravity) { [void]$wanted.Remove("antigravity") }
    if ($SkipAntigravityCli) { [void]$wanted.Remove("antigravity-cli") }
    if ($SkipClaude) { [void]$wanted.Remove("claude") }
    if ($SkipZeroClaw) { [void]$wanted.Remove("zeroclaw") }

    return $wanted
}

function Test-Wanted {
    param([string]$Id)
    return $script:Wanted.Contains($Id)
}

function Install-HermesAgent {
    if (-not (Test-Wanted "hermes-agent")) {
        Add-Result -Name "Hermes Agent" -Status "skipped" -Detail "not selected"
        return
    }
    if (Test-AppCommand "hermes") {
        Write-Ok "Hermes Agent already on PATH"
        Add-Result -Name "Hermes Agent" -Status "already" -Detail (Get-Command hermes).Source
        return
    }
    Write-Host ""
    Write-Host "  HERMES AGENT" -ForegroundColor White
    try {
        Write-Step "Official installer  hermes-agent.nousresearch.com"
        if ($DryRun) {
            Add-Result -Name "Hermes Agent" -Status "installed" -Detail "dry-run"
            return
        }
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
    if (-not (Test-Wanted "hermes-ide")) {
        Add-Result -Name "Hermes IDE" -Status "skipped" -Detail "not selected"
        return
    }
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
    if (-not (Test-Wanted "zcode")) {
        Add-Result -Name "ZCode" -Status "skipped" -Detail "not selected"
        return
    }
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
    if (-not (Test-Wanted "antigravity")) {
        Add-Result -Name "Antigravity" -Status "skipped" -Detail "not selected"
        return
    }
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
            if ($page.Links) {
                $hrefs = @($page.Links | ForEach-Object { $_.href })
            }
            $match = $hrefs | Where-Object { $_ -and ($_ -match [regex]::Escape($exeName) -or $_ -match "windows-$MachineArch" -or $_ -match "windows-x64") } | Select-Object -First 1
            if ($match) {
                if ($match -notmatch "^https?://") {
                    $match = [Uri]::new([Uri]"https://antigravity.google/download", $match).AbsoluteUri
                }
                $out = Join-Path $WorkDir $exeName
                Save-Url -Url $match -Destination $out
                $code = Invoke-SetupExe -Path $out -Arguments @("/S")
                if ($code -ne 0 -and -not $DryRun) {
                    Start-Process -FilePath $out | Out-Null
                }
                Add-Result -Name "Antigravity" -Status "installed" -Detail "direct download"
                $desktopOk = $true
            }
        } catch {
            Write-WarnLine $_.Exception.Message
        }
    }

    if (-not $desktopOk) {
        Write-WarnLine "Opening official download page for Antigravity desktop"
        if (-not $DryRun) { Start-Process "https://antigravity.google/download" | Out-Null }
        Add-Result -Name "Antigravity" -Status "skipped" -Detail "opened antigravity.google/download"
    }
}

function Install-AntigravityCli {
    if (-not (Test-Wanted "antigravity-cli")) {
        Add-Result -Name "Antigravity CLI" -Status "skipped" -Detail "not selected"
        return
    }
    if (Test-AppCommand "agy" -or Test-AppCommand "antigravity") {
        Write-Ok "Antigravity CLI already on PATH"
        Add-Result -Name "Antigravity CLI" -Status "already"
        return
    }
    Write-Host ""
    Write-Host "  ANTIGRAVITY CLI" -ForegroundColor White
    if (Invoke-WingetInstall -Id "Google.AntigravityCLI" -DisplayName "Antigravity CLI") {
        Write-Ok "Antigravity CLI via winget"
        Add-Result -Name "Antigravity CLI" -Status "installed" -Detail "winget"
        return
    }
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

function Install-GitIfNeeded {
    if (Test-AppCommand "git") { return }
    Write-Step "Git for Windows — used by Claude Code"
    if (Invoke-WingetInstall -Id "Git.Git" -DisplayName "Git") {
        Write-Ok "Git"
        Add-Result -Name "Git" -Status "installed" -Detail "dependency for Claude Code"
    } else {
        Write-WarnLine "Git not installed — Claude Code will use PowerShell as its shell"
        Add-Result -Name "Git" -Status "skipped" -Detail "optional for Claude Code"
    }
}

function Install-ClaudeCode {
    if (-not (Test-Wanted "claude")) {
        Add-Result -Name "Claude Code" -Status "skipped" -Detail "not selected"
        return
    }
    $claudeExe = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
    if ((Test-AppCommand "claude") -or (Test-Path $claudeExe)) {
        Write-Ok "Claude Code already installed"
        $detail = if (Test-AppCommand "claude") { (Get-Command claude).Source } else { $claudeExe }
        Add-Result -Name "Claude Code" -Status "already" -Detail $detail
        return
    }
    Write-Host ""
    Write-Host "  CLAUDE CODE" -ForegroundColor White
    try {
        Install-GitIfNeeded
        if (Invoke-WingetInstall -Id "Anthropic.ClaudeCode" -DisplayName "Claude Code") {
            Write-Ok "Claude Code via winget"
            Add-Result -Name "Claude Code" -Status "installed" -Detail "winget"
            return
        }
        Write-Step "Official installer  claude.ai/install.ps1"
        if ($DryRun) {
            Add-Result -Name "Claude Code" -Status "installed" -Detail "dry-run"
            return
        }
        $installer = Invoke-WebRequest -Uri "https://claude.ai/install.ps1" -UseBasicParsing
        & ([scriptblock]::Create($installer.Content))
        Add-UserPath (Join-Path $env:USERPROFILE ".local\bin")
        if ((Test-AppCommand "claude") -or (Test-Path $claudeExe)) {
            Write-Ok "Claude Code ready"
            Add-Result -Name "Claude Code" -Status "installed" -Detail "official installer"
        } else {
            Write-WarnLine "Installer finished; open a new terminal so PATH refreshes"
            Add-Result -Name "Claude Code" -Status "installed" -Detail "open a new terminal"
        }
    } catch {
        Write-Fail $_.Exception.Message
        Add-Result -Name "Claude Code" -Status "failed" -Detail $_.Exception.Message
    }
}

function Install-ZeroClaw {
    param([string]$MachineArch)
    if (-not (Test-Wanted "zeroclaw")) {
        Add-Result -Name "ZeroClaw" -Status "skipped" -Detail "not selected"
        return
    }
    $dst = Join-Path $env:USERPROFILE ".zeroclaw\bin"
    $exe = Join-Path $dst "zeroclaw.exe"
    if ((Test-AppCommand "zeroclaw") -or (Test-Path $exe)) {
        Write-Ok "ZeroClaw already installed"
        $detail = if (Test-Path $exe) { $exe } else { (Get-Command zeroclaw).Source }
        Add-Result -Name "ZeroClaw" -Status "already" -Detail $detail
        return
    }
    Write-Host ""
    Write-Host "  ZEROCLAW" -ForegroundColor White
    try {
        $patterns = if ($MachineArch -eq "arm64") {
            @("zeroclaw-aarch64-pc-windows-msvc.zip", "zeroclaw-x86_64-pc-windows-msvc.zip")
        } else {
            @("zeroclaw-x86_64-pc-windows-msvc.zip")
        }
        $asset = Get-GitHubLatestAsset -Owner "zeroclaw-labs" -Repo "zeroclaw" -NamePatterns $patterns
        $zip = Join-Path $env:TEMP "zeroclaw.zip"
        Save-Url -Url $asset.Url -Destination $zip
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force -Path $dst | Out-Null
            Expand-Archive -Force -Path $zip -DestinationPath $dst
        }
        Add-UserPath $dst
        Write-Ok "ZeroClaw $($asset.Tag)"
        Write-Step "Run 'zeroclaw quickstart' in a new terminal to pick a provider"
        Add-Result -Name "ZeroClaw" -Status "installed" -Detail $asset.Tag
    } catch {
        Write-Fail $_.Exception.Message
        Write-WarnLine "Manual install: https://github.com/zeroclaw-labs/zeroclaw"
        Add-Result -Name "ZeroClaw" -Status "failed" -Detail $_.Exception.Message
    }
}

function Write-Summary {
    Write-Host ""
    Write-Host "  SUMMARY" -ForegroundColor White
    Write-Host "  -------" -ForegroundColor DarkGray
    foreach ($row in $Results) {
        $mark = switch ($row.Status) {
            "installed" { "✓" }
            "already" { "·" }
            "skipped" { "–" }
            "failed" { "×" }
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
    if (Test-Wanted "hermes-agent") { Write-Host "    hermes --version" -ForegroundColor White }
    if (Test-Wanted "claude") { Write-Host "    claude --version" -ForegroundColor White }
    if (Test-Wanted "zeroclaw") { Write-Host "    zeroclaw --version" -ForegroundColor White }
    Write-Host ""
}

# --- main ---
Write-Banner
$machineArch = Get-MachineArch
$script:Wanted = Resolve-Wanted
Write-Step "Windows $([Environment]::OSVersion.VersionString)"
Write-Step "Architecture $machineArch"
$selectedNames = @($CatalogIds | Where-Object { Test-Wanted $_ })
Write-Step ("Selected  " + ($(if ($selectedNames) { $selectedNames -join ", " } else { "(none)" })))
if ($DryRun) { Write-WarnLine "Dry run — no installers will execute" }

if ($script:Wanted.Count -eq 0) {
    Write-Fail "Nothing selected. Pass -Only hermes,zcode,claude,zeroclaw (or omit -Only to install all)."
    exit 1
}

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

Install-HermesAgent
Install-HermesIde -MachineArch $machineArch
Install-ZCode -MachineArch $machineArch
Install-Antigravity -MachineArch $machineArch
Install-AntigravityCli
Install-ClaudeCode
Install-ZeroClaw -MachineArch $machineArch

Write-Summary

$failed = @($Results | Where-Object { $_.Status -eq "failed" })
if ($failed.Count -gt 0) { exit 1 }
exit 0
