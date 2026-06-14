# Script PowerShell para ejecutar como Administrador si hay problemas de symlinks
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FLUTTER WINDOWS - MODO ADMINISTRADOR" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar si somos administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ADVERTENCIA: Este script debe ejecutarse como Administrador" -ForegroundColor Red
    Write-Host "Cerrando en 5 segundos..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    exit 1
}

Write-Host "[OK] Ejecutando como Administrador" -ForegroundColor Green
Write-Host ""

# Habilitar modo desarrollador (permite symlinks sin admin)
Write-Host "[1/8] Habilitando modo desarrollador..." -ForegroundColor Yellow
try {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord
    Write-Host "     OK - Modo desarrollador habilitado" -ForegroundColor Green
} catch {
    Write-Host "     AVISO: No se pudo habilitar modo desarrollador: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2/8] Limpiando proyecto..." -ForegroundColor Yellow
if (Test-Path "build") { Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path "windows\flutter\ephemeral") { Remove-Item -Path "windows\flutter\ephemeral" -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path ".dart_tool") { Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path ".flutter-plugins") { Remove-Item -Path ".flutter-plugins" -Force -ErrorAction SilentlyContinue }
if (Test-Path ".flutter-plugins-dependencies") { Remove-Item -Path ".flutter-plugins-dependencies" -Force -ErrorAction SilentlyContinue }
flutter clean | Out-Null
Write-Host "     OK - Limpieza completada" -ForegroundColor Green

Write-Host ""
Write-Host "[3/8] Obteniendo dependencias..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "     ERROR - Fallo en flutter pub get" -ForegroundColor Red
    pause
    exit 1
}
Write-Host "     OK - Dependencias obtenidas" -ForegroundColor Green

Write-Host ""
Write-Host "[4/8] Verificando symlinks..." -ForegroundColor Yellow
if (-not (Test-Path "windows\flutter\ephemeral\.plugin_symlinks\firebase_core")) {
    Write-Host "     AVISO - Symlinks no se generaron" -ForegroundColor Yellow
    Write-Host "     Reintentando pub get..." -ForegroundColor Yellow
    flutter pub get
    
    if (-not (Test-Path "windows\flutter\ephemeral\.plugin_symlinks\firebase_core")) {
        Write-Host "     ERROR - Los symlinks siguen sin generarse" -ForegroundColor Red
        Write-Host ""
        Write-Host "     Intentando reparar cache de Flutter..." -ForegroundColor Yellow
        flutter pub cache repair
        flutter pub get
        
        if (-not (Test-Path "windows\flutter\ephemeral\.plugin_symlinks\firebase_core")) {
            Write-Host ""
            Write-Host "ERROR CRITICO: No se pueden crear symlinks" -ForegroundColor Red
            Write-Host ""
            Write-Host "Prueba manual:" -ForegroundColor Yellow
            Write-Host "1. Abre CMD como administrador" -ForegroundColor Yellow
            Write-Host "2. cd a este directorio" -ForegroundColor Yellow
            Write-Host "3. flutter pub get" -ForegroundColor Yellow
            Write-Host "4. flutter run -d windows" -ForegroundColor Yellow
            pause
            exit 1
        }
    }
}
Write-Host "     OK - Symlinks verificados" -ForegroundColor Green

Write-Host ""
Write-Host "[5/8] Descargando Firebase SDK..." -ForegroundColor Yellow
Write-Host "     (El build fallara, es normal)" -ForegroundColor Gray
flutter build windows --debug 2>$null

Write-Host ""
Write-Host "[6/8] Parcheando Firebase CMakeLists.txt..." -ForegroundColor Yellow
$firebaseCMake = "build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt"

if (Test-Path $firebaseCMake) {
    Write-Host "     OK - Firebase SDK encontrado" -ForegroundColor Green
    
    # Crear backup
    Copy-Item $firebaseCMake "$firebaseCMake.backup" -ErrorAction SilentlyContinue
    
    # Aplicar parche
    (Get-Content $firebaseCMake) -replace 'cmake_minimum_required\(VERSION [0-9.]+\)', 'cmake_minimum_required(VERSION 3.10)' | Set-Content $firebaseCMake
    
    Write-Host "     OK - Parche aplicado (VERSION 3.10)" -ForegroundColor Green
} else {
    Write-Host "     AVISO - Firebase SDK no descargado" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[7/8] Configuracion de Visual Studio..." -ForegroundColor Yellow
# Verificar que Visual Studio esta instalado
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    $vsPath = & $vsWhere -latest -property installationPath
    if ($vsPath) {
        Write-Host "     OK - Visual Studio encontrado: $vsPath" -ForegroundColor Green
    } else {
        Write-Host "     AVISO - Visual Studio no detectado" -ForegroundColor Yellow
    }
} else {
    Write-Host "     AVISO - vswhere.exe no encontrado" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[8/8] Ejecutando Flutter en Windows..." -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

flutter run -d windows

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  FALLO EN EJECUCION" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Verifica flutter doctor:" -ForegroundColor Yellow
    flutter doctor -v
    Write-Host ""
    pause
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  EJECUCION EXITOSA" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
pause
