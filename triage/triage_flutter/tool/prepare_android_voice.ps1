$ErrorActionPreference = 'Stop'
$appRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = [IO.Path]::GetFullPath((Join-Path $appRoot '../..'))
$sourceRoot = Join-Path $repoRoot 'spike/web'
$destination = Join-Path $appRoot 'assets/voice_engine'

foreach ($required in @(
  'engine.js', 'needle_worker.js', 'vendor/needle.js', 'vendor/needle.wasm',
  'models/needle3.cact', 'models/whistle.cact'
)) {
  if (!(Test-Path -LiteralPath (Join-Path $sourceRoot $required))) {
    throw "Missing $required. Run tool/prepare_web.ps1 -DownloadModels first."
  }
}

New-Item -ItemType Directory -Force -Path $destination | Out-Null
foreach ($file in @('engine.js', 'vendor/needle.js', 'vendor/needle.wasm', 'models/needle3.cact', 'models/whistle.cact')) {
  $target = Join-Path $destination $file
  New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
  Copy-Item -LiteralPath (Join-Path $sourceRoot $file) -Destination $target -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../web/android_voice/needle_worker.js') -Destination (Join-Path $destination 'needle_worker.js') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../web/android_voice/index.html') -Destination (Join-Path $destination 'index.html') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../web/android_voice/android_bridge.js') -Destination (Join-Path $destination 'android_bridge.js') -Force
New-Item -ItemType Directory -Force -Path (Join-Path $destination 'assets') | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot 'spike/assets/tools.json') -Destination (Join-Path $destination 'assets/tools.json') -Force

Write-Output 'Prepared bundled Android Needle/Whistle WASM engine assets.'
