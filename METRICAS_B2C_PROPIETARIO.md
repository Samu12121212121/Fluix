# Métricas B2C en Módulo Propietario

**Fecha de implementación:** 2026-05-20  
**Ubicación:** `lib/features/dashboard/widgets/modulo_propietario.dart`

## 📋 Resumen

Se han implementado **7 grupos de métricas B2C** en el módulo de propietario para monitorizar el crecimiento y salud de la plataforma desde la perspectiva de clientes finales.

---

## 📊 Métricas Implementadas

### 1. Usuarios Registrados en App Explorar
**Por qué es importante:** Es la métrica de crecimiento de la red B2C. Sin ella no sabes si la app de clientes está creciendo o muriendo.

**Fuente de datos:**
```dart
db.collection('usuarios').where('rol', isEqualTo: 'clienteFinal')
```

**Métricas mostradas:**
- ✅ **Total usuarios**: Todos los usuarios B2C registrados
- ✅ **Nuevos este mes**: Usuarios creados desde inicio del mes actual
- ✅ **Nuevos esta semana**: Usuarios creados en los últimos 7 días

**Campos requeridos:**
- `rol: String` (debe ser 'clienteFinal')
- `fecha_creacion: Timestamp`

---

### 2. Usuarios Activos (DAU / MAU)
**Por qué es importante:** Registrados ≠ activos. La ratio DAU/MAU te dice si la gente vuelve o solo se registra y desaparece. Una app sana tiene DAU/MAU > 20%.

**Fuente de datos:**
```dart
db.collection('usuarios').where('rol', isEqualTo: 'clienteFinal')
```

**Métricas mostradas:**
- ✅ **DAU (Daily Active Users)**: Usuarios con `ultimo_acceso` < 24h
- ✅ **MAU (Monthly Active Users)**: Usuarios con `ultimo_acceso` < 30 días
- ✅ **Ratio DAU/MAU**: Porcentaje que indica engagement
  - 🟢 Verde si > 20% (engagement excelente)
  - 🟡 Amarillo si ≤ 20% (engagement bajo)

**Campos requeridos:**
- `ultimo_acceso: Timestamp` — **NOTA:** Este campo debe actualizarse cada vez que el usuario abre la app

**🔧 Implementación requerida:**
El campo `ultimo_acceso` debe actualizarse en:
- Inicio de sesión
- Cada vez que la app vuelve del background
- Apertura de la app

---

### 3. Reservas B2C por Día/Semana/Mes
**Por qué es importante:** Es la métrica más importante del negocio. Una reserva B2C significa que tanto el cliente como la empresa están usando la plataforma al mismo tiempo.

**Fuente de datos:**
```dart
db.collectionGroup('reservas').where('origen', isEqualTo: 'app_cliente')
```

**Métricas mostradas:**
- ✅ **Hoy**: Reservas creadas hoy (desde 00:00)
- ✅ **Esta semana**: Reservas de los últimos 7 días
- ✅ **Este mes**: Reservas desde inicio del mes
- ✅ **Ratio conversión**: (Reservas mes / Visitas web mes) × 100

**Campos requeridos:**
- `origen: String` (debe ser 'app_cliente')
- `fecha_creacion: Timestamp` o `fecha_reserva: Timestamp`

**Índice Firestore requerido:**
```
Collection Group: reservas
Fields: origen (Ascending), fecha_creacion (Descending)
```

---

### 4. Ratio de Conversión: Visita → Reserva
**Por qué es importante:** Si tienes tráfico web y reservas, puedes calcular cuántas visitas se convierten en reservas. Si es muy bajo, el problema es el formulario o el negocio. Si es alto, el producto funciona.

**Fuente de datos:**
```dart
// Visitas mensuales
db.collection('empresas')
  .doc(empresaPropietariaId)
  .collection('estadisticas')
  .doc('web_resumen')
  .snapshots()

// Reservas B2C mensuales (calculadas arriba)
```

**Cálculo:**
```dart
ratio = (reservas_b2c_mes / visitas_mes) × 100
```

