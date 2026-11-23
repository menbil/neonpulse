# Script PowerShell pour régénérer toutes les beatmaps avec generate_beatmap_v4.py
# Usage: .\regenerate_beatmaps.ps1 [easy|normal|hard|expert|all]

param(
    [string]$Difficulty = "all"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🎵 NeonPulse Beatmap Regenerator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$dataPath = Join-Path $scriptPath "data"
$trackFolders = Get-ChildItem -Path $dataPath -Directory

foreach ($folder in $trackFolders) {
    $trackPath = $folder.FullName
    $audioFile = Get-ChildItem -Path $trackPath -Include "*.ogg", "*.mp3", "*.wav" -File | Select-Object -First 1

    if ($audioFile) {
        Write-Host "🎧 Traitement de: $($folder.Name) ($($audioFile.Name))" -ForegroundColor Green
        $outputPath = if ($Difficulty -eq "all") { $trackPath } else { Join-Path $trackPath "beatmap_$Difficulty.json" }
        $pythonCmd = "python `"$scriptPath\generate_beatmap_v4.py`" `"$($audioFile.FullName)`" `"$outputPath`" $Difficulty"
        Invoke-Expression $pythonCmd
    } else {
        Write-Host "⚠️ Pas de fichier audio dans: $($folder.Name)" -ForegroundColor Yellow
    }
}

Write-Host "🎉 Terminé!" -ForegroundColor Cyan
