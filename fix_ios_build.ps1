# Script para resolver el error de compilación iOS
# Ejecutar con: powershell -ExecutionPolicy Bypass -File fix_ios_build.ps1

Write-Host "=== REPARANDO ERROR DE COMPILACIÓN IOS ===" -ForegroundColor Green
Write-Host ""

Set-Location "C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter"

Write-Host "1. Limpiando caché de Flutter..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) { Write-Host "Error en flutter clean" -ForegroundColor Red; exit }

Write-Host "2. Eliminando archivos de build de iOS..." -ForegroundColor Yellow
if (Test-Path "ios\Pods") { Remove-Item -Recurse -Force "ios\Pods" }
if (Test-Path "ios\Podfile.lock") { Remove-Item -Force "ios\Podfile.lock" }
if (Test-Path "ios\.symlinks") { Remove-Item -Recurse -Force "ios\.symlinks" }

Write-Host "3. Obteniendo dependencias..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "Error en pub get" -ForegroundColor Red; exit }

Write-Host "4. Instalando pods de iOS..." -ForegroundColor Yellow
Set-Location ios
pod install --repo-update
Set-Location ..

Write-Host "5. Verificando análisis de código..." -ForegroundColor Yellow
flutter analyze --no-fatal-infos

Write-Host "6. Intentando build de iOS..." -ForegroundColor Yellow
flutter build ios --debug --no-codesign

Write-Host ""
Write-Host "=== REPARACIÓN COMPLETADA ===" -ForegroundColor Green
Write-Host "Si aún hay errores, revisa la salida anterior"
Write-Host ""
