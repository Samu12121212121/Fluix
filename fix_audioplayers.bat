@echo off
echo ══════════════════════════════════════════════════
echo  Fix audioplayers_android Kotlin compile error
echo ══════════════════════════════════════════════════
cd /d "%~dp0"

echo.
echo [1/4] Limpiando cache Flutter...
call flutter clean

echo.
echo [2/4] Eliminando cache Gradle...
cd android
call gradlew.bat --stop
cd ..

echo.
echo [3/4] Reinstalando dependencias Dart...
call flutter pub get

echo.
echo [4/4] Compilando (debug)...
call flutter run --debug

echo.
echo ══════════════════════════════════════════════════
echo  Si sigue fallando, borra manualmente:
echo  %%USERPROFILE%%\.gradle\caches
echo ══════════════════════════════════════════════════
pause

