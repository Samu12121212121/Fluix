@echo off
cls
echo ============================================
echo 🧪 TESTING - NAVEGACION NOTIFICACIONES
echo ============================================
echo.
echo Este script te prepara para probar que
echo las notificaciones abran el detalle correcto
echo.
pause

echo.
echo [1/4] Limpiando proyecto Flutter...
echo.
flutter clean
flutter pub get

echo.
echo [2/4] Compilando Cloud Functions...
echo.
cd functions
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ ERROR compilando functions
    pause
    exit /b 1
)
cd ..

echo.
echo [3/4] Desplegando Firestore Rules...
echo.
firebase deploy --only firestore:rules

echo.
echo [4/4] Desplegando Cloud Functions de Reservas...
echo.
cd functions
call firebase deploy --only functions:onNuevaReserva,functions:onReservaConfirmada,functions:onReservaCancelada
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ ADVERTENCIA: Error desplegando functions
    echo Puedes continuar pero las notif icaciones pueden no funcionar
    pause
)
cd ..

echo.
echo ============================================
echo ✅ SETUP COMPLETADO
echo ============================================
echo.
echo Ahora sigue estos pasos:
echo.
echo TERMINAL 1 (esta ventana):
echo   flutter run
echo.
echo TERMINAL 2 (nueva ventana):
echo   flutter logs
echo   (para ver los logs en tiempo real)
echo.
echo PRUEBAS:
echo   1. Crea una reserva nueva en la app
echo   2. Toca la notificacion que llega
echo   3. Verifica que abre el DETALLE (no solo el modulo)
echo.
echo   4. Ve a Dashboard → "Proximos 3 Dias"
echo   5. Toca un dia con eventos
echo   6. Toca un evento en la lista
echo   7. Verifica que abre el DETALLE
echo.
echo LOGS A BUSCAR:
echo   ✅ "🔔 Notificacion de reserva recibida"
echo   ✅ "reserva_id: XYZ..."
echo   ✅ "✅ Reserva encontrada, navegando a detalle"
echo.
echo   ❌ "⚠️ No hay reserva_id en el payload"
echo   ❌ "🔙 Fallback: abriendo modulo de reservas"
echo.
echo Lee GUIA_PRUEBAS_NAVEGACION.md para mas detalles
echo.
pause

echo.
echo ¿Quieres ejecutar la app ahora? (S/N)
set /p EJECUTAR=
if /i "%EJECUTAR%"=="S" (
    echo.
    echo Ejecutando flutter run...
    echo Abre otra terminal y ejecuta: flutter logs
    echo.
    flutter run
)

