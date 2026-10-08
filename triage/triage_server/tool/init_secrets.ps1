$ErrorActionPreference = 'Stop'
$serverRoot = Split-Path $PSScriptRoot -Parent
$target = Join-Path $serverRoot 'config/passwords.yaml'
if (Test-Path -LiteralPath $target) {
    Write-Host 'Existing local passwords.yaml retained.'
    return
}
$lines = [System.Collections.Generic.List[string]]::new()
foreach ($mode in @('development', 'test', 'staging', 'production')) {
    $lines.Add("${mode}:")
    foreach ($key in @('database', 'serviceSecret', 'emailSecretHashPepper', 'jwtRefreshTokenHashPepper', 'jwtHmacSha512PrivateKey')) {
        $secretBytes = New-Object byte[] 64
        $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        try { $random.GetBytes($secretBytes) } finally { $random.Dispose() }
        $secret = [Convert]::ToBase64String($secretBytes)
        $lines.Add("  ${key}: '$secret'")
    }
    $lines.Add('')
}
$lines | Set-Content -LiteralPath $target -Encoding utf8
Write-Host 'Generated local secrets in ignored config/passwords.yaml. Secret values were not printed.'
