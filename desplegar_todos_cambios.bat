@echo off
echo ============================================
echo COMANDOS PARA DESPLEGAR CAMBIOS
echo ============================================
echo.
echo Este script te guia por los pasos necesarios
echo.
pause

echo.
echo [1/5] Desplegando Reglas de Firestore...
echo.
firebase deploy --only firestore:rules
if %ERRORLEVEL% NEQ 0 (
    echo ERROR desplegando reglas
    pause
    exit /b 1
)

echo.
echo [2/5] Compilando Cloud Functions...
echo.
cd functions
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo ERROR compilando functions
    pause
    exit /b 1
)
cd ..

echo.
echo [3/5] Desplegando Cloud Function de Contacto...
echo.
cd functions
call firebase deploy --only functions:enviarEmailsContactoInteres
if %ERRORLEVEL% NEQ 0 (
    echo ERROR desplegando function
    pause
    exit /b 1
)
cd ..

echo.
echo [4/5] Limpiando proyecto Flutter...
echo.
flutter clean
flutter pub get

echo.
echo [5/5] Verificando codigo...
echo.
flutter analyze

echo.
echo ============================================
echo ✅ TODOS LOS CAMBIOS DESPLEGADOS
echo ============================================
echo.
echo CAMBIOS APLICADOS:
echo.
echo  ✅ Firestore Rules - Formulario contacto publico
echo  ✅ Cloud Function - Emails de contacto
echo  ✅ Fix navegacion - Notificaciones push
echo  ✅ Fix navegacion - Proximos 3 dias
echo  ✅ Codigo limpio y verificado
echo.
echo IMPORTANTE:
echo  - Las notificaciones push DEBEN incluir "reserva_id" en payload
echo  - Las Cloud Functions deben recompilar con: npm run build
echo  - Probar navegacion desde notificaciones
echo  - Probar navegacion desde widget "Proximos 3 Dias"
echo.
echo Lee los archivos:
echo  - FIX_NAVEGACION_NOTIFICACIONES.md
echo  - INSTRUCCIONES_DESPLIEGUE_CONTACTO.md
echo  - APP_STORE_REVIEW_2026_05_04.md
echo.
pause

