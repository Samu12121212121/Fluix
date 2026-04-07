@echo off
echo ========================================
echo   Generador de Keystore PlaneaGuada
echo ========================================
echo.
echo Este script crea la firma digital para publicar en Google Play.
echo GUARDA el archivo .jks y la contrasena en un lugar seguro.
echo Si los pierdes, NO podras actualizar la app nunca mas.
echo.
echo Presiona cualquier tecla para continuar...
pause > nul

cd /d "%~dp0android"

keytool -genkey -v ^
  -keystore planeaguada-release.jks ^
  -keyalg RSA ^
  -keysize 2048 ^
  -validity 10000 ^
  -alias planeaguada ^
  -dname "CN=Samuel, OU=Fluix, O=Fluix, L=Guadalajara, ST=Guadalajara, C=ES"

echo.
echo ========================================
echo Keystore generado correctamente:
echo android/planeaguada-release.jks
echo.
echo AHORA: Edita android/key.properties y pon la contrasena.
echo ========================================
pause
