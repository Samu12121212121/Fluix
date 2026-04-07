@echo off
cd /d "%~dp0"
echo Desplegando visor web y script fluix-embed.js a Firebase Hosting...
call firebase deploy --only hosting
echo.
echo ----------------------------------------------------------------
echo TU SCRIPT ESTA LISTO EN:
echo https://planeaapp-4bea4.web.app/fluix-embed.js
echo.
echo Usa esa URL en todas las webs de tus clientes.
echo ----------------------------------------------------------------
pause
