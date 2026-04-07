## PASOS PARA ACTIVAR EL MÓDULO GMB EN PRODUCCIÓN

### 1. Instalar dependencia (desde la carpeta functions/)
```bash
cd functions
npm install @google-cloud/secret-manager --save
```

### 2. Configurar variables en functions/.env
```
GOOGLE_OAUTH_CLIENT_ID=TU_CLIENT_ID_AQUI.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=TU_CLIENT_SECRET_AQUI
```

### 3. Habilitar APIs en Google Cloud Console
- Secret Manager API: https://console.cloud.google.com/apis/library/secretmanager.googleapis.com
- My Business Account Management API
- My Business Business Information API
- My Business Reviews API

### 4. Dar permisos a la service account de Functions
En IAM, asignar rol "Secret Manager Admin" a:
  service-PROJECT_NUMBER@gcf-admin-robot.iam.gserviceaccount.com

### 5. Añadir índice en Firestore para cola de respuestas pendientes
En firestore.indexes.json añadir (collectionGroup):
```json
{
  "collectionGroup": "respuestas_pendientes",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "proximo_intento", "order": "ASCENDING" },
    { "fieldPath": "intentos", "order": "ASCENDING" }
  ]
}
```

### 6. Deploy de functions
```bash
firebase deploy --only functions
```

### 7. Verificar el google_sign_in en Android
En android/app/build.gradle verificar que el SHA-1 del keystore está en Firebase Console.
El serverAuthCode requiere que el clientId WEB (no Android) esté configurado en google_sign_in.

En AndroidManifest.xml verificar:
```xml
<meta-data android:name="com.google.android.gms.version" 
  android:value="@integer/google_play_services_version"/>
```

