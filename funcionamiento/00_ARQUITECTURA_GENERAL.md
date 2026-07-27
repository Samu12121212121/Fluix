# Fluix CRM — Arquitectura General

## Qué es

Fluix CRM es una aplicación Flutter multiplataforma (iOS, Android, Web, Windows, Linux, macOS) orientada a pymes españolas. Centraliza en una sola app: facturación, nóminas, reservas, TPV, clientes, tareas y cumplimiento fiscal (VeriFactu, modelos AEAT).

**Versión:** 1.0.15  
**Nombre técnico:** planeag_flutter

---

## Stack Tecnológico

### Frontend
- **Flutter 3.11.1** — UI multiplataforma
- **Provider** — gestión de estado
- **Go Router** — navegación declarativa
- **Shared Preferences** — persistencia local de configuración
- **SQLite** — base de datos local para modo offline

### Backend
- **Firebase Auth** — autenticación y sesiones
- **Cloud Firestore** — base de datos NoSQL en tiempo real
- **Cloud Functions** (TypeScript, región `europe-west1`) — lógica de servidor
- **Firebase Storage** — documentos, imágenes, PDFs
- **Firebase Messaging (FCM)** — notificaciones push
- **Firebase Analytics + Crashlytics** — métricas y errores

### Terceros integrados
| Servicio | Uso |
|----------|-----|
| Stripe | Pagos de suscripción |
| Google Business Profile (GMB) | Reviews y presencia online |
| WhatsApp Business API | Chatbot y notificaciones |
| Document AI + Claude API | OCR de facturas recibidas |
| Certificados PKCS12/XAdES | Firma digital VeriFactu |
| AEAT VeriFactu | Facturación electrónica obligatoria |
| SEPA XML | Transferencias bancarias de nóminas |

---

## Arquitectura de Capas

```
lib/
├── main.dart                   ← Punto de entrada
├── core/
│   ├── di/service_locator.dart ← Inyección de dependencias (get_it)
│   ├── tema/                   ← Tema Material
│   ├── errores/                ← Excepciones personalizadas
│   └── utils/                  ← Logger, utilidades
├── domain/
│   ├── modelos/                ← 50+ modelos de negocio
│   ├── repositorios/           ← Interfaces (contratos)
│   └── casos_uso/              ← Lógica de negocio pura
├── data/
│   ├── datasources/            ← Firebase, APIs externas
│   └── repositorios/           ← Implementaciones concretas
├── features/                   ← 26+ módulos funcionales
│   └── {modulo}/
│       ├── pantallas/          ← Widgets de pantalla
│       ├── widgets/            ← Widgets reutilizables
│       └── providers/          ← ChangeNotifiers
└── services/                   ← Servicios de negocio compartidos
```

---

## Autenticación y Roles

### Métodos de login
- Email/Password
- Biometría (FaceID/huella dactilar)
- Google Sign-In
- Apple Sign-In
- 2FA con OTP
- Control anti-fuerza bruta (bloqueo automático)

### Roles de usuario
| Rol | Descripción |
|-----|-------------|
| `propietario` | Acceso total, gestión de empresa |
| `admin` | Administrador con permisos amplios |
| `staff` | Personal con módulos limitados |
| `clienteFinal` | Usuario de la app pública (explorar negocios) |
| `plataforma_admin` | Administrador de la plataforma Fluix |

---

## Multi-tenancy

Toda la información de cada empresa está bajo `/empresas/{empresaId}/`. Un usuario puede pertenecer a una empresa y tener un rol asignado. La seguridad se valida en Firestore Rules combinando `uid`, `empresaId` y `rol`.

---

## Persistencia Offline

- **Web:** sin caché Firestore local
- **Desktop:** caché de 100 MB
- **Mobile:** caché ilimitada

Los datos se sincronizan automáticamente cuando el dispositivo recupera conexión.

---

## Deep Links

`fluixcrm://invite?token=...` — usado para invitar a empleados a unirse a una empresa vía enlace.

---

## Módulos principales

| # | Módulo | Carpeta |
|---|--------|---------|
| 01 | Autenticación | `features/autenticacion/` |
| 02 | Dashboard | `features/dashboard/` |
| 03 | Registro | `features/registro/` |
| 04 | Facturación | `features/facturacion/` |
| 05 | Fiscal + VeriFactu | `features/fiscal/` + `services/verifactu/` |
| 06 | Clientes | `features/clientes/` |
| 07 | Empleados | `features/empleados/` |
| 08 | Nóminas | `features/nominas/` |
| 09 | Vacaciones | `features/vacaciones/` |
| 10 | Finiquitos | `features/finiquitos/` |
| 11 | Tareas | `features/tareas/` |
| 12 | Pedidos | `features/pedidos/` |
| 13 | TPV | `features/tpv/` |
| 14 | Fichajes | `features/fichaje/` |
| 15 | Reservas | `features/reservas/` |
| 16 | Perfil | `features/perfil/` |
| 17 | Suscripción | `features/suscripcion/` |
| 18 | Onboarding | `features/onboarding/` |
| 19 | Explorar negocios | `features/explorar_negocios/` |
| 20 | Perfil cliente | `features/perfil_cliente/` |
| 21 | Tienda monedas | `features/tienda_monedas/` |
| 22 | Fidelización | `features/fidelizacion/` |
| 23 | Servicios | `features/servicios/` |
| 24 | PDF Templates | `features/pdf_templates/` |
| 25 | Flash Slots | `features/flash_slots/` |
| 26 | Valoraciones | `features/valoraciones/` |

---

## Puntos técnicos destacados

1. **VeriFactu completo** — RD 1007/2023 con firma XAdES, hash chain y envío a AEAT
2. **Nóminas españolas** — SS 2026, IRPF autonómico, convenios colectivos, embargos
3. **Facturación electrónica** — SEPA XML, modelos AEAT 111/115/130/190/202/303/347/349/390
4. **OCR de facturas** — Document AI + Claude API para extraer datos automáticamente
5. **WhatsApp Business** — bot para recibir pedidos y enviar confirmaciones
6. **Google Business** — sincronización de reviews y respuestas desde la app
