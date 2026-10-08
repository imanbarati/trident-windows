function Detect-TridentPackage {
  param([hashtable]$Pkg)
  $id = $Pkg.Id
  $detail = ''
  $status = 'missing'
  switch ($Pkg.Kind) {
    'ps1-script' {
      $v = $null
      if ($Pkg.Cmd) { $v = Get-CommandVersion -Cmd $Pkg.Cmd -VerArgs $Pkg.VerArgs }
      if ($v) { $status = 'installed'; $detail = $v } else { try { $c = Get-Command $Pkg.Cmd -ErrorAction SilentlyContinue; if ($c) { $status='installed'; $detail=$c.Source } } catch {} }
    }
    'winget' {
      $wg = Get-Command winget -ErrorAction SilentlyContinue
      if ($null -eq $wg) { $status = 'unknown'; $detail = 'winget not found' }
      else {
        try {
          $o = & winget list --id $Pkg.WingetId --exact 2>&1 | Out-String
          if ($o -match [regex]::Escape($Pkg.WingetId)) { $status = 'installed'; $detail = $Pkg.WingetId }
        } catch { $status = 'unknown'; $detail = $_.Exception.Message }
      }
      if ($status -eq 'missing' -and $Pkg.Cmd) {
        $v = Get-CommandVersion -Cmd $Pkg.Cmd -VerArgs '--version'
        if ($v) { $status = 'installed'; $detail = $v }
      }
    }
    'github-zip' {
      $dst = Join-Path $env:USERPROFILE '.zeroclaw\bin\zeroclaw.exe'
      if (Test-Path $dst) { $status = 'installed'; $detail = $dst }
      else {
        $v = Get-CommandVersion -Cmd 'zeroclaw' -VerArgs '--version'
        if ($v) { $status = 'installed'; $detail = $v }
        elseif (Get-Command zeroclaw -ErrorAction SilentlyContinue) { $status='installed'; $detail=(Get-Command zeroclaw).Source }
      }
    }
    'github-nsis' {
      $found = $false
      $roots = @((Join-Path $env:LOCALAPPDATA 'Programs'), 'C:\Program Files', 'C:\Program Files (x86)')
      foreach ($exeName in $Pkg.ExeNames) {
        foreach ($r in $roots) {
          if (-not (Test-Path $r)) { continue }
          $hit = Get-ChildItem -Path $r -Recurse -Depth 3 -Filter ($exeName + '.exe') -ErrorAction SilentlyContinue | Select-Object -First 1
          if ($hit) { $status='installed'; $detail=$hit.FullName; $found=$true; break }
        }
        if ($found) { break }
      }
      if (-not $found) {
        $wg = Get-Command winget -ErrorAction SilentlyContinue
        if ($wg) {
          foreach ($exeName in $Pkg.ExeNames) {
            try {
              $o = & winget list --name $exeName 2>&1 | Out-String
              if ($o -match [regex]::Escape($exeName)) { $status='installed'; $detail="winget: $exeName"; $found=$true; break }
            } catch {}
          }
        }
      }
      if (-not $found) { $status = 'missing'; $detail = '' }
    }
  }
  return [pscustomobject]@{ Id=$id; Name=$Pkg.Name; Status=$status; Detail=$detail }
}

function Save-TridentUrl {
  param([string]$Url, [string]$Destination, [switch]$Dry)
  Write-TStep "GET $Url"
  if ($Dry) { Write-TWarn "DRY: would download -> $Destination"; return }
  $dir = Split-Path $Destination -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  try {
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
  } catch {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($Url, $Destination)
  }
}

function Get-GitHubLatestAsset {
  param([string]$Owner, [string]$Repo, [string[]]$NamePatterns, [switch]$Dry)
  $api = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
  Write-TStep "GitHub latest: $Owner/$Repo"
  if ($Dry) { Write-TWarn "DRY: would query $api for $($NamePatterns -join ' | ')"; return [pscustomobject]@{ Url='https://example.invalid/dry-run.exe'; Tag='dry-run'; Name='dry-run.exe' } }
  $rel = Invoke-RestMethod -Uri $api -ErrorAction Stop
  foreach ($pat in $NamePatterns) {
    $a = @($rel.assets | Where-Object { $_.name -like $pat })
    if ($a.Count -gt 0) { return [pscustomobject]@{ Url=$a[0].browser_download_url; Tag=$rel.tag_name; Name=$a[0].name } }
  }
  $names = ($rel.assets | ForEach-Object { $_.name }) -join ', '
  throw "No asset matching ($($NamePatterns -join ' | ')). Available: $names"
}

function Add-TridentUserPath {
  param([string]$Dir, [switch]$Dry)
  if ($Dry) { Write-TWarn "DRY: would add to User PATH: $Dir"; return }
  $cur = [Environment]::GetEnvironmentVariable('Path','User')
  if ($cur -split ';' | Where-Object { $_ -eq $Dir }) { return }
  [Environment]::SetEnvironmentVariable('Path', (($cur.TrimEnd(';') + ';' + $Dir)), 'User')
  $env:Path = $env:Path.TrimEnd(';') + ';' + $Dir
  try {
    $sig = '[DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);'
    $t = Add-Type -MemberDefinition $sig -Name Win32Trident -Namespace Trident -PassThru -ErrorAction Stop
    $r = [UIntPtr]::Zero
    $t::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r) | Out-Null
  } catch {}
}
