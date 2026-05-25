# 🚀 Módulo TPV — Guía de Despliegue y Uso

## ✅ Implementación Completada

### Archivos Creados/Modificados

1. **`lib/domain/modelos/mesa.dart`** — Modelo de mesa (102 líneas)
2. **`lib/domain/modelos/comanda.dart`** — Modelos comanda y línea (129 líneas)
3. **`lib/features/tpv/pantallas/tpv_root_screen.dart`** — Módulo completo (1450+ líneas)
4. **`firestore.rules`** — Reglas añadidas para mesas, comandas y contadores

### Funcionalidades Implementadas

#### ✅ Completamente Funcionales
- Orientación paisaje forzada
- AppBar con reloj en tiempo real, botón de salida
- NavigationRail con 3 pestañas
- **Vista Plano de Mesas**:
  - Grid en tiempo real con StreamBuilder
  - Filtros por zona
  - Creación de nueva mesa (admin)
  - Importe dinámico en mesas ocupadas (StreamBuilder de comanda)
  - Panel lateral con resumen
- **Vista Catálogo + Comanda (60/40)**:
  - Catálogo de productos con búsqueda y filtros
  - Selector de variantes con modal bottom sheet
  - Gestión de comanda con +/- controles
  - Notas por línea (long press)
  - Badge "NUEVO" para líneas recientes
  - Desglose IVA correcto desde `Producto.ivaPorcentaje`
- **Vista Cierre de Caja**: Estructura base

#### ⚠️ Requieren Configuración Adicional
- Impresión de ticket BT al cobrar (servicio existe, falta integrar)
- Contador secuencial de tickets
- Método de pago (diálogo completo con mixto)
- Cálculo real de métricas en cierre

---

## 📋 Pasos para Desplegar

### 1. Desplegar Reglas de Firestore

```powershell
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter
firebase deploy --only firestore:rules
```

**Verificar output**:
```
✔ Deploy complete!
```

### 2. Crear Datos Iniciales en Firestore Console

#### A) Inicializar Contador de Tickets

Crear documento manualmente:
```
Colección: empresas/{tu-empresa-id}/contadores
Documento ID: tickets
Campos:
  - ultimo_numero: 0 (número)
```

#### B) Crear Mesas de Prueba

```
Colección: empresas/{tu-empresa-id}/mesas
```

Documento 1 (`mesa1`):
```json
{
  "numero": 1,
  "nombre": "Mesa 1",
  "zona": "Sal��n",
  "capacidad": 4,
  "estado": "libre",
  "comanda_id": null,
  "camarero_uid": null,
  "fecha_apertura": null
}
```

Documento 2 (`mesa2`):
```json
{
  "numero": 2,
  "nombre": "Mesa 2",
  "zona": "Terraza",
  "capacidad": 6,
  "estado": "libre",
  "comanda_id": null,
  "camarero_uid": null,
  "fecha_apertura": null
}
```

Crea al menos 5-10 mesas para hacer pruebas visuales del grid.

#### C) Verificar Productos en Catálogo

Asegúrate de que tienes productos activos con `iva_porcentaje: 10` (bebidas/comida):

```
Colección: empresas/{tu-empresa-id}/catalogo
```

Ejemplo producto con variantes:
```json
{
  "nombre": "Caña",
  "categoria": "Bebidas",
  "precio": 2.50,
  "activo": true,
  "iva_porcentaje": 10,
  "tiene_variantes": true,
  "variantes": [
    {
      "id": "pequeña",
      "nombre": "Pequeña (20cl)",
      "tipo": "tamaño",
      "precio": 2.00,
      "disponible": true
    },
    {
      "id": "grande",
      "nombre": "Grande (50cl)",
      "tipo": "tamaño",
      "precio": 3.50,
      "disponible": true
    }
  ]
}
```

### 3. Integrar en la App Principal

#### Opción A: Añadir al Dashboard

En `lib/features/dashboard/pantallas/pantalla_dashboard.dart`:

```dart
// En la lista de módulos, añadir:
_ModuloCardDash(
  icono: Icons.point_of_sale,
  titulo: 'TPV',
  onTap: () {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TpvRootScreen(
        empresaId: Provider.of<...>(context, listen: false).empresaId,
        esAdmin: _esAdmin,
      ),
    ));
  },
),
```

#### Opción B: Desde el Módulo TPV Existente

En `lib/features/tpv/pantallas/modulo_tpv_screen.dart`, añadir tarjeta al inicio:

```dart
_TarjetaAccionTpv(
  icono: Icons.restaurant,
  titulo: 'TPV Completo (Mesas + Caja)',
  descripcion: 'Modo tablet con plano de mesas, comandas y cierre de caja',
  color: const Color(0xFF1565C0),
  onTap: () => Navigator.push(context, MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => TpvRootScreen(
      empresaId: empresaId,
      esAdmin: esAdmin,
    ),
  )),
),
```

---

## 🧪 Flujo de Prueba Completo

### Test 1: Crear Mesa (Solo Admin)

