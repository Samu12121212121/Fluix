
@echo off
cd /d "%~dp0"
echo  Desplegando reglas Firestore
echo  Desplegando reglas Firestore + script web
echo ============================================
echo.

call firebase deploy --only firestore:rules
    echo.
    echo ERROR desplegando reglas.
    echo Comprueba que has iniciado sesion: firebase login
echo    OK: Fluix: N seccion(es) conectadas
    pause
    exit /b 1

echo  OK: Reglas desplegadas

echo  LISTO. Reglas desplegadas correctamente.
echo  Los visitantes ya pueden crear reservas
echo  desde la web sin necesidad de login.
    exit /b 1
)
echo  OK: Script publicado
echo.

echo ============================================
echo  TODO LISTO. Comprueba la web del cliente:
echo  abre las DevTools (F12) y mira la consola.
echo  Deberias ver:
echo    OK: Fluix: autenticacion anonima OK
echo    OK: Fluix: N seccion(es) conectadas
echo ============================================
pause
