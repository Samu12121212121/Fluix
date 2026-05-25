@echo off
echo ========================================
echo Limpiando cache de Flutter...
echo ========================================
cd /d "C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter"

echo.
echo [1/3] Ejecutando flutter clean...
flutter clean

echo.
echo [2/3] Borrando pubspec.lock...
del pubspec.lock 2>nul

echo.
echo [3/3] Ejecutando flutter pub get...
flutter pub get

echo.
echo ========================================
echo Completado! El cache ha sido limpiado.
echo Ahora el problema de image_picker deberia estar resuelto.
echo ========================================
pause

