# Build Magisk zips with ddns-go for Android.
# Output:
#   dist/ddns-go-android-arm64.zip   # official GitHub android_arm64 asset
#   dist/ddns-go-android-armv7a.zip  # self-built GOOS=android GOARCH=arm GOARM=7
#                                   # (upstream does not publish android_arm)
#
# Usage:
#   .\build-release.ps1
#   .\build-release.ps1 -CoreVer v6.17.2
#   .\build-release.ps1 -Proxy https://ghfast.top/

param(
  [string]$CoreVer = "",
  [string]$Proxy = "",
  [string]$CoreRepo = "jeessy2/ddns-go",
  [string]$ModuleVer = "v1.0.0",
  [int]$ModuleCode = 100
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $root "dist"
$work = Join-Path $root ".build"
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
if (Test-Path $dist) { Remove-Item -Recurse -Force $dist }
New-Item -ItemType Directory -Path $work, $dist -Force | Out-Null

function Normalize-Proxy([string]$raw) {
  if ([string]::IsNullOrWhiteSpace($raw)) { return "" }
  $raw = $raw.Trim()
  if ($raw -match '^https?://') {
    return ($raw.TrimEnd('/') + '/')
  }
  if ($raw.StartsWith('//')) {
    return ('https://' + $raw.TrimStart('/').TrimEnd('/') + '/')
  }
  return ('https://' + $raw.TrimStart('/').TrimEnd('/') + '/')
}

function Build-Url([string]$ghUrl, [string]$proxy) {
  if ([string]::IsNullOrEmpty($proxy)) { return $ghUrl }
  return ($proxy + $ghUrl)
}

function Download-File([string]$url, [string]$out) {
  Write-Host "[*] download $url"
  & curl.exe -fL --retry 3 --retry-delay 2 -A "ddns-go-magisk-build" -o $out $url
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out) -or (Get-Item $out).Length -le 0) {
    throw "download failed: $url"
  }
}

function To-UnixPath([string]$p) {
  return (($p -replace '\\', '/') -replace '^([A-Za-z]):', '/$1')
}

function Resolve-LatestTag([string]$proxy) {
  $api = "https://api.github.com/repos/$CoreRepo/releases/latest"
  $apiUrl = Build-Url $api $proxy
  $json = & curl.exe -fsSL -A "ddns-go-magisk-build" $apiUrl 2>$null
  if (-not $json) { return $null }
  if ($json -match '"tag_name"\s*:\s*"(v[^"]+)"') {
    return $Matches[1]
  }
  return $null
}

