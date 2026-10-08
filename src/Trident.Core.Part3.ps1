function Install-TridentPackage {
  param([hashtable]$Pkg, [string]$MachineArch = 'x64', [switch]$Dry)
  $name = $Pkg.Name
  try {
    switch ($Pkg.Kind) {
      'ps1-script' {
        Write-Host ''; Write-Host "  $($name.ToUpper())" -ForegroundColor White
        $tmp = Join-Path $env:TEMP ('trident-' + $Pkg.Flag + '.ps1')
        Save-TridentUrl -Url $Pkg.Url -Destination $tmp -Dry:$Dry
        if ($Dry) { return [pscustomobject]@{ Name=$name; Status='skipped'; Detail='dry-run' } }
        $extra = ''
        if ($Pkg.Flag -eq 'hermes') { $extra = ' -NonInteractive' }
        $cmd = "& '$tmp'$extra"
        Write-TStep "Running official installer: $($Pkg.Url)"
        Write-TridentLog "EXEC: $cmd" 'EXEC'
        $out = powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1 | Out-String
        Write-TridentLog $out 'INSTALLER'
        return [pscustomobject]@{ Name=$name; Status='installed'; Detail=$Pkg.Url }
      }
      'winget' {
        Write-Host ''; Write-Host "  $($name.ToUpper())" -ForegroundColor White
        $wg = Get-Command winget -ErrorAction SilentlyContinue
        if ($null -eq $wg) { throw 'winget not found. Install App Installer from Microsoft Store.' }
        $cmd = "winget install -e --id $($Pkg.WingetId) --silent --accept-package-agreements --accept-source-agreements"
        Write-TStep $cmd
        if ($Dry) { return [pscustomobject]@{ Name=$name; Status='skipped'; Detail='dry-run' } }
        Write-TridentLog "EXEC: $cmd" 'EXEC'
        $out = & winget install -e --id $Pkg.WingetId --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
        Write-TridentLog $out 'WINGET'
        if ($LASTEXITCODE -ne 0) { throw "winget exit ${LASTEXITCODE}: $out" }
        return [pscustomobject]@{ Name=$name; Status='installed'; Detail=$Pkg.WingetId }
      }
      'github-zip' {
        Write-Host ''; Write-Host '  ZEROCLAW' -ForegroundColor White
        $patterns = if ($MachineArch -eq 'arm64') { @('zeroclaw-aarch64-pc-windows-msvc.zip','zeroclaw-x86_64-pc-windows-msvc.zip') } else { @('zeroclaw-x86_64-pc-windows-msvc.zip') }
        $asset = Get-GitHubLatestAsset -Owner $Pkg.Owner -Repo $Pkg.Repo -NamePatterns $patterns -Dry:$Dry
        $zip = Join-Path $env:TEMP 'zeroclaw-trident.zip'
        Save-TridentUrl -Url $asset.Url -Destination $zip -Dry:$Dry
        $dst = Join-Path $env:USERPROFILE '.zeroclaw\bin'
        if ($Dry) { return [pscustomobject]@{ Name=$name; Status='skipped'; Detail='dry-run' } }
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Expand-Archive -Force -Path $zip -DestinationPath $dst
        Add-TridentUserPath -Dir $dst
        Write-TStep "Run 'zeroclaw onboard' in a new terminal to pick a provider"
        return [pscustomobject]@{ Name=$name; Status='installed'; Detail=$asset.Tag }
      }
      'github-nsis' {
        Write-Host ''; Write-Host "  $($name.ToUpper())" -ForegroundColor White
        $asset = Get-GitHubLatestAsset -Owner $Pkg.Owner -Repo $Pkg.Repo -NamePatterns $Pkg.Patterns -Dry:$Dry
        $exe = Join-Path $env:TEMP ('trident-' + $Pkg.Flag + '-' + $asset.Name)
        Save-TridentUrl -Url $asset.Url -Destination $exe -Dry:$Dry
        if ($Dry) { return [pscustomobject]@{ Name=$name; Status='skipped'; Detail='dry-run' } }
        foreach ($silentArgs in @('/S','/VERYSILENT /SUPPRESSMSGBOXES /NORESTART','/quiet /norestart','/silent')) {
          $stepMsg = 'Executing installer ' + $asset.Name + ' with args: ' + $silentArgs
          Write-TStep $stepMsg
          $execMsg = $exe + ' ' + $silentArgs
          Write-TridentLog $execMsg 'EXEC'
          $p = Start-Process -FilePath $exe -ArgumentList $silentArgs -Wait -PassThru
          $exitMsg = 'exit=' + $p.ExitCode
          Write-TridentLog $exitMsg 'EXEC'
          if ($p.ExitCode -eq 0) { break }
          $retryMsg = 'exit=' + $p.ExitCode + ' with ' + $silentArgs + ' - trying next fallback'
          Write-TWarn $retryMsg
        }
        return [pscustomobject]@{ Name=$name; Status='installed'; Detail=$asset.Tag }
      }
    }
  } catch {
    return [pscustomobject]@{ Name=$name; Status='failed'; Detail=$_.Exception.Message }
  }
  return [pscustomobject]@{ Name=$name; Status='failed'; Detail='unknown kind' }
}

function Verify-TridentInstall {
  param([string[]]$WantedIds)
  $rows = @()
  foreach ($p in $script:Catalog) {
    if ($WantedIds -notcontains $p.Id) { continue }
    $d = Detect-TridentPackage -Pkg $p
    if ($d.Status -eq 'installed') { $vs = 'installed' } else { $vs = 'failed' }
    $rows += [pscustomobject]@{ Name=$p.Name; Status=$vs; Detail=$d.Detail }
    $vmsg = $p.Name + ' verified: ' + $d.Detail
    $nmsg = $p.Name + ' NOT found after install'
    if ($vs -eq 'installed') { Write-TOk $vmsg } else { Write-TFail $nmsg }
  }
  return $rows
}

function Show-TridentSummary {
  param($Rows)
  Write-Host ''
  Write-Host '  SUMMARY' -ForegroundColor White
  $fmt = '  {0}  {1}  {2}  {3}'
  foreach ($r in $Rows) {
    if ($r.Status -eq 'installed') { $mark = 'OK' }
    elseif ($r.Status -eq 'already') { $mark = '..' }
    elseif ($r.Status -eq 'skipped') { $mark = '--' }
    elseif ($r.Status -eq 'failed') { $mark = 'XX' }
    else { $mark = $r.Status }
    $nm = [string]$r.Name
    $st = [string]$r.Status
    $dt = [string]$r.Detail
    Write-Host ($fmt -f $mark, $nm.PadRight(16), $st.PadRight(9), $dt)
  }
  Write-Host ''
}
