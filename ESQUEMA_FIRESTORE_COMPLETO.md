# 🗄️ Esquema completo de Firestore — PlaneaGuada CRM

> Documento generado el 10/03/2026. Refleja **todos** los campos que la app
> lee y escribe actualmente. Úsalo como referencia para revisar tu consola
> de Firebase o para inicializar datos manualmente.

---

## 📐 Estructura raíz

```
usuarios/{uid}
empresas/{empresaId}/
  ├── (documento raíz — perfil de empresa)
  ├── clientes/{clienteId}
  ├── empleados/{empleadoId}
  ├── servicios/{servicioId}
  ├── reservas/{reservaId}
  ├── valoraciones/{valoracionId}
  ├── pedidos/{pedidoId}
  ├── pedidos_whatsapp/{pedidoId}
  ├── facturas/{facturaId}
  ├── transacciones/{transaccionId}
  ├── tareas/{tareaId}
  ├── equipos/{equipoId}
  ├── secciones_web/{seccionId}
  ├── dispositivos/{uid}
  ├── suscripcion/actual
  ├── estadisticas/resumen
  ├── cache/estadisticas
  └── configuracion/modulos
```

---

## 👤 `/usuarios/{uid}`

```json
{
  "nombre":            "string",
  "correo":            "string",
  "telefono":          "string | null",
  "rol":               "propietario | admin | staff",
  "empresa_id":        "string (ID de empresa)",
  "activo":            true,
  "permisos":          ["string"],
  "fecha_creacion":    "ISO string",
  "token_dispositivo": "string | null  ← FCM token para notificaciones",
  "token_actualizado": "Timestamp | null",
  "plataforma":        "android | ios | unknown"
}
```

---

## 🏢 `/empresas/{empresaId}` (documento raíz)

```json
{
  "nombre":            "string",
  "correo":            "string",
  "telefono":          "string",
  "direccion":         "string",
  "descripcion":       "string",
  "sitio_web":         "string | null",
  "categoria":         "string | null",
  "fecha_creacion":    "Timestamp"
}
```

---

## 👥 `/empresas/{empresaId}/clientes/{clienteId}`

```json
{
  "nombre":          "string",
  "telefono":        "string",
  "correo":          "string | null",
  "total_gastado":   0.0,
  "ultima_visita":   "Timestamp | null",
  "numero_reservas": 0,
  "etiquetas":       ["string"],
  "notas":           "string | null",
  "fecha_registro":  "Timestamp   ← usado por estadísticas para nuevos_clientes_mes"
}
```

---

## 👨‍💼 `/empresas/{empresaId}/empleados/{empleadoId}`

```json
{
  "nombre":   "string",
  "rol":      "propietario | admin | staff",
  "permisos": ["string"],
  "activo":   true,
  "uid":      "string | null  ← UID de Firebase Auth si tiene cuenta"
}
```

---

## 💇 `/empresas/{empresaId}/servicios/{servicioId}`

```json
{
  "nombre":             "string",
  "precio":             0.0,
  "duracion":           60,
  "empleado_asignado":  "string | null",
  "activo":             true,
  "categoria":          "string"
}
```

---

## 📅 `/empresas/{empresaId}/reservas/{reservaId}`

```json
{
  "cliente":      "string (nombre)",
  "servicio":     "string (nombre)",
  "estado":       "PENDIENTE | CONFIRMADA | CANCELADA | COMPLETADA",
  "fecha":        "Timestamp",
  "hora_inicio":  "string (HH:mm)  ← usado para horas_pico en estadísticas",
  "notas":        "string | null"
}
```

---

## ⭐ `/empresas/{empresaId}/valoraciones/{valoracionId}`

```json
{
  "cliente":      "string",
  "calificacion": 5,
  "comentario":   "string",
  "fecha":        "Timestamp",
  "origen":       "google | app | manual"
}
```

> ⚠️ Algunas reseñas antiguas usan `estrellas` en vez de `calificacion`.
> La app acepta ambos campos.

---

## 🛒 `/empresas/{empresaId}/pedidos/{pedidoId}`

```json
{
  "cliente":       "string (nombre)",
  "telefono":      "string",
  "productos":     [
    {
      "producto_id":  "string",
      "nombre":       "string",
      "precio":       0.0,
      "cantidad":     1,
      "variante":     "string | null"
    }
  ],
  "precio_total":  0.0,
  "estado":        "pendiente | confirmado | en_preparacion | listo | entregado | cancelado",
  "estado_pago":   "pendiente | pagado | reembolsado",
  "metodo_pago":   "tarjeta | paypal | bizum | efectivo",
  "origen":        "web | app | whatsapp | presencial",
  "notas_internas":"string | null",
  "historial":     [{"campo": "string", "antes": "any", "despues": "any", "fecha": "Timestamp", "usuario": "string"}],
  "fecha_creacion":"Timestamp"
}
```

