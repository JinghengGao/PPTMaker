param([Parameter(Mandatory=$true)][string]$InputDirectory,[Parameter(Mandatory=$true)][string]$OutputDirectory,[int]$PerSheet=4,[int]$ThumbWidth=800)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$files=@(Get-ChildItem -LiteralPath $InputDirectory -Filter 'slide-*.png' | Sort-Object Name)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$font=New-Object Drawing.Font('Arial',14)
for($start=0;$start -lt $files.Count;$start+=$PerSheet){
  $count=[Math]::Min($PerSheet,$files.Count-$start)
  $rows=[int][Math]::Ceiling($count/2)
  $thumbHeight=[int]($ThumbWidth*9/16)
  $bitmap=New-Object Drawing.Bitmap(($ThumbWidth*2),($rows*($thumbHeight+32)))
  $g=[Drawing.Graphics]::FromImage($bitmap)
  $g.Clear([Drawing.Color]::FromArgb(235,235,235))
  for($j=0;$j -lt $count;$j++){
    $x=($j%2)*$ThumbWidth; $y=[Math]::Floor($j/2)*($thumbHeight+32)
    $img=[Drawing.Image]::FromFile($files[$start+$j].FullName)
    $g.DrawString($files[$start+$j].Name,$font,[Drawing.Brushes]::Black,[single]($x+10),[single]($y+6))
    $g.DrawImage($img,[int]$x,[int]($y+32),$ThumbWidth,$thumbHeight)
    $img.Dispose()
  }
  $out=Join-Path $OutputDirectory ('contact-{0:D2}.png' -f ([int]($start/$PerSheet)+1))
  $bitmap.Save($out,[Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose();$bitmap.Dispose()
  Write-Output $out
}
$font.Dispose()
