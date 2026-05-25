#  Análisis: Pantalla Explorar — Estado actual y mejoras

## ✅ Lo que tiene ahora

| Componente | Estado | Descripción |
|---|---|---|
| **Tab Explorar** | ✅ Funcional | Grid categorías, carruseles, chips de filtro |
| **Carrusel Ofertas** | ✅ Funcional | Tarjetas anchas horizontales |
| **Carrusel Recomendados** | ✅ Funcional | Filtro por rating ≥ 4.0 |
| **Carrusel Cerca de ti** | ⚠️ Parcial | No usa geolocalización real |
| **Grid principal** | ✅ Funcional | 2 columnas con foto, rating, categoría |
| **Tab Buscar** | ✅ Arreglado | Texto + categoría, resultados tappables |
| **Tab Favoritos** | ✅ Arreglado | Lista real desde Firestore con ❤️ |
| **Botón ❤️ Favorito** | ✅ Nuevo | En todas las tarjetas (oferta, compacta, grid, buscar) |
| **Campana notificaciones** | ✅ Arreglada | Navega a PantallaNotificacionesCliente + badge |
| **Tab Perfil** | ✅ Funcional | Navega a PantallaPerfilCliente |

---

##  Problemas actuales / pendientes

- **Geolocalización falsa**: "Cerca de ti" no usa ubicación real del usuario
- **Sin paginación**: Al haber muchos negocios, se cargan todos a la vez (rendimiento)
- **Sin caché offline**: Si no hay conexión, pantalla vacía
- **Búsqueda solo cliente-side**: Para grandes datasets, necesita Algolia/Typesense
- **Sin filtros avanzados**: No hay filtro por precio, horario, distancia
- **Sin mapa**: No hay vista de mapa con pins de negocios
- **Sin resultados vacíos animados**: Estado vacío plano, nada llamativo

---

##  Mejoras para hacer una plataforma TOP

###  Alta prioridad

1. **Geolocalización real**
   - Paquete: `geolocator` + `geocoding`
   - Ordenar negocios por distancia al usuario
   - Mostrar distancia en cada tarjeta: "800m · 10 min"
   - Requireimiento: campo `geopoint` en Firestore en cada negocio

2. **Búsqueda con Algolia o Typesense**
   - Búsqueda instantánea con typo-tolerance
   - Ranking por relevancia, rating y distancia
   - Alternativa gratuita: Firebase + índice Firestore con `array_contains`

3. **Filtros avanzados en Buscar**
   - Precio: €, €€, €€€
   - Horario: "Abierto ahora"
   - Rating mínimo: ≥ 3, ≥ 4, ≥ 4.5
   - Con/sin reservas online
   - `BottomSheet` de filtros con chips seleccionables

4. **Vista de mapa (`flutter_map` o `google_maps_flutter`)**
   - Pins con categoría en mapa
   - Al pulsar pin → PreviewTarjeta mini
   - Toggle entre grid y mapa

###  Media prioridad

5. **Infinite scroll / paginación**
   - `Firestore .limit(20)` + `startAfter()` al llegar al fondo
   - Mejora masiva de rendimiento y reducción de costes de Firestore

6. **Sección "Tendencias / Esta semana"**
   - Negocios con más reservas en los últimos 7 días
   - Campo `reservas_semana: int` actualizado por Cloud Function

7. **Etiquetas / badges en tarjetas**
   -  Nuevo (creado hace < 30 días)
   -  Popular (muchas reservas)
   - ⚡ Disponible hoy
   -  Tiene oferta activa

8. **Búsqueda por voz**
   - Paquete `speech_to_text`
   - Icono de micrófono en el buscador

9. **Stories/Highlights de negocios**
   - Círculos horizontales en la parte superior (estilo Instagram)
   - Negocio publican "momentos": foto del día, oferta flash

###  Baja prioridad

10. **Recomendaciones personalizadas**
    - Basadas en historial de reservas del usuario
    - "Porque reservaste en X, prueba Y"

11. **Notificaciones de flash offers**
    - Push cuando un negocio publica oferta de última hora

12. **Comparador de negocios**
    - Seleccionar 2-3 negocios y ver tabla comparativa
    - Precio, rating, horarios, servicios

---

##  Mejoras de diseño

- [ ] **Animaciones de entrada**: FadeTransition + SlideTransition en tarjetas al cargar
- [ ] **Shimmer/Skeleton**: Placeholder animado mientras carga Firestore
- [ ] **Pull-to-refresh**: Deslizar hacia abajo para recargar
- [ ] **Hero animations**: Foto de tarjeta → foto en detalle con transición fluida
- [ ] **Chips con emojis**: Cada categoría con su emoji en el explorar (ya en Buscar)
- [ ] **Banner editable**: El negocio puede marcar si tiene "oferta del día" visible
- [ ] **Dark/Light mode toggle**: Aunque el dark ya queda bien

---

##  Métricas a rastrear (Analytics)

```dart
// Events que deberías registrar con Firebase Analytics
FirebaseAnalytics.instance.logEvent(name: 'negocio_visto', parameters: {
  'negocio_id': negocio.id,
  'categoria': negocio.categoria.name,
  'origen': 'explorar_grid', // o 'carrusel_ofertas', 'busqueda', 'favoritos'
});

FirebaseAnalytics.instance.logEvent(name: 'favorito_agregado', parameters: {
  'negocio_id': negocio.id,
  'categoria': negocio.categoria.name,
});

FirebaseAnalytics.instance.logEvent(name: 'busqueda', parameters: {
  'query': _q,
  'resultados': items.length,
});
```

---

##  Estructura Firestore recomendada

```
negocios_publicos/{id}
  activo: bool
  nombre: String
  categoria: String (enum name)
  descripcion: String?
  foto_url: String?
  fotos_galeria: List<String>
  rating_google: double?
  geopoint: GeoPoint       ← añadir para geolocalización
  distancia_metros: int?   ← calculado en Cloud Function
  nivel_precio: String     ← '€' | '€€' | '€€€'
  abierto_ahora: bool      ← calculado en CF cada hora
  reservas_semana: int     ← contador semanal para "tendencias"
  tiene_oferta: bool       ← flag para badge oferta
  es_nuevo: bool           ← creado hace < 30 días
  empresa_id_vinculada: String
  ...
```

---

*Generado: 14 mayo 2026 — PlaneaG / FluixCRM*
