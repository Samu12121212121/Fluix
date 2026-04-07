@echo off
echo ========================================
echo  Generar Certificado de PRUEBA Verifactu
echo ========================================
echo.
echo ATENCION: Este certificado es SOLO para pruebas.
echo Para produccion necesitas un certificado FNMT real.
echo.

cd /d "%~dp0"

:: Generar certificado autofirmado .p12 usando keytool de Java
keytool -genkeypair -v ^
  -keystore verifactu_pruebas.p12 ^
  -storetype PKCS12 ^
  -keyalg RSA ^
  -keysize 2048 ^
  -validity 365 ^
  -alias verifactu ^
  -dname "CN=Fluix CRM Pruebas, OU=Desarrollo, O=Fluix, L=Guadalajara, ST=Guadalajara, C=ES" ^
  -storepass fluixtest123 ^
  -keypass fluixtest123

if errorlevel 1 (
    echo.
    echo ERROR: No se pudo generar el certificado.
    echo Asegurate de tener Java/keytool en el PATH.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Certificado generado: verifactu_pruebas.p12
echo Contrasena: fluixtest123
echo ========================================
echo.
echo Convirtiendo a base64...

:: Convertir a base64 usando certutil
certutil -encode verifactu_pruebas.p12 verifactu_pruebas_b64.txt > nul 2>&1

:: Limpiar headers de certutil
powershell -Command "(Get-Content 'verifactu_pruebas_b64.txt') -notmatch '-----' -join '' | Set-Content 'verifactu_pruebas_clean.txt'"

echo.
echo Base64 guardado en: verifactu_pruebas_clean.txt
echo.
echo SIGUIENTE PASO:
echo 1. Copia el contenido de verifactu_pruebas_clean.txt
echo 2. Pegalo en Firebase Console como se indica en las instrucciones
echo.
echo Abriendo archivo...
notepad verifactu_pruebas_clean.txt

pause

