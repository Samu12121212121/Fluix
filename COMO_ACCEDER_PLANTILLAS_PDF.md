# 📱 Cómo Acceder al Sistema de Plantillas PDF

## 🎯 Guía Rápida de Acceso

### Desde la Aplicación Móvil/Desktop

1. **Abrir la app** PlaneaG
2. **Iniciar sesión** como **Administrador** o **Propietario**
3. En el **Dashboard principal**, buscar el módulo **"Plantillas PDF"** (icono 📄)
4. **Tocar/Clic** en el módulo para acceder

---

## 📋 Requisitos de Acceso

### ✅ Permisos Necesarios

- **Rol**: Propietario o Administrador
- **Módulo activo**: El módulo "plantillas_pdf" debe estar habilitado en Firestore
- **Firestore**: Debe existir el documento en `empresas/{empresaId}/modulos/plantillas_pdf`

### ⚠️ Si NO Ves el Módulo

Si no aparece "Plantillas PDF" en tu dashboard:

#### Opción 1: Script Automático (Recomendado)
```bash
cd scripts
node agregar_modulo_plantillas_pdf.js
```

Esto agregará el módulo automáticamente a todas las empresas.

#### Opción 2: Activación Manual en Firestore

1. Abrir **Firebase Console** → Firestore Database
2. Navegar a: `empresas/{TU_EMPRESA_ID}/modulos`
3. Crear documento con ID: `plantillas_pdf`
4. Agregar estos campos:

```json
{
  "id": "plantillas_pdf",
  "nombre": "Plantillas PDF",
  "icono": "article",
  "activo": true,
  "descripcion": "Personaliza el diseño de tus PDFs",
  "orden": 100,
  "requiere_rol": ["propietario", "admin"]
}
```

5. **Guardar** y **reiniciar la app**

---

## 🖥️ Ubicación en la Interfaz

### Vista Desktop (Pantalla Grande)
```
┌───────────────────────────────────────────┐
│  🏠 Dashboard  📊 Estadísticas  👥 Clientes │
│  💰 Facturación  📋 Tareas  📄 Plantillas PDF │
├───────────────────────────────────────────┤
│                                           │
│  [Contenido del módulo seleccionado]     │
│                                           │
└───────────────────────────────────────────┘
```

El módulo aparece en el **NavigationRail** lateral.

### Vista Mobile (Teléfono/Tablet)
```
┌────────────────────────────┐
│ 🏠  📊  👥  💰  📋  📄     │ ← Tabs superiores
├────────────────────────────┤
│                            │
│  [Contenido del módulo]   │
│                            │
└────────────────────────────┘
```

El módulo aparece como **tab** en la barra superior.

---

## 🎨 ¿Qué Puedes Hacer en Plantillas PDF?

### 1. Ver Plantillas Existentes
- Lista de todas tus plantillas
- Filtrar por tipo (Factura, Presupuesto, etc.)
- Ver estado (Activa/Inactiva)

### 2. Crear Nueva Plantilla
```
1. Tap en botón "+"
2. Seleccionar tipo de documento
3. Configurar bloques (Header, Tabla, Totales, etc.)
4. Personalizar colores y tipografía
5. Guardar
```

### 3. Activar/Desactivar Plantillas
- Solo **1 plantilla activa** por tipo de documento
- Al activar una nueva, la anterior se desactiva automáticamente

### 4. Editar Plantilla
```
1. Tap en plantilla existente
2. Modificar bloques y estilos
3. Vista previa en tiempo real
4. Guardar cambios
```

### 5. Eliminar Plantilla
- Confirmar eliminación
- No se puede eliminar plantilla activa (desactivar primero)

---

## 🔧 Integración con PDFs Existentes

### Generación Automática

Cuando generas un PDF en la app:

1. **Sistema busca** plantilla activa para el tipo de documento
2. Si existe → **Usa plantilla personalizada** ✅
3. Si NO existe → **Usa diseño por defecto** (legacy)

### Tipos de Documento Soportados

| Tipo | ID Firestore | Descripción |
|------|--------------|-------------|
| Factura | `factura` | PDFs de facturas |
| Rectificativa | `rectificativa` | Facturas rectificativas |
| Presupuesto | `presupuesto` | PDFs de presupuestos |
| Fichaje | `fichaje` | Informes de fichajes |
| Nómina | `nomina` | PDFs de nóminas |
| Albarán | `albar` | Albaranes de entrega |

---

## 🚀 Flujo de Trabajo Completo

### Escenario: Personalizar Facturas

