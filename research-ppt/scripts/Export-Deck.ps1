<# Export PDF and editable PPTX for one version; keep no snapshots or run history. #>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')][string]$DeckId,
  [Parameter(Mandatory=$true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Workspace.ps1')
$engineDirectory=$script:EngineDirectory
$deckDirectory=Get-DeckDirectory $DeckId -MustExist
$entry=Join-Path $deckDirectory 'slides.md'
$outputDirectory=Join-Path $deckDirectory "exports/v$Version"
$work=Join-Path $deckDirectory '.export-work'
$prepared=Join-Path $work 'prepared'
$previous=Join-Path $work 'previous'
$lockPath=Join-Path $deckDirectory '.export.lock'
$lock=$null
$ownsWork=$false
$published=$false
$success=$false
Assert-EngineDependencies
[void](Get-Command python -ErrorAction Stop)
$config=Get-DeckConfig $deckDirectory
$postprocessor=$null
if ($config -and $config.editablePostprocessor) {
  $postprocessor=[IO.Path]::GetFullPath((Join-Path $deckDirectory $config.editablePostprocessor))
  Assert-WithinDirectory $postprocessor $deckDirectory
  if (-not (Test-Path -LiteralPath $postprocessor -PathType Leaf)) { throw "Editable postprocessor missing: $postprocessor" }
}
Assert-WithinDirectory $outputDirectory $deckDirectory
if ((Test-Path -LiteralPath $outputDirectory) -and -not (Test-Path -LiteralPath $outputDirectory -PathType Container)) { throw 'Output path is not a directory.' }
try {
  try { $lock=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read) }
  catch { throw "Another export is running, or a stale lock exists: $lockPath" }
  $bytes=[Text.Encoding]::UTF8.GetBytes("PID=$PID; version=$Version")
  $lock.Write($bytes,0,$bytes.Length);$lock.Flush()
  if (Test-Path -LiteralPath $work) { throw 'Interrupted export found in .export-work. Inspect it before removing the stale lock/work directory.' }
  New-Item -ItemType Directory -Path $prepared -Force | Out-Null
  $ownsWork=$true
  New-Item -ItemType Directory -Path (Join-Path $work 'reports') | Out-Null
  Push-Location $engineDirectory
  try {
    $stem=Join-Path $prepared "$DeckId-v$Version"
    & npx.cmd --no-install slidev export $entry --format pdf --output ($stem+'.pdf') --with-toc --with-clicks false --timeout 60000 --wait 800
    if ($LASTEXITCODE -ne 0) { throw 'PDF export failed' }
    & npx.cmd --no-install slidev export $entry --format pptx-editable --output ($stem+'-editable.pptx') --scale 2 --with-clicks false --timeout 60000 --wait 800
    if ($LASTEXITCODE -ne 0) { throw 'Editable PPTX export failed' }
    if ($postprocessor) {
      & python -B $postprocessor ($stem+'-editable.pptx') --report (Join-Path $work 'reports/editable-fixes.json')
      if ($LASTEXITCODE -ne 0) { throw 'Editable PPTX postprocessing failed' }
    }
    & python -B (Join-Path $PSScriptRoot 'inspect-exports.py') --deck $deckDirectory --version $Version --directory $prepared --output (Join-Path $work 'prepared.json')
    if ($LASTEXITCODE -ne 0) { throw 'Prepared export integrity check failed' }
    New-Item -ItemType Directory -Path (Split-Path -Parent $outputDirectory) -Force | Out-Null
    # The previous pair exists only during this transaction, for rollback.
    if (Test-Path -LiteralPath $outputDirectory) { Move-Item -LiteralPath $outputDirectory -Destination $previous }
    try {
      Move-Item -LiteralPath $prepared -Destination $outputDirectory
      $published=$true
      & python -B (Join-Path $PSScriptRoot 'inspect-exports.py') --deck $deckDirectory --version $Version --output (Join-Path $work 'published.json')
      if ($LASTEXITCODE -ne 0) { throw 'Published export integrity check failed' }
      $success=$true
    } catch {
      if ($published -and (Test-Path -LiteralPath $outputDirectory)) { Remove-GeneratedPath $outputDirectory $deckDirectory }
      if (Test-Path -LiteralPath $previous) { Move-Item -LiteralPath $previous -Destination $outputDirectory }
      throw
    }
    Write-Output "Export complete: $outputDirectory (PDF + editable PPTX). Other versions are unchanged."
  } finally { Pop-Location }
} finally {
  try { if ($ownsWork) {
    # Never discard the last good output if rollback itself failed.
    if ((Test-Path -LiteralPath $previous) -and -not $success) {
      Write-Warning "Previous output preserved in $previous; restore it before retrying."
    } else { Remove-GeneratedPath $work $deckDirectory }
  } } finally { if ($lock) { $lock.Dispose(); Remove-Item -LiteralPath $lockPath } }
}
