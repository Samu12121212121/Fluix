# 🛠️ ESTADO DE IDS DE EMPRESA - DOCUMENTACIÓN

## 📊 **Situación Actual (15/04/2026)**

### ✅ **Empresa Principal** (CORRECTO):
```
ID: TUz8GOnQ6OX8ejiov7c5GM9LFPl2
Nombre: DamaJuana
Email: damajuanaguadalajara@gmail.com
Tipo: Restaurante / Bar
Plan: basico
Estado: Activa ✅
```

**Subcolecciones:**
- ✅ `configuracion` - Configuraciones de la app
- ✅ `contenido_web` - Carta, ofertas, etc.
- ✅ `dispositivos` - Dispositivos registrados 
- ✅ `estadisticas` - Analíticas web
- ✅ `suscripcion` - Datos de suscripción

### ❌ **Empresa Duplicada** (PROBLEMA):
```
ID: 7Uz8GOnQ6OX8ejiov7c5M9LFPI2
Nombre: [Sin datos principales]
Estado: Incompleta - Solo fragmentos
```

**Subcolecciones:**
- ⚠️ `configuracion` - Datos parciales
- ⚠️ `contenido_web` - Datos parciales  
- ⚠️ `estadisticas` - Datos parciales

### 📋 **Otras Empresas:**
```
37KyODVYpXYD04VwG3Vf - Empresa adicional
demo_empresa_fluix2026 - Empresa de demostración
```

---

## 🔧 **Archivos Corregidos**

Todos los archivos ahora usan el **ID correcto** `TUz8GOnQ6OX8ejiov7c5GM9LFPl2`:

- ✅ `seed_contenido_web.js` - Script de creación de contenido
- ✅ `sincronizar_carta.html` - Sincronizador de carta
- ✅ `sincronizar_todo.html` - Sincronizador completo
- ✅ `public_web_visor/carta_dama_juana_conectada.html` - Carta conectada
- ✅ `public_web_visor/ejemplo_2secciones.html` - Ejemplo multi-sección
- ✅ `GUIA_SCRIPT_ANALITICAS_WEB.md` - Documentación de analíticas

---

## 🎯 **Próximos Pasos**

### 1. **Ejecutar Script de Verificación**
```bash
node limpiar_empresas_duplicadas.js
```

### 2. **Eliminar Empresa Duplicada** (Manual)
- Ve a **Firebase Console → Firestore**
- Busca `empresas/7Uz8GOnQ6OX8ejiov7c5M9LFPI2`
- **Elimina** el documento completo (incluyendo subcolecciones)

### 3. **Regenerar Contenido Limpio**
```bash
node seed_contenido_web.js
```

### 4. **Probar Webs Conectadas**
- Abrir `public_web_visor/carta_dama_juana_conectada.html`
- Verificar que conecta a la empresa correcta
- Revisar consola del navegador (F12) para confirmar logs

### 5. **Verificar en App Flutter**
- Dashboard → Módulo Web → Ver secciones creadas
- Analytics → Ver datos de tráfico web
- Verificar que todo funciona correctamente

---

## 🚨 **¿Por qué ocurrió esto?**

### **Causa Raíz:**
El ID de empresa se creó originalmente con una **inconsistencia**:
- **ID Real**: `TUz8GOnQ6OX8ejiov7c5GM9LFPl2` (correcto)
- **ID en Código**: `7Uz8GOnQ6OX8ejiov7c5M9LFPI2` (incorrecto)

### **Diferencias:**
1. **Primer carácter**: `T` vs `7`
2. **Carácter antes del final**: `L` vs `I` 
3. **Último grupo**: `LFPl2` vs `LFPI2`

### **Resultado:**
- Los scripts creaban datos en la empresa **incorrecta**
- La empresa **correcta** ya existía con datos reales
- Se generaron **datos duplicados** en dos empresas diferentes

---

## 🔒 **Seguridad y Consistencia**

### **Verificaciones Implementadas:**
- ✅ **Búsqueda exhaustiva** de IDs incorrectos en todo el código
- ✅ **Script de verificación** automática del estado
- ✅ **Documentación clara** del ID correcto
- ✅ **Proceso de limpieza** documentado

### **Prevención Futura:**
1. **Usar constantes** para IDs importantes
2. **Verificación automática** en scripts críticos
3. **Tests de integración** para conexiones Firebase
4. **Documentación actualizada** con IDs correctos

---

## 📞 **Contacto y Soporte**

**Empresa:** DamaJuana  
**Email:** damajuanaguadalajara@gmail.com  
**ID Firebase:** `TUz8GOnQ6OX8ejiov7c5GM9LFPl2`  
**Región:** eur3  
**Última Actualización:** 15/04/2026  

---

## 🔗 **Enlaces Rápidos**

- [Firebase Console](https://console.firebase.google.com/project/planeaapp-4bea4)
- [Guía de Analíticas Web](./GUIA_SCRIPT_ANALITICAS_WEB.md)
- [Script de Contenido Web](./seed_contenido_web.js)
- [Carta Conectada](./public_web_visor/carta_dama_juana_conectada.html)

---

**🎯 Estado:** CORREGIDO ✅  
**📅 Fecha:** 15 de Abril de 2026  
**👤 Responsable:** Equipo de Desarrollo FluxTech
