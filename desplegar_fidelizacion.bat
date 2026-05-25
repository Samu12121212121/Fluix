@echo off
echo ========================================
echo   DESPLIEGUE SISTEMA FIDELIZACION QR
echo ========================================
echo.

echo [1/5] Instalando dependencias Flutter...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: No se pudieron instalar las dependencias de Flutter
    pause
    exit /b 1
)
echo ✅ Dependencias Flutter instaladas
echo.

echo [2/5] Compilando Cloud Functions...
cd functions
call npm install
if %errorlevel% neq 0 (
    echo ERROR: No se pudieron instalar las dependencias de Node
    cd ..
    pause
    exit /b 1
)
call npm run build
if %errorlevel% neq 0 (
    echo ERROR: No se pudieron compilar las Cloud Functions
    cd ..
    pause
    exit /b 1
)
cd ..
echo ✅ Cloud Functions compiladas
echo.

echo [3/5] Desplegando Cloud Functions...
call firebase deploy --only functions:onCheckinFidelizacion,functions:onCanjeRecompensa,functions:marcarQRsExpirados,functions:verificarCaducidadSellos
if %errorlevel% neq 0 (
    echo ERROR: No se pudieron desplegar las Cloud Functions
    pause
    exit /b 1
)
echo ✅ Cloud Functions desplegadas
echo.

echo [4/5] Desplegando Reglas de Firestore...
call firebase deploy --only firestore:rules
if %errorlevel% neq 0 (
    echo ERROR: No se pudieron desplegar las reglas de Firestore
    pause
    exit /b 1
)
echo ✅ Reglas de Firestore desplegadas
echo.

echo [5/5] Verificando logs...
call firebase functions:log --lines 20
echo.

echo ========================================
echo   ✅ DESPLIEGUE COMPLETADO CON ÉXITO
echo ========================================
echo.
echo Sistema de Fidelización QR desplegado al 95%%
echo.
echo Próximos pasos:
echo - Ejecuta: flutter run
echo - Navega a la pantalla de tarjeta de sellos
echo - Prueba el flujo completo
echo.
echo Funciones desplegadas:
echo   ✅ onCheckinFidelizacion
echo   ✅ onCanjeRecompensa
echo   ✅ marcarQRsExpirados
echo   ✅ verificarCaducidadSellos
echo.
pause
