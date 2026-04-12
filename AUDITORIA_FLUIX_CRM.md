# 🔒 AUDITORÍA FLUIX CRM — Seguridad, Modelos Fiscales y Empleados
> Actualizado: 12 abril 2026

---

## ✅ 1. CUENTA CREADA Y 2FA ACTIVADO
- **Estado**: ✅ Completado
- La cuenta está operativa con autenticación de dos factores (2FA/TOTP)
- Implementación en `services/auth/dos_factores_service.dart`

---

## ✅ 2. FACE ID — Flujo Completo Corregido

### Problema original
El Face ID no funcionaba en iOS porque:
1. El widget de biometría usaba `canCheckBiometrics()` para decidir si mostrarse, pero en iOS esto devuelve `false` ANTES de que el usuario conceda el permiso de Face ID → el toggle nunca aparecía.
2. Al activar, no se llamaba a `authenticate()` → iOS nunca mostraba el diálogo de permiso del sistema.
3. No había manejo de errores (dispositivo sin Face ID, bloqueado, denegado, etc.)

### Correcciones aplicadas

#### 2a. Detección de soporte (`BiometriaService`)
```
dispositivoSoportaBiometria() → usa isDeviceSupported() en vez de canCheckBiometrics
```
Esto permite detectar el hardware incluso antes del permiso.

#### 2b. Flujo de activación (`_ToggleBiometria` en pantalla_perfil.dart)
```
1. Usuario pulsa toggle ON
2. App llama a BiometriaService.autenticar()
3. iOS muestra diálogo: "¿Permitir que Fluix use Face ID?"
4. Si acepta → authenticate() devuelve true → guardar en SecureStorage
5. Si rechaza → mostrar diálogo explicativo con "Ir a Ajustes"
```

#### 2c. Info.plist verificado
```xml
<key>NSFaceIDUsageDescription</key>
<string>Fluix CRM usa Face ID para proteger el acceso a datos sensibles de tu empresa.</string>
```
→ Ya estaba presente ✅

#### 2d. Manejo de errores completo
| Error | Código | Mensaje |
|-------|--------|---------|
| No disponible | `NotAvailable` | "Este dispositivo no soporta autenticación biométrica" |
| No configurada | `NotEnrolled` / `PasscodeNotSet` | "Ve a Ajustes → Face ID y código" + botón Ajustes |
| Bloqueada | `LockedOut` / `PermanentlyLockedOut` | "Demasiados intentos. Desbloquea con PIN" |
| Cancelada | `UserCancel` / `SystemCancel` | (silencioso, no hace nada) |
| Permiso denegado | fallback general | "Ve a Ajustes → Fluix → Face ID" + botón Ajustes |

#### 2e. Abrir Ajustes del dispositivo
- iOS: `app-settings:` via `url_launcher` → abre Ajustes → Fluix
- Implementado en `BiometriaService.abrirAjustesDispositivo()`

### Archivos modificados
- `lib/services/auth/biometria_service.dart` — añadido `abrirAjustesDispositivo()`, import url_launcher
- `lib/features/perfil/pantallas/pantalla_perfil.dart` — reescrito `_ToggleBiometria` completo

---

## ✅ 3. SISTEMA DE INVITACIÓN DE EMPLEADOS

### Implementación
- **Servicio**: `services/auth/invitaciones_service.dart` (ya existía)
- **Pantalla registro**: `features/registro/pantallas/pantalla_registro_invitacion.dart` (ya existía)
- **Integración en empleados**: ✅ NUEVO — botón "Invitar empleado" añadido

### Flujo
```
Admin → Módulo Empleados → FAB "Invitar" (icono mail)
  → Diálogo: email + rol (admin/staff)
  → InvitacionesService.enviarInvitacion()
  → Firestore: invitaciones/{token}
  → Cloud Function envía email con enlace
  → Empleado abre enlace → pantalla_registro_invitacion.dart
  → Se crea cuenta + se asocia a empresa
```

### Archivo modificado
- `lib/features/empleados/pantallas/modulo_empleados_screen.dart` — añadido `_invitarEmpleado()` y FAB doble

---

## ✅ 4. CONSTRUCCIÓN / OBRA — Sector Configurado

### Problema
El onboarding no guardaba el campo `sector` en Firestore, solo `tipo_negocio`. El servicio de nóminas/convenios necesita `sector` para cargar las categorías correctas (ej. `construccion-obras-publicas-guadalajara`).

### Corrección
- Añadida función `_inferirSector()` al onboarding
- El sector se infiere automáticamente del tipo de negocio seleccionado
- Se guarda en Firestore junto con los demás datos de empresa

