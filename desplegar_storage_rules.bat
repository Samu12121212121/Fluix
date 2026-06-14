@echo off
echo Desplegando reglas de Firebase Storage...
cd /d "%~dp0"
firebase deploy --only storage
echo.
echo Listo. Reglas de Storage actualizadas.
pause
