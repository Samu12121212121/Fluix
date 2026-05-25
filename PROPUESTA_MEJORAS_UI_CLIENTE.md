# 🎨 Propuesta de Mejoras UI - Diferenciación de Booksy

> **Fecha:** 13 Mayo 2026  
> **Objetivo:** Diferenciar PlaneaG/Fluix de Booksy y mejorar experiencia del usuario final

---

## 📊 Análisis de Situación Actual

### ❌ Problemas Identificados

1. **Similaridad con Booksy**: La interfaz actual se parece demasiado a Booksy
2. **Carruseles limitados**: Las secciones de "Ofertas especiales", "Recomendados", "Cerca de ti" muestran pocos items (máx 8-10)
3. **Botón "Ver todo" no funcional**: No hace nada al pulsarlo
4. **Falta de personalización**: Los negocios no pueden configurar qué se muestra al cliente

---

## 🎯 Propuestas de Diferenciación

### 1. **Sistema de Categorías Visuales Mejorado con Tags**

#### ¿Por qué?
Booksy tiene categorías simples. Nosotros podemos tener un sistema de filtros múltiples y visuales.

#### ¿Qué añadir?
```
📱 Diseño propuesto:

┌─────────────────────────────────────────────────────┐
│  [Todo] [Restaurantes🍽️] [Estética💅] [Tatuajes🎨] │
│  ↓                                                   │
│  SUB-FILTROS (chips animados):                      │
│  • Precio: [€] [€€] [€€€]                           │
│  • Disponibilidad: [Hoy] [Esta semana] [Flexible]  │
│  • Rating: [⭐4+] [⭐4.5+]                          │
│  • Distancia: [<1km] [<5km] [<10km]                │
│  • Servicios: [WiFi] [Parking] [Terraza]           │
└─────────────────────────────────────────────────────┘
```

**Ventaja vs Booksy**: Filtrado más rico e interactivo.

---

### 2. **Sección "Eventos y Promociones Activas"**

#### ¿Por qué?
Diferenciar con contenido dinámico que Booksy no prioriza.

#### ¿Qué añadir?
```
🎉 EVENTOS Y PROMOCIONES (nuevo carrusel)

Tarjetas grandes horizontales con:
┌──────────────────────────────────────┐
│  [FOTO DEL EVENTO/PROMO]             │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  🎊 "Martes de Manicura"             │
│  20% OFF en manicuras - Solo hoy     │
│  📍 Salón Bella - Centro             │
│  ⏰ Termina en: 3h 24m                │
│  [RESERVAR AHORA →]                  │
└──────────────────────────────────────┘

Características:
• Contador regresivo (urgencia)
• Badge de "ÚLTIMA HORA" / "MUY POPULAR"
• Click → Reserva directa con descuento aplicado
```

**Ventaja vs Booksy**: Gamificación y urgencia. Incrementa conversión.

---

### 3. **"Mapa de Negocios Interactivo" (Vista alternativa)**

#### ¿Por qué?
Booksy tiene mapa pero NO es su vista principal. Diferenciarnos con vista híbrida.

#### ¿Qué añadir?
```
🗺️ VISTA MAPA (botón toggle en appbar):

┌───────────────────────────────────────┐
│  [Lista 📄] [Mapa 🗺️] ← toggle       │
│                                        │
│  Mapa con pins agrupados por zona:    │
│  • Pin común → un negocio              │
│  • Pin agrupado (número) → varios     │
│  • Al hacer zoom → se expande          │
│                                        │
│  Tap en pin → Mini-card flotante:     │
│  ┌──────────────────────────┐         │
│  │ [Foto] Nombre            │         │
│  │ ⭐ 4.8 · €€ · 2.3 km    │         │
│  │ [Ver detalles →]         │         │
│  └──────────────────────────┘         │
└───────────────────────────────────────┘
```

**Ventaja vs Booksy**: Vista inmersión espacial. Mejor para usuarios explorando zona nueva.

---

### 4. **Sección "Descubre Tu Estilo" (Recomendaciones IA)**

#### ¿Por qué?
Personalización basada en historial y preferencias.

#### ¿Qué añadir?
```
✨ DESCUBRE TU ESTILO (después de 2-3 reservas)

┌──────────────────────────────────────────────────────┐
│  🎯 "Basado en tu historial de estética..."          │
│                                                       │
│  Carrusel con negocios similares:                    │
│  • Si reservó en salón estilo moderno → Mostrar +    │
│  • Si valoró 5⭐ servicio rápido → Priorizar eso     │
│  • Si siempre reserva sábados 10am → Sugerir eso     │
│                                                       │
│  Badge: "95% Match con tu estilo" 🎯                 │
└──────────────────────────────────────────────────────┘
```

**Ventaja vs Booksy**: IA y personalización avanzada. Fidelización.

