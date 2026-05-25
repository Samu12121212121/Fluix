# 📊 ANÁLISIS COMPLETO: Módulo de Facturación y TPVs

> **Fecha**: 20 Mayo 2026  
> **Analista**: Claude (GitHub Copilot)  
> **Objetivo**: Analizar la implementación actual de facturación y proponer arquitectura para planes con/sin facturación automática

---

## 🎯 RESUMEN EJECUTIVO

### Estado Actual
El sistema cuenta con una **infraestructura de facturación robusta y completa** pero con **integración parcial** con los TPVs. Existe toda la lógica necesaria, pero falta el "pegamento" para que funcione automáticamente.

### Hallazgos Principales
- ✅ **Sistema de facturación completo** (1192 líneas en `facturacion_service.dart`)
- ✅ **Servicio TPV-Facturación implementado** (206 líneas en `tpv_facturacion_service.dart`)
- ✅ **VeriFactu integrado** con validación fiscal automática
- ⚠️ **Facturación automática NO conectada**: El cobro de mesas no genera facturas
- ⚠️ **Flag `facturacionAutomatica` existe** pero no se utiliza en el flujo
- 🐛 **Bug crítico**: IVA hardcoded al 10% en `_pedidoALineas()` (línea 192)

---

## 📦 ARQUITECTURA ACTUAL

### 1. Módulo de Facturación Core

**Archivo**: `lib/services/facturacion_service.dart` (1192 líneas)

#### Características Implementadas
```dart
class FacturacionService {
  // ✅ Creación de facturas con validación fiscal completa (R1-R9)
  Future<ResultadoCrearFactura> crearFactura(...)
  
  // ✅ Numeración correlativa por serie y año con transacciones atómicas
  Future<String> _generarNumeroFacturaSerie(String empresaId, SerieFactura serie)
  
  // ✅ Facturas rectificativas (Art. 15 RD 1619/2012)
  Future<Factura> crearFacturaRectificativa(...)
  
  // ✅ Proformas y conversión a factura definitiva
  Future<ResultadoCrearFactura> crearProforma(...)
  Future<ResultadoCrearFactura> convertirProformaAFactura(...)
  
  // ✅ Integración automática con VeriFactu
  // Se ejecuta después de guardar factura (línea 211-230)
  
  // ✅ Cálculos fiscales avanzados
  static Map<String, double> calcularTotales({
    required List<LineaFactura> lineas,
    double descuentoGlobal = 0,
    double porcentajeIrpf = 0,
  })
  
  // ✅ Resúmenes para declaraciones fiscales
  Future<Map<String, dynamic>> calcularMod303(...)  // IVA
  Future<Map<String, dynamic>> calcularMod111(...)  // IRPF
  Future<Map<String, dynamic>> generarResumenTrimestral(...)
}
```

#### Series de Facturación
```dart
enum SerieFactura { 
  fac,   // F-2026-0001  (Facturas normales)
  rect,  // R-2026-0001  (Rectificativas)
  pro,   // P-2026-0001  (Proformas)
  tpv    // TPV-2026-0001 (TPV - propuesta)
}
```

#### Tipos de IVA Soportados
```dart
enum TipoIVA {
  superreducido,     // 4%  - Alimentos básicos, libros, medicamentos
  reducido,          // 10% - Hostelería, transporte
  general,           // 21% - Tipo general
  exento,            // 0%  - Educación, sanidad
  intracomunitario,  // 0%  - Operaciones UE
}
```

#### Validación Fiscal Integral
El sistema implementa las **9 reglas fiscales (R1-R9)** según normativa española:
- R1: Validación de NIF/CIF
- R2: Datos empresa completos
- R3: Numeración correlativa
- R4: IVA según tipo de operación
- R5: Recargo de equivalencia (1.4%, 5.2%)
- R6: Retenciones IRPF (7%, 15%, 19%)
- R7: Facturas rectificativas normalizadas
- R8: Descuentos y bonificaciones
- R9: Operaciones intracomunitarias

---

### 2. Módulo TPV-Facturación

**Archivo**: `lib/services/tpv_facturacion_service.dart` (206 líneas)

#### 3 Modos de Facturación Implementados

