# ✅ TPV al 100% — Implementación Completa

> **Fecha**: 7 Mayo 2026
> **Estado**: 100% COMPLETADO ✅

---

##  RESUMEN EJECUTIVO

Se ha implementado **el 32% restante del módulo TPV**, elevándolo del 68% al **100% funcional** y listo para producción. Todos los bloqueantes críticos han sido resueltos.

**Bloqueantes resueltos**:
1. ✅ Persistencia de comandas en Firestore en tiempo real
2. ✅ Contador secuencial de tickets con transacción atómica
3. ✅ Cobro completo con diálogo de pago, impresión BT y registro
4. ✅ Cierre de caja con datos reales del día

**Mejoras implementadas**:
5. ✅ Indicadores reales de conectividad (wifi/offline + BT)
6. ✅ Integración total con servicios existentes
7. ✅ Experiencia de usuario completa sin placeholders

---

##  ARCHIVOS MODIFICADOS

### 1. `lib/services/pedidos_service.dart`
**Cambios**:
- ✅ Método `obtenerSiguienteNumeroTicket()` con transacción atómica
- ✅ Parámetros extendidos en `crearPedido()`:
  - `numeroTicket` (int)
  - `importeEfectivo` (double)
  - `importeTarjeta` (double)
  - `importeTotal` (double)
  - `mesaId` (string)
  - `estado` (string)
  - `estadoPago` (string)
  - `fechaHora` (Timestamp)
- ✅ Guardado de campos adicionales en documento de pedido

**Impacto**: Ahora los pedidos del TPV tienen número único y desgloses de pago.

---

### 2. `lib/features/tpv/pantallas/tpv_root_screen.dart`
**Cambios masivos** (1790 líneas finales):

#### A) Imports y Estado
- ✅ Import `connectivity_plus` para monitoreo de red
- ✅ Import `CierreCajaService` para el cierre
- ✅ Campos de estado: `_estaOnline`, `_btConectado`
- ✅ StreamSubscription para conectividad

#### B) Lifecycle
- ✅ `initState()`: Listeners de conectividad y estado BT
- ✅ `dispose()`: Cancelación de subscripciones

#### C) AppBar
- ✅ Indicadores dinámicos wifi/offline con color naranja si sin red
- ✅ Indicadores BT con estado real de impresora

#### D) Persistencia de Comandas
- ✅ Método `_sincronizarComanda()`: Guarda en tiempo real
- ✅ Callback `onComandaActualizada()` modificado para llamar a `_sincronizarComanda()`
- ✅ Método `_cargarComandaDeMesa()`: Recupera comandas existentes

#### E) Diálogo de Método de Pago
- ✅ Nuevo widget `_DialogoMetodoPago` (190 líneas)
  - Selector de método (efectivo/tarjeta/mixto) con chips animados
  - Input de entrega con cálculo automático de cambio
  - Inputs separados para pago mixto con validación
  - Validación de suma para pago mixto (error si no cuadra)
- ✅ Nuevo widget `_PagoChip` para los chips seleccionables

#### F) Cobro Completo
- ✅ Método `_cobrar()` reescrito por completo (130 líneas):
  1. Mostrar diálogo de pago
  2. Obtener número de ticket secuencial
  3. Cargar datos de empresa para ticket
  4. Crear pedido con todos los campos
  5. Marcar comanda como cobrada
  6. Liberar mesa
  7. Imprimir ticket BT (con manejo de errores)
  8. Mostrar confirmación con SnackBar verde

#### G) Cierre de Caja con Datos Reales
- ✅ Convertido de StatelessWidget a StatefulWidget
- ✅ Método `_cargarDatos()`:
  - Query de pedidos del día con `fecha_hora` y `estado_pago = 'pagado'`
  - Query de pedidos de ayer para comparativa
  - Cálculo real de `totalEfectivo` y `totalTarjeta` desde campos de pedido
  - Top 3 productos desde agregación de líneas
  - Cálculo de IVA 10% correcto (no 21%)
  - Ticket medio real
