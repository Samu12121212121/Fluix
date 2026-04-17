# 🐛 FIX: Error "no object exist at the desired reference" al subir facturas

## Problema

Al intentar subir imágenes de facturas, la app mostraba el error:
```
no object exist at the desired reference
```

## Causa Raíz

El servicio `fiscal_upload_service.dart` usaba **rutas de Firestore incorrectas**:

### ❌ INCORRECTO (antes):
```dart
_db.collection('empresas/$empresaId/fiscal_documents')  // Firestore lo interpreta literal
_db.doc('empresas/$empresaId/fiscal_documents/$documentId')
```

Firestore interpretaba esto como:
- Colección: `"empresas/$empresaId/fiscal_documents"` (con el $ literal)
- Documento: `"empresas/$empresaId/fiscal_documents/$documentId"` (string completo)

### ✅ CORRECTO (después):
```dart
_db.collection('empresas').doc(empresaId).collection('fiscal_documents')
_db.collection('empresas').doc(empresaId).collection('fiscal_documents').doc(documentId)
```

## Archivos Modificados

| Archivo | Cambios |
|---------|---------|
| `lib/services/fiscal/fiscal_upload_service.dart` | 3 rutas corregidas |

## Cambios Específicos

### 1. Query de verificación de duplicados (línea ~40)
```dart
// ANTES
final existing = await _db
    .collection('empresas/$empresaId/fiscal_documents')
    .where('sha256_hash', isEqualTo: hash)
    .limit(1)
    .get();

// DESPUÉS
final existing = await _db
    .collection('empresas')
    .doc(empresaId)
    .collection('fiscal_documents')
    .where('sha256_hash', isEqualTo: hash)
    .limit(1)
    .get();
```

### 2. Creación del documento fiscal (línea ~85)
```dart
// ANTES
await _db
    .doc('empresas/$empresaId/fiscal_documents/$documentId')
    .set({ ... });

// DESPUÉS
await _db
    .collection('empresas')
    .doc(empresaId)
    .collection('fiscal_documents')
    .doc(documentId)
    .set({ ... });
```

### 3. Stream para watchTransaction (línea ~138)
```dart
// ANTES
return _db
    .doc('empresas/$empresaId/fiscal_transactions/$transactionId')
    .snapshots();

// DESPUÉS
return _db
    .collection('empresas')
    .doc(empresaId)
    .collection('fiscal_transactions')
    .doc(transactionId)
    .snapshots();
```

## Reglas de Firestore (ya estaban correctas)

Las reglas en `firestore.rules` ya usaban la estructura correcta:

```javascript
match /empresas/{empresaId} {
  match /fiscal_documents/{docId} {
    allow read: if esAdminOPropietario(empresaId);
    allow create: if esAdminOPropietario(empresaId)
      && request.resource.data.keys().hasAll(['filename', 'storage_path', 'sha256_hash']);
  }
}
```

## Reglas de Storage (ya estaban correctas)

Las reglas en `storage.rules` permiten subir archivos:

```javascript
// Documentos fiscales subidos por el usuario (facturas recibidas, tickets)
match /empresas/{empresaId}/private/fiscal/{allPaths=**} {
  allow read: if request.auth != null;
  allow write: if request.auth != null
    && request.resource.size < 25 * 1024 * 1024  // max 25MB
    && (request.resource.contentType == 'application/pdf'
        || request.resource.contentType.matches('image/.*'));
}
```

## Estructura de Rutas Correcta

```
empresas/
  └── {empresaId}/
      ├── fiscal_documents/        ← Facturas subidas (metadata)
      │   └── {documentId}
      ├── fiscal_extractions/      ← Datos extraídos por IA
      │   └── {extractionId}
      ├── fiscal_transactions/     ← Transacciones contables
      │   └── {txId}
      └── fiscal_models/           ← Modelos fiscales calculados
          └── {modelId}

Storage:
empresas/
  └── {empresaId}/
      └── private/
          └── fiscal/
              └── documents/       ← Archivos físicos (PDF/imágenes)
                  └── {uuid}.pdf
```

## Testing

Para verificar el fix:

1. **Comprobar reglas Firestore:**
   ```bash
   firebase deploy --only firestore:rules
   ```
   
2. **Comprobar reglas Storage:**
   ```bash
   firebase deploy --only storage
   ```

3. **Probar en la app:**
   - Navegar a módulo Fiscal
   - Capturar/seleccionar una factura
   - Subir → debería funcionar sin error
   - Verificar en Firestore Console:
     ```
     empresas/{id}/fiscal_documents/{docId}
     ```

## Prevención

**Regla mnemotécnica para Firestore en Flutter:**

✅ **Siempre encadenar `.collection()` y `.doc()` alternados:**
```dart
db.collection('nivel1').doc(id1).collection('nivel2').doc(id2)
```

❌ **NUNCA usar interpolación de strings en collection():**
```dart
db.collection('nivel1/$id1/nivel2')  // NO FUNCIONA
```

## Fecha de Fix
17 de abril de 2026

