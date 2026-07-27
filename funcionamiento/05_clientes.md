# Módulo: Clientes

## Qué hace

Base de datos completa de clientes con búsqueda, filtros, segmentación, importación masiva por CSV, detección y fusión de duplicados, y análisis de clientes inactivos ("silenciosos").

---

## Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/clientes/pantallas/clientes_silenciosos_screen.dart` | Clientes sin actividad reciente |
| `features/clientes/pantallas/duplicados_cliente_screen.dart` | Detectar y fusionar duplicados |
| `features/clientes/pantallas/tab_tareas_cliente.dart` | Tareas vinculadas a un cliente |
| `services/importacion_clientes_service.dart` | Importación masiva desde CSV |
| `domain/modelos/cliente_importado_model.dart` | Modelo para importación |

---

## Modelo de datos: Cliente

```dart
Cliente {
  id: String
  nombre: String
  telefono: String?
  correo: String?
  nif: String?
  
  // Dirección
  direccion: String?
  codigoPostal: String?
  ciudad: String?
  
  // Estado
  estado: EstadoCliente     // contacto, activo, inactivo
  noContactar: bool
  fichaIncompleta: bool
  
  // Métricas
  totalGastado: double
  numeroReservas: int
  ultimaVisita: DateTime?
  fechaAlta: DateTime
  
  // Notas
  notas: String?
  etiquetas: List<String>
}

enum EstadoCliente { contacto, activo, inactivo }
```

---

## Cómo funciona internamente

### Búsqueda y filtros
- Búsqueda en tiempo real por nombre, teléfono y email
- Filtros por estado, etiqueta, y período de inactividad
- La lista usa `StreamBuilder` sobre la colección Firestore con índices compuestos

### Clientes silenciosos
- `clientes_silenciosos_screen.dart` filtra clientes con `ultimaVisita` anterior a N días (configurable)
- Se puede enviar un email/WhatsApp de reactivación desde esta pantalla
- Útil para campañas de recuperación

### Duplicados
- `duplicados_cliente_screen.dart` detecta duplicados comparando teléfono y email
- Muestra pares/grupos de posibles duplicados
- Al fusionar, combina el historial de ambos y elimina el secundario

### Importación CSV
- `importacion_clientes_service.dart` parsea el CSV
- Mapea columnas (nombre, teléfono, email, NIF) con validación
- Detecta duplicados antes de importar y ofrece skip/merge

### Historial de actividad
- Cada vez que un cliente hace una reserva, pedido o compra, se registra en `clientes/{id}/actividad`
- Actualiza `ultimaVisita` y `totalGastado` en el documento principal
- Los triggers de Cloud Functions hacen esta actualización automáticamente

---

## Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/clientes` | Documento principal del cliente |
| `empresas/{empresaId}/clientes/{clienteId}/actividad` | Historial de interacciones |
| `empresas/{empresaId}/clientes/{clienteId}/valoraciones` | Reviews dados por el cliente |

---

## Cloud Functions relacionadas

Las Cloud Functions de otros módulos actualizan automáticamente los datos del cliente:
- Trigger en `reservas` → incrementa `numeroReservas`, actualiza `ultimaVisita`
- Trigger en `pedidos` → incrementa `totalGastado`, actualiza `ultimaVisita`
- Trigger en `valoraciones` → registra la valoración en el historial del cliente

---

## Conexión con otros módulos

- **Reservas** — al crear reserva se busca o crea el cliente
- **Pedidos** — los pedidos tienen referencia al clienteId
- **Facturación** — datos fiscales del cliente (NIF, dirección) se copian a la factura
- **Tareas** — se pueden crear tareas vinculadas a un cliente concreto
- **WhatsApp** — se puede iniciar conversación desde la ficha del cliente
