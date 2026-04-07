@echo off
echo 🚀 PLANEAGUADA CRM - Script de Compilacion
echo ==========================================
echo.

cd /d "C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter"

echo 🧹 Limpiando proyecto...
flutter clean
if errorlevel 1 (
    echo ❌ Error en flutter clean
    pause
    exit /b 1
)

echo 📦 Obteniendo dependencias...
flutter pub get
if errorlevel 1 (
    echo ❌ Error en flutter pub get
    pause
    exit /b 1
)

echo 🔨 Compilando aplicacion...
flutter run
if errorlevel 1 (
    echo ❌ Error en flutter run
    pause
    exit /b 1
)

echo ✅ ¡Aplicacion ejecutandose correctamente!
pause
