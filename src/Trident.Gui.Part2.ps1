function Get-GuiArch {
  $sel = $archBox.SelectedItem
  if ($sel -ne $null) { return $sel.Content }
  return 'auto'
}
function Get-GuiSelectedIds {
  $ids = @()
  foreach ($p in $script:Catalog) {
    $cb = $script:checks[$p.Id]
    if ($cb -ne $null -and $cb.IsChecked) { $ids += $p.Id }
  }
  return $ids
}
function Get-GuiCliCommand {
  $flags = @()
  foreach ($p in $script:Catalog) {
    $cb = $script:checks[$p.Id]
    if ($cb -ne $null -and $cb.IsChecked) { $flags += $p.Flag }
  }
  $arch = Get-GuiArch
  $list = $flags -join ','
  if (-not $list) { return '# tick at least one package' }
  $dry = if ($dryBox.IsChecked) { ' -DryRun' } else { '' }
  return "powershell -NoProfile -ExecutionPolicy Bypass -File src\Trident.Cli.ps1 -Only $list -Arch $arch$dry"
}
function Set-Pill {
  param([string]$Id, [string]$Status, [string]$Detail = '')
  $pill = $script:pills[$Id]
  if ($pill -eq $null) { return }
  if ($Detail) { $txt = $Status + ' - ' + $Detail } else { $txt = $Status }
  if ($Status -eq 'installed') { $color = '#4CAF50' }
  elseif ($Status -eq 'missing') { $color = '#9AA3B2' }
  elseif ($Status -eq 'unknown') { $color = '#FFC107' }
  elseif ($Status -eq 'failed') { $color = '#F44336' }
  else { $color = '#9AA3B2' }
  try {
    $win.Dispatcher.Invoke([action]{
      $pill.Text = $txt
      $pill.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($color)
    })
  } catch {}
}
function Gui-Detect {
  $arch = Get-TridentArch -Wanted (Get-GuiArch)
  Write-TStep "Detect (arch=$arch)"
  foreach ($p in $script:Catalog) {
    $d = Detect-TridentPackage -Pkg $p
    Set-Pill -Id $p.Id -Status $d.Status -Detail $d.Detail
    $msg = "[$($d.Status)] $($p.Name) $($d.Detail)"
    if ($d.Status -eq 'installed') { Write-TOk $msg } else { Write-TStep $msg }
  }
  Write-TStep "Log: $($script:LogFile)"
}
function Gui-Install {
  $ids = Get-GuiSelectedIds
  if ($ids.Count -eq 0) { Write-TFail 'Select at least one package.'; return }
  $arch = Get-TridentArch -Wanted (Get-GuiArch)
  $dry = [bool]$dryBox.IsChecked
  $script:Wanted = $ids
  $total = $ids.Count; $i = 0
  Write-TStep "Install start: $($ids -join ', ') arch=$arch dry=$dry"
  foreach ($p in $script:Catalog) {
    if ($ids -notcontains $p.Id) { continue }
    $i++
    try { $win.Dispatcher.Invoke([action]{ $prog.Value = ($i / $total) * 100 }) } catch {}
    $pre = Detect-TridentPackage -Pkg $p
    if ($pre.Status -eq 'installed' -and -not $dry) {
      Write-TOk "$($p.Name) already installed: $($pre.Detail)"
      Set-Pill -Id $p.Id -Status 'installed' -Detail $pre.Detail
      continue
    }
    Set-Pill -Id $p.Id -Status 'working' -Detail '...'
    $r = Install-TridentPackage -Pkg $p -MachineArch $arch -Dry:$dry
    if ($r.Status -eq 'installed') { Write-TOk "$($r.Name) done"; Set-Pill -Id $p.Id -Status 'installed' -Detail $r.Detail }
    elseif ($r.Status -eq 'skipped') { Write-TWarn "$($r.Name) skipped (dry-run)"; Set-Pill -Id $p.Id -Status 'missing' -Detail 'dry-run' }
    else { Write-TFail "$($r.Name): $($r.Detail)"; Set-Pill -Id $p.Id -Status 'failed' -Detail $r.Detail }
  }
  try { $win.Dispatcher.Invoke([action]{ $prog.Value = 100 }) } catch {}
  Write-TStep "Done. Full log: $($script:LogFile)"
  Write-TWarn 'Open a NEW terminal to verify PATH-based tools.'
}
function Gui-Verify {
  $ids = Get-GuiSelectedIds
  if ($ids.Count -eq 0) { Write-TFail 'Select at least one package.'; return }
  foreach ($p in $script:Catalog) {
    if ($ids -notcontains $p.Id) { continue }
    $d = Detect-TridentPackage -Pkg $p
    if ($d.Status -eq 'installed') { Write-TOk "verified $($p.Name): $($d.Detail)"; Set-Pill -Id $p.Id -Status 'installed' -Detail $d.Detail }
    else { Write-TFail "$($p.Name) NOT found"; Set-Pill -Id $p.Id -Status 'failed' -Detail $d.Detail }
  }
}
($win.FindName('DetectBtn')).Add_Click({ Gui-Detect })
($win.FindName('InstallBtn')).Add_Click({ Gui-Install })
($win.FindName('VerifyBtn')).Add_Click({ Gui-Verify })
($win.FindName('CopyBtn')).Add_Click({
  $cmd = Get-GuiCliCommand
  try { [System.Windows.Clipboard]::SetText($cmd); Write-TOk 'CLI command copied.' } catch { Write-TWarn $cmd }
  Write-TridentLog $cmd 'CMD'
})
($win.FindName('LogsBtn')).Add_Click({
  try { Start-Process (Split-Path $script:LogFile -Parent) } catch { Write-TWarn $_.Exception.Message }
})
Write-TridentLog "Trident GUI $($script:TridentVersion) ready. Log=$($script:LogFile)" 'INFO'
Write-TStep 'Tip: keep Dry run ON for a safe preview, then uncheck it to install.'
$win.ShowDialog() | Out-Null
