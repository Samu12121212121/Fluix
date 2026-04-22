# 📋 NOTA: CONFIGURACION FIREBASE PACKAGE NAMES

## 🎯 **Package Names configurados actualmente:**

### **En google-services.json:**
1. ✅ `com.example.planeaa` (original/legacy)
2. ✅ `com.example.planeag_flutter` (desarrollo)  
3. ✅ `com.fluixcrm.app` (producción - ACTIVO)

### **En aplicación Android:**
- **applicationId**: `com.fluixcrm.app`
- **namespace**: `com.fluixcrm.crm`

## 🔥 **Firebase Console - Apps registradas:**

**Para verificar en Firebase Console:**
1. Ir a [Firebase Console](https://console.firebase.google.com)
2. Proyecto: `planeaapp-4bea4`
3. Project Settings → Your apps
4. Verificar que aparezca `com.fluixcrm.app`

## 💡 **Si necesitas agregar nuevo package name:**

### **Paso 1: Firebase Console**
1. Project Settings → Your apps
2. "Add app" → Android
3. Package name: `tu.nuevo.packagename`
4. Download `google-services.json`

### **Paso 2: Actualizar aplicación**
1. Reemplazar `android/app/google-services.json`
2. O agregar nueva entrada client manualmente

## 🚨 **IMPORTANTE:**
- **Producción**: Usar `com.fluixcrm.app`
- **Desarrollo**: Usar `com.example.planeag_flutter` 
- **Legacy**: `com.example.planeaa` (no eliminar)

## 📱 **Verificación final:**
```bash
# Verificar que build funciona
flutter build apk --debug

# Verificar que Firebase se conecta
flutter run
# → Revisar logs de Firebase.initializeApp()
```

## 🍎 **Configuración iOS App Store:**

### **Versiones actuales:**
- **CFBundleShortVersionString**: 1.0.9 (visible al usuario)
- **CFBundleVersion**: 11 (build number - debe incrementarse cada upload)
- **Bundle Identifier**: com.fluixtech.crm
- **iOS Deployment Target**: 15.0

### **Último upload exitoso:**
- **Build Number**: 9 (YA USADO - no volver a usar)
- **Próximo build**: 11 o superior

### **Para nuevos uploads:**
```bash
# Incrementar build number en pubspec.yaml antes de cada upload
version: 1.0.9+12  # Siguiente versión
# Nunca repetir números de build previamente subidos
```

---
**Mantener esta configuración para builds futuros.** 🎉
