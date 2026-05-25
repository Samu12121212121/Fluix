@echo off
echo ========================================
echo CONTINUANDO BUILD WINDOWS
echo ========================================
echo.
echo El error de CMake ha sido parcheado.
echo Continuando con la compilacion...
echo.

cd /d "%~dp0"

flutter build windows --release

if errorlevel 1 (
    echo.
    echo ========================================
    echo ERROR EN LA COMPILACION
    echo ========================================
    echo.
    echo Ejecuta el script fix_cmake_firebase.bat
    echo para limpiar y recompilar desde cero.
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
echo Para ejecutar la app en modo DEBUG:
echo flutter run -d windows
echo.
pause

