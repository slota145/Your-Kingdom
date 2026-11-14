# Your Kingdom: builds the game as a Windows program (build\windows\YourKingdom.exe), one file
# with everything inside, to play without Godot or to give to friends (ROADMAP M10 part 2).
# Run in the game folder:  powershell -ExecutionPolicy Bypass -File eksportuj.ps1
# The first time it downloads Godot's export templates (about 1.3 GB, once).

$godot = "C:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
$version = "4.7.2.stable"
$templates = Join-Path $env:APPDATA "Godot\export_templates\$version"
$url = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
Set-Location $PSScriptRoot

if (-not (Test-Path $godot)) {
    Write-Host "Nie znalazlem Godota w: $godot" -ForegroundColor Red
    exit 1
}

Write-Host "1/3 Sprawdzam szablony eksportu Godota..." -ForegroundColor Cyan
if (-not (Test-Path (Join-Path $templates "windows_release_x86_64.exe"))) {
    Write-Host "Brak szablonow. Pobieram (ok. 1,3 GB, tylko raz, to chwile potrwa)..." -ForegroundColor Yellow
    $zip = Join-Path $env:TEMP "godot_templates_$version.zip"
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $url -OutFile $zip
    if (-not $?) { Write-Host "Nie udalo sie pobrac szablonow." -ForegroundColor Red; exit 1 }
    New-Item -ItemType Directory -Force -Path $templates | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
    foreach ($entry in $archive.Entries) {
        # Only what a Windows game needs (the rest are other systems).
        if ($entry.Name -like "windows_*x86_64*" -or $entry.Name -eq "version.txt") {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $templates $entry.Name), $true)
        }
    }
    $archive.Dispose()
    Remove-Item $zip
}

Write-Host "2/3 Wczytuje grafiki i dzwieki do Godota..." -ForegroundColor Cyan
& $godot --headless --path . --import | Out-Null

Write-Host "3/3 Buduje gre (to chwile potrwa)..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "build\windows" | Out-Null
& $godot --headless --path . --export-release "Windows Desktop" "build/windows/YourKingdom.exe"
if (-not (Test-Path "build\windows\YourKingdom.exe")) {
    Write-Host "Nie udalo sie zbudowac gry. Wklej ten komunikat Claude'owi." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Gotowe! Gra jest w folderze build\windows (YourKingdom.exe)." -ForegroundColor Green
Write-Host "Zapisy i dziennik bledow: $env:APPDATA\Godot\app_userdata\Your Kingdom" -ForegroundColor Green
Start-Process "build\windows"
