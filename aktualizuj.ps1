# Your Kingdom: downloads the newest version of the game from GitHub (branch main)
# and imports the new art into Godot.
# Run in the game folder:  powershell -ExecutionPolicy Bypass -File aktualizuj.ps1

$godot = "C:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
Set-Location $PSScriptRoot

Write-Host "1/3 Sprawdzam lokalne zmiany..." -ForegroundColor Cyan
$changes = git status --porcelain --untracked-files=no
if ($changes) {
    Write-Host "Masz zmienione pliki, ktorych nie ma na GitHubie:" -ForegroundColor Yellow
    Write-Host $changes
    Write-Host "Nic nie ruszam. Wklej ten komunikat Claude'owi, powie co zrobic." -ForegroundColor Yellow
    exit 1
}

Write-Host "2/3 Pobieram najnowsza wersje gry (main)..." -ForegroundColor Cyan
git fetch origin
if ($LASTEXITCODE -ne 0) { Write-Host "Nie udalo sie polaczyc z GitHubem." -ForegroundColor Red; exit 1 }
git checkout main
if ($LASTEXITCODE -ne 0) { Write-Host "Nie udalo sie przejsc na main." -ForegroundColor Red; exit 1 }
git pull --ff-only origin main
if ($LASTEXITCODE -ne 0) { Write-Host "Nie udalo sie pobrac zmian. Wklej ten komunikat Claude'owi." -ForegroundColor Red; exit 1 }

Write-Host "3/3 Wczytuje grafiki do Godota (to chwile potrwa)..." -ForegroundColor Cyan
if (-not (Test-Path $godot)) {
    Write-Host "Nie znalazlem Godota w: $godot" -ForegroundColor Red
    Write-Host "Kod jest pobrany. Otworz projekt w Godocie, a grafiki wczytaja sie same." -ForegroundColor Yellow
    exit 1
}
& $godot --headless --path . --import | Out-Null

Write-Host ""
Write-Host "Gotowe! Mozesz uruchomic gre." -ForegroundColor Green
git log -1 --format="Najnowsza zmiana: %s (%cr)"
