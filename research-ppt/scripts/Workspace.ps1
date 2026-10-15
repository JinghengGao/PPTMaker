# Shared workflows behind PPTMaker.ps1. Windows PowerShell 5.1 compatible.
$script:ScriptsDirectory = $PSScriptRoot
$script:EngineDirectory = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))

function Assert-WorkspaceId([string]$Value) {
  if ($Value -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw 'ID must contain lowercase letters, numbers and single hyphens.' }
}

function Assert-WithinDirectory([string]$Path, [string]$Directory) {
  $full = [IO.Path]::GetFullPath($Path)
  $prefix = [IO.Path]::GetFullPath($Directory).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes directory: $full" }
  # Reject junctions/symlinks in an existing path, including its parents.
  $cursor = $full
  while ($cursor -and $cursor.Length -ge $Directory.Length) {
    if (Test-Path -LiteralPath $cursor) {
      if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked path is not supported: $cursor" }
    }
    $cursor = Split-Path -Parent $cursor
  }
}

function Get-DeckDirectory([string]$DeckId, [switch]$MustExist) {
  Assert-WorkspaceId $DeckId
  $path = Join-Path $script:EngineDirectory "decks/$DeckId"
  Assert-WithinDirectory $path $script:EngineDirectory
  if ($MustExist -and -not (Test-Path -LiteralPath (Join-Path $path 'slides.md') -PathType Leaf)) { throw "Deck source missing: $path" }
  return $path
}

function Get-DeckConfig([string]$DeckDirectory) {
  $path = Join-Path $DeckDirectory 'export.config.json'
  if (Test-Path -LiteralPath $path -PathType Leaf) { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json }
  return $null
}

function Open-DeckLock([string]$DeckDirectory, [string]$Version) {
  $path=Join-Path $DeckDirectory '.export.lock'
  Assert-WithinDirectory $path $DeckDirectory
  try { $handle=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read) }
  catch { throw "Another export/check is running, or a stale lock exists: $path" }
  try {
    $bytes=[Text.Encoding]::UTF8.GetBytes("PID=$PID; version=$Version")
    $handle.Write($bytes,0,$bytes.Length); $handle.Flush()
    return $handle
  } catch { $handle.Dispose(); Remove-Item -LiteralPath $path; throw }
}

function Assert-EngineDependencies {
  if (-not (Test-Path -LiteralPath (Join-Path $script:EngineDirectory 'node_modules/@slidev/cli/package.json'))) { throw 'Slidev is missing. Run npm.cmd ci in research-ppt.' }
  [void](Get-Command node -ErrorAction Stop)
  [void](Get-Command npx.cmd -ErrorAction Stop)
}

function Remove-GeneratedPath([string]$Path, [string]$ParentDirectory) {
  Assert-WithinDirectory $Path $ParentDirectory
  if (Test-Path -LiteralPath $Path) {
    $links=Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction Stop | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }
    if ($links) { throw "Refusing to recursively delete linked content: $Path" }
    Remove-Item -LiteralPath ([IO.Path]::GetFullPath($Path)) -Recurse -Force
  }
}

function Test-WorkspaceEnvironment {
  [CmdletBinding()]
  param()
  $ErrorActionPreference = 'Stop'
  $failed = $false
  foreach ($command in @('node','npm.cmd','python','git')) {
    try {
      [void](Get-Command $command -ErrorAction Stop)
      $value = & $command --version 2>&1
      if ($LASTEXITCODE -ne 0) { throw "$command failed" }
      Write-Output "[OK] $command $value"
    } catch { Write-Output "[MISSING] $command"; $failed = $true }
  }
  Push-Location $script:EngineDirectory
  try {
    & node (Join-Path $script:ScriptsDirectory 'browser.mjs') --doctor
    if ($LASTEXITCODE -ne 0) { $failed = $true }
  } finally { Pop-Location }
  if ([Type]::GetTypeFromProgID('PowerPoint.Application')) { Write-Output '[OPTIONAL OK] PowerPoint registered; Check verifies actual rendering.' }
  else { Write-Output '[OPTIONAL MISSING] PowerPoint: PPTX native rendering will be skipped.' }
  if ($failed) { throw 'Required environment checks failed. See README.md.' }
}

