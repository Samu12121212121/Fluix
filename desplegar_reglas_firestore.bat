@echo off
echo ========================================
echo Desplegando reglas de Firestore...
echo ========================================
echo.

firebase deploy --only firestore:rules

echo.
echo ========================================
echo Despliegue completado!
echo ========================================
pause

