#  Análisis: Perfil del Cliente — Estado actual y mejoras

## ✅ Lo que tiene ahora

| Sección | Descripción |
|---|---|
| **Avatar con inicial** | Círculo con gradiente cian mostrando la primera letra del nombre |
| **Nombre y email** | Datos básicos del usuario autenticado |
| **Información de contacto** | Email, teléfono (si existe), fecha de registro |
| **Mis Reservas** | Lista de las últimas 5 reservas del usuario (collectionGroup) |
| **Programa de Fidelización** | Puntos acumulados por negocio |
| **Cerrar sesión** | Botón con diálogo de confirmación |

---

##  Problemas detectados

- **Sin edición de perfil**: El usuario no puede cambiar nombre, teléfono ni foto.
- **Sin foto de avatar real**: Solo muestra la inicial; no hay opción de subir foto.
- **Favoritos no integrados**: La sección de favoritos no aparece en el perfil.
- **Sin historial completo**: Solo muestra 5 reservas; no hay "ver todas".
- **Sin estadísticas personales**: No sabe cuántas reservas lleva, cuánto ha gastado.
- **Sin preferencias**: No puede configurar notificaciones, idioma, etc.
- **Programa de puntos básico**: No mostrara barra de progreso, recompensas ni canje.

---

##  Mejoras para hacer una plataforma TOP

###  Alta prioridad (impacto directo en conversión)

1. **Edición de perfil completa**
   - Cambiar nombre, teléfono, fecha de nacimiento
   - Subir foto de avatar (Firebase Storage)
   - `pantalla_editar_perfil.dart`

2. **Historial de reservas completo**
   - Paginación o "cargar más"
   - Filtros: pendiente / confirmada / cancelada / pasadas
   - Acción de cancelar desde el historial
   - Valorar negocio tras la visita (⭐1-5 estrellas)

3. **Notificaciones in-app visibles en el perfil**
   - Número de no leídas
   - Acceso directo a `PantallaNotificacionesCliente`

4. **Favoritos en el perfil**
   - Sección rápida "Mis favoritos" con acceso directo

###  Media prioridad (diferenciación)

5. **Gamificación de puntos mejorada**
   - Barra de progreso hacia siguiente nivel (Bronce, Plata, Oro, Platino)
   - Mostrar recompensas disponibles ("Con 500 puntos consigues X")
   - Historial de movimientos de puntos
   - Botón de canje

6. **Tarjeta de cliente digital**
   - QR único del usuario para escanear en el negocio
   - Ver en qué negocios tiene puntos acumulados

7. **Sección "Mis valoraciones"**
   - Ver todas las reseñas que ha dejado
   - Editar o eliminar valoraciones propias

8. **Ajustes y preferencias**
   - Activar/desactivar notificaciones push por tipo
   - Preferencias de categorías favoritas
   - Política de privacidad y términos

###  Baja prioridad (extra)

9. **Referidos**
   - Código de invitación único
   - "Invita a un amigo y gana 50 puntos"

10. **Historial de gasto**
    - Total gastado en la plataforma
    - Por negocio y por mes (gráfico simple)

11. **Método de pago guardado**
    - Integración con Stripe o similar para pagos 1-click

---

##  Mejoras de diseño

- [ ] Avatar editable con cámara/galería (`image_picker`)
- [ ] Animaciones suaves en las secciones (Fade-in, SlideIn)
- [ ] Modo "skeleton/shimmer" mientras carga datos
- [ ] Tarjeta de puntos con diseño premium (gradiente, level badge)
- [ ] Bienvenida personalizada con nombre: "Hola, Juan "
- [ ] Cabecera sticky con foto que colapsa al hacer scroll

---

##  Cambios técnicos necesarios

```dart
// Estructura de datos en Firestore sugerida
// usuarios/{uid}
{
  nombre: String,
  email: String,
  telefono: String?,
  foto_url: String?,          // nuevo
  fecha_nacimiento: Timestamp?, // nuevo
  codigo_referido: String,    // nuevo
  nivel_fidelizacion: String, // 'bronce' | 'plata' | 'oro' | 'platino'
  total_puntos: int,          // campo agregado
  preferencias: {
    notif_reservas: bool,
    notif_promos: bool,
    categorias_favoritas: List<String>,
  }
}

// usuarios/{uid}/favoritos/{negocioId}  → ya implementado ✅
// usuarios/{uid}/notificaciones/{id}    → ya implementado ✅
// usuarios/{uid}/puntos/{empresaId}     → ya existe
```

---

*Generado: 14 mayo 2026 — PlaneaG / FluixCRM*