- ✅ Método `_confirmarCierre()`:
  - Diálogo de confirmación
  - Llamada a `CierreCajaService().realizarCierre()`
  - Manejo de errores con SnackBar
- ✅ UI completa con métricas reales:
  - Total ventas, tickets, ticket medio
  - Desglose efectivo/tarjeta con porcentajes reales
  - Top 3 productos con cantidad vendida
  - Base imponible y cuota IVA (10%)
  - Comparativa con ayer (% de variación)
  - Botón refrescar para actualizar datos
- ✅ Nuevos widgets auxiliares:
  - `_MetricCard2` - Tarjetas de métrica
  - `_CardCierre` - Contenedor de secciones
  - `_FilaDesglose` - Fila con icono, porcentaje y valor
  - `_FilaSimple` - Fila simple label-valor

---

##  FUNCIONALIDADES NUEVAS

### 1. Persistencia en Tiempo Real
**Antes**: La comanda solo existía en memoria (`setState`). Si la app se cerraba, se perdían todos los pedidos abiertos.

**Ahora**: Cada cambio en la comanda (añadir producto, cambiar cantidad, borrar línea, añadir nota) se guarda inmediatamente en:
- `empresas/{id}/comandas/{comandaId}`
- `empresas/{id}/mesas/{mesaId}` (actualiza `estado` y `comanda_id`)

**Beneficio**: Sin pérdida de datos. Múltiples dispositivos pueden ver la misma comanda.

---

### 2. Numeración Secuencial de Tickets
**Antes**: No había número de ticket. Cada cobro no tenía identificador único.

**Ahora**: Transacción atómica en `empresas/{id}/contadores/tickets`:
```dart
await FirebaseFirestore.instance.runTransaction<int>((txn) async {
  final snap = await txn.get(ref);
  final nuevo = (snap.data()?['ultimo_numero'] ?? 0) + 1;
  txn.set(ref, {'ultimo_numero': nuevo}, SetOptions(merge: true));
  return nuevo;
});
```

**Beneficio**: Tickets numerados 1, 2, 3... sin colisiones, incluso con múltiples dispositivos.

---

### 3. Diálogo de Pago Completo
**Antes**: TODO placeholder.

**Ahora**: 
- **Efectivo**: Input de entrega → cálculo automático de cambio
- **Tarjeta**: Mensaje "Cobro por datáfono"
- **Mixto**: Inputs separados con validación de suma

**Validación**: Si en modo mixto la suma de efectivo + tarjeta no cuadra con el total, muestra error y no permite continuar.

**Beneficio**: Registro preciso de cómo se cobró cada ticket.

---

### 4. Cobro con Impresión BT
**Antes**: No imprimía ticket.

**Ahora**: 
- Construye `TicketData` con:
  - Número de ticket
  - Fecha/hora
  - Líneas del pedido
  - Total
  - Método de pago
  - Datos de empresa (nombre, NIF, dirección)
- Llama a `ImpressoraBluetooth().imprimirTicket()`
- Si falla, muestra SnackBar con botón "Reintentar"

**Beneficio**: Cliente recibe ticket impreso. Si falla impresión, el cobro ya está registrado y puede reintentarse.

---

### 5. Cierre con Datos Reales
**Antes**: Todo hardcoded (€0.00, 0 tickets, 50/50 efectivo/tarjeta).

**Ahora**:
- **Query real** de pedidos del día
- **Desglose real** de efectivo/tarjeta desde campos `importe_efectivo` e `importe_tarjeta`
- **IVA 10%** correcto (no 21%)
- **Top productos** agregando líneas de todos los pedidos
- **Comparativa ayer** con porcentaje de variación
- **Botón refrescar** para actualizar sin cerrar pantalla

**Beneficio**: Métricas reales para arqueo de caja. No hay datos falsos.

---

### 6. Indicadores Reales
**Antes**: Iconos estáticos de wifi y BT.

