# 🪟 GUÍA DE COMPILACIÓN WINDOWS

**Fecha:** 7 de mayo de 2026  
**Versión:** 1.0.15  
**Estado:** ✅ Funcional

---

## 📋 REQUISITOS

### Software necesario
- ✅ Flutter SDK 3.11.1 o superior
- ✅ Visual Studio 2022 o 2019 con "Desktop development with C++"
- ✅ CMake 3.10 o superior
- ✅ Git

### Verificar instalación
```powershell
flutter doctor -v
cmake --version
```

---

## 🚀 COMPILACIÓN RÁPIDA

### Opción 1: Script automático (RECOMENDADO)
```powershell
# Doble clic en:
continuar_build_windows.bat
```

### Opción 2: Comando manual
```powershell
flutter build windows --release
```

---

## ⚠️ ERRORES COMUNES

### Error: "cmake_minimum_required: Compatibility with CMake < 3.5"

**Síntoma:**
```
CMake Error at build/windows/x64/extracted/firebase_cpp_sdk_windows/CMakeLists.txt:17
Compatibility with CMake < 3.5 has been removed
```

**Solución:**
```powershell
# Ejecutar el script de reparación:
fix_cmake_firebase.bat
```

O manualmente:
```powershell
flutter clean
Remove-Item -Path "build\windows" -Recurse -Force
flutter pub get
flutter build windows --release
```

---

### Error: "ZIP decompression failed (-5)"

**Síntoma:**
```
cmake -E tar: error: ZIP decompression failed (-5)
```

**Causa:** Descarga corrupta del Firebase C++ SDK

**Solución:**
```powershell
flutter clean
Remove-Item -Path "build\windows" -Recurse -Force
flutter build windows --release
```

---

### Error: Visual Studio no encontrado

**Síntoma:**
```
Visual Studio not found
```

**Solución:**
1. Instalar Visual Studio 2022: https://visualstudio.microsoft.com/
2. Durante la instalación, seleccionar: **"Desktop development with C++"**
3. Reiniciar el terminal
4. Ejecutar: `flutter doctor -v`

---

## 📁 UBICACIÓN DEL EJECUTABLE

Después de compilar exitosamente:

```
build\windows\x64\runner\Release\planeag_flutter.exe
```

### Ejecutar en modo DEBUG
```powershell
flutter run -d windows
```

### Ejecutar el ejecutable directamente
```powershell
cd build\windows\x64\runner\Release
.\planeag_flutter.exe
```

---

## 🔧 SCRIPTS DISPONIBLES

### `continuar_build_windows.bat`
- **Uso:** Continuar una compilación interrumpida
- **Qué hace:** Parchea CMakeLists.txt si es necesario y continúa la compilación

### `fix_cmake_firebase.bat`
- **Uso:** Resolver problemas persistentes de CMake
- **Qué hace:** Limpia todo el build y recompila desde cero

### `ejecutar_windows_admin.ps1`
- **Uso:** Ejecutar la app en modo administrador
- **Qué hace:** Verifica permisos y ejecuta el ejecutable

### `build_windows.bat`
- **Uso:** Compilación completa desde cero
- **Qué hace:** `flutter clean` + `flutter build windows --release`

---

## 🐛 DEBUGGING

### Ver logs en tiempo real
```powershell
flutter run -d windows --verbose
```

### Limpiar caché de Flutter
```powershell
flutter clean
flutter pub cache clean
flutter pub get
```

### Ver información del sistema
```powershell
flutter doctor -v
flutter config --list
```

---

## 📊 TIEMPOS DE COMPILACIÓN

| Tipo | Tiempo estimado |
|------|----------------|
| Primera compilación | 8-15 minutos |
| Compilación incremental | 2-5 minutos |
| Hot reload (debug) | 1-3 segundos |

---

## 🎯 CHECKLIST DE COMPILACIÓN EXITOSA

- [ ] `flutter doctor -v` no muestra errores críticos
- [ ] CMake versión 3.10 o superior instalado
- [ ] Visual Studio con "Desktop development with C++" instalado
- [ ] El ejecutable se genera en `build\windows\x64\runner\Release\`
- [ ] La app inicia sin errores al ejecutar `flutter run -d windows`

---

## 📝 NOTAS

### Firebase en Windows
- La primera compilación descarga el Firebase C++ SDK (~200 MB)
- Si hay errores de CMake, se parchea automáticamente con los scripts
- El SDK queda cacheado en `build\windows\x64\extracted\`

### Tamaño del ejecutable
- **Debug:** ~150 MB
- **Release:** ~80 MB

### Rendimiento
- Windows nativo es más rápido que la versión web
- Hot reload funciona sin problemas en modo debug

---

## 🆘 AYUDA

Si ninguna solución funciona:

1. Elimina completamente la carpeta `build\`
2. Ejecuta `flutter doctor -v` y resuelve todos los warnings
3. Actualiza Flutter: `flutter upgrade`
4. Reinstala las dependencias: `flutter pub get`
5. Intenta compilar de nuevo: `flutter build windows --release`

Si el problema persiste, revisa:
- Firewall de Windows (puede bloquear descargas)
- Antivirus (puede bloquear CMake)
- Espacio en disco (necesitas ~5 GB libres)

---

**Última actualización:** 7 de mayo de 2026  
**Autor:** Claude Code