function New-ZipFromDir([string]$stageDir, [string]$zipOut) {
  if (Test-Path $zipOut) { Remove-Item $zipOut -Force }
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::Open($zipOut, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    $files = Get-ChildItem -Path $stageDir -Recurse -File
    foreach ($file in $files) {
      $rel = $file.FullName.Substring($stageDir.Length).TrimStart('\', '/').Replace('\', '/')
      [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, $file.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal)
    }
  } finally {
    $zip.Dispose()
  }
}

function Pack-Module([string]$abi, [string]$coreArch, [string]$sourceNote, [string]$binPath) {
  $stage = Join-Path $work "stage-$abi"
  if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
  New-Item -ItemType Directory -Path (Join-Path $stage "META-INF\com\google\android"), (Join-Path $stage "dg\bin") -Force | Out-Null

  Copy-Item (Join-Path $root "customize.sh") $stage
  Copy-Item (Join-Path $root "service.sh") $stage
  Copy-Item (Join-Path $root "uninstall.sh") $stage
  Copy-Item (Join-Path $root "README.md") $stage
  Copy-Item (Join-Path $root "META-INF\com\google\android\update-binary") (Join-Path $stage "META-INF\com\google\android\")
  Copy-Item (Join-Path $root "META-INF\com\google\android\updater-script") (Join-Path $stage "META-INF\com\google\android\")
  foreach ($f in @("dg.sh", "start.sh", "stop.sh", "restart.sh", "update.sh", "menu.sh")) {
    Copy-Item (Join-Path $root "dg\$f") (Join-Path $stage "dg\")
  }
  Copy-Item $binPath (Join-Path $stage "dg\bin\ddns-go")

  # same Magisk id for both abis -> only one entry if reinstalled
  @"
id=ddns-go
name=ddns-go
version=$ModuleVer
versionCode=$ModuleCode
author=wcwq99
description=ddns-go Magisk abi=$abi. Core: $CoreRepo $CoreVer $coreArch. menu: /data/adb/ddns-go/menu.sh
"@ | Set-Content -Path (Join-Path $stage "module.prop") -Encoding ascii
  Add-Content -Path (Join-Path $stage "module.prop") -Value "" -Encoding ascii

  @"
core_repo=$CoreRepo
core_version=$CoreVer
core_arch=$coreArch
module_abi=$abi
bundled=1
source=$sourceNote
"@ | Set-Content -Path (Join-Path $stage "dg\core.version") -Encoding ascii

  $zipOut = Join-Path $dist "ddns-go-android-$abi.zip"
  New-ZipFromDir $stage $zipOut
  Write-Host "[OK] $zipOut ($((Get-Item $zipOut).Length) bytes)"
}

# ---- resolve version ----
$proxyNorm = Normalize-Proxy $Proxy

if ([string]::IsNullOrWhiteSpace($CoreVer) -or $CoreVer -eq "latest") {
  Write-Host "[*] resolve latest from GitHub..."
  $CoreVer = Resolve-LatestTag $proxyNorm
  if (-not $CoreVer -and [string]::IsNullOrEmpty($proxyNorm)) {
    $proxyNorm = "https://ghfast.top/"
    Write-Host "[WARN] direct failed, retry via $proxyNorm"
    $CoreVer = Resolve-LatestTag $proxyNorm
  }
  if (-not $CoreVer) { throw "cannot resolve latest core version" }
}

$verNum = $CoreVer.TrimStart('v')
$CoreVer = "v$verNum"
Write-Host "[*] module=$ModuleVer core=$CoreVer repo=$CoreRepo"

# ---- arm64: official GitHub android_arm64 ----
$asset = "ddns-go_${verNum}_android_arm64.tar.gz"
$ghUrl = "https://github.com/$CoreRepo/releases/download/$CoreVer/$asset"
$tgz = Join-Path $work $asset
try {
  Download-File (Build-Url $ghUrl $proxyNorm) $tgz
} catch {
  if ([string]::IsNullOrEmpty($proxyNorm)) {
    $proxyNorm = "https://ghfast.top/"
    Write-Host "[WARN] direct download failed, retry via $proxyNorm"
    Download-File (Build-Url $ghUrl $proxyNorm) $tgz
  } else {
    throw
  }
}

$extract = Join-Path $work "extract-arm64"
New-Item -ItemType Directory -Path $extract -Force | Out-Null
& tar -xzf (To-UnixPath $tgz) -C (To-UnixPath $extract)
if ($LASTEXITCODE -ne 0) { throw "tar extract failed: $tgz" }
$bin64 = Get-ChildItem -Path $extract -Recurse -Filter "ddns-go" -File | Select-Object -First 1
if (-not $bin64) { throw "ddns-go binary not found in $asset" }
Pack-Module "arm64" "android_arm64" "github_release_android_arm64" $bin64.FullName

# ---- armv7a: cross-compile GOOS=android GOARCH=arm GOARM=7 ----
# upstream goreleaser ignores android/arm; we build from source tag.
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
  throw "need Go toolchain to build armv7a (GOOS=android GOARCH=arm)"
}

$srcDir = Join-Path $work "src"
Write-Host "[*] clone $CoreRepo @$CoreVer for armv7a build..."
& git clone --depth 1 --branch $CoreVer "https://github.com/$CoreRepo.git" $srcDir
if ($LASTEXITCODE -ne 0) {
  # fallback proxy clone URL form is not standard for git; retry plain once more after fetch tags
  throw "git clone failed: $CoreRepo $CoreVer"
}

$bin32 = Join-Path $work "ddns-go-armv7a"
Write-Host "[*] go build android/arm GOARM=7 ..."
Push-Location $srcDir
try {
  $env:CGO_ENABLED = "0"
  $env:GOOS = "android"
  $env:GOARCH = "arm"
  $env:GOARM = "7"
  & go build -trimpath -ldflags "-s -w -X main.version=$CoreVer" -o $bin32 .
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $bin32)) {
    throw "go build android/arm failed"
  }
} finally {
  Pop-Location
  Remove-Item Env:CGO_ENABLED -ErrorAction SilentlyContinue
  Remove-Item Env:GOOS -ErrorAction SilentlyContinue
  Remove-Item Env:GOARCH -ErrorAction SilentlyContinue
  Remove-Item Env:GOARM -ErrorAction SilentlyContinue
}

# verify ELF arch if file available
$fileOut = & file $bin32 2>$null
if ($fileOut) { Write-Host "[*] $fileOut" }

Pack-Module "armv7a" "android_armv7" "self_build_goos_android_goarch_arm_goarm7" $bin32

# ---- manifest ----
@"
built_at=$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))
module_version=$ModuleVer
module_version_code=$ModuleCode
core_repo=$CoreRepo
core_version=$CoreVer
artifacts:
  ddns-go-android-arm64.zip   # official GitHub android_arm64
  ddns-go-android-armv7a.zip  # self-built GOOS=android GOARCH=arm GOARM=7
note: upstream only ships android_arm64. armv7a is cross-compiled from the same tag. Install only ONE abi package (same module id=ddns-go).
"@ | Set-Content -Path (Join-Path $dist "build-manifest.txt") -Encoding utf8

Write-Host ""
Write-Host "======== DONE ========"
Get-ChildItem (Join-Path $dist "ddns-go-android-*.zip") | Format-Table Name, Length -AutoSize
Get-Content (Join-Path $dist "build-manifest.txt")
