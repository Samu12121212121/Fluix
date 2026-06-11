@echo off
echo ========================================
echo DESPLEGAR SOLUCION NOTIFICACIONES WEB
echo ========================================
echo.
echo Este script desplegara:
echo 1. Reglas de Firestore (usuarios anonimos)
echo 2. Cloud Function (notificarNuevaReserva)
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
echo [2/2] Desplegando Cloud Function...
echo ========================================
firebase deploy --only functions:notificarNuevaReserva
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
echo Siguiente paso:
echo 1. Sube el formulario actualizado a tu sitio web:
echo    public_web_visor/damajuana_reservas_ORIGINAL.html
echo.
echo 2. Prueba enviando una reserva en:
echo    https://damajuanaguadalajara.site
echo.
echo 3. Verifica que llegue el email al correo del dueno
echo.
echo Documentacion completa en:
echo SOLUCION_NOTIFICACIONES_DAMAJUANA.md
echo.
pause

