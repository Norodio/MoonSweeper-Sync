param([String]$game="")

# Define variables
$repoPath = "C:\JAVA_Projet\MoonSweeper-Sync"  # Path where the GitHub repository is cloned
$savePath = "C:\Users\tomar\AppData\LocalLow\DragDropGames\MoonSweepers\MoonSessions" # Path to the Satisfactory save files
$saveFile = "\slot-2"
$processName = "MoonSweepers"  # Process name for Satisfactory

# Pull the latest save file
Set-Location $repoPath
git pull origin main
Copy-Item "$repoPath\$saveFile" "$savePath\$saveFile" -Recurse -Force 
# Launch Satisfactory
Start-Process $game # Satisfactory Steam ID

# Wait for the game to exit
$gameProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue
while ($null -ne $gameProcess) {
    Start-Sleep -Seconds 5
    $gameProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue
}

# After game exit, push the save file back to GitHub
Copy-Item "$savePath\$saveFile" "$repoPath\$saveFile" -Force
Set-Location $repoPath

# Get the current date and time
$currentDate = Get-Date -Format "yyyy-MM-dd"

# Create the commit message with the date
$commitMessage = "Updated save file on $currentDate"

# Commit and push the changes
git add $saveFile
git commit -m "$commitMessage"
git push origin main

Read-Host "Appuyez sur Entrée pour continuer"