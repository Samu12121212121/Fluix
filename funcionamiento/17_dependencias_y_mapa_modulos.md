# Mapa de Dependencias entre Módulos

## Diagrama de dependencias

```
                    ┌─────────────────┐
                    │  autenticacion  │ ← Base de toda la app
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────────┐
              │              │                  │
         ┌────▼────┐   ┌─────▼─────┐   ┌───────▼──────┐
         │registro │   │onboarding  │   │   dashboard  │ ← Agrega todo
         └────┬────┘   └─────┬─────┘   └──────────────┘
              │              │
              └──────┬───────┘
                     │
              ┌──────▼──────┐
              │ suscripcion │ ← Controla acceso a módulos
              └─────────────┘


MÓDULOS DE NEGOCIO (requieren suscripción activa):

empleados ──────┬──── nominas ──────┬──── finiquitos
                │                   │
                ├──── vacaciones ────┘
                │
                ├──── fichajes
                │
                └──── tareas ─────── clientes (opcional)

clientes ───────────── reservas ──── servicios
                │
                └────── pedidos ──── catalogo ──── tpv
                              │
                              └──── facturacion ──── fiscal (VeriFactu)
                                                      │
                                                      └──── PDF templates


APP PÚBLICA (rol clienteFinal):

explorar_negocios ─── perfil_cliente ─── tienda_monedas
                                │
                                ├──── fidelizacion
                                ├──── flash_slots
                                └──── valoraciones
```

---

## Tabla de dependencias detallada

| Módulo | Depende de | Lo usan |
|--------|-----------|---------|
| autenticacion | — | todos |
| dashboard | todos (agrega) | — |
| registro | autenticacion | — |
| onboarding | autenticacion, suscripcion | — |
| suscripcion | perfil, stripe | todos los módulos premium |
| empleados | autenticacion | nominas, vacaciones, fichajes, tareas, reservas, finiquitos |
| nominas | empleados, vacaciones, fichajes | finiquitos, fiscal |
| vacaciones | empleados | nominas, finiquitos |
| finiquitos | empleados, nominas, vacaciones | — |
| fichajes | empleados | nominas |
| tareas | empleados | clientes (vinculación) |
| clientes | — | pedidos, reservas, facturacion, tareas |
| pedidos | clientes, catalogo, facturacion | tpv |
| catalogo | — | pedidos, tpv |
| tpv | pedidos, facturacion, catalogo | — |
| facturacion | clientes | fiscal, pedidos, tpv |
| fiscal | facturacion, empleados, nominas | — |
| reservas | clientes, empleados, servicios | — |
| servicios | empleados | reservas |
| perfil | autenticacion | suscripcion |
| explorar_negocios | — | perfil_cliente, fidelizacion, tienda_monedas |
| perfil_cliente | explorar_negocios | tienda_monedas, fidelizacion |
| tienda_monedas | perfil_cliente | — |
| fidelizacion | explorar_negocios, tienda_monedas | — |
| flash_slots | explorar_negocios | — |
| valoraciones | clientes | perfil_cliente |

---

## Flujos de datos principales

### Flujo de venta completa (tienda online)
```
cliente hace pedido (web)
    → onNuevoPedido (CF) → notificación al negocio
    → negocio confirma → onNuevoPedidoWhatsApp (CF) → mensaje a cliente
    → pedido entregado + pago registrado
    → onNuevoPedidoGenerarFactura (CF) → factura automática
    → factura → verifactu_service → firmarXMLVerifactu (CF)
    → remitirVerifactu (CF) → AEAT
    → factura alimenta Modelo 303 (IVA trimestral)
```

### Flujo de nómina mensual
```
Inicio de mes
    → propietario crea remesa en nominas
    → sistema genera borradores para todos los empleados activos
    → cálculo: SS + IRPF + embargos + complementos + ausencias (de fichajes)
    → propietario revisa y aprueba cada nómina
    → empleado firma digitalmente
    → se genera SEPA XML → banco hace transferencias
    → retenciones IRPF → alimentan Modelo 111 trimestral
```

### Flujo de reserva
```
cliente hace reserva (web pública)
    → reservasPublicas (CF HTTP) → crea en estado "pendiente"
    → onNuevaReserva (CF) → email + push al negocio
    → negocio confirma → onReservaConfirmada (CF) → email/push al cliente
    → 24h antes: recordatoriosCitas (CF Scheduled)
    → reserva completada → onReservaCompletada (CF) → solicitar valoración
    → cliente deja valoración → onNuevaValoracion (CF) → actualiza rating en negocios_publicos
    → valoración → evalúa trofeos → onResenaCreadaTrofeos (CF)
```

---

## Dependencias del pubspec.yaml (principales)

### Estado y navegación
- `provider` — gestión de estado
- `go_router` — navegación declarativa

### Firebase
- `firebase_core`, `firebase_auth`, `cloud_firestore`
- `firebase_storage`, `firebase_messaging`, `firebase_analytics`
- `firebase_crashlytics`, `firebase_remote_config`

### UI
- `flutter_svg`, `cached_network_image`, `shimmer`
- `table_calendar` — calendario vacaciones/reservas
- `fl_chart` — gráficos del dashboard
- `syncfusion_flutter_charts` — gráficos avanzados
- `photo_view` — visor de imágenes

### PDF
- `pdf` — generación de PDFs
- `printing` — impresión y previsualización
- `flutter_pdfview` — visor de PDFs

### Dispositivo
- `blue_thermal_printer` — impresora térmica Bluetooth (TPV)
- `mobile_scanner` — scanner QR/código de barras (TPV)
- `local_auth` — biometría (FaceID/huella)
- `geolocator`, `geocoding` — GPS para fichajes
- `image_picker` — selección de fotos

### Pagos
- `flutter_stripe` — integración Stripe

### Datos locales
- `sqflite` — SQLite para modo offline
- `shared_preferences` — preferencias locales
- `hive` — base de datos local rápida

### Utilidades
- `dio` — HTTP client
- `intl` — formateo de fechas, números y monedas
- `uuid` — generación de IDs únicos
- `crypto` — SHA-256 para hash chain VeriFactu
- `pointycastle` — criptografía para firma XAdES
- `xml` — generación y parseo de XML (VeriFactu, SEPA)
- `csv` — importación/exportación de CSV
- `path_provider` — rutas del sistema de archivos