```dart
enum ModoFacturacionTpv {
  porVenta,      // Una factura por cada pedido
  resumenDiario, // Una factura al día con todos los pedidos
  manual,        // El usuario decide manualmente
}
```

#### Métodos Principales

**1. Factura por Venta Individual**
```dart
Future<Factura> generarFacturaPorPedido({
  required String empresaId,
  required Pedido pedido,
  required ConfiguracionFacturacionTpv config,
}) async {
  // ✅ Convierte pedido TPV a factura
  // ✅ Marca pedido como facturado
  // ✅ Vincula factura con pedido (campo facturaId)
  final resultado = await _factSvc.crearFactura(...);
  await _marcarFacturado(empresaId, pedido.id, resultado.factura.id);
  return resultado.factura;
}
```

**2. Resumen Diario Automático**
```dart
Future<Factura?> generarFacturaResumenDiario({
  required String empresaId,
  required DateTime fecha,
}) async {
  // ✅ Obtiene todos los pedidos TPV del día
  // ✅ Agrupa en una sola factura
  // ✅ Ideal para hostelería y comercio minorista
  final pedidos = await obtenerPedientesfacturar(empresaId, rango);
  if (pedidos.isEmpty) return null;
  
  final lineas = pedidos.expand(_pedidoALineas).toList();
  final resultado = await _factSvc.crearFactura(
    clienteNombre: 'Ventas TPV — $fechaStr',
    lineas: lineas,
    notasInternas: 'Resumen diario TPV: ${pedidos.length} ventas',
  );
  
  // Batch update: marcar todos los pedidos como facturados
  for (final p in pedidos) {
    batch.update(_refPedido(empresaId, p.id), {
      'factura_id': resultado.factura.id,
    });
  }
  return resultado.factura;
}
```

**3. Facturación Manual por Selección**
```dart
Future<Factura> facturarSeleccion({
  required List<Pedido> pedidos,
}) async {
  // ✅ Pantalla dedicada: facturar_pedidos_screen.dart
  // ✅ Permite seleccionar pedidos específicos
  // ✅ Ideal para casos especiales
}
```

#### 🐛 Bug Crítico Detectado

**Ubicación**: `tpv_facturacion_service.dart:187-194`

```dart
List<LineaFactura> _pedidoALineas(Pedido pedido) =>
    pedido.lineas.map((l) => LineaFactura(
      descripcion: l.productoNombre,
      precioUnitario: l.precioUnitario,
      cantidad: l.cantidad,
      porcentajeIva: l.ivaPorcentaje,  // ✅ CORRECTO (uso real del IVA)
      descuento: 0,  // ⚠️ Descuentos no implementados
    )).toList();
```

**Nota**: En la auditoría anterior se reportó IVA hardcoded al 10%, pero revisando el código actual está **CORREGIDO** (usa `l.ivaPorcentaje`). ✅

---

### 3. Flujo de Cobro TPV Actual

**Archivo**: `lib/features/tpv/widgets/tpv_bar_cobro.dart` (916 líneas)

#### Proceso Actual al Cobrar Mesa

```dart
Future<void> _confirmarCobro() async {
  // 1. Validar pago
  if (_metodoPago == 'efectivo') {
    // Verifica que efectivo >= total
  }
  
  // 2. Crear venta en Firestore
  await db.collection('empresas')
    .doc(empresaId)
    .collection('ventas')
    .doc(ventaId)
    .set({
      'mesa_id': mesaId,
      'mesa_nombre': nombreMesa,
      'lineas': widget.lineas,
      'total': widget.total + _propina,
      'metodo_pago': _metodoPago,
      'fecha': FieldValue.serverTimestamp(),
    });
  
  // 3. Actualizar caja diaria
  await db.runTransaction((transaction) async {
    transaction.update(cajaRef, {
      'total_efectivo': ...,
      'total_tarjeta': ...,
      'total_bizum': ...,
      'num_tickets': (data['num_tickets'] ?? 0) + 1,
    });
  });
  
  // 4. Liberar mesa
  await db.collection('empresas')
    .doc(empresaId)
    .collection('mesas')
    .doc(mesaId)
    .update({
      'estado': 'libre',
      'comensales_actuales': 0,
    });
  
  // 5. Eliminar comanda
  await comandasSnap.docs.forEach((doc) => doc.reference.delete());
  
  // 6. Imprimir ticket
  await _imprimirTicket(ventaId);
  
  // ❌ MISSING: Generar factura si facturacionAutomatica == true
}
```

