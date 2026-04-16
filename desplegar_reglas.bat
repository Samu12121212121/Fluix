@echo off
cd /d "%~dp0"
echo ============================================
echo  Desplegando reglas Firestore
echo ============================================
echo.

call firebase deploy --only firestore:rules
if %errorlevel% neq 0 (
    echo.
    echo ERROR desplegando reglas.
    echo Comprueba que has iniciado sesion: firebase login
    pause
    exit /b 1
)

echo.
echo ============================================
echo  LISTO. Reglas desplegadas correctamente.
echo  Los visitantes ya pueden crear reservas
echo  desde la web sin necesidad de login.
echo ============================================
pause
