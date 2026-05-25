# Script para parchear Firebase SDK CMakeLists.txt en Windows
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PARCHE FIREBASE SDK PARA WINDOWS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$firebaseCMake = "build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt"

if (Test-Path $firebaseCMake) {
    Write-Host "[1/2] Archivo Firebase CMakeLists.txt encontrado" -ForegroundColor Green
    Write-Host "      Aplicando parche..." -ForegroundColor Yellow

    # Leer el contenido
    $content = Get-Content $firebaseCMake -Raw

    # Reemplazar cmake_minimum_required con versión 3.10 (compatible con CMake moderno)
    $content = $content -replace 'cmake_minimum_required\(VERSION [0-9.]+\)', 'cmake_minimum_required(VERSION 3.10)'

    # Guardar el archivo modificado
    Set-Content $firebaseCMake -Value $content -NoNewline

    Write-Host "[2/2] Parche aplicado correctamente" -ForegroundColor Green
    Write-Host "      VERSION cambiada a 3.10" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ahora puedes ejecutar: flutter run -d windows" -ForegroundColor Cyan
} else {
    Write-Host "[ERROR] Archivo no encontrado." -ForegroundColor Red
    Write-Host "        Primero ejecuta: flutter build windows" -ForegroundColor Yellow
    Write-Host "        para que Flutter descargue el SDK de Firebase" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Presiona Enter para cerrar..." -ForegroundColor Gray
Read-Host