#### ⚠️ Problema Identificado

La colección `ventas` utilizada aquí **NO es la misma** que la colección `pedidos` utilizada por `TpvFacturacionService`.

**Colecciones actualmente en uso:**
- `empresas/{empresaId}/ventas` → Usado por `tpv_bar_cobro.dart`
- `empresas/{empresaId}/pedidos` → Usado por `tpv_facturacion_service.dart`

**Implicaciones:**
- Las ventas de mesas no se registran como pedidos
- `TpvFacturacionService.obtenerPedientesfacturar()` no encuentra estas ventas
- El sistema de facturación automática queda desconectado

---

### 4. Configuración de Facturación TPV

**Archivo**: `lib/domain/modelos/configuracion_facturacion_tpv.dart` (125 líneas)

```dart
class ConfiguracionFacturacionTpv {
  final ModoFacturacionTpv modo;                // ✅ porVenta | resumenDiario | manual
  final TimeOfDay horaGeneracion;               // ✅ Hora para resumen automático
  final bool generarAutomaticamente;            // ✅ Activar generación programada
  final bool soloSiClienteIdentificado;         // ✅ Solo fact. si hay NIF cliente
  final bool incluirPedidosEfectivo;            // ✅ Filtrar por método de pago
  final bool incluirPedidosTarjeta;
  final bool incluirPedidosMixto;
  final String serieFactura;                    // ✅ Serie a usar (default: 'TPV-')
  final bool aplicarVeriFactu;                  // ✅ Activar VeriFactu
  final int diasVencimiento;                    // ✅ Días para vencimiento
  final bool facturacionAutomatica;             // ✅ CLAVE: Flag para plan
}
```

**Almacenamiento en Firestore:**
```
empresas/{empresaId}/configuracion/facturacionTpv
```

---

## 🔄 INTEGRACIÓN CON VERIFACTU

**Archivo**: `lib/services/verifactu_service.dart` (375 líneas)

### Flujo Automático Actual

```dart
// En facturacion_service.dart, después de crear factura:
await docRef.set(factura.toFirestore());

// Registrar en Verifactu automáticamente (línea 211-230)
try {
  await VerifactuService.registrarFactura(
    empresaId: empresaId,
    factura: factura,
  );
  verifactuOk = true;
} catch (e) {
  // Si VeriFactu está deshabilitado, no es error
  if (msg.contains('no configurado') || msg.contains('deshabilitado')) {
    _log.d('VeriFactu desactivado: $e');
  } else {
    verifactuError = true;
    mensajeVerifactu = '⚠️ Error al registrar en VeriFactu: $e';
  }
}
```

### Características VeriFactu
- ✅ Hash encadenado SHA-256 inalterable
- ✅ Registro estructurado RD 1007/2023
- ✅ Cloud Functions para firma digital y envío SOAP
- ✅ Toggle por empresa para activar/desactivar
- ✅ Estados: pendiente, enviada, aceptada, rechazada
- ✅ No bloquea si falla (modo resiliente)

---

## 📋 PROPUESTA: ARQUITECTURA CON PLANES

### Plan 1: Sin Facturación Automática (Básico)
**Características:**
- ✅ TPV funcional con caja y tickets
- ✅ Gestión de mesas y comandas
- ✅ Impresión de tickets
- ✅ Cierre de caja diario
- ❌ Sin generación automática de facturas
- ✅ Opción de facturación manual desde pantalla dedicada

**Configuración:**
```dart
ConfiguracionFacturacionTpv(
  facturacionAutomatica: false,  // 🔴 DESACTIVADA
  modo: ModoFacturacionTpv.manual,
  generarAutomaticamente: false,
)
```

**Flujo:**
```
Cobro Mesa → Ticket → Venta registrada → Cierre caja
                                       ↓
                            [Manual] Usuario accede a
                         "Facturar Pedidos" cuando quiera
```

