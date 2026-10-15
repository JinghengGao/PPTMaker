<# Export the current deck into a version folder containing three deliverables. #>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')][string]$DeckId,
  [Parameter(Mandatory=$true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
  [switch]$Rebuild
)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'research-ppt/scripts/Export-Deck.ps1') -DeckId $DeckId -Version $Version -Rebuild:$Rebuild
