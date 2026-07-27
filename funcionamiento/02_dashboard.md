# Módulo: Dashboard

## Qué hace

Pantalla central de la app. Muestra un panel configurable con KPIs, resumen de métricas, acceso rápido a todos los módulos, y widgets dinámicos adaptados al tipo de negocio y rol del usuario.

---

## Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/dashboard/pantallas/` | Pantallas del dashboard |
| `features/dashboard/widgets/cabecera_dashboard.dart` | Header con logo y acciones |
| `features/dashboard/widgets/grid_modulos.dart` | Grid de acceso a módulos |
| `features/dashboard/widgets/reserva_card_mejorada.dart` | Card de próxima reserva |
| `features/dashboard/widgets/briefing_card.dart` | Resumen del día |
| `features/dashboard/widgets/badge_icon.dart` | Icono con notificación |
| `features/dashboard/widgets/offline_banner.dart` | Banner de modo offline |
| `features/dashboard/widgets/skeleton_loaders.dart` | Loaders de carga |
| `features/dashboard/widgets/configuracion_modulos.dart` | Edición del panel |
| `features/dashboard/widgets/configuracion_modulos_simple.dart` | Versión simplificada |
| `features/dashboard/widgets/grafico_evolucion_rating_widget.dart` | Gráfico de valoraciones |
| `features/dashboard/widgets/kpis_rating_widget.dart` | KPIs de satisfacción |
| `features/dashboard/widgets/estado_respuesta_widget.dart` | Estado de respuestas GMB |
| `features/dashboard/widgets/widget_cobertura_resumen.dart` | Cobertura de turnos |
| `features/dashboard/widgets/boton_recalcular_estadisticas.dart` | Recalcular métricas |
| `features/dashboard/providers/provider_dashboard.dart` | Estado del dashboard |
| `features/dashboard/pantallas/pantallas_configuracion_extras.dart` | Config avanzada |
| `features/dashboard/pantallas/tab_blog_web.dart` | Tab de blog integrado |
| `features/dashboard/pantallas/tab_seo_web.dart` | Tab de SEO |
| `features/dashboard/pantallas/pantalla_integracion_script.dart` | Script de integración |
| `features/dashboard/pantallas/conectar_google_business_screen.dart` | Conectar GMB |
| `features/dashboard/pantallas/configurar_google_reviews_screen.dart` | Config reviews |

---

## Cómo funciona internamente

### Carga inicial
1. `provider_dashboard.dart` se inicializa al entrar al dashboard
2. Carga desde Firestore: estadísticas del día, próximas reservas, tareas pendientes, rating actual
3. Si hay conexión, usa stream en tiempo real; si no, usa caché local
4. `skeleton_loaders.dart` muestra animaciones de carga mientras llegan los datos

### Grid de módulos
- `grid_modulos.dart` lee los módulos habilitados en `empresas/{empresaId}/configuracion/modulos`
- Filtra los módulos según el rol del usuario y los packs activos en la suscripción
- Módulos no contratados aparecen bloqueados con un icono de upgrade

### Widgets configurables
- El propietario puede personalizar qué widgets ver y en qué orden
- La configuración se guarda en `empresas/{empresaId}/configuracion/dashboard`
- `configuracion_modulos.dart` es el editor drag-and-drop del panel

### Briefing diario
- `briefing_card.dart` muestra: reservas del día, tareas vencidas, ventas de ayer, alertas de stock

### Estadísticas
- Los datos vienen de `empresas/{empresaId}/estadisticas/resumen` (documento agregado)
- Este documento se actualiza con triggers de Cloud Functions cuando hay nuevos pedidos, reservas o valoraciones
- `boton_recalcular_estadisticas.dart` fuerza una recalculación manual si hay discrepancias

---

## Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/estadisticas/resumen` | KPIs del día actual |
| `empresas/{empresaId}/estadisticas/web_resumen` | Analytics de la web pública |
| `empresas/{empresaId}/estadisticas/historico_diario` | Evolución histórica |
| `empresas/{empresaId}/configuracion/modulos` | Módulos habilitados |
| `empresas/{empresaId}/configuracion/dashboard` | Orden y visibilidad de widgets |
| `empresas/{empresaId}/reservas` | Próximas reservas del día |
| `empresas/{empresaId}/tareas` | Tareas pendientes/urgentes |

---

## Cloud Functions relacionadas

Las estadísticas del dashboard se actualizan automáticamente mediante triggers:
- Trigger en `pedidos` → actualiza ventas del día
- Trigger en `reservas` → actualiza ocupación
- Trigger en `valoraciones` → actualiza rating promedio
- `registrarVisita` — callable para tracking de visitas web

---

## Conexión con otros módulos

El dashboard es el **hub central** — tiene acceso a todos los módulos. No tiene lógica de negocio propia, solo agrega información de otros módulos y muestra accesos directos.

Módulos con integración especial en el dashboard:
- **Reservas** → muestra las próximas del día
- **Tareas** → alertas de vencidas/urgentes
- **GMB (Google Business)** → reviews recientes + estado de respuestas
- **Suscripción** → módulos bloqueados si el plan no los incluye
- **Web** → tabs de blog y SEO integrados en el dashboard