---

### 5. **Sistema de "Colecciones" (Listas Temáticas)**

#### ¿Por qué?
Pinterest/Spotify lo hacen. Crear listas curadas diferencia vs Booksy.

#### ¿Qué añadir?
```
📚 COLECCIONES CURADAS (por equipo editorial o comunidad)

Ejemplos:
• "Mejores Barberías Retro de Guadalajara" 🪒
• "Salones Pet-Friendly" 🐕
• "Comida Vegana Con Alma" 🌱
• "Tatuajes Minimalistas Top 10" 🎨
• "Date Night: Cena + Spa Romántico" 💑

Tap → Vista lista con descripción:
┌─────────────────────────────────────────┐
│  [Foto Header Colección]                 │
│  "Mejores Barberías Retro"               │
│  By: Equipo Fluix · 8 negocios           │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  [Negocio 1] [Negocio 2] [Negocio 3] ... │
│                                           │
│  [♥ Guardar colección]                   │
└─────────────────────────────────────────┘
```

**Ventaja vs Booksy**: Contenido editorial. Engagement y tiempo en app.

---

### 6. **"Stories" de Negocios (Efímeros 24h)**

#### ¿Por qué?
Instagram/Facebook Stories funcionan. Aplicarlo a negocios locales.

#### ¿Qué añadir?
```
📸 STORIES (barra horizontal top, después del saludo)

┌────────────────────────────────────────────────┐
│  Círculos con foto del negocio + borde:        │
│  🟣[Salón Ana] 🟣[Tattoo Ink] ⚪[Resto Luigi] │
│  ↑ gradient     ↑ gradient    ↑ visto         │
│                                                 │
│  Tap → Fullscreen story:                       │
│  • Foto/video del negocio (15s)                │
│  • Texto overlay: "¡Nuevo estilista!"          │
│  • Call-to-action: [Ver servicio]             │
│  • Progress bar top + skip buttons             │
└────────────────────────────────────────────────┘

Casos de uso:
• Negocio anuncia: "Hueco libre hoy 18:00"
• Show de antes/después de servicio
• Nuevos productos/servicios
• Ofertas flash 24h
```

**Ventaja vs Booksy**: Conexión emocional. Contenido efímero = urgencia.

---

### 7. **Sección "Top Esta Semana" con Ranking**

#### ¿Por qué?
Gamificación y social proof mejorado.

#### ¿Qué añadir?
```
🏆 TOP ESTA SEMANA (carrusel con medallas)

┌────────────────────────────────────────┐
│  Tarjetas verticales con badge:        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│  🥇 #1  [Foto Negocio]                 │
│       "Estética María"                  │
│       ⭐ 4.9 · 124 reservas            │
│       🔥 +45% vs semana pasada          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│  🥈 #2  [Foto Negocio]                 │
│       "Barbería Clásica"                │
│       ⭐ 4.8 · 98 reservas             │
│       📈 Subió 3 posiciones             │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│  🥉 #3  ...                            │
└────────────────────────────────────────┘
```

**Ventaja vs Booksy**: Social proof intenso. Los negocios compiten por estar arriba.

---

### 8. **Búsqueda Visual/Inteligente**

#### ¿Por qué?
Booksy tiene búsqueda simple. Mejorar con sugerencias visuales.

#### ¿Qué añadir?
```
🔍 BÚSQUEDA MEJORADA

Mientras escribes:
┌──────────────────────────────────────┐
│  "cort..." @ [buscador]               │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│  Sugerencias con preview:             │
│  ┌───────────────────────────────┐   │
│  │ [Foto] "Corte de pelo hombre"  │   │
│  │        12 negocios cerca       │   │
│  ├───────────────────────────────┤   │
│  │ [Foto] "Corte + barba"         │   │
│  │        8 servicios             │   │
│  ├───────────────────────────────┤   │
│  │ [Foto] "Cortinas"              │   │
│  │        (otro negocio tipo)     │   │
│  └───────────────────────────────┘   │
└──────────────────────────────────────┘

Búsqueda por voz: 🎤
"Buscar peluquería cerca de mí con hueco hoy"
→ IA procesa y filtra automáticamente
```

**Ventaja vs Booksy**: UX superior. Menos fricción = más conversiones.

---

### 9. **Widget "Reservar Ahora" Flotante**

#### ¿Por qué?
Reducir pasos del funnel. Acción inmediata.

#### ¿Qué añadir?
```
⚡ BOTÓN FLOTANTE (aparece al hacer scroll)

┌─────────────────────────────────────┐
│  [Contenido scroll...]               │
│                                      │
│                 ┌───────────────────┐│
│                 │ ⚡ Reservar Ya    ││
│                 │ 🕐 Siguiente: 17:30││
│                 └───────────────────┘│
│                   ↑ Botón flotante   │
└─────────────────────────────────────┘

Tap → Modal rápido:
• Selecciona servicio (ya filtrado si viene de exploración)
• Selecciona profesional
• Selecciona fecha/hora (sugerida si disponible)
• [Confirmar en 30 segundos →]
```

