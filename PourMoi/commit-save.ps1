$ErrorActionPreference = "Stop"

$player      = "Norodio"
$repoPath    = "C:\JAVA_Projet\MoonSweeper-Sync"
$savePath    = "C:\Users\tomar\AppData\LocalLow\DragDropGames\MoonSweepers\MoonSessions"
$slot        = "slot-5"
$processName = "MoonSweepers"

function Invoke-Git {
    & git.exe @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') a echoue (code $LASTEXITCODE)" }
}

try {
    if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
        throw "Le jeu est ouvert. Ferme-le, puis relance ce script."
    }

    $gameSlot = Join-Path $savePath $slot
    if (-not (Test-Path (Join-Path $gameSlot "slot.json"))) {
        throw "Sauvegarde introuvable : $gameSlot\slot.json"
    }

    Set-Location $repoPath
    Invoke-Git pull --rebase origin main

    Write-Host "Copie de la sauvegarde vers le depot..."
    robocopy $gameSlot (Join-Path $repoPath $slot) /MIR /XD backups slot-5 /XF *.bak /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "La copie vers le depot a echoue." }
    $global:LASTEXITCODE = 0

    Invoke-Git add -A
    if (& git.exe status --porcelain) {
        Invoke-Git commit -m "Initial clean save by $player"
        try {
            Invoke-Git push origin main
        } catch {
            Invoke-Git pull --rebase origin main
            Invoke-Git push origin main
        }
        Write-Host "Sauvegarde envoyee. Previens ton ami." -ForegroundColor Green
    } else {
        Write-Host "Rien de nouveau a envoyer."
    }
}
catch {
    Write-Host "ERREUR : $_" -ForegroundColor Red
}

Read-Host "Appuie sur Entree pour fermer"