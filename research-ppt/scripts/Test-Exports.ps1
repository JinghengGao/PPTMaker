<# Render PDF and, when installed, both PPTX variants. Visual review is separate. #>
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
$engineDirectory=$script:EngineDirectory
$deckDirectory=Get-DeckDirectory $DeckId -MustExist
$exportDirectory=Join-Path $deckDirectory "exports/v$Version"
$reportDirectory=Join-Path $deckDirectory ("screenshots/v$Version/export-checks/"+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
Assert-WithinDirectory $reportDirectory $deckDirectory
if ($PreviewUrl -and $PreviewUrl -notmatch '^http://(localhost|127\.0\.0\.1)(:\d+)?/?$') { throw 'PreviewUrl must be a local HTTP preview root' }
$hasPowerPoint=[bool][Type]::GetTypeFromProgID('PowerPoint.Application')
if ($RequirePowerPoint -and -not $hasPowerPoint) { throw 'PowerPoint is required but not registered.' }
New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
$summary=[ordered]@{deck=$DeckId;version=$Version;checked_at=(Get-Date).ToString('o');integrity='pending';pdf_render='pending';pptx_render='skipped: PowerPoint not installed';browser_checked=$false;manual_visual_review='required';status='running'}
Push-Location $engineDirectory
try {
  & python (Join-Path $PSScriptRoot 'inspect-exports.py') --deck $deckDirectory --version $Version --output (Join-Path $reportDirectory 'deliverables.json')
  if ($LASTEXITCODE -ne 0) { throw 'Deliverable integrity check failed' }
  $summary.integrity='passed'
  $audit=Get-Content -LiteralPath (Join-Path $reportDirectory 'deliverables.json') -Encoding UTF8 -Raw | ConvertFrom-Json
  $summary.pages=$audit.slides
  $stem=Join-Path $exportDirectory "$DeckId-v$Version"
  & powershell.exe -NoProfile -File (Join-Path $PSScriptRoot 'Render-Pdf.ps1') -InputFile ($stem+'.pdf') -OutputDirectory (Join-Path $reportDirectory 'pdf') -Width 1600
  if ($LASTEXITCODE -ne 0) { throw 'Native PDF rendering failed' }
  $pdf=Get-Content -LiteralPath (Join-Path $reportDirectory 'pdf/pdf-inspection.json') -Encoding UTF8 -Raw | ConvertFrom-Json
  if ($pdf.page_count -ne $audit.slides -or @(Get-ChildItem -LiteralPath (Join-Path $reportDirectory 'pdf') -Filter 'slide-*.png').Count -ne $audit.slides) { throw 'PDF page counts differ or screenshots incomplete' }
  $summary.pdf_render='passed'
  if ($hasPowerPoint) {
    $summary.pptx_render='running'
    foreach ($variant in @('pptx','pptx-editable')) {
      $suffix=if ($variant -eq 'pptx') { '.pptx' } else { '-editable.pptx' }
      & powershell.exe -NoProfile -File (Join-Path $PSScriptRoot 'Render-PowerPoint.ps1') -InputFile ($stem+$suffix) -OutputDirectory (Join-Path $reportDirectory $variant) -Width 1600
      if ($LASTEXITCODE -ne 0) { throw "Native PowerPoint rendering failed: $variant" }
      $render=Get-Content -LiteralPath (Join-Path $reportDirectory "$variant/powerpoint-inspection.json") -Encoding UTF8 -Raw | ConvertFrom-Json
      if ($render.slide_count -ne $audit.slides -or $render.sha256.ToLowerInvariant() -ne (Get-FileHash -LiteralPath ($stem+$suffix) -Algorithm SHA256).Hash.ToLowerInvariant() -or @(Get-ChildItem -LiteralPath (Join-Path $reportDirectory $variant) -Filter 'slide-*.png').Count -ne $audit.slides) { throw "PowerPoint evidence mismatch: $variant" }
    }
    $summary.pptx_render='passed'
  }
  if ($PreviewUrl) {
    $qaArguments=@((Join-Path $PSScriptRoot 'qa-deck.mjs'),$PreviewUrl,(Join-Path $reportDirectory 'browser'),$audit.slides)
    if ($AllowKnownToolchainIssues) { $qaArguments+='--allow-known-toolchain-issues' }
    & node @qaArguments
    if ($LASTEXITCODE -ne 0) { throw 'Browser preview check failed' }
    $summary.browser_checked=$true
    $summary.browser_status=(Get-Content -LiteralPath (Join-Path $reportDirectory 'browser/browser-qa.json') -Raw -Encoding UTF8 | ConvertFrom-Json).status
  }
  $summary.status=if ($hasPowerPoint) { 'automated_checks_passed' } else { 'partial: native PPTX rendering skipped' }
  @{version=$Version;report=$reportDirectory;checked_at=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $deckDirectory "screenshots/v$Version/latest-check.json") -Encoding UTF8
  Write-Output "Check status: $($summary.status). Visual review still required."
  Write-Output "Review screenshots: $reportDirectory"
} catch { $summary.status='failed'; $summary.error=$_.Exception.Message; throw }
finally {
  $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $reportDirectory 'check-summary.json') -Encoding UTF8
  Pop-Location
}
