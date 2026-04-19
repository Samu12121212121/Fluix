@echo off
echo ========================================
echo SUBIENDO CAMBIOS A GITHUB
echo ========================================
echo.

cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter

echo [1/5] Verificando estado de Git...
git status
echo.

echo [2/5] Agregando todos los archivos modificados...
git add .
echo.

echo [3/5] Creando commit con los cambios de hoy...
git commit -m "fix: Mejoras en modulo de valoraciones - 19 Abril 2026

- Arreglado scroll en modulo de valoraciones (AlwaysScrollableScrollPhysics)
- Cambiado boton Responder por Responder en Google (abre Google Business)
- Actualizado Google Reviews Service a Places API (New)
- Migrado TarjetasResumen a datos reales desde Firestore
- Eliminados datos demo de KPIs y Reservas
- Actualizado limite de valoraciones de 50 a 20
- Mejorada funcion de responder con validacion y feedback
- Widgets ahora usan StreamBuilder para tiempo real"
echo.

echo [4/5] Verificando repositorio remoto...
git remote -v
echo.

echo [5/5] Subiendo a GitHub (rama actual)...
git push
echo.

echo ========================================
echo COMPLETADO!
echo ========================================
echo.
echo Si hay errores de autenticacion, ejecuta:
echo   git config --global user.name "Tu Nombre"
echo   git config --global user.email "tu@email.com"
echo.
pause

