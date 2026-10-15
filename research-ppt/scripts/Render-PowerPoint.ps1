param(
  [Parameter(Mandatory=$true)][string]$InputFile,
  [Parameter(Mandatory=$true)][string]$OutputDirectory,
  [int]$Width = 1600,
  [switch]$ExportPdf
)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $InputFile).Path
$target = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $target -Force | Out-Null
$app = $null
$deck = $null
try {
  $app = New-Object -ComObject PowerPoint.Application
  $deck = $app.Presentations.Open($source, -1, 0, 0)
  $height = [int][Math]::Round($Width * $deck.PageSetup.SlideHeight / $deck.PageSetup.SlideWidth)
  $pages = @()
  for ($i=1; $i -le $deck.Slides.Count; $i++) {
    $slide = $deck.Slides.Item($i)
    $file = Join-Path $target ('slide-{0:D2}.png' -f $i)
    $slide.Export($file, 'PNG', $Width, $height)
    $objects = @()
    foreach ($shape in $slide.Shapes) {
      $item = [ordered]@{name=$shape.Name;type=[int]$shape.Type;x=[Math]::Round($shape.Left,2);y=[Math]::Round($shape.Top,2);width=[Math]::Round($shape.Width,2);height=[Math]::Round($shape.Height,2)}
      try {
        if ($shape.HasTextFrame -and $shape.TextFrame.HasText) {
          $range = $shape.TextFrame.TextRange
          $item.text = $range.Text
          $item.font = $range.Font.Name
          $item.font_far_east = $range.Font.NameFarEast
          $item.font_size = $range.Font.Size
          $item.font_color_rgb = $range.Font.Color.RGB
          $item.bold = [int]$range.Font.Bold
          $item.margin_left = $shape.TextFrame.MarginLeft
          $item.margin_top = $shape.TextFrame.MarginTop
        }
        $item.fill_rgb = $shape.Fill.ForeColor.RGB
        $item.line_rgb = $shape.Line.ForeColor.RGB
        $item.line_weight = $shape.Line.Weight
      } catch { $item.property_warning = $_.Exception.Message }
      $objects += $item
    }
    $pages += [ordered]@{page=$i;layout=$slide.CustomLayout.Name;hidden=[int]$slide.SlideShowTransition.Hidden;shapes=$objects}
    Write-Output ('Rendered {0}/{1}: {2}' -f $i,$deck.Slides.Count,$file)
  }
  if ($ExportPdf) { $deck.SaveAs((Join-Path $target 'reference.pdf'), 32) }
  $record = [ordered]@{renderer='Microsoft PowerPoint';version=$app.Version;input=$source;sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash;slide_count=$deck.Slides.Count;width_pt=$deck.PageSetup.SlideWidth;height_pt=$deck.PageSetup.SlideHeight;png_width=$Width;png_height=$height;pages=$pages}
  $record | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $target 'powerpoint-inspection.json') -Encoding UTF8
} finally {
  if ($deck) { $deck.Close(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($deck) }
  if ($app) { if ($app.Presentations.Count -eq 0) { $app.Quit() }; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($app) }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