**Interpretación:**
- **2-5%**: Ratio normal para ecommerce/servicios
- **> 5%**: Excelente conversión
- **< 1%**: Problema en el funnel de conversión

---

### 5. Valoraciones B2C (negocios_publicos)
**Por qué es importante:** El rating promedio de la plataforma es un indicador de calidad del servicio. Si baja, algo está fallando en los negocios que tienes.

**Fuente de datos:**
```dart
db.collectionGroup('valoraciones')
```

**Métricas mostradas:**
- ✅ **Total valoraciones**: Todas las valoraciones de la plataforma
- ✅ **Media de estrellas**: Promedio de todas las valoraciones
  - 🟢 Amarillo/dorado si ≥ 4.0
  - ⚪ Gris si < 4.0
- ✅ **Nuevas esta semana**: Valoraciones de los últimos 7 días

**Campos esperados:**
- `rating: number` o `estrellas: number` (1-5)
- `fecha: Timestamp` o `fecha_creacion: Timestamp`

**Índice Firestore requerido:**
```
Collection Group: valoraciones
Fields: fecha (Ascending)
```

---

### 6. Flash Slots Creados y Tasa de Ocupación
**Por qué es importante:** Si el flash slot es una feature diferenciadora, necesitas saber si se usa. Un slot creado pero no reservado es dinero perdido para el negocio. Una tasa de ocupación alta justifica invertir más en esa feature.

**Fuente de datos:**
```dart
db.collectionGroup('flash_slots')
```

**Métricas mostradas:**
- ✅ **Creados este mes**: Flash slots creados desde inicio del mes
- ✅ **Reservados**: Flash slots con estado reservado/ocupado
- ✅ **Tasa de ocupación**: (Reservados / Creados) × 100
  - 🟢 Verde si > 50%
  - 🟡 Amarillo si ≤ 50%

**Campos esperados:**
- `fecha_creacion: Timestamp`
- `reservado: boolean` o `ocupado: boolean`

---

### 7. Negocios con Reservas Online Activas
**Por qué es importante:** Te dice cuántos de tus negocios B2B están generando valor B2C. Si tienes 50 empresas pero solo 10 reciben reservas online, los otros 40 no están aprovechando la plataforma y son candidatos a churn.

**Fuente de datos:**
```dart
db.collection('negocios_publicos')
```

**Métricas mostradas:**
- ✅ **Con reservas activas**: Negocios con `reservas_online: true`
- ✅ **Sin reservas**: Negocios con `reservas_online: false` o sin el campo
- ✅ **Tasa de activación**: (Con reservas / Total) × 100
- ⚠️ **Alerta**: Si hay negocios sin reservas, muestra warning

**Campos esperados:**
- `reservas_online: boolean` o `permite_reservas: boolean`

---

## 🎨 Diseño UI

Cada métrica está organizada en **tarjetas colapsables** con:
- **Título descriptivo** con emoji
- **3 KPIs por fila** con iconos y colores distintivos
- **Indicadores de salud** (verde/amarillo/rojo según el valor)
- **Tooltips explicativos** cuando el valor es crítico

### Colores utilizados:
- 🔵 Azul: Métricas informativas (usuarios totales, DAU, MAU)
- 🟢 Verde: Métricas positivas (nuevos usuarios, reservas, valoraciones altas)
- 🟡 Amarillo: Warnings (engagement bajo, ocupación baja)
- 🔴 Rojo: No usado (se reserva para errores críticos)
- 🟣 Morado: Métricas especiales (reservas semana/mes)
- 🟠 Naranja: Valoraciones y flash slots

---

## 🔧 Mantenimiento

### Actualización del campo `ultimo_acceso`
Para que DAU/MAU funcione correctamente, necesitas actualizar el campo `ultimo_acceso` en el documento del usuario:

**Ubicación sugerida:**
```dart
// En lib/core/servicios/auth_service.dart o similar

Future<void> registrarAccesoUsuario(String userId) async {
  await FirebaseFirestore.instance
    .collection('usuarios')
    .doc(userId)
    .update({
      'ultimo_acceso': FieldValue.serverTimestamp(),
    });
}
```

