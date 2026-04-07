import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/modelos/cliente.dart';

/// Servicio para calcular y actualizar el estado de los clientes
/// (Contacto / Activo / Inactivo) basado en su última actividad.
class ClienteEstadoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _clientes(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('clientes');

  // ── OBTENER UMBRAL DE INACTIVIDAD ─────────────────────────────────────────

  /// Devuelve el umbral en días configurado por la empresa (default 90).
  Future<int> obtenerUmbralDias(String empresaId) async {
    final doc = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('clientes')
        .get();
    return doc.data()?['umbral_inactividad_dias'] ?? 90;
  }

  /// Guarda el umbral de inactividad en días.
  Future<void> guardarUmbralDias(String empresaId, int dias) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('clientes')
        .set({'umbral_inactividad_dias': dias}, SetOptions(merge: true));
  }

  // ── CALCULAR ESTADO DE UN CLIENTE ─────────────────────────────────────────

  /// Calcula el estado basándose en la última actividad del cliente.
  /// Consulta facturas, reservas y pedidos para encontrar la más reciente.
  Future<EstadoCliente> calcularEstado({
    required String empresaId,
    required String clienteId,
    required String clienteNombre,
    String? clienteCorreo,
    int umbralDias = 90,
  }) async {
    final ultimaActividad = await _obtenerUltimaActividad(
      empresaId: empresaId,
      clienteId: clienteId,
      clienteNombre: clienteNombre,
      clienteCorreo: clienteCorreo,
    );

    if (ultimaActividad == null) return EstadoCliente.contacto;

    final diasSinActividad = DateTime.now().difference(ultimaActividad).inDays;
    return diasSinActividad <= umbralDias
        ? EstadoCliente.activo
        : EstadoCliente.inactivo;
  }

  /// Busca la fecha de la última actividad del cliente en facturas, reservas y pedidos.
  Future<DateTime?> _obtenerUltimaActividad({
    required String empresaId,
    required String clienteId,
    required String clienteNombre,
    String? clienteCorreo,
  }) async {
    DateTime? ultima;

    // 1. Última factura (busca por nombre del cliente)
    final factSnap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas')
        .where('cliente_nombre', isEqualTo: clienteNombre)
        .orderBy('fecha_emision', descending: true)
        .limit(1)
        .get();
    if (factSnap.docs.isNotEmpty) {
      final f = factSnap.docs.first.data();
      final fecha = f['fecha_emision'];
      if (fecha is Timestamp) {
        ultima = fecha.toDate();
      } else if (fecha is String) {
        ultima = DateTime.tryParse(fecha);
      }
    }

    // 2. Última reserva/cita
    final resSnap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('reservas')
        .where('cliente_id', isEqualTo: clienteId)
        .orderBy('fecha_hora', descending: true)
        .limit(1)
        .get();
    if (resSnap.docs.isNotEmpty) {
      final r = resSnap.docs.first.data();
      final fecha = r['fecha_hora'];
      DateTime? fechaRes;
      if (fecha is Timestamp) {
        fechaRes = fecha.toDate();
      } else if (fecha is String) {
        fechaRes = DateTime.tryParse(fecha);
      }
      if (fechaRes != null && (ultima == null || fechaRes.isAfter(ultima))) {
        ultima = fechaRes;
      }
    }

    // 3. Último pedido
    final pedSnap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos')
        .where('cliente_nombre', isEqualTo: clienteNombre)
        .orderBy('fecha_creacion', descending: true)
        .limit(1)
        .get();
    if (pedSnap.docs.isNotEmpty) {
      final p = pedSnap.docs.first.data();
      final fecha = p['fecha_creacion'];
      DateTime? fechaPed;
      if (fecha is Timestamp) {
        fechaPed = fecha.toDate();
      } else if (fecha is String) {
        fechaPed = DateTime.tryParse(fecha);
      }
      if (fechaPed != null && (ultima == null || fechaPed.isAfter(ultima))) {
        ultima = fechaPed;
      }
    }

    return ultima;
  }

  // ── ACTUALIZAR ESTADO DE UN CLIENTE ───────────────────────────────────────

  Future<void> actualizarEstadoCliente({
    required String empresaId,
    required String clienteId,
    required String clienteNombre,
    String? clienteCorreo,
  }) async {
    final umbral = await obtenerUmbralDias(empresaId);
    final estado = await calcularEstado(
      empresaId: empresaId,
      clienteId: clienteId,
      clienteNombre: clienteNombre,
      clienteCorreo: clienteCorreo,
      umbralDias: umbral,
    );

    final ultimaAct = await _obtenerUltimaActividad(
      empresaId: empresaId,
      clienteId: clienteId,
      clienteNombre: clienteNombre,
      clienteCorreo: clienteCorreo,
    );

    await _clientes(empresaId).doc(clienteId).update({
      'estado_cliente': estado.name,
      'ultima_actividad': ultimaAct?.toIso8601String(),
    });
  }

  // ── ACTUALIZAR TODOS LOS ESTADOS (para Cloud Function nocturna) ───────────

  /// Recalcula el estado de TODOS los clientes de una empresa.
  /// Retorna el número de clientes actualizados.
  Future<int> recalcularTodosLosEstados(String empresaId) async {
    final umbral = await obtenerUmbralDias(empresaId);
    final clientesSnap = await _clientes(empresaId)
        .where('estado_fusionado', isEqualTo: false)
        .get();

    int actualizados = 0;
    // Firestore batch max 500
    final batchSize = 450;
    WriteBatch batch = _db.batch();
    int batchCount = 0;

    for (final doc in clientesSnap.docs) {
      final data = doc.data();
      final nombre = data['nombre'] ?? '';
      final correo = data['correo']?.toString();

      final estado = await calcularEstado(
        empresaId: empresaId,
        clienteId: doc.id,
        clienteNombre: nombre,
        clienteCorreo: correo,
        umbralDias: umbral,
      );

      final ultimaAct = await _obtenerUltimaActividad(
        empresaId: empresaId,
        clienteId: doc.id,
        clienteNombre: nombre,
        clienteCorreo: correo,
      );

      final estadoAnterior = data['estado_cliente'] ?? 'contacto';
      if (estadoAnterior != estado.name) {
        batch.update(doc.reference, {
          'estado_cliente': estado.name,
          'ultima_actividad': ultimaAct?.toIso8601String(),
        });
        batchCount++;
        actualizados++;

        if (batchCount >= batchSize) {
          await batch.commit();
          batch = _db.batch();
          batchCount = 0;
        }
      }
    }

    if (batchCount > 0) await batch.commit();
    return actualizados;
  }

  // ── OBTENER CLIENTES SILENCIOSOS ──────────────────────────────────────────

  /// Devuelve clientes sin actividad en más de [umbralDias] días,
  /// excluyendo los marcados como noContactar y fusionados.
  Future<List<Map<String, dynamic>>> obtenerClientesSilenciosos(
    String empresaId, {
    int? umbralDiasOverride,
  }) async {
    final umbral = umbralDiasOverride ?? await obtenerUmbralInactividad(empresaId);
    final limite = DateTime.now().subtract(Duration(days: umbral));

    final snap = await _clientes(empresaId)
        .where('estado_fusionado', isEqualTo: false)
        .where('no_contactar', isEqualTo: false)
        .get();

    final silenciosos = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final ultimaAct = data['ultima_actividad'] != null
          ? DateTime.tryParse(data['ultima_actividad'])
          : null;
      final ultimaVis = data['ultima_visita'] != null
          ? DateTime.tryParse(data['ultima_visita'])
          : null;

      final ultima = ultimaAct ?? ultimaVis;

      // Si tiene actividad pero es antigua, o si nunca tuvo actividad
      // pero fue creado hace más de umbral días
      if (ultima != null && ultima.isBefore(limite)) {
        final diasInactivo = DateTime.now().difference(ultima).inDays;
        silenciosos.add({
          'id': doc.id,
          ...data,
          'dias_inactivo': diasInactivo,
          'ultima_actividad_real': ultima.toIso8601String(),
        });
      }
    }

    // Ordenar por más antiguo primero
    silenciosos.sort((a, b) =>
        (b['dias_inactivo'] as int).compareTo(a['dias_inactivo'] as int));

    return silenciosos;
  }

  /// Obtener umbral de inactividad para alertas (default 60 días).
  Future<int> obtenerUmbralInactividad(String empresaId) async {
    final doc = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('clientes')
        .get();
    return doc.data()?['umbral_alerta_inactividad_dias'] ?? 60;
  }

  /// Guardar umbral de inactividad para alertas.
  Future<void> guardarUmbralInactividad(String empresaId, int dias) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('clientes')
        .set(
      {'umbral_alerta_inactividad_dias': dias},
      SetOptions(merge: true),
    );
  }
}

