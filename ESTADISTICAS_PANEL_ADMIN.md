#  Estadísticas Interesantes para el Panel de Admin (PlaneaG)

> Ideas de métricas y KPIs que se pueden añadir al panel de administración de plataforma.  
> Todas se pueden calcular desde Firestore con Cloud Functions programadas o en tiempo real.

---

##  Métricas de Empresas

| Métrica | Descripción | Fuente Firestore |
|---------|-------------|-----------------|
| **Total empresas registradas** | Nº total de documentos en `/empresas` | `empresas` (count) |
| **Empresas activas** | Estado `activo == true` en `suscripcion/actual` | `empresas/{id}/suscripcion/actual` |
| **Empresas vencidas** | Estado `estado == 'VENCIDA'` | `empresas/{id}/suscripcion/actual` |
| **Empresas en prueba / demo** | Flag `es_demo == true` | `empresas/{id}/suscripcion/actual` |
| **Nuevas empresas este mes** | `fecha_creacion` en el mes actual | `empresas` |
| **Churn mensual** | Empresas que pasaron a VENCIDA este mes | `empresas/{id}/suscripcion/actual` |

### Widget sugerido: Tarjetas de resumen
```
┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐
│   Total  │  │  ✅ Activas │  │  ❌ Vencidas│  │   Nuevas │
│    142     │  │    118     │  │    24      │  │   +7 mes   │
└────────────┘  └────────────┘  └────────────┘  └────────────┘
```

---

##  Métricas Financieras (MRR / ARR)

| Métrica | Cálculo | Notas |
|---------|---------|-------|
| **MRR** (Monthly Recurring Revenue) | Suma de `precio_mensual` de suscripciones activas | Calcular con Cloud Function |
| **ARR** (Annual Recurring Revenue) | MRR × 12 | Derivado |
| **Ticket medio** | MRR / nº empresas activas | Derivado |
| **LTV estimado** | Ticket medio × duración media en meses | Histórico necesario |
| **Ingresos por plan** | Agrupar activas por plan y multiplicar por precio | Por segmento |
| **Evolución MRR** | MRR de cada mes (últimos 12 meses) | Gráfico de línea |

### Widget sugerido: Gráfico de evolución MRR
```
€ MRR
2.800 │                              ●
2.600 │                         ●─●
2.400 │                    ●─●
2.200 │               ●─●
      └──────────────────────────────▶ Mes
        Ene  Feb  Mar  Abr  May  Jun
```

---

##  Distribución por Plan

| Plan | Empresas | % | Precio/mes | MRR aportado |
|------|----------|---|------------|--------------|
| FREE | — | —% | 0 € | 0 € |
| BÁSICO | — | —% | — € | — € |
| PRO | — | —% | — € | — € |
| ENTERPRISE | — | —% | — € | — € |

> **Widget sugerido**: Gráfico de tarta + tabla desglosada.

---

##  Reservas y Citas

| Métrica | Descripción | Fuente |
|---------|-------------|--------|
| **Total reservas plataforma** | Suma de todas las reservas de todas las empresas | `empresas/{id}/reservas` |
| **Reservas este mes** | Filtrar por `fecha_hora` en el mes actual | ídem |
| **Reservas pendientes** | `estado == 'PENDIENTE'` globales | ídem |
| **Tasa de confirmación** | CONFIRMADAS / (CONFIRMADAS + CANCELADAS) % | Calculado |
| **Top 5 empresas por reservas** | Ranking de empresas con más reservas | Agregado |
| **Pico de reservas por día de semana** | Lunes-Domingo, promedio reservas | Análisis temporal |

---

##  Tráfico Web (Fluix Analytics)

| Métrica | Descripción | Fuente |
|---------|-------------|--------|
| **Visitas totales plataforma** | Suma de `visitas_total` de todos los `web_resumen` | `empresas/{id}/estadisticas/web_resumen` |
| **Visitas este mes** | Suma de `visitas_mes` | ídem |
| **% móvil vs desktop** | `visitas_movil / visitas_total` | ídem |
| **Top 5 páginas visitadas** | Agregado del mapa `paginas_mas_vistas` | ídem |
| **Empresas con script activo** | Nº de empresas con doc `web_resumen` existente | Consulta |