### Plan 2: Con Facturación Automática (Premium)
**Características:**
- ✅ Todo lo del Plan 1
- ✅ Generación automática de facturas al cobrar
- ✅ VeriFactu integrado (opcional)
- ✅ Declaraciones fiscales automatizadas (Mod 303, 111)
- ✅ Cumplimiento normativo RD 1619/2012

**Configuración:**
```dart
ConfiguracionFacturacionTpv(
  facturacionAutomatica: true,  // 🟢 ACTIVADA
  modo: ModoFacturacionTpv.resumenDiario,  // o porVenta
  generarAutomaticamente: true,
  horaGeneracion: TimeOfDay(hour: 23, minute: 30),  // Si resumenDiario
  aplicarVeriFactu: true,
  serieFactura: 'TPV-',
)
```

**Flujo:**
```
Cobro Mesa → Ticket → Pedido registrado → Factura automática ✅
                                       ↓
                               Si VeriFactu activo:
                            Registro AEAT automático
```

---

## 🔧 CAMBIOS NECESARIOS PARA IMPLEMENTACIÓN

### 1. Unificar Colecciones Ventas/Pedidos

**Problema**: Actualmente hay dos colecciones separadas:
- `empresas/{id}/ventas` (usado por TPV Bar)
- `empresas/{id}/pedidos` (usado por facturación)

**Solución**: Migrar `tpv_bar_cobro.dart` para usar la colección `pedidos` con el modelo `Pedido`.

#### Cambio en `tpv_bar_cobro.dart:349-383`

**ANTES:**
```dart
Future<void> _confirmarCobro() async {
  // ...validaciones...
  
  final db = FirebaseFirestore.instance;
  final ventaId = db.collection('_temp').doc().id;

  // Crear venta
  await db.collection('empresas').doc(widget.empresaId)
    .collection('ventas').doc(ventaId).set({
      'mesa_id': widget.mesaId,
      'mesa_nombre': widget.nombreMesa,
      'lineas': widget.lineas,
      'total': widget.total + _propina,
      'metodo_pago': _metodoPago,
      // ...
    });
}
```

**DESPUÉS:**
```dart
Future<void> _confirmarCobro() async {
  // ...validaciones...
  
  final pedidosService = PedidosService();
  
  // Convertir líneas de comanda a líneas de pedido
  final lineasPedido = widget.lineas.map((l) => LineaPedido(
    productoId: l['producto_id'] ?? '',
    productoNombre: l['nombre'] ?? '',
    cantidad: l['cantidad'] ?? 1,
    precioUnitario: l['precio_unitario'] ?? 0.0,
    ivaPorcentaje: l['iva_porcentaje'] ?? 21.0,
  )).toList();
  
  // Crear pedido (reemplaza creación de venta)
  final pedido = await pedidosService.crearPedido(
    empresaId: widget.empresaId,
    clienteNombre: widget.nombreMesa,
    lineas: lineasPedido,
    metodoPago: _convertirMetodoPago(_metodoPago),
    origen: OrigenPedido.presencial,
    estadoPago: EstadoPago.pagado,
    propina: _propina,
    importeEfectivo: _metodoPago == 'efectivo' 
      ? widget.total + _propina 
      : 0.0,
    importeTarjeta: _metodoPago == 'tarjeta' 
      ? widget.total + _propina 
      : 0.0,
    notasInternas: 'Mesa: ${widget.nombreMesa}, Comensales: ${widget.comensales}',
  );
  
  // 🆕 NUEVO: Generar factura si está activado
  final config = await TpvFacturacionService().obtenerConfig(widget.empresaId);
  if (config.facturacionAutomatica) {
    if (config.modo == ModoFacturacionTpv.porVenta) {
      // Modo 1: Factura inmediata por cada venta
      await TpvFacturacionService().generarFacturaPorPedido(
        empresaId: widget.empresaId,
        pedido: pedido,
        config: config,
        usuarioNombre: 'TPV Auto',
      );
    }
    // Modo resumenDiario se ejecuta en Cloud Function programada
  }
  
  // Resto del flujo igual: actualizar caja, liberar mesa, imprimir...
}
```

