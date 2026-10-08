param([switch]$DownloadModels)
$ErrorActionPreference = 'Stop'
$appRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = [IO.Path]::GetFullPath((Join-Path $appRoot '../..'))
$spikeRoot = Join-Path $repoRoot 'spike'
New-Item -ItemType Directory -Force -Path (Join-Path $spikeRoot 'assets/audio') | Out-Null
if ($DownloadModels) { & (Join-Path $spikeRoot 'scripts/setup.ps1') }
New-Item -ItemType Directory -Force -Path (Join-Path $appRoot 'assets/fonts') | Out-Null
Copy-Item -LiteralPath (Join-Path $spikeRoot 'assets/tools.json') -Destination (Join-Path $appRoot 'assets/tools.json')
foreach ($file in @('bridge.js', 'engine.js', 'needle_worker.js')) {
  Copy-Item -LiteralPath (Join-Path $spikeRoot "web/$file") -Destination (Join-Path $appRoot "web/$file")
}
foreach ($folder in @('vendor', 'models')) {
  $sourcePath = Join-Path $spikeRoot "web/$folder"
  if (!(Test-Path -LiteralPath $sourcePath)) { throw 'Run tool/prepare_web.ps1 -DownloadModels first.' }
  Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $appRoot 'web') -Recurse -Force
}
$redactRoot = Join-Path $appRoot 'tool/redact'
Push-Location $redactRoot
try {
  npm ci
  npm run build
} finally {
  Pop-Location
}
$litertWasm = Join-Path $redactRoot 'node_modules/@litertjs/core/wasm'
if (!(Test-Path -LiteralPath $litertWasm)) { throw 'LiteRT.js WASM assets are missing after npm ci.' }
$redactWasm = Join-Path $redactRoot 'node_modules/@desert-ant-labs/redact/dist/RedactWeb.wasm'
if (!(Test-Path -LiteralPath $redactWasm)) { throw 'Desert Ant Redact WASM asset is missing after npm ci.' }
$webRoot = Join-Path $appRoot 'web'
Copy-Item -LiteralPath $redactWasm -Destination $webRoot -Force
$litertDestination = Join-Path $appRoot 'web/vendor/litert'
New-Item -ItemType Directory -Force -Path $litertDestination | Out-Null
Get-ChildItem -LiteralPath $litertWasm -Force | Copy-Item -Destination $litertDestination -Recurse -Force
$fontPath = Join-Path $appRoot 'assets/fonts/Inter.ttf'
if (!(Test-Path -LiteralPath $fontPath)) {
  Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf' -OutFile $fontPath
  Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/google/fonts/main/ofl/inter/OFL.txt' -OutFile (Join-Path $appRoot 'assets/fonts/OFL.txt')
}
$emojiPath = Join-Path $appRoot 'assets/fonts/NotoEmoji.ttf'
if (!(Test-Path -LiteralPath $emojiPath)) {
  Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/google/fonts/main/ofl/notoemoji/NotoEmoji%5Bwght%5D.ttf' -OutFile $emojiPath
  Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/google/fonts/main/ofl/notoemoji/OFL.txt' -OutFile (Join-Path $appRoot 'assets/fonts/NotoEmoji-OFL.txt')
}
& (Join-Path $appRoot 'tool/prepare_android_voice.ps1')
Write-Output 'Prepared Needle/Redact assets and bundled fonts. No runtime font CDN needed.'
