# Cloud Functions — Referencia Completa

## Configuración general

- **Runtime:** Node.js 20 (TypeScript)
- **Región:** `europe-west1` (Bélgica)
- **Punto de entrada:** `functions/src/index.ts`

---

## Índice por categoría

### Autenticación y seguridad
| Función | Tipo | Descripción |
|---------|------|-------------|
| `verificarLoginIntento` | Callable | Valida intentos de login, bloquea por fuerza bruta |
| `sendResetPasswordEmail` | Callable | Envía email de recuperación de contraseña |
| `gestionCuentas` | Callable | Gestión de cuentas de usuario (suspender, eliminar) |

### Empresa y registro
| Función | Tipo | Descripción |
|---------|------|-------------|
| `crearEmpresaHTTP` | HTTP | Crea una nueva empresa en Firestore |
| `inicializarEmpresa` | Callable | Setup inicial: módulos, servicios, empleado demo |
| `onInvitacionCreada` | Trigger Firestore | Envía email de invitación a empleado |
| `catalogoFunciones` | Callable | Devuelve catálogo de funciones disponibles según plan |

### TPV y facturación
| Función | Tipo | Descripción |
|---------|------|-------------|
| `generarFacturasResumenTpv` | Scheduled 23:30 | Genera factura resumen diaria del TPV |
| `cerrarCaja` | Callable | Proceso de cierre Z/X del TPV |

### Fiscal y VeriFactu
| Función | Tipo | Descripción |
|---------|------|-------------|
| `firmarXMLVerifactu` | Callable | Firma el XML de VeriFactu con certificado PKCS12 |
| `remitirVerifactu` | Callable | Envía la factura firmada a la AEAT |
| `alertaCertificado` | Scheduled | Alerta cuando el certificado digital va a vencer |
| `processInvoice` | Trigger Storage | OCR de factura recibida con Document AI + Claude |
| `calculateModel` | Callable | Calcula modelos fiscales (303, 111, 115, etc.) |
| `backupDatosFiscalesNocturno` | Scheduled noche | Backup de datos fiscales críticos |

### Pedidos y WhatsApp
| Función | Tipo | Descripción |
|---------|------|-------------|
| `onNuevoPedido` | Trigger Firestore | Notificación push al negocio |
| `onNuevoPedidoGenerarFactura` | Trigger Firestore | Auto-genera factura si el pedido está pagado |
| `whatsappWebhook` | HTTP | Recibe mensajes de WhatsApp Business API |
| `whatsappBot` | Internal | Procesa y responde mensajes del bot |

### Reservas
| Función | Tipo | Descripción |
|---------|------|-------------|
| `onNuevaReserva` | Trigger Firestore | Notificación al negocio + email al cliente |
| `onNuevaReservaEmail` | Trigger Firestore | Email de nueva reserva al negocio |
| `onReservaConfirmada` | Trigger Firestore | Notificación push al cliente |
| `onReservaCancelada` | Trigger Firestore | Email de cancelación |
| `confirmarReserva` | Callable | Cambia estado a confirmada |
| `rechazarReserva` | Callable | Cambia estado a cancelada |
| `recordatoriosCitas` | Scheduled noche | Recordatorios 24h antes a clientes |
| `reservasPublicas` | HTTP | Crear reserva desde web pública (sin auth) |
| `expirarReservasPublicas` | Scheduled | Limpia reservas expiradas |
| `notificacionesReservas` | Internal | Orquestador de notificaciones de reservas |

### Tareas
| Función | Tipo | Descripción |
|---------|------|-------------|
| `onTareaAsignada` | Trigger Firestore | Notificación push al empleado asignado |
| `scheduledGenerarTareasRecurrentes` | Scheduled diario | Genera nuevas instancias de tareas recurrentes |
| `scheduledRecordatoriosTareas` | Scheduled | Alertas de tareas próximas a vencer |
| `notificacionesTareas` | Internal | Orquestador de notificaciones de tareas |

