@echo off
echo ========================================
echo   LIMPIAR Y EJECUTAR FLUIXCRM WINDOWS
echo ========================================
echo.

echo [1/5] Limpiando cache de Flutter...
flutter clean
echo.

echo [2/5] Eliminando carpeta build...
if exist build rmdir /s /q build
echo.

echo [3/5] Eliminando .dart_tool...
if exist .dart_tool rmdir /s /q .dart_tool
echo.

echo [4/5] Obteniendo dependencias...
flutter pub get
echo.

echo [5/5] Ejecutando en Windows...
flutter run -d windows --verbose

