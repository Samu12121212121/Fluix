import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EstadisticasCacheService {
  static final EstadisticasCacheService _instance =
  EstadisticasCacheService._internal();
  factory EstadisticasCacheService() => _instance;
  EstadisticasCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Timer> _timers = {};

  // ─────────────────────────────────────────────────────────────────────────
  // CICLO DE VIDA DEL CACHE
  // ─────────────────────────────────────────────────────────────────────────

  void iniciarCacheAutomatico(String empresaId) {
    _timers[empresaId]?.cancel();
    _calcularYGuardarEstadisticas(empresaId);
    _timers[empresaId] = Timer.periodic(const Duration(hours: 1), (_) {
      _calcularYGuardarEstadisticas(empresaId);
    });
    debugPrint('✅ Cache automático iniciado para $empresaId (TTL: 1h)');
  }

  void detenerCacheAutomatico(String empresaId) {
    _timers[empresaId]?.cancel();
    _timers.remove(empresaId);
  }

  Future<void> recalcularEstadisticas(String empresaId) async {
    await _calcularYGuardarEstadisticas(empresaId);
  }

  Future<void> limpiarCache(String empresaId) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('cache')
          .doc('estadisticas')
          .delete();
    } catch (e) {
      debugPrint('❌ Error limpiando cache: $e');
    }
  }

  Stream<Map<String, dynamic>> estadoCache(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('cache')
        .doc('estadisticas')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return {'existe': false, 'calculando': false};
      final data = doc.data()!;
      final ultima = _parseFecha(data['fecha_calculo']);
      final dif = DateTime.now().difference(ultima ?? DateTime(2000));
      return {
        'existe': true,
        'es_reciente': dif.inMinutes < 60,
        'ultima_actualizacion': (ultima ?? DateTime.now()).toIso8601String(),
        'minutos_desde_actualizacion': dif.inMinutes,
        'calculando': false,
      };
    });
  }

  Future<Map<String, dynamic>?> obtenerEstadisticasCache(
      String empresaId) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('cache')
          .doc('estadisticas')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final ultima = _parseFecha(data['fecha_calculo']);
        if (ultima != null &&
            DateTime.now().difference(ultima).inHours > 1) {
          _calcularYGuardarEstadisticas(empresaId);
        }
        return data;
      }
      _calcularYGuardarEstadisticas(empresaId);
      return null;
    } catch (e) {
      debugPrint('❌ Error obteniendo cache: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CÁLCULO PRINCIPAL
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _calcularYGuardarEstadisticas(String empresaId) async {
    try {
      debugPrint('🔄 Calculando estadísticas para $empresaId...');
      final now = DateTime.now();
      final inicioMes         = DateTime(now.year, now.month, 1);
      final inicioMesAnterior = DateTime(now.year, now.month - 1, 1);

      final results = await Future.wait([
        _calcularKpisPrincipales(empresaId, inicioMes, inicioMesAnterior),
        _calcularMetricasBasicas(empresaId, inicioMes, inicioMesAnterior),
        _calcularTendencias(empresaId),
        _calcularFichajes(empresaId, inicioMes),
      ]);

      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('cache')
          .doc('estadisticas')
          .set({
        ...results[0],
        ...results[1],
        ...results[2],
        ...results[3],
        'ultima_actualizacion': FieldValue.serverTimestamp(),
        'fecha_calculo': now.toIso8601String(),
        'version_cache': 3,
      }, SetOptions(merge: true));

      debugPrint('✅ Estadísticas guardadas en cache');
    } catch (e) {
      debugPrint('❌ Error calculando estadísticas: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KPIs PRINCIPALES
  // FIX: valor_medio_reserva calculado desde reservas (no transacciones)
  //      servicio_mas_rentable calculado por ingresos reales por servicio
  //      reservas_mes_anterior añadido para mostrar % de cambio en UI
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _calcularKpisPrincipales(
      String empresaId,
      DateTime inicioMes,
      DateTime inicioMesAnterior,
      ) async {
    try {
      // Reservas mes actual
      final reservasMesSnap = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .where('fecha',
          isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
          .get();

      // Reservas mes anterior (para calcular % cambio en UI)
      final reservasMesAnteriorSnap = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .where('fecha',
          isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMesAnterior))
          .where('fecha', isLessThan: Timestamp.fromDate(inicioMes))
          .get();

      int resConfirmadas = 0;
      int resCompletadas = 0;
      int resPendientes  = 0;
      int resCanceladas  = 0;

      // Mapas para popularidad e ingresos por servicio
      final Map<String, int>    serviciosConteo   = {};
      final Map<String, double> serviciosIngresos = {};

      // Mapas para empleados
      final Map<String, int> empleadosConteo = {};

      // Acumuladores para valor medio y horas pico
      double ingresosTotalReservas = 0;
      int    reservasConPrecio     = 0;
      final Map<String, int> horasConteo = {};

      // Métodos de pago
      final Map<String, int> metodoPagoConteo = {};

      // Clientes y su valor
      final Map<String, double> clientesValor = {};

      for (final doc in reservasMesSnap.docs) {
        final d     = doc.data();
        final estado = (d['estado'] ?? '').toString().toUpperCase();

        if (estado == 'CONFIRMADA')                     resConfirmadas++;
        else if (estado == 'COMPLETADA' ||
            estado == 'FINALIZADA')                resCompletadas++;
        else if (estado == 'PENDIENTE')                 resPendientes++;
        else if (estado == 'CANCELADA')                 resCanceladas++;

        // Servicio
        final servNombre = (d['servicio_nombre'] as String?) ??
            (d['servicio']     as String?) ?? 'General';
        serviciosConteo[servNombre] =
            (serviciosConteo[servNombre] ?? 0) + 1;

        // Precio de la reserva — FIX: varios nombres de campo posibles
        final precio = ((d['precio']        as num?) ??
            (d['total']         as num?) ??
            (d['importe']       as num?) ??
            (d['precio_total']  as num?) ?? 0).toDouble();
        if (precio > 0) {
          serviciosIngresos[servNombre] =
              (serviciosIngresos[servNombre] ?? 0) + precio;
          ingresosTotalReservas += precio;
          reservasConPrecio++;
        }

        // Empleado
        final empNombre = (d['empleado_nombre'] as String?) ??
            (d['empleado']     as String?) ?? 'Sin asignar';
        empleadosConteo[empNombre] =
            (empleadosConteo[empNombre] ?? 0) + 1;

        // Hora pico — saca la hora de inicio si existe
        final horaStr = d['hora_inicio'] as String? ??
            d['hora']          as String?;
        if (horaStr != null && horaStr.contains(':')) {
          final hora = horaStr.split(':').first;
          horasConteo[hora] = (horasConteo[hora] ?? 0) + 1;
        } else {
          // Intentar sacar de Timestamp fecha
          final fechaTs = d['fecha'];
          DateTime? dt;
          if (fechaTs is Timestamp) dt = fechaTs.toDate();
          if (dt != null) {
            final hora = dt.hour.toString().padLeft(2, '0');
            horasConteo[hora] = (horasConteo[hora] ?? 0) + 1;
          }
        }

        // Método de pago
        final metodo = (d['metodo_pago'] as String?) ??
            (d['forma_pago']  as String?) ?? 'Efectivo';
        metodoPagoConteo[metodo] =
            (metodoPagoConteo[metodo] ?? 0) + 1;

        // Valor por cliente
        final clienteId = (d['cliente_id'] as String?) ??
            (d['cliente_nombre'] as String?) ?? '';
        if (clienteId.isNotEmpty && precio > 0) {
          clientesValor[clienteId] =
              (clientesValor[clienteId] ?? 0) + precio;
        }
      }

      final totalReservas = reservasMesSnap.docs.length;

      // Tasas
      final tasaConversion  = totalReservas > 0
          ? resCompletadas / totalReservas * 100
          : 0.0;
      final tasaCancelacion = totalReservas > 0
          ? resCanceladas  / totalReservas * 100
          : 0.0;

      // FIX: valor_medio_reserva desde reservas con precio, no /transacciones
      final valorMedioReserva = reservasConPrecio > 0
          ? ingresosTotalReservas / reservasConPrecio
          : 0.0;

      // Servicio más popular (por número de reservas)
      final serviciosSortedConteo = serviciosConteo.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final servicioPopular = serviciosSortedConteo.isNotEmpty
          ? serviciosSortedConteo.first.key
          : 'N/A';

      // FIX: servicio más rentable (por ingresos reales)
      final serviciosSortedIngresos = serviciosIngresos.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final servicioRentable = serviciosSortedIngresos.isNotEmpty
          ? serviciosSortedIngresos.first.key
          : servicioPopular; // fallback al popular si no hay precios

      // Empleado más activo
      final empleadosSorted = empleadosConteo.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final empleadoActivo = empleadosSorted.isNotEmpty
          ? empleadosSorted.first.key
          : 'N/A';

      // Horas pico — top 3
      final horasSorted = horasConteo.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final horasPico = horasSorted
          .take(3)
          .map((e) => '${e.key}:00h')
          .toList();

      // Método de pago preferido
      final metodoPagoSorted = metodoPagoConteo.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final metodoPagoPreferido = metodoPagoSorted.isNotEmpty
          ? metodoPagoSorted.first.key
          : 'Efectivo';

      // Cliente más valioso
      final clientesSorted = clientesValor.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final clienteMasValioso = clientesSorted.isNotEmpty
          ? clientesSorted.first.key
          : 'N/A';
      final valorPromedioCliente = clientesValor.isNotEmpty
          ? clientesValor.values.fold(0.0, (a, b) => a + b) /
          clientesValor.length
          : 0.0;

      // Map para UI de reservas por servicio
      final reservasPorServicio = <String, dynamic>{};
      for (final e in serviciosSortedConteo) {
        reservasPorServicio[e.key] = e.value;
      }

      // Map para UI de rendimiento empleados
      final rendimientoEmpleados = <String, dynamic>{};
      for (final e in empleadosConteo.entries) {
        rendimientoEmpleados[e.key] = {
          'reservas': e.value,
          'ingresos': 0, // se podría cruzar si reservas tienen precio+empleado
        };
      }

      return {
        // Reservas mes actual
        'reservas_mes':           totalReservas,
        'reservas_confirmadas':   resConfirmadas,
        'reservas_completadas':   resCompletadas,
        'reservas_pendientes':    resPendientes,
        'reservas_canceladas':    resCanceladas,
        // Reservas mes anterior — para % cambio en UI
        'reservas_mes_anterior':  reservasMesAnteriorSnap.docs.length,
        // Rendimiento
        'tasa_conversion':        tasaConversion,
        'tasa_cancelacion':       tasaCancelacion,
        'valor_medio_reserva':    valorMedioReserva,
        'ingresos_reservas_mes':  ingresosTotalReservas,
        // Servicios
        'reservas_por_servicio':  reservasPorServicio,
        'servicio_mas_popular':   servicioPopular,
        'servicio_mas_rentable':  servicioRentable,   // FIX: calculado por ingresos
        // Empleados
        'rendimiento_empleados':  rendimientoEmpleados,
        'empleado_mas_activo':    empleadoActivo,
        // Comportamiento
        'horas_pico':             horasPico,
        'metodo_pago_preferido':  metodoPagoPreferido,
        'cliente_mas_valioso':    clienteMasValioso,
        'valor_promedio_cliente': valorPromedioCliente,
      };
    } catch (e) {
      debugPrint('❌ Error calculando KPIs: $e');
      return {};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTRICAS BÁSICAS
  // FIX: clientes_activos filtra por campo activo si existe
  //      nuevos_clientes_mes_anterior añadido para % cambio en UI
  //      ingresos_mes eliminado de /transacciones (no existe)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _calcularMetricasBasicas(
      String empresaId,
      DateTime inicioMes,
      DateTime inicioMesAnterior,
      ) async {
    try {
      final results = await Future.wait([
        _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('clientes')
            .get(),
        _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('servicios')
            .where('activo', isEqualTo: true)
            .get(),
        _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('empleados')
            .where('activo', isEqualTo: true)   // FIX: filtrar por activo
            .get(),
        _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('valoraciones')
            .get(),
        _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('pedidos')
            .where('fecha_creacion',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
            .get(),
        _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('facturas')
            .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
            .get(),
        _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('gastos')
            .where('fecha_gasto',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
            .get(),
      ]);

      final clientes     = results[0] as QuerySnapshot;
      final servicios    = results[1] as QuerySnapshot;
      final empleados    = results[2] as QuerySnapshot;
      final valoraciones = results[3] as QuerySnapshot;
      final pedidosMes   = results[4] as QuerySnapshot;
      final facturasMes  = results[5] as QuerySnapshot;
      final gastosMes    = results[6] as QuerySnapshot;

      // ── Clientes ──────────────────────────────────────────────────────
      // FIX: clientes_activos cuenta los que tienen activo != false
      // (si no tienen el campo se asumen activos)
      int clientesActivos = 0;
      int clientesNuevosMes = 0;
      int clientesNuevosMesAnterior = 0;

      for (final doc in clientes.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final activoField = d['activo'];
        // Si el campo no existe o es true, se considera activo
        if (activoField == null || activoField == true) {
          clientesActivos++;
        }

        // Nuevos este mes
        final fechaRaw = d['fecha_registro'] ?? d['fecha_creacion'];
        final fecha    = _tsToDate(fechaRaw);
        if (fecha != null) {
          if (fecha.isAfter(inicioMes)) {
            clientesNuevosMes++;
          } else if (fecha.isAfter(inicioMesAnterior) &&
              fecha.isBefore(inicioMes)) {
            clientesNuevosMesAnterior++;
          }
        }
      }

      // ── Valoraciones ─────────────────────────────────────────────────
      double sumaVal = 0;
      int val5 = 0, val4 = 0, val3 = 0, val2 = 0, val1 = 0;
      int valMes = 0;

      for (final doc in valoraciones.docs) {
        final d      = doc.data() as Map<String, dynamic>;
        final rating = ((d['calificacion'] as num?) ??
            (d['puntuacion']   as num?) ??
            (d['rating']       as num?) ?? 0).toDouble();
        sumaVal += rating;

        if (rating >= 4.5)      val5++;
        else if (rating >= 3.5) val4++;
        else if (rating >= 2.5) val3++;
        else if (rating >= 1.5) val2++;
        else                    val1++;

        final fechaVal = _tsToDate(d['fecha'] ?? d['fecha_creacion']);
        if (fechaVal != null && fechaVal.isAfter(inicioMes)) valMes++;
      }

      final valoracionPromedio = valoraciones.docs.isEmpty
          ? 0.0
          : sumaVal / valoraciones.docs.length;

      // ── Empleados por rol ─────────────────────────────────────────────
      int empProp = 0, empAdmin = 0, empStaff = 0;
      for (final doc in empleados.docs) {
        final rol = ((doc.data() as Map)['rol'] ?? '').toString().toLowerCase();
        if (rol.contains('prop') || rol.contains('dueño'))    empProp++;
        else if (rol.contains('admin') || rol.contains('enc')) empAdmin++;
        else                                                   empStaff++;
      }

      // ── Pedidos ───────────────────────────────────────────────────────
      final ingresosPedidosMes = pedidosMes.docs
          .where((d) {
        final estado = (d.data() as Map)['estado_pago'] ??
            (d.data() as Map)['estado'];
        return estado == 'pagado' || estado == 'PAGADO';
      })
          .fold<double>(
          0,
              (s, d) =>
          s +
              (((d.data() as Map)['total'] as num?) ?? 0).toDouble());

      // ── Facturas ──────────────────────────────────────────────────────
      final ingresosFacturasMes = facturasMes.docs
          .where((d) {
        final estado = ((d.data() as Map)['estado'] ?? '').toString();
        return estado == 'PAGADA' || estado == 'pagada' || estado == 'cobrada';
      })
          .fold<double>(
          0,
              (s, d) =>
          s +
              (((d.data() as Map)['total'] as num?) ?? 0).toDouble());

      // ── Gastos ────────────────────────────────────────────────────────
      final gastosPagadosMes = gastosMes.docs
          .where((d) {
        final estado = ((d.data() as Map)['estado'] ?? '').toString();
        return estado == 'pagado' || estado == 'PAGADO';
      })
          .fold<double>(
          0,
              (s, d) =>
          s +
              (((d.data() as Map)['total'] as num?) ??
                  ((d.data() as Map)['importe'] as num?) ?? 0).toDouble());

      final beneficioNetoMes = ingresosFacturasMes - gastosPagadosMes;

      return {
        // Clientes
        'total_clientes':                clientes.docs.length,
        'clientes_activos':              clientesActivos,           // FIX
        'nuevos_clientes_mes':           clientesNuevosMes,
        'nuevos_clientes_mes_anterior':  clientesNuevosMesAnterior, // NUEVO
        // Servicios y empleados
        'total_servicios_activos':       servicios.docs.length,
        'total_empleados_activos':       empleados.docs.length,
        'empleados_propietarios':        empProp,
        'empleados_admin':               empAdmin,
        'empleados_staff':               empStaff,
        // Valoraciones
        'valoracion_promedio':           valoracionPromedio,
        'total_valoraciones':            valoraciones.docs.length,
        'valoraciones_mes':              valMes,
        'valoraciones_5_estrellas':      val5,
        'valoraciones_4_estrellas':      val4,
        'valoraciones_3_estrellas':      val3,
        'valoraciones_2_estrellas':      val2,
        'valoraciones_1_estrella':       val1,
        // Pedidos
        'pedidos_mes':                   pedidosMes.docs.length,
        'pedidos_pendientes':            pedidosMes.docs
            .where((d) => (d.data() as Map)['estado'] == 'pendiente')
            .length,
        'ingresos_pedidos_mes':          ingresosPedidosMes,
        // Facturas
        'facturas_mes':                  facturasMes.docs.length,
        'ingresos_facturas_mes':         ingresosFacturasMes,
        // Gastos y beneficio
        'gastos_pagados_mes':            gastosPagadosMes,
        'beneficio_neto_mes':            beneficioNetoMes,
        // Total combinado
        'ingresos_totales_mes':          ingresosPedidosMes + ingresosFacturasMes,
      };
    } catch (e) {
      debugPrint('❌ Error calculando métricas básicas: $e');
      return {};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TENDENCIAS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _calcularTendencias(String empresaId) async {
    try {
      final hace7Dias = DateTime.now().subtract(const Duration(days: 7));

      final reservasSnap = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .where('fecha',
          isGreaterThanOrEqualTo: Timestamp.fromDate(hace7Dias))
          .get();

      final distribucionDias = <String, int>{};
      for (final doc in reservasSnap.docs) {
        final fecha = _tsToDate((doc.data())['fecha']);
        if (fecha != null) {
          final dia = _diaSemana(fecha.weekday);
          distribucionDias[dia] = (distribucionDias[dia] ?? 0) + 1;
        }
      }

      final diaMasActivo = distribucionDias.entries.isEmpty
          ? 'N/A'
          : (distribucionDias.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;

      return {
        'reservas_ultima_semana': reservasSnap.docs.length,
        'dia_mas_activo':         diaMasActivo,
        'distribucion_dias':      distribucionDias,
      };
    } catch (e) {
      debugPrint('❌ Error calculando tendencias: $e');
      return {};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FICHAJES — Control horario
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _calcularFichajes(
      String empresaId, DateTime inicioMes) async {
    try {
      final ahora = DateTime.now();
      final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);

      // Todos los fichajes del mes
      final fichajesMesSnap = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('fichajes')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
          .get();

      // Fichajes de hoy (para calcular activos y únicos de hoy)
      final fichajesHoySnap = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('fichajes')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
          .orderBy('timestamp')
          .get();

      // ── Horas trabajadas este mes ─────────────────────────────────────
      // Agrupar entrada/salida por empleado (pares consecutivos)
      final Map<String, List<Map<String, dynamic>>> porEmpleado = {};
      for (final doc in fichajesMesSnap.docs) {
        final d  = doc.data();
        final id = d['empleado_id'] as String? ?? 'desconocido';
        porEmpleado.putIfAbsent(id, () => []).add(d);
      }

      double horasTrabajadasMes = 0;
      int fichajesConSalida = 0;

      for (final registros in porEmpleado.values) {
        // Ordenar por timestamp
        registros.sort((a, b) {
          final ta = _tsToDate(a['timestamp'])?? DateTime(2000);
          final tb = _tsToDate(b['timestamp'])?? DateTime(2000);
          return ta.compareTo(tb);
        });

        DateTime? entrada;
        for (final r in registros) {
          final tipo = r['tipo'] as String? ?? '';
          final ts   = _tsToDate(r['timestamp']);
          if (ts == null) continue;

          if (tipo == 'entrada') {
            entrada = ts;
          } else if (tipo == 'salida' && entrada != null) {
            horasTrabajadasMes += ts.difference(entrada).inMinutes / 60.0;
            fichajesConSalida++;
            entrada = null;
          }
        }
      }

      // ── Empleados con fichaje activo AHORA (entrada sin salida hoy) ──
      final Map<String, String?> ultimoTipoHoy = {};
      for (final doc in fichajesHoySnap.docs) {
        final d    = doc.data();
        final id   = d['empleado_id'] as String? ?? '';
        final tipo = d['tipo'] as String? ?? '';
        if (id.isNotEmpty) ultimoTipoHoy[id] = tipo;
      }

      final empleadosActivos = ultimoTipoHoy.values
          .where((t) => t == 'entrada' || t == 'pausa_fin')
          .length;

      // ── Empleados únicos que ficharon hoy ────────────────────────────
      final empleadosFichadosHoy = ultimoTipoHoy.keys.length;

      // ── Empleado con más horas este mes ──────────────────────────────
      final Map<String, double> horasPorEmpleadoNombre = {};
      final Map<String, double> horasPorEmpleadoId = {};
      for (final entry in porEmpleado.entries) {
        final registros = entry.value;
        registros.sort((a, b) {
          final ta = _tsToDate(a['timestamp']) ?? DateTime(2000);
          final tb = _tsToDate(b['timestamp']) ?? DateTime(2000);
          return ta.compareTo(tb);
        });
        double horas = 0;
        String nombre = 'Desconocido';
        DateTime? entrada;
        for (final r in registros) {
          final tipo = r['tipo'] as String? ?? '';
          final ts   = _tsToDate(r['timestamp']);
          nombre = r['empleado_nombre'] as String? ?? nombre;
          if (ts == null) continue;
          if (tipo == 'entrada') {
            entrada = ts;
          } else if (tipo == 'salida' && entrada != null) {
            horas += ts.difference(entrada).inMinutes / 60.0;
            entrada = null;
          }
        }
        horasPorEmpleadoNombre[nombre] = (horasPorEmpleadoNombre[nombre] ?? 0) + horas;
        horasPorEmpleadoId[entry.key] = horas;
      }

      final empleadoMasHoras = horasPorEmpleadoNombre.entries.isEmpty
          ? 'N/A'
          : (horasPorEmpleadoNombre.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;

      final horasPromedioEmpleado = horasPorEmpleadoId.isEmpty
          ? 0.0
          : horasPorEmpleadoId.values.fold(0.0, (s, v) => s + v) /
              horasPorEmpleadoId.length;

      return {
        'fichajes_mes':                fichajesMesSnap.docs.length,
        'horas_trabajadas_mes':        double.parse(horasTrabajadasMes.toStringAsFixed(1)),
        'empleados_con_fichaje_activo': empleadosActivos,
        'empleados_fichados_hoy':      empleadosFichadosHoy,
        'empleado_mas_horas_mes':      empleadoMasHoras,
        'horas_promedio_empleado_mes': double.parse(horasPromedioEmpleado.toStringAsFixed(1)),
        'fichajes_con_salida_mes':     fichajesConSalida,
      };
    } catch (e) {
      debugPrint('❌ Error calculando fichajes: $e');
      return {};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Convierte Timestamp, String o null a DateTime de forma segura.
  DateTime? _tsToDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String)    return DateTime.tryParse(raw);
    return null;
  }

  DateTime? _parseFecha(dynamic raw) => _tsToDate(raw);

  String _diaSemana(int weekday) {
    switch (weekday) {
      case 1: return 'lunes';
      case 2: return 'martes';
      case 3: return 'miércoles';
      case 4: return 'jueves';
      case 5: return 'viernes';
      case 6: return 'sábado';
      case 7: return 'domingo';
      default: return 'desconocido';
    }
  }
}