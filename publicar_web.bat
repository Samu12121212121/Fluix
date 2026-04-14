@echo off
cd /d "%~dp0"
echo ============================================
echo  Publicando scripts Fluix en Firebase Hosting
echo ============================================
echo.

REM ── PASO 1: Copiar scripts a la carpeta web/ ──────────────────
echo [1/3] Copiando scripts desde public_web_visor a web\...
echo.

copy /Y "public_web_visor\fluix-embed.js"             "web\fluix-embed.js"             >nul && echo  OK: fluix-embed.js
copy /Y "public_web_visor\fluix_script_universal.js"   "web\fluix_script_universal.js"  >nul && echo  OK: fluix_script_universal.js
copy /Y "public_web_visor\fluix-setup-hostinger.js"    "web\fluix-setup-hostinger.js"   >nul 2>&1 && echo  OK: fluix-setup-hostinger.js
copy /Y "public_web_visor\reservas.js"                 "web\reservas.js"                >nul && echo  OK: reservas.js

echo.

REM ── PASO 2: Verificar Firebase CLI ────────────────────────────
echo [2/3] Verificando Firebase CLI...
where firebase >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Firebase CLI no encontrado.
    echo Instala con: npm install -g firebase-tools
    echo.
    pause
    exit /b 1
)
echo  OK: Firebase CLI encontrado
echo.

REM ── PASO 3: Desplegar en Firebase Hosting ─────────────────────
echo [3/3] Publicando en Firebase Hosting...
firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo.
    echo ERROR al desplegar. Revisa el error arriba.
    echo Si pone "not logged in", ejecuta primero: firebase login
    pause
    exit /b 1
)

echo.
echo ============================================
echo  LISTO. URLs de tus scripts:
echo.
echo  PRINCIPAL (analiticas + contenido):
echo  https://planeaapp-4bea4.web.app/fluix-embed.js
echo.
echo  UNIVERSAL (hostinger con data-id):
echo  https://planeaapp-4bea4.web.app/fluix_script_universal.js
echo.
echo  RESERVAS (widget reservas standalone):
echo  https://planeaapp-4bea4.web.app/reservas.js
echo.
echo  --- PEGAR EN LA WEB DEL CLIENTE: ---
echo  ^<script data-empresa="ID_EMPRESA"
echo          src="https://planeaapp-4bea4.web.app/fluix-embed.js"^>^</script^>
echo ============================================
pause