---

## 💬 `/empresas/{empresaId}/pedidos_whatsapp/{pedidoId}`

```json
{
  "nombre_cliente": "string",
  "telefono":       "string",
  "descripcion":    "string",
  "total":          0.0,
  "estado":         "nuevo | confirmado | en_proceso | entregado | cancelado",
  "fecha":          "Timestamp"
}
```

---

## 🛍️ `/empresas/{empresaId}/productos/{productoId}`

```json
{
  "empresa_id":   "string",
  "nombre":       "string",
  "descripcion":  "string | null",
  "categoria":    "string",
  "precio":       0.0,
  "imagen_url":   "string | null",
  "stock":        0,
  "activo":       true,
  "destacado":    false,
  "variantes": [
    {
      "id":                "string",
      "nombre":            "string",
      "tipo":              "tamaño | sabor | color | ...",
      "precio_diferencia": 0.0,
      "stock_extra":       0
    }
  ],
  "etiquetas":           ["string"],
  "fecha_creacion":      "Timestamp",
  "fecha_actualizacion": "Timestamp | null"
}
```

---

## 🧾 `/empresas/{empresaId}/facturas/{facturaId}`

```json
{
  "numero_factura":  "FAC-2026-0001",
  "tipo":            "pedido | venta_directa | servicio",
  "estado":          "pendiente | pagada | anulada | vencida",
  "cliente_nombre":  "string",
  "cliente_email":   "string | null",
  "datos_fiscales": {
    "nif":           "string | null",
    "razon_social":  "string | null",
    "direccion":     "string | null",
    "codigo_postal": "string | null",
    "ciudad":        "string | null",
    "pais":          "España"
  },
  "lineas": [
    {
      "descripcion":      "string",
      "precio_unitario":  0.0,
      "cantidad":         1,
      "tipo_iva":         0 | 4 | 10 | 21,
      "subtotal":         0.0,
      "iva_amount":       0.0,
      "total":            0.0
    }
  ],
  "subtotal":          0.0,
  "total_iva":         0.0,
  "total":             0.0,
  "metodo_pago":       "tarjeta | paypal | bizum | efectivo | null",
  "pedido_id":         "string | null",
  "notas":             "string | null",
  "historial_cambios": [{"accion": "string", "fecha": "Timestamp", "usuario_id": "string"}],
  "fecha_emision":     "Timestamp",
  "fecha_vencimiento": "Timestamp | null",
  "fecha_pago":        "Timestamp | null"
}
```

---

## 💰 `/empresas/{empresaId}/transacciones/{transaccionId}`

```json
{
  "cliente":      "string",
  "monto":        0.0,
  "metodo_pago":  "string",
  "fecha":        "Timestamp"
}
```

> Las transacciones las usa el módulo de **estadísticas financieras**
> para calcular `ingresos_mes` y `ticket_medio`.

---

## ✅ `/empresas/{empresaId}/tareas/{tareaId}`

```json
{
  "empresa_id":   "string",
  "titulo":       "string",
  "descripcion":  "string | null",
  "tipo":         "normal | checklist | incidencia | proyecto",
  "prioridad":    "urgente | alta | media | baja",
  "estado":       "pendiente | en_progreso | en_revision | completada | cancelada",
  "asignado_a":   "string (uid)",
  "equipo_id":    "string | null",
  "fecha_limite": "Timestamp | null",
  "subtareas":    [{"id": "string", "titulo": "string", "completada": false}],
  "etiquetas":    ["string"],
  "adjuntos":     ["string (url)"],
  "historial_tiempo": [{"usuario_id": "string", "inicio": "Timestamp", "fin": "Timestamp | null"}],
  "fecha_creacion":    "Timestamp",
  "fecha_actualizacion": "Timestamp | null"
}
```

---

## 👥 `/empresas/{empresaId}/equipos/{equipoId}`

```json
{
  "empresa_id":     "string",
  "nombre":         "string",
  "descripcion":    "string | null",
  "responsable_id": "string (uid)",
  "miembros_ids":   ["string (uid)"],
  "fecha_creacion": "Timestamp"
}
```

---

## 🌐 `/empresas/{empresaId}/secciones_web/{seccionId}`

```json
{
  "titulo":          "string",
  "contenido":       "string (texto o HTML)",
  "imagen_url":      "string | null",
  "tipo":            "texto | imagen | galeria | oferta | carta | horarios | contacto",
  "activo":          true,
  "orden":           0,
  "empresa_id":      "string",
  "fecha_creacion":  "Timestamp",
  "ultima_edicion":  "Timestamp"
}
```

---

