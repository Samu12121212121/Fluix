# 🔑 CONFIGURACIÓN DE GOOGLE PLACES API

## API Key Proporcionada

```
AIzaSyDFR0Ltn7I1jzDtd_sXV4yZ53DPr63LfNc
```

## ✅ Pasos de Configuración

### 1. Habilitar Places API (New) en Google Cloud Console

1. Ve a: https://console.cloud.google.com/
2. Selecciona tu proyecto
3. Ve a **"APIs y servicios"** → **"Biblioteca"**
4. Busca **"Places API (New)"**
5. Haz clic en **"HABILITAR"**

### 2. Verificar Permisos de la API Key

1. Ve a **"Credenciales"** en Google Cloud Console
2. Encuentra tu API Key: `AIzaSyDFR0Ltn7I1jzDtd_sXV4yZ53DPr63LfNc`
3. Asegúrate de que tiene acceso a **"Places API (New)"**
4. Si usas restricciones:
   - **Opción 1**: Restricción por IP (recomendado para testing)
   - **Opción 2**: Sin restricción (solo para desarrollo)
   - ⚠️ **NO usar restricción de app Android** para la API de Places (evita errores REQUEST_DENIED)

### 3. Configurar en la App

Hay dos formas de configurar la API Key:

#### Opción A: Por Empresa (Multiempresa) ✅ Recomendado

Cada empresa configura su propia API Key y Place ID:

1. Ve a la app y abre **Estadísticas** → **Configurar Google Reviews**
2. Ingresa:
   - **API Key**: `AIzaSyDFR0Ltn7I1jzDtd_sXV4yZ53DPr63LfNc`
   - **Place ID**: El Place ID de tu negocio (ej: `ChIJ...`)
3. Haz clic en **Guardar**
4. Haz clic en **Probar Conexión**

#### Opción B: Global (Desarrollo)

Para pruebas, puedes usar la API Key directamente en el código (no recomendado para producción).

### 4. Obtener el Place ID de tu Negocio

Hay varias formas de obtener el Place ID:

**Método 1: Place ID Finder**
- Ve a: https://developers.google.com/maps/documentation/javascript/examples/places-placeid-finder
- Busca tu negocio
- Copia el Place ID (formato: `ChIJ...`)

**Método 2: Google Maps**
- Busca tu negocio en Google Maps
- Copia la URL
- El Place ID está en el parámetro `place_id=...`

**Método 3: Places API**
- Usa el endpoint de Text Search:
  ```
  https://places.googleapis.com/v1/places:searchText
  ```
- Envía una búsqueda con el nombre de tu negocio
- Extrae el `name` del resultado (formato: `places/{placeId}`)

### 5. Probar la Integración

```bash
flutter clean
flutter pub get
flutter run
```

Luego en la app:
1. Ve a **Estadísticas**
2. Haz clic en **"Sincronizar con Google"**
3. Verifica la consola:
   ```
   🔄 Sincronizando Google Places (New API) para empresa xxx...
   ⭐ Rating Google (New API): 4.7 (632 reseñas) — 5 descargadas
   ✅ 5 reseñas nuevas acumuladas
   ```

## 🔧 Solución de Problemas

### Error: "API_KEY_INVALID"
**Causa**: La API Key no tiene acceso a Places API (New)  
**Solución**: Ve a Google Cloud Console y habilita "Places API (New)"

### Error: "PERMISSION_DENIED" o "REQUEST_DENIED"
**Causa**: La API Key tiene restricciones que bloquean el acceso  
**Solución**: 
1. Ve a Google Cloud Console → Credenciales
2. Edita la API Key
3. En "Restricciones de la aplicación":
   - Si usas restricción de Android: **cámbiala temporalmente a "Ninguna"** para probar
   - Si la sincronización funciona, el problema es la restricción
4. En "Restricciones de API":
   - Asegúrate de que "Places API (New)" está en la lista

### Error: 404 Not Found
**Causa**: El Place ID es incorrecto o no existe  
**Solución**: Verifica el Place ID usando el Place ID Finder

### Las reseñas no se descargan
**Posibles causas**:
1. El Place ID no tiene reseñas públicas
2. Las reseñas están deshabilitadas en Google My Business
3. El negocio es muy nuevo y no tiene reseñas aún
4. La API solo devuelve máximo 5 reseñas (limitación de Google)

## 📋 Checklist de Verificación

- [ ] Places API (New) está habilitada en Google Cloud Console
- [ ] API Key tiene permisos para Places API (New)
- [ ] API Key NO tiene restricción de app Android (o está en "Ninguna")
- [ ] Place ID es correcto (formato `ChIJ...`)
- [ ] Se puede sincronizar desde la app sin errores
- [ ] Se descargan reseñas (si el negocio tiene reseñas públicas)
- [ ] El rating global se muestra correctamente

## 🚀 Migración Completada

✅ El código ha sido migrado a la nueva Places API (New)  
✅ Usa el endpoint: `https://places.googleapis.com/v1/places/{placeId}`  
✅ API Key en header `X-Goog-Api-Key`  
✅ Campos actualizados: `userRatingCount`, `authorAttribution`, `publishTime`

## 📚 Referencias

- **Places API (New) Overview**: https://developers.google.com/maps/documentation/places/web-service/op-overview
- **Place Details**: https://developers.google.com/maps/documentation/places/web-service/place-details
- **Migration Guide**: https://developers.google.com/maps/documentation/places/web-service/migrate-to-new
- **Place ID Finder**: https://developers.google.com/maps/documentation/javascript/examples/places-placeid-finder

---

**Fecha**: Abril 2026  
**API Key**: `AIzaSyDFR0Ltn7I1jzDtd_sXV4yZ53DPr63LfNc`  
**Estado**: ✅ Configurada y lista para usar

