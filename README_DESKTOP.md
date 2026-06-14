# ️ FluixCRM Desktop — Guía Rápida

## ⚡ Inicio Rápido

### **Windows**
```cmd
ejecutar_windows.bat
```

### **macOS**
```bash
flutter run -d macos
```

### **Linux**
```bash
flutter run -d linux
```

---

##  Vista Previa

### Móvil
- TabBar horizontal arriba
- Contenido debajo

### Desktop (ancho >800px)
- NavigationRail lateral izquierdo
- Contenido a la derecha
- **Redimensionable**: Se adapta automáticamente

---

## ✅ Lo que Funciona en Desktop

✅ Todas las vistas del dashboard  
✅ Gestión de clientes, reservas, pedidos  
✅ Facturación y contabilidad  
✅ Estadísticas y gráficas  
✅ TPV (excepto impresora BT)  
✅ Perfil y configuración  
✅ Autenticación Firebase  
✅ Firestore en tiempo real  

---

## ⚠️ Lo que NO Funciona

❌ Notificaciones push (solo móvil)  
❌ Impresora Bluetooth del TPV  
❌ Tomar fotos con cámara (pero sí galería)  

---

##  Archivos Clave

- `lib/core/utils/platform_helper.dart` — Detección de plataforma
- `lib/features/dashboard/pantallas/pantalla_dashboard.dart` — UI adaptativa
- `ejecutar_windows.bat` — Script de ejecución Windows
- `build_windows.bat` — Script de compilación Release

---

##  Compilar Release

### Windows
```cmd
build_windows.bat
```
**Salida**: `build\windows\runner\Release\planeag_flutter.exe`

### macOS
```bash
flutter build macos --release
```
**Salida**: `build/macos/Build/Products/Release/planeag_flutter.app`

---

##  Documentación Completa

Ver: `DESKTOP_ADAPTACION_COMPLETA.md`

---

*✨ Disfruta de FluixCRM en tu desktop!*
