# 🏢 Fluix CRM

**CRM/ERP multiempresa para PYMES españolas** desarrollado con Flutter + Firebase.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-orange?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-Proprietary-red)]()

---

## 📋 Descripción

Fluix CRM es una aplicación de gestión empresarial completa diseñada específicamente para **pequeñas y medianas empresas españolas** en Castilla-La Mancha. Integra facturación con cumplimiento fiscal español, nóminas con convenios colectivos, gestión de clientes, reservas, citas, pedidos y más.

## 🎯 Sectores Target

| Sector | Convenio |
|--------|----------|
| 🍽️ Hostelería | Guadalajara provincial |
| 🛒 Comercio | Guadalajara provincial |
| ✂️ Peluquerías/Estética | Estatal |
| 🥩 Industrias Cárnicas | Estatal (BOE-A-2025-13965) |
| 🐾 Veterinarios | Estatal (BOE-A-2023-21910) |

## 🚀 Módulos

- **Dashboard** — Panel centralizado con métricas en tiempo real
- **Facturación** — Facturas, rectificativas, proformas (RD 1619/2012)
- **Nóminas** — SS 2026 + IRPF CLM + Convenios + SEPA XML
- **Clientes** — CRM con etiquetas, filtros e historial
- **Reservas** — Sistema de reservas con calendario
- **Citas** — Gestión de citas por profesional/servicio
- **Pedidos** — Pedidos online + WhatsApp
- **Tareas** — Kanban + lista + calendario
- **Empleados** — Gestión de personal con datos de nómina
- **Valoraciones** — Integración Google Reviews
- **Estadísticas** — Gráficas de ingresos, clientes, rendimiento
- **Modelos AEAT** — 303, 111, 115, 130, 190, 349

## 🛠️ Stack Técnico

```
Frontend:  Flutter 3.x (Dart)
Backend:   Firebase (Firestore, Auth, Functions, Storage, Messaging)
Pagos:     Stripe
PDF:       pdf + printing
Firma:     XAdES-BES (Cloud Functions + node-forge)
Remesas:   SEPA XML pain.001.001.03
```

## 📦 Instalación

```bash
# Clonar repositorio
git clone <url> && cd planeag_flutter

# Instalar dependencias
flutter pub get

# Configurar Firebase
# Copiar google-services.json a android/app/
# Copiar GoogleService-Info.plist a ios/Runner/

# Ejecutar
flutter run
```

## 🔧 Configuración

1. **Firebase Console** — Crear proyecto y habilitar Auth, Firestore, Storage, Messaging, Crashlytics
2. **Stripe** — Configurar clave pública/privada en Cloud Functions
3. **Google Reviews** — Configurar OAuth para Google My Business API
4. **Certificado Verifactu** — Subir a Secret Manager para firma XAdES

## 📁 Estructura del Proyecto

```
lib/
├── core/           # Constantes, providers, utils, router, DI
├── domain/         # Modelos de datos (Factura, Nomina, etc.)
├── features/       # Módulos por feature
│   ├── autenticacion/
│   ├── clientes/
│   ├── citas/
│   ├── dashboard/
│   ├── empleados/
│   ├── facturacion/
│   ├── nominas/
│   ├── pedidos/
│   ├── perfil/
│   ├── reservas/
│   ├── servicios/
│   ├── suscripcion/
│   ├── tareas/
│   └── vacaciones/
├── services/       # Servicios (Firebase, PDF, SEPA, etc.)
└── main.dart       # Punto de entrada
```

## 🇪🇸 Cumplimiento Fiscal

- **Verifactu** — RD 1007/2023 + RD 254/2025 (plazo: IS 01/01/2027, resto 01/07/2027)
- **Modelos AEAT** — Exportación en formato posicional (500 chars + CRLF)
- **NIF/CIF/NIE** — Validación algorítmica según normativa AEAT
- **IRPF** — Tramos estatales + autonómicos CLM 2026
- **SS** — Bases y tipos 2026 (MEI 0.9%, base máx 5,101.20€)

## 📄 Licencia

Propiedad de Fluixtech. Todos los derechos reservados.

---

*Desarrollado con ❤️ por [Fluixtech](https://fluixtech.com)*
