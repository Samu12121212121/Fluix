# Firestore — Estructura de Base de Datos

## Esquema completo de colecciones

```
/usuarios/{uid}
  ├── nombre: String
  ├── email: String
  ├── rol: String                    // propietario | admin | staff | clienteFinal | plataforma_admin
  ├── empresa_id: String?
  ├── modulos_permitidos: List       // Solo para rol=staff
  ├── es_plataforma_admin: bool
  ├── fotoUrl: String?
  ├── fcmTokens: List<String>        // Tokens FCM para notificaciones push
  │
  ├── /auditoria/{logId}
  │     ├── accion: String
  │     ├── timestamp: Timestamp
  │     ├── ip: String?
  │     └── dispositivo: String?
  │
  ├── /renovaciones/{alertId}
  │     ├── tipo: String
  │     ├── fechaVencimiento: Timestamp
  │     └── enviado: bool
  │
  ├── /trofeos/{trofeoId}
  │     ├── nombre: String
  │     ├── fechaDesbloqueo: Timestamp
  │     └── empresaId: String?
  │
  └── /monedero/{movId}
        ├── tipo: String             // ganado | canjeado | expirado
        ├── cantidad: int
        ├── concepto: String
        └── fecha: Timestamp


/empresas/{empresaId}
  ├── nombre: String
  ├── correo: String
  ├── telefono: String?
  ├── nif: String?
  ├── direccion: String?
  ├── logo: String?
  ├── onboarding_completado: bool
  ├── sector: String?               // hosteleria | peluqueria | tienda | servicios
  ├── web: String?
  │
  ├── /configuracion
  │   ├── /modulos
  │   │     └── {moduloId}: { activo: bool, orden: int }
  │   ├── /facturacion
  │   │     ├── contador_fac: int
  │   │     ├── contador_rect: int
  │   │     ├── contador_pro: int
  │   │     ├── contador_tpv: int
  │   │     └── verifactu_activo: bool
  │   ├── /fiscal
  │   │     ├── regimen: String      // general | simplificado | estimacion_directa
  │   │     ├── periodicidad_iva: String  // trimestral | mensual
  │   │     ├── comunidad_autonoma: String
  │   │     ├── smi_anual: double
  │   │     └── obligaciones: List
  │   ├── /vacaciones
  │   │     ├── dias_anuales: int
  │   │     ├── carryover_max: int
  │   │     └── periodo_reset: String
  │   └── /reservas
  │         ├── horario_apertura: String
  │         ├── horario_cierre: String
  │         ├── duracion_slot_min: int
  │         └── antelacion_min_horas: int
  │
  ├── /suscripcion/actual
  │     ├── estado: 'ACTIVA' | 'VENCIDA' | 'SUSPENDIDA'
  │     ├── plan: String
  │     ├── packs_activos: List<String>
  │     ├── addons_activos: List<String>
  │     ├── fechaInicio: Timestamp
  │     ├── fechaFin: Timestamp
  │     ├── es_demo: bool
  │     ├── stripeCustomerId: String?
  │     └── stripeSubscriptionId: String?
  │
  ├── /estadisticas
  │   ├── /resumen
  │   │     ├── ventasHoy: double
  │   │     ├── reservasHoy: int
  │   │     ├── ratingPromedio: double
  │   │     └── tareasVencidas: int
  │   ├── /web_resumen
  │   │     └── visitasHoy: int, ...
  │   └── /historico_diario/{fecha}
  │         └── ventas: double, reservas: int, ...
  │
  ├── /facturas/{facturaId}
  │     ├── numeroFactura: String    // FAC-2026-0001
  │     ├── serie: String
  │     ├── estado: String          // pendiente | pagada | anulada | vencida | rectificada
  │     ├── clienteNombre: String
  │     ├── clienteNif: String?
  │     ├── lineas: Array
  │     ├── subtotal: double
  │     ├── totalIva: double
  │     ├── total: double
  │     ├── fechaEmision: Timestamp
  │     ├── fechaVencimiento: Timestamp?
  │     ├── metodoPago: String
  │     ├── verifactuRegistrado: bool
  │     └── verifactuHash: String?
  │
  ├── /facturas_recibidas/{id}
  │     ├── proveedor: String
  │     ├── numeroFactura: String
  │     ├── fecha: Timestamp
  │     ├── lineas: Array
  │     ├── total: double
  │     ├── estadoPago: String
  │     └── pdfUrl: String?
  │
  ├── /modelo_111/{id}, /modelo_115/{id}, /modelo_303/{id}, etc.
  │     └── (datos de la declaración presentada)
  │
  ├── /clientes/{clienteId}
  │     ├── nombre: String
  │     ├── telefono: String?
  │     ├── correo: String?
  │     ├── nif: String?
  │     ├── estado: String          // contacto | activo | inactivo
  │     ├── totalGastado: double
  │     ├── numeroReservas: int
  │     ├── ultimaVisita: Timestamp?
  │     ├── etiquetas: List<String>
  │     ├── noContactar: bool
  │     │
  │     ├── /actividad/{actId}
  │     │     ├── tipo: String       // reserva | pedido | valoracion
  │     │     ├── fecha: Timestamp
  │     │     └── importe: double?
  │     │
  │     └── /valoraciones/{valId}
  │           └── (copia de la valoración del cliente)
  │
  ├── /empleados/{empleadoId}
  │     ├── nombre: String
  │     ├── nif: String
  │     ├── email: String?
  │     ├── puesto: String
  │     ├── tipoContrato: String
  │     ├── salarioBase: double
  │     ├── fechaAlta: Timestamp
  │     ├── activo: bool
  │     ├── usuarioId: String?
  │     │
  │     ├── /documentos/{docId}
  │     │     ├── tipo: String
  │     │     ├── url: String
  │     │     └── fechaSubida: Timestamp
  │     │
  │     └── /renovaciones/{alertId}
  │           └── (alertas de vencimiento de contrato)
  │
  ├── /nominas/{nominaId}
  │     ├── empleadoId: String
  │     ├── mes: int
  │     ├── año: int
  │     ├── estado: String          // borrador | aprobada | pagada
  │     ├── salarioBase: double
  │     ├── cotizacionSs: double
  │     ├── retencionIrpf: double
  │     ├── liquidoPerc: double
  │     └── firmaEmpleado: String?
  │
  ├── /vacaciones/{vacId}
  │     ├── empleadoId: String
  │     ├── fechaInicio: Timestamp
  │     ├── fechaFin: Timestamp
  │     ├── diasUsados: int
  │     └── estado: String
  │
  ├── /finiquitos/{finiquitoId}
  │     ├── empleadoId: String
  │     ├── fechaCese: Timestamp
  │     ├── motivoCese: String
  │     ├── totalFiniquito: double
  │     └── estado: String
  │
  ├── /tareas/{tareaId}
  │     ├── titulo: String
  │     ├── estado: String
  │     ├── prioridad: String
  │     ├── asignadoId: String?
  │     ├── fechaVencimiento: Timestamp?
  │     ├── esRecurrente: bool
  │     ├── subtareas: Array
  │     │
  │     ├── /adjuntos/{adjId}
  │     │     └── url: String, nombre: String, ...
  │     │
  │     └── /tiempo/{entradaId}
  │           ├── usuarioId: String
  │           ├── inicio: Timestamp
  │           ├── fin: Timestamp?
  │           └── duracionMin: int
  │
  ├── /equipos/{equipoId}
  │     ├── nombre: String
  │     ├── responsableId: String
  │     └── miembrosIds: List<String>
  │
  ├── /pedidos/{pedidoId}
  │     ├── clienteId: String?
  │     ├── clienteNombre: String
  │     ├── fecha: Timestamp
  │     ├── origen: String          // web | app | whatsapp | presencial
  │     ├── lineas: Array
  │     ├── total: double
  │     ├── estado: String
  │     ├── estadoPago: String
  │     └── facturaId: String?
  │
  ├── /catalogo/{productoId}
  │     ├── nombre: String
  │     ├── precio: double
  │     ├── costo: double?
  │     ├── categoriaId: String?
  │     ├── stock: int?
  │     ├── imagenUrl: String?
  │     ├── activo: bool
  │     └── variantes: Array
  │
  ├── /servicios/{servicioId}
  │     ├── nombre: String
  │     ├── duracionMin: int
  │     ├── precio: double
  │     └── empleadoIds: List<String>
  │
  ├── /reservas/{reservaId}
  │     ├── clienteNombre: String
  │     ├── fechaHora: Timestamp
  │     ├── estado: String
  │     ├── origen: String
  │     ├── servicioId: String?
  │     ├── profesionalId: String?
  │     └── mesaId: String?
  │
  ├── /mesas/{mesaId}
  │     ├── numero: int
  │     ├── zona: String
  │     ├── capacidad: int
  │     └── estado: String          // libre | ocupada | reservada
  │
  ├── /cierres_caja/{cierreId}
  │     ├── fecha: Timestamp
  │     ├── efectivoInicial: double
  │     ├── efectivoFinal: double
  │     ├── ventasEfectivo: double
  │     ├── ventasTarjeta: double
  │     └── diferencia: double
  │
  ├── /fichajes/{fichajeId}
  │     ├── empleadoId: String
  │     ├── fecha: Timestamp
  │     ├── horaEntrada: Timestamp?
  │     ├── horaSalida: Timestamp?
  │     ├── ubicacionEntrada: GeoPoint?
  │     └── horasTrabajadas: double?
  │
  ├── /flash_slots/{slotId}
  │     ├── titulo: String
  │     ├── descuentoPct: double
  │     ├── fechaFin: Timestamp
  │     └── stock: int
  │
  ├── /fidelizacion/config
  │     └── (configuración del programa de sellos)
  │
  ├── /recompensas/{recompensaId}
  │     ├── nombre: String
  │     ├── monedasRequeridas: int
  │     └── stock: int?
  │
  ├── /valoraciones/{valId}
  │     ├── clienteId: String
  │     ├── puntuacion: int
  │     ├── comentario: String?
  │     └── fecha: Timestamp
  │
  ├── /pdf_templates/{templateId}
  │     ├── nombre: String
  │     ├── html: String
  │     └── variables: List<String>
  │
  ├── /contenido_web/{paginaId}
  │     ├── titulo: String
  │     ├── slug: String
  │     ├── contenido: String
  │     └── seo: Map
  │
  └── /trofeos/{trofeoId}
        ├── nombre: String
        ├── descripcion: String
        ├── icono: String
        └── condicion: Map


/negocios_publicos/{empresaId}           ← Lectura pública
  ├── nombre: String
  ├── categoria: String
  ├── descripcion: String
  ├── logoUrl: String?
  ├── fotos: List<String>
  ├── ubicacion: GeoPoint?
  ├── rating: double
  ├── totalValoraciones: int
  └── horarios: Map


/convocatorios/{convenioId}              ← Colección global de convenios colectivos
  └── (datos del convenio colectivo español)
```

---

## Índices Firestore necesarios

Los índices compuestos más importantes para el rendimiento:

```
facturas: [empresaId, fechaEmision DESC]
facturas: [empresaId, estado, fechaEmision DESC]
pedidos: [empresaId, estado, fecha DESC]
pedidos: [empresaId, origen, fecha DESC]
reservas: [empresaId, fechaHora ASC, estado]
tareas: [empresaId, asignadoId, estado]
tareas: [empresaId, fechaVencimiento ASC, estado]
fichajes: [empresaId, empleadoId, fecha DESC]
nominas: [empresaId, empleadoId, año DESC, mes DESC]
```

---

## Reglas de seguridad (resumen)

```javascript
// Funciones de validación principales:
function esUsuarioReal()          // Auth + no anónimo
function esPropietario(eId)       // rol == 'propietario'
function esAdminOPropietario(eId) // rol in ['admin', 'propietario']
function esStaffOSuperior(eId)    // rol in ['staff', 'admin', 'propietario']
function tienePackActivo(eId, pack)  // pack in packs_activos OR es_demo
function esPlataformaAdmin()      // campo especial en custom claims

// Colecciones públicas (sin auth):
/negocios_publicos    → allow read: true
/trafico_web          → allow write: true (tracking)
```