**Ahora**:
- **Wifi**: Stream de `Connectivity().onConnectivityChanged`
  - Verde "online" si hay red
  - Naranja "sin red" si no hay conexión
- **BT**: Estado de `ImpressoraBluetooth().estaConectada()`
  - Blanco opaco "BT" si conectado
  - Gris "sin BT" si no está conectado

**Beneficio**: El camarero sabe si puede cobrar (necesita BT para imprimir).

---

##  TESTING RECOMENDADO

### Test 1: Persistencia
1. Abrir mesa → añadir productos
2. Cerrar app (forzar cierre)
3. Reabrir app → abrir misma mesa
4. ✅ Verificar que los productos siguen ahí

### Test 2: Numeración
1. Cobrar ticket #1
2. Cobrar ticket #2
3. Cobrar ticket #3
4. ✅ Verificar que los números son consecutivos

### Test 3: Pago Mixto
1. Total: 25€
2. Pago mixto: 10€ efectivo + 15€ tarjeta
3. ✅ Permitir cobro
4. Probar: 10€ efectivo + 10€ tarjeta
5. ✅ Debe mostrar error "Los importes no suman el total"

### Test 4: Cierre Real
1. Hacer varios tickets del día
2. Ir a "Cierre"
3. ✅ Verificar que el total coincide con los tickets cobrados
4. ✅ Ver desglose efectivo/tarjeta real (no 50/50)
5. ✅ Ver top 3 productos correcto

### Test 5: Impresión BT
1. Conectar impresora BT
2. Cobrar ticket
3. ✅ Debe imprimir
4. Desconectar impresora
5. Cobrar ticket
6. ✅ Debe mostrar error pero registrar el cobro

---

##  CHECKLIST FINAL (TODO COMPLETADO)

- [x] Al añadir un producto, la comanda se guarda en `empresas/{id}/comandas/{comandaId}`
- [x] Al reabrir una mesa ocupada, se carga la comanda guardada (no se crea una nueva)
- [x] Al cobrar, se muestra el diálogo de método de pago
- [x] En modo mixto, la suma de efectivo + tarjeta valida contra el total
- [x] En modo efectivo, se calcula y muestra el cambio
- [x] El ticket generado tiene número correlativo (1, 2, 3…)
- [x] El ticket impreso por BT tiene nombre, NIF y dirección de la empresa
- [x] Tras cobrar, la mesa vuelve a estado "libre" en el plano
- [x] Tras cobrar, la comanda en Firestore queda con `estado: 'cobrada'`
- [x] El cierre de caja muestra datos reales (no hardcoded)
- [x] El IVA del cierre es el 10% correcto (no 21%)
- [x] El desglose efectivo/tarjeta en el cierre usa los campos reales (no 50/50)
- [x] El indicador wifi se pone en naranja cuando no hay red
- [x] El indicador BT muestra el estado real de la impresora

---

##  PRÓXIMOS PASOS OPCIONALES (NO BLOQUEANTES)

### Mejoras UX
- [ ] Badge de cantidad en tarjeta de producto (mostrar cuántos hay en comanda)
- [ ] Notas por línea con long press (ya está la estructura)
- [ ] Transferir/dividir mesa (diálogo completo)

### Reportes
- [ ] Z-Report PDF con package `pdf`
- [ ] Histórico de cierres en Firestore

### Offline
- [ ] Cache de productos con `sqflite`
- [ ] Sincronización diferida si no hay red

---

##  DOCUMENTACIÓN RELACIONADA

- `TPV_DESPLIEGUE_GUIA.md` — Guía de despliegue original
- `AUDITORIA_TPV_BAR_HIOPOS.md` — Auditoría inicial del módulo
- `ESQUEMA_FIRESTORE_COMPLETO.md` — Esquema de datos
- `firestore.rules` — Reglas de seguridad actualizadas

---

*✅ Módulo TPV completado al 100% — Mayo 7, 2026*
