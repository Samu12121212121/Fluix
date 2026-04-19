# 🔄 MIGRACIÓN A GOOGLE PLACES API (NEW)

## ✅ **ESTADO: COMPLETADA** (19 Abril 2026)

**API Key configurada**: `AIzaSyDFR0Ltn7I1jzDtd_sXV4yZ53DPr63LfNc`

### **Archivos Modificados**
- ✅ `lib/services/google_reviews_service.dart` - Actualizado a nueva API

---

## ✅ **CAMBIOS REALIZADOS**

### **Problema Original**
El código usaba la **API antigua de Google Places**:
- Endpoint: `https://maps.googleapis.com/maps/api/place/details/json`
- API Key como query parameter: `?key=xxx`
- Formato de respuesta con `status` y `result`

### **Solución Implementada**
Actualizado a la **nueva Places API (New)**:
- ✅ Endpoint: `https://places.googleapis.com/v1/places/{placeId}`
- ✅ API Key en header: `X-Goog-Api-Key`
- ✅ Formato de respuesta directo (sin `status`)
- ✅ Campos renombrados según la nueva especificación

---

## 📋 **CAMBIOS EN EL CÓDIGO**

### **1. Endpoint y Headers**

**ANTES (API antigua):**
```dart
final url = 'https://maps.googleapis.com/maps/api/place/details/json'
    '?place_id=$placeId'
    '&fields=name,rating,user_ratings_total,reviews'
    '&key=$apiKey';

final response = await _dio.get(url);
```

**AHORA (API nueva):**
```dart
final url = 'https://places.googleapis.com/v1/places/$placeId';

final response = await _dio.get(
  url,
  options: Options(
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': 'displayName,rating,userRatingCount,reviews',
    },
  ),
  queryParameters: {
    'languageCode': 'es',
  },
);
```

### **2. Mapeo de Campos**

| Campo Antiguo | Campo Nuevo | Notas |
|--------------|-------------|-------|
| `result.rating` | `rating` | Directo en el objeto raíz |
| `result.user_ratings_total` | `userRatingCount` | Renombrado |
| `result.reviews` | `reviews` | Mismo nombre pero estructura diferente |
| `review.author_name` | `review.authorAttribution.displayName` | Ahora anidado |
| `review.profile_photo_url` | `review.authorAttribution.photoUri` | Renombrado |
| `review.author_url` | `review.authorAttribution.uri` | Renombrado |
| `review.text` | `review.text.text` | Ahora anidado con `languageCode` |
| `review.time` | `review.publishTime` | Formato ISO 8601 en lugar de timestamp |
| `review.rating` | `review.rating` | Puede ser decimal (antes solo entero) |
| - | `review.name` | Nuevo: ID único del review |

### **3. Procesamiento de Reseñas**

**ANTES:**
```dart
'cliente': r['author_name'] ?? 'Usuario de Google',
'calificacion': (r['rating'] as num?)?.toInt() ?? 5,
'comentario': r['text'] ?? '',
'fecha': Timestamp.fromMillisecondsSinceEpoch(
    ((r['time'] as int?) ?? 0) * 1000),
'avatar_url': r['profile_photo_url'],
```

**AHORA:**
```dart
final authorAttr = r['authorAttribution'] as Map<String, dynamic>?;
final textObj = r['text'] as Map<String, dynamic>?;
final publishTime = r['publishTime'] as String?;

'cliente': authorAttr?['displayName'] as String? ?? 'Usuario de Google',
'calificacion': (r['rating'] as num?)?.toDouble().round() ?? 5,
'comentario': textObj?['text'] as String? ?? '',
'fecha': Timestamp.fromDate(DateTime.parse(publishTime)),
'avatar_url': authorAttr?['photoUri'] as String? ?? '',
```

---

## ⚙️ **CONFIGURACIÓN NECESARIA**

### **En Google Cloud Console:**

1. **Habilitar la Nueva API:**
   - Ve a: https://console.cloud.google.com/
   - Selecciona tu proyecto
   - Ve a "APIs y servicios" → "Biblioteca"
   - Busca **"Places API (New)"** (no la antigua "Places API")
   - Haz clic en "HABILITAR"

