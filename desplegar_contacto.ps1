# Script para desplegar Cloud Function de emails de contacto
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DESPLEGAR CLOUD FUNCTION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location "C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter\functions"

Write-Host "Desplegando: enviarEmailsContactoInteres" -ForegroundColor Yellow
Write-Host ""

firebase deploy --only functions:enviarEmailsContactoInteres

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ ERROR en despliegue" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ DESPLIEGUE COMPLETADO" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "La Cloud Function está lista en producción." -ForegroundColor White
Write-Host ""
Write-Host "Cuando alguien llene el formulario:" -ForegroundColor Cyan
Write-Host "  1. Email de confirmación → usuario" -ForegroundColor White
Write-Host "  2. Email de notificación → sacoor80@gmail.com" -ForegroundColor White
Write-Host "  3. Tarea de alta prioridad → módulo propietario" -ForegroundColor White
Write-Host ""
pause

