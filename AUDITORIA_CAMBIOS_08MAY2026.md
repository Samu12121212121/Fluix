#  AUDITORÍA DE CAMBIOS — 8 de Mayo 2026

## Resumen Ejecutivo

Se han implementado las siguientes funcionalidades:

1. ✅ **Vista de Usuario (Cliente Final)** en el selector de vistas del propietario
2. ✅ **Gestión de Negocios Públicos** con subida de fotos desde el panel del propietario
3. ✅ **Seed de 40 negocios de Guadalajara** (restaurantes, estéticas, peluquerías, tatuajes)
4. ✅ **Módulo Comandas** añadido al Pack Gestión
5. ✅ **Rol clienteFinal** en el sistema de permisos

---

## 1. Vista de Usuario (Cliente Final)

### Archivos modificados:
- `lib/core/utils/permisos_service.dart`
- `lib/features/dashboard/pantallas/pantalla_dashboard.dart`

### Cambios:
- Añadido el rol `clienteFinal` al enum `RolApp`
- El propietario ahora puede simular cómo ve la app un cliente final (B2C)
- Selector de vistas actualizado con 4 opciones:
  -  Propietario
  - ️ Admin
  -  Staff  
  -  Usuario (Cliente Final)

### Permisos del rol `clienteFinal`:
```dart
case RolApp.clienteFinal:
  // Cliente final: solo puede explorar negocios y ver su perfil
  return ['explorar'];
```

---

## 2. Gestión de Negocios Públicos

### Archivos creados:
- `lib/services/negocios_publicos_service.dart` - Servicio completo para CRUD de negocios
- `lib/features/dashboard/pantallas/gestion_negocios_screen.dart` - Pantalla de gestión

### Archivos modificados:
- `lib/features/dashboard/widgets/modulo_propietario.dart` - Añadida sección de negocios

### Funcionalidades:
- ✅ Listado de todos los negocios públicos con filtros por categoría
- ✅ Búsqueda por nombre/descripción
- ✅ Subida de fotos desde galería (móvil y web)
- ✅ Activar/desactivar negocios
- ✅ Ver detalles en modal
- ✅ Seed automático de negocios de Guadalajara
- ✅ Eliminar todos (para reset)

### Colección Firestore:
```
negocios_publicos/{negocioId}
├── id: string
├── nombre: string
├── categoria: "restaurantes" | "esteticas" | "peluquerias" | "carnicerias" | "tatuajes"
├── fotoUrl: string (opcional)
├── ratingGoogle: number (opcional)
├── descripcion: string (opcional)
├── direccion: string (opcional)
├── telefono: string (opcional)
├── activo: boolean
└── empresaIdVinculada: string (para futuras vinculaciones)
```

### KPIs en el módulo propietario:
- Total de negocios
- Negocios activos
- Negocios sin foto (alerta)

---

## 3. Negocios de Guadalajara (Seed)

### Restaurantes (10):
| Nombre | Rating | Especialidad |
|--------|--------|--------------|
| Restaurante Dama Juana | ⭐ 4.7 | Cocina moderna española, carnes premium |
| Summer | ⭐ 4.1 | Tapas, cenas, copas |
| Botánico | ⭐ 4.5 | Brunch, cocina moderna |
| Casa Palomo | ⭐ 4.6 | Cocina castellana tradicional |
| Biosfera Guadalajara | ⭐ 4.4 | Cocina internacional, sushi |
| Restaurante Dávalos | ⭐ 4.3 | Menú español tradicional |
| Puerta Gayola | ⭐ 4.1 | Tapas, raciones y cañas |
| Ristorante Giovani Fratelli | ⭐ 4.7 | Cocina italiana |
| Restaurante La Duquesa | ⭐ 4.3 | Cocina mediterránea |
| Casa Victoria Restaurante | ⭐ 4.8 | Cocina mediterránea moderna |

