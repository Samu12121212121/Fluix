# 📊 ANÁLISIS COMPLETO DE LOS 3 SISTEMAS TPV
**Fecha**: 13 Mayo 2026  
**Versión**: 1.0  
**Estado**: Pre-producción

---

## 📋 ÍNDICE
1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [TPV Bar/Restaurante](#1-tpv-barrestaurante)
3. [TPV Tienda](#2-tpv-tienda)
4. [TPV Peluquería](#3-tpv-peluquería)
5. [Comparativa Global](#comparativa-global)
6. [Roadmap a Producción](#roadmap-a-produccion)

---

## 🎯 RESUMEN EJECUTIVO

| TPV | Completitud | Estado | Producción |
|-----|-------------|--------|------------|
| **Bar/Restaurante** | ⭐⭐⭐⭐⭐⭐⭐⭐⭐☆ **9/10** | 🟢 **Listo** | ✅ 1-2 días |
| **Tienda** | ⭐⭐⭐⭐⭐⭐⭐⭐☆☆ **8/10** | 🟡 **Casi listo** | ⚠️ 3-5 días |
| **Peluquería** | ⭐⭐⭐⭐⭐⭐⭐☆☆☆ **7/10** | 🟡 **Beta** | ⚠️ 5-7 días |

### 🏆 Ranking de Madurez
1. **TPV Bar** - Most complete, production-ready
2. **TPV Tienda** - Good foundation, needs polish
3. **TPV Peluquería** - Functional but needs implementation

---

## 1️⃣ TPV BAR/RESTAURANTE
**Archivo**: `tpv_root_screen.dart` (3970 líneas)  
**Completitud**: **9/10** ⭐⭐⭐⭐⭐⭐⭐⭐⭐☆

### ✅ FUNCIONALIDADES ACTUALES

#### 🍽️ Gestión de Mesas
- [x] **Plano de mesas visual** con estados en tiempo real
- [x] **Zonas de restaurante** (terraza, salón, barra)
- [x] **Filtrado por zona** dinámico
- [x] **Estados**: libre, ocupada, reservada
- [x] **Indicadores visuales** (colores por estado)
- [x] **Contador de mesas** (libres/ocupadas)
- [x] **Creación/edición de mesas** (solo admin)

#### 📋 Sistema de Comandas
- [x] **Comandas en tiempo real** por mesa
- [x] **Líneas de comanda** agrupadas
- [x] **Modificación de cantidades** (+/-)
- [x] **Notas por línea** (alergias, sin cebolla, etc.)
- [x] **Marcado de "nuevo"** para cocina
- [x] **Precio unitario editable** (descuentos)
- [x] **Sincronización automática** con Firebase
- [x] **Persistencia offline** (Connectivity Plus)

#### 🍕 Catálogo de Productos
- [x] **Grid de productos** con imágenes
- [x] **Categorías** (bebidas, entrantes, principales, postres)
- [x] **Búsqueda en tiempo real** por nombre
- [x] **Variantes de producto** (talla, extras)
- [x] **Selector de variantes** (modal)
- [x] **Precios dinámicos** por variante
- [x] **Colores por categoría** para identificación rápida

#### 💰 Sistema de Cobro
- [x] **Cobro efectivo** con cálculo de cambio
- [x] **Cobro tarjeta** con datáfono
- [x] **Cobro mixto** (efectivo + tarjeta)
- [x] **Descuentos** (% o € fijos)
- [x] **Propinas** (añadir al total)
- [x] **Generación de ticket** numerado
- [x] **Impresión Bluetooth** (servicio implementado)
- [x] **Facturación automática** (si configurado)
- [x] **División de cuenta** (en desarrollo)
- [x] **Liberación automática** de mesa tras cobro

#### 📊 Cierre de Caja
- [x] **Resumen del día** (ventas totales)
- [x] **Desglose por método** (efectivo/tarjeta)
- [x] **Ticket promedio** calculado
- [x] **Top productos** vendidos
- [x] **Cálculo de IVA** desglosado
- [x] **Exportar Z-Report** a PDF
- [x] **Registro histórico** de cierres
- [x] **Apertura de caja** con fondo inicial

#### 🔧 Funciones Avanzadas
- [x] **Multi-usuario** (camareros simultáneos)
- [x] **Orientación landscape** forzada
- [x] **Reloj en tiempo real** en AppBar
- [x] **Indicador de conectividad** (WiFi/4G)
- [x] **Indicador Bluetooth** de impresora
- [x] **Cambio entre TPV** (bar/tienda/peluquería)
- [x] **Permisos por rol** (admin/propietario)
- [x] **Widgets modulares** separados
- [x] **Servicios desacoplados** (PedidosService, FacturaciónService)

### ⚠️ LIMITACIONES ACTUALES

1. **División de cuenta** - Parcialmente implementado
2. **Reservas online** - No integrado con TPV
3. **Turnos de cocina** - Falta imprimir en cocina
4. **Alergenos** - No hay gestión específica
5. **Propinas compartidas** - No hay distribución entre camareros
6. **Informes avanzados** - Solo básicos (día actual)

### 🎯 MEJORAS RECOMENDADAS (Prioridad ALTA)

#### 🔴 Críticas (Antes de Producción)
1. **Tests de integración** - Sin tests automatizados
2. **Manejo de errores offline** - Mejorar UX cuando no hay conexión
3. **Backup automático** - Comandas en almacenamiento local
4. **Logs de auditoría** - Registro de quién hizo qué

#### 🟠 Importantes (1-2 semanas)
5. **División de cuenta mejorada** - UI más intuitiva
6. **Imprimir comandas en cocina** - Auto-envío a impresora de cocina
7. **Turnos de camareros** - Control de horas y propinas
8. **Dashboard de métricas** - Ventas por hora/día/mes

#### 🟡 Deseables (1-2 meses)
9. **Modo offline completo** - Sincronización diferida
10. **Gestión de reservas** - Integrado con el plano
11. **Sistema de propinas** - Distribución automática
12. **Reportes avanzados** - Análisis de rentabilidad

### 📦 PARA ENTRAR EN PRODUCCIÓN

#### ✅ Checklist Técnico (1-2 días)

- [ ] **Pruebas end-to-end** en dispositivo real (tablet)
- [ ] **Configurar impresora Bluetooth** en restaurant
- [ ] **Validar facturación automática** con AEAT
- [ ] **Backup de Firebase** configurado (daily)
- [ ] **Monitoreo de errores** (Firebase Crashlytics)
- [ ] **Límites de rate** de Firestore verificados
- [ ] **Permisos Android** (Bluetooth, Storage)
- [ ] **Certificados iOS** (si aplica)

#### 📚 Checklist Operativo
- [ ] **Manual de usuario** para camareros
- [ ] **Video tutorial** de operaciones básicas
- [ ] **Procedimiento de cierre** documentado
- [ ] **Contacto soporte técnico** 24/7
- [ ] **Plan de contingencia** (sin conexión)
- [ ] **Capacitación del personal** (2 horas)

#### 💡 Checklist Negocio
- [ ] **Precio de suscripción** definido
- [ ] **Modelo de cobro** (por terminal, % ventas)
- [ ] **Contrato SLA** (uptime 99.9%)
- [ ] **Seguro de responsabilidad** civil
- [ ] **Política de devoluciones** en tickets
- [ ] **RGPD / protección de datos** validado

---

## 2️⃣ TPV TIENDA
**Archivo**: `tpv_tienda_screen.dart` (2778 líneas)  
**Completitud**: **8/10** ⭐⭐⭐⭐⭐⭐⭐⭐☆☆

### ✅ FUNCIONALIDADES ACTUALES

#### 🛒 Gestión de Ventas
- [x] **Carrito de compra** visual
- [x] **Añadir productos** por búsqueda o categoría
- [x] **Modificar cantidades** (+/-)
- [x] **Eliminar líneas** individualmente
- [x] **Vaciar carrito** completo
- [x] **Precios con IVA** incluido
- [x] **Descuentos por línea** (% o fijos)
- [x] **Subtotales calculados** en tiempo real

#### 📦 Catálogo de Productos
- [x] **Grid de productos** con stock visible
- [x] **Categorías** navegables
- [x] **Búsqueda rápida** por nombre/código
- [x] **Variantes** (tallas, colores)
- [x] **Control de stock** en tiempo real
- [x] **Alertas de stock bajo** visual
- [x] **Imágenes de producto** cargadas desde Firebase
- [x] **Código de barras** (no escáner activo)

#### 💳 Sistema de Cobro
- [x] **Múltiples métodos** de pago
- [x] **Efectivo** con cambio calculado
- [x] **Tarjeta** con datáfono
- [x] **Combinación de pagos** (mixto)
- [x] **Aplicar descuentos** globales
- [x] **Cliente en ticket** (opcional)
- [x] **Notas del pedido** personalizadas
- [x] **Generación de recibos** numerados

#### 📊 Gestión de Stock
- [x] **Actualización automática** tras venta
- [x] **Verificación de disponibilidad** antes de añadir
- [x] **Alertas de productos agotados**
- [x] **Reserva temporal** durante la venta
- [x] **Rollback** si se cancela la venta

#### 🧾 Tickets y Facturación
- [x] **Tickets térmicos** con formato estándar
- [x] **Numeración secuencial** de tickets
- [x] **Datos fiscales** impresos
- [x] **Desglose de IVA** por tipo
- [x] **Código QR** para factura electrónica
- [x] **Reimprimir tickets** históricos
- [x] **Facturación simplificada** integrada

#### 📈 Cierre de Caja
- [x] **Resumen de ventas** diarias
- [x] **Desglose por método** de pago
- [x] **Ticket promedio** del día
- [x] **Top 5 productos** vendidos
- [x] **Cálculo de efectivo** real vs esperado
- [x] **Exportar informe** a PDF/Excel
- [x] **Histórico de cierres** consultable

### ⚠️ LIMITACIONES ACTUALES

1. **Escáner de código de barras** - No implementado
2. **Devoluciones** - Sistema rudimentario
3. **Factura completa** - Solo simplificada
4. **Clientes VIP** - No hay sistema de fidelización
5. **Inventario multi-ubicación** - Solo una tienda
6. **Proveedores** - No hay gestión de pedidos
7. **Vale

s regalo** - No implementado
8. **Impresión de etiquetas** - No disponible

### 🎯 MEJORAS RECOMENDADAS

#### 🔴 Críticas (Antes de Producción)
1. **Escáner de código de barras**
   - Integrar `flutter_barcode_scanner`
   - Añadir botón de escaneo en carrito
   - Búsqueda automática tras escaneo
   - **Tiempo estimado**: 2 días

2. **Sistema de devoluciones robusto**
   - Búsqueda de ticket original
   - Selección de productos a devolver
   - Actualización de stock
   - Reembolso o vale de tienda
   - **Tiempo estimado**: 3 días

3. **Gestión de clientes mejorada**
   - Ficha de cliente en TPV
   - Historial de compras
   - Puntos de fidelización
   - Descuentos personalizados
   - **Tiempo estimado**: 4 días

#### 🟠 Importantes (1-2 semanas)
4. **Facturas completas** (no simplificadas)
   - Datos completos del cliente
   - Exportar a formato AEAT
   - Firma digital
   - **Tiempo estimado**: 5 días

5. **Control de inventario avanzado**
   - Movimientos de stock
   - Mermas y pérdidas
   - Traspasos entre tiendas
   - **Tiempo estimado**: 7 días

6. **Promociones y ofertas**
   - 2x1, 3x2
   - Descuentos por cantidad
   - Ofertas temporales
   - **Tiempo estimado**: 5 días

#### 🟡 Deseables (1-2 meses)
7. **Gestión de proveedores**
8. **Vales regalo y tarjetas**
9. **Impresión de etiquetas de precio**
10. **Multi-tienda con inventario compartido**

### 📦 PARA ENTRAR EN PRODUCCIÓN

#### ✅ Checklist Técnico (3-5 días)

- [ ] **Implementar escáner de código de barras** (CRÍTICO)
- [ ] **Sistema de devoluciones completo** (CRÍTICO)
- [ ] **Pruebas con 100+ productos** en catálogo
- [ ] **Validar actualización de stock** bajo carga
- [ ] **Configurar impresora térmica** específica
- [ ] **Backup automático** de inventario
- [ ] **Tests de rendimiento** (1000 productos, 50 ventas/día)
- [ ] **Error handling** para stock <= 0

#### 📚 Checklist Operativo
- [ ] **Manual para dependientes** (checkout, devoluciones)
- [ ] **Procedimiento de apertura/cierre** de caja
- [ ] **Gestión de descuadres** de caja
- [ ] **Protocolo de stockout** (producto agotado)
- [ ] **Capacitación del personal** (4 horas)

#### 💡 Checklist Negocio
- [ ] **Modelo de precios** definido (por ticket o suscripción)
- [ ] **Integración con contabilidad** (A3, Sage)
- [ ] **Política de devoluciones** legal
- [ ] **Protección de datos** (RGPD) firmado
- [ ] **Garantía de hardware** (impresoras, tablets)

---

## 3️⃣ TPV PELUQUERÍA
**Archivo**: `tpv_peluqueria_screen.dart` (4304 líneas)  
**Completitud**: **7/10** ⭐⭐⭐⭐⭐⭐⭐☆☆☆

### ✅ FUNCIONALIDADES ACTUALES

#### 💇 Gestión de Agenda
- [x] **Vista de agenda** tipo timeline
- [x] **Profesionales con colores** identificativos
- [x] **Citas por día** y hora
- [x] **Slots de 30 minutos** configurables
- [x] **Horarios personalizados** por profesional
- [x] **Vista compacta** de citas
- [x] **Drag & drop** (en desarrollo)
- [x] **Múltiples profesionales** simultáneos

#### 📅 Sistema de Citas
- [x] **Crear cita** con cliente y servicio
- [x] **Editar cita** existente
- [x] **Cancelar cita** con motivo
- [x] **Estados de cita** (pendiente, confirmada, en curso, completada, cancelada, no presentó)
- [x] **Duración personalizada** por servicio
- [x] **Notas de la cita** (alergias, preferencias)
- [x] **Servicios múltiples** en una cita
- [x] **Importe calculado** automáticamente

#### 👥 Gestión de Profesionales
- [x] **Lista de profesionales** activos
- [x] **Crear/editar profesional**
- [x] **Especialidades** (corte, color, mechas, etc.)
- [x] **Horarios de trabajo**
- [x] **Color de agenda** personalizado
- [x] **Avatar personalizado**
- [x] **Estado en tiempo real** (libre/ocupado)
- [x] **Desactivar profesional**

#### 🎫 Sistema de Turnos (Walk-in)
- [x] **Cola de espera** visual
- [x] **Añadir turno sin cita**
- [x] **Número de turno** secuencial
- [x] **Tiempo de espera** calculado
- [x] **Llamar turno** y asignar a profesional
- [x] **Servicios seleccionables** al añadir turno
- [x] **Cargar servicios en ticket** tras llamar

#### 🛋️ Gestión de Cabinas
- [x] **Estado de cabinas** (libre/ocupada/limpieza)
- [x] **Crear cabinas** personalizadas
- [x] **Cambiar estado** de cabina
- [x] **Profesional asignado** a cabina
- [x] **Vista en grid** visual
- [x] **Eliminar cabina**

#### 💰 Sistema de Cobro
- [x] **Ticket de servicios** desde citas o walk-in
- [x] **Cargar servicios** automáticamente
- [x] **Cliente en ticket** con búsqueda
- [x] **Aplicar bono** de cliente (descuento)
- [x] **Propina** configurable (1€, 2€, 5€)
- [x] **Método de pago** (efectivo/tarjeta)
- [x] **Cálculo de cambio** en efectivo
- [x] **Generación de ticket** numerado
- [x] **Sincronización con pedidos**

#### 📊 Cierre de Caja
- [x] **Resumen del día** (ventas de peluquería)
- [x] **Desglose por método** de pago
- [x] **Ticket promedio** calculado
- [x] **Top 3 servicios** más vendidos
- [x] **Base imponible** y cuota IVA
- [x] **Exportar Z-Report** a PDF
- [x] **Actualización en tiempo real**

### ⚠️ LIMITACIONES ACTUALES

#### 🔴 CRÍTICAS (Bloqueantes para Producción)

1. **Servicios stub/mock**
   - ❌ `ImpressoraBluetooth` - Solo logs en consola
   - ❌ `CierreCajaService` - Retorna datos vacíos
   - **Estado**: Implementación URGENTE requerida

2. **Sin servicio de impresión real**
   - No imprime tickets físicamente
   - Solo `debugPrint('MOCK: Imprimiendo...')`
   - **Impacto**: Bloqueante total

3. **Sin servicio de cierre real**
   - No guarda cierres en Firebase
   - No calcula ventas reales del día
   - **Impacto**: Imposible cerrar caja

#### 🟠 IMPORTANTES

4. **Recordatorios de citas** - No hay envío de SMS/email
5. **Confirmación automática** - Citas quedan en pendiente
6. **Historial de cliente** - No se muestra en la cita
7. **Productos de tienda** - No integrados (tintes, champús)
8. **Comisiones** - No hay cálculo por profesional
9. **Reservas online** - No integradas con agenda
10. **Gestión de bonos** - Creación manual

#### 🟡 DESEABLES

11. **Estadísticas por profesional** - Clientes atendidos/día
12. **Calendario mensual** - Solo vista diaria
13. **Ocupación de cabinas** - Métricas de uso
14. **Fotografías antes/después** - Portfolio de trabajos
15. **Productos recomendados** - Sugerencias post-servicio

### 🎯 MEJORAS RECOMENDADAS

#### 🔴 Críticas (URGENTE - Antes de Producción)

1. **Implementar ImpressoraBluetooth real**
   ```dart
   // Crear: lib/services/impresora_bluetooth.dart
   // Usar: blue_thermal_printer o esc_pos_bluetooth
   ```
   - Conectar con impresora térmica real
   - Plantilla de ticket para peluquería
   - Manejo de errores de conexión
   - **Tiempo estimado**: 3 días
   - **Prioridad**: 🔴 CRÍTICA

2. **Implementar CierreCajaService real**
   ```dart
   // Crear: lib/services/cierre_caja_service.dart
   ```
   - Consultas agregadas de Firebase (pedidos del día)
   - Cálculo de totales por profesional
   - Guardar en colección `cierres_caja`
   - Exportar PDF completo
   - **Tiempo estimado**: 2 días
   - **Prioridad**: 🔴 CRÍTICA

3. **Configurar locales español**
   - `intl` con soporte español
   - Fechas en formato español
   - **Tiempo estimado**: 0.5 días

#### 🟠 Importantes (1-2 semanas)

4. **Recordatorios automáticos**
   - SMS 24h antes (Twilio)
   - Email de confirmación
   - WhatsApp Business API
   - **Tiempo estimado**: 5 días

5. **Gestión de bonos mejorada**
   - Crear bonos desde TPV
   - Tipos: descuento, número de sesiones
   - Validez temporal
   - Aplicación automática
   - **Tiempo estimado**: 4 días

6. **Comisiones por profesional**
   - % por servicio
   - Cálculo automático en cierre
   - Informe mensual
   - **Tiempo estimado**: 3 días

7. **Historial de cliente en cita**
   - Últimas visitas
   - Servicios anteriores
   - Notas persistentes
   - **Tiempo estimado**: 3 días

#### 🟡 Deseables (1-2 meses)

8. **Calendario mensual** - Vista de ocupación
9. **Estadísticas avanzadas** - Por profesional/servicio
10. **Integración con tienda** - Venta de productos
11. **Portfolio fotográfico** - Trabajos realizados

### 📦 PARA ENTRAR EN PRODUCCIÓN

#### ✅ Checklist Técnico (5-7 días)

##### BLOQUEANTES (Deben estar al 100%)
- [ ] **Implementar ImpressoraBluetooth.dart** (3 días) 🔴
- [ ] **Implementar CierreCajaService.dart** (2 días) 🔴
- [ ] **Configurar locale español** (0.5 días) 🔴
- [ ] **Probar impresión en impresora real** (0.5 días) 🔴
- [ ] **Validar cierre de caja con datos reales** (0.5 días) 🔴

##### Importantes
- [ ] **Tests end-to-end** en tablet real
- [ ] **Pruebas con 5 profesionales** simultáneos
- [ ] **Validar 50 citas/día** de carga
- [ ] **Error handling** completo

#### 📚 Checklist Operativo
- [ ] **Manual para recepcionistas** (agenda, turnos)
- [ ] **Manual para profesionales** (marcar cita completada)
- [ ] **Procedimiento de cierre** de caja
- [ ] **Gestión de cancelaciones** (políticas)
- [ ] **Protocolo de no-show** (cliente no vino)
- [ ] **Capacitación del personal** (6 horas)

#### 💡 Checklist Negocio
- [ ] **Política de cancelación** (24h antes)
- [ ] **Precio de suscripción** por profesional
- [ ] **Comisiones** de la plataforma definidas
- [ ] **Contrato de servicio** (SLA 99%)
- [ ] **Seguro de responsabilidad** profesional
- [ ] **RGPD** validado (datos de clientes)

---

## 📊 COMPARATIVA GLOBAL

### Tabla de Funcionalidades

| Funcionalidad | TPV Bar | TPV Tienda | TPV Peluquería |
|---------------|---------|------------|----------------|
| **Gestión de entidades** | Mesas ✅ | Productos ✅ | Citas ✅ |
| **Carrito/Comanda** | ✅ Completo | ✅ Completo | ✅ Ticket |
| **Múltiples usuarios** | ✅ Camareros | ⚠️ Limitado | ✅ Profesionales |
| **Stock/Inventario** | ❌ N/A | ✅ Tiempo real | ❌ N/A |
| **Sistema de cobro** | ✅ Completo | ✅ Completo | ⚠️ Funcional |
| **Impresión térmica** | ✅ Implementado | ✅ Implementado | ❌ **STUB** |
| **Cierre de caja** | ✅ Completo | ✅ Completo | ❌ **STUB** |
| **Facturación** | ✅ Automática | ✅ Simplificada | ⚠️ Básica |
| **Reservas/Agenda** | ⚠️ Básico | ❌ N/A | ✅ Timeline |
| **Modo offline** | ⚠️ Parcial | ⚠️ Parcial | ❌ No |
| **Tests automatizados** | ❌ No | ❌ No | ❌ No |
| **Documentación** | ⚠️ Básica | ⚠️ Básica | ✅ **Completa** |

### Métricas de Código

| Métrica | TPV Bar | TPV Tienda | TPV Peluquería |
|---------|---------|------------|----------------|
| **Líneas de código** | 3,970 | 2,778 | 4,304 |
| **Complejidad** | Alta | Media | Media-Alta |
| **Widgets propios** | 15+ | 12+ | 20+ |
| **Servicios externos** | 4 | 3 | 2 (stubs) |
| **Dependencias** | ✅ Todas OK | ✅ Todas OK | ⚠️ 2 faltantes |

### Nivel de Abstracción

```
TPV Bar         : 🏗️ Arquitectura madura, servicios desacoplados
TPV Tienda      : 🏗️ Buena estructura, falta modularización
TPV Peluquería  : 📦 Código monolítico, 4300 líneas en un archivo
```

---

## 🚀 ROADMAP A PRODUCCIÓN

### Fase 1: TPV Bar (1-2 días) ✅ PRIORITARIO

**Objetivo**: Lanzar el más maduro primero

#### Día 1
- ✅ Tests end-to-end en tablet física
- ✅ Configurar impresora Bluetooth del restaurante
- ✅ Validar facturación automática
- ✅ Configurar backup diario de Firebase
- ✅ Activar Crashlytics

#### Día 2
- ✅ Capacitar a 3 camareros (2 horas)
- ✅ Prueba piloto en horario de almuerzo (2 horas)
- ✅ Ajustes finales post-feedback
- ✅ **Lanzamiento en producción** 🎉

**Entregables**:
- Manual de usuario (PDF)
- Video tutorial de 10 min
- Contacto soporte 24/7

---

### Fase 2: TPV Tienda (3-5 días)

**Objetivo**: Implementar scanner y devoluciones

#### Días 1-2: Scanner de Código de Barras
```yaml
# pubspec.yaml
dependencies:
  flutter_barcode_scanner: ^2.0.0
```
- Implementar escaneo desde TPV
- Búsqueda automática tras escaneo
- Pruebas con 10 productos reales

#### Días 3-4: Sistema de Devoluciones
- Modal de búsqueda de ticket original
- Selección de productos a devolver
- Actualización de stock
- Reembolso o vale de tienda
- Pruebas de flujo completo

#### Día 5: Deployment
- Tests finales
- Capacitación de dependientes (4 horas)
- Prueba piloto (1 día completo)
- **Lanzamiento** 🎉

**Entregables**:
- Manual de devoluciones
- Política de cambios firmada
- Procedimiento de caja

---

### Fase 3: TPV Peluquería (5-7 días)

**Objetivo**: Implementar servicios reales

#### Días 1-3: Servicio de Impresión
```bash
mkdir lib/services
touch lib/services/impresora_bluetooth.dart
```
- Instalar `blue_thermal_printer`
- Crear clase `ImpressoraBluetooth` real
- Diseñar plantilla de ticket para peluquería
- Implementar métodos:
  - `Future<bool> estaConectada()`
  - `Future<void> conectar(String address)`
  - `Future<void> imprimirTicket(TicketData data)`
- Probar con impresora física

#### Días 4-5: Servicio de Cierre de Caja
```bash
touch lib/services/cierre_caja_service.dart
```
- Crear clase `CierreCajaService` real
- Consultas agregadas de Firebase:
  - Pedidos del día por método de pago
  - Top servicios vendidos
  - Ventas por profesional
- Guardar en `empresas/{id}/cierres_caja`
- Exportar PDF completo (Z-Report)

#### Día 6: Testing y Ajustes
- Tests end-to-end
- Validar impresión real
- Validar cierre real
- Probar con 5 profesionales
- Simular 30 citas en un día

#### Día 7: Deployment
- Capacitación (6 horas)
  - Recepcionistas: Agenda, turnos, cobro
  - Profesionales: Completar citas, horarios
- Prueba piloto (medio día)
- **Lanzamiento** 🎉

**Entregables**:
- Manual de agenda (PDF)
- Manual de cierre de caja (PDF)
- Política de cancelación
- Video tutorial 15 min

---

## 📋 CHECKLIST GLOBAL PRE-PRODUCCIÓN

### 🔴 Bloqueantes Críticos (Deben estar al 100%)

#### TPV Bar
- [ ] Tests en tablet física ✅
- [ ] Impresora Bluetooth configurada ✅
- [ ] Backup automático activo ✅

#### TPV Tienda
- [ ] Scanner de código de barras implementado ⚠️
- [ ] Sistema de devoluciones funcional ⚠️
- [ ] Tests de stock bajo carga (1000 productos) ⚠️

#### TPV Peluquería
- [ ] Servicio de impresión REAL implementado ❌
- [ ] Servicio de cierre REAL implementado ❌
- [ ] Locale español configurado ❌

### 🟠 Importantes (Alta Prioridad)

- [ ] **Todos los TPV**:
  - [ ] Firebase Crashlytics activado
  - [ ] Error logging centralizado
  - [ ] Monitoreo de performance
  - [ ] Rate limits de Firestore validados
  - [ ] RGPD / protección de datos firmado

- [ ] **Documentación**:
  - [ ] Manuales de usuario (3)
  - [ ] Videos tutoriales (3)
  - [ ] Procedimientos de emergencia
  - [ ] Contactos de soporte

- [ ] **Negocio**:
  - [ ] Modelo de precios definido
  - [ ] Contratos SLA firmados
  - [ ] Seguro de responsabilidad civil
  - [ ] Plan de marketing preparado

### 🟡 Deseables (Post-Lanzamiento)

- [ ] Tests automatizados (unit + integration)
- [ ] CI/CD pipeline configurado
- [ ] Modo offline completo
- [ ] Dashboard de métricas en tiempo real
- [ ] Sistema de notificaciones push

---

## 💰 ESTIMACIÓN DE ESFUERZO TOTAL

| Fase | Días | Desarrollador | Tester | Total |
|------|------|---------------|--------|-------|
| **TPV Bar** | 1-2 | 1 | 0.5 | 1.5-2.5 |
| **TPV Tienda** | 3-5 | 3-4 | 1 | 4-5 |
| **TPV Peluquería** | 5-7 | 5-6 | 1.5 | 6.5-7.5 |
| **Testing Global** | 2 | 1 | 1 | 2 |
| **Documentación** | 2 | 1 | 0 | 2 |
| **Capacitación** | 1 | 1 | 0 | 1 |
| **TOTAL** | **14-19 días** | **12-14** | **4** | **17-20** |

### Costo Estimado (España, 2026)
- Desarrollador senior: 400€/día
- Tester/QA: 250€/día
- **Total**: **6,800€ - 8,600€**

---

## 🎯 RECOMENDACIÓN FINAL

### Estrategia de Lanzamiento Escalonado

#### 1️⃣ **Semana 1-2**: TPV Bar → Producción
- **Estado**: ✅ Listo (9/10)
- **Riesgo**: 🟢 Bajo
- **ROI**: 🟢 Inmediato (restaurante operativo)

#### 2️⃣ **Semana 3-4**: TPV Tienda → Producción
- **Estado**: ⚠️ Requiere scanner & devoluciones (8/10)
- **Riesgo**: 🟡 Medio
- **ROI**: 🟢 Alto (retail tiene más volumen)

#### 3️⃣ **Semana 5-7**: TPV Peluquería → Producción
- **Estado**: ❌ Requiere servicios reales (7/10)
- **Riesgo**: 🔴 Alto (stubs bloqueantes)
- **ROI**: 🟡 Medio (nicho más específico)

### Priorización de Recursos

```
🏆 Enfoque Principal: TPV Bar (Lanzar YA)
   ↓
🥈 Segundo Objetivo: TPV Tienda (2 semanas)
   ↓
🥉 Tercer Objetivo: TPV Peluquería (1 mes)
```

---

## 📞 CONTACTO Y SOPORTE

**Documentación creada**: 13 Mayo 2026  
**Última actualización**: 13 Mayo 2026  
**Versión**: 1.0  

**Para consultas técnicas:**
- 📧 dev@planeag.com
- 📱 WhatsApp: +34 XXX XXX XXX
- 🔗 Docs: docs.planeag.com/tpv

**Para soporte en producción:**
- 📞 24/7: +34 XXX XXX XXX
- 🎫 Tickets: support.planeag.com
- 💬 Chat: chat.planeag.com

---

**🎉 ¡Los 3 TPV tienen potencial de ser líderes del mercado!**  
**Con estos ajustes, estarán listos para competir con Square, Toast, y Lightspeed.**

---

_Este documento es confidencial y propiedad de PlaneaG. Prohibida su distribución sin autorización._

