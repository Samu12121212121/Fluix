# Script para compilar Cloud Functions y verificar templates
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COMPILAR CLOUD FUNCTIONS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location "C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter\functions"

# Verificar que existen los templates de origen
Write-Host "[1/3] Verificando templates..." -ForegroundColor Yellow
$templatesOrigen = @(
    "src/templates/contacto_interes_confirmacion.html",
    "src/templates/contacto_interes_notificacion.html"
)

foreach ($template in $templatesOrigen) {
    if (Test-Path $template) {
        Write-Host "  ✅ $template" -ForegroundColor Green
    } else {
        Write-Host "  ❌ FALTA: $template" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "[2/3] Compilando TypeScript y copiando templates..." -ForegroundColor Yellow
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ ERROR en compilación" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "[3/3] Verificando templates compilados..." -ForegroundColor Yellow
$templatesDestino = @(
    "lib/templates/contacto_interes_confirmacion.html",
    "lib/templates/contacto_interes_notificacion.html"
)

foreach ($template in $templatesDestino) {
    if (Test-Path $template) {
        Write-Host "  ✅ $template" -ForegroundColor Green
    } else {
        Write-Host "  ❌ FALTA: $template" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ COMPILACIÓN COMPLETADA" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Ahora ejecuta: " -ForegroundColor Cyan
Write-Host "  desplegar_contacto.bat" -ForegroundColor White
Write-Host ""
pause