### Estéticas (10):
| Nombre | Rating | Especialidad |
|--------|--------|--------------|
| Estética Belén | ⭐ 5.0 | Tratamientos faciales, depilación |
| Beauty by Patricia | ⭐ 4.9 | Uñas, maquillaje |
| IC Belleza Pro | ⭐ 4.8 | Belleza avanzada |
| Aesthetic Center Alba | ⭐ 4.8 | Estética facial y corporal |
| Centro Venus | ⭐ 4.7 | Depilación y faciales |
| Natura Belleza | ⭐ 4.6 | Cosmética natural |
| Beauty Concept | ⭐ 4.7 | Manicura premium |
| Stylo Estética | ⭐ 4.5 | Estética integral |
| Elena Beauty Center | ⭐ 4.6 | Skincare |
| Luxury Beauty Studio | ⭐ 4.7 | Estética avanzada |

### Peluquerías (10):
| Nombre | Rating | Especialidad |
|--------|--------|--------------|
| Alberto hair & beauty | ⭐ 4.8 | Coloración, cortes modernos |
| Aurelia Estilistas | ⭐ 4.9 | Mechas, balayage |
| Vanessa Fernández Peluqueros | ⭐ 4.7 | Color y tratamientos |
| La pelu de Roci | ⭐ 4.9 | Cortes modernos, peinados |
| Peluquería D'Ellas | ⭐ 4.4 | Peluquería femenina |
| Blu Estilistas | ⭐ 4.7 | Coloración de tendencia |
| La Pelu | ⭐ 4.8 | Peluquería personalizada |
| Golden Estilistas | ⭐ 4.8 | Peluquería y estética |
| R & B Peluqueros | ⭐ 4.9 | Estilismo moderno |
| O'S Peluquerias Mario's | ⭐ 4.7 | Cortes, color premium |

### Tatuajes (10):
| Nombre | Rating | Especialidad |
|--------|--------|--------------|
| Studio Madrid Tattoo | ⭐ 5.0 | Realismo, blackwork |
| Studio 8 - Tattoo and Piercing | ⭐ 4.9 | Tatuajes, piercing, fine line |
| La Boheme Tattoo Studio | ⭐ 5.0 | Tatuajes artísticos |
| Estudio Checa | ⭐ 4.8 | Blackwork, lettering |
| La Tinta Mona Tattoo | ⭐ 5.0 | Fine line, minimalista |
| Magistral Tattoo | ⭐ 4.8 | Realismo, color, cover up |
| Ink Brotherhood Tattoo | ⭐ 4.8 | Black & grey |
| Dark Rose Tattoo | ⭐ 4.7 | Neotradicional, color |
| Old Skull Tattoo | ⭐ 4.7 | Old school, lettering |
| Black Moon Tattoo | ⭐ 4.6 | Fine line |

---

## 4. Módulo Comandas (TPV para Bares)

### Archivos modificados:
- `lib/domain/modelos/widget_config.dart`
- `lib/core/config/planes_config.dart`

### Definición del módulo:
```dart
const ModuloConfig(
  id: 'comandas',
  nombre: 'Comandas',
  descripcion: 'Sistema de comandas para bares y restaurantes. '
      'Gestión de mesas, pedidos en cocina/barra, y control de tiempos. '
      'Ideal para hostelería con servicio de mesa.',
  icono: Icons.restaurant_menu,
  activo: false,
  plan: PlanModulo.gestion,
);
```

### Incluido en Pack Gestión:
```dart
static const packGestion = PackConfig(
  id: 'gestion',
  nombre: 'Pack Gestión',
  precioAnual: 370,
  modulosAdicionales: ['facturacion', 'vacaciones', 'tpv', 'fichaje', 'comandas'],
  descripcion: 'Facturación completa, gestión de vacaciones, TPV, fichaje y comandas para hostelería.',
  color: Color(0xFF7B1FA2),
  icono: Icons.workspace_premium,
);
```

### Activación desde Firebase:
Para activar el módulo Comandas en una empresa, añadir al documento:
```
empresas/{empresaId}/suscripcion/actual
{
  "packs_activos": ["gestion"],  // o añadir "comandas" a modulos si es addon separado
  "estado": "ACTIVA"
}
```