2. **Verificar la API Key:**
   - Ve a "Credenciales"
   - Asegúrate de que tu API Key tiene acceso a "Places API (New)"
   - Si usas restricciones, agrega "Places API (New)" a la lista

3. **Diferencias entre APIs:**
   - ❌ **Places API (antigua)**: Usa `maps.googleapis.com`
   - ✅ **Places API (New)**: Usa `places.googleapis.com`
   - **Importante**: Ambas APIs pueden coexistir, pero la antigua será deprecada

---

## 🧪 **TESTING**

### **1. Compilar y ejecutar:**
```bash
flutter clean
flutter pub get
flutter run
```

### **2. Probar sincronización:**
1. Ve a la pantalla de **Estadísticas**
2. Haz clic en **"Sincronizar con Google"**
3. Verifica en la consola:
```
🔄 Sincronizando Google Places (New API) para empresa xxx...
⭐ Rating Google (New API): 4.7 (632 reseñas) — 5 descargadas
✅ 5 reseñas nuevas acumuladas
```

### **3. Verificar campos:**
- Las reseñas deben tener nombres de autor correctos
- Los avatares deben mostrarse
- Las fechas deben ser correctas
- Los comentarios deben mostrarse completos

---

## 🔧 **SOLUCIÓN DE PROBLEMAS**

### **Error: "API_KEY_INVALID"**
**Causa**: La API Key no tiene acceso a Places API (New)
**Solución**: Ve a Google Cloud Console y habilita "Places API (New)" en tu proyecto

### **Error: "PERMISSION_DENIED"**
**Causa**: La API Key tiene restricciones que bloquean el acceso
**Solución**: Ajusta las restricciones de la API Key para permitir "Places API (New)"

### **Error: 404 Not Found**
**Causa**: El Place ID es incorrecto o no existe
**Solución**: Verifica el Place ID en https://developers.google.com/maps/documentation/places/web-service/place-id

### **Las reseñas no se descargan**
**Posibles causas**:
1. El Place ID no tiene reseñas públicas
2. Las reseñas están deshabilitadas en Google My Business
3. El negocio es muy nuevo y no tiene reseñas aún

---

## 📚 **DOCUMENTACIÓN OFICIAL**

- **Places API (New) Overview**: https://developers.google.com/maps/documentation/places/web-service/op-overview
- **Place Details (New)**: https://developers.google.com/maps/documentation/places/web-service/place-details
- **Migration Guide**: https://developers.google.com/maps/documentation/places/web-service/migrate-to-new
- **Field Mask**: https://developers.google.com/maps/documentation/places/web-service/place-data-fields

---

## ✅ **VENTAJAS DE LA NUEVA API**

1. ✅ **Más eficiente**: Menos datos transferidos usando Field Mask
2. ✅ **Mejor tipado**: Campos más consistentes y predecibles
3. ✅ **Ratings decimales**: Mayor precisión en las calificaciones
4. ✅ **Mejor información del autor**: Datos más completos en `authorAttribution`
5. ✅ **IDs únicos**: Cada review tiene un `name` único para tracking
6. ✅ **Formato estándar**: Usa ISO 8601 para fechas
7. ✅ **Future-proof**: Google mantendrá esta versión activamente

---

## 🚀 **PRÓXIMOS PASOS (OPCIONAL)**

Si quieres aprovechar aún más la nueva API:

1. **Responder a reseñas**: Usa la nueva API para responder directamente desde el CRM
2. **Filtros avanzados**: La nueva API permite filtrar por rating, fecha, etc.
3. **Paginación mejorada**: Mejor soporte para cargar más de 5 reseñas
4. **Business Profile API**: Integración con My Business para gestión completa

---

## 📝 **NOTAS IMPORTANTES**

- ⚠️ La API antigua seguirá funcionando hasta que Google la deprece oficialmente
- ⚠️ Si ya tienes reseñas antiguas en Firestore, seguirán funcionando
- ⚠️ Las nuevas reseñas se guardarán con el formato actualizado
- ✅ El código es compatible hacia atrás (lee ambos formatos)
- ✅ No necesitas migrar datos existentes en Firestore

---

**Fecha de migración**: Abril 2026  
**Versión de Flutter**: 3.x  
**Versión de Dart**: 3.x


