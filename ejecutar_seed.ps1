# Script para ejecutar el seed de datos demo en PowerShell
# Ejecutar: .\ejecutar_seed.ps1

Write-Host "🌱 Ejecutando seed de datos demo..." -ForegroundColor Green
Write-Host ""

# Verificar que existe el archivo
if (-Not (Test-Path "functions\scripts\seed_demo.js")) {
    Write-Host "❌ Error: No se encuentra el archivo seed_demo.js" -ForegroundColor Red
    Write-Host "   Verifica que estás en la raíz del proyecto" -ForegroundColor Yellow
    exit 1
}

# Verificar que existe serviceAccountKey.json
if (-Not (Test-Path "functions\serviceAccountKey.json")) {
    Write-Host "❌ Error: Falta el archivo functions\serviceAccountKey.json" -ForegroundColor Red
    Write-Host ""
    Write-Host "Descárgalo desde:" -ForegroundColor Yellow
    Write-Host "https://console.firebase.google.com/project/planeaapp-4bea4/settings/serviceaccounts/adminsdk" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Verificar que firebase-admin está instalado
Write-Host "Verificando dependencias..." -ForegroundColor Yellow
Push-Location functions
$npmList = npm list firebase-admin 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "📦 Instalando firebase-admin..." -ForegroundColor Yellow
    npm install firebase-admin
}
Pop-Location

# Ejecutar el seed
Write-Host ""
Write-Host "▶️  Ejecutando seed..." -ForegroundColor Cyan
Write-Host ""

Set-Location functions\scripts
node seed_demo.js
$exitCode = $LASTEXITCODE
Set-Location ..\..

if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "✅ Seed completado exitosamente!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Error al ejecutar el seed" -ForegroundColor Red
    exit $exitCode
}