---

## ⭐ Valoraciones y Reputación

| Métrica | Descripción |
|---------|-------------|
| **Valoración media plataforma** | Media de `calificacion` en todas las `valoraciones` de todas las empresas |
| **Top 10 empresas mejor valoradas** | Ranking por media de valoraciones |
| **Nº reseñas Google gestionadas** | Documentos en `google_reviews` |
| **Tasa de respuesta a reseñas** | Reseñas con `respondida == true` / total |

---

##  Usuarios y Equipo

| Métrica | Descripción |
|---------|-------------|
| **Total usuarios registrados** | Documentos en `/usuarios` |
| **Breakdown por rol** | propietario / admin / staff / cliente |
| **Usuarios activos últimos 30 días** | Últimos `timestamp` de fichaje o acceso |
| **Promedio empleados por empresa** | Total staff / nº empresas activas |

---

##  Notificaciones y Engagement

| Métrica | Descripción |
|---------|-------------|
| **Notificaciones enviadas este mes** | Docs en `/notificaciones/{id}/items` |
| **Tasa de apertura** | `leida == true` / total notificaciones |
| **Sugerencias recibidas** | Docs con tipo 'sugerencia' en tareas de la empresa admin |
| **Tiempo medio respuesta sugerencia** | Entre `fecha_creacion` y primera respuesta |

---

##  Módulos más usados

| Módulo | Empresas que lo usan | % adopción |
|--------|---------------------|------------|
| Reservas | — | —% |
| Clientes | — | —% |
| Pedidos | — | —% |
| Facturación | — | —% |
| Tráfico Web | — | —% |
| Google Reviews | — | —% |
| Nóminas | — | —% |

> Detectable contando empresas que tienen documentos en cada subcolección.

---

##  Widgets prioritarios para implementar primero

### Nivel 1 – Fáciles (datos ya existentes, solo leer)
1. ✅ Contador total empresas + activas/vencidas
2. ✅ Distribución por plan (gráfico tarta)
3. ✅ Nuevas empresas este mes vs mes anterior

### Nivel 2 – Medios (requieren agregación)
4.  MRR calculado (Cloud Function diaria que guarda snapshot en `/plataforma_stats/mrr_historico`)
5.  Top empresas por reservas este mes
6.  Gráfico visitas web agregadas

### Nivel 3 – Avanzados (requieren más lógica)
7.  Tasa de churn mensual
8.  LTV estimado
9.  Embudo de conversión (demo → pago → renovación)

---

## ️ Estructura Firestore sugerida para estadísticas de plataforma

Para no recalcular en cada carga, guardar snapshots diarios:

```
/plataforma_stats/
  resumen_diario/{fecha}/
    - total_empresas: int
    - empresas_activas: int
    - empresas_nuevas: int
    - empresas_vencidas: int
    - mrr: double
    - arr: double
    - total_reservas_mes: int
    - total_visitas_web: int
    - fecha: timestamp

  mrr_historico/{mes_YYYY_MM}/
    - mrr: double
    - empresas_pagantes: int
    - ticket_medio: double
```

La Cloud Function `generarResumenPlataforma` se ejecutaría cada noche a las 02:00 UTC.

---

##  Código Flutter sugerido — Tarjeta KPI

```dart
class KpiCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String? subtitulo;
  final IconData icono;
  final Color color;
  final String? tendencia; // "+12% vs mes anterior"

  const KpiCard({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
    this.subtitulo,
    this.tendencia,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icono, color: color, size: 20),
                ),
                const Spacer(),
                if (tendencia != null)
                  Text(tendencia!,
                    style: TextStyle(
                      fontSize: 11,
                      color: tendencia!.startsWith('+') ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(valor,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(titulo,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            if (subtitulo != null) ...[
              const SizedBox(height: 2),
              Text(subtitulo!,
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

*Generado: 2026-05-06 | PlaneaG / FluixCRM Admin Panel*
