echo    OK: Ubicacion: ...
echo  TODO LISTO. Comprueba la web del cliente:
echo  abre las DevTools (F12) y mira la consola.
echo  Deberias ver:
echo    OK: Fluix Analytics: Modulo iniciado
    echo ERROR desplegando reglas. Comprueba que has iniciado sesion con: firebase login
@echo off
cd /d "%~dp0"
echo ============================================
echo  Desplegando reglas Firestore + script web
echo ============================================
echo.

call firebase deploy --only firestore:rules
if %errorlevel% neq 0 (
    echo ERROR desplegando reglas. Comprueba que has iniciado sesion con: firebase login
    pause
    exit /b 1
)
echo  OK: Reglas desplegadas
echo.

echo [2/3] Copiando script actualizado a web\...
copy /Y "public_web_visor\fluix-embed.js" "web\fluix-embed.js" >nul && echo  OK: fluix-embed.js copiado

echo.
echo [3/3] Publicando script en Firebase Hosting...
call firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo ERROR desplegando hosting.
    pause
    exit /b 1
)
echo  OK: Script publicado
echo.

echo ============================================
echo  TODO LISTO. Comprueba la web del cliente:
echo  abre las DevTools (F12) y mira la consola.
echo  Deberias ver:
echo    OK: Fluix Analytics: Modulo iniciado
echo    OK: Visita registrada
echo    OK: Ubicacion: ...
echo ============================================
pause
