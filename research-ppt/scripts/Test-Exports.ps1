<# Render the selected version in a disposable directory; keep no screenshots. #>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')][string]$DeckId,
  [Parameter(Mandatory=$true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
  [string]$PreviewUrl,
  [switch]$RequirePowerPoint,
  [switch]$AllowKnownToolchainIssues
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Workspace.ps1')
$deck=Get-DeckDirectory $DeckId -MustExist
$exports=Join-Path $deck "exports/v$Version"
if ($PreviewUrl -and $PreviewUrl -notmatch '^http://(localhost|127\.0\.0\.1)(:\d+)?/?$') { throw 'PreviewUrl must be a local HTTP preview root' }
$hasPowerPoint=[bool][Type]::GetTypeFromProgID('PowerPoint.Application')
if ($RequirePowerPoint -and -not $hasPowerPoint) { throw 'PowerPoint is required but not registered.' }
$tempParent=[IO.Path]::GetTempPath()
$work=Join-Path $tempParent ('pptmaker-check-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
Push-Location $script:EngineDirectory
try {
  & python -B (Join-Path $PSScriptRoot 'inspect-exports.py') --deck $deck --version $Version --output (Join-Path $work 'deliverables.json')
  if ($LASTEXITCODE -ne 0) { throw 'Deliverable integrity check failed' }
  $audit=Get-Content -LiteralPath (Join-Path $work 'deliverables.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $stem=Join-Path $exports "$DeckId-v$Version"
  & powershell.exe -NoProfile -File (Join-Path $PSScriptRoot 'Render-Pdf.ps1') -InputFile ($stem+'.pdf') -OutputDirectory (Join-Path $work 'pdf') -Width 1600 -ExitAfterRendering
  if ($LASTEXITCODE -ne 0) { throw 'Native PDF rendering failed' }
  $pdf=Get-Content -LiteralPath (Join-Path $work 'pdf/pdf-inspection.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($pdf.page_count -ne $audit.slides -or @(Get-ChildItem -LiteralPath (Join-Path $work 'pdf') -Filter 'slide-*.png').Count -ne $audit.slides) { throw 'PDF page count differs or rendering is incomplete' }
  if ($hasPowerPoint) {
    & powershell.exe -NoProfile -File (Join-Path $PSScriptRoot 'Render-PowerPoint.ps1') -InputFile ($stem+'-editable.pptx') -OutputDirectory (Join-Path $work 'editable') -Width 1600
    if ($LASTEXITCODE -ne 0) { throw 'Native PowerPoint rendering failed' }
    $render=Get-Content -LiteralPath (Join-Path $work 'editable/powerpoint-inspection.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($render.slide_count -ne $audit.slides -or @(Get-ChildItem -LiteralPath (Join-Path $work 'editable') -Filter 'slide-*.png').Count -ne $audit.slides -or $render.sha256.ToLowerInvariant() -ne (Get-FileHash -LiteralPath ($stem+'-editable.pptx')).Hash.ToLowerInvariant()) { throw 'PPTX evidence mismatch' }
  }
  $browserStatus='not requested'
  if ($PreviewUrl) {
    $qa=@((Join-Path $PSScriptRoot 'qa-deck.mjs'),$PreviewUrl,(Join-Path $work 'browser'),$audit.slides)
    if ($AllowKnownToolchainIssues) { $qa+='--allow-known-toolchain-issues' }
    & node @qa
    if ($LASTEXITCODE -ne 0) { throw 'Browser preview check failed' }
    $browserStatus=(Get-Content -LiteralPath (Join-Path $work 'browser/browser-qa.json') -Raw -Encoding UTF8 | ConvertFrom-Json).status
  }
  $pptxStatus=if ($hasPowerPoint) { 'passed' } else { 'skipped: PowerPoint not installed' }
  Write-Output "Check: $($audit.slides) pages; PDF passed; editable PPTX $pptxStatus; browser $browserStatus."
  Write-Output 'Temporary render files are removed. Open the final PDF/PPTX for visual review.'
} finally {
  Pop-Location
  Remove-GeneratedPath $work $tempParent
}
