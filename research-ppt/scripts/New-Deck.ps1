[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$DeckId,
  [string]$Theme = 'default'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Workspace.ps1')
$deck = Get-DeckDirectory $DeckId
$assets = Join-Path $script:EngineDirectory "public/decks/$DeckId"
Assert-WithinDirectory $assets $script:EngineDirectory
if ((Test-Path -LiteralPath $deck) -or (Test-Path -LiteralPath $assets)) { throw 'Deck or assets already exist. Nothing was replaced.' }
Assert-WorkspaceId $Theme
$themeValue = 'default'
# PowerShell 5.1 cannot parse package-lock's empty-string package key.
# package.json pins the same exact versions, and has no empty property names.
$enginePackage = Get-Content -LiteralPath (Join-Path $script:EngineDirectory 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$themeVersion = $enginePackage.dependencies.'@slidev/theme-default'
$config = [ordered]@{ theme = 'default'; themeVersion = $themeVersion }
if ($Theme -ne 'default') {
  $themeDirectory = Join-Path $script:EngineDirectory "templates/$Theme"
  Assert-WithinDirectory $themeDirectory $script:EngineDirectory
  foreach ($name in @('package.json','manifest.json','STYLE-GUIDE.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $themeDirectory $name) -PathType Leaf)) { throw "Local theme is incomplete: $Theme/$name" }
  }
  $manifest = Get-Content -LiteralPath (Join-Path $themeDirectory 'manifest.json') -Encoding UTF8 -Raw | ConvertFrom-Json
  if ($manifest.id -ne $Theme -or -not $manifest.version) { throw 'Invalid local theme manifest.' }
  $themeValue = "../../templates/$Theme"
  $themeVersion = $manifest.version
  $config = [ordered]@{ themeId = $Theme; themeVersion = $manifest.version }
}
# CreateNew on the marker prevents two creators from overwriting each other.
New-Item -ItemType Directory -Path (Split-Path -Parent $deck) -Force | Out-Null
$marker = "$deck.creating"
$creationLock = [IO.File]::Open($marker, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
  if ((Test-Path -LiteralPath $deck) -or (Test-Path -LiteralPath $assets)) { throw 'Deck or assets appeared during creation.' }
  foreach ($path in @($deck,$assets,(Join-Path $deck 'exports'))) { New-Item -ItemType Directory -Path $path | Out-Null }
  $source = Get-Content -LiteralPath (Join-Path $script:EngineDirectory 'decks/demo/slides.md') -Raw -Encoding UTF8
  $source = $source.Replace('theme: default', "theme: $themeValue").Replace('/decks/demo/', "/decks/$DeckId/")
  $utf8 = New-Object Text.UTF8Encoding($false)
  [IO.File]::WriteAllText((Join-Path $deck 'slides.md'), $source, $utf8)
  [IO.File]::WriteAllText((Join-Path $deck 'vite.config.ts'), "export { default } from '../../config/vite.ts'`n", $utf8)
  [IO.File]::WriteAllText((Join-Path $deck 'export.config.json'), ($config | ConvertTo-Json) + "`n", $utf8)
  $brief = Get-Content -LiteralPath (Join-Path $script:EngineDirectory 'decks/_template/brief.md') -Raw -Encoding UTF8
  $brief = $brief.Replace('{{DECK_ID}}', $DeckId).Replace('{{THEME_ID}}', $Theme).Replace('{{THEME_VERSION}}', $themeVersion)
  [IO.File]::WriteAllText((Join-Path $deck 'brief.md'), $brief, $utf8)
  Copy-Item -LiteralPath (Join-Path $script:EngineDirectory 'decks/_template/QA-CHECKLIST.md') -Destination (Join-Path $deck 'QA.md')
  Copy-Item -LiteralPath (Join-Path $script:EngineDirectory 'public/decks/demo/sample.svg') -Destination (Join-Path $assets 'sample.svg')
} finally { $creationLock.Dispose(); Remove-Item -LiteralPath $marker }
Write-Output "Created $deck (theme: $Theme). Edit brief.md, slides.md and QA.md."