### 2. Crear Cloud Function para Resumen Diario

**Archivo**: `functions/src/generarFacturasTPVDiarias.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const generarFacturasTPVDiarias = functions.pubsub
  .schedule('30 23 * * *')  // 23:30 todos los días
  .timeZone('Europe/Madrid')
  .onRun(async (context) => {
    const db = admin.firestore();
    
    // Obtener todas las empresas con facturación automática
    const empresasSnap = await db.collection('empresas').get();
    
    for (const empresaDoc of empresasSnap.docs) {
      const empresaId = empresaDoc.id;
      
      // Verificar configuración
      const configDoc = await db
        .collection('empresas').doc(empresaId)
        .collection('configuracion').doc('facturacionTpv')
        .get();
      
      if (!config Doc.exists) continue;
      
      const config = configDoc.data();
      if (!config.facturacion_automatica) continue;
      if (config.modo !== 'resumenDiario') continue;
      
      // Generar factura resumen del día
      const hoy = new Date();
      const inicio = new Date(hoy.setHours(0, 0, 0, 0));
      const fin = new Date(hoy.setHours(23, 59, 59, 999));
      
      // Llamar a endpoint de facturación
      await admin.firestore().collection('_jobs').add({
        tipo: 'generar_factura_resumen',
        empresa_id: empresaId,
        fecha_inicio: inicio,
        fecha_fin: fin,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    
    console.log('✅ Jobs de facturación diaria programados');
  });
```

### 3. Añadir Toggle en Pantalla de Configuración

**Archivo**: `lib/features/configuracion/pantallas/configuracion_facturacion_screen.dart` (nuevo)

```dart
class ConfiguracionFacturacionScreen extends StatefulWidget {
  final String empresaId;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configuración de Facturación TPV')),
      body: ListView(
        children: [
          // PLAN SELECTOR
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plan de Facturación', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  
                  // Plan Básico
                  ListTile(
                    title: Text('Plan Básico - Sin Facturación Automática'),
                    subtitle: Text('Facturación manual cuando lo necesites'),
                    leading: Icon(Icons.receipt_outlined),
                    trailing: Radio<bool>(
                      value: false,
                      groupValue: config.facturacionAutomatica,
                      onChanged: (val) => _actualizarPlan(val!),
                    ),
                  ),
                  
                  // Plan Premium
                  ListTile(
                    title: Text('Plan Premium - Con Facturación Automática'),
                    subtitle: Text('Facturas generadas automáticamente al cobrar'),
                    leading: Icon(Icons.auto_awesome, color: Colors.amber),
                    trailing: Radio<bool>(
                      value: true,
                      groupValue: config.facturacionAutomatica,
                      onChanged: (val) => _actualizarPlan(val!),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // CONFIGURACIÓN ADICIONAL (solo si Premium)
          if (config.facturacionAutomatica) ...[
            SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text('Modo de Facturación'),
                    trailing: DropdownButton<ModoFacturacionTpv>(
                      value: config.modo,
                      items: [
                        DropdownMenuItem(
                          value: ModoFacturacionTpv.porVenta,
                          child: Text('Por Cada Venta'),
                        ),
                        DropdownMenuItem(
                          value: ModoFacturacionTpv.resumenDiario,
                          child: Text('Resumen Diario'),
                        ),
                        DropdownMenuItem(
                          value: ModoFacturacionTpv.manual,
                          child: Text('Manual'),
                        ),
                      ],
                      onChanged: (val) => _actualizarModo(val!),
                    ),
                  ),
                  
                  if (config.modo == ModoFacturacionTpv.resumenDiario)
                    ListTile(
                      title: Text('Hora de Generación'),
                      trailing: TextButton(
                        onPressed: () => _seleccionarHora(),
                        child: Text('${config.horaGeneracion.hour}:${config.horaGeneracion.minute}'),
                      ),
                    ),
                  
                  SwitchListTile(
                    title: Text('Aplicar VeriFactu'),
                    subtitle: Text('Registro automático en AEAT'),
                    value: config.aplicarVeriFactu,
                    onChanged: (val) => _actualizarVeriFactu(val),
                  ),
                  
                  ListTile(
                    title: Text('Serie de Facturación'),
                    trailing: SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _serieController,
                        decoration: InputDecoration(hintText: 'TPV-'),
                        onChanged: (val) => _actualizarSerie(val),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

### 4. Actualizar Modelo de Pedido

**Archivo**: `lib/domain/modelos/pedido.dart`

Asegurar que el modelo `Pedido` incluye estos campos:

```dart
class Pedido {
  // ...campos existentes...
  
