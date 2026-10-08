# Trident MVP polished GUI part 1 — loads Core, builds WPF shell + package cards.
# (Dot-sourced by Trident.Gui.ps1 — no #Requires here on purpose.)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase | Out-Null

$here = Split-Path $MyInvocation.MyCommand.Path -Parent
. (Join-Path $here 'Trident.Core.ps1')
. (Join-Path $here 'Trident.Core.Part2.ps1')
. (Join-Path $here 'Trident.Core.Part3.ps1')

$script:Wanted = @($script:Catalog | ForEach-Object { $_.Id })
$script:GuiLogBox = $null

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Trident Setup — MVP" Height="640" Width="560" MinHeight="560" MinWidth="480"
        Background="#0F1115" WindowStartupLocation="CenterScreen">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="150"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0">
      <TextBlock Text="TRIDENT" FontSize="22" FontWeight="Bold" Foreground="White"/>
      <TextBlock Text="Selective installer — Hermes · ZCode · Antigravity · Claude · ZeroClaw" FontSize="12" Foreground="#9AA3B2"/>
      <TextBlock Text="Official sources only. Nothing bundled." FontSize="11" Foreground="#9AA3B2"/>
    </StackPanel>
    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,10,0,6" VerticalAlignment="Center">
      <TextBlock Text="Arch:" VerticalAlignment="Center" Margin="0,0,6,0" Foreground="#9AA3B2"/>
      <ComboBox Name="ArchBox" Width="110" SelectedIndex="0">
        <ComboBoxItem Content="auto"/>
        <ComboBoxItem Content="x64"/>
        <ComboBoxItem Content="arm64"/>
      </ComboBox>
      <CheckBox Name="DryBox" Content="Dry run" Margin="14,0,0,0" VerticalAlignment="Center" IsChecked="True" Foreground="White"/>
      <TextBlock Name="LogPathText" Text="log" FontSize="10" Margin="14,0,0,0" VerticalAlignment="Center" Foreground="#9AA3B2" TextWrapping="Wrap" Width="210"/>
    </StackPanel>
    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
      <StackPanel Name="PkgPanel"/>
    </ScrollViewer>
    <ProgressBar Grid.Row="3" Name="Prog" Height="10" Margin="0,8,0,4" Minimum="0" Maximum="100" Value="0"/>
    <TextBox Grid.Row="4" Name="LogBox" Background="#0A0D12" Foreground="#C9D1D9"
             FontFamily="Consolas" FontSize="11" IsReadOnly="True"
             VerticalScrollBarVisibility="Auto" AcceptsReturn="True"/>
    <WrapPanel Grid.Row="5" Margin="0,8,0,0">
      <Button Name="DetectBtn" Content="Detect" Margin="4" Padding="10,6"/>
      <Button Name="InstallBtn" Content="Install selected" Margin="4" Padding="10,6" Background="#2E7D32" Foreground="White"/>
      <Button Name="VerifyBtn" Content="Verify" Margin="4" Padding="10,6"/>
      <Button Name="CopyBtn" Content="Copy CLI command" Margin="4" Padding="10,6"/>
      <Button Name="LogsBtn" Content="Open logs" Margin="4" Padding="10,6"/>
    </WrapPanel>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [Windows.Markup.XamlReader]::Load($reader)

$archBox  = $win.FindName('ArchBox')
$dryBox   = $win.FindName('DryBox')
$pkgPanel = $win.FindName('PkgPanel')
$prog     = $win.FindName('Prog')
$logBox   = $win.FindName('LogBox')
$logPathT = $win.FindName('LogPathText')
$script:GuiLogBox = $logBox
$logPathT.Text = "log: $($script:LogFile)"

$script:checks = @{}
$script:pills  = @{}

foreach ($p in $script:Catalog) {
  $border = New-Object System.Windows.Controls.Border
  $border.Margin = '0,4,0,4'
  $border.Padding = '10,6,10,6'
  $border.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#161B24')
  $border.CornerRadius = '8'
  $grid = New-Object System.Windows.Controls.Grid
  $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = '1*'
  $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = 'Auto'
  $grid.ColumnDefinitions.Add($c1); $grid.ColumnDefinitions.Add($c2)
  $left = New-Object System.Windows.Controls.StackPanel
  $cb = New-Object System.Windows.Controls.CheckBox
  $cb.Content = $p.Name + '  (' + $p.Flag + ')'
  $cb.IsChecked = $true
  $cb.FontWeight = 'SemiBold'
  $cb.Foreground = [System.Windows.Media.Brushes]::White
  $sub = New-Object System.Windows.Controls.TextBlock
  $sub.Text = $p.Maker + ' - ' + $p.Desc
  $sub.FontSize = 11
  $sub.TextWrapping = 'Wrap'
  $sub.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#9AA3B2')
  $left.Children.Add($cb) | Out-Null
  $left.Children.Add($sub) | Out-Null
  $pill = New-Object System.Windows.Controls.TextBlock
  $pill.Text = 'not checked'
  $pill.FontSize = 11
  $pill.Margin = '10,0,0,0'
  $pill.VerticalAlignment = 'Center'
  $pill.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#9AA3B2')
  [System.Windows.Controls.Grid]::SetColumn($left, 0)
  [System.Windows.Controls.Grid]::SetColumn($pill, 1)
  $grid.Children.Add($left) | Out-Null
  $grid.Children.Add($pill) | Out-Null
  $border.Child = $grid
  $pkgPanel.Children.Add($border) | Out-Null
  $script:checks[$p.Id] = $cb
  $script:pills[$p.Id] = $pill
}
