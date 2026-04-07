@echo off
echo ========================================
echo   Subir Certificado Verifactu a Firestore
echo ========================================
echo.
echo Este script convierte tu certificado .p12/.pfx a base64
echo y te muestra los datos para pegarlos en la consola de Firebase.
echo.

set /p CERT_FILE="Ruta del archivo .p12 o .pfx: "
set /p CERT_PASS="Contrasena del certificado: "

echo.
echo Convirtiendo a base64...

:: Convertir a base64 usando certutil (viene con Windows)
certutil -encode "%CERT_FILE%" "%TEMP%\cert_b64.txt" > nul 2>&1

if errorlevel 1 (
    echo ERROR: No se pudo convertir el archivo. Verifica la ruta.
    pause
    exit /b 1
)

:: Limpiar headers de certutil (quita "-----BEGIN/END CERTIFICATE-----")
powershell -Command "(Get-Content '%TEMP%\cert_b64.txt') -notmatch '-----' -join '' | Set-Content '%TEMP%\cert_clean.txt'"

echo.
echo ========================================
echo INSTRUCCIONES PARA FIREBASE CONSOLE:
echo ========================================
echo.
echo 1. Ve a https://console.firebase.google.com
echo 2. Selecciona tu proyecto
echo 3. Ve a Firestore Database
echo 4. Navega a: empresas/{TU_EMPRESA_ID}/configuracion/
echo 5. Crea un documento llamado: certificado_verifactu
echo 6. Anade estos campos:
echo.
echo    Campo: p12Base64  (tipo: string)
echo    Valor: [pega el contenido del archivo que se abre a continuacion]
echo.
echo    Campo: password   (tipo: string)
echo    Valor: %CERT_PASS%
echo.
echo    Campo: fecha_subida (tipo: timestamp)
echo    Valor: [fecha actual]
echo.
echo ========================================
echo.
echo Abriendo el archivo con el base64...
notepad "%TEMP%\cert_clean.txt"

echo.
echo ALTERNATIVA: Usa la pantalla "Certificado Verifactu" en la app
echo (Configuracion Fiscal ^> Certificado Verifactu) para subirlo
echo directamente desde el movil/web.
echo.
pause

