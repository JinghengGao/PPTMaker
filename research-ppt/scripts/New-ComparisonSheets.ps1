param([Parameter(Mandatory=$true)][string]$ReferenceDirectory,[Parameter(Mandatory=$true)][string]$DeckDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$maps=Get-Content -LiteralPath (Join-Path $DeckDirectory 'comparison-map.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$target=Join-Path $DeckDirectory 'screenshots/comparisons'
New-Item -ItemType Directory -Path $target -Force | Out-Null
$font=New-Object Drawing.Font('Microsoft YaHei',13)
foreach($map in $maps){
  $bmp=New-Object Drawing.Bitmap(1600,490)
  $g=[Drawing.Graphics]::FromImage($bmp);$g.Clear([Drawing.Color]::FromArgb(240,240,240))
  $left=Join-Path $ReferenceDirectory ('slide-{0:D2}.png' -f $map.reference)
  $right=Join-Path $DeckDirectory ('screenshots/slide-{0:D2}.png' -f $map.example)
  $a=[Drawing.Image]::FromFile((Resolve-Path -LiteralPath $left));$b=[Drawing.Image]::FromFile((Resolve-Path -LiteralPath $right))
  $g.DrawString(('Reference {0:D2}' -f $map.reference),$font,[Drawing.Brushes]::Black,12,9)
  $g.DrawString(('Example {0:D2}  {1}' -f $map.example,$map.note),$font,[Drawing.Brushes]::Black,812,9)
  $g.DrawImage($a,0,40,800,450);$g.DrawImage($b,800,40,800,450)
  $out=Join-Path $target ('example-{0:D2}-reference-{1:D2}.png' -f $map.example,$map.reference)
  $bmp.Save([IO.Path]::GetFullPath($out),[Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose();$bmp.Dispose();$a.Dispose();$b.Dispose();Write-Output $out
}
$font.Dispose()
