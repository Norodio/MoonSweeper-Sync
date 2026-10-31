param(
    [string]$game = "",           # optionnel : si fourni, le script lance le jeu
    [switch]$ForceUnlock          # ignore un verrou resté bloqué (crash, etc.)
)

$ErrorActionPreference = "Stop"

# ---------- Chargement du .env ----------
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) { throw "Fichier .env introuvable : $envFile" }

$config = @{}
Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
        $k, $v = $line -split "=", 2
        $config[$k.Trim()] = $v.Trim().Trim('"')
    }
}

foreach ($key in "REPO_PATH", "SAVE_PATH", "SAVE_SLOT", "PROCESS_NAME", "PLAYER_NAME") {
    if (-not $config[$key]) { throw "Variable manquante dans .env : $key" }
}

$repoPath    = $config["REPO_PATH"]
$saveSlot    = $config["SAVE_SLOT"]
$processName = $config["PROCESS_NAME"]
$player      = $config["PLAYER_NAME"]

$repoSlot = Join-Path $repoPath $saveSlot
$gameSlot = Join-Path $config["SAVE_PATH"] $saveSlot
$lockFile = Join-Path $repoPath "$saveSlot.lock.json"

# ---------- Fonctions ----------
function Git {
    & git.exe @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') a échoué (code $LASTEXITCODE)" }
}

function Sync-Folder($from, $to) {
    # /MIR = copie exacte ; backups/ et *.bak ne sont ni copiés ni supprimés
    robocopy $from $to /MIR /XD backups /XF *.bak /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy a échoué (code $LASTEXITCODE)" }
    $global:LASTEXITCODE = 0
}

# ---------- 1. Récupération + verrou + dépôt -> jeu ----------
try {
    Set-Location $repoPath
    Git pull --ff-only origin main

    if (Test-Path $lockFile) {
        $lock = Get-Content $lockFile -Raw | ConvertFrom-Json
        if ($lock.owner -ne $player -and -not $ForceUnlock) {
            throw "La sauvegarde est utilisée par $($lock.owner) depuis $($lock.since). (-ForceUnlock si le verrou est périmé)"
        }
    }

    @{ owner = $player; since = (Get-Date -Format "yyyy-MM-dd HH:mm") } |
        ConvertTo-Json | Set-Content $lockFile
    Git add $lockFile
    Git commit -m "Lock by $player"
    try {
        Git push origin main
    } catch {
        Git reset --hard HEAD~1
        throw "Impossible de poser le verrou (l'autre joueur a poussé en même temps). Relancez le jeu."
    }

    Sync-Folder $repoSlot $gameSlot
}
catch {
    # Le jeu a déjà été lancé par Steam : on le ferme pour ne pas jouer sans verrou
    Write-Host "ERREUR : $_" -ForegroundColor Red
    Get-Process -Name $processName -ErrorAction SilentlyContinue | Stop-Process -Force
    Read-Host "Appuyez sur Entrée pour fermer"
    exit 1
}

# ---------- 2. Lancement optionnel ----------
if ($game) { Start-Process $game }

# ---------- 3. Attente de la fermeture du jeu ----------
$timeout = 120
$elapsed = 0
while (-not (Get-Process -Name $processName -ErrorAction SilentlyContinue) -and $elapsed -lt $timeout) {
    Start-Sleep -Seconds 2
    $elapsed += 2
}
if ($elapsed -ge $timeout) { Write-Warning "Processus $processName non détecté après ${timeout}s." }

while (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 5
}

# ---------- 4. Jeu -> dépôt ----------
Sync-Folder $gameSlot $repoSlot

$saveChanged = [bool](git status --porcelain -- $saveSlot)
Remove-Item $lockFile -Force
Git add -A

$date = Get-Date -Format "yyyy-MM-dd HH:mm"
if ($saveChanged) {
    Git commit -m "Save updated by $player on $date"
} else {
    Git commit -m "Unlock by $player (no save changes)"
}

# ---------- 5. Push (avec un retry) ----------
try {
    Git push origin main
} catch {
    Git pull --rebase origin main
    Git push origin main
}