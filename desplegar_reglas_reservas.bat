@echo off
REM ===================================================================
REM Script para desplegar las nuevas reglas de Firestore para reservas
REM ===================================================================

echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║   DESPLIEGUE DE REGLAS FIRESTORE - SISTEMA DE RESERVAS B2C   ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.

echo [1/3] Verificando que Firebase CLI esté instalado...
firebase --version >nul 2>&1
if errorlevel 1 (
    echo ❌ ERROR: Firebase CLI no está instalado
    echo.
    echo Instálalo con: npm install -g firebase-tools
    echo.
    pause
    exit /b 1
)
echo ✅ Firebase CLI instalado
echo.

echo [2/3] Validando sintaxis de firestore.rules...
firebase deploy --only firestore:rules --dry-run
if errorlevel 1 (
    echo.
    echo ❌ ERROR: Las reglas tienen errores de sintaxis
    echo Revisa el archivo firestore.rules
    echo.
    pause
    exit /b 1
)
echo ✅ Sintaxis correcta
echo.

echo [3/3] ¿Desplegar reglas a producción?
echo.
echo ATENCIÓN: Esto actualizará las reglas de seguridad en Firestore.
echo Las nuevas reglas incluyen:
echo   - Reservas B2C (clientes pueden crear reservas pendientes)
echo   - Notificaciones de reservas (solo owner puede leer)
echo   - Validación de estados (pendiente/confirmada/cancelada)
echo.
choice /C SN /M "¿Continuar con el despliegue"

if errorlevel 2 (
    echo.
    echo ❌ Despliegue cancelado
    echo.
    pause
    exit /b 0
)

echo.
echo Desplegando reglas...
firebase deploy --only firestore:rules

if errorlevel 1 (
    echo.
    echo ❌ ERROR: Fallo en el despliegue
    echo.
    pause
    exit /b 1
)

echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                    ✅ DESPLIEGUE EXITOSO                     ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo Las nuevas reglas ya están activas en Firestore.
echo.
echo Prueba el sistema de reservas:
echo   1. Abre la app en modo cliente (B2C)
echo   2. Busca un negocio en "Explorar"
echo   3. Entra en "Reservar"
echo   4. Completa el flujo de reserva
echo   5. Verifica que aparezca en el módulo owner (reservas pendientes)
echo.
echo Recuerda implementar la Cloud Function para enviar emails:
echo   - Ver: CAMBIOS_SISTEMA_RESERVAS.md
echo.
pause

