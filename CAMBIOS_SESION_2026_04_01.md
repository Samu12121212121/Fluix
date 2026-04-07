# ✅ CORRECCIONES Y MEJORAS — Sesión 2026-04-01

## Cambios implementados en esta sesión

### 1. pantalla_perfil.dart — REESCRITO COMPLETAMENTE
- Estaba completamente roto (código de 3 clases mezclado)
- Ahora tiene estructura correcta: `PantallaPerfil` → tabs dinámicos
  - Tab "Mi Perfil" (siempre visible): nombre, teléfono, cambio de contraseña, sonidos
  - Tab "Mi Empresa" (solo Propietario): tipo negocio, sector, horarios
  - Tab "Cuentas" (solo Admin Plataforma): embeds `GestionarCuentasScreen`

### 2. facturacion_service.dart — NUMERACIÓN ANUAL
- Añadido campo `anio_ultimo_{serie}` en Firestore
- Al cambiar de año el contador se resetea automáticamente a 1
- Protección anti-hueco: `anularFactura` solo cambia estado, nunca decrementa contador
- `obtenerFacturasPorEstado` ahora filtra en Firestore (server-side) en vez de en memoria

### 3. configuracion_modulos_simple.dart + configuracion_modulos.dart — LIMPIADOS
- Ambos archivos eran código muerto (nadie los importaba)
- Reemplazados por comentario que apunta al `ConfiguracionDashboardScreen` real
- El toggle de módulos ya funcionaba correctamente en `configuracion_dashboard_screen.dart`

### 4. importar_csv_screen.dart — WARNINGS ELIMINADOS
- Eliminadas variables no usadas `_nombreArchivo` y `_bytesArchivo`
- Import `dart:typed_data` innecesario eliminado

### 5. pubspec.yaml — DEPENDENCIAS AÑADIDAS
- `audioplayers: ^6.1.0` — para sonidos de notificación (ya se usaba pero faltaba)
- `flutter_launcher_icons: ^0.14.3` — para generar icono de la app
- Añadido directorio `assets/sounds/` para archivos de audio

### 6. inicializar_empresa.dart — CONTADOR ACTUALIZADO
- El contador de facturas ahora también inicializa `anio_ultimo_factura`

---

## ⚠️ PASOS MANUALES REQUERIDOS

### A. Instalar dependencias (OBLIGATORIO antes de compilar)
```bash
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter
flutter pub get

cd billing_service
dart pub get
```

### B. Añadir sonidos de notificación
Coloca archivos `.wav` o `.mp3` en `assets/sounds/`:
- `notif_default.wav`
- `notif_urgente.wav`
- `notif_suave.wav`
- `notif_digital.wav`
- `notif_clasico.wav`
- `sin_sonido.wav` (puede ser un archivo vacío/silencioso)

Puedes descargar sonidos gratuitos de: https://freesound.org

### C. Añadir icono de la app
1. Crea o descarga un icono 1024×1024 px (PNG, sin transparencia para Android)
2. Guárdalo en `assets/icon/app_icon.png`
3. Ejecuta:
```bash
flutter pub run flutter_launcher_icons
```

### D. Compilar y probar
```bash
flutter run --debug
# o para release:
flutter build apk --release
```

---

## Estado del proyecto

| Módulo | Estado |
|--------|--------|
| Flutter app (compilación) | ✅ Sin errores |
| billing_service | ⚠️ Necesita `dart pub get` |
| Cloud Functions | ✅ Sin errores TypeScript |
| Firestore Rules | ✅ Corregidas |
| Módulo Citas | ✅ Con profesional + tipo servicio + calendario |
| Módulo Tareas | ✅ 3 vistas (Kanban/Lista/Calendario) |
| Toggle módulos | ✅ Persiste en Firestore |
| Numeración facturas | ✅ Reset anual + anti-hueco |
| Perfil usuario | ✅ Reescrito y funcional |
| Gestión cuentas (admin) | ✅ Accesible desde Perfil |

