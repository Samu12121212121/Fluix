# Módulo: App Pública, Explorar Negocios, Fidelización y Tienda de Monedas

## Qué es la "app pública"

Fluix tiene dos caras:
1. **App del negocio** — para propietarios/staff de empresas (todos los módulos descritos hasta ahora)
2. **App del cliente final** — para consumidores que quieren explorar y comprar en los negocios que usan Fluix

Los módulos de esta sección pertenecen a la segunda cara (rol `clienteFinal`).

---

## EXPLORAR NEGOCIOS

### Qué hace

Directorio público de todos los negocios registrados en la plataforma Fluix. Los clientes finales pueden buscar, filtrar por categoría y acceder al perfil de cada negocio para hacer reservas, comprar o fidelizarse.

### Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/explorar_negocios/pantallas/pantalla_explorar.dart` | Listado de negocios con búsqueda |

### Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `negocios_publicos` | Catálogo público de negocios |

Esta colección es **lectura pública** (sin autenticación). Cada negocio tiene: nombre, categoría, descripción, logo, fotos, ubicación, horarios y el link a su web de reservas.

---

## PERFIL CLIENTE

### Qué hace

Perfil del cliente final dentro de la app pública: historial de reservas, pedidos, puntos de fidelidad, trofeos desbloqueados y saldo de monedas.

### Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/perfil_cliente/pantallas/pantalla_perfil_cliente.dart` | Mi cuenta y historial |
| `features/perfil_cliente/pantallas/pantalla_trofeos.dart` | Colección de trofeos |
| `features/perfil_cliente/pantallas/pantalla_monedero.dart` | Saldo de monedas |
| `features/perfil_cliente/widgets/avatar_picker_sheet.dart` | Selector de avatar |
| `features/perfil_cliente/widgets/trofeo_desbloqueado_overlay.dart` | Overlay animado al desbloquear trofeo |
| `features/perfil_cliente/models/trofeo_def.dart` | Definición de condiciones de trofeo |

### Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `usuarios/{uid}` | Perfil del cliente final (rol=clienteFinal) |
| `usuarios/{uid}/trofeos` | Trofeos desbloqueados |
| `usuarios/{uid}/monedero` | Saldo actual de monedas |

---

## FIDELIZACIÓN

### Qué hace

Sistema de fidelización basado en sellos digitales (tipo tarjeta de fidelización): el cliente acumula sellos en cada visita al negocio escaneando un QR, y al completar una tarjeta obtiene una recompensa.

### Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/fidelizacion/widgets/carrusel_flash_slots.dart` | Widget de promociones activas |

### Cómo funciona

1. El negocio configura la tarjeta de fidelización: N sellos para una recompensa
2. Al visitar el negocio, el cliente muestra su QR personal desde la app
3. El staff escanea el QR del cliente
4. La Cloud Function `onCheckinFidelizacion` valida el QR y añade un sello
5. Al completar la tarjeta, se crea automáticamente una recompensa disponible
6. Los sellos tienen fecha de caducidad (configurable por el negocio)

### Colecciones Firestore

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/fidelizacion` | Configuración del programa |
| `usuarios/{uid}/sellos` | Sellos por empresa del cliente |
| `empresas/{empresaId}/recompensas` | Catálogo de recompensas |

### Cloud Functions

| Función | Cuándo |
|---------|--------|
| `onCheckinFidelizacion` | Callable — valida QR y registra sello |
| `marcarQRsExpirados` | Scheduled — limpiar QR vencidos |
| `verificarCaducidadSellos` | Scheduled — caducar sellos expirados |

---

## TIENDA DE MONEDAS

### Qué hace

Moneda virtual de la plataforma. Los clientes ganan monedas por actividades (visitas, reservas, valoraciones, trofeos) y las canjean por recompensas en cualquier negocio Fluix.

### Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/tienda_monedas/pantalla_tienda_monedas.dart` | Catálogo de recompensas canjeables |
| `features/tienda_monedas/modelos/item_canje.dart` | Modelo de item de canje |
| `lib/domain/modelos/monedero.dart` | Modelo del monedero |

### Modelo de datos

```dart
Monedero {
  usuarioId: String
  saldo: int                   // Monedas disponibles
  historial: List<MovimientoMonedero>
}

MovimientoMonedero {
  fecha: DateTime
  tipo: TipoMovimiento         // ganado, canjeado, expirado
  cantidad: int
  concepto: String             // "Reserva completada", "Canje recompensa X"
  empresaId: String?
}

ItemCanje {
  id: String
  nombre: String
  descripcion: String
  monedasRequeridas: int
  empresaId: String
  stock: int?
  fechaExpiracion: DateTime?
}
```

### Cómo se ganan monedas

| Actividad | Monedas |
|-----------|---------|
| Primera reserva | 100 |
| Reserva completada | 50 |
| Valoración publicada | 75 |
| Referido registrado | 200 |
| Trofeo desbloqueado | Variable |

### Cloud Functions

| Función | Cuándo |
|---------|--------|
| `onCanjeRecompensa` | Callable — valida saldo y procesa canje |
| `evaluarTrofeosFidelidad` | Callable — calcula y desbloquea trofeos |
| `onCitaCompletadaTrofeos` | Trigger — evalúa trofeos tras cita completada |
| `onResenaCreadaTrofeos` | Trigger — evalúa trofeos tras reseña |
| `fanNumero1Job` | Scheduled — corona al cliente con más visitas en el mes |

---

## FLASH SLOTS

### Qué hace

Promociones de tiempo limitado: el negocio crea un "slot" (ej: "20% descuento en próximas 2 horas, solo 5 plazas") que aparece en la app pública y notifica a los clientes cercanos.

### Colecciones Firestore

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/flash_slots` | Slots activos |

### Cloud Functions

| Función | Cuándo |
|---------|--------|
| `onNuevoFlashSlot` | Trigger — notificación push a clientes potenciales |
| `expirarFlashSlots` | Scheduled — limpia slots vencidos o sin stock |

---

## VALORACIONES (Reviews)

### Qué hace

Sistema de reseñas de clientes sobre los negocios. Se pueden solicitar automáticamente tras una visita o reserva completada.

### Colecciones Firestore

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/valoraciones` | Valoraciones recibidas |

### Cloud Functions

| Función | Cuándo |
|---------|--------|
| `onNuevaValoracion` | Trigger — actualiza rating promedio del negocio en `negocios_publicos` |
| `onReservaCompletada` | Trigger — solicita valoración al cliente 2h después |
| `onValoracionBaja` | Trigger — alerta si la valoración es < 3 estrellas |

---

## Conexión entre módulos públicos

```
clienteFinal (usuario)
    │
    ├── explorar_negocios → ver catálogo público
    ├── perfil_cliente → mi cuenta, historial, monedero, trofeos
    ├── fidelizacion → sellos por visita (QR)
    ├── tienda_monedas → canjear recompensas con monedas
    ├── flash_slots → ver y comprar promociones
    └── valoraciones → dejar reseñas
```
