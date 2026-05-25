#  Firestore Security Rules — Flash Slots

Añadir estas reglas al archivo `firestore.rules` existente:

```javascript
// ─── FLASH SLOTS (subcol de negocios_publicos) ───────────────────────────────
match /negocios_publicos/{negocioId}/flash_slots/{slotId} {

  // Cualquier usuario autenticado puede LEER slots activos
  allow read: if request.auth != null;

  // Solo el propietario del negocio (empleado admin de la empresa vinculada) puede crear/actualizar/borrar
  allow create: if request.auth != null
    && _esAdminDeNegocio(negocioId);

  allow update: if request.auth != null
    && (
      // El negocio puede actualizar sus propios slots
      _esAdminDeNegocio(negocioId)
      // O un usuario autenticado puede incrementar huecos_reservados (reservar)
      // Solo permite cambiar huecos_reservados, estado y reservas_ids
      || (request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['huecos_reservados', 'estado', 'reservas_ids'])
         && request.resource.data.huecos_reservados == resource.data.huecos_reservados + 1
         && resource.data.estado == 'activo')
    );

  allow delete: if request.auth != null && _esAdminDeNegocio(negocioId);
}

// ─── COLA DE NOTIFICACIONES FLASH ────────────────────────────────────────────
match /flash_slots_notificaciones/{docId} {
  // Solo el backend (Cloud Functions) procesa esto
  // El cliente puede CREAR pero no leer/actualizar (Cloud Function actualiza)
  allow create: if request.auth != null;
  allow read, update, delete: if false; // Solo Cloud Functions (admin SDK)
}
```

## Función auxiliar necesaria en las reglas:

```javascript
function _esAdminDeNegocio(negocioId) {
  // Obtener el empresaId del negocio y verificar que el usuario es admin
  // Nota: Firestore rules no permiten cross-document reads fácilmente,
  // alternativa: almacenar el uid del propietario en el documento del negocio
  let negocioDoc = get(/databases/$(database)/documents/negocios_publicos/$(negocioId));
  let empresaId  = negocioDoc.data.empresa_id_vinculada;
  return exists(/databases/$(database)/documents/empresas/$(empresaId)/empleados/$(request.auth.uid))
    && get(/databases/$(database)/documents/empresas/$(empresaId)/empleados/$(request.auth.uid)).data.activo == true;
}
```

## Índices necesarios en Firestore (agregar en firestore.indexes.json):

```json
{
  "indexes": [
    {
      "collectionGroup": "flash_slots",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "estado", "order": "ASCENDING" },
        { "fieldPath": "fecha_hora_expiracion", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "flash_slots",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "estado", "order": "ASCENDING" },
        { "fieldPath": "creado_at", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "favoritos",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "negocio_id", "order": "ASCENDING" }
      ]
    }
  ]
}
```

## Resumen de permisos:

| Colección | Cliente | Negocio/Admin | Cloud Functions |
|---|---|---|---|
| `flash_slots` (leer) | ✅ auth | ✅ auth | ✅ admin SDK |
| `flash_slots` (crear) | ❌ | ✅ propietario | ✅ admin SDK |
| `flash_slots` (reservar +=1) | ✅ auth | ✅ | ✅ |
| `flash_slots_notificaciones` | ✅ crear | ✅ crear | ✅ CRUD |

---
*Generado: 14 mayo 2026 — PlaneaG / FluixCRM*
