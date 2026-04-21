@echo off
echo ===== VERIFICACION COMPLETA DE NOTIFICACIONES PUSH =====
echo.

echo [1/5] Ejecutando app en modo debug...
flutter run --debug --dart-define=DEBUG_FCM=true &
timeout 10

echo.
echo [2/5] Verificando configuracion de Firebase...
if exist android\app\google-services.json (
    echo ✅ google-services.json encontrado
) else (
    echo ❌ google-services.json NO encontrado
)

if exist ios\Runner\GoogleService-Info.plist (
    echo ✅ GoogleService-Info.plist encontrado
) else (
    echo ❌ GoogleService-Info.plist NO encontrado
)

echo.
echo [3/5] Verificando permisos Android...
findstr "android.permission.POST_NOTIFICATIONS" android\app\src\main\AndroidManifest.xml >nul
if %errorlevel% == 0 (
    echo ✅ Permiso POST_NOTIFICATIONS configurado
) else (
    echo ❌ Permiso POST_NOTIFICATIONS NO configurado
)

findstr "remote-notification" android\app\src\main\AndroidManifest.xml >nul
if %errorlevel% == 0 (
    echo ✅ Metadata FCM configurado
) else (
    echo ❌ Metadata FCM NO configurado
)

echo.
echo [4/5] Verificando configuracion iOS...
findstr "remote-notification" ios\Runner\Info.plist >nul
if %errorlevel% == 0 (
    echo ✅ UIBackgroundModes configurado
) else (
    echo ❌ UIBackgroundModes NO configurado
)

echo.
echo [5/5] Verificando funciones Firebase...
if exist functions\src\index.ts (
    findstr "testPushNotification" functions\src\index.ts >nul
    if %errorlevel% == 0 (
        echo ✅ Funcion testPushNotification encontrada
    ) else (
        echo ❌ Funcion testPushNotification NO encontrada
    )
) else (
    echo ❌ Archivo functions\src\index.ts NO encontrado
)

echo.
echo ===== INSTRUCCIONES PARA PROBAR =====
echo.
echo 1. Abre la app en tu dispositivo/emulador
echo 2. Logueate con tu cuenta
echo 3. Ve al dashboard
echo 4. Busca el boton naranja flotante (bug icon) en la esquina inferior derecha
echo 5. Toca el boton para abrir el panel de debug FCM
echo 6. Utiliza estos botones en orden:
echo    • "TEST COMPLETO" - Verifica todo el flujo
echo    • "Test WhatsApp Style" - Prueba notificacion local estilo WhatsApp
echo    • "Probar PUSH (Cloud)" - Prueba notificacion desde servidor
echo.
echo ===== COMO DEBEN "SALTAR" LAS NOTIFICACIONES =====
echo.
echo ✅ App en PRIMER PLANO:
echo    - Se muestra banner en la parte superior (heads-up)
echo    - Suena el sonido de notificacion
echo    - Vibra el dispositivo
echo    - Aparece en el centro de notificaciones
echo.
echo ✅ App en BACKGROUND:
echo    - Aparece notificacion push automaticamente
echo    - Al tocar, abre la app y navega a la seccion correcta
echo.
echo ✅ App CERRADA:
echo    - Sistema muestra la notificacion
echo    - Al tocar, abre la app desde cero
echo.
echo ===== SOLUCION DE PROBLEMAS =====
echo.
echo Si NO aparecen las notificaciones:
echo 1. Verifica permisos en Configuracion del sistema
echo 2. Revisa que el token FCM este guardado en Firestore
echo 3. Comprueba que las funciones Firebase esten desplegadas
echo 4. Asegurate de tener internet y Firebase configurado
echo.
echo ¡Pulsa cualquier tecla para cerrar!
pause >nul