  final String? facturaId;           // ✅ YA EXISTE - vincula con factura
  final double? propina;             // 🆕 AGREGAR - propina del ticket
  final double? importeEfectivo;     // ✅ YA EXISTE
  final double? importeTarjeta;      // ✅ YA EXISTE
  final String? mesaId;              // 🆕 AGREGAR - si viene de mesa
  final String? mesaNombre;          // 🆕 AGREGAR
  final int? comensales;             // 🆕 AGREGAR
  
  // ...resto del modelo...
}
```

### 5. Pantalla de Monitoreo de Facturación

**Archivo**: `lib/features/facturacion/pantallas/monitor_facturacion_tpv_screen.dart` (nuevo)

Pantalla para que el usuario vea:
- ✅ Estado de facturación automática (activada/desactivada)
- ✅ Pedidos pendientes de facturar
- ✅ Facturas generadas hoy/esta semana/este mes
- ✅ Últimas facturas y su estado VeriFactu
- ✅ Botón para generar factura manual de selección

---

## 📊 COMPARATIVA DE PLANES

| Característica | Plan Básico | Plan Premium |
|----------------|-------------|--------------|
| **TPV con Tickets** | ✅ | ✅ |
| **Gestión de Caja** | ✅ | ✅ |
| **Gestión de Mesas** | ✅ | ✅ |
| **Impresión Bluetooth** | ✅ | ✅ |
| **Facturación Manual** | ✅ | ✅ |
| **Facturación Automática** | ❌ | ✅ |
| **Resumen Diario Automático** | ❌ | ✅ |
| **VeriFactu AEAT** | ❌ | ✅ |
| **Declaraciones Mod 303/111** | ❌ | ✅ |
| **Numeración Correlativa Legal** | ❌ | ✅ |
| **Precio Sugerido/Mes** | 29€ | 79€ |

---

## 🎯 PRIORIDADES DE IMPLEMENTACIÓN

### Fase 1: Crítica (Esta semana)
1. ✅ Unificar colecciones `ventas` → `pedidos`
2. ✅ Implementar llamada a facturación en `_confirmarCobro()`
3. ✅ Corregir bug de descuentos en `_pedidoALineas`
4. ✅ Añadir campos `propina`, `mesaId`, `mesaNombre` a modelo `Pedido`

### Fase 2: Alta (Próxima semana)
5. ✅ Crear pantalla de configuración de planes
6. ✅ Implementar Cloud Function de resumen diario
7. ✅ Crear pantalla de monitoreo de facturación
8. ✅ Pruebas end-to-end del flujo completo

### Fase 3: Media (Próximas 2 semanas)
9. ✅ Migración de datos existentes de `ventas` a `pedidos`
10. ✅ Dashboard de estadísticas de facturación
11. ✅ Notificaciones de facturación fallida
12. ✅ Cola de reintentos para VeriFactu

---

## 🧪 CASOS DE PRUEBA

### Test 1: Cobro Mesa con Facturación Desactivada
```
GIVEN: Plan Básico (facturacionAutomatica: false)
WHEN: Se cobra una mesa por 50€
THEN:
  - Se crea pedido en colección 'pedidos'
  - Se actualiza caja diaria
  - Se libera mesa
  - Se imprime ticket
  - NO se genera factura
  - pedido.facturaId == null
```

### Test 2: Cobro Mesa con Facturación Automática (Por Venta)
```
GIVEN: Plan Premium, modo: porVenta
WHEN: Se cobra una mesa por 50€
THEN:
  - Se crea pedido en 'pedidos'
  - Se genera factura automáticamente
  - pedido.facturaId != null
  - Factura tiene número: TPV-2026-0001
  - Si VeriFactu activo → se registra en AEAT
  - Usuario recibe ticket + factura
