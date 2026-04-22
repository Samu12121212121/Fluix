@echo off
echo Reparando error de compilacion...
echo.

echo 1. Limpiando proyecto Flutter...
flutter clean

echo.
echo 2. Obteniendo dependencias...
flutter pub get

echo.
echo 3. Ejecutando codigo generator (si existe)...
flutter packages pub run build_runner build --delete-conflicting-outputs

echo.
echo 4. Probando compilacion...
flutter build apk --debug

echo.
echo Reparacion completada. Si aun hay errores, ejecuta:
echo flutter build ios
echo.
pause
