# Fluix CRM — Mapa de Reconocimiento
**Fase 1 · Solo lectura · 2026-10-26**

---

## 1. Metadatos del proyecto

| Campo | Valor |
|---|---|
| Nombre | `planeag_flutter` |
| Versión app | 1.0.18 |
| Flutter SDK | `^3.11.1` |
| Dart SDK | `^3.11.1` |
| Firebase project | `planeaapp-4bea4` (europe-west1) |
| Bundle ID iOS | `com.fluixtech.crm` |
| Application ID Android | `com.fluixcrm.app` |
| Namespace Android | `com.fluixcrm.crm` ⚠️ inconsistencia |
| Min SDK Android | 24 (Android 7.0) |
| Target SDK Android | 35 |
| iOS deployment target | 17.0 ⚠️ muy alto |
| Apple Team | `3AMXPPGLN8` (SAMUEL CORCHO ORTEGA) |
| Aprovisionamiento iOS | manual · perfil `Fluix12` |

---

## 2. Ramas Git

| Rama | Estado |
|---|---|
| `main` | Rama activa. 5 commits más recientes que `web-module-stabilization`. |
| `web-module-stabilization` | Divergida. Tiene commits únicos (sep 2026: fixes dashboard, fiscal, TPV). Pendiente de evaluar merge. |

**Nota:** ambas ramas se analizarán — `main` como base, `web-module-stabilization` como delta.

---

## 3. Estructura de `lib/`

```
lib/
├── core/              # config, di, enums, errores, firebase, layout, navigation, router, tema, widgets
├── data/              # datasources, repositorios
├── domain/            # casos_uso, modelos (58 .dart), repositorios
├── features/          # 40+ módulos feature-first
│   ├── autenticacion/
│   ├── clientes/
│   ├── contenido_web/
│   ├── dashboard/        # pantallas principales + web editor
│   ├── empleados/
│   ├── facturacion/
│   ├── fichaje/          # ⚠️ duplicado con fichajes/
│   ├── fichajes/
│   ├── fiscal/
│   ├── negocio_publico/
│   ├── nominas/
│   ├── finiquitos/
│   ├── pedidos/
│   ├── pdf_templates/
│   ├── reservas/
│   ├── tpv/
│   └── web/
├── models/            # modelos alternativos (posible duplicación)
├── modulos/tpv_bar/
├── screens/           # pantallas sueltas (legacy?)
├── scripts/
├── services/          # 100+ servicios planos + subdirectorios especializados
│   ├── auth/
│   ├── exportadores_aeat/  # exportadores AEAT (7 archivos)
│   ├── fiscal/             # calculadoras modelos (13 archivos)
│   ├── pdf/                # generación PDF
│   ├── tpv/
│   └── verifactu/          # motor Verifactu completo (19 archivos)
├── utils/
└── widgets/tpv/
```

---

## 4. Mapa de módulos analizados

### 4.1 Web + Editorial Nazarí
**Pantallas:**
```
lib/features/dashboard/pantallas/
  pantalla_contenido_web.dart          # hub principal del módulo web
  pantalla_contenido_web_blog.dart
  pantalla_contenido_web_autores.dart
  pantalla_contenido_web_galeria.dart
  pantalla_contenido_web_secciones.dart
  pantalla_editor_blog.dart
  pantalla_editor_word.dart            # editor WYSIWYG (flutter_quill)
  tab_blog_web.dart
  tab_catalogo_web.dart
  tab_categorias_nazari.dart           # Nazarí específico
  tab_seleccion_nazari.dart
  tab_seleccion_nazari_pack.dart
  tab_eventos_web.dart
  tab_analytics_web.dart
  tab_config_web.dart
  tab_seo_web.dart
  tab_mensajes_contacto.dart
  pantalla_mensajes_contacto.dart
lib/features/contenido_web/pantallas/  # sub-módulo complementario
lib/features/web/presentation/         # capa alternativa web
```
**Servicios:**
```
lib/services/contenido_web_service.dart
lib/services/blog_service.dart
lib/services/admin_contenido_web_service.dart
lib/services/analytics_web_service.dart
lib/services/catalogo_web_sync_service.dart
```
**Cloud Functions:**
```
functions/src/nazariCache.ts
functions/src/nazariEbooks.ts
functions/src/nazariMigracion.ts
functions/src/nazariPedidoEmail.ts
functions/src/nazariResumenEmail.ts
functions/src/blogApi.ts
functions/src/schedulerBlog.ts
functions/src/cdnPurge.ts
```