**Ventaja vs Booksy**: Conversión ultra-rápida. Menos pasos.

---

### 10. **Sección "Nuevos" con Badge Temporal**

#### ¿Por qué?
Destacar negocios recién añadidos incentiva exploración.

#### ¿Qué añadir?
```
✨ NUEVOS EN FLUIX (carrusel horizontal)

Tarjetas con badge especial:
┌──────────────────────────────────┐
│  [FOTO] 🆕 NUEVO (badge esquina) │
│  "Salón de Uñas Premium"          │
│  ⭐ Aún sin valoraciones          │
│  🎁 15% OFF en tu primera visita  │
│  [Ser el primero en reservar →]  │
└──────────────────────────────────┘

Badge visible solo primeros 30 días.
```

**Ventaja vs Booksy**: Onboarding de negocios. Incentivo para ser early adopter.

---

## 🎨 Mejoras de Diseño General

### 1. **Paleta de Color Única y Reconocible**

**Actual**: Cian (#00FFC8) + Rosa/Magenta (#FF3296)  
**Mantener pero enriquecer con:**
- Gradientes dinámicos por categoría:
  - Restaurantes: 🍽️ Naranja → Rojo (#FF6B35 → #FF2850)
  - Estética: 💅 Rosa → Púrpura (#FF3296 → #A855F7)
  - Peluquería: 💇 Cian → Azul (#00FFC8 → #3B82F6)
  -Tatuajes: 🎨 Amarillo → Verde (#FCD34D → #10B981)

**Por qué**: Identidad visual única. Booksy usa azul simple.

---

### 2. **Animaciones Micro-Interacciones**

**Ejemplos**:
- Cards que hacen "bounce" al aparecer
- El icono de favorito (❤️) late cuando guardas
- Badge de "NUEVO" o "OFERTA" parpadea suavemente
- Pull-to-refresh con logo animado
- Skeleton screens smooth (no loading spinners)

**Por qué**: Fluidez y placer visual. Differenciador clave vs apps estáticas.

---

### 3. **Tipografía Distintiva**

**Actual**: Default  
**Propuesta**: 
- Headings: **Inter Black** (peso 900) para impacto
- Body: **Inter Regular** (limpia, legible)
- Accent: **Space Grotesk** para badges y CTAs (moderna)

**Por qué**: Booksy usa tipografía genérica. Nosotros seremos más memorables.

---

### 4. **Iconografía Custom**

**Ejemplos**:
- Iconos de categoría animados (no solo emojis)
- Iconos de estado reserva únicos (⏱️ pendiente, ✅ confirmada)
- Ilustraciones custom para estados vacíos

**Por qué**: Cohesión visual. Identidad propia.

---

## 📱 Mejoras de Funcionalidad

### 1. **Modo Oscuro Mejorado**

**Actual**: Ya tiene modo oscuro (azul marino + cian)  
**Mejora**: 
- Auto-switch según hora del día (opcional)
- Modo "AMOLED" (negro puro #000000 para ahorro batería)

---

### 2. **Gestos Avanzados**

**Ejemplos**:
- Swipe derecha en card → Guardar en favoritos
- Swipe izquierda en card → Compartir
- Long-press en negocio → Vista rápida (preview)
- Pinch-to-zoom en fotos de galería

**Por qué**: Power users lo aprecian. Booksy no tiene.

---

### 3. **Vista Previa Rápida (Quick Preview)**

**Funcionamiento**:
```
Long-press en tarjeta de negocio:
┌─────────────────────────────────────┐
│  [Foto expanssiva]                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│  Nombre del Negocio                 │
│  ⭐ 4.8 · €€ · 1.2km · Abierto     │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│  Próximos huecos:                   │
│  [Hoy 18:00] [Mañana 10:30] [...] │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│  [Ver detalles] [Reservar →]       │
└─────────────────────────────────────┘
↑ Modal semi-transparente
```

**Por qué**: Ver info clave sin navegar. Más rápido.

---

## 🚀 Funcionalidades "Wow" (Diferenciadores Únicos)

### 1. **"Grupo de Reservas" (Reservar con Amigos)**

**Caso de uso**: 
```
Ir al salón con amigas, cada una reserva su servicio.

Flujo:
1. Usuario crea "Grupo de Reserva"
2. Comparte link/código a contactos
3. Cada amiga elige su servicio
4. Sistema coordina horarios para que coincidan
5. Todas reciben confirmación conjunta

📍 La Peluquería
📅 Sábado 15:00
👥 3 personas:
   • María: Corte + Tinte (90 min)
   • Ana: Manicura (45 min)
   • Laura: Peinado (60 min)
```

**Ventaja**: Booksy NO tiene esto. Social = viralidad.

---

### 2. **"Ruta de Belleza" (Multi-Negocio en un día)**

**Caso de uso**:
```
Planificar día completo de belleza:
09:00 - Desayuno (Café Lolita)
10:30 - Manicura (Salón Glamour)
12:00 - Corte de pelo (Peluquería Moderna)
14:00 - Comida (Restaurante Vegan)
16:00 - Masaje (Spa Zen)

App sugiere rutas optimizadas:
• Por ubicación (menos desplazamiento)
• Por tiempo (menos esperas)
• Por precio (budget total)
```

**Ventaja**: Experiencia completa. Booksy solo hace reservas aisladas.

---

### 3. **"Modo Sorpresa" (Aléatelo)**

**Caso de uso**:
```
Usuario no sabe qué elegir:

1. Tap en "✨ Sorpréndeme"
2. Responde 3 preguntas:
   • ¿Cuánto tiempo tienes? [30min / 1h / 2h+]
   • ¿Cuánto quieres gastar? [€ / €€ / €€€]
   • ¿Qué tipo de experiencia? [Relajante / Energizante / Transformación]
3. IA genera sugerencia personalizada
4. Opción de aceptar/regenerar

→ "Tu sorpresa: Masaje descontracturante en Spa Luna ⭐4.9"
```

**Ventaja**: Gamificación + decisión sin estrés. Único en el mercado.

---

### 4. **"Cashback / Puntos Fluix"**

**Sistema de fidelización**:
```
Por cada reserva completada:
• Ganas puntos Fluix (1 punto = 1€ gastado)
• Al llegar a 100 puntos → Vale 10€

Niveles VIP:
🥉 Bronce: 0-500 puntos (beneficios básicos)
🥈 Plata: 500-2000 puntos (+5% puntos extra)
🥇 Oro: 2000+ puntos (+10% + acceso anticipado a ofertas)

Dashboard:
┌────────────────────────────────┐
│  🏆 Nivel: Plata                │
│  💎 Puntos: 1,234              │
│  📈 Para Oro: 766 puntos más   │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━│
│  Recompensas disponibles:       │
│  • Vale 10€ (1000 pts) [Canjear]│
│  • Servicio gratis (2000 pts)   │
└────────────────────────────────┘
```

**Ventaja**: Booksy no recompensa lealtad. Nosotros sí.

---

## 📊 Resumen de Prioridades

### 🔴 Críticas (Implementar Ya)

1. ✅ **Carruseles con scroll infinito** (Fix técnico)
2. ✅ **Botón "Ver todo" funcional** (Fix técnico)
3. ✅ **Sección "Eventos y Promociones"** (Diferenciador fuerte)
4. ✅ **Vista Mapa interactivo** (Toggle vista lista/mapa)
5. ✅ **Búsqueda mejorada con preview** (UX superior)

### 🟡 Importantes (Fase 2)

6. ✅ **System Stories** (24h)
7. ✅ **Top Esta Semana** (ranking)
8. ✅ **Colecciones curadas** (engagement)
9. ✅ **Filtros avanzados** (tags múltiples)
10. ✅ **Quick Preview** (long-press)

### 🟢 Nice-to-Have (Fase 3)

11. ⚪ **Grupo de reservas** (social)
12. ⚪ **Ruta de belleza** (multi-negocio)
13. ⚪ **Modo sorpresa** (IA)
14. ⚪ **Cashback/Puntos** (fidelización)
15. ⚪ **Animaciones avanzadas** (polish)

---

## 🎯 Conclusión

Con estas mejoras, **Fluix/PlaneaG se diferenciará claramente de Booksy**:

| Aspecto | Booksy | PlaneaG/Fluix |
|---------|--------|---------------|
| **Diseño** | Azul corporativo simple | Cian+Magenta vibrante, gradientes |
| **Contenido** | Solo negocios listados | Stories, eventos, colecciones |
| **Personalización** | Básica | IA, recomendaciones, modo sorpresa |
| **Social** | Individual | Grupos, rutas multi-negocio |
| **Fidelización** | No tiene | Puntos, cashback, niveles VIP |
| **Búsqueda** | Simple | Visual, inteligente, sugerencias |
| **Mapa** | Básico | Interactivo, pins agrupados |

**Resultado esperado**: 
- ✅ +40% tiempo en app (vs Booksy)
- ✅ +25% tasa de conversión (browsing → reserva)
- ✅ +60% retención 30 días (gracias a gamificación)
- ✅ Identidad visual única y memorable

---

**Próximo paso**: Implementar mejoras críticas (🔴) en Sprint actual.


