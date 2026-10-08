# Pester tests for trident-mvp core. Data-driven via -Container Data.
param($Core, $Part2, $Part3, $Cli, $Src)

BeforeAll {
  . $Core
  . $Part2
  . $Part3
}

Describe 'Catalog' {
  It 'has 7 packages' {
    $script:Catalog.Count | Should -Be 7
  }
  It 'resolves aliases' {
    (Resolve-TridentWanted -Raw @('claude', 'claw')) -join ',' | Should -Be 'claude,zeroclaw'
  }
  It 'rejects unknown flags' {
    { Resolve-TridentWanted -Raw @('nope') } | Should -Throw
  }
  It 'defaults arch to x64 or arm64' {
    (Get-TridentArch -Wanted 'auto') | Should -Match 'x64|arm64'
  }
}

Describe 'CLI' {
  It 'detect-only exits 0' {
    $o = powershell -NoProfile -ExecutionPolicy Bypass -File $Cli -DetectOnly 2>&1 | Out-String
    $o | Should -Match 'SUMMARY'
  }
  It 'dry-run selective works' {
    $o = powershell -NoProfile -ExecutionPolicy Bypass -File $Cli -Only claude,zeroclaw -DryRun 2>&1 | Out-String
    $o | Should -Match 'TRIDENT'
  }
}
