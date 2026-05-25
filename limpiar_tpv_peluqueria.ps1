# Script para eliminar código duplicado en tpv_peluqueria_screen.dart

$archivo = "C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter\lib\features\tpv\pantallas\tpv_peluqueria_screen.dart"
$archivoTemp = $archivo + ".temp"

# Leer todo el archivo
$lineas = Get-Content $archivo -Encoding UTF8

# Conservar líneas 1-155 (imports y modelos principales)
$inicio = $lineas[0..154]

# Conservar líneas desde 1015 hasta el final (nueva implementación)
$final = $lineas[1014..($lineas.Count - 1)]

# Combinar
$contenidoLimpio = $inicio + $final

# Escribir archivo temp
$contenidoLimpio | Out-File -FilePath $archivoTemp -Encoding UTF8

# Reemplazar original
Move-Item -Path $archivoTemp -Destination $archivo -Force

Write-Host "✓ Archivo limpiado correctamente" -ForegroundColor Green
Write-Host "  - Líneas originales: $($lineas.Count)" -ForegroundColor Yellow
Write-Host "  - Líneas finales: $($contenidoLimpio.Count)" -ForegroundColor Yellow
Write-Host "  - Líneas eliminadas: $($lineas.Count - $contenidoLimpio.Count)" -ForegroundColor Cyan

