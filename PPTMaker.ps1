<# .SYNOPSIS
PPTMaker: Doctor, New, Preview, Export and Check. Run without arguments for help.
#>
[CmdletBinding()]
param(
  [ValidateSet('Help','Doctor','New','Preview','Export','Check')][string]$Action = 'Help',
  [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')][string]$DeckId,
  [ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
  [string]$Theme = 'default',
  [ValidateRange(1024,65535)][int]$Port = 3030,
  [switch]$Rebuild,
  [string]$PreviewUrl,
  [switch]$RequirePowerPoint,
  [switch]$AllowKnownToolchainIssues
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'research-ppt/scripts/Workspace.ps1')
if ($Action -eq 'Help') {
  Write-Output @'
PPTMaker -Action Doctor
PPTMaker -Action New -DeckId my-talk [-Theme default|local-theme-id]
PPTMaker -Action Preview -DeckId demo [-Port 3030]
PPTMaker -Action Export -DeckId demo -Version 1.0.0 [-Rebuild]
PPTMaker -Action Check -DeckId demo -Version 1.0.0 [-PreviewUrl http://localhost:3030] [-RequirePowerPoint]
Use powershell.exe -NoProfile -File .\PPTMaker.ps1 before these arguments. See README.md.
'@
  return
}
if ($Action -eq 'Doctor') { & (Join-Path $PSScriptRoot 'research-ppt/scripts/Doctor.ps1'); return }
if (-not $DeckId) { throw '-DeckId is required for this action.' }
if ($Action -in @('Export','Check') -and -not $Version) { throw '-Version X.Y.Z is required for this action.' }
switch ($Action) {
  'New' { & (Join-Path $PSScriptRoot 'research-ppt/scripts/New-Deck.ps1') -DeckId $DeckId -Theme $Theme }
  'Preview' {
    $deck = Get-DeckDirectory $DeckId -MustExist
    Assert-EngineDependencies
    Push-Location $script:EngineDirectory
    try {
      & npx.cmd --no-install slidev (Join-Path $deck 'slides.md') --port $Port --bind 127.0.0.1
      if ($LASTEXITCODE -ne 0) { throw 'Preview failed.' }
    } finally { Pop-Location }
  }
  'Export' { & (Join-Path $PSScriptRoot 'research-ppt/scripts/Export-Deck.ps1') -DeckId $DeckId -Version $Version -Rebuild:$Rebuild }
  'Check' { & (Join-Path $PSScriptRoot 'research-ppt/scripts/Test-Exports.ps1') -DeckId $DeckId -Version $Version -PreviewUrl $PreviewUrl -RequirePowerPoint:$RequirePowerPoint -AllowKnownToolchainIssues:$AllowKnownToolchainIssues }
}