**Llamar en:**
1. `initState()` de la pantalla principal de la app B2C
2. Listener de `AppLifecycleState.resumed`
3. Después del login exitoso

---

## 📈 KPIs a Monitorizar

| Métrica | Objetivo | Acción si no se cumple |
|---------|----------|------------------------|
| **Usuarios B2C totales** | Crecimiento 15%+ mensual | Invertir en marketing |
| **Ratio DAU/MAU** | > 20% | Mejorar engagement, push notifications |
| **Reservas B2C mes** | Crecimiento 10%+ mensual | Promocionar feature de reservas |
| **Ratio conversión** | > 2% | Optimizar UX del formulario de reserva |
| **Media valoraciones** | ≥ 4.0 | Auditar negocios con valoraciones bajas |
| **Tasa ocupación flash** | > 50% | Educar negocios en cómo usar flash slots |
| **Tasa activación** | > 80% | Contactar negocios sin reservas online |

---

## 🚀 Próximos Pasos

### Mejoras futuras:
1. **Gráficas históricas**: Mostrar tendencias de los últimos 3-6 meses
2. **Comparativa período anterior**: "↑ 15% vs mes anterior"
3. **Top 10 negocios**: Ranking por reservas B2C
4. **Embudo de conversión**: Visitas → Registros → Reservas
5. **Churn prediction**: Alertas de usuarios inactivos hace >30 días
6. **Push notifications**: Disparar notificaciones si DAU/MAU < 15%

### Índices Firestore a crear:
Si obtienes errores al cargar las métricas, crea estos índices en Firebase Console:

```
1. Collection Group: reservas
   Fields: origen (Ascending), fecha_creacion (Descending)

2. Collection Group: valoraciones
   Fields: fecha (Ascending)

3. Collection Group: flash_slots
   Fields: fecha_creacion (Descending), reservado (Ascending)
```

---

## ✅ Checklist de Verificación

- [x] Modelo de datos actualizado con campos B2C
- [x] Queries Firestore implementadas con try-catch
- [x] UI responsive con colores y emojis
- [x] Indicadores de salud (verde/amarillo)
- [x] Ratio DAU/MAU con tooltip explicativo
- [x] Ratio de conversión calculado desde visitas web
- [x] Documentación completa
- [ ] Campo `ultimo_acceso` implementado en app cliente
- [ ] Índices Firestore creados en producción
- [ ] Testing con datos reales
- [ ] Analytics para tracking de uso del módulo

---

## 📝 Notas Técnicas

**Rendimiento:**
- Las queries usan `collectionGroup` que puede ser lento con millones de documentos
- Se recomienda cachear los resultados en `empresas/{id}/cache/metricas_b2c`
- Considerar actualizar las métricas cada 10-15 minutos en lugar de tiempo real

**Permisos Firestore:**
El usuario debe tener `es_plataforma_admin: true` en su documento de `usuarios` para poder leer estas métricas.

**Límites de Firestore:**
- CollectionGroup queries cuentan como 1 read por documento encontrado
- Si tienes 10,000 reservas B2C, cada carga del módulo = 10,000 reads
- **Solución**: Implementar agregaciones precalculadas

---

## 🐛 Troubleshooting

### Error: "Missing or insufficient permissions"
**Causa:** El usuario no tiene `es_plataforma_admin: true`  
**Solución:** Actualizar el documento del usuario en Firestore

### Error: "Requires an index"
**Causa:** Falta índice compuesto en collectionGroup  
**Solución:** Hacer clic en el link del error para crear el índice automáticamente

### Las métricas muestran 0
**Causa:** No hay datos con el campo `origen: 'app_cliente'` o `rol: 'clienteFinal'`  
**Solución:** Verificar que la app cliente esté guardando estos campos correctamente

### DAU/MAU siempre es 0%
**Causa:** Campo `ultimo_acceso` no existe o no se actualiza  
**Solución:** Implementar la actualización del campo según documentado arriba

---

**Implementado por:** GitHub Copilot  
**Versión:** 1.0.0  
**Última actualización:** 2026-05-20

