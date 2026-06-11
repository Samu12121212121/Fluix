@echo off
echo ========================================
echo DESPLEGAR NOTIFICACIONES PUSH RESERVAS
echo ========================================
echo.
echo Este script desplegara:
echo 1. Reglas de Firestore (reservas anonimas)
echo 2. Cloud Function: onNuevaReserva (Push notifications)
echo.
echo Presiona CTRL+C para cancelar o
pause

echo.
echo [1/2] Desplegando reglas de Firestore...
echo ========================================
firebase deploy --only firestore:rules
if errorlevel 1 (
  echo.
  echo ERROR: Fallo el despliegue de reglas
  pause
  exit /b 1
)

echo.
echo [2/2] Desplegando Cloud Function onNuevaReserva...
echo ========================================
firebase deploy --only functions:onNuevaReserva
if errorlevel 1 (
  echo.
  echo ERROR: Fallo el despliegue de la Cloud Function
  pause
  exit /b 1
)

echo.
echo ========================================
echo DESPLIEGUE COMPLETADO EXITOSAMENTE
echo ========================================
echo.
echo RESULTADO:
echo - Las reservas web ahora enviaran notificaciones push
echo - Las notificaciones apareceran como WhatsApp en la app
echo - Se guardaran en la bandeja de notificaciones
echo.
echo PRUEBA:
echo 1. Envia una reserva desde: https://damajuanaguadalajara.site
echo 2. Deberas ver notificacion push en tu movil con:
echo    Titulo: "📅 Nueva Reserva"
echo    Mensaje: "[Nombre cliente] - [Fecha y hora]"
echo.
pause

