$ErrorActionPreference = "Stop"

# ---------- A ADAPTER : le pseudo de ton ami (different de Norodio) ----------
$player = "Viito"

# ---------- Configuration ----------
$repoUrl     = "https://github.com/Norodio/MoonSweeper-Sync.git"
$repoPath    = "E:\Codes\MoonSweeper-Sync"
$savePath    = "C:\Users\User\AppData\LocalLow\DragDropGames\MoonSweepers\MoonSessions"
$slot        = "slot-5"
$processName = "MoonSweepers"

function Invoke-Git {
    & git.exe @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') a echoue (code $LASTEXITCODE)" }
}

try {
    Write-Host "=== Installation MoonSweeper Sync ===" -ForegroundColor Cyan

    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        throw "Git n'est pas installe (ou pas dans le PATH)."
    }
    if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
        throw "Le jeu est ouvert. Ferme-le, puis relance ce script."
    }

    # --- 1. Copie de securite de son dossier de jeu actuel (si present) ---
    $gameSlot = Join-Path $savePath $slot
    if (Test-Path $gameSlot) {
        $backup = Join-Path ([Environment]::GetFolderPath("Desktop")) ("MoonSweeper-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        Write-Host "Copie de securite vers $backup ..."
        robocopy $gameSlot $backup /E /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "La copie de securite a echoue." }
        $global:LASTEXITCODE = 0
    }

    # --- 2. Depot git ---
    if (Test-Path (Join-Path $repoPath ".git")) {
        Write-Host "Depot existant : mise a jour..."
        Set-Location $repoPath
        Invoke-Git fetch origin
        Invoke-Git checkout main
        Invoke-Git reset --hard origin/main
    } else {
        Write-Host "Clonage du depot..."
        Invoke-Git clone $repoUrl $repoPath
        Set-Location $repoPath
    }

    if (-not (Test-Path (Join-Path $repoPath "$slot\slot.json"))) {
        throw "La sauvegarde n'est pas encore dans le depot. Attends que Norodio ait fini, puis relance."
    }

    # Identite git si elle n'est pas deja configuree
    if (-not (& git.exe config user.name))  { Invoke-Git config user.name $player }
    if (-not (& git.exe config user.email)) { Invoke-Git config user.email "$player@users.noreply.github.com" }

    # --- 3. Fichier .env ---
    @(
        "REPO_PATH=$repoPath",
        "SAVE_PATH=$savePath",
        "SAVE_SLOT=$slot",
        "PROCESS_NAME=$processName",
        "PLAYER_NAME=$player"
    ) | Set-Content (Join-Path $repoPath ".env") -Encoding UTF8
    Write-Host ".env cree."

    Write-Host ""
    Write-Host "TERMINE !" -ForegroundColor Green
    Write-Host "Dans Steam : clic droit sur Moon Sweeper > Proprietes > Options de lancement, colle :"
    Write-Host ""
    Write-Host "powershell -ExecutionPolicy Bypass -File `"$repoPath\script.ps1`" -game %command%" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Au premier lancement, la sauvegarde du depot remplacera celle du dossier de jeu."
}
catch {
    Write-Host ""
    Write-Host "ERREUR : $_" -ForegroundColor Red
}

Read-Host "Appuie sur Entree pour fermer"