# Shared path and configuration rules. Keep compatible with Windows PowerShell 5.1.
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

function Assert-EngineDependencies {
  if (-not (Test-Path -LiteralPath (Join-Path $script:EngineDirectory 'node_modules/@slidev/cli/package.json'))) { throw 'Slidev is missing. Run npm.cmd ci in research-ppt.' }
  [void](Get-Command node -ErrorAction Stop)
  [void](Get-Command npx.cmd -ErrorAction Stop)
}

function Get-CleanupBlockers([string]$EngineDirectory, [object[]]$NodeProcesses) {
  $enginePrefix=[IO.Path]::GetFullPath($EngineDirectory).Replace('\','/').TrimEnd('/')+'/'
  foreach ($process in $NodeProcesses) {
    $command=$process.CommandLine
    if ($command -and $command.Replace('\','/').IndexOf($enginePrefix,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and $command -match 'slidev') {
      Write-Output "Slidev process PID=$($process.ProcessId): $command"
    }
  }
  # Export-Deck creates its lock directly in the deck directory. Locks inside
  # archives, snapshots and test fixtures are historical files, not active locks.
  foreach ($deck in Get-ChildItem -LiteralPath (Join-Path $EngineDirectory 'decks') -Directory) {
    $lock=Join-Path $deck.FullName '.export.lock'
    if (Test-Path -LiteralPath $lock) { Write-Output "Export lock: $lock" }
  }
}

function Remove-GeneratedPath([string]$Path, [string]$ParentDirectory) {
  Assert-WithinDirectory $Path $ParentDirectory
  if (Test-Path -LiteralPath $Path) {
    $links=Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction Stop | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }
    if ($links) { throw "Refusing to recursively delete linked content: $Path" }
    Remove-Item -LiteralPath ([IO.Path]::GetFullPath($Path)) -Recurse -Force
  }
}
