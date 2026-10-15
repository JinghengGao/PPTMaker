<# Preview obsolete generated files. -Apply deletes only the reviewed generated scope. #>
[CmdletBinding()]
param([switch]$Apply)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Workspace.ps1')
$root=Split-Path -Parent $script:EngineDirectory
$candidates=New-Object Collections.Generic.List[string]
function Add-Candidate([string]$Path) {
  $full=[IO.Path]::GetFullPath($Path)
  Assert-WithinDirectory $full $root
  if (Test-Path -LiteralPath $full) { $candidates.Add($full) }
}
foreach ($name in @('clean-room','cleanup-backups','private-regression','public-index-check-fixture','tests','visual-review','visual-review-final','CLEANUP-REPORT.md','current-backup.txt','latest-visual-review.txt')) {
  Add-Candidate (Join-Path $root "_local/$name")
}
Add-Candidate (Join-Path $script:EngineDirectory 'archive')
foreach ($deck in Get-ChildItem -LiteralPath (Join-Path $script:EngineDirectory 'decks') -Directory) {
  if ($deck.Name -match '^starter-backup-\d{8}$') { Add-Candidate $deck.FullName; continue }
  foreach ($name in @('archive','versions','screenshots','node_modules')) { Add-Candidate (Join-Path $deck.FullName $name) }
  foreach ($file in Get-ChildItem -LiteralPath $deck.FullName -File) {
    if ($file.Name -match '(?i)(backup.*\.json$|^protected-files-before\.json$|^protection-report\.json$|^QA-\d.*\.md$)') { Add-Candidate $file.FullName }
  }
  $exports=Join-Path $deck.FullName 'exports'
  if (Test-Path -LiteralPath $exports) {
    foreach ($file in Get-ChildItem -LiteralPath $exports -Recurse -File) {
      if ($file.Extension -ne '.pdf' -and -not $file.Name.EndsWith('-editable.pptx')) { Add-Candidate $file.FullName }
    }
  }
  # Retain the active export hook, its same-folder dependencies and all vendored libraries.
  $config=Get-DeckConfig $deck.FullName
  $tools=Join-Path $deck.FullName 'tools'
  if ($config -and $config.editablePostprocessor -and (Test-Path -LiteralPath $tools)) {
    $keep=@{}
    $hook=[IO.Path]::GetFullPath((Join-Path $deck.FullName $config.editablePostprocessor))
    Assert-WithinDirectory $hook $deck.FullName
    if (-not (Test-Path -LiteralPath $hook -PathType Leaf)) { throw "Active postprocessor missing: $hook" }
    $queue=New-Object Collections.Generic.Queue[string]
    $queue.Enqueue($hook)
    $toolFiles=@(Get-ChildItem -LiteralPath $tools -File)
    while ($queue.Count) {
      $current=$queue.Dequeue()
      if ($keep.ContainsKey($current)) { continue }
      $keep[$current]=$true
      $text=Get-Content -LiteralPath $current -Raw -Encoding UTF8
      foreach ($file in $toolFiles) {
        if ($text.Contains($file.Name) -and -not $keep.ContainsKey($file.FullName)) { $queue.Enqueue($file.FullName) }
      }
    }
    foreach ($file in $toolFiles) {
      if ($file.Extension -in @('.py','.ps1','.mjs','.json') -and -not $keep.ContainsKey($file.FullName)) { Add-Candidate $file.FullName }
    }
  }
}
foreach ($folder in Get-ChildItem -LiteralPath (Join-Path $script:EngineDirectory 'templates') -Directory -Recurse -Force | Where-Object { $_.Name -in @('node_modules','screenshots','__pycache__') }) {
  Add-Candidate $folder.FullName
}
$selected=New-Object Collections.Generic.List[string]
foreach ($path in ($candidates | Sort-Object Length -Unique)) {
  $covered=$false
  foreach ($parent in $selected) {
    if ($path.StartsWith($parent.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { $covered=$true;break }
  }
  if (-not $covered) { $selected.Add($path) }
}
$files=New-Object Collections.Generic.List[object]
$directories=New-Object Collections.Generic.List[string]
$bytes=0L
foreach ($path in $selected) {
  if (-not (Test-Path -LiteralPath $path)) { continue }
  $item=Get-Item -LiteralPath $path -Force
  $items=if ($item.PSIsContainer) { @($item)+@(Get-ChildItem -LiteralPath $path -Recurse -Force) } else { @($item) }
  foreach ($entry in $items) {
    if (-not ([IO.Path]::GetFullPath($entry.FullName)).StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Entry escapes workspace' }
    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked content requires manual review: $($entry.FullName)" }
    if ($entry.PSIsContainer) { $directories.Add($entry.FullName) }
    else { $files.Add($entry);$bytes+=$entry.Length }
  }
}
Write-Output "Generated-file cleanup: $($files.Count) files, $([Math]::Round($bytes/1GB,2)) GiB."
foreach ($path in $selected) { Write-Output ('  '+$path.Substring($root.Length+1)) }
if (-not $Apply) { Write-Output 'Preview only. Re-run with -Apply to delete this scope. Keep all versioned PDFs/editable PPTXs and current source materials.'; return }
$blockers=@(Get-CleanupBlockers $script:EngineDirectory @(Get-CimInstance Win32_Process -Filter "Name='node.exe'"))
if ($blockers.Count) {
  throw ("Cleanup blocked before deleting any files:`n  "+($blockers -join "`n  ")+"`nStop the listed processes. For a deck-root lock, confirm its export has stopped before removing that lock.")
}
# File-by-file deletion; only empty directories are removed, never recursive deletion.
foreach ($file in $files) {
  $absolute=[IO.Path]::GetFullPath($file.FullName)
  if (-not $absolute.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'File escapes workspace' }
  Remove-Item -LiteralPath $absolute -Force
}
foreach ($path in ($directories | Sort-Object Length -Descending -Unique)) {
  if ((Test-Path -LiteralPath $path) -and @(Get-ChildItem -LiteralPath $path -Force).Count -eq 0) { Remove-Item -LiteralPath $path -Force }
}
Write-Output 'Cleanup finished. All versions of PDF/editable PPTX and current sources remain.'
