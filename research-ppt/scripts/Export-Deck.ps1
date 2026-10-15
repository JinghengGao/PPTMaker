<#
.SYNOPSIS
Export the current deck source into exports/v<Version> with exactly three files.
.DESCRIPTION
Prepare and check all outputs before publication. -Rebuild archives old outputs.
Logs, editable-export reports and source snapshots stay outside exports.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')][string]$DeckId,
  [Parameter(Mandatory=$true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
  [switch]$Rebuild
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Workspace.ps1')
$engineDirectory=$script:EngineDirectory
$deckDirectory=Get-DeckDirectory $DeckId -MustExist
$entry=Join-Path $deckDirectory 'slides.md'
$outputDirectory=Join-Path $deckDirectory "exports/v$Version"
$lockPath=Join-Path $deckDirectory '.export.lock'
$lock=$null
$transcribing=$false
$previousLocation=Get-Location
$runId=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$runDirectory=Join-Path $deckDirectory "screenshots/v$Version/export-runs/$runId"
$stagingDirectory=Join-Path $runDirectory 'staging'
$snapshotDirectory=Join-Path $deckDirectory "versions/v$Version/export-snapshots/$runId"
$previousOutputArchive=$null
function Assert-WithinDeck([string]$Path) {
  Assert-WithinDirectory $Path $deckDirectory
  $resolved=[IO.Path]::GetFullPath($Path)
  $prefix=[IO.Path]::GetFullPath($deckDirectory).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
  if (-not $resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes deck: $resolved" }
}
function Copy-SnapshotFile([string]$Source) {
  $relative=$Source.Substring($engineDirectory.Length).TrimStart('\','/')
  $destination=Join-Path (Join-Path $snapshotDirectory 'research-ppt') $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $Source -Destination $destination
}
if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { throw "Deck source missing: $entry" }
if (Test-Path -LiteralPath $outputDirectory) {
  if (-not $Rebuild) { throw "Version v$Version already exists. Choose a new version or pass -Rebuild to archive and replace it." }
  if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) { throw "Version path is not a directory: $outputDirectory" }
}
if (-not (Test-Path -LiteralPath (Join-Path $engineDirectory 'node_modules/@slidev/cli/package.json'))) { throw 'Existing Slidev dependency is missing. Restore locked dependencies before exporting.' }
[void](Get-Command npx.cmd -ErrorAction Stop)
[void](Get-Command python -ErrorAction Stop)
$config=Get-DeckConfig $deckDirectory
$postprocessor=$null
if ($config -and $config.editablePostprocessor) {
  $postprocessor=[IO.Path]::GetFullPath((Join-Path $deckDirectory $config.editablePostprocessor))
  Assert-WithinDeck $postprocessor
  if (-not (Test-Path -LiteralPath $postprocessor -PathType Leaf)) { throw "Editable postprocessor missing: $postprocessor" }
}
try {
  # CreateNew prevents concurrent exports; sharing permits Vite to watch the file.
  try { $lock=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)) }
  catch { throw "Another export is running, or a stale lock exists: $lockPath. Check the active process before removing a stale lock." }
  $lockBytes=[Text.Encoding]::UTF8.GetBytes("PID=$PID; run=$runId; version=$Version")
  $lock.Write($lockBytes,0,$lockBytes.Length); $lock.Flush()
  New-Item -ItemType Directory -Path $stagingDirectory -Force | Out-Null
  New-Item -ItemType Directory -Path $snapshotDirectory -Force | Out-Null
  Start-Transcript -Path (Join-Path $runDirectory 'export.log') | Out-Null
  $transcribing=$true
  Set-Location -LiteralPath $engineDirectory
  # Save inputs for this individual export, with original engine-relative paths.
  foreach ($name in @('slides.md','vite.config.ts','export.config.json','setup.ts','global-top.vue','global-bottom.vue')) {
    $file=Join-Path $deckDirectory $name
    if (Test-Path -LiteralPath $file -PathType Leaf) { Copy-SnapshotFile $file }
  }
  foreach ($name in @('styles','layouts','components')) {
    $folder=Join-Path $deckDirectory $name
    if (Test-Path -LiteralPath $folder -PathType Container) {
      foreach ($file in Get-ChildItem -LiteralPath $folder -Recurse -File) { Copy-SnapshotFile $file.FullName }
    }
  }
  $assetDirectory=Join-Path $engineDirectory "public/decks/$DeckId"
  if (Test-Path -LiteralPath $assetDirectory -PathType Container) {
    foreach ($file in Get-ChildItem -LiteralPath $assetDirectory -Recurse -File) { Copy-SnapshotFile $file.FullName }
  }
  foreach ($name in @('package.json','package-lock.json')) { Copy-SnapshotFile (Join-Path $engineDirectory $name) }
  foreach ($name in @('Export-Deck.ps1','Test-Exports.ps1','inspect-exports.py','Render-Pdf.ps1','Render-PowerPoint.ps1','qa-deck.mjs')) { Copy-SnapshotFile (Join-Path $PSScriptRoot $name) }
  foreach ($file in Get-ChildItem -LiteralPath (Join-Path $engineDirectory 'config') -Recurse -File) { Copy-SnapshotFile $file.FullName }
  Copy-SnapshotFile (Join-Path $PSScriptRoot 'Workspace.ps1')
  Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $engineDirectory) 'PPTMaker.ps1') -Destination (Join-Path $snapshotDirectory 'PPTMaker.ps1')
  $rootEntry=Join-Path (Split-Path -Parent $engineDirectory) 'Export-PPT.ps1'
  if (Test-Path -LiteralPath $rootEntry -PathType Leaf) { Copy-Item -LiteralPath $rootEntry -Destination (Join-Path $snapshotDirectory 'Export-PPT.ps1') }
  if ($config -and $config.themeId) {
    if ($config.themeId -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw 'Invalid themeId in export.config.json' }
    $themeDirectory=Join-Path $engineDirectory "templates/$($config.themeId)"
    if (-not (Test-Path -LiteralPath $themeDirectory -PathType Container)) { throw "Local theme missing: $themeDirectory" }
    foreach ($file in Get-ChildItem -LiteralPath $themeDirectory -Recurse -File) {
      $themeRelative=$file.FullName.Substring($themeDirectory.Length).TrimStart('\','/')
      if ($themeRelative -notmatch '^(examples|node_modules)(\\|/)' -and $file.Extension -notmatch '^\.(ttf|otf|woff2?|pdf|pptx|zip)$') { Copy-SnapshotFile $file.FullName }
    }
  }
  if ($postprocessor) { Copy-SnapshotFile $postprocessor }
  if ($config -and $config.snapshotIncludes) {
    foreach ($relative in $config.snapshotIncludes) {
      $inputPath=[IO.Path]::GetFullPath((Join-Path $deckDirectory $relative))
      Assert-WithinDeck $inputPath
      if (-not (Test-Path -LiteralPath $inputPath)) { throw "Snapshot input missing: $relative" }
      if (Test-Path -LiteralPath $inputPath -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $inputPath -Recurse -File) { Assert-WithinDeck $file.FullName; Copy-SnapshotFile $file.FullName }
      } else { Copy-SnapshotFile $inputPath }
    }
  }
  $snapshotRecords=@(Get-ChildItem -LiteralPath $snapshotDirectory -Recurse -File | ForEach-Object {
    @{path=$_.FullName.Substring($snapshotDirectory.Length).TrimStart('\','/').Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
  })
  @{deck=$DeckId;version=$Version;run=$runId;created_at=(Get-Date).ToString('o');files=$snapshotRecords} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $snapshotDirectory 'snapshot.json') -Encoding UTF8
  $stem=Join-Path $stagingDirectory "$DeckId-v$Version"
  & npx.cmd --no-install slidev export $entry --format pdf --output ($stem+'.pdf') --with-toc --with-clicks false --timeout 60000 --wait 800
  if ($LASTEXITCODE -ne 0) { throw 'PDF export failed' }
  # Long decks can exceed Chromium's large one-piece screenshot surface.
  # Opt in per deck; existing decks retain their previous export behavior.
  $pptxArguments=@('--no-install','slidev','export',$entry,'--format','pptx','--output',($stem+'.pptx'),'--scale','2','--with-clicks','false','--timeout','60000','--wait','800')
  if ($config -and $config.pptxPerSlide -eq $true) { $pptxArguments+='--per-slide' }
  & npx.cmd @pptxArguments
  if ($LASTEXITCODE -ne 0) { throw 'PPTX export failed' }
  & npx.cmd --no-install slidev export $entry --format pptx-editable --output ($stem+'-editable.pptx') --scale 2 --with-clicks false --timeout 60000 --wait 800
  if ($LASTEXITCODE -ne 0) { throw 'Editable PPTX export failed' }
  if ($postprocessor) {
    & python $postprocessor ($stem+'-editable.pptx') --report (Join-Path $runDirectory 'editable-fixes.json')
    if ($LASTEXITCODE -ne 0) { throw 'Editable PPTX postprocessing failed' }
  }
  & python (Join-Path $PSScriptRoot 'inspect-exports.py') --deck $deckDirectory --version $Version --directory $stagingDirectory --output (Join-Path $runDirectory 'prepared-artifacts.json')
  if ($LASTEXITCODE -ne 0) { throw 'Prepared export integrity check failed' }
  Assert-WithinDeck $stagingDirectory
  Assert-WithinDeck $outputDirectory
  New-Item -ItemType Directory -Path (Split-Path -Parent $outputDirectory) -Force | Out-Null
  if (Test-Path -LiteralPath $outputDirectory) {
    if (-not $Rebuild) { throw "Version appeared during export: $outputDirectory" }
    $previousOutputArchive=Join-Path $deckDirectory "archive/replaced-exports/v$Version/$runId"
    Assert-WithinDeck $previousOutputArchive
    New-Item -ItemType Directory -Path (Split-Path -Parent $previousOutputArchive) -Force | Out-Null
    Move-Item -LiteralPath $outputDirectory -Destination $previousOutputArchive
  }
  try { Move-Item -LiteralPath $stagingDirectory -Destination $outputDirectory }
  catch {
    if ($previousOutputArchive -and -not (Test-Path -LiteralPath $outputDirectory)) { Move-Item -LiteralPath $previousOutputArchive -Destination $outputDirectory }
    throw
  }
  & python (Join-Path $PSScriptRoot 'inspect-exports.py') --deck $deckDirectory --version $Version --output (Join-Path $runDirectory 'deliverables.json')
  if ($LASTEXITCODE -ne 0) { throw 'Published export integrity check failed' }
  @{version=$Version;run=$runId;outputs="exports/v$Version";report="screenshots/v$Version/export-runs/$runId/deliverables.json";snapshot="versions/v$Version/export-snapshots/$runId";previous_outputs=$previousOutputArchive;status='exported'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $deckDirectory "screenshots/v$Version/latest-export.json") -Encoding UTF8
  Write-Host "Export complete: $outputDirectory"
  Write-Host "Source snapshot: $snapshotDirectory"
  Write-Host "Logs and manifest: $runDirectory"
}
catch {
  if (Test-Path -LiteralPath $runDirectory) {
    @{status='failed';version=$Version;run=$runId;error=$_.Exception.Message;failed_at=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDirectory 'failure.json') -Encoding UTF8
  }
  throw
}
finally {
  Set-Location $previousLocation
  if ($transcribing) { Stop-Transcript | Out-Null }
  if ($lock) { $lock.Dispose(); Assert-WithinDeck $lockPath; Remove-Item -LiteralPath $lockPath }
}
