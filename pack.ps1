# Pack Magisk zip WITHOUT binary (script-only / debug).
# For release with bundled binary, use: .\build-release.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root "dist"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$out = Join-Path $outDir "ddns-go-android-nocore.zip"
if (Test-Path $out) { Remove-Item $out -Force }
Write-Host "[WARN] packing script-only zip (no binary). Prefer build-release.ps1"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$entries = @(
  "module.prop",
  "customize.sh",
  "service.sh",
  "uninstall.sh",
  "README.md",
  "META-INF/com/google/android/update-binary",
  "META-INF/com/google/android/updater-script",
  "dg/dg.sh",
  "dg/start.sh",
  "dg/stop.sh",
  "dg/restart.sh",
  "dg/update.sh",
  "dg/menu.sh"
)

$zip = [System.IO.Compression.ZipFile]::Open($out, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($rel in $entries) {
    $src = Join-Path $root ($rel -replace '/', '\')
    if (-not (Test-Path $src)) { throw "missing: $src" }
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
      $zip, $src, $rel, [System.IO.Compression.CompressionLevel]::Optimal)
  }
} finally {
  $zip.Dispose()
}

Write-Host "OK: $out"
