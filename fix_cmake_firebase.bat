@echo off
echo ========================================
echo REPARACION CMAKE FIREBASE WINDOWS
echo ========================================
echo.

cd /d "%~dp0"

echo [1/5] Limpiando build anterior...
flutter clean
if errorlevel 1 (
    echo ERROR: flutter clean fallo
    pause
    exit /b 1
)

echo.
echo [2/5] Eliminando carpeta build corrupta...
if exist "build\windows" (
    rmdir /s /q "build\windows"
    echo Carpeta build\windows eliminada
) else (
    echo Carpeta build\windows no existe (OK)
)

echo.
echo [3/5] Eliminando cache de Flutter...
if exist "build" (
    rmdir /s /q "build"
    echo Carpeta build eliminada
) else (
    echo Carpeta build no existe (OK)
)

echo.
echo [4/5] Obteniendo dependencias...
flutter pub get
if errorlevel 1 (
    echo ERROR: flutter pub get fallo
    pause
    exit /b 1
)

echo.
echo [5/5] Compilando para Windows (modo release)...
echo Este paso puede tardar varios minutos...
echo.
flutter build windows --release
if errorlevel 1 (
    echo.
    echo ========================================
    echo ERROR: La compilacion fallo
    echo ========================================
    echo.
    echo Si el error persiste:
    echo 1. Verifica que CMake este instalado: cmake --version
    echo 2. CMake debe ser version 3.10 o superior
    echo 3. Descarga desde: https://cmake.org/download/
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo COMPILACION EXITOSA
echo ========================================
echo.
echo El ejecutable esta en:
echo build\windows\x64\runner\Release\planeag_flutter.exe
echo.
pause
