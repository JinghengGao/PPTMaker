<# Regression tests for creation, export refusal and preservation of existing outputs.
No real browser export is performed here; the end-to-end check is documented separately.
#>
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$tempParent=[IO.Path]::GetTempPath()
$testRoot=Join-Path $tempParent ('pptmaker-test-'+[Guid]::NewGuid().ToString('N'))
. (Join-Path $PSScriptRoot 'Workspace.ps1')
try {
$engine=Join-Path $testRoot 'research-ppt'
New-Item -ItemType Directory -Path $engine -Force | Out-Null
foreach ($name in @('scripts','config')) { Copy-Item -LiteralPath (Join-Path $root "research-ppt/$name") -Destination $engine -Recurse }
foreach ($name in @('decks/demo')) {
  $destination=Join-Path $engine $name
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root "research-ppt/$name") -File) {
    Copy-Item -LiteralPath $file.FullName -Destination $destination
  }
}
Copy-Item -LiteralPath (Join-Path $root 'research-ppt/decks/demo/components') -Destination (Join-Path $engine 'decks/demo') -Recurse
foreach ($name in @('PPTMaker.ps1')) { Copy-Item -LiteralPath (Join-Path $root $name) -Destination $testRoot }
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
$brief=Get-Content -LiteralPath (Join-Path $engine 'decks/test-talk/brief.md') -Raw -Encoding UTF8
Assert-True ($brief.Contains('test-talk') -and $brief.Contains('default@0.25.0') -and -not $brief.Contains('{{')) 'Created brief must record theme version and deck ID'
$createdSource=Get-Content -LiteralPath $source -Raw -Encoding UTF8
Assert-True ($createdSource -match '(?m)^theme: default' -and $createdSource.Contains('theme: seriph')) 'New must change only the frontmatter theme, preserving official theme examples'
$counter=Join-Path $engine 'decks/test-talk/components/Counter.vue'
Assert-True ((Get-FileHash -LiteralPath $counter).Hash -eq (Get-FileHash -LiteralPath (Join-Path $engine 'decks/demo/components/Counter.vue')).Hash) 'New must copy the official demo component'
Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $engine 'public/decks/test-talk') -Force).Count -eq 0) 'New must not add unused sample assets'
$results.Add(@{test='official starter dependencies copied and only frontmatter theme changed';status='passed'})
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
$otherVersion=Join-Path $engine 'decks/test-talk/exports/v0.9.0'
New-Item -ItemType Directory -Path $otherVersion -Force | Out-Null
Set-Content -LiteralPath (Join-Path $otherVersion 'keep.txt') -Value 'other version'

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
  Expect-Failure 'failed rebuild preserves previous output' { & $cli -Action Export -DeckId test-talk -Version 1.0.0 } 'PDF export failed'
} finally { $env:PATH=$savedPath }
Assert-True ((Get-FileHash -LiteralPath $sentinel).Hash -eq $sentinelHash) 'Failed rebuild modified existing output'
Assert-True (-not (Test-Path -LiteralPath $lock)) 'Failed export left its lock'
$results.Add(@{test='failed export preserves hashes and releases own lock';status='passed'})
# Simulate a failure after the staged files have passed inspection and moved.
# These dummy artifacts stay in the disposable fixture, never in user decks.
Set-Content -LiteralPath (Join-Path $mock 'mock-export.py') -Value @'
import pathlib,sys
args=sys.argv[1:]
path=pathlib.Path(args[args.index('--output')+1])
path.parent.mkdir(parents=True,exist_ok=True)
path.write_bytes(b'fixture-output')
'@ -Encoding ASCII
Set-Content -LiteralPath (Join-Path $mock 'npx.cmd') -Value '@python "%~dp0mock-export.py" %*' -Encoding ASCII
Set-Content -LiteralPath (Join-Path $engine 'scripts/inspect-exports.py') -Value @'
import pathlib,sys
args=sys.argv[1:]
if '--directory' not in args:sys.exit(38)
pathlib.Path(args[args.index('--output')+1]).write_text('{}',encoding='utf-8')
'@ -Encoding ASCII
try {
  $env:PATH="$mock;$savedPath"
  Expect-Failure 'publication failure rolls back old output' { & $cli -Action Export -DeckId test-talk -Version 1.0.0 } 'Published export integrity check failed'
} finally { $env:PATH=$savedPath }
Assert-True ((Get-FileHash -LiteralPath $sentinel).Hash -eq $sentinelHash) 'Publication rollback lost original output'
Assert-True (-not (Test-Path -LiteralPath $lock)) 'Rollback left a lock'
Assert-True (Test-Path -LiteralPath (Join-Path $otherVersion 'keep.txt')) 'Another version was removed'
$results.Add(@{test='other versions preserved';status='passed'})
Assert-True (-not (Test-Path -LiteralPath (Join-Path $deck '.export-work'))) 'Temporary export data was retained'
Write-Output "Passed $($results.Count) workflow checks. Temporary fixtures are removed."
} finally { Remove-GeneratedPath $testRoot $tempParent }
