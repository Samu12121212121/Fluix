# 📝 CÓMO REGISTRAR NUEVAS EMPRESAS

## ✅ Tu sistema ya soporta múltiples empresas automáticamente

Cada empresa nueva simplemente necesita:

1. ✅ Un documento en Firestore: `empresas/{nuevo_id}`
2. ✅ Sus usuarios vinculados: `usuarios/{uid}` con `empresa_id`
3. ✅ ¡Listo! Automáticamente todo funciona dinámicamente

---

## 🚀 PASO A PASO PARA UNA NUEVA EMPRESA

### PASO 1: Crear la empresa en Firebase Console

1. Ve a: https://console.firebase.google.com
2. Firestore → Crear colección: `empresas`
3. Documento con ID único (ej: `empresa_nueva_001`)
4. Campos:
   ```
   nombre: "Nombre de la empresa"
   dominio: "sudominio.com"
   sitio_web: "sudominio.com"
   fecha_creacion: timestamp
   activa: true
   ```

5. Crear subcollections:
   ```
   estadisticas/web_resumen
   configuracion/general
   ```

### PASO 2: Crear usuario para esa empresa

1. Crear usuario en Firebase Auth
   - Email: usuario@empresa.com
   - Password: ...

2. Crear documento en Firestore:
   ```
   usuarios/{auth_uid}/
   ├─ email: "usuario@empresa.com"
   ├─ empresa_id: "empresa_nueva_001"  ← CLAVE: vincula a su empresa
   ├─ rol: "admin"
   └─ ...otros campos
   ```

### PASO 3: Usuario inicia sesión

- Automáticamente se carga su empresa_id
- Todos los módulos cargan SUS datos
- ¡Funciona dinámicamente! ✅

---

## 🔧 AUTOMATIZAR CON CLOUD FUNCTION

O puedes usar la Cloud Function que ya existe:

```bash
curl -X POST https://europe-west1-planeaapp-4bea4.cloudfunctions.net/crearEmpresaHTTP \
  -H "Content-Type: application/json" \
  -d '{
    "empresaId": "empresa_nueva_001",
    "nombre": "Nueva Empresa",
    "dominio": "nuevaempresa.com"
  }'
```

---

## 💾 ESTRUCTURA FINAL PARA EMPRESA NUEVA

```
empresas/
└─ empresa_nueva_001/
   ├─ nombre: "Nueva Empresa"
   ├─ dominio: "nuevaempresa.com"
   ├─ sitio_web: "nuevaempresa.com"
   ├─ fecha_creacion: 2026-03-13
   ├─ activa: true
   ├─ estadisticas/
   │  ├─ web_resumen
   │  ├─ visitas_2026-03-13
   │  └─ mes_2026-03
   ├─ configuracion/
   │  └─ general
   ├─ valoraciones/
   ├─ reservas/
   ├─ eventos/
   └─ ... (otras colecciones)

usuarios/
└─ {auth_uid}/
   ├─ email: "usuario@nuevaempresa.com"
   ├─ empresa_id: "empresa_nueva_001"  ← Vinculación
   └─ rol: "admin"
```

---

## ✨ DINÁMICO SIGNIFICA:

- ✅ No hay IDs hardcodeados
- ✅ Cada usuario ve datos de SU empresa
- ✅ Todos los módulos cargan dinámicamente
- ✅ Completamente escalable
- ✅ Sin mantenimiento

---

## 🎯 EJEMPLO CON 3 EMPRESAS

### Empresa 1 - Fluixtech
```
empresas/ztZblwm1w71wNQtzHV7S/
usuarios/uid_fluixtech/
  ├─ empresa_id: "ztZblwm1w71wNQtzHV7S"
  └─ ve datos de: empresas/ztZblwm1w71wNQtzHV7S/ ✓
```

### Empresa 2 - Peluquería
```
empresas/peluqueria_001/
usuarios/uid_peluqueria/
  ├─ empresa_id: "peluqueria_001"
  └─ ve datos de: empresas/peluqueria_001/ ✓
```

### Empresa 3 - Restaurante
```
empresas/restaurante_001/
usuarios/uid_restaurante/
  ├─ empresa_id: "restaurante_001"
  └─ ve datos de: empresas/restaurante_001/ ✓
```

**Cada empresa solo ve sus datos.** 🔐

---

## 📋 CHECKLIST PARA NUEVA EMPRESA

- [ ] Crear documento en `empresas/{id}`
- [ ] Llenar campos: nombre, dominio, sitio_web
- [ ] Crear subcollections: estadisticas, configuracion
- [ ] Crear usuario en Firebase Auth
- [ ] Crear documento en `usuarios/{uid}` con empresa_id
- [ ] Usuario inicia sesión
- [ ] ¡Verifica que ve sus datos dinámicamente!

---

## 🚀 RESUMEN

**Tu sistema es completamente multi-empresa y dinámico.**

Para agregar una empresa nueva:
1. Crear en Firebase (2 minutos)
2. Crear usuario vinculado (1 minuto)
3. ¡Listo! Ya funciona (0 minutos)

**Sin cambios de código. Sin hardcodeos. Dinámico 100%.** ✨

