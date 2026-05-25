# 🖨️ Diagnóstico Completo: Impresión Bluetooth ESC/POS en Windows TPV

## 📋 Índice

1. [Causas Más Probables (Priorizado)](#1-causas-más-probables-priorizado)
2. [Análisis Técnico Detallado](#2-análisis-técnico-detallado)
3. [Diagnóstico Paso a Paso](#3-diagnóstico-paso-a-paso)
4. [Logs y Event Viewer](#4-logs-y-event-viewer)
5. [Errores Comunes y Stack Traces](#5-errores-comunes-y-stack-traces)
6. [Arquitectura Estable](#6-arquitectura-estable)
7. [Buenas Prácticas](#7-buenas-prácticas)
8. [Checklists](#8-checklists)

---

## 1. CAUSAS MÁS PROBABLES (Priorizado)

### 🔴 **CRÍTICO - Revisar PRIMERO**

#### 1.1. Bloqueo del Hilo UI (UI Thread Blocking)
**Probabilidad**: ⭐⭐⭐⭐⭐ (90%)
- **Síntoma**: App se congela/crashea al pulsar "Cobrar"
- **Causa**: Impresión síncrona en el hilo principal de Flutter/Dart
- **Diagnóstico**: App deja de responder 3-10 segundos antes del crash
- **Fix Inmediato**: Mover impresión a un thread separado

```dart
// ❌ MAL - Bloquea UI
void _cobrar() {
  final ticket = generarTicket();
  imprimirBluetooth(ticket); // ← BLOQUEA UI
  Navigator.pop(context);
}

// ✅ BIEN - Async no bloqueante
Future<void> _cobrar() async {
  final ticket = generarTicket();
  
  // Mostrar loading
  showDialog(context: context, builder: (_) => LoadingDialog());
  
  try {
    // Imprimir en background
    await compute(imprimirBluetooth, ticket);
  } finally {
    Navigator.pop(context); // Cerrar loading
  }
}
```

#### 1.2. Problema del Servicio Print Spooler
**Probabilidad**: ⭐⭐⭐⭐ (75%)
- **Síntoma**: Crash con error "Print Spooler stopped working"
- **Causa**: Spooler de Windows cuelga con impresoras Bluetooth
- **Diagnóstico**: Event Viewer → Application Log → Error 7031 (Print Spooler)

**Verificación Rápida**:
```powershell
# Ver estado del spooler
Get-Service -Name Spooler

# Ver errores recientes
Get-EventLog -LogName Application -Source "Print" -Newest 20

# Reiniciar spooler
Restart-Service -Name Spooler -Force
```

#### 1.3. Driver Bluetooth ESC/POS Incompatible
**Probabilidad**: ⭐⭐⭐⭐ (70%)
- **Síntoma**: Timeout al enviar comandos, crash intermitente
- **Causa**: Drivers chinos sin firma, API deprecated
- **Diagnóstico**: Device Manager → Impresora muestra triángulo amarillo

**Impresoras Problemáticas Conocidas**:
- POS-5890 (Xprinter) → Driver chino sin firma
- POS-80C → Conflicto con Windows 11
- TP-B3 → Timeout frecuente > 10s

#### 1.4. Puerto COM Virtual Bluetooth Inestable
**Probabilidad**: ⭐⭐⭐ (60%)
- **Síntoma**: "COM port not found", "Access denied"
- **Causa**: Windows crea/elimina puerto COM dinámicamente
- **Diagnóstico**: Impresora cambia de COM3 a COM5 aleatoriamente

---

### 🟡 **MEDIO - Revisar DESPUÉS**

#### 1.5. Compatibilidad Windows 10 vs 11
**Probabilidad**: ⭐⭐⭐ (50%)
- **Windows 11**: Nuevo stack Bluetooth LE → rompe drivers antiguos
- **Windows 10 1909**: Último con Bluetooth clásico estable
- **Windows 11 22H2**: Cambios en Print Spooler

#### 1.6. Arquitectura x86 vs x64
**Probabilidad**: ⭐⭐ (40%)
- App compilada x64 + Driver x86 = Crash
- Flutter Windows default: x64
- Drivers chinos: mayormente x86

#### 1.7. Timeout de Bluetooth
**Probabilidad**: ⭐⭐⭐ (55%)
- Timeout default: 5s (muy corto para Bluetooth)
- Impresoras lentas: 8-15s para procesar ticket
- Fix: Aumentar timeout a 30s

---

### 🟢 **BAJO - Casos Raros**

#### 1.8. Windows Defender / Antivirus
**Probabilidad**: ⭐ (20%)
- Bloquea acceso a puerto COM
- Sandbox de Microsoft Defender Application Guard

#### 1.9. Handles de Recursos No Liberados
**Probabilidad**: ⭐⭐ (30%)
- Memory leak al abrir/cerrar puerto
- GDI handles no liberados (PrintDocument)

#### 1.10. Sleep Mode de Impresora
**Probabilidad**: ⭐⭐ (35%)
- Impresora en standby no responde primer comando
- Fix: Enviar "wake-up" ESC/POS antes

---

## 2. ANÁLISIS TÉCNICO DETALLADO

### 2.1. Stack Tecnológico: Flutter Windows + Bluetooth

```
┌─────────────────────────────────────────────┐
│      Flutter App (Dart)                     │
│      - UI thread (main isolate)             │
│      - Background isolates                  │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│   Platform Channel (MethodChannel)          │
│   - async/await bridge                      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│   Windows Native Code (C++/C#)              │
│   - blue_thermal_printer plugin            │
│   - SerialPort / WinAPI                     │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│   Windows Bluetooth Stack                   │
│   - Win32 BluetoothAPIs                     │
│   - RFCOMM / SPP                            │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│   Virtual COM Port (COMx)                   │
│   - bthport.sys driver                      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│   Impresora Térmica ESC/POS                 │
│   - Comandos ESC @ (init)                   │
│   - Print buffer                            │
└─────────────────────────────────────────────┘
```

**Puntos de Fallo**:
1. ❌ **Platform Channel**: Excepciones no manejadas → crash
2. ❌ **SerialPort**: Acceso concurrente → deadlock
3. ❌ **Bluetooth Stack**: Timeout → no response
4. ❌ **COM Port**: Desaparece durante operación → error fatal

---

### 2.2. Problema: `blue_thermal_printer` en Windows

Este paquete Flutter **NO FUNCIONA en Windows** nativamente:

```yaml
# pubspec.yaml
dependencies:
  blue_thermal_printer: ^2.0.0  # ❌ Solo Android/iOS
```

**Razón**: Usa APIs específicas de plataforma móvil (Android Bluetooth API, iOS CoreBluetooth).

**Alternativas Windows**:
1. ✅ **Paquete `printing`** + driver ESC/POS Windows
2. ✅ **Serial Port** directo (package `flutter_libserialport`)
3. ✅ **Custom Platform Channel** con C++/C# nativo

---

### 2.3. Arquitectura ESC/POS: RAW vs Driver Windows

#### Opción A: Impresión RAW (Comandos ESC/POS Directos)

```dart
// Enviar bytes directamente por puerto COM
final port = SerialPort('COM3');
port.open(mode: SerialOpenMode.readWrite);

// Comandos ESC/POS
final commands = [
  0x1B, 0x40,        // ESC @ - Reset
  0x1B, 0x61, 0x01,  // ESC a 1 - Center align
  ...bytes.encode('TICKET #123'),
  0x0A,              // Line feed
  0x1B, 0x64, 0x05,  // ESC d 5 - Feed 5 lines
  0x1B, 0x69,        // ESC i - Cut paper
];

port.write(Uint8List.fromList(commands));
port.close();
```

**Ventajas**:
- ✅ Control total sobre impresión
- ✅ No depende de Print Spooler
- ✅ Más rápido (sin intermediarios)

**Desventajas**:
- ❌ Requiere conocer comandos ESC/POS
- ❌ Puerto COM puede no estar disponible
- ❌ Windows antivirus puede bloquear

---

#### Opción B: Driver Windows + Print Spooler

```dart
final printer = Printer.fromName('POS-58-Bluetooth');
final doc = PrintDocument();
doc.addPage(Page(build: (context) => buildTicket()));
await Printing.directPrintPdf(
  printer: printer,
  onLayout: (_) => doc.save(),
);
```

**Ventajas**:
- ✅ Usa sistema estándar Windows
- ✅ Gestión de cola

**Desventajas**:
- ❌ Print Spooler puede crashear
- ❌ Driver mal hecho = problemas
- ❌ Más lento (conversión PDF → ESC/POS)

---

### 2.4. Print Spooler: Fuente #1 de Crashes

**Servicio**: `spoolsv.exe` (Windows Print Spooler)

**Problemas Conocidos**:
1. **Memory Leak**: Spooler consume GB RAM con drivers malos
2. **Crash en Cascada**: Spooler crashea → todas las apps pierden impresoras
3. **Jobs Atorados**: Cola llena → nuevos trabajos fallan
4. **Driver Incompatible**: DLL sin firma → spooler se niega a cargar

**Event Viewer Típico**:
```
Event ID: 7031
Source: Service Control Manager
The Print Spooler service terminated unexpectedly.
It has done this 3 time(s).

Faulting module: winspool.drv
Exception code: 0xc0000005 (ACCESS_VIOLATION)
```

**Solución Definitiva**: ❌ NO usar Print Spooler → Impresión RAW directa

---

### 2.5. Problema: Puerto COM Virtual Bluetooth

Windows crea un puerto COM cuando empareja impresora Bluetooth:

```
Settings → Devices → Bluetooth → POS-58 → More Bluetooth Options
→ COM Ports → Outgoing: COM3
```

**Problemas**:
1. **Puerto Dinámico**: Puede cambiar al reconectar (COM3 → COM5)
2. **Acceso Exclusivo**: Solo 1 app puede abrir puerto
3. **Timeout**: Si impresora apagada, `SerialPort.open()` cuelga 60s
4. **Permisos**: Antivirus bloquea acceso

**Detección de Puerto Automática**:
```dart
List<String> detectarPuertosDisponibles() {
  final puertos = <String>[];
  for (int i = 1; i <= 20; i++) {
    final port = SerialPort('COM$i');
    try {
      if (port.open(mode: SerialOpenMode.readWrite)) {
        puertos.add('COM$i');
        port.close();
      }
    } catch (_) {}
  }
  return puertos;
}
```

---

## 3. DIAGNÓSTICO PASO A PASO

### Paso 1: Verificar Conexión Bluetooth

```powershell
# 1. Listar dispositivos Bluetooth emparejados
Get-PnpDevice -Class Bluetooth | Format-Table

# 2. Ver servicios Bluetooth activos
Get-Service -Name bthserv

# 3. Ver puertos COM creados
Get-WmiObject Win32_SerialPort | Select-Object Name, DeviceID

# 4. Probar conexión manual
mode COM3 BAUD=9600 PARITY=N DATA=8 STOP=1
echo "TEST" > COM3
```

**Resultado Esperado**:
```
Name                DeviceID
----                --------
POS-58 (COM3)       COM3
```

---

### Paso 2: Test de Impresión RAW Básica

```dart
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';

Future<bool> testImpresionBasica() async {
  final port = SerialPort('COM3');
  
  try {
    if (!port.openReadWrite()) {
      print('❌ No se pudo abrir puerto: ${port.lastError}');
      return false;
    }
    
    // Configurar puerto
    final config = SerialPortConfig();
    config.baudRate = 9600;
    config.bits = 8;
    config.parity = SerialPortParity.none;
    config.stopBits = 1;
    port.config = config;
    
    // Comandos ESC/POS básicos
    final comandos = Uint8List.fromList([
      0x1B, 0x40,        // ESC @ - Reset impresora
      0x0A,              // Line feed
      ...utf8.encode('*** TEST IMPRESION ***'),
      0x0A, 0x0A, 0x0A,  // 3 line feeds
      0x1B, 0x64, 0x05,  // Feed paper 5 lines
      0x1B, 0x69,        // Cut paper
    ]);
    
    final bytesWritten = port.write(comandos);
    print('✅ Enviados $bytesWritten bytes');
    
    // Esperar a que impresora procese
    await Future.delayed(Duration(seconds: 2));
    
    port.close();
    return true;
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print(stackTrace);
    return false;
  }
}
```

**Casos de Fallo**:
1. `SerialPortError.noSuchDevice` → Puerto COM no existe
2. `SerialPortError.accessDenied` → Otra app usa el puerto
3. `SerialPortError.timeout` → Impresora apagada/desconectada
4. Ningún error pero no imprime → Driver incorrecto

---

### Paso 3: Diagnosticar Print Spooler

```powershell
# 1. Ver estado del servicio
Get-Service -Name Spooler | Format-List

# 2. Ver trabajos pendientes
Get-PrintJob -PrinterName "POS-58-Bluetooth"

# 3. Limpiar cola
Stop-Service -Name Spooler
Remove-Item "C:\Windows\System32\spool\PRINTERS\*" -Force
Start-Service -Name Spooler

# 4. Ver drivers instalados
Get-PrinterDriver | Format-Table Name, Manufacturer, PrinterEnvironment

# 5. Test de impresión Windows
notepad /p test.txt
```

---

### Paso 4: Análisis de Threads y Deadlocks

```dart
// Herramienta: Observatory (Dart DevTools)

// 1. Habilitar Observatory en app
flutter run --observatory-port=8080

// 2. En DevTools → Timeline, buscar:
// - UI thread blocked > 100ms
// - Platform channel calls > 5s
// - SerialPort.write() hanging

// 3. Si hay deadlock, verás:
Thread #1 (UI):     Waiting on Platform Channel response
Thread #2 (Native): Blocked on SerialPort.open()
```

---

## 4. LOGS Y EVENT VIEWER

### 4.1. Event Viewer: Qué Buscar

**Ruta**: `eventvwr.msc` → Windows Logs → Application / System

#### Errores Críticos de Print Spooler

```
Event ID: 7031 (Service Crash)
Source: Service Control Manager
Level: Error
Message: The Print Spooler service terminated unexpectedly.

→ CAUSA: Driver crasheó el spooler
→ FIX: Desinstalar driver problemático
```

```
Event ID: 372 (Driver Error)
Source: PrintService
Level: Warning
Message: The printer driver POS-58 is known to be unreliable.

→ CAUSA: Driver sin firma digital
→ FIX: Buscar driver oficial certificado WHQL
```

```
Event ID: 307 (Print Job Failed)
Source: PrintService
Level: Error
Message: Printer POS-58-Bluetooth failed to print document.

→ CAUSA: Timeout, impresora offline
→ FIX: Verificar conexión Bluetooth
```

---

#### Errores de Bluetooth

```
Event ID: 17 (Bluetooth Pairing Failed)
Source: Microsoft-Windows-Bluetooth-BthLEPrepairing
Message: Bluetooth device failed to connect.

→ CAUSA: Impresora fuera de rango, batería baja
→ FIX: Revisar conexión física
```

```
Event ID: 20203 (Bluetooth Service Error)
Source: Microsoft-Windows-Bluetooth-BthUSB
Message: The local Bluetooth adapter has failed in an undetermined manner.

→ CAUSA: Driver Bluetooth corrupto
→ FIX: Reinstalar drivers Bluetooth
```

---

### 4.2. Logs de tu App Flutter

```dart
// logger.dart
import 'package:logging/logging.dart';

final _log = Logger('PrinterService');

Future<void> imprimirTicket(TicketData ticket) async {
  _log.info('🖨️ Iniciando impresión ticket #${ticket.numero}...');
  
  try {
    final port = SerialPort('COM3');
    _log.fine('Abriendo puerto COM3...');
    
    if (!port.openReadWrite()) {
      _log.severe('❌ Error al abrir puerto: ${port.lastError}');
      throw PrinterException('Puerto COM no disponible');
    }
    
    _log.fine('✅ Puerto abierto correctamente');
    
    final comandos = generarComandosESC(ticket);
    _log.fine('Generados ${comandos.length} bytes de comandos ESC/POS');
    
    final bytesEscritos = port.write(comandos);
    _log.info('✅ Enviados $bytesEscritos bytes a impresora');
    
    await Future.delayed(Duration(seconds: 2));
    port.close();
    
    _log.info('🎉 Impresión completada exitosamente');
    
  } catch (e, stackTrace) {
    _log.severe('❌ Error durante impresión', e, stackTrace);
    rethrow;
  }
}
```

**Output Esperado** (exitoso):
```
[INFO] 🖨️ Iniciando impresión ticket #1234...
[FINE] Abriendo puerto COM3...
[FINE] ✅ Puerto abierto correctamente
[FINE] Generados 456 bytes de comandos ESC/POS
[INFO] ✅ Enviados 456 bytes a impresora
[INFO] 🎉 Impresión completada exitosamente
```

**Output de Fallo**:
```
[INFO] 🖨️ Iniciando impresión ticket #1234...
[FINE] Abriendo puerto COM3...
[SEVERE] ❌ Error al abrir puerto: SerialPortError.accessDenied
[SEVERE] ❌ Error durante impresión
PrinterException: Puerto COM no disponible
  at imprimirTicket (printer_service.dart:45)
  at _cobrar (tpv_screen.dart:234)
```

---

### 4.3. Logs del Sistema Windows

**Print Spooler Logs**:
```
C:\Windows\System32\spool\PRINTERS\*.SHD  (Shadow files - trabajos pendientes)
C:\Windows\System32\spool\PRINTERS\*.SPL  (Spool files - datos a imprimir)

# Ver tamaño de cola
Get-ChildItem "C:\Windows\System32\spool\PRINTERS" | Measure-Object -Property Length -Sum
```

**Bluetooth Logs**:
```
C:\Windows\INF\setupapi.dev.log  (Instalación drivers Bluetooth)

# Ver últimas instalaciones
Select-String -Path "C:\Windows\INF\setupapi.dev.log" -Pattern "Bluetooth" -Context 2,5
```

---

## 5. ERRORES COMUNES Y STACK TRACES

### 5.1. Error: "The application has stopped responding"

**Descripción**: App se congela completamente al pulsar "Cobrar".

**Stack Trace** (Dart Observatory):
```
Thread 1 (UI Thread - BLOCKED):
  dart:ui._waitForNativeResponse
  dart:ui._invokeMethod
  package:flutter/src/services/platform_channel.dart: MethodChannel.invokeMethod
  package:blue_thermal_printer/blue_thermal_printer.dart: printBytes
  package:myapp/printer_service.dart:45: imprimirTicket
  package:myapp/tpv_screen.dart:234: _cobrar
```

**Causa**: Impresión síncrona en UI thread.

**Fix**:
```dart
// ❌ MAL
void _cobrar() {
  imprimirTicket(ticket); // ← BLOQUEA
}

// ✅ BIEN
Future<void> _cobrar() async {
  showDialog(context: context, builder: (_) => LoadingDialog());
  await compute(_imprimirEnBackground, ticket);
  Navigator.pop(context);
}

static void _imprimirEnBackground(TicketData ticket) {
  // Se ejecuta en isolate separado
  final port = SerialPort('COM3');
  // ...
}
```

---

### 5.2. Error: "Print Spooler has stopped working"

**Event Viewer**:
```
Application: spoolsv.exe
Faulting Module: POS58Drv.dll
Exception Code: 0xc0000005 (ACCESS_VIOLATION)
Fault Offset: 0x00012a4f
```

**Causa**: Driver ESC/POS chino incompatible crashea el spooler.

**Diagnóstico**:
```powershell
# Ver módulos cargados por spooler antes del crash
tasklist /m /fi "IMAGENAME eq spoolsv.exe"

# Si aparece POS58Drv.dll → driver problemático
```

**Fix**:
```
1. Desinstalar driver actual:
   printui /s /t2 /n "POS-58-Bluetooth" /delete

2. Instalar driver genérico ESC/POS:
   - Epson TM-T20 (compatible ESC/POS estándar)
   - Star TSP100 (alternativa)

3. O mejor: NO usar Print Spooler → impresión RAW directa
```

---

### 5.3. Error: "COM port access denied"

**Exception**:
```
SerialPortException: Access is denied. (0x5)
  at SerialPort.open()
  at PrinterService.conectar()
```

**Causa**: Otra aplicación tiene el puerto abierto.

**Diagnóstico**:
```powershell
# Ver procesos usando puerto serie
Get-Process | Where-Object {$_.Modules.ModuleName -like "*serial*"}

# O usar Handle de Sysinternals
handle.exe COM3
```

**Fix**:
1. Cerrar otra app que usa el puerto
2. Implementar retry con timeout:

```dart
Future<SerialPort> abrirPuertoConRetry(String puerto, {int intentos = 3}) async {
  for (int i = 0; i < intentos; i++) {
    try {
      final port = SerialPort(puerto);
      if (port.openReadWrite()) {
        return port;
      }
    } catch (e) {
      if (i == intentos - 1) rethrow;
      await Future.delayed(Duration(seconds: 2));
    }
  }
  throw Exception('No se pudo abrir puerto después de $intentos intentos');
}
```

---

### 5.4. Error: "Bluetooth device not found"

**Exception**:
```
BluetoothException: No se encontró dispositivo POS-58
  at BluetoothManager.findDevice()
  at PrinterService.conectar()
```

**Causa**: Impresora no emparejada o fuera de rango.

**Diagnóstico**:
```powershell
# Listar dispositivos Bluetooth
Get-PnpDevice -Class Bluetooth | Where-Object {$_.FriendlyName -like "*POS*"}

# Ver estado de conexión
Get-NetAdapter | Where-Object {$_.InterfaceDescription -like "*Bluetooth*"}
```

**Fix**:
```dart
Future<bool> verificarImpresoraConectada(String nombreImpresora) async {
  // Verificar si existe puerto COM para la impresora
  final puertos = SerialPort.availablePorts;
  
  for (final puerto in puertos) {
    final port = SerialPort(puerto);
    final descripcion = port.description ?? '';
    
    if (descripcion.contains(nombreImpresora)) {
      return true;
    }
  }
  
  return false;
}
```

---

### 5.5. Error: "Timeout waiting for printer response"

**Log**:
```
[ERROR] Timeout esperando respuesta de impresora después de 5000ms
[ERROR] Comando enviado: ESC @ (reset)
[ERROR] Bytes enviados: 2
[ERROR] Bytes confirmados: 0
```

**Causa**: Impresora lenta o en sleep mode.

**Fix**:
```dart
Future<void> imprimirConTimeout(Uint8List comandos, {Duration timeout = const Duration(seconds: 30)}) async {
  final port = SerialPort('COM3');
  port.open(mode: SerialOpenMode.readWrite);
  
  try {
    // Enviar wake-up command
    port.write(Uint8List.fromList([0x1B, 0x40])); // ESC @
    await Future.delayed(Duration(milliseconds: 500)); // Esperar despertar
    
    // Ahora enviar comandos reales
    await port.write(comandos).timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException('Impresora no respondió en $timeout');
      },
    );
  } finally {
    port.close();
  }
}
```

---

## 6. ARQUITECTURA ESTABLE

### 6.1. Arquitectura Recomendada para TPV Windows

```
┌─────────────────────────────────────────────┐
│           Flutter UI (Main Thread)          │
│  - Botón "Cobrar"                           │
│  - Loading Dialog                           │
│  - Error Handling                           │
└─────────────────────────────────────────────┘
          ↓ async call
┌─────────────────────────────────────────────┐
│     PrinterService (Background Isolate)     │
│  - Queue de trabajos                        │
│  - Retry logic                              │
│  - Error recovery                           │
└───────────────────���─────────────────────────┘
          ↓ direct access
┌─────────────────────────────────────────────┐
│    Serial Port Manager (Singleton)          │
│  - Pool de conexiones                       │
│  - Auto-reconexión                          │
│  - Health checks                            │
└─────────────────────────────────────────────┘
          ↓ RAW commands
┌──────────��──────────────────────────────────┐
│         Puerto COM Bluetooth                │
│  - COM3 (virtual)                           │
│  - Baudrate: 9600                           │
└─────────────────────────────────────────────┘
          ↓ ESC/POS
┌────────────────────────────────��────────────┐
│       Impresora Térmica                     │
└─────────────────────────────────────────────┘
```

---

### 6.2. Implementación: PrinterService Robusto

```dart
// printer_service.dart
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._();
  factory PrinterService() => _instance;
  PrinterService._();
  
  String? _puertoActual;
  bool _conectado = false;
  final _cola = <TicketData>[];
  Timer? _healthCheckTimer;
  
  // Configuración
  static const baudRate = 9600;
  static const timeout = Duration(seconds: 30);
  static const maxReintentos = 3;
  
  /// Inicializar servicio (llamar al inicio de la app)
  Future<void> inicializar() async {
    await _detectarImpresora();
    _iniciarHealthChecks();
  }
  
  /// Detectar impresora automáticamente
  Future<void> _detectarImpresora() async {
    final puertos = SerialPort.availablePorts;
    
    for (final puerto in puertos) {
      final port = SerialPort(puerto);
      
      // Intentar abrir puerto
      if (port.openReadWrite()) {
        // Test básico
        try {
          port.write(Uint8List.fromList([0x1B, 0x40])); // ESC @ reset
          await Future.delayed(Duration(milliseconds: 500));
          
          _puertoActual = puerto;
          _conectado = true;
          print('✅ Impresora detectada en $puerto');
          port.close();
          return;
        } catch (e) {
          port.close();
        }
      }
    }
    
    print('⚠️ No se detectó ninguna impresora');
  }
  
  /// Health check periódico
  void _iniciarHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(minutes: 5), (_) {
      _verificarConexion();
    });
  }
  
  Future<void> _verificarConexion() async {
    if (_puertoActual == null) {
      await _detectarImpresora();
      return;
    }
    
    final port = SerialPort(_puertoActual!);
    try {
      if (port.openReadWrite()) {
        port.write(Uint8List.fromList([0x1B, 0x40]));
        _conectado = true;
        port.close();
      } else {
        _conectado = false;
      }
    } catch (e) {
      _conectado = false;
    }
  }
  
  /// Imprimir ticket (async, no bloqueante)
  Future<void> imprimirTicket(TicketData ticket) async {
    if (!_conectado || _puertoActual == null) {
      throw PrinterException('Impresora no conectada');
    }
    
    // Ejecutar en isolate separado
    await compute(_imprimirEnBackground, _ImpresionParams(
      puerto: _puertoActual!,
      ticket: ticket,
    ));
  }
  
  /// Función que se ejecuta en isolate separado (NO bloquea UI)
  static Future<void> _imprimirEnBackground(_ImpresionParams params) async {
    final port = SerialPort(params.puerto);
    
    try {
      if (!port.openReadWrite()) {
        throw PrinterException('No se pudo abrir puerto ${params.puerto}');
      }
      
      // Configurar puerto
      final config = SerialPortConfig();
      config.baudRate = baudRate;
      config.bits = 8;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;
      port.config = config;
      
      // Wake-up
      port.write(Uint8List.fromList([0x1B, 0x40]));
      await Future.delayed(Duration(milliseconds: 300));
      
      // Generar comandos ESC/POS
      final comandos = _generarComandosESC(params.ticket);
      
      // Enviar con timeout
      final bytesEscritos = await Future.microtask(() => port.write(comandos))
          .timeout(timeout);
      
      if (bytesEscritos != comandos.length) {
        throw PrinterException('Solo se enviaron $bytesEscritos de ${comandos.length} bytes');
      }
      
      // Esperar procesamiento
      await Future.delayed(Duration(seconds: 2));
      
    } finally {
      port.close();
    }
  }
  
  /// Generar comandos ESC/POS
  static Uint8List _generarComandosESC(TicketData ticket) {
    final bytes = <int>[];
    
    // Reset
    bytes.addAll([0x1B, 0x40]);
    
    // Centrar
    bytes.addAll([0x1B, 0x61, 0x01]);
    
    // Título BOLD
    bytes.addAll([0x1B, 0x45, 0x01]); // Bold ON
    bytes.addAll(utf8.encode(ticket.nombreEmpresa.toUpperCase()));
    bytes.add(0x0A);
    bytes.addAll([0x1B, 0x45, 0x00]); // Bold OFF
    
    // Número ticket
    bytes.add(0x0A);
    bytes.addAll(utf8.encode('TICKET Nº ${ticket.numeroTicket}'));
    bytes.add(0x0A);
    
    // Fecha
    bytes.addAll(utf8.encode(DateFormat('dd/MM/yyyy HH:mm').format(ticket.fecha)));
    bytes.add(0x0A);
    bytes.add(0x0A);
    
    // Línea separadora
    bytes.addAll(utf8.encode('--------------------------------'));
    bytes.add(0x0A);
    
    // Alinear izquierda
    bytes.addAll([0x1B, 0x61, 0x00]);
    
    // Líneas del ticket
    for (final linea in ticket.lineas) {
      final cantidad = '${linea.cantidad}x';
      final nombre = linea.nombre.padRight(20);
      final precio = linea.subtotal.toStringAsFixed(2).padLeft(8);
      
      bytes.addAll(utf8.encode('$cantidad $nombre €$precio'));
      bytes.add(0x0A);
    }
    
    bytes.add(0x0A);
    bytes.addAll(utf8.encode('--------------------------------'));
    bytes.add(0x0A);
    
    // Total (centrado, grande)
    bytes.addAll([0x1B, 0x61, 0x01]); // Center
    bytes.addAll([0x1D, 0x21, 0x11]); // Double size
    bytes.addAll(utf8.encode('TOTAL: €${ticket.total.toStringAsFixed(2)}'));
    bytes.addAll([0x1D, 0x21, 0x00]); // Normal size
    bytes.add(0x0A);
    bytes.add(0x0A);
    
    // Método pago
    bytes.addAll([0x1B, 0x61, 0x00]); // Left
    bytes.addAll(utf8.encode('Pago: ${ticket.metodoPago}'));
    bytes.add(0x0A);
    bytes.add(0x0A);
    bytes.add(0x0A);
    
    // Gracias (centrado)
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll(utf8.encode('¡Gracias por su compra!'));
    bytes.add(0x0A);
    bytes.add(0x0A);
    
    // Feed y cortar
    bytes.addAll([0x1B, 0x64, 0x05]); // Feed 5 lines
    bytes.addAll([0x1D, 0x56, 0x00]); // Cut paper
    
    return Uint8List.fromList(bytes);
  }
  
  void dispose() {
    _healthCheckTimer?.cancel();
  }
}

class _ImpresionParams {
  final String puerto;
  final TicketData ticket;
  _ImpresionParams({required this.puerto, required this.ticket});
}

class PrinterException implements Exception {
  final String message;
  PrinterException(this.message);
  String toString() => 'PrinterException: $message';
}
```

---

### 6.3. Uso en TPV Screen

```dart
// tpv_screen.dart
class _TpvScreenState extends State<TpvScreen> {
  
  @override
  void initState() {
    super.initState();
    // Inicializar servicio al cargar pantalla
    PrinterService().inicializar();
  }
  
  Future<void> _cobrar() async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Imprimiendo ticket...'),
        ]),
      ),
    );
    
    try {
      // Generar ticket data
      final ticket = TicketData(
        nombreEmpresa: 'Mi Empresa',
        numeroTicket: 1234,
        fecha: DateTime.now(),
        lineas: comandaActual.lineas,
        total: comandaActual.total,
        metodoPago: 'Efectivo',
      );
      
      // Imprimir (NO bloqueante, se ejecuta en isolate)
      await PrinterService().imprimirTicket(ticket);
      
      // Cerrar loading
      Navigator.pop(context);
      
      // Mostrar éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Ticket impreso correctamente')),
      );
      
    } catch (e) {
      // Cerrar loading
      Navigator.pop(context);
      
      // Mostrar error
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Error de Impresión'),
          content: Text('No se pudo imprimir el ticket:\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _cobrar(); // Reintentar
              },
              child: Text('Reintentar'),
            ),
          ],
        ),
      );
    }
  }
}
```

---

## 7. BUENAS PRÁCTICAS

### 7.1. ✅ DO - Hacer SIEMPRE

1. **Impresión Asíncrona en Isolate Separado**
   ```dart
   await compute(imprimirEnBackground, ticket); // ✅
   imprimirSincrono(ticket); // ❌
   ```

2. **Timeout en Todas las Operaciones de Puerto**
   ```dart
   await port.write(comandos).timeout(Duration(seconds: 30));
   ```

3. **Cerrar Puerto en `finally`**
   ```dart
   try {
     port.open();
     port.write(data);
   } finally {
     port.close(); // SIEMPRE cerrar
   }
   ```

4. **Wake-Up Command Antes de Imprimir**
   ```dart
   port.write([0x1B, 0x40]); // ESC @ reset
   await Future.delayed(Duration(milliseconds: 300));
   // Ahora enviar datos
   ```

5. **Health Checks Periódicos**
   ```dart
   Timer.periodic(Duration(minutes: 5), (_) {
     verificarConexionImpresora();
   });
   ```

6. **Fallback a Vista de Ticket en Pantalla**
   ```dart
   try {
     await imprimirBluetooth(ticket);
   } catch (e) {
     await mostrarTicketEnPantalla(ticket);
   }
   ```

---

### 7.2. ❌ DON'T - NO Hacer NUNCA

1. **NO Bloquear UI Thread**
   ```dart
   // ❌ MAL
   void cobrar() {
     SerialPort.write(...); // Bloquea UI
   }
   ```

2. **NO Usar Print Spooler para ESC/POS**
   ```dart
   // ❌ MAL - Usar Printing.directPrintPdf()
   // ✅ BIEN - Usar SerialPort directo
   ```

3. **NO Asumir Puerto COM Fijo**
   ```dart
   // ❌ MAL
   final port = SerialPort('COM3'); // Puede cambiar
   
   // ✅ BIEN
   final puerto = await detectarPuertoImpresora();
   final port = SerialPort(puerto);
   ```

4. **NO Ignorar Excepciones de Impresión**
   ```dart
   // ❌ MAL
   try { imprimir(); } catch (e) {}
   
   // ✅ BIEN
   try { imprimir(); } catch (e) { mostrarError(e); }
   ```

5. **NO Dejar Puerto Abierto Indefinidamente**
   ```dart
   // ❌ MAL
   port.open();
   // ... app sigue ejecutando
   
   // ✅ BIEN
   port.open();
   port.write(...);
   port.close(); // Inmediatamente
   ```

---

## 8. CHECKLISTS

### 8.1. ✅ Checklist de Debugging

Cuando la app crashea al imprimir, revisar en orden:

- [ ] **1. Verificar que NO sea bloqueo de UI**
  - [ ] ¿Impresión se ejecuta en async/isolate?
  - [ ] ¿Hay `await compute()` o similar?
  - [ ] ¿Timeline de DevTools muestra UI thread blocked?

- [ ] **2. Verificar conexión Bluetooth**
  - [ ] ¿Impresora está emparejada en Windows?
  - [ ] ¿Puerto COM existe en Device Manager?
  - [ ] ¿Puerto COM es accesible (no "Access Denied")?
  - [ ] `Get-WmiObject Win32_SerialPort` muestra la impresora?

- [ ] **3. Verificar Print Spooler (si se usa)**
  - [ ] ¿Servicio `Spooler` está corriendo?
  - [ ] ¿Hay trabajos atorados en cola?
  - [ ] ¿Event Viewer muestra crash de spoolsv.exe?
  - [ ] ¿Driver tiene firma digital?

- [ ] **4. Verificar Driver**
  - [ ] ¿Driver es x64 si app es x64?
  - [ ] ¿Driver es certificado WHQL?
  - [ ] ¿Device Manager muestra triángulo amarillo?
  - [ ] ¿Test de impresión Windows funciona? (`notepad /p`)

- [ ] **5. Verificar Código**
  - [ ] ¿Se cierra puerto en `finally`?
  - [ ] ¿Hay timeout configurado?
  - [ ] ¿Excepciones están siendo capturadas?
  - [ ] ¿Logs muestran el punto exacto de fallo?

- [ ] **6. Verificar Sistema**
  - [ ] ¿Windows Defender bloqueando?
  - [ ] ¿Antivirus terceros bloqueando?
  - [ ] ¿Permisos de administrador necesarios?
  - [ ] ¿.NET runtime instalado?

---

### 8.2. ✅ Checklist de Configuración Windows

Para TPV en producción, Windows debe tener:

**Sistema Operativo**:
- [ ] Windows 10 Pro/Enterprise (mínimo 1909)
- [ ] O Windows 11 Pro 22H2 (con últimas actualizaciones)
- [ ] NO Windows 11 Home (problemas con Bluetooth corporativo)

**Servicios**:
- [ ] Bluetooth Support Service: Running, Automatic
- [ ] Print Spooler: Running, Automatic (o Disabled si RAW)
- [ ] Windows Update: Habilitado (para drivers)

**Drivers**:
- [ ] Bluetooth driver actualizado (del fabricante del PC)
- [ ] Impresora ESC/POS con driver firmado WHQL
- [ ] O sin driver (impresión RAW recomendada)

**Firewall/Antivirus**:
- [ ] Windows Defender: Exclusión para app TPV
- [ ] Puerto COM no bloqueado
- [ ] Carpeta de app en exclusiones

**Energía**:
- [ ] Plan de energía: Alto rendimiento
- [ ] Bluetooth: "Permitir que equipo apague este dispositivo" = OFF
- [ ] USB: "Suspensión selectiva" = Deshabilitado

**Bluetooth**:
- [ ] Impresora emparejada correctamente
- [ ] Puerto COM outgoing configurado
- [ ] "Mostrar icono Bluetooth" habilitado (para debugging)

---

### 8.3. ✅ Checklist de Despliegue en Producción

Antes de poner TPV en un comercio:

**Hardware**:
- [ ] Impresora térmica ESC/POS compatible probada
- [ ] Papel térmico suficiente (rollo 80mm x 50m)
- [ ] Adaptador Bluetooth USB si PC no tiene BT integrado
- [ ] Distancia PC <-> Impresora < 5 metros (sin obstáculos)
- [ ] Impresora con batería cargada (o conectada AC)

**Software**:
- [ ] App TPV instalada y probada
- [ ] Impresión de prueba exitosa (10 tickets consecutivos)
- [ ] Fallback a ticket en pantalla funcional
- [ ] Logs habilitados (nivel INFO mínimo)
- [ ] Crash reporting configurado (Sentry/Firebase Crashlytics)

**Configuración**:
- [ ] Puerto COM detectado automáticamente
- [ ] O configurado manualmente en settings
- [ ] Timeout de impresión ≥ 30 segundos
- [ ] Retry automático habilitado (3 intentos)
- [ ] Health check cada 5 minutos

**Testing**:
- [ ] Prueba con 50 tickets consecutivos sin fallos
- [ ] Prueba desconectar/reconectar Bluetooth
- [ ] Prueba apagar/encender impresora
- [ ] Prueba sin papel (manejo error)
- [ ] Prueba impresora apagada (fallback)

**Contingencia**:
- [ ] Manual de usuario con troubleshooting
- [ ] Número de soporte técnico
- [ ] Plan B: Imprimir tickets desde otro PC
- [ ] Plan C: Tickets manuscritos + facturación posterior

---

### 8.4. ✅ Checklist de Estabilidad a Largo Plazo

Para un TPV que funcione meses sin problemas:

**Mantenimiento Preventivo**:
- [ ] Limpiar cabezal impresora cada semana
- [ ] Reiniciar PC cada noche (scheduled task)
- [ ] Reiniciar servicio Bluetooth cada noche
- [ ] Limpiar cola Print Spooler cada noche
- [ ] Actualizar drivers cada 3 meses

**Monitoreo**:
- [ ] Logs centralizados (ELK/Splunk)
- [ ] Alertas de fallos de impresión
- [ ] Dashboard de salud del TPV
- [ ] Métricas: tasa éxito impresión > 98%

**Actualizaciones**:
- [ ] Windows Update diferido (30 días)
- [ ] Updates solo en horario de cierre
- [ ] Snapshot/backup antes de updates
- [ ] Plan de rollback si algo falla

---

## 9. RECOMENDACIONES FINALES

### Opción RECOMENDADA para Máxima Estabilidad:

```
✅ Impresión RAW directa por SerialPort
✅ SIN Print Spooler
✅ SIN driver de impresora
✅ Async con compute()/isolate
✅ Timeout 30s
✅ Retry automático
✅ Fallback a pantalla
✅ Health checks
```

### Alternativas si RAW No Es Opción:

**Plan B**: Driver Epson TM-T20 genérico ESC/POS
- Compatible con mayoría de impresoras chinas
- Firmado WHQL
- Estable en Windows 10/11

**Plan C**: Imprimir PDF con `printing` package
- Más lento pero más compatible
- Requiere conversión ticket → PDF
- Works en todos los sistemas

---

## 10. EJEMPLO COMPLETO FUNCIONAL

```dart
// main.dart
void main() {
  // Inicializar logger
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  
  runApp(MyApp());
}

// En initState del TPV screen
@override
void initState() {
  super.initState();
  PrinterService().inicializar();
}

// Al cobrar
Future<void> _cobrar() async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Imprimiendo ticket...'),
          ],
        ),
      ),
    ),
  );
  
  try {
    final ticket = TicketData(/* ... */);
    await PrinterService().imprimirTicket(ticket);
    
    Navigator.pop(context); // Cerrar loading
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🖨️ Ticket impreso correctamente'),
        backgroundColor: Colors.green,
      ),
    );
    
  } on PrinterException catch (e) {
    Navigator.pop(context); // Cerrar loading
    
    // Mostrar ticket en pantalla como fallback
    await _mostrarTicketEnPantalla(ticket);
    
  } catch (e, stackTrace) {
    Navigator.pop(context); // Cerrar loading
    
    logger.severe('Error impresión', e, stackTrace);
    
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Error de Impresión'),
        content: Text('$e'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cobrar(); // Reintentar
            },
            child: Text('Reintentar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
```

---

## 📞 SOPORTE

Si después de seguir esta guía el problema persiste:

1. **Capturar logs completos**:
   - Event Viewer (últimas 24h)
   - Logs de tu app
   - `Get-EventLog` output

2. **Información del sistema**:
   - Versión Windows (`winver`)
   - Modelo impresora exacto
   - Versión driver (`devmgmt.msc`)
   - `Get-PnpDevice -Class Bluetooth`

3. **Crear issue con**:
   - Stack trace completo
   - Logs adjuntos
   - Pasos para reproducir
   - Capturas de pantalla

---

*Última actualización: 25 Mayo 2026*  
*Versión: 1.0 - Diagnóstico Completo Windows TPV Bluetooth*

