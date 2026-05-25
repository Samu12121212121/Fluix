@echo off
echo ========================================
echo   COMPILAR FLUIXCRM PARA WINDOWS
echo ========================================
echo.

echo Compilando version Release para Windows...
flutter build windows --release

echo.
echo ========================================
echo   BUILD COMPLETADO
echo ========================================
echo.
echo Ejecutable en: build\windows\runner\Release\planeag_flutter.exe
echo.

pause

