@echo off
cd /d "%~dp0"
echo Desplegando reglas de Firestore...
call firebase deploy --only firestore:rules
echo.
echo Hecho. Ahora abre sincronizar_carta.html y pulsa el boton.
pause
