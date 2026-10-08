$ErrorActionPreference = 'Stop'
$appRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = [IO.Path]::GetFullPath((Join-Path $appRoot '../..'))
$flutter = Join-Path $repoRoot '.spike-cache/flutter/bin/flutter.bat'
Push-Location $appRoot
try {
  & $flutter build web --no-web-resources-cdn
  if ($LASTEXITCODE -ne 0) { throw "Flutter web build failed with exit code $LASTEXITCODE." }
} finally {
  Pop-Location
}
$wasm = Join-Path $appRoot 'web/RedactWeb.wasm'
$output = Join-Path $appRoot 'build/web/RedactWeb.wasm'
if (!(Test-Path -LiteralPath $wasm)) { throw 'Run tool/prepare_web.ps1 before building the web app.' }
Copy-Item -LiteralPath $wasm -Destination $output -Force
Write-Output 'Built Flutter web app and copied the Desert Ant Redact WASM runtime.'
