@echo off
echo ========================================
echo  Desplegando Cloud Functions de PlaneaGuada
echo ========================================

cd /d "%~dp0functions"

echo.
echo [1/3] Instalando dependencias npm...
call npm install
if %errorlevel% neq 0 (
    echo ERROR: Fallo al instalar dependencias
    pause
    exit /b 1
)

echo.
echo [2/3] Compilando TypeScript...
call npm run build
if %errorlevel% neq 0 (
    echo ERROR: Fallo al compilar TypeScript
    pause
    exit /b 1
)

echo.
echo [3/3] Desplegando en Firebase (proyecto: planeaapp-4bea4)...
cd /d "%~dp0"
call firebase deploy --only functions --project planeaapp-4bea4
if %errorlevel% neq 0 (
    echo ERROR: Fallo al desplegar funciones
    echo.
    echo Si el error persiste, ejecuta manualmente:
    echo   firebase login
    echo   firebase use planeaapp-4bea4
    pause
    exit /b 1
)

echo.
echo ========================================
echo  Cloud Functions desplegadas con exito!
echo ========================================
echo.
echo Funciones desplegadas:
echo   - onNuevaReserva
echo   - onReservaCancelada
echo   - onNuevaValoracion
echo   - onNuevoPedido
echo   - onNuevaFactura
echo   - onNuevoPedidoWhatsApp
echo   - verificarSuscripciones (cron diario)
echo.
pause