1. Abrir TPV → pestaña "Mesas"
2. Pulsar botón "+" en barra de zonas
3. Crear mesa: número 10, zona "Barra", capacidad 2
4. Verificar que aparece en el grid en tiempo real

### Test 2: Abrir Comanda en Mesa

1. Tocar una mesa libre (ej: Mesa 1)
2. Se cambia a vista 60/40 automáticamente
3. Header muestra "Mesa 1" con badge "Comanda abierta"
4. Catálogo carga productos

### Test 3: Añadir Productos

1. Tocar un producto SIN variantes → se añade directo
2. Tocar un producto CON variantes (ej: "Caña")
3. Se abre modal selector → elegir variante
4. Verificar que aparece en la comanda con el precio de la variante

### Test 4: Gestionar Líneas

1. Pulsar "+" en una línea → aumenta cantidad
2. Pulsar "-" → disminuye cantidad
3. Mantener pulsada una línea → opciones
   - "Añadir nota" → escribir "sin hielo" → guardar
   - Verificar que aparece "📝 sin hielo" bajo la línea
4. Eliminar línea desde el menú contextual

### Test 5: Ver Importe en Plano de Mesas

1. Volver a "Mesas" (botón X o navegar)
2. La Mesa 1 ahora muestra:
   - Estado: "Ocupada" (fondo naranja)
   - Importe dinámico: "€12.50" (actualizado en tiempo real)

### Test 6: Caja Rápida

1. Navegar a pestaña "Caja"
2. Añadir productos
3. Header muestra "Ticket #XXXX" (sin mesa)
4. Botón papelera limpia el ticket

### Test 7: Cierre de Caja

1. Navegar a pestaña "Cierre" (icono inferior)
2. Ver estructura base de métricas
3. (Métricas reales requieren implementación adicional)

---

## 🔧 Próximos Pasos para Producción

### Alta Prioridad

1. **Implementar Cobro Completo**
   - Diálogo método de pago (efectivo/tarjeta/mixto)
   - Contador secuencial de tickets en transacción
   - Imprimir ticket con `ImpressoraBluetooth`
   - Guardar `importe_efectivo`/`importe_tarjeta` reales
   - Marcar mesa como libre tras cobro

2. **Datos de Empresa en Ticket**
   - Cargar `EmpresaConfig` con nombre, NIF, dirección
   - Pasar a `TicketData` para impresión

3. **Persistir Comandas en Firestore**
   - Actualmente solo vive en memoria (`setState`)
   - Guardar cambios en tiempo real en `empresas/{id}/comandas/{id}`

### Media Prioridad

4. **Cálculo Real de Cierre**
   - Query de pedidos del día con `fecha >= inicio && fecha < fin`
   - Agrupar por método de pago (NO hardcoded 50/50)
   - Top 3 productos del día
   - Desglose IVA real

5. **Indicadores Reales**
   - Wifi/offline usando `connectivity_plus` (ya en pubspec)
   - Estado impresora BT real
   - Resumen del turno con datos reales

6. **Transferir/Dividir Mesa**
   - Diálogos funcionales para estas acciones

### Baja Prioridad

7. **Botón Crear Producto** (FloatingActionButton en catálogo)
8. **Badge de Cantidad** en tarjeta de producto si está en comanda
9. **Modo Offline** con `sqflite` (ya en pubspec)
10. **Z-Report PDF** con `pdf` package (ya en pubspec)

---

## 📱 Compatibilidad

- **Orientación**: Forzada a paisaje (landscape left/right)
- **Dispositivos**: Optimizado para tablet 10"+ (grid 130px por tarjeta)
- **Mínimo recomendado**: 1024x600px (tablet 7")
- **Light/Dark Mode**: Totalmente compatible
- **Material3**: Usa `colorScheme` dinámico

---

## 🐛 Troubleshooting

### Error: "Missing or insufficient permissions" al crear mesa
**Solución**: Desplegar firestore.rules actualizado
```powershell
firebase deploy --only firestore:rules
```

### Las mesas no aparecen
**Verificar**:
1. Reglas desplegadas
2. Usuario tiene rol `staff | admin | propietario`
3. Colección `empresas/{id}/mesas` existe con documentos

### Importe de mesa no se actualiza
**Verificar**:
1. La comanda existe en `empresas/{id}/comandas/{comandaId}`
2. El campo `comanda_id` de la mesa apunta al documento correcto
3. StreamBuilder renderiza (revisar logs de Flutter)

### Selector de variantes no aparece
**Verificar**:
1. Producto tiene `tiene_variantes: true`
2. Campo `variantes` es array no vacío
3. Las variantes tienen `disponible: true`

---

## 📚 Archivos de Referencia

- **Auditoría inicial**: `AUDITORIA_TPV_BAR_HIOPOS.md`
- **Implementación**: `MODULO_TPV_IMPLEMENTACION.md`
- **Este documento**: `TPV_DESPLIEGUE_GUIA.md`

---

*Última actualización: Mayo 7, 2026*

