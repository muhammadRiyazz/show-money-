Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "      DANADA LOANS - WINDOWS RELEASE BUILD SCRIPT       " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Checking Flutter..." -ForegroundColor Yellow
flutter --version
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter is not found in PATH! Please ensure Flutter is installed."
    exit $LASTEXITCODE
}

Write-Host "`n[2/4] Enabling Windows desktop support..." -ForegroundColor Yellow
flutter config --enable-windows-desktop

Write-Host "`n[3/4] Fetching dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n[4/4] Building Windows Release (danada_loans.exe)..." -ForegroundColor Yellow
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build windows failed!"
    exit $LASTEXITCODE
}

$buildDir = "build\windows\x64\runner\Release"
if (-not (Test-Path $buildDir)) {
    $buildDir = "build\windows\runner\Release"
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "[SUCCESS] Windows build completed successfully!" -ForegroundColor Green
Write-Host "Release folder: $buildDir" -ForegroundColor Green
Write-Host "Binary: $buildDir\danada_loans.exe" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green

if (Test-Path $buildDir) {
    explorer.exe $buildDir
}