## 📱 `/empresas/{empresaId}/dispositivos/{uid}`

```json
{
  "token":               "string (FCM token)",
  "uid_usuario":         "string",
  "plataforma":          "android | ios | web",
  "activo":              true,
  "ultima_actualizacion":"Timestamp"
}
```

> Esta colección la usa el servicio de **notificaciones push** para saber
> a qué dispositivos enviar.

---

## 💳 `/empresas/{empresaId}/suscripcion/actual`

```json
{
  "estado":        "ACTIVA | VENCIDA | PENDIENTE",
  "plan":          "basico | gestion | tienda",
  "fecha_inicio":  "Timestamp",
  "fecha_fin":     "Timestamp",
  "aviso_enviado": false,
  "ultimo_aviso":  "Timestamp | null"
}
```

> Las Cloud Functions verifican este documento cada 24h y envían
> notificación push si faltan 7, 3 o 1 días para el vencimiento.

---

## 📊 `/empresas/{empresaId}/estadisticas/resumen`

Calculado por `EstadisticasService`. Campos principales:

```json
{
  "reservas_mes":              0,
  "reservas_mes_anterior":     0,
  "reservas_confirmadas":      0,
  "reservas_canceladas":       0,
  "reservas_completadas":      0,
  "reservas_pendientes":       0,
  "tasa_conversion":           0.0,
  "tasa_cancelacion":          0.0,
  "distribucion_dias":         {"lunes": 0, "martes": 0, ...},
  "horas_pico":                ["10:00", "17:00"],
  "dia_mas_activo":            "viernes",
  "ingresos_mes":              0.0,
  "ingresos_mes_anterior":     0.0,
  "valor_medio_reserva":       0.0,
  "metodo_pago_preferido":     "Efectivo",
  "total_clientes":            0,
  "nuevos_clientes_mes":       0,
  "clientes_activos":          0,
  "clientes_frecuentes":       0,
  "valor_promedio_cliente":    0.0,
  "cliente_mas_valioso":       "string",
  "total_servicios_activos":   0,
  "servicio_mas_popular":      "string",
  "total_empleados_activos":   0,
  "empleado_mas_activo":       "string",
  "valoracion_promedio":       0.0,
  "total_valoraciones":        0,
  "ultima_actualizacion":      "Timestamp",
  "fecha_calculo":             "ISO string"
}
```

---

## ⚡ `/empresas/{empresaId}/cache/estadisticas`

Mismos campos que `estadisticas/resumen` pero con:

```json
{
  "version_cache":         1,
  "ultima_actualizacion":  "Timestamp",
  "fecha_calculo":         "ISO string"
}
```

> Se actualiza automáticamente cada 5 minutos en background.
> La pantalla de estadísticas **solo lee de aquí**, nunca de `estadisticas/resumen` directamente.

---

## ⚙️ `/empresas/{empresaId}/configuracion/modulos`

```json
{
  "modulos": [
    {"id": "dashboard",    "activo": true},
    {"id": "valoraciones", "activo": true},
    {"id": "estadisticas", "activo": true},
    {"id": "reservas",     "activo": true},
    {"id": "web",          "activo": true},
    {"id": "whatsapp",     "activo": true},
    {"id": "facturacion",  "activo": true},
    {"id": "pedidos",      "activo": true},
    {"id": "tareas",       "activo": true}
  ],
  "ultima_actualizacion": "Timestamp"
}
```

---

## ⚠️ Campos que DEBES revisar en tu Firestore

Si has entrado datos manualmente en la consola, verifica que:

| Colección | Campo crítico | Valor esperado |
|---|---|---|
| `valoraciones` | `calificacion` | número 1-5 (no `estrellas`) |
| `reservas` | `fecha` | Timestamp (no string) |
| `clientes` | `fecha_registro` | Timestamp (para estadísticas) |
| `transacciones` | `monto` | número (para ingresos) |
| `facturas` | `fecha_emision` | Timestamp |
| `dispositivos` | `activo` | `true` (booleano) |
| `suscripcion/actual` | `estado` | `"ACTIVA"` en mayúsculas |
| `configuracion/modulos` | `modulos` | array de objetos `{id, activo}` |

---

## 🚀 Inicializar datos mínimos para una empresa nueva

Al registrar una empresa nueva, la app espera encontrar (o crea automáticamente):

1. **`usuarios/{uid}`** — creado por `AdminInitializer` o registro
2. **`empresas/{empresaId}/configuracion/modulos`** — creado por `WidgetManagerService._inicializarModulosDefault()`
3. **`empresas/{empresaId}/cache/estadisticas`** — creado por `EstadisticasCacheService` al primer cálculo
4. **`empresas/{empresaId}/dispositivos/{uid}`** — creado por `NotificacionesService` al iniciar sesión

