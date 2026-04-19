# 🚀 GUÍA PARA SUBIR A GITHUB

## 📋 Opción 1: Usar el Script Automático (Recomendado)

### Paso a Paso:

1. **Doble clic en el archivo**:
   ```
   subir_a_github.bat
   ```

2. **El script hará todo automáticamente**:
   - ✅ Agrega todos los archivos modificados
   - ✅ Crea un commit con descripción completa
   - ✅ Sube los cambios a GitHub

3. **Espera el mensaje**: "COMPLETADO!"

---

## 📋 Opción 2: Comandos Manuales en Terminal

Si prefieres hacerlo manualmente, abre PowerShell o Terminal y ejecuta:

### 1. Verificar estado:
```bash
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter
git status
```

### 2. Agregar todos los archivos:
```bash
git add .
```

### 3. Crear commit:
```bash
git commit -m "fix: Mejoras en modulo de valoraciones - 19 Abril 2026"
```

### 4. Subir a GitHub:
```bash
git push
```

---

## 🔧 Si es la Primera Vez (Configuración Inicial)

### 1. Configurar usuario de Git:
```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu@email.com"
```

### 2. Si NO tienes repositorio remoto configurado:
```bash
git remote add origin https://github.com/TU_USUARIO/planeag_flutter.git
```

### 3. Primera subida:
```bash
git push -u origin main
```
(O `master` si tu rama principal se llama así)

---

## ❌ Solución de Problemas Comunes

### Error: "No tienes permisos"
**Solución**: Configura autenticación con token de GitHub

1. Ve a GitHub → Settings → Developer settings → Personal access tokens
2. Genera un nuevo token (classic)
3. Copia el token
4. Usa en lugar de contraseña al hacer push

### Error: "No git repository"
**Solución**: Inicializa el repositorio
```bash
git init
git remote add origin https://github.com/TU_USUARIO/planeag_flutter.git
```

### Error: "Divergent branches"
**Solución**: Pull primero
```bash
git pull origin main --rebase
git push
```

### Error: "Authentication failed"
**Solución**: Usa token en lugar de contraseña
```bash
# Cuando pida contraseña, pega tu token de GitHub
```

---

## 📊 Archivos que se Subirán Hoy

### Archivos Modificados:
1. ✅ `lib/services/google_reviews_service.dart`
   - Migrado a Places API (New)
   - Límite cambiado a 20 valoraciones

2. ✅ `lib/features/dashboard/widgets/modulo_valoraciones.dart`
   - Scroll arreglado
   - Botón "Responder en Google" añadido
   - Método _responder() eliminado

3. ✅ `lib/features/dashboard/widgets/tarjetas_resumen.dart`
   - Migrado a datos reales con StreamBuilder

4. ✅ `lib/features/dashboard/widgets/widgets_adicionales.dart`
   - WidgetKpisRapidos: datos reales
   - WidgetReservasHoy: datos reales
   - WidgetValoracionesRecientes: datos reales

### Archivos Nuevos (Documentación):
1. ✅ `CONFIGURACION_GOOGLE_API.md`
2. ✅ `RESUMEN_MIGRACION_COMPLETADA.md`
3. ✅ `RESUMEN_FINAL_WIDGETS.md`
4. ✅ `ESTADO_WIDGETS_DASHBOARD.md`
5. ✅ `CORRECCIONES_VALORACIONES_RESERVAS.md`
6. ✅ `FUNCIONAMIENTO_VALORACIONES_COMPLETO.md`
7. ✅ `CAMBIO_BOTON_RESPONDER_GOOGLE.md`
8. ✅ `GUIA_SUBIR_GITHUB.md` (este archivo)
9. ✅ `subir_a_github.bat`

---

## 📝 Mensaje del Commit

El commit incluirá este mensaje descriptivo:

```
fix: Mejoras en modulo de valoraciones - 19 Abril 2026

- Arreglado scroll en modulo de valoraciones (AlwaysScrollableScrollPhysics)
- Cambiado boton Responder por Responder en Google (abre Google Business)
- Actualizado Google Reviews Service a Places API (New)
- Migrado TarjetasResumen a datos reales desde Firestore
- Eliminados datos demo de KPIs y Reservas
- Actualizado limite de valoraciones de 50 a 20
- Mejorada funcion de responder con validacion y feedback
- Widgets ahora usan StreamBuilder para tiempo real
```

---

## 🎯 Verificación Post-Subida

Después de subir, verifica en GitHub:

1. Ve a tu repositorio en GitHub
2. Verifica que aparezca el commit nuevo
3. Revisa que los archivos estén actualizados
4. Comprueba la fecha del último commit

---

## 🔐 Seguridad

### Archivos que NO se subirán (están en .gitignore):

- ✅ `credentials.json` (credenciales de Google)
- ✅ `fluix_release.jks` (keystore de Android)
- ✅ Archivos de compilación (`build/`, `.dart_tool/`)
- ✅ Archivos locales (`.vscode/`, `.idea/`)

**IMPORTANTE**: El archivo `.gitignore` protege tus credenciales automáticamente.

---

## 📱 Desde Android Studio

### Opción Visual:

1. **VCS → Commit** (o Ctrl+K)
2. **Marca todos los archivos** que quieres subir
3. **Escribe mensaje de commit**:
   ```
   fix: Mejoras en modulo de valoraciones - 19 Abril 2026
   ```
4. **Commit and Push**
5. **Push** en el diálogo que aparece

---

## ✅ Checklist Antes de Subir

- [ ] Archivos modificados revisados
- [ ] Sin errores de compilación
- [ ] Credenciales NO incluidas
- [ ] Mensaje de commit descriptivo
- [ ] Tests pasados (si aplica)

---

## 🚀 Resumen Rápido

### Si Todo Está OK:

```bash
# Opción A: Doble clic
subir_a_github.bat

# Opción B: Terminal
git add .
git commit -m "fix: Mejoras en modulo de valoraciones - 19 Abril 2026"
git push
```

### Si es Primera Vez:

```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu@email.com"
git remote add origin https://github.com/TU_USUARIO/planeag_flutter.git
git push -u origin main
```

---

## 📞 Ayuda Adicional

### Ver historial de commits:
```bash
git log --oneline -10
```

### Ver archivos modificados:
```bash
git status
```

### Ver diferencias:
```bash
git diff
```

### Deshacer último commit (sin perder cambios):
```bash
git reset --soft HEAD~1
```

---

**Fecha**: 19 Abril 2026  
**Total de archivos**: 4 modificados + 9 nuevos (documentación)  
**Estado**: ✅ Listo para subir

**¡Solo ejecuta `subir_a_github.bat` y listo!** 🎉

