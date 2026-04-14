@echo off
echo =========================================
echo  CREAR DATOS CONTENIDO WEB EN FIRESTORE
echo =========================================
echo.

cd /d "%~dp0"

echo Verificando Node.js...
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js no esta instalado
    pause
    exit /b 1
)

echo Verificando firebase-admin...
if not exist "node_modules\firebase-admin" (
    echo Instalando firebase-admin...
    npm install firebase-admin
)

echo.
echo Ejecutando seed de contenido web...
echo Empresa: TUz8GOnQ6OX8ejiov7c5GM9LFPl2
echo.

node seed_contenido_web.js

echo.
pause


