# ✅ ACCESO A PLANTILLAS PDF DESDE MI PERFIL

## 📱 NUEVA UBICACIÓN

El acceso a **Plantillas PDF** ahora está integrado en:

**Mi Perfil → Mi Empresa → Configuración de PDFs**

---

## 🗺️ RUTA DE NAVEGACIÓN

```
1. Tap en avatar/perfil (esquina superior derecha)
   ↓
2. Seleccionar tab "Mi Empresa"
   ↓
3. Scroll hasta "Configuración Fiscal y Facturación"
   ↓
4. Tap en "Configuración de PDFs (Plantillas, Diseño)"
   ↓
5. ¡Listo! 🎉
```

---

## 🖼️ VISTA DE LA PANTALLA

```
┌─────────────────────────────────────────────────────────┐
│  👤 Mi Perfil    🏢 Mi Empresa    ⚙️ Cuentas           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  📊 Información del negocio                             │
│  [Nombre, Tipo, Sector, etc.]                           │
│                                                         │
│  🕐 Horarios de apertura                                │
│  [Lun-Vie 9:00-20:00]                                   │
│                                                         │
│  💡 Mejoras y sugerencias                               │
│  [Campo de texto...]                                    │
│                                                         │
│  ▼ Configuración Fiscal y Facturación                  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  📋 Configuración Fiscal (NIF, Series, etc.)   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  📄 Configuración de PDFs (Plantillas, Diseño) │  ← AQUÍ
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │         💾 Guardar cambios                      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🎨 DISEÑO DEL BOTÓN

- **Icono**: 📄 (picture_as_pdf_outlined)
- **Color**: Azul claro `#1565C0`
- **Texto**: "Configuración de PDFs (Plantillas, Diseño)"
- **Estilo**: OutlinedButton con borde azul
- **Tamaño**: Ancho completo, altura 52px
- **Posición**: Justo debajo del botón "Configuración Fiscal"

---

## 🔧 CAMBIOS TÉCNICOS REALIZADOS

### 1. Import Agregado
**Archivo**: `lib/features/perfil/pantallas/pantalla_perfil.dart`  
**Línea**: 18

```dart
import '../../pdf_editor/pantallas/pdf_templates_list_screen.dart';
```

### 2. Botón Insertado
**Archivo**: `lib/features/perfil/pantallas/pantalla_perfil.dart`  
**Línea**: ~1087

```dart
SizedBox(
  width: double.infinity, height: 52,
  child: OutlinedButton.icon(
    onPressed: () {
      final empresaId = widget.sesion?.empresaId;
      if (empresaId == null) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PdfTemplatesListScreen(empresaId: empresaId),
      ));
    },
    icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
    label: const Text('Configuración de PDFs (Plantillas, Diseño)',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF1565C0),
      side: const BorderSide(color: Color(0xFF1565C0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
),
```

---

## 🔒 CONTROL DE ACCESO

### Permisos Requeridos

| Rol | Acceso al Tab "Mi Empresa" | Acceso a Plantillas PDF |
|-----|---------------------------|-------------------------|
| **Propietario** | ✅ Sí | ✅ Sí |
| **Admin** | ✅ Sí | ✅ Sí |
| **Staff** | ❌ No | ❌ No |
| **Cliente** | ❌ No | ❌ No |

**Nota**: Solo los usuarios con rol Propietario o Admin ven el tab "Mi Empresa" y, por tanto, el botón de Configuración de PDFs.

---

## 📊 VENTAJAS DE ESTA UBICACIÓN

### ✅ Pros

1. **Contexto Lógico**: Está junto a "Configuración Fiscal", que es similar en naturaleza
2. **Acceso Restringido**: Solo admin/propietario ven esta sección
3. **Espacio Adecuado**: No satura el dashboard principal
4. **Flujo Natural**: Los usuarios buscan configuraciones en "Mi Empresa"
5. **Sin Módulo Extra**: No requiere activar módulo en Firestore

### ⚠️ Consideraciones

- Requiere 2 taps extra vs dashboard directo
- Menos visible para nuevos usuarios
- Depende de que el usuario explore "Mi Empresa"

---

## 🚀 VERIFICACIÓN POST-DESPLIEGUE

### Checklist de Pruebas

- [ ] Login como Propietario
- [ ] Ir a Mi Perfil
- [ ] Tab "Mi Empresa" visible
- [ ] Scroll hasta "Configuración Fiscal y Facturación"
- [ ] Botón "Configuración de PDFs" visible
- [ ] Tap en botón abre PdfTemplatesListScreen
- [ ] empresaId se pasa correctamente
- [ ] Navegación hacia atrás funciona
- [ ] Login como Staff → Tab "Mi Empresa" NO visible ✅

---

## 📚 DOCUMENTACIÓN RELACIONADA

1. **ACCESO_PLANTILLAS_PDF_RAPIDO.txt** ← Guía visual rápida (ACTUALIZADA)
2. **RESUMEN_CORRECCIONES_PDF.md** ← Correcciones técnicas
3. **COMO_ACCEDER_PLANTILLAS_PDF.md** ← Guía completa de usuario
4. **INTEGRACION_DASHBOARD_COMPLETADA.md** ← Integración original (dashboard)

---

## 🔄 COMPARACIÓN: ANTES vs AHORA

### ANTES (Dashboard)
```
Dashboard → Tab/NavigationRail "Plantillas PDF"
```
- ✅ Acceso directo (1 tap)
- ❌ Requiere módulo en Firestore
- ❌ Satura dashboard con muchos módulos

### AHORA (Mi Perfil)
```
Avatar → Mi Empresa → Configuración de PDFs
```
- ✅ No requiere módulo en Firestore
- ✅ Contexto lógico (junto a Fiscal)
- ⚠️ Requiere 3 taps

---

## 🛠️ MANTENIMIENTO FUTURO

### Si se Requieren Cambios

**Cambiar texto del botón**:
```dart
// Línea ~1098 en pantalla_perfil.dart
label: const Text('TU NUEVO TEXTO AQUÍ',
    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
```

**Cambiar color**:
```dart
// Línea ~1099 en pantalla_perfil.dart
foregroundColor: const Color(0xFFTU_COLOR_AQUI),
side: const BorderSide(color: Color(0xFFTU_COLOR_AQUI)),
```

**Cambiar icono**:
```dart
// Línea ~1095 en pantalla_perfil.dart
icon: const Icon(Icons.TU_ICONO_AQUI, size: 22),
```

**Mover a otra sección**:
- Cortar el bloque `SizedBox` completo (líneas ~1088-1106)
- Pegar en la nueva ubicación deseada

---

## ✅ ESTADO FINAL

**Ubicación**: Mi Perfil → Mi Empresa → Configuración de PDFs  
**Estado**: ✅ **COMPLETAMENTE INTEGRADO**  
**Fecha**: 2026-05-25  
**Versión**: 2.0.0  
**Archivo modificado**: `pantalla_perfil.dart` (1 import + 1 botón)  

---

## 🎯 PRÓXIMOS PASOS RECOMENDADOS

1. **Probar** el flujo completo en desarrollo
2. **Compilar** y probar en dispositivo real
3. **Informar** a usuarios sobre la nueva ubicación
4. **Actualizar** capturas de pantalla en documentación
5. **Considerar** agregar tooltip/ayuda contextual

---

*Integración completada por: GitHub Copilot*  
*Fecha: 2026-05-25 16:00*

