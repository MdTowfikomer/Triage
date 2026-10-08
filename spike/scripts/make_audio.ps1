$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$spikeRoot = Split-Path $PSScriptRoot -Parent
$audioDir = Join-Path $spikeRoot 'assets/audio'
New-Item -ItemType Directory -Force $audioDir | Out-Null
$utterances = Get-Content -LiteralPath (Join-Path $spikeRoot 'assets/utterances.json') -Raw | ConvertFrom-Json
$synth = [System.Speech.Synthesis.SpeechSynthesizer]::new()
$format = [System.Speech.AudioFormat.SpeechAudioFormatInfo]::new(16000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
try {
    for ($i = 0; $i -lt $utterances.Count; $i++) {
        $target = Join-Path $audioDir ('{0:00}.wav' -f ($i + 1))
        $synth.SetOutputToWaveFile($target, $format)
        $synth.Speak($utterances[$i])
        $synth.SetOutputToNull()
    }
    [ordered]@{ kind='synthetic speech, not human microphone recordings'; voice=$synth.Voice.Name; rate=16000; channels=1; bits=16; utterances=$utterances } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $audioDir 'manifest.json') -Encoding utf8
} finally { $synth.Dispose() }