---

## 5. Propuesta de Planes TPV

Basado en el módulo TPV + Comandas, aquí hay una propuesta para diseñar planes:

### Plan TPV Básico (Autónomos / Pequeños comercios)
**Precio sugerido: 290€/año**
- ✅ TPV básico (cobros presenciales)
- ✅ Facturación simplificada
- ✅ Control de caja
- ✅ Tickets/recibos
- ❌ Sin comandas
- ❌ Sin gestión de mesas

### Plan TPV Hostelería (Bares / Restaurantes)
**Precio sugerido: 420€/año**
- ✅ Todo lo del TPV Básico
- ✅ **Módulo Comandas**
  - Gestión de mesas
  - Pedidos a cocina/barra
  - Control de tiempos
  - Carta digital
- ✅ División de cuentas
- ✅ Gestión de turnos
- ✅ Estadísticas de ventas por mesa/hora

### Comparativa con Pack Gestión actual:

| Característica | Pack Gestión (370€) | TPV Básico (290€) | TPV Hostelería (420€) |
|----------------|---------------------|-------------------|----------------------|
| TPV | ✅ | ✅ | ✅ |
| Comandas | ✅ | ❌ | ✅ |
| Facturación | ✅ | ✅ Simplificada | ✅ Completa |
| Vacaciones | ✅ | ❌ | ❌ |
| Fichaje | ✅ | ❌ | ❌ |

### Recomendación:
El Pack Gestión actual (370€) ya incluye todo. Para crear planes TPV específicos, considera:
1. **Separar Comandas como add-on** (+80€/año)
2. **Crear Pack TPV Hostelería** que incluya solo TPV + Comandas + Facturación
3. **Mantener Pack Gestión** para negocios que necesitan todo (vacaciones, fichaje, etc.)

---

## 6. Reglas de Firestore Necesarias

Para que funcione correctamente la gestión de negocios públicos:

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Negocios públicos - lectura pública, escritura solo propietario plataforma
    match /negocios_publicos/{negocioId} {
      allow read: if true;
      allow write: if get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.es_plataforma_admin == true;
    }
    
    // Storage para fotos de negocios
    // (configurar en storage.rules)
  }
}
```

```javascript
// storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /negocios_publicos/{negocioId}/{fileName} {
      allow read: if true;
      allow write: if firestore.get(/databases/(default)/documents/usuarios/$(request.auth.uid)).data.es_plataforma_admin == true;
    }
  }
}
```

---

## 7. Próximos Pasos Sugeridos

1. **Implementar pantalla de Comandas** (`lib/features/comandas/`)
   - Visualización de mesas
   - Toma de pedidos
   - Envío a cocina/barra
   - Control de tiempos

2. **Vincular negocios con empresas**
   - Cuando una empresa se registra, vincular su negocio público
   - Permitir que la empresa suba su propia foto

3. **Revisar reglas de Firestore**
   - Asegurar que el propietario puede escribir en `negocios_publicos`

4. **Subir fotos reales a los negocios**
   - Usar la pantalla de gestión para subir fotos de cada negocio

---

## 8. Testing Recomendado

### Verificar Vista de Usuario:
1. Iniciar sesión como propietario
2. Pulsar chip " Usuario"
3. Verificar que solo se muestra el módulo "Explorar"
4. Volver a " Propietario"

### Verificar Gestión de Negocios:
1. Ir a Panel Propietario
2. Sección "Negocios Públicos (B2C)"
3. Pulsar "Gestionar Negocios"
4. Usar menú para "Cargar negocios Guadalajara"
5. Verificar que se cargan 40 negocios
6. Probar subir foto a un negocio

### Verificar Módulo Comandas:
1. En Firebase, añadir `"comandas"` a `packs_activos` de una empresa
2. Verificar que aparece en el catálogo de módulos
3. (Pendiente: implementar la pantalla de comandas)

---

**Fecha de auditoría:** 8 de Mayo de 2026  
**Versión:** 1.0  
**Autor:** Sistema Fluix CRM