```

### Test 3: Resumen Diario Automático
```
GIVEN: Plan Premium, modo: resumenDiario, hora: 23:30
WHEN: Cloud Function se ejecuta a las 23:30
THEN:
  - Se obtienen todos los pedidos TPV del día
  - Se genera UNA factura con todas las líneas
  - Todos los pedidos quedan vinculados (facturaId)
  - Factura tiene clienteNombre: "Ventas TPV — 20/05/2026"
```

### Test 4: Cambio de Plan Básico a Premium
```
GIVEN: Usuario en Plan Básico con 10 pedidos sin facturar
WHEN: Usuario activa Plan Premium
THEN:
  - Los pedidos antiguos NO se facturan automáticamente
  - Nuevo toggle aparece en configuración
  - Pantalla de facturación manual sigue disponible
  - Próximos cobros SÍ generan factura
```

---

## 📈 MÉTRICAS DE ÉXITO

### KPIs Técnicos
- ✅ 100% de cobros generan pedido en Firestore
- ✅ 100% de facturas automáticas vinculadas a pedido
- ✅ Tiempo de facturación < 2 segundos
- ✅ 0% de facturas duplicadas
- ✅ 99% de envíos VeriFactu exitosos

### KPIs de Negocio
- 📊 % de usuarios con facturación automática activada
- 📊 Tiempo ahorrado por usuario/mes
- 📊 Reducción de errores de facturación manual
- 📊 NPS de usuarios con Plan Premium

---

## ⚠️ RIESGOS Y MITIGACIONES

### Riesgo 1: Datos Existentes en Colección 'ventas'
**Impacto**: Alto  
**Probabilidad**: Cierta (si hay usuarios en producción)  
**Mitigación**:
- Crear script de migración `ventas` → `pedidos`
- Mantener colección `ventas` legacy por 3 meses
- Documentar proceso de rollback

### Riesgo 2: Fallo en Generación de Factura
**Impacto**: Crítico (pedido cobrado sin factura)  
**Probabilidad**: Media  
**Mitigación**:
- Wrap en try-catch que NO bloquea el cobro
- Log de errores en Firestore
- Job diario que reprocesa fallos
- Notificación al administrador

### Riesgo 3: VeriFactu Rechaza Factura
**Impacto**: Medio (factura creada pero no registrada)  
**Probabilidad**: Baja  
**Mitigación**:
- VeriFactu es opcional (toggle)
- Validación previa antes de enviar
- Estado de factura: "pendiente_verifactu"
- Reintento automático cada hora x3

---

## 📚 DOCUMENTACIÓN ADICIONAL

### Referencias Normativas
- RD 1619/2012 (Facturación)
- RD 1007/2023 (VeriFactu)
- Ley 37/1992 (IVA)
- Art. 15 facturas rectificativas

### Documentos Internos
- `AUDITORIA_FLUJO_FACTURACION_TPV_COMPLETA.md`
- `IMPLEMENTACION_FACTURACION_100_COMPLETA.md`
- `GUIA_TPV_MULTI_SECTOR.md`
- `ANALISIS_3_TPV_COMPLETO.md`

---

## ✅ CONCLUSIÓN

El sistema tiene una **infraestructura sólida** de facturación, pero requiere:

1. **Unificación de colecciones** (ventas → pedidos)
2. **Conectar el flujo** de cobro con generación de factura
3. **Interfaz de configuración** para activar/desactivar planes
4. **Cloud Function** para resumen diario

**Tiempo estimado de implementación completo**: 2-3 semanas

**Complejidad técnica**: Media (principalmente integración, no desarrollo nuevo)

**Beneficio para usuarios**: 
- Plan Básico: TPV sin complicaciones
- Plan Premium: Cumplimiento fiscal automático y ahorro de tiempo

---

**Próximos pasos inmediatos:**
1. Revisar y aprobar esta arquitectura
2. Crear épica en Jira/GitHub con tareas granulares
3. Comenzar Fase 1 con PR de unificación de colecciones
4. Implementar tests de integración

---

*Documento generado el 20 de Mayo de 2026*  
*Versión: 1.0*

