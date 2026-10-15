[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Workspace.ps1')
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
  & node (Join-Path $PSScriptRoot 'doctor.mjs')
  if ($LASTEXITCODE -ne 0) { $failed = $true }
} finally { Pop-Location }
if ([Type]::GetTypeFromProgID('PowerPoint.Application')) { Write-Output '[OPTIONAL OK] PowerPoint registered; Check verifies actual rendering.' }
else { Write-Output '[OPTIONAL MISSING] PowerPoint: PPTX native rendering will be skipped.' }
if ($failed) { throw 'Required environment checks failed. See README.md.' }