function New-WorkspaceDeck {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$DeckId,
    [string]$Theme = 'default'
  )
  $ErrorActionPreference = 'Stop'
  $deck = Get-DeckDirectory $DeckId
  $assets = Join-Path $script:EngineDirectory "public/decks/$DeckId"
  Assert-WithinDirectory $assets $script:EngineDirectory
  if ((Test-Path -LiteralPath $deck) -or (Test-Path -LiteralPath $assets)) { throw 'Deck or assets already exist. Nothing was replaced.' }
  $aliases = @{ TemplateMC = 'mc'; TemplateNKU = 'nku' }
  if ($aliases.ContainsKey($Theme)) { $Theme = $aliases[$Theme] }
  Assert-WorkspaceId $Theme
  $themeValue = 'default'
  $starter = Join-Path $script:EngineDirectory 'decks/demo/slides.md'
  # PowerShell 5.1 cannot parse package-lock's empty-string package key.
  # package.json pins the same exact versions, and has no empty property names.
  $enginePackage = Get-Content -LiteralPath (Join-Path $script:EngineDirectory 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $themeVersion = $enginePackage.dependencies.'@slidev/theme-default'
  $config = [ordered]@{ theme = 'default'; themeVersion = $themeVersion }
  if ($Theme -ne 'default') {
    $sourceDirectory = Join-Path $script:EngineDirectory "decks/$Theme"
    Assert-WithinDirectory $sourceDirectory $script:EngineDirectory
    foreach ($name in @('theme/package.json','manifest.json','STYLE-GUIDE.md')) {
      if (-not (Test-Path -LiteralPath (Join-Path $sourceDirectory $name) -PathType Leaf)) { throw "Local theme is incomplete: $Theme/$name" }
    }
    $manifest = Get-Content -LiteralPath (Join-Path $sourceDirectory 'manifest.json') -Encoding UTF8 -Raw | ConvertFrom-Json
    if ($manifest.id -ne $Theme -or -not $manifest.version) { throw 'Invalid local theme manifest.' }
    $themeValue = "../$Theme/theme"
    $themeVersion = $manifest.version
    $config = [ordered]@{ themeId = $Theme; themeVersion = $manifest.version }
    if ($manifest.starter) {
      $starter = [IO.Path]::GetFullPath((Join-Path $sourceDirectory $manifest.starter))
      Assert-WithinDirectory $starter $sourceDirectory
      if (-not (Test-Path -LiteralPath $starter -PathType Leaf)) { throw "Theme starter missing: $starter" }
    }
  }
  # CreateNew on the marker prevents two creators from overwriting each other.
  New-Item -ItemType Directory -Path (Split-Path -Parent $deck) -Force | Out-Null
  $marker = "$deck.creating"
  $creationLock = [IO.File]::Open($marker, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  try {
    if ((Test-Path -LiteralPath $deck) -or (Test-Path -LiteralPath $assets)) { throw 'Deck or assets appeared during creation.' }
    foreach ($path in @($deck,$assets,(Join-Path $deck 'exports'))) { New-Item -ItemType Directory -Path $path | Out-Null }
    $source = Get-Content -LiteralPath $starter -Raw -Encoding UTF8
    # Only change the frontmatter theme; keep theme examples in the official demo intact.
    $source = ([regex]'(?m)^theme:[ \t]*[^\r\n]+').Replace($source, "theme: $themeValue", 1)
    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $deck 'slides.md'), $source, $utf8)
    [IO.File]::WriteAllText((Join-Path $deck 'vite.config.ts'), "export { default } from '../../config/vite.ts'`n", $utf8)
    [IO.File]::WriteAllText((Join-Path $deck 'export.config.json'), ($config | ConvertTo-Json) + "`n", $utf8)
    $brief = @"
# Presentation brief

- Deck: $DeckId
- Theme: $Theme@$themeVersion
- Title, audience and duration: [fill in]
- Main message and outline: [fill in]
- Materials and citations: [fill in]
- Author and affiliation: [fill in or leave blank]
- Deliverables: PDF and editable PPTX in exports/vX.Y.Z/
"@
    [IO.File]::WriteAllText((Join-Path $deck 'brief.md'), $brief, $utf8)
    $qa = @'
# Review checklist

- [ ] Review every slide: layout, fonts, images, formulas and technical content.
- [ ] Verify data and citations; mark placeholders clearly.
- [ ] Open the PDF and editable PPTX; check native text and image fidelity.
- [ ] Record commands, results and remaining issues below.
'@
    [IO.File]::WriteAllText((Join-Path $deck 'QA.md'), $qa, $utf8)
    foreach ($name in @('components','assets')) {
      $support = Join-Path (Split-Path -Parent $starter) $name
      if (Test-Path -LiteralPath $support -PathType Container) {
        Assert-WithinDirectory $support (Split-Path -Parent $starter)
        Copy-Item -LiteralPath $support -Destination $deck -Recurse
      }
    }
  } finally { $creationLock.Dispose(); Remove-Item -LiteralPath $marker }
  Write-Output "Created $deck (theme: $Theme). Edit brief.md, slides.md and QA.md."
}

