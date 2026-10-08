#Requires -Version 5.1
# Trident GUI entry — joins Part1 (shell) + Part2 (actions).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$here = Split-Path $MyInvocation.MyCommand.Path -Parent
. (Join-Path $here 'Trident.Gui.Part1.ps1')
. (Join-Path $here 'Trident.Gui.Part2.ps1')
