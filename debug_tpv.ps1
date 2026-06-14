# ═══════════════════════════════════════════════════════════════════════════════
# DEBUG_TPV.ps1 - Script automatizado para debugging del crash en TPV
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   FLUIX CRM - DEBUGGING TPV CRASH" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Rutas
$ProjectPath = $PSScriptRoot
$LogFile = "$env:USERPROFILE\Documents\fluixcrm_crash.log"
$DebugLogFile = "$env:USERPROFILE\debug_tpv_complete_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

Write-Host " Directorio del proyecto: $ProjectPath" -ForegroundColor Yellow
Write-Host " Log persistente:          $LogFile" -ForegroundColor Yellow
Write-Host " Log completo:             $DebugLogFile" -ForegroundColor Yellow
Write-Host ""

# Verificar que flutter está instalado
Write-Host " Verificando Flutter..." -ForegroundColor White
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "✅ $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Flutter no está instalado o no está en PATH" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Limpiar log anterior si existe
if (Test-Path $LogFile) {
    Write-Host "️  Eliminando log anterior..." -ForegroundColor White
    Remove-Item $LogFile -Force
    Write-Host "✅ Log anterior eliminado" -ForegroundColor Green
} else {
    Write-Host "ℹ️  No hay log anterior" -ForegroundColor Gray
}

Write-Host ""

# Limpiar compilación previa
Write-Host " Limpiando compilación previa..." -ForegroundColor White
Set-Location $ProjectPath
flutter clean | Out-Null
Write-Host "✅ Limpieza completada" -ForegroundColor Green

Write-Host ""

# Obtener dependencias
Write-Host " Obteniendo dependencias..." -ForegroundColor White
flutter pub get | Out-Null
Write-Host "✅ Dependencias listas" -ForegroundColor Green

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   INICIANDO APLICACIÓN EN MODO DEBUG" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "⏳ La aplicación se está ejecutando..." -ForegroundColor Yellow
Write-Host ""
Write-Host " INSTRUCCIONES:" -ForegroundColor White
Write-Host "   1. Espera a que la app se abra" -ForegroundColor Gray
Write-Host "   2. Ve a TPV → Caja Rápida" -ForegroundColor Gray
Write-Host "   3. Agrega productos al ticket" -ForegroundColor Gray
Write-Host "   4. Haz click en COBRAR" -ForegroundColor Gray
Write-Host "   5. Confirma el cobro" -ForegroundColor Gray
Write-Host "   6. Observa los logs en esta ventana" -ForegroundColor Gray
Write-Host ""
Write-Host " Busca estos símbolos en los logs:" -ForegroundColor White
Write-Host "    [COBRO] = Flujo de cobro activo" -ForegroundColor Gray
Write-Host "   ✅         = Operación exitosa" -ForegroundColor Gray
Write-Host "            = ERROR CRÍTICO" -ForegroundColor Red
Write-Host "   Stack:     = Stack trace del error" -ForegroundColor Red
Write-Host ""
Write-Host "⌨️  Para detener: Presiona Ctrl+C" -ForegroundColor White
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Ejecutar Flutter con logs
try {
    # Ejecutar y guardar en archivo mientras muestra en pantalla
    flutter run -d windows --verbose 2>&1 | Tee-Object -FilePath $DebugLogFile
} catch {
    Write-Host ""
    Write-Host "⚠️  La aplicación se cerró o fue detenida" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   ANÁLISIS DE LOGS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Análisis automático del log
Write-Host " Analizando logs..." -ForegroundColor White
Write-Host ""

# Buscar errores críticos
$erroresEncontrados = Select-String -Path $DebugLogFile -Pattern "|ERROR|EXCEPTION|FATAL|Stack:" -AllMatches

if ($erroresEncontrados.Count -gt 0) {
    Write-Host "❌ SE ENCONTRARON ERRORES:" -ForegroundColor Red
    Write-Host ""
    $erroresEncontrados | Select-Object -Last 20 | ForEach-Object {
        Write-Host $_.Line -ForegroundColor Red
    }
} else {
    Write-Host "✅ No se detectaron errores en el log" -ForegroundColor Green
}

Write-Host ""

# Verificar si existe el log persistente
if (Test-Path $LogFile) {
    Write-Host "✅ Log persistente generado:" -ForegroundColor Green
    Write-Host "   $LogFile" -ForegroundColor Gray
    Write-Host ""
    
    # Mostrar últimas 30 líneas del log persistente
    Write-Host " Últimas 30 líneas del log persistente:" -ForegroundColor White
    Write-Host "---" -ForegroundColor Gray
    Get-Content $LogFile -Tail 30
    Write-Host "---" -ForegroundColor Gray
} else {
    Write-Host "⚠️  No se generó log persistente (app no llegó a inicializar)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   ARCHIVOS GENERADOS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "1️⃣  Log completo de ejecución:" -ForegroundColor White
Write-Host "    $DebugLogFile" -ForegroundColor Gray
Write-Host ""

if (Test-Path $LogFile) {
    Write-Host "2️⃣  Log persistente de crashes:" -ForegroundColor White
    Write-Host "    $LogFile" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   PRÓXIMOS PASOS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Revisa los logs mostrados arriba buscando:" -ForegroundColor White
Write-Host "   - El último mensaje [COBRO] antes del crash" -ForegroundColor Gray
Write-Host "   - Líneas con , ERROR, EXCEPTION o Stack:" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Abre los archivos de log en un editor:" -ForegroundColor White
Write-Host "   notepad '$DebugLogFile'" -ForegroundColor Cyan
if (Test-Path $LogFile) {
    Write-Host "   notepad '$LogFile'" -ForegroundColor Cyan
}
Write-Host ""

Write-Host "3. Si no encuentras el error, revisa Event Viewer:" -ForegroundColor White
Write-Host "   eventvwr.msc" -ForegroundColor Cyan
Write-Host "   → Windows Logs → Application → Buscar 'planeag_flutter.exe'" -ForegroundColor Gray
Write-Host ""

Write-Host "4. Comandos útiles:" -ForegroundColor White
Write-Host "   # Ver las últimas 50 líneas del log" -ForegroundColor Gray
Write-Host "   Get-Content '$DebugLogFile' -Tail 50" -ForegroundColor Cyan
Write-Host ""
Write-Host "   # Buscar líneas con [COBRO]" -ForegroundColor Gray
Write-Host "   Select-String -Path '$DebugLogFile' -Pattern '\[COBRO\]'" -ForegroundColor Cyan
Write-Host ""
Write-Host "   # Buscar errores" -ForegroundColor Gray
Write-Host "   Select-String -Path '$DebugLogFile' -Pattern 'ERROR|EXCEPTION'" -ForegroundColor Cyan
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✅ SCRIPT COMPLETADO" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Preguntar si quiere abrir los logs
$openLogs = Read-Host "¿Deseas abrir los archivos de log en Notepad? (S/N)"
if ($openLogs -eq "S" -or $openLogs -eq "s") {
    notepad $DebugLogFile
    if (Test-Path $LogFile) {
        Start-Sleep -Seconds 1
        notepad $LogFile
    }
}

Write-Host ""
Write-Host " Comparte estos archivos para obtener ayuda con el problema." -ForegroundColor Green
Write-Host ""
