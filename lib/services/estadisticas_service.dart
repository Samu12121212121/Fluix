import 'package:cloud_firestore/cloud_firestore.dart';

class EstadisticasService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calcular y guardar todas las estadísticas relevantes para el empresario
  Future<void> calcularEstadisticasCompletas(String empresaId) async {
    try {
      print('📊 Calculando estadísticas completas para empresa: $empresaId');

      // Verificar conectividad antes de continuar
      if (await _verificarConectividad()) {
        await _calcularYGuardarEstadisticas(empresaId);
      } else {
        print('⚠️ Sin conexión - usando datos locales');
        await _usarDatosLocales(empresaId);
      }
    } catch (e) {
      print('❌ Error en calcularEstadisticasCompletas: $e');
      // Intentar usar datos locales como fallback
      await _usarDatosLocales(empresaId);
    }
  }

  /// Verificar conectividad con Firebase
  Future<bool> _verificarConectividad() async {
    try {
      await _firestore.doc('test/connection').get();
      return true;
    } catch (e) {
      print('🌐 Sin conexión a Firebase: $e');
      return false;
    }
  }

  /// Usar datos locales como fallback
  Future<void> _usarDatosLocales(String empresaId) async {
    try {
      print('📱 Usando datos locales para estadísticas...');

      // Estadísticas básicas como fallback
      final estadisticasLocales = {
        'ingresos_mes': 0.0,
        'reservas_mes': 0,
        'nuevos_clientes_mes': 0,
        'valoracion_promedio': 0.0,
        'total_clientes': 0,
        'total_servicios_activos': 0,
        'total_empleados_activos': 0,
        'reservas_confirmadas': 0,
        'reservas_completadas': 0,
        'reservas_pendientes': 0,
        'modo_offline': true,
        'ultima_actualizacion': DateTime.now().toIso8601String(),
      };

      // Intentar guardar en cache local si es posible
      print('✅ Estadísticas locales preparadas');
    } catch (e) {
      print('❌ Error en datos locales: $e');
    }
  }

  /// Calcular y guardar estadísticas (método original renombrado)
  Future<void> _calcularYGuardarEstadisticas(String empresaId) async {
    try {
      print('📊 Calculando estadísticas completas para empresa: $empresaId');

      // Obtener datos de los últimos 30 días
      final now = DateTime.now();
      final hace30Dias = now.subtract(const Duration(days: 30));
      final hace60Dias = now.subtract(const Duration(days: 60));
      final inicioMes = DateTime(now.year, now.month, 1);
      final inicioMesAnterior = DateTime(now.year, now.month - 1, 1);

      // Calcular estadísticas de reservas
      final statsReservas = await _calcularEstadisticasReservas(
        empresaId, inicioMes, inicioMesAnterior, hace30Dias, hace60Dias
      );

      // Calcular estadísticas de clientes
      final statsClientes = await _calcularEstadisticasClientes(
        empresaId, inicioMes, inicioMesAnterior, hace30Dias
      );

      // Calcular estadísticas financieras
      final statsFinancieras = await _calcularEstadisticasFinancieras(
        empresaId, inicioMes, inicioMesAnterior
      );

      // Calcular estadísticas de servicios
      final statsServicios = await _calcularEstadisticasServicios(empresaId, hace30Dias);

      // Calcular estadísticas de valoraciones
      final statsValoraciones = await _calcularEstadisticasValoraciones(
        empresaId, inicioMes, inicioMesAnterior
      );

      // Calcular estadísticas de empleados
      final statsEmpleados = await _calcularEstadisticasEmpleados(empresaId, hace30Dias);

      // Combinar todas las estadísticas
      final estadisticasCompletas = {
        // Estadísticas de reservas
        ...statsReservas,

        // Estadísticas de clientes
        ...statsClientes,

        // Estadísticas financieras
        ...statsFinancieras,

        // Estadísticas de servicios
        ...statsServicios,

        // Estadísticas de valoraciones
        ...statsValoraciones,

        // Estadísticas de empleados
        ...statsEmpleados,

        // Metadatos
        'ultima_actualizacion': FieldValue.serverTimestamp(),
        'fecha_calculo': now.toIso8601String(),
      };

      // Guardar en Firestore
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('resumen')
          .set(estadisticasCompletas, SetOptions(merge: true));

      print('✅ Estadísticas calculadas y guardadas correctamente');
    } catch (e) {
      print('❌ Error calculando estadísticas: $e');
      rethrow;
    }
  }

  /// Calcular estadísticas de reservas
  Future<Map<String, dynamic>> _calcularEstadisticasReservas(
    String empresaId,
    DateTime inicioMes,
    DateTime inicioMesAnterior,
    DateTime hace30Dias,
    DateTime hace60Dias
  ) async {
    try {
      // Reservas del mes actual
      final reservasMesQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
          .get();

      // Reservas del mes anterior
      final reservasMesAnteriorQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMesAnterior))
          .where('fecha', isLessThan: Timestamp.fromDate(inicioMes))
          .get();

      // Reservas últimos 30 días
      final reservas30DiasQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(hace30Dias))
          .get();

      final reservasMes = reservasMesQuery.docs.map((doc) => doc.data()).toList();
      final reservasMesAnterior = reservasMesAnteriorQuery.docs.map((doc) => doc.data()).toList();
      final reservas30Dias = reservas30DiasQuery.docs.map((doc) => doc.data()).toList();

      // Calcular métricas de reservas
      final reservasConfirmadas = reservasMes.where((r) => r['estado'] == 'CONFIRMADA').length;
      final reservasCanceladas = reservasMes.where((r) => r['estado'] == 'CANCELADA').length;
      final reservasCompletadas = reservasMes.where((r) => r['estado'] == 'COMPLETADA').length;
      final reservasPendientes = reservasMes.where((r) => r['estado'] == 'PENDIENTE').length;

      final reservasConfirmadasAnterior = reservasMesAnterior.where((r) => r['estado'] == 'CONFIRMADA').length;

      // Tasa de conversión (confirmadas / total)
      final tasaConversion = reservasMes.isEmpty ? 0.0 : (reservasConfirmadas / reservasMes.length * 100);
      final tasaConversionAnterior = reservasMesAnterior.isEmpty ? 0.0 : (reservasConfirmadasAnterior / reservasMesAnterior.length * 100);

      // Tasa de cancelación
      final tasaCancelacion = reservasMes.isEmpty ? 0.0 : (reservasCanceladas / reservasMes.length * 100);

      // Distribución por días de la semana
      final distribucionDias = <String, int>{};
      final diasSemana = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

      for (final reserva in reservas30Dias) {
        final fecha = (reserva['fecha'] as Timestamp).toDate();
        final diaSemana = diasSemana[fecha.weekday - 1];
        distribucionDias[diaSemana] = (distribucionDias[diaSemana] ?? 0) + 1;
      }

      // Horarios más populares
      final horariosPopulares = <String, int>{};
      for (final reserva in reservas30Dias) {
        final hora = reserva['hora_inicio']?.toString() ?? '';
        if (hora.isNotEmpty) {
          horariosPopulares[hora] = (horariosPopulares[hora] ?? 0) + 1;
        }
      }

      final horasPico = horariosPopulares.entries
          .where((e) => e.value > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'reservas_mes': reservasMes.length,
        'reservas_mes_anterior': reservasMesAnterior.length,
        'reservas_confirmadas': reservasConfirmadas,
        'reservas_canceladas': reservasCanceladas,
        'reservas_completadas': reservasCompletadas,
        'reservas_pendientes': reservasPendientes,
        'tasa_conversion': tasaConversion,
        'tasa_conversion_anterior': tasaConversionAnterior,
        'tasa_cancelacion': tasaCancelacion,
        'distribucion_dias': distribucionDias,
        'horas_pico': horasPico.take(3).map((e) => e.key).toList(),
        'dia_mas_activo': distribucionDias.entries.isEmpty ? 'N/A' :
            distribucionDias.entries.reduce((a, b) => a.value > b.value ? a : b).key,
      };
    } catch (e) {
      print('❌ Error calculando estadísticas de reservas: $e');
      return {
        'reservas_mes': 0,
        'reservas_mes_anterior': 0,
        'reservas_confirmadas': 0,
        'reservas_canceladas': 0,
        'reservas_completadas': 0,
        'reservas_pendientes': 0,
        'tasa_conversion': 0.0,
        'tasa_conversion_anterior': 0.0,
        'tasa_cancelacion': 0.0,
        'distribucion_dias': {},
        'horas_pico': [],
        'dia_mas_activo': 'N/A',
      };
    }
  }

  /// Calcular estadísticas de clientes
  Future<Map<String, dynamic>> _calcularEstadisticasClientes(
    String empresaId,
    DateTime inicioMes,
    DateTime inicioMesAnterior,
    DateTime hace30Dias
  ) async {
    try {
      // Clientes nuevos este mes
      final clientesNuevosMesQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('clientes')
          .where('fecha_registro', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
          .get();

      // Clientes nuevos mes anterior
      final clientesNuevosMesAnteriorQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('clientes')
          .where('fecha_registro', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMesAnterior))
          .where('fecha_registro', isLessThan: Timestamp.fromDate(inicioMes))
          .get();

      // Total de clientes
      final totalClientesQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('clientes')
          .get();

      // Clientes activos (con reserva en últimos 30 días)
      final clientesActivosQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('clientes')
          .where('ultima_visita', isGreaterThanOrEqualTo: Timestamp.fromDate(hace30Dias))
          .get();

      // Calcular cliente más valioso
      final clientes = totalClientesQuery.docs.map((doc) => doc.data()).toList();
      final clienteMasValioso = clientes.isEmpty ? null : clientes.reduce((a, b) =>
          (a['total_gastado'] ?? 0) > (b['total_gastado'] ?? 0) ? a : b);

      // Calcular valor promedio por cliente
      final totalGastado = clientes.fold<double>(0, (sum, cliente) => sum + (cliente['total_gastado'] ?? 0));
      final valorPromedioCliente = clientes.isEmpty ? 0.0 : totalGastado / clientes.length;

      // Clientes frecuentes (más de 5 reservas)
      final clientesFrecuentes = clientes.where((c) => (c['numero_reservas'] ?? 0) > 5).length;

      return {
        'nuevos_clientes_mes': clientesNuevosMesQuery.docs.length,
        'nuevos_clientes_mes_anterior': clientesNuevosMesAnteriorQuery.docs.length,
        'total_clientes': totalClientesQuery.docs.length,
        'clientes_activos': clientesActivosQuery.docs.length,
        'clientes_frecuentes': clientesFrecuentes,
        'valor_promedio_cliente': valorPromedioCliente,
        'cliente_mas_valioso': clienteMasValioso?['nombre'] ?? 'N/A',
        'valor_cliente_mas_valioso': clienteMasValioso?['total_gastado'] ?? 0,
      };
    } catch (e) {
      print('❌ Error calculando estadísticas de clientes: $e');
      return {
        'nuevos_clientes_mes': 0,
        'nuevos_clientes_mes_anterior': 0,
        'total_clientes': 0,
        'clientes_activos': 0,
        'clientes_frecuentes': 0,
        'valor_promedio_cliente': 0.0,
        'cliente_mas_valioso': 'N/A',
        'valor_cliente_mas_valioso': 0,
      };
    }
  }

  /// Calcular estadísticas financieras
  Future<Map<String, dynamic>> _calcularEstadisticasFinancieras(
    String empresaId,
    DateTime inicioMes,
    DateTime inicioMesAnterior
  ) async {
    try {
      // Transacciones del mes actual
      final transaccionesMesQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('transacciones')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
          .get();

      // Transacciones del mes anterior
      final transaccionesMesAnteriorQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('transacciones')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMesAnterior))
          .where('fecha', isLessThan: Timestamp.fromDate(inicioMes))
          .get();

      final transaccionesMes = transaccionesMesQuery.docs.map((doc) => doc.data()).toList();
      final transaccionesMesAnterior = transaccionesMesAnteriorQuery.docs.map((doc) => doc.data()).toList();

      // Calcular ingresos
      final ingresosMes = transaccionesMes.fold<double>(0, (sum, t) => sum + (t['monto'] ?? 0));
      final ingresosMesAnterior = transaccionesMesAnterior.fold<double>(0, (sum, t) => sum + (t['monto'] ?? 0));

      // Ticket promedio
      final ticketPromedio = transaccionesMes.isEmpty ? 0.0 : ingresosMes / transaccionesMes.length;
      final ticketPromedioAnterior = transaccionesMesAnterior.isEmpty ? 0.0 : ingresosMesAnterior / transaccionesMesAnterior.length;

      // Métodos de pago más usados
      final metodosPago = <String, int>{};
      for (final transaccion in transaccionesMes) {
        final metodo = transaccion['metodo_pago']?.toString() ?? 'Efectivo';
        metodosPago[metodo] = (metodosPago[metodo] ?? 0) + 1;
      }

      final metodoMasUsado = metodosPago.entries.isEmpty ? 'Efectivo' :
          metodosPago.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      return {
        'ingresos_mes': ingresosMes,
        'ingresos_mes_anterior': ingresosMesAnterior,
        'valor_medio_reserva': ticketPromedio,
        'valor_medio_reserva_anterior': ticketPromedioAnterior,
        'total_transacciones_mes': transaccionesMes.length,
        'metodo_pago_preferido': metodoMasUsado,
        'distribucion_metodos_pago': metodosPago,
      };
    } catch (e) {
      print('❌ Error calculando estadísticas financieras: $e');
      return {
        'ingresos_mes': 0.0,
        'ingresos_mes_anterior': 0.0,
        'valor_medio_reserva': 0.0,
        'valor_medio_reserva_anterior': 0.0,
        'total_transacciones_mes': 0,
        'metodo_pago_preferido': 'Efectivo',
        'distribucion_metodos_pago': {},
      };
    }
  }

  /// Calcular estadísticas de servicios
  Future<Map<String, dynamic>> _calcularEstadisticasServicios(
    String empresaId,
    DateTime hace30Dias
  ) async {
    try {
      // Obtener servicios
      final serviciosQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('servicios')
          .where('activo', isEqualTo: true)
          .get();

      // Reservas por servicio en los últimos 30 días
      final reservasQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(hace30Dias))
          .get();

      final servicios = serviciosQuery.docs.map((doc) => doc.data()).toList();
      final reservas = reservasQuery.docs.map((doc) => doc.data()).toList();

      // Contar reservas por servicio
      final reservasPorServicio = <String, int>{};
      final ingresosPorServicio = <String, double>{};

      for (final reserva in reservas) {
        final servicioId = reserva['servicio_id']?.toString() ?? '';
        final servicio = servicios.firstWhere((s) => s['id'] == servicioId, orElse: () => {});
        final nombreServicio = servicio['nombre']?.toString() ?? 'Servicio desconocido';
        final precioServicio = (servicio['precio'] as num?)?.toDouble() ?? 0.0;

        reservasPorServicio[nombreServicio] = (reservasPorServicio[nombreServicio] ?? 0) + 1;
        ingresosPorServicio[nombreServicio] = (ingresosPorServicio[nombreServicio] ?? 0) + precioServicio;
      }

      // Servicio más popular
      final servicioMasPopular = reservasPorServicio.entries.isEmpty ? 'N/A' :
          reservasPorServicio.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      // Servicio más rentable
      final servicioMasRentable = ingresosPorServicio.entries.isEmpty ? 'N/A' :
          ingresosPorServicio.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      return {
        'total_servicios_activos': servicios.length,
        'servicio_mas_popular': servicioMasPopular,
        'servicio_mas_rentable': servicioMasRentable,
        'reservas_por_servicio': reservasPorServicio,
        'ingresos_por_servicio': ingresosPorServicio,
      };
    } catch (e) {
      print('❌ Error calculando estadísticas de servicios: $e');
      return {
        'total_servicios_activos': 0,
        'servicio_mas_popular': 'N/A',
        'servicio_mas_rentable': 'N/A',
        'reservas_por_servicio': {},
        'ingresos_por_servicio': {},
      };
    }
  }

  /// Calcular estadísticas de valoraciones
  Future<Map<String, dynamic>> _calcularEstadisticasValoraciones(
    String empresaId,
    DateTime inicioMes,
    DateTime inicioMesAnterior
  ) async {
    try {
      // Valoraciones del mes actual
      final valoracionesMesQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
          .get();

      // Todas las valoraciones para promedio general
      final todasValoracionesQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones')
          .get();

      final valoracionesMes = valoracionesMesQuery.docs.map((doc) => doc.data()).toList();
      final todasValoraciones = todasValoracionesQuery.docs.map((doc) => doc.data()).toList();

      // Calcular promedio general
      final totalValoraciones = todasValoraciones.length;
      final sumaCalificaciones = todasValoraciones.fold<double>(0, (sum, v) => sum + ((v['calificacion'] as num?) ?? 0).toDouble());
      final promedioGeneral = totalValoraciones == 0 ? 0.0 : sumaCalificaciones / totalValoraciones;

      // Distribución de calificaciones
      final distribucionCalificaciones = <int, int>{};
      for (final val in todasValoraciones) {
        final calificacion = ((val['calificacion'] as num?) ?? 0).toInt();
        distribucionCalificaciones[calificacion] = (distribucionCalificaciones[calificacion] ?? 0) + 1;
      }

      // Valoraciones recientes (últimas 5)
      final valoracionesRecientes = todasValoraciones
          .where((v) => v['fecha'] != null)
          .toList()
        ..sort((a, b) => (b['fecha'] as Timestamp).compareTo(a['fecha'] as Timestamp));

      return {
        'valoracion_promedio': promedioGeneral,
        'total_valoraciones': totalValoraciones,
        'valoraciones_mes': valoracionesMes.length,
        'distribucion_calificaciones': distribucionCalificaciones,
        'valoraciones_5_estrellas': distribucionCalificaciones[5] ?? 0,
        'valoraciones_4_estrellas': distribucionCalificaciones[4] ?? 0,
        'valoraciones_3_estrellas': distribucionCalificaciones[3] ?? 0,
        'valoraciones_2_estrellas': distribucionCalificaciones[2] ?? 0,
        'valoraciones_1_estrella': distribucionCalificaciones[1] ?? 0,
        'valoraciones_recientes': valoracionesRecientes.take(5).map((v) => {
          'cliente': v['cliente']?.toString() ?? '',
          'calificacion': ((v['calificacion'] as num?) ?? 0).toInt(),
          'comentario': v['comentario']?.toString() ?? '',
          'fecha': (v['fecha'] as Timestamp?)?.toDate().toIso8601String() ?? '',
        }).toList(),
      };
    } catch (e) {
      print('❌ Error calculando estadísticas de valoraciones: $e');
      return {
        'valoracion_promedio': 0.0,
        'total_valoraciones': 0,
        'valoraciones_mes': 0,
        'distribucion_calificaciones': {},
        'valoraciones_5_estrellas': 0,
        'valoraciones_4_estrellas': 0,
        'valoraciones_3_estrellas': 0,
        'valoraciones_2_estrellas': 0,
        'valoraciones_1_estrella': 0,
        'valoraciones_recientes': [],
      };
    }
  }

  /// Calcular estadísticas de empleados
  Future<Map<String, dynamic>> _calcularEstadisticasEmpleados(
    String empresaId,
    DateTime hace30Dias
  ) async {
    try {
      // Obtener empleados activos
      final empleadosQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('empleados')
          .where('activo', isEqualTo: true)
          .get();

      // Reservas asignadas a empleados en últimos 30 días
      final reservasEmpleadosQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(hace30Dias))
          .where('empleado_asignado', isNotEqualTo: null)
          .get();

      final empleados = empleadosQuery.docs.map((doc) => doc.data()).toList();
      final reservasEmpleados = reservasEmpleadosQuery.docs.map((doc) => doc.data()).toList();

      // Rendimiento por empleado
      final rendimientoEmpleados = <String, Map<String, dynamic>>{};
      for (final empleado in empleados) {
        final nombreEmpleado = empleado['nombre']?.toString() ?? 'Sin nombre';
        final empleadoId = empleado['id']?.toString() ?? '';
        final reservasEmpleado = reservasEmpleados.where((r) => r['empleado_asignado']?.toString() == empleadoId).length;

        rendimientoEmpleados[nombreEmpleado] = {
          'reservas': reservasEmpleado,
          'rol': empleado['rol']?.toString() ?? 'STAFF',
        };
      }

      // Empleado más activo
      final empleadoMasActivo = rendimientoEmpleados.entries.isEmpty ? 'N/A' :
          rendimientoEmpleados.entries.reduce((a, b) =>
              a.value['reservas'] > b.value['reservas'] ? a : b).key;

      return {
        'total_empleados_activos': empleados.length,
        'empleado_mas_activo': empleadoMasActivo,
        'rendimiento_empleados': rendimientoEmpleados,
        'empleados_propietarios': empleados.where((e) => e['rol']?.toString() == 'PROPIETARIO').length,
        'empleados_admin': empleados.where((e) => e['rol']?.toString() == 'ADMIN').length,
        'empleados_staff': empleados.where((e) => e['rol']?.toString() == 'STAFF').length,
      };
    } catch (e) {
      print('❌ Error calculando estadísticas de empleados: $e');
      return {
        'total_empleados_activos': 0,
        'empleado_mas_activo': 'N/A',
        'rendimiento_empleados': {},
        'empleados_propietarios': 0,
        'empleados_admin': 0,
        'empleados_staff': 0,
      };
    }
  }

  /// Obtener estadísticas desde Firebase
  Future<Map<String, dynamic>?> obtenerEstadisticas(String empresaId) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('resumen')
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return null;
    }
  }

  /// Programar actualización automática de estadísticas
  void programarActualizacionAutomatica(String empresaId) {
    // Actualizar estadísticas cada hora
    Stream.periodic(const Duration(hours: 1)).listen((_) {
      calcularEstadisticasCompletas(empresaId);
    });
  }
}
