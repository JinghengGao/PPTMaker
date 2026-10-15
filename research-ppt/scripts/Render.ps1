# Internal worker: run with powershell.exe -File, never dot-source this script.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][ValidateSet('Pdf','PowerPoint')][string]$Format,
  [Parameter(Mandatory=$true)][string]$InputFile,
  [Parameter(Mandatory=$true)][string]$OutputDirectory,
  [ValidateRange(320,3840)][int]$Width = 1600
)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $InputFile).Path
$target = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $target -Force | Out-Null

if ($Format -eq 'Pdf') {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
  [Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime] | Out-Null
  [Windows.Data.Pdf.PdfPageRenderOptions,Windows.Data.Pdf,ContentType=WindowsRuntime] | Out-Null
  [Windows.Storage.Streams.InMemoryRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime] | Out-Null
  $genericAsTask=[System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1} | Select-Object -First 1
  $actionAsTask=[System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and -not $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'} | Select-Object -First 1
  function Await-Result($Operation,[Type]$ResultType){ $task=$genericAsTask.MakeGenericMethod($ResultType).Invoke($null,@($Operation)); $task.GetAwaiter().GetResult() }
  function Await-Action($Operation){ $task=$actionAsTask.Invoke($null,@($Operation)); [void]$task.GetAwaiter().GetResult() }
  $file=Await-Result ([Windows.Storage.StorageFile]::GetFileFromPathAsync($source)) ([Windows.Storage.StorageFile])
  $pdf=Await-Result ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
  $records=@()
  for($i=0;$i -lt $pdf.PageCount;$i++){
    $page=$pdf.GetPage([uint32]$i)
    $options=New-Object Windows.Data.Pdf.PdfPageRenderOptions
    $options.DestinationWidth=[uint32]$Width
    $stream=New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
    Await-Action ($page.RenderToStreamAsync($stream,$options))
    $stream.Seek(0)
    $input=[System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
    $output=Join-Path $target ('slide-{0:D2}.png' -f ($i+1))
    $disk=[IO.File]::Create([IO.Path]::GetFullPath($output))
    $input.CopyTo($disk);$disk.Dispose();$input.Dispose();$stream.Dispose()
    $records+=@{page=$i+1;width=$page.Size.Width;height=$page.Size.Height;png=$output}
    $page.Dispose();Write-Output ('Rendered PDF page {0}/{1}' -f ($i+1),$pdf.PageCount)
  }
  @{renderer='Windows.Data.Pdf';input=$source;page_count=$pdf.PageCount;pages=$records} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $target 'pdf-inspection.json') -Encoding UTF8
  # Avoid a WinRT finalizer hang after all pages and the record are written.
  [Console]::Out.Flush()
  [Environment]::Exit(0)
}

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
  $record = [ordered]@{renderer='Microsoft PowerPoint';version=$app.Version;input=$source;sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash;slide_count=$deck.Slides.Count;width_pt=$deck.PageSetup.SlideWidth;height_pt=$deck.PageSetup.SlideHeight;png_width=$Width;png_height=$height;pages=$pages}
  $record | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $target 'powerpoint-inspection.json') -Encoding UTF8
} finally {
  if ($deck) { $deck.Close(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($deck) }
  if ($app) { if ($app.Presentations.Count -eq 0) { $app.Quit() }; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($app) }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
