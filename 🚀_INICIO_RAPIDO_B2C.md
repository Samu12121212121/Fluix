# 🚀 INICIO RÁPIDO - Sistema B2C Implementado

## ✅ TODO ESTÁ LISTO - Solo 3 Pasos

```
┌─────────────────────────────────────────────────────────────┐
│  PASO 1: Configura las Reglas de Firestore (5 min)         │
└─────────────────────────────────────────────────────────────┘
```

### Opción A - Automático:
```bash
firebase deploy --only firestore:rules
```

### Opción B - Manual:
1. Abre Firebase Console → Firestore Database → Reglas
2. Copia el contenido de `firestore_rules_b2c.rules`
3. Pega y Publica

📖 **Guía completa:** `INSTRUCCIONES_REGLAS_FIRESTORE.md`

---

```
┌─────────────────────────────────────────────────────────────┐
│  PASO 2: Agrega Negocios de Prueba (2 min)                 │
└─────────────────────────────────────────────────────────────┘
```

### Método Rápido:
1. Abre `lib\scripts\seed_negocios_prueba.dart`
2. Cambia `EMPRESA_ID_VINCULADA` por tu ID de empresa real
3. Ejecuta: **doble clic en** `ejecutar_seed_negocios.bat`

### Método Manual (Firebase Console):
1. Abre Firebase Console → Firestore Database
2. Crea colección `negocios_publicos`
3. Añade documento con estos campos:
   ```json
   {
     "nombre": "Mi Negocio",
     "categoria": "restaurantes",
     "empresaIdVinculada": "TU_EMPRESA_ID",
     "activo": true,
     "descripcion": "Descripción del negocio",
     "direccion": "Calle Mayor 1",
     "telefono": "+34 600000000",
     "ratingGoogle": 4.5
   }
   ```

💡 **Categorías disponibles:** restaurantes, peluquerias, esteticas, carnicerias, tatuajes

---

```
┌─────────────────────────────────────────────────────────────┐
│  PASO 3: Ejecuta y Prueba (1 min)                          │
└─────────────────────────────────────────────────────────────┘
```

### Para Windows:
```bash
flutter run -d windows
```

### Para Android:
```bash
flutter run -d android
```

### Para iOS:
```bash
flutter run -d ios
```

---

## 🎯 FLUJO DE PRUEBA

```
┌────────────────────────────────────────────────────────────────┐
│  1. PANTALLA LOGIN                                             │
│     └─→ Haz clic en "Registrarse como usuario" (botón verde)  │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│  2. REGISTRO CLIENTE                                            │
│     └─→ Completa: Nombre, Email, Teléfono, Contraseña         │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│  3. PANTALLA EXPLORAR (Estilo Booksy)                         │
│     ├─→ Usa los chips de arriba para filtrar por categoría    │
│     ├─→ Busca negocios con la barra de búsqueda               │
│     └─→ Toca cualquier tarjeta para ver detalle               │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│  4. DETALLE DE NEGOCIO                                         │
│     ├─→ Ve información completa                               │
│     ├─→ Check rating de Google                                │
│     └─→ Completa formulario de reserva                        │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│  5. CONFIRMACIÓN                                               │
│     └─→ ¡Reserva creada! Aparece en "Mis Reservas"           │
└────────────────────────────────────────────────────────────────┘
```

---

## 📱 PANTALLAS IMPLEMENTADAS

| Pantalla | Descripción | Estado |
|----------|-------------|--------|
| 🔐 Login | Botón "Registrarse como usuario" | ✅ |
| 📝 Registro | Formulario simple (nombre, email, teléfono) | ✅ |
| 🏠 Explorar | Filtros + Búsqueda + Tarjetas | ✅ |
| 📋 Detalle | Info completa + Formulario reserva | ✅ |
| 👤 Perfil | Datos + Historial + Puntos | ✅ |

---

## 🔧 TIPOS DE FORMULARIOS

### 💇 Peluquerías/Estéticas:
- Selecciona empleado
- Selecciona servicio (con precio)
- Fecha y hora

### 🍽️ Restaurantes:
- Fecha y hora
- Interior o exterior
- Número de personas (1-20)

### 🏪 Otros Negocios:
- Fecha y hora
- Notas opcionales

---

## 🎨 CATEGORÍAS DISPONIBLES

```
🍽️ Restaurantes      💅 Estéticas       💇 Peluquerías
🥩 Carnicerías       🎨 Tatuajes
```

---

## 📂 ARCHIVOS IMPORTANTES

```
SISTEMA_B2C_IMPLEMENTADO.md           ← Documentación completa
INSTRUCCIONES_REGLAS_FIRESTORE.md     ← Guía de reglas de seguridad
ejecutar_seed_negocios.bat            ← Script para agregar datos de prueba
lib/scripts/seed_negocios_prueba.dart ← Datos de prueba (9 negocios)
firestore_rules_b2c.rules             ← Reglas de Firestore
```

---

## 🆘 PROBLEMAS COMUNES

### ❌ "No se encontraron negocios"
**Solución:** Ejecuta `ejecutar_seed_negocios.bat` (no olvides cambiar EMPRESA_ID)

### ❌ "Permission denied" al crear reserva
**Solución:** Aplica las reglas de Firestore (Paso 1)

### ❌ "No aparecen empleados/servicios"
**Solución:** Verifica que tu empresa tiene empleados y servicios creados y con `activo: true`

### ❌ Los usuarios empresa ven la UI de cliente
**Solución:** Verifica que el campo `role` en Firestore sea correcto:
- `clienteFinal` → UI de explorar
- `companyAdmin`, `companyManager`, `normalUser` → UI de dashboard

---

## 📊 PRÓXIMOS PASOS (Opcional)

Una vez que el sistema funciona básico:

1. **[ ]** Añadir fotos reales a los negocios (Firebase Storage)
2. **[ ]** Configurar Google My Business API para ratings reales
3. **[ ]** Implementar panel de gestión en UI empresa
4. **[ ]** Activar sistema de fidelización completo
5. **[ ]** Agregar notificaciones push

📖 Ver `SISTEMA_B2C_IMPLEMENTADO.md` para más detalles

---

## ✨ LO QUE TIENES AHORA

✅ Sistema de registro de usuarios finales
✅ Exploración de negocios por categorías
✅ Búsqueda de negocios
✅ Formularios de reserva especializados
✅ Perfil de usuario con historial
✅ Diferenciación automática usuario empresa/cliente
✅ Integración con sistema existente de empresas
✅ Listo para producción (con reglas de seguridad)

---

## 🎉 ¡LISTO!

**Tiempo total de configuración: ~10 minutos**

1. ⚡ Reglas Firestore → 5 min
2. ⚡ Datos de prueba → 2 min
3. ⚡ Ejecutar app → 1 min
4. ⚡ Registrarse y probar → 2 min

**¿Dudas?** Revisa `SISTEMA_B2C_IMPLEMENTADO.md` o pregunta.

---

**🚀 Desarrollado con GitHub Copilot**
**📅 Mayo 2026**
**✅ v1.0 - MVP Funcional**

