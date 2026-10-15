<# Regression tests for creation, export refusal and preservation of existing outputs.
No real browser export is performed here; the end-to-end check is documented separately.
#>
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$testRoot=Join-Path $root ('_local/tests/'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$engine=Join-Path $testRoot 'research-ppt'
New-Item -ItemType Directory -Path $engine -Force | Out-Null
foreach ($name in @('scripts','config')) { Copy-Item -LiteralPath (Join-Path $root "research-ppt/$name") -Destination $engine -Recurse }
foreach ($name in @('decks/demo','decks/_template','public/decks/demo')) {
  $destination=Join-Path $engine $name
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $root "research-ppt/$name") -Destination $destination -Recurse
}
foreach ($name in @('PPTMaker.ps1','Export-PPT.ps1')) { Copy-Item -LiteralPath (Join-Path $root $name) -Destination $testRoot }
foreach ($name in @('package.json','package-lock.json')) { Copy-Item -LiteralPath (Join-Path $root "research-ppt/$name") -Destination $engine }
$results=New-Object Collections.Generic.List[object]
function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Expect-Failure([string]$Name,[scriptblock]$Body,[string]$Pattern) {
  $caught=$false
  try { & $Body | Out-Null } catch {
    if ($_.Exception.Message -notmatch $Pattern) { throw "Unexpected failure in ${Name}: $($_.Exception.Message)" }
    $caught=$true
  }
  Assert-True $caught "Expected failure: $Name"
  $results.Add(@{test=$Name;status='passed'})
}
$cli=Join-Path $testRoot 'PPTMaker.ps1'
& $cli -Action New -DeckId test-talk | Out-Null
$source=Join-Path $engine 'decks/test-talk/slides.md'
$hash=(Get-FileHash -LiteralPath $source).Hash
Expect-Failure 'duplicate deck does not overwrite' { & $cli -Action New -DeckId test-talk } 'already exist'
Assert-True ((Get-FileHash -LiteralPath $source).Hash -eq $hash) 'Duplicate creation modified source'
Expect-Failure 'path traversal rejected' { & $cli -Action New -DeckId '../escape' } 'pattern|ID must'
Expect-Failure 'version required' { & $cli -Action Export -DeckId test-talk } 'Version'
Expect-Failure 'missing theme rejected before creation' { & $cli -Action New -DeckId no-theme -Theme unavailable } 'incomplete'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $engine 'decks/no-theme'))) 'Missing theme left a deck'
Expect-Failure 'missing dependencies rejected' { & $cli -Action Export -DeckId test-talk -Version 1.0.0 } 'dependency is missing|Slidev is missing'
$output=Join-Path $engine 'decks/test-talk/exports/v1.0.0'
New-Item -ItemType Directory -Path $output -Force | Out-Null
$sentinel=Join-Path $output 'original.txt'
Set-Content -LiteralPath $sentinel -Value 'preserve this output'
$sentinelHash=(Get-FileHash -LiteralPath $sentinel).Hash
Expect-Failure 'existing version refused' { & $cli -Action Export -DeckId test-talk -Version 1.0.0 } 'already exists'
$packageFolder=Join-Path $engine 'node_modules/@slidev/cli'
New-Item -ItemType Directory -Path $packageFolder -Force | Out-Null
Set-Content -LiteralPath (Join-Path $packageFolder 'package.json') -Value '{}'
$deck=Join-Path $engine 'decks/test-talk'
$lock=Join-Path $deck '.export.lock'
Set-Content -LiteralPath $lock -Value 'test lock'
Expect-Failure 'export lock respected' { & $cli -Action Export -DeckId test-talk -Version 1.0.1 } 'Another export|stale lock'
Assert-True (Test-Path -LiteralPath $lock) 'Exporter removed a foreign lock'
Remove-Item -LiteralPath $lock
$mock=Join-Path $testRoot 'mock-bin'
New-Item -ItemType Directory -Path $mock | Out-Null
Set-Content -LiteralPath (Join-Path $mock 'npx.cmd') -Value "@exit /b 37" -Encoding ASCII
$savedPath=$env:PATH
try {
  $env:PATH="$mock;$savedPath"
  Expect-Failure 'failed rebuild preserves previous output' { & $cli -Action Export -DeckId test-talk -Version 1.0.0 -Rebuild } 'PDF export failed'
} finally { $env:PATH=$savedPath }
Assert-True ((Get-FileHash -LiteralPath $sentinel).Hash -eq $sentinelHash) 'Failed rebuild modified existing output'
Assert-True (-not (Test-Path -LiteralPath $lock)) 'Failed export left its lock'
$results.Add(@{test='failed export preserves hashes and releases own lock';status='passed'})
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $testRoot 'results.json') -Encoding UTF8
Write-Output "Passed $($results.Count) workflow checks. Evidence: $testRoot"
