param([switch]$SkipAudio, [switch]$Native)
$ErrorActionPreference = 'Stop'
$spikeRoot = Split-Path $PSScriptRoot -Parent
$modelDir = Join-Path $spikeRoot 'web/models'
$vendorDir = Join-Path $spikeRoot 'web/vendor'
New-Item -ItemType Directory -Force $modelDir, $vendorDir | Out-Null
# Immutable revisions: update deliberately and rerun the benchmark on any change.
$needleRevision = '2ae11323dc000f5e70c49f7403efa6af12ba9e67'
$whistleRevision = 'b358ddadd89b7a713b5aa131f23032d3cca1b251'
$files = @(
    @{ repo='needle3'; revision=$needleRevision; source='wasm/needle.js'; target=(Join-Path $vendorDir 'needle.js') },
    @{ repo='needle3'; revision=$needleRevision; source='wasm/needle.wasm'; target=(Join-Path $vendorDir 'needle.wasm') },
    @{ repo='needle3'; revision=$needleRevision; source='needle3.cact'; target=(Join-Path $modelDir 'needle3.cact') },
    @{ repo='whistle'; revision=$whistleRevision; source='whistle.cact'; target=(Join-Path $modelDir 'whistle.cact') }
)
$lock = Get-Content -LiteralPath (Join-Path $spikeRoot 'assets/runtime.lock.json') -Raw | ConvertFrom-Json
$manifest = foreach ($entry in $files) {
    $url = "https://huggingface.co/Cactus-Compute/$($entry.repo)/resolve/$($entry.revision)/$($entry.source)"
    Write-Host "Checking $($entry.source)"
    if (-not (Test-Path -LiteralPath $entry.target)) { Invoke-WebRequest $url -OutFile $entry.target }
    $relativePath = $entry.target.Substring($spikeRoot.Length + 1).Replace('\','/')
    $digest = (Get-FileHash $entry.target -Algorithm SHA256).Hash.ToLower()
    $expected = ($lock | Where-Object path -eq $relativePath).sha256
    if ($digest -ne $expected) { throw "Checksum mismatch for $relativePath. Move the invalid file aside and rerun setup." }
    [ordered]@{ source=$url; path=$relativePath; bytes=(Get-Item $entry.target).Length; sha256=$digest }
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $vendorDir 'manifest.json') -Encoding utf8
if ($Native) {
    $nativeDir = Join-Path (Split-Path $spikeRoot -Parent) '.spike-cache/native'
    New-Item -ItemType Directory -Force $nativeDir | Out-Null
    $wheel = Join-Path $nativeDir 'cactus_needle-3.2.0-py3-none-win_amd64.whl'
    if (-not (Test-Path -LiteralPath $wheel)) {
        Invoke-WebRequest "https://huggingface.co/Cactus-Compute/needle3/resolve/$needleRevision/python/cactus_needle-3.2.0-py3-none-win_amd64.whl" -OutFile $wheel
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($wheel)
    try {
        $entry = $archive.GetEntry('needle/libneedle3.dll')
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $nativeDir 'libneedle3.dll'), $true)
    } finally { $archive.Dispose() }
}
if (-not $SkipAudio) { & (Join-Path $PSScriptRoot 'make_audio.ps1') }
