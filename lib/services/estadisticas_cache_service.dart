import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class EstadisticasCacheService {
  static final EstadisticasCacheService _instance = EstadisticasCacheService._internal();
  factory EstadisticasCacheService() => _instance;
  EstadisticasCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Timer> _timers = {};

  /// Iniciar cálculo automático de estadísticas para una empresa
  void iniciarCacheAutomatico(String empresaId) {
    // Cancelar timer anterior si existe
    _timers[empresaId]?.cancel();

    // Calcular inmediatamente
    _calcularYGuardarEstadisticas(empresaId);

    // Programar cálculo cada 5 minutos
    _timers[empresaId] = Timer.periodic(const Duration(minutes: 5), (_) {
      _calcularYGuardarEstadisticas(empresaId);
    });

    print('✅ Cache automático iniciado para empresa $empresaId');
  }

  /// Detener cálculo automático
  void detenerCacheAutomatico(String empresaId) {
    _timers[empresaId]?.cancel();
    _timers.remove(empresaId);
    print('🛑 Cache automático detenido para empresa $empresaId');
  }

  /// Calcular y guardar estadísticas en cache
  Future<void> _calcularYGuardarEstadisticas(String empresaId) async {
    try {
      print('🔄 Calculando estadísticas en background para $empresaId...');

      // Obtener datos básicos
      final now = DateTime.now();
      final inicioMes = DateTime(now.year, now.month, 1);
      final inicioMesAnterior = DateTime(now.year, now.month - 1, 1);

      // Calcular estadísticas principales (versión optimizada)
      final estadisticas = await _calcularEstadisticasOptimizadas(empresaId, inicioMes, inicioMesAnterior);

      // Guardar en cache
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('cache')
          .doc('estadisticas')
          .set({
        ...estadisticas,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
        'fecha_calculo': now.toIso8601String(),
        'version_cache': 1,
      }, SetOptions(merge: true));

      print('✅ Estadísticas calculadas y guardadas en cache');
    } catch (e) {
      print('❌ Error calculando estadísticas en background: $e');
    }
  }

  /// Versión optimizada del cálculo de estadísticas (más rápida)
  Future<Map<String, dynamic>> _calcularEstadisticasOptimizadas(
    String empresaId,
    DateTime inicioMes,
    DateTime inicioMesAnterior
  ) async {
    final futures = [
      _calcularKpisPrincipales(empresaId, inicioMes, inicioMesAnterior),
      _calcularMetricasBasicas(empresaId, inicioMes),
      _calcularTendencias(empresaId),
    ];

    final resultados = await Future.wait(futures);

    return {
      ...resultados[0], // KPIs principales
      ...resultados[1], // Métricas básicas
      ...resultados[2], // Tendencias
    };
  }

  /// KPIs principales (solo los más importantes)
  Future<Map<String, dynamic>> _calcularKpisPrincipales(
    String empresaId,
    DateTime inicioMes,
    DateTime inicioMesAnterior
  ) async {
    try {
      // Transacciones del mes actual
      final transaccionesMes = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('transacciones')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
          .get();

      // Transacciones del mes anterior
      final transaccionesMesAnterior = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('transacciones')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMesAnterior))
          .where('fecha', isLessThan: Timestamp.fromDate(inicioMes))
          .get();

      // Calcular ingresos
      final ingresosMes = transaccionesMes.docs.fold<double>(
        0, (sum, doc) => sum + ((doc.data()['monto'] as num?) ?? 0).toDouble()
      );

      final ingresosMesAnterior = transaccionesMesAnterior.docs.fold<double>(
        0, (sum, doc) => sum + ((doc.data()['monto'] as num?) ?? 0).toDouble()
      );

      // Reservas del mes
      final reservasMes = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
          .get();

      // ANÁLISIS RESERVAS Y TRANSACCIONES
      int resConfirmadas = 0;
      int resCompletadas = 0;
      int resPendientes = 0;
      int resCanceladas = 0;
      
      final Map<String, int> serviciosCount = {};
      final Map<String, int> empleadosCount = {};

      for (var doc in reservasMes.docs) {
        final data = doc.data();
        final estado = (data['estado'] ?? '').toString().toUpperCase();
        
        if (estado == 'CONFIRMADA') resConfirmadas++;
        else if (estado == 'COMPLETADA' || estado == 'FINALIZADA') resCompletadas++;
        else if (estado == 'PENDIENTE') resPendientes++;
        else if (estado == 'CANCELADA') resCanceladas++;

        // Servicio
        final servicio = data['servicio_nombre'] as String? ?? 'General';
        serviciosCount[servicio] = (serviciosCount[servicio] ?? 0) + 1;
        
        // Empleado
        final empleado = data['empleado_nombre'] as String? ?? 'Sin asignar';
        empleadosCount[empleado] = (empleadosCount[empleado] ?? 0) + 1;
      }

      final totalReservas = reservasMes.docs.length;
      final tasaConversion = totalReservas > 0 ? (resCompletadas / totalReservas * 100) : 0.0;
      final tasaCancelacion = totalReservas > 0 ? (resCanceladas / totalReservas * 100) : 0.0;
      
      final numTransacciones = transaccionesMes.docs.length;
      final valorMedioReserva = numTransacciones > 0 ? (ingresosMes / numTransacciones) : 0.0;

      // Ordenar mapas
      final serviciosSorted = Map.fromEntries(
        serviciosCount.entries.toList()..sort((a,b) => b.value.compareTo(a.value))
      );
      final serviciosMapDynamic = <String, dynamic>{};
      serviciosSorted.forEach((k,v) => serviciosMapDynamic[k] = v);

      final empleadosSorted = Map.fromEntries(
        empleadosCount.entries.toList()..sort((a,b) => b.value.compareTo(a.value))
      );
      
      final servicioPopular = serviciosSorted.isNotEmpty ? serviciosSorted.keys.first : 'N/A';
      final empleadoActivo = empleadosSorted.isNotEmpty ? empleadosSorted.keys.first : 'N/A';
      
      // Estructura para gráfica de empleados
      final rendimientoEmpleados = <String, dynamic>{};
      empleadosCount.forEach((k,v) => rendimientoEmpleados[k] = {'reservas': v});

      return {
        'ingresos_mes': ingresosMes,
        'ingresos_mes_anterior': ingresosMesAnterior,
        'reservas_mes': totalReservas,
        'reservas_confirmadas': resConfirmadas,
        'reservas_completadas': resCompletadas,
        'reservas_pendientes': resPendientes,
        'reservas_canceladas': resCanceladas,
        'tasa_conversion': tasaConversion,
        'tasa_cancelacion': tasaCancelacion,
        'total_transacciones_mes': numTransacciones,
        'valor_medio_reserva': valorMedioReserva,
        'crecimiento_ingresos': ingresosMesAnterior > 0
            ? ((ingresosMes - ingresosMesAnterior) / ingresosMesAnterior * 100)
            : 0,
        // Extras para desgloses
        'reservas_por_servicio': serviciosMapDynamic,
        'servicio_mas_popular': servicioPopular,
        'servicio_mas_rentable': servicioPopular, // Simplificación
        'rendimiento_empleados': rendimientoEmpleados,
        'empleado_mas_activo': empleadoActivo,
      };
    } catch (e) {
      print('❌ Error calculando KPIs: $e');
      return {};
    }
  }

  /// Métricas básicas del negocio
  Future<Map<String, dynamic>> _calcularMetricasBasicas(String empresaId, DateTime inicioMes) async {
    try {
      final futures = [
        _firestore.collection('empresas').doc(empresaId).collection('clientes').get(),
        _firestore.collection('empresas').doc(empresaId).collection('servicios').where('activo', isEqualTo: true).get(),
        _firestore.collection('empresas').doc(empresaId).collection('empleados').get(),
        _firestore.collection('empresas').doc(empresaId).collection('valoraciones').get(),
        // Pedidos del mes
        _firestore.collection('empresas').doc(empresaId).collection('pedidos')
            .where('fecha_creacion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes)).get(),
        // Facturas del mes
        _firestore.collection('empresas').doc(empresaId).collection('facturas')
            .where('fecha_emision', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes)).get(),
        // Estadísticas de la web (visitas de Hostinger)
        _firestore.collection('empresas').doc(empresaId).collection('estadisticas').doc('resumen').get(),
        // Gastos del mes
        _firestore.collection('empresas').doc(empresaId).collection('gastos')
            .where('fecha_gasto', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes)).get(),
      ];

      final resultados = await Future.wait(futures);
      final clientes = resultados[0] as QuerySnapshot;
      final servicios = resultados[1] as QuerySnapshot;
      final empleados = resultados[2] as QuerySnapshot;
      final valoraciones = resultados[3] as QuerySnapshot;
      final pedidosMes = resultados[4] as QuerySnapshot;
      final facturasMes = resultados[5] as QuerySnapshot;
      final webResumen = resultados[6] as DocumentSnapshot;
      final gastosMes = resultados[7] as QuerySnapshot;

      // ANÁLISIS VALORACIONES
      double sumaVal = 0;
      int val5 = 0, val4 = 0, val3 = 0, val2 = 0, val1 = 0;
      int valMes = 0;

      for (var doc in valoraciones.docs) {
        final d = doc.data() as Map;
        final rating = ((d['calificacion'] as num?) ?? 0).toDouble();
        sumaVal += rating;
        
        if (rating >= 4.5) val5++;
        else if (rating >= 3.5) val4++;
        else if (rating >= 2.5) val3++;
        else if (rating >= 1.5) val2++;
        else val1++;
        
        // Fecha para "este mes"
        final fecha = d['fecha'] ?? d['fecha_creacion'];
        if (fecha != null) {
           DateTime? dt;
           if (fecha is Timestamp) dt = fecha.toDate();
           else if (fecha is String) dt = DateTime.tryParse(fecha);
           
           if (dt != null && dt.isAfter(inicioMes)) valMes++;
        }
      }
      
      final valoracionPromedio = valoraciones.docs.isEmpty ? 0.0 : sumaVal / valoraciones.docs.length;

      // ANÁLISIS EMPLEADOS (Roles)
      int empProp = 0, empAdmin = 0, empStaff = 0;
      for (var doc in empleados.docs) {
         final d = doc.data() as Map;
         final rol = (d['rol'] ?? '').toString().toLowerCase();
         if (rol.contains('prop') || rol.contains('dueño')) empProp++;
         else if (rol.contains('admin') || rol.contains('encargado')) empAdmin++;
         else empStaff++;
      }

      // Clientes nuevos este mes
      final clientesNuevosMes = clientes.docs.where((doc) {
        final fechaRegistro = (doc.data() as Map)['fecha_registro'];
        if (fechaRegistro is Timestamp) return fechaRegistro.toDate().isAfter(inicioMes);
        if (fechaRegistro is String) return (DateTime.tryParse(fechaRegistro) ?? DateTime(2000)).isAfter(inicioMes);
        return false;
      }).length;

      // Ingresos de pedidos pagados del mes
      final ingresosPedidosMes = pedidosMes.docs
          .where((d) => (d.data() as Map)['estado_pago'] == 'pagado')
          .fold<double>(0, (s, d) => s + (((d.data() as Map)['total'] as num?) ?? 0).toDouble());

      // Ingresos de facturas pagadas del mes
      final ingresosFacturasMes = facturasMes.docs
          .where((d) => (d.data() as Map)['estado'] == 'PAGADA')
          .fold<double>(0, (s, d) => s + (((d.data() as Map)['total'] as num?) ?? 0).toDouble());

      // Visitas web desde Hostinger
      final webData = webResumen.exists ? webResumen.data() as Map<String, dynamic> : {};
      final visitasWeb = (webData['visitas'] as num?)?.toInt() ?? 0;
      final ratingGoogle = (webData['rating_google'] as num?)?.toDouble() ?? 0;
      final totalResenasGoogle = (webData['total_resenas_google'] as num?)?.toInt() ?? 0;

      // Gastos pagados del mes
      final gastosPagadosMes = gastosMes.docs
          .where((d) => (d.data() as Map)['estado'] == 'pagado')
          .fold<double>(0, (s, d) => s + (((d.data() as Map)['total'] as num?) ?? 0).toDouble());

      // Beneficio neto = ingresos facturados - gastos pagados
      final beneficioNetoMes = ingresosFacturasMes - gastosPagadosMes;

      return {
        'total_clientes': clientes.docs.length,
        'clientes_activos': clientes.docs.length, // Simplificación: total como activos si no hay campo específico
        'nuevos_clientes_mes': clientesNuevosMes,
        'total_servicios_activos': servicios.docs.length,
        'total_empleados_activos': empleados.docs.length,
        'valoracion_promedio': valoracionPromedio,
        'total_valoraciones': valoraciones.docs.length,
        'valoraciones_mes': valMes,
        'valoraciones_5_estrellas': val5,
        'valoraciones_4_estrellas': val4,
        'valoraciones_3_estrellas': val3,
        'valoraciones_2_estrellas': val2,
        'valoraciones_1_estrella': val1,
        'empleados_propietarios': empProp,
        'empleados_admin': empAdmin,
        'empleados_staff': empStaff,
        'pedidos_mes': pedidosMes.docs.length,
        'pedidos_pendientes': pedidosMes.docs.where((d) => (d.data() as Map)['estado'] == 'pendiente').length,
        'ingresos_pedidos_mes': ingresosPedidosMes,
        'facturas_mes': facturasMes.docs.length,
        'ingresos_facturas_mes': ingresosFacturasMes,
        'gastos_pagados_mes': gastosPagadosMes,
        'beneficio_neto_mes': beneficioNetoMes,
        'ingresos_totales_mes': ingresosPedidosMes + ingresosFacturasMes,
        'visitas_web': visitasWeb,
        'rating_google': ratingGoogle,
        'total_resenas_google': totalResenasGoogle,
      };
    } catch (e) {
      print('❌ Error calculando métricas básicas: $e');
      return {};
    }
  }

  /// Tendencias simples
  Future<Map<String, dynamic>> _calcularTendencias(String empresaId) async {
    try {
      final hace7Dias = DateTime.now().subtract(const Duration(days: 7));

      // Reservas de los últimos 7 días
      final reservasRecientes = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(hace7Dias))
          .get();

      // Distribución por día de la semana
      final distribucionDias = <String, int>{};
      for (final doc in reservasRecientes.docs) {
        final fecha = (doc.data()['fecha'] as Timestamp?)?.toDate();
        if (fecha != null) {
          final diaSemana = _obtenerDiaSemana(fecha.weekday);
          distribucionDias[diaSemana] = (distribucionDias[diaSemana] ?? 0) + 1;
        }
      }

      // Día más activo
      final diaMasActivo = distribucionDias.entries.isEmpty ? 'N/A' :
          distribucionDias.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      return {
        'reservas_ultima_semana': reservasRecientes.docs.length,
        'dia_mas_activo': diaMasActivo,
        'distribucion_dias': distribucionDias,
      };
    } catch (e) {
      print('❌ Error calculando tendencias: $e');
      return {};
    }
  }

  String _obtenerDiaSemana(int weekday) {
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

  /// Obtener estadísticas desde cache (súper rápido)
  Future<Map<String, dynamic>?> obtenerEstadisticasCache(String empresaId) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('cache')
          .doc('estadisticas')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final ultimaActualizacion = data['fecha_calculo'] != null
            ? (DateTime.tryParse((data['fecha_calculo'] as String).length > 23 ? (data['fecha_calculo'] as String).substring(0, 23) : data['fecha_calculo']) ?? DateTime.now().subtract(const Duration(days: 1)))
            : DateTime.now().subtract(const Duration(days: 1));

        // Si los datos tienen más de 1 hora, recalcular
        final diferencia = DateTime.now().difference(ultimaActualizacion);
        if (diferencia.inHours > 1) {
          print('⚠️ Cache obsoleto (${diferencia.inMinutes} min), recalculando...');
          _calcularYGuardarEstadisticas(empresaId);
        }

        return data;
      }

      // No hay cache, calcular por primera vez
      print('📊 No hay cache, calculando estadísticas por primera vez...');
      _calcularYGuardarEstadisticas(empresaId);
      return null;
    } catch (e) {
      print('❌ Error obteniendo cache de estadísticas: $e');
      return null;
    }
  }

  /// Forzar recálculo manual
  Future<void> recalcularEstadisticas(String empresaId) async {
    print('🔄 Recálculo manual solicitado para $empresaId');
    await _calcularYGuardarEstadisticas(empresaId);
  }

  /// Limpiar cache
  Future<void> limpiarCache(String empresaId) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('cache')
          .doc('estadisticas')
          .delete();

      print('🗑️ Cache limpiado para $empresaId');
    } catch (e) {
      print('❌ Error limpiando cache: $e');
    }
  }

  /// Obtener información del estado del cache
  Stream<Map<String, dynamic>> estadoCache(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('cache')
        .doc('estadisticas')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return {'existe': false, 'calculando': false};
      }

      final data = doc.data()!;
      final ultimaActualizacion = data['fecha_calculo'] != null
          ? (DateTime.tryParse((data['fecha_calculo'] as String).length > 23 ? (data['fecha_calculo'] as String).substring(0, 23) : data['fecha_calculo']) ?? DateTime.now().subtract(const Duration(days: 1)))
          : DateTime.now().subtract(const Duration(days: 1));

      final diferencia = DateTime.now().difference(ultimaActualizacion);
      final esReciente = diferencia.inMinutes < 60;

      return {
        'existe': true,
        'es_reciente': esReciente,
        'ultima_actualizacion': ultimaActualizacion.toIso8601String(),
        'minutos_desde_actualizacion': diferencia.inMinutes,
        'calculando': false,
      };
    });
  }
}
