@echo off
echo ================================================
echo  Borrar funciones 1st Gen para migrar a 2nd Gen
echo  Proyecto: planeaapp-4bea4 / Region: europe-west1
echo ================================================
echo.
echo ATENCION: Esto borra las funciones antiguas (1st Gen).
echo Se redesplegaran automaticamente como 2nd Gen.
echo Hay unos segundos de inactividad durante el proceso.
echo.
echo Presiona cualquier tecla para continuar o Ctrl+C para cancelar...
pause > nul

cd /d "%~dp0"

echo.
echo [1/16] Borrando onNuevaReserva...
call firebase functions:delete onNuevaReserva --region=europe-west1 --force

echo [2/16] Borrando onReservaCancelada...
call firebase functions:delete onReservaCancelada --region=europe-west1 --force

echo [3/16] Borrando onNuevaValoracion...
call firebase functions:delete onNuevaValoracion --region=europe-west1 --force

echo [4/16] Borrando onNuevoPedido...
call firebase functions:delete onNuevoPedido --region=europe-west1 --force

echo [5/16] Borrando onNuevoPedidoGenerarFactura...
call firebase functions:delete onNuevoPedidoGenerarFactura --region=europe-west1 --force

echo [6/16] Borrando onNuevaFactura...
call firebase functions:delete onNuevaFactura --region=europe-west1 --force

echo [7/16] Borrando verificarSuscripciones...
call firebase functions:delete verificarSuscripciones --region=europe-west1 --force

echo [8/16] Borrando onNuevoPedidoWhatsApp...
call firebase functions:delete onNuevoPedidoWhatsApp --region=europe-west1 --force

echo [9/16] Borrando generarScriptEmpresa...
call firebase functions:delete generarScriptEmpresa --region=europe-west1 --force

echo [10/16] Borrando obtenerScriptJSON...
call firebase functions:delete obtenerScriptJSON --region=europe-west1 --force

echo [11/16] Borrando inicializarEmpresa...
call firebase functions:delete inicializarEmpresa --region=europe-west1 --force

echo [12/16] Borrando crearEmpresaHTTP...
call firebase functions:delete crearEmpresaHTTP --region=europe-west1 --force

echo [13/16] Borrando stripeWebhook...
call firebase functions:delete stripeWebhook --region=europe-west1 --force

echo [14/16] Borrando enviarEmailConPdf...
call firebase functions:delete enviarEmailConPdf --region=europe-west1 --force

echo [15/16] Borrando enviarRecordatoriosCitas...
call firebase functions:delete enviarRecordatoriosCitas --region=europe-west1 --force

echo [16/16] Borrando onTareaAsignada...
call firebase functions:delete onTareaAsignada --region=europe-west1 --force

echo.
echo ================================================
echo  Funciones 1st Gen borradas.
echo  Ahora desplegando TODAS como 2nd Gen...
echo  (incluye firmarXMLVerifactu y remitirVerifactu)
echo ================================================
echo.

call firebase deploy --only functions

echo.
echo ================================================
echo  LISTO. Todas las funciones son ahora 2nd Gen.
echo  Nuevas funciones desplegadas:
echo    - firmarXMLVerifactu  (firma XAdES Verifactu)
echo    - remitirVerifactu    (envio AEAT mTLS)
echo ================================================
pause