```
1. Dashboard → Tap "Plantillas PDF"
   
2. Filtrar por: "Factura"
   
3. Si no existe plantilla:
   - Tap "+" → "Nueva Plantilla"
   - Tipo: Factura
   - Nombre: "Factura Corporativa 2026"
   
4. Configurar bloques:
   ✅ Header (logo + datos empresa)
   ✅ Cliente (datos del cliente)
   ✅ Tabla (líneas de factura)
   ✅ Totales (Base + IVA + Total)
   ✅ QR (código Verifactu)
   
5. Personalizar colores:
   - Color primario: #1565C0 (azul)
   - Color accent: #00ACC1 (cyan)
   - Tipografía: Roboto
   
6. Vista previa → Guardar
   
7. Activar plantilla → Listo ✅
```

Ahora **todas las facturas** usarán este diseño automáticamente.

---

## 📊 Códigos de Estado

### En la Lista de Plantillas

| Estado | Icono | Significado |
|--------|-------|-------------|
| ✅ Activa | Badge verde | Esta plantilla se usa actualmente |
| ⏸️ Inactiva | Badge gris | Plantilla guardada pero no en uso |
| 🔒 Sistema | Badge azul | Plantilla predefinida (no editable) |

---

## 🆘 Solución de Problemas

### ❌ Error: "Módulo no disponible"

**Causa**: El módulo no está activado en Firestore

**Solución**:
```bash
cd scripts
node agregar_modulo_plantillas_pdf.js
```

### ❌ Error: "Sin acceso"

**Causa**: Tu usuario no tiene permisos de Propietario/Admin

**Solución**: Contacta al propietario de la empresa para que te asigne el rol

### ❌ No aparece el módulo en el dashboard

**Verificaciones**:
1. Cerrar y reabrir la app
2. Verificar rol en Firebase Console:
   - `usuarios/{uid}/rol` debe ser "propietario" o "admin"
3. Verificar módulo activo:
   - `empresas/{empresaId}/modulos/plantillas_pdf/activo` = `true`

### ❌ PDF no usa plantilla personalizada

**Verificaciones**:
1. La plantilla está **activa** (badge verde)
2. El tipo de documento coincide (factura → factura)
3. Ejecutar `flutter clean && flutter pub get`
4. Recompilar la app

---

## 📱 Capturas de Pantalla (Referencia)

### Vista Principal
```
┌─────────────────────────────────────┐
│  📄 Plantillas PDF           [?] [+]│
├─────────────────────────────────────┤
│                                     │
│  📊 Resumen                         │
│  ┌──────┐ ┌──────┐ ┌──────┐        │
│  │  3   │ │  2   │ │  5   │        │
│  │Total │ │Activas│ │Tipos │        │
│  └──────┘ └──────┘ └──────┘        │
│                                     │
│  🎨 Plantillas por Tipo             │
│  ┌─────────────────────────────┐   │
│  │ 📄 Factura                  │   │
│  │ ✅ Factura Corporativa 2026 │   │
│  │ ⏸️ Factura Minimalista      │   │
│  ├─────────────────────────────┤   │
│  │ 📋 Presupuesto              │   │
│  │ ✅ Presupuesto Pro          │   │
│  └─────────────────────────────┘   │
│                                     │
│  [+ Nueva Plantilla]                │
└─────────────────────────────────────┘
```

---

## 🔐 Seguridad y Permisos

### Firestore Security Rules

Las plantillas están protegidas:

```javascript
match /empresas/{empresaId}/pdf_templates/{templateId} {
  // Solo admin/propietario pueden leer
  allow read: if isAdminOrOwner(empresaId);
  
  // Solo admin/propietario pueden escribir
  allow write: if isAdminOrOwner(empresaId);
}
```

---

## 🎓 Próximos Pasos

1. ✅ **Acceder** al módulo desde el dashboard
2. ✅ **Explorar** plantillas existentes (si hay)
3. ✅ **Crear** tu primera plantilla personalizada
4. ✅ **Activar** la plantilla
5. ✅ **Generar** un PDF de prueba
6. ✅ **Verificar** que use el nuevo diseño

---

## 📞 Soporte

**¿Necesitas ayuda?**

- 📧 Email: soporte@planeag.com
- 💬 Chat en la app (módulo "Web")
- 📚 Documentación: Ver `RESUMEN_CORRECCIONES_PDF.md`

---

## 🔄 Actualizaciones Futuras

### En Desarrollo
- [ ] Editor visual Canva-style
- [ ] Importar/Exportar plantillas
- [ ] Marketplace de plantillas
- [ ] Vista previa 3D del PDF
- [ ] Bloques personalizados (HTML/CSS)

---

*Última actualización: 2026-05-25*  
*Versión: 1.0.0*  
*Estado: ✅ PRODUCCIÓN READY*