### Mapeo
| tipo_negocio | sector |
|---|---|
| Restaurante / Bar | hosteleria |
| Tienda / Comercio | comercio |
| Peluquería / Estética / Gimnasio / Spa | peluqueria |
| Construcción / Obra / Taller | construccion |
| Clínica / Salud | salud |
| Otro | otros |

### Archivo modificado
- `lib/features/onboarding/pantallas/pantalla_onboarding.dart`

---

## 📋 5. MODELOS FISCALES — Estado Completo (Actualización AEAT 2026)

### Cambios AEAT 2026 implementados

| Cambio | Estado |
|--------|--------|
| Mod.303: TXT ya no válido → solo Pre303 online | ✅ PDF borrador + botón Sede AEAT |
| Mod.130: Presentación online Pre130 | ✅ Botón Sede AEAT añadido |
| Mod.390: Online obligatorio | ✅ Botón Sede AEAT, eliminado export posicional |
| Mod.347: Pipe-delimited → posicional AEAT real | ✅ 500 chars/registro, ISO-8859-1 |
| Mod.202: NUEVO para sociedades | ✅ Dominio + calculadora + PDF + pantalla |
| Campo `forma_juridica` en empresa | ✅ EmpresaConfig + perfil + filtrado |
| Calendario fiscal automático | ✅ Widget dinámico PENDIENTE/PRESENTADO/VENCIDO |
| Widget "Presentar en AEAT" reutilizable | ✅ Pasos + enlace + justificante |

### Modelos implementados

| Modelo | Descripción | Fichero TXT | Presentación |
|--------|-------------|-------------|--------------|
| **303** | IVA trimestral | ❌ No válido 2026 | Pre303 online |
| **111** | Retenciones IRPF | ✅ DR111e16v18 | Fichero importable |
| **115** | Retenciones arrendamientos | ✅ DR115e15v13 | Fichero importable |
| **130** | IRPF autónomos | ❌ | Pre130 online |
| **190** | Resumen anual retenciones | ✅ Posicional | Fichero importable |
| **390** | Resumen anual IVA | ❌ | Online obligatorio |
| **347** | Operaciones terceros >3.005€ | ✅ Posicional AEAT | Fichero importable |
| **349** | Operaciones intracomunitarias | ✅ Posicional AEAT | Fichero importable |
| **202** | **NUEVO** Pago fraccionado IS | ❌ | Online obligatorio |

### Modelos según forma jurídica
- **Autónomo/CB/SC**: 303, 111, **130**, 115, 347, 390, 190
- **S.L./S.A./S.L.P./Cooperativa**: 303, 111, **202**, 115, 347, 390, 190

---

## 📋 6. ARCHIVOS NUEVOS (8)

| Archivo | Descripción |
|---------|-------------|
| `lib/domain/modelos/modelo202.dart` | Modelo de dominio Mod.202 |
| `lib/services/fiscal/mod202_calculator.dart` | Calculadora Mod.202 |
| `lib/services/fiscal/mod202_exporter.dart` | Exportador PDF Mod.202 |
| `lib/features/fiscal/pantallas/modelo202_screen.dart` | Pantalla completa Mod.202 |
| `lib/services/fiscal/calendario_fiscal_service.dart` | Servicio de plazos fiscales |
| `lib/services/fiscal/sede_aeat_urls.dart` | URLs centralizadas Sede AEAT |
| `lib/widgets/calendario_fiscal_widget.dart` | Widget calendario fiscal |
| `lib/widgets/presentar_aeat_widget.dart` | Widget presentar en AEAT |

## 📋 7. ARCHIVOS MODIFICADOS (8)

| Archivo | Cambios |
|---------|---------|
| `lib/domain/modelos/empresa_config.dart` | Enum FormaJuridica + campo + helpers esSociedad/tributaIRPF |
| `lib/services/exportadores_aeat/mod_347_exporter.dart` | Reescrito a formato posicional AEAT |
| `lib/features/fiscal/pantallas/modelo303_screen.dart` | Quitado TXT, añadido PDF + Sede AEAT |
| `lib/features/fiscal/pantallas/modelo130_screen.dart` | Añadido botón Sede AEAT |
| `lib/features/fiscal/pantallas/modelo390_screen.dart` | Quitado posicional, añadido Sede AEAT + widget |
| `lib/features/facturacion/pantallas/tab_modelos_fiscales.dart` | Tabs 202/347 + filtro forma jurídica + calendario dinámico |
| `lib/features/facturacion/pantallas/pantalla_configuracion_fiscal_empresa.dart` | Dropdown forma jurídica |
| `AUDITORIA_FLUIX_CRM.md` | Actualizado con todos los cambios |