### Vacaciones
| Función | Tipo | Descripción |
|---------|------|-------------|
| `onVacacionEstadoCambiado` | Trigger Firestore | Notifica al empleado la aprobación/rechazo |
| `scheduledCierreAnualVacaciones` | Scheduled 31/12 | Cierra el período anual |
| `scheduledExpiracionCarryover` | Scheduled 31/12 | Elimina días de carryover caducados |
| `importarFestivosEspana` | Callable | Carga festivos nacionales y autonómicos |

### Fidelización y trofeos
| Función | Tipo | Descripción |
|---------|------|-------------|
| `onCheckinFidelizacion` | Callable | Valida QR y añade sello al cliente |
| `onCanjeRecompensa` | Callable | Valida saldo y procesa canje de monedas |
| `marcarQRsExpirados` | Scheduled | Limpia QR vencidos |
| `verificarCaducidadSellos` | Scheduled | Caducar sellos expirados |
| `evaluarTrofeosFidelidad` | Callable | Evalúa y desbloquea trofeos |
| `onCitaCompletadaTrofeos` | Trigger Firestore | Evalúa trofeos tras cita completada |
| `onResenaCreadaTrofeos` | Trigger Firestore | Evalúa trofeos tras reseña |
| `fanNumero1Job` | Scheduled mensual | Corona al cliente top del mes |
| `fidelizacion` | Internal | Lógica de acumulación de puntos |
| `trofeos` | Internal | Definiciones y evaluación de trofeos |
| `valoraciones` | Internal | Gestión de valoraciones |
| `flashSlots` | Internal | Lógica de flash slots |
| `expirarFlashSlots` | Scheduled | Limpia flash slots expirados |

### Finiquitos
| Función | Tipo | Descripción |
|---------|------|-------------|
| `enviarDocumentacionFiniquito` | Callable | Envía PDF del finiquito por email |

### Notificaciones generales
| Función | Tipo | Descripción |
|---------|------|-------------|
| `notificaciones_cliente` | Internal | Notificaciones a clientes finales |
| `enviarEmailConPdf` | Callable | Envía cualquier PDF por email |

### Google My Business
| Función | Tipo | Descripción |
|---------|------|-------------|
| `gmbTokens` | HTTP | OAuth2 tokens para GMB |
| `gmbRespuestas` | Callable | Responde a reseñas desde GMB |
| `gmbSnapshots` | Scheduled | Toma snapshots de métricas GMB |

### Web pública y analytics
| Función | Tipo | Descripción |
|---------|------|-------------|
| `registrarVisita` | Callable | Tracking de visitas a la web pública |

### Email (resend_service)
| Función | Tipo | Descripción |
|---------|------|-------------|
| Interna: `resend_service.ts` | Internal | Servicio de envío de emails con Resend |
| Interna: `email_service.ts` | Internal | Templates de email |

### Suscripciones
| Función | Tipo | Descripción |
|---------|------|-------------|
| `stripeWebhook` | HTTP | Recibe eventos de Stripe (pagos, cancelaciones) |
| `verificarSuscripciones` | Scheduled | Comprueba vencimientos de planes |
| `resetPassword` | Callable | Reset de contraseña vía función |
| `invitaciones` | Internal | Gestión de invitaciones de empleados |
| `tareasFunciones` | Internal | Lógica de tareas |

---

## Servicios compartidos en Functions

| Archivo | Propósito |
|---------|-----------|
| `utils/authGuard.ts` | Middleware para validar autenticación en callables |
| `resend_service.ts` | Cliente de Resend para envío de emails |
| `email_service.ts` | Templates HTML de emails |
| `fiscal/ocrPreprocessor.ts` | Preprocesado de imagen para OCR |
| `fiscal/prompts/invoiceExtractionV4.ts` | Prompt de Claude para extraer datos de facturas |
| `auth/fuerzaBruta.ts` | Lógica anti-fuerza bruta |

---

## Reglas de seguridad en Functions

Todas las Cloud Functions Callable pasan por `authGuard.ts` que:
1. Verifica que el usuario está autenticado (`context.auth`)
2. Verifica que el usuario pertenece a la empresa que solicita la operación
3. Verifica el rol mínimo requerido para la operación
4. Las HTTP Functions (webhooks) usan firma HMAC para verificar el origen (Stripe, WhatsApp)