function Export-WorkspaceDeck {
  <# Export PDF and editable PPTX for one version; keep no snapshots or run history. #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')][string]$DeckId,
    [Parameter(Mandatory=$true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version
  )
  $ErrorActionPreference='Stop'
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
    $lock=Open-DeckLock $deckDirectory $Version
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
      & python -B (Join-Path $script:ScriptsDirectory 'inspect-exports.py') --deck $deckDirectory --version $Version --directory $prepared --output (Join-Path $work 'prepared.json') --prepare
      if ($LASTEXITCODE -ne 0) { throw 'Prepared export integrity check failed' }
      New-Item -ItemType Directory -Path (Split-Path -Parent $outputDirectory) -Force | Out-Null
      # The previous pair exists only during this transaction, for rollback.
      if (Test-Path -LiteralPath $outputDirectory) { Move-Item -LiteralPath $outputDirectory -Destination $previous }
      try {
        Move-Item -LiteralPath $prepared -Destination $outputDirectory
        $published=$true
        & python -B (Join-Path $script:ScriptsDirectory 'inspect-exports.py') --deck $deckDirectory --version $Version --output (Join-Path $work 'published.json')
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
}

function Test-WorkspaceDeck {
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
  $deck=Get-DeckDirectory $DeckId -MustExist
  $exports=Join-Path $deck "exports/v$Version"
  if ($PreviewUrl -and $PreviewUrl -notmatch '^http://(localhost|127\.0\.0\.1)(:\d+)?/?$') { throw 'PreviewUrl must be a local HTTP preview root' }
  $hasPowerPoint=[bool][Type]::GetTypeFromProgID('PowerPoint.Application')
  if ($RequirePowerPoint -and -not $hasPowerPoint) { throw 'PowerPoint is required but not registered.' }
  $lockPath=Join-Path $deck '.export.lock'
  $lock=Open-DeckLock $deck $Version
  try {
    $tempParent=[IO.Path]::GetTempPath()
    $work=Join-Path $tempParent ('pptmaker-check-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    Push-Location $script:EngineDirectory
    try {
      & python -B (Join-Path $script:ScriptsDirectory 'inspect-exports.py') --deck $deck --version $Version --output (Join-Path $work 'deliverables.json')
      if ($LASTEXITCODE -ne 0) { throw 'Deliverable integrity check failed' }
      $audit=Get-Content -LiteralPath (Join-Path $work 'deliverables.json') -Raw -Encoding UTF8 | ConvertFrom-Json
      $stem=Join-Path $exports "$DeckId-v$Version"
      & powershell.exe -NoProfile -File (Join-Path $script:ScriptsDirectory 'Render.ps1') -Format Pdf -InputFile ($stem+'.pdf') -OutputDirectory (Join-Path $work 'pdf') -Width 1600
      if ($LASTEXITCODE -ne 0) { throw 'Native PDF rendering failed' }
      $pdf=Get-Content -LiteralPath (Join-Path $work 'pdf/pdf-inspection.json') -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($pdf.page_count -ne $audit.slides -or @(Get-ChildItem -LiteralPath (Join-Path $work 'pdf') -Filter 'slide-*.png').Count -ne $audit.slides) { throw 'PDF page count differs or rendering is incomplete' }
      if ($hasPowerPoint) {
        & powershell.exe -NoProfile -File (Join-Path $script:ScriptsDirectory 'Render.ps1') -Format PowerPoint -InputFile ($stem+'-editable.pptx') -OutputDirectory (Join-Path $work 'editable') -Width 1600
        if ($LASTEXITCODE -ne 0) { throw 'Native PowerPoint rendering failed' }
        $render=Get-Content -LiteralPath (Join-Path $work 'editable/powerpoint-inspection.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($render.slide_count -ne $audit.slides -or @(Get-ChildItem -LiteralPath (Join-Path $work 'editable') -Filter 'slide-*.png').Count -ne $audit.slides -or $render.sha256.ToLowerInvariant() -ne (Get-FileHash -LiteralPath ($stem+'-editable.pptx')).Hash.ToLowerInvariant()) { throw 'PPTX evidence mismatch' }
      }
      $browserStatus='not requested'
      if ($PreviewUrl) {
        $qa=@((Join-Path $script:ScriptsDirectory 'browser.mjs'),$PreviewUrl,(Join-Path $work 'browser'),$audit.slides)
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
  } finally { $lock.Dispose(); Remove-Item -LiteralPath $lockPath }
}