### 4.2 Fichajes
**Pantallas:**
```
lib/features/fichajes/pantallas/
  gestion_fichajes_screen.dart
  historial_empleado_sheet.dart
  pantalla_fichaje_empleado.dart
  resumen_mensual_empleados.dart
lib/features/fichaje/pantalla_fichaje/  # ⚠️ carpeta duplicada (legacy?)
```
**Servicios:**
```
lib/features/fichajes/servicios/
  fichaje_service.dart
lib/services/firma_service.dart
lib/services/geolocalizacion_service.dart
```
**Modelo:**
```
lib/features/fichajes/modelos/fichaje.dart
```

### 4.3 Empleados
**Pantallas:**
```
lib/features/empleados/pantallas/
  modulo_empleados_screen.dart
  formulario_empleado_form.dart
  configurar_acceso_staff_screen.dart
  configurar_modulos_empleado_screen.dart
  empleados_baja_screen.dart
  formulario_datos_nomina_form.dart
  portal_empleado_screen.dart
lib/features/nominas/pantallas/        # módulo relacionado
lib/features/finiquitos/pantallas/     # módulo relacionado
lib/features/vacaciones/pantallas/
```
**Servicios:**
```
lib/services/nominas_service.dart
lib/services/nomina_pdf_service.dart
lib/services/baja_empleado_service.dart
lib/services/finiquito_service.dart
lib/services/finiquito_calculator.dart
lib/services/documentos_empleado_service.dart
lib/services/regularizacion_irpf_service.dart
lib/services/convenio_service.dart
lib/services/convenio_firestore_service.dart
```
**Cloud Functions:**
```
functions/src/crearEmpleado.ts
functions/src/adminClaims.ts
functions/src/invitaciones.ts
```

### 4.4 Clientes
**Pantallas:**
```
lib/features/clientes/pantallas/
  modulo_clientes_screen.dart
  clientes_silenciosos_screen.dart
  duplicados_cliente_screen.dart
  importar_csv_screen.dart
```
**Servicios:**
```
lib/services/clientes_service.dart
lib/services/cliente_estado_service.dart
lib/services/cliente_notificaciones_service.dart
lib/services/importacion_clientes_service.dart
lib/services/exportacion_clientes_service.dart
lib/services/fusion_clientes_service.dart
```
**Modelo:**
```
lib/domain/modelos/cliente.dart
lib/domain/modelos/cliente_importado_model.dart
```

### 4.5 Facturación
**Pantallas:**
```
lib/features/facturacion/pantallas/
  modulo_facturacion_screen.dart
  formulario_factura_screen.dart
  detalle_factura_screen.dart
  formulario_rectificativa_screen.dart
  formulario_albaran_recibido_screen.dart
  formulario_factura_recibida_screen.dart
  formulario_linea_factura_sheet.dart
  tab_facturas.dart
  tab_facturas_recibidas.dart
  tab_facturas_recurrentes.dart
  tab_albaranes_recibidos.dart
  tab_graficos_contabilidad.dart
  tab_libro_ingresos.dart
  tab_modelos_fiscales.dart            # enlaza con módulo fiscal
  tab_mod_347.dart
  tab_mod_349.dart
  pantalla_configuracion_fiscal_empresa.dart
  pantalla_contabilidad.dart
  resumen_fiscal_screen.dart
  upload_invoice_screen.dart
```
**Servicios Verifactu:**
```
lib/services/verifactu/
  verifactu_service.dart
  verifactu_flow_service.dart
  xml_builder_service.dart
  xml_payload_verifactu_builder.dart
  hash_chain_service.dart
  firma_xades_service.dart
  firma_xades_pkcs12_service.dart
  firma_xades_minima_validator.dart
  aeat_remision_service.dart
  representacion_verifactu.dart
  validador_verifactu.dart
  generador_qr_verifactu.dart
  modelos_verifactu.dart
  certificado_repository.dart
  qr_generator_service.dart
  qr_service.dart
  lgt_201bis_riesgos.dart
  politica_verifactu_2027.dart
  README_VERIFACTU_FASE2.md
```
**Cloud Functions:**
```
functions/src/firmarXMLVerifactu.ts
functions/src/remitirVerifactu.ts
```

