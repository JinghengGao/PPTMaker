param([Parameter(Mandatory=$true)][string]$InputFile,[Parameter(Mandatory=$true)][string]$OutputDirectory,[int]$Width=1600,[switch]$ExitAfterRendering)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Pdf.PdfPageRenderOptions,Windows.Data.Pdf,ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.Streams.InMemoryRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime] | Out-Null
$genericAsTask=[System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1} | Select-Object -First 1
$actionAsTask=[System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and -not $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'} | Select-Object -First 1
function Await-Result($Operation,[Type]$ResultType){ $task=$genericAsTask.MakeGenericMethod($ResultType).Invoke($null,@($Operation)); $task.GetAwaiter().GetResult() }
function Await-Action($Operation){ $task=$actionAsTask.Invoke($null,@($Operation)); [void]$task.GetAwaiter().GetResult() }
$source=(Resolve-Path -LiteralPath $InputFile).Path
$file=Await-Result ([Windows.Storage.StorageFile]::GetFileFromPathAsync($source)) ([Windows.Storage.StorageFile])
$pdf=Await-Result ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$records=@()
for($i=0;$i -lt $pdf.PageCount;$i++){
  $page=$pdf.GetPage([uint32]$i)
  $options=New-Object Windows.Data.Pdf.PdfPageRenderOptions
  $options.DestinationWidth=[uint32]$Width
  $stream=New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
  Await-Action ($page.RenderToStreamAsync($stream,$options))
  $stream.Seek(0)
  $input=[System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
  $output=Join-Path $OutputDirectory ('slide-{0:D2}.png' -f ($i+1))
  $disk=[IO.File]::Create([IO.Path]::GetFullPath($output))
  $input.CopyTo($disk);$disk.Dispose();$input.Dispose();$stream.Dispose()
  $records+=@{page=$i+1;width=$page.Size.Width;height=$page.Size.Height;png=$output}
  $page.Dispose();Write-Output ('Rendered PDF page {0}/{1}' -f ($i+1),$pdf.PageCount)
}
@{renderer='Windows.Data.Pdf';input=$source;page_count=$pdf.PageCount;pages=$records} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'pdf-inspection.json') -Encoding UTF8
# Standalone worker only: some WinRT PDF finalizers stall PowerShell shutdown.
# Exit only after every page and the complete inspection record are written.
if ($ExitAfterRendering) { [Console]::Out.Flush(); [Environment]::Exit(0) }
