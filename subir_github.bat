@echo off
echo ╔══════════════════════════════════════════════════════╗
echo ║        SUBIR PROYECTO A GITHUB - FLUIXTECH           ║
echo ╚══════════════════════════════════════════════════════╝
echo.

cd /d "C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter"

REM Verificar si git está inicializado
if not exist ".git" (
    echo [1/5] Inicializando Git...
    git init
) else (
    echo [1/5] Git ya inicializado.
)

REM Crear/actualizar .gitignore para no subir archivos sensibles
echo [2/5] Verificando .gitignore...

REM Verificar si ya existe un remote
git remote get-url origin >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [3/5] Remote ya existe, actualizando URL...
    git remote set-url origin https://github.com/Samu121212121/Fluix.git
) else (
    echo [3/5] Configurando remote origin...
    git remote add origin https://github.com/Samu121212121/Fluix.git
)

echo [4/5] Preparando archivos para subir...
git add .
git commit -m "FluixTech CRM - Commit inicial completo" 2>nul || (
    echo Ya hay commits anteriores, creando nuevo commit...
    git add .
    git commit -m "FluixTech CRM - Actualizacion %date%" 2>nul
)

echo [5/5] Subiendo a GitHub...
git branch -M main
git push -u origin main --force

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ╔══════════════════════════════════════════════════════╗
    echo ║   ✅ SUBIDO CORRECTAMENTE A GITHUB                   ║
    echo ║                                                      ║
    echo ║   Ahora ve a Codemagic:                              ║
    echo ║   https://codemagic.io/apps                         ║
    echo ║   → Add application                                  ║
    echo ║   → GitHub → Fluix                                   ║
    echo ╚══════════════════════════════════════════════════════╝
) else (
    echo.
    echo ╔══════════════════════════════════════════════════════╗
    echo ║   ❌ ERROR AL SUBIR                                   ║
    echo ║                                                      ║
    echo ║   Comprueba:                                         ║
    echo ║   1. El repo "Fluix" existe en GitHub (privado)      ║
    echo ║      https://github.com/new                          ║
    echo ║   2. Estas logueado en git con tu cuenta             ║
    echo ║      git config --global user.email "tu@email.com"   ║
    echo ║   3. Usa token de acceso como contraseña             ║
    echo ║      https://github.com/settings/tokens/new         ║
    echo ╚══════════════════════════════════════════════════════╝
)

echo.
pause