### 4.6 Modelos Fiscales AEAT
**Pantallas:**
```
lib/features/fiscal/pantallas/
  modelo111_screen.dart   (retenciones trimestrales)
  modelo115_screen.dart   (retenciones alquiler)
  modelo130_screen.dart   (IRPF fraccionado)
  modelo180_screen.dart   (resumen anual alquileres)
  modelo190_screen.dart   (resumen anual retenciones)
  modelo202_screen.dart   (pagos fraccionados IS)
  modelo303_screen.dart   (IVA trimestral)
  modelo347_screen.dart   (operaciones terceros)
  modelo349_screen.dart   (operaciones intracomunitarias)
  modelo390_screen.dart   (resumen anual IVA)
  export_models_screen.dart
  historial_presentaciones_screen.dart
  calendario_fiscal_screen.dart
  review_transaction_screen.dart
  invoice_result_screen.dart
  subir_certificado_verifactu_screen.dart
  pantalla_libros_registro.dart
  upload_invoice_screen.dart
```
**Calculadoras/Exportadores (lib/services/fiscal/ + exportadores_aeat/):**
```
mod303_service.dart / dr303e26v101_exporter.dart
mod347_service.dart / mod_347_exporter.dart
mod349_service.dart / mod_349_exporter.dart
mod390_calculator.dart / mod390_exporter.dart
mod390_posicional_service.dart
modelo111_service.dart / modelo111_aeat_exporter.dart
mod115_calculator.dart / mod115_exporter.dart
mod130_calculator.dart / mod130_exporter.dart
mod180_calculator.dart
mod202_calculator.dart / mod202_exporter.dart
libro_registro_iva_exporter.dart
```
**Cloud Functions:**
```
functions/src/fiscal/models/ (model111, model115, model180, model190, model202, model303, model347, model390)
functions/src/fiscal/exports/ (generateModelPdf, model303PreDec)
functions/src/fiscal/ocrPreprocessor.ts
functions/src/fiscal/processInvoice.ts
```

---

## 5. Plataformas

### iOS
- Deployment target: **17.0** (excluye iPhone 6s/7 en iOS 15/16, ~15% usuarios)
- Método exportación: `app-store`, firma manual
- Provisioning: `Fluix12` para `com.fluixtech.crm`
- Podfile: `platform :ios, '17.0'`

### Android
- `minSdk=24` (Android 7.0), `targetSdk=35`
- `applicationId="com.fluixcrm.app"` vs `namespace="com.fluixcrm.crm"` ⚠️ **inconsistencia crítica**
- Keystore: `android/planeaguada-release.jks` (referenciada desde `key.properties`)
- Permisos declarados: INTERNET, BOOT, VIBRATE, POST_NOTIFICATIONS, GPS fino/grueso, Bluetooth x4
- No declarados en Manifest: CAMERA (mobile_scanner), RECORD_AUDIO → pendiente verificar

### Windows
- Build: CMake estándar Flutter
- Sin MSIX ni auto-update configurado
- Sin firma de código
- Plugins **sin soporte Windows** (probables): `blue_thermal_printer`, `mobile_scanner`, `local_auth` (biometría), audioplayers (parcial)

---

## 6. Firebase y seguridad

| Servicio | Versión |
|---|---|
| firebase_core | ^4.15.0 |
| cloud_firestore | ^6.10.0 |
| firebase_auth | ^6.7.0 |
| firebase_messaging (FCM) | ^16.7.0 |
| firebase_analytics | ^12.6.0 |
| firebase_storage | ^13.6.0 |
| firebase_app_check | ^0.4.8 |
| firebase_crashlytics | ^5.4.0 |
| firebase_performance | ^0.11.6 |

- **Firestore rules**: 1.497 líneas. Multi-tenant por `empresaId`. Roles: propietario / admin / staff / empleado / clienteFinal / plataforma_admin.
- **Firestore indexes**: Definidos para pedidos, pedidos_web_nazari, carta_web, pdf_templates, valoraciones, etc.

---

## 7. Alertas rápidas (señales para agentes)

| # | Nivel | Descripción | Fichero |
|---|---|---|---|
| A1 | ⛔ Crítico | `namespace` Android ≠ `applicationId` | `android/app/build.gradle.kts:21,37` |
| A2 | 🔴 Alto | iOS min target 17.0 — excluye usuarios en iOS 15/16 | `ios/Podfile:1` |
| A3 | 🔴 Alto | Windows sin MSIX ni firma de código | `windows/CMakeLists.txt` |
| A4 | 🔴 Alto | Carpeta `lib/features/fichaje/` duplicada vs `lib/features/fichajes/` | estructura lib/ |
| A5 | 🟡 Medio | `blue_thermal_printer` y `mobile_scanner` sin soporte Windows declarado | `pubspec.yaml:144,148` |
| A6 | 🟡 Medio | `local_auth` (biometría) en Windows requiere Windows Hello config explícita | `pubspec.yaml:158` |
| A7 | 🟡 Medio | `web-module-stabilization` divergida de main; revisar si hay trabajo no mergeado | git branches |
| A8 | 🟡 Medio | `sqflite` sin soporte nativo Windows → usa `sqflite_common_ffi` (OK si se inicializa correctamente) | `pubspec.yaml:71-72` |
| A9 | ℹ️ Info | `lib/models/` y `lib/domain/modelos/` coexisten — posible duplicación | estructura lib/ |
| A10 | ℹ️ Info | Módulo Verifactu extenso (19 ficheros) — pendiente validación legal exhaustiva | `lib/services/verifactu/` |

---

*Generado en Fase 1 de reconocimiento. Sin modificación de código.*
