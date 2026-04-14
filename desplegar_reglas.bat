@echo off
cd /d "%~dp0"
echo ============================================
echo  Desplegando reglas Firestore + script web
echo ============================================
echo.

echo [0/3] Verificando sesion de Firebase CLI...
firebase projects:list >nul 2>&1
if %errorlevel% neq 0 (
    echo  SESION EXPIRADA o no iniciada. Abriendo navegador para hacer login...
    echo  Cuando termines el login en el navegador, vuelve aqui y pulsa cualquier tecla.
    firebase login
    if %errorlevel% neq 0 (
        echo ERROR: No se pudo iniciar sesion en Firebase.
        pause
        exit /b 1
    )
)
echo  OK: Sesion activa
echo.

echo [1/3] Desplegando reglas de Firestore...
call firebase deploy --only firestore:rules
if %errorlevel% neq 0 (
    echo ERROR desplegando reglas.
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
echo  TODO LISTO.
echo  - Abre la web del cliente en INCOGNITO
echo    y revisa la consola (F12).
echo  - Deberias ver:
echo    OK: Fluix Analytics iniciado
echo    OK: Visita registrada
echo  - En la app: Dashboard -> Contenido Web
echo    -> pestana Secciones -> aparece la carta
echo ============================================
pause
