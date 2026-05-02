import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── ETIQUETAS DEL SISTEMA ─────────────────────────────────────────────────────

const kEtiquetasPredefinidas = [
  'VIP',
  'Frecuente',
  'Moroso',
  'Proveedor',
  'Potencial',
];

// ── OPCIONES DE FILTROS ───────────────────────────────────────────────────────

const kOpcionesFacturacion = [
  (label: '>500 €', value: 500.0),
  (label: '>1.000 €', value: 1000.0),
  (label: '>5.000 €', value: 5000.0),
];

const kOpcionesActividad = [
  (label: 'Últimos 30 días', value: 1),
  (label: 'Últimos 3 meses', value: 3),
  (label: 'Últimos 6 meses', value: 6),
  (label: 'Sin actividad +6 m', value: -6),
];

// ── FIX: TIPO DE INTERACCIÓN ──────────────────────────────────────────────────
// Enum necesario por modulo_clientes_screen.dart

enum TipoInteraccion {
  llamada,
  email,
  whatsapp,
  nota,
  reunion,
  reserva;

  String get label {
    switch (this) {
      case TipoInteraccion.llamada:   return 'Llamada';
      case TipoInteraccion.email:     return 'Email';
      case TipoInteraccion.whatsapp:  return 'WhatsApp';
      case TipoInteraccion.nota:      return 'Nota';
      case TipoInteraccion.reunion:   return 'Reunión';
      case TipoInteraccion.reserva:   return 'Reserva';
    }
  }

  /// Serializa a string para Firestore
  String get value => name;

  /// Deserializa desde string de Firestore
  static TipoInteraccion fromString(String s) {
    return TipoInteraccion.values.firstWhere(
          (e) => e.name == s,
      orElse: () => TipoInteraccion.nota,
    );
  }
}

// ── FIX: MODELO INTERACCIÓN CLIENTE ──────────────────────────────────────────

class InteraccionCliente {
  final String id;
  final TipoInteraccion tipo;
  final DateTime fecha;
  final String descripcion;
  final String usuarioNombre;

  const InteraccionCliente({
    required this.id,
    required this.tipo,
    required this.fecha,
    required this.descripcion,
    required this.usuarioNombre,
  });

  factory InteraccionCliente.fromMap(String id, Map<String, dynamic> m) {
    DateTime fecha;
    final raw = m['fecha'];
    if (raw is Timestamp) {
      fecha = raw.toDate();
    } else if (raw is String) {
      fecha = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      fecha = DateTime.now();
    }

    return InteraccionCliente(
      id: id,
      tipo: TipoInteraccion.fromString(m['tipo'] as String? ?? 'nota'),
      fecha: fecha,
      descripcion: (m['descripcion'] as String? ?? '').toString(),
      usuarioNombre: (m['usuario_nombre'] as String? ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'tipo':           tipo.value,
    'fecha':          Timestamp.fromDate(fecha),
    'descripcion':    descripcion,
    'usuario_nombre': usuarioNombre,
  };
}

// ── SERVICIO ──────────────────────────────────────────────────────────────────

class ClientesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _clientes(String empresaId) =>
      _firestore.collection('empresas').doc(empresaId).collection('clientes');

  DocumentReference<Map<String, dynamic>> _docEtiquetas(String empresaId) =>
      _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('etiquetas_clientes');

  // ── FIX: watchInteracciones ───────────────────────────────────────────────

  /// Stream en tiempo real de las interacciones de un cliente.
  Stream<List<InteraccionCliente>> watchInteracciones(
      String empresaId, String clienteId) {
    return _clientes(empresaId)
        .doc(clienteId)
        .collection('interacciones')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => InteraccionCliente.fromMap(d.id, d.data()))
        .toList());
  }

  // ── FIX: agregarInteraccion ───────────────────────────────────────────────

  /// Añade una nueva interacción al historial de un cliente.
  Future<void> agregarInteraccion(
      String empresaId,
      String clienteId,
      InteraccionCliente interaccion,
      ) async {
    await _clientes(empresaId)
        .doc(clienteId)
        .collection('interacciones')
        .add(interaccion.toMap());

    // Actualizar campo ultima_interaccion en el documento del cliente
    await _clientes(empresaId).doc(clienteId).update({
      'ultima_interaccion': FieldValue.serverTimestamp(),
    });
  }

  // ── FILTRADO LOCAL ────────────────────────────────────────────────────────

  static List<QueryDocumentSnapshot> filtrarClientes({
    required List<QueryDocumentSnapshot> docs,
    String textoBusqueda = '',
    Set<String> etiquetasActivas = const {},
    double? minFacturacion,
    int? mesesActividad,
    String localidad = '',
  }) {
    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;

      if (textoBusqueda.isNotEmpty) {
        final q = textoBusqueda.toLowerCase();
        final nombre = (d['nombre'] ?? '').toString().toLowerCase();
        final tel = (d['telefono'] ?? '').toString().toLowerCase();
        final correo = (d['correo'] ?? '').toString().toLowerCase();
        if (!nombre.contains(q) && !tel.contains(q) && !correo.contains(q)) {
          return false;
        }
      }

      if (etiquetasActivas.isNotEmpty) {
        final etiquetas = List<String>.from(d['etiquetas'] ?? []);
        if (!etiquetasActivas.any((e) => etiquetas.contains(e))) return false;
      }

      if (minFacturacion != null) {
        final total = ((d['total_gastado'] ?? 0.0) as num).toDouble();
        if (total < minFacturacion) return false;
      }

      if (mesesActividad != null) {
        final visStr = d['ultima_visita'] as String?;
        final ultimaVisita = visStr != null ? DateTime.tryParse(visStr) : null;
        final limite =
        DateTime.now().subtract(Duration(days: mesesActividad.abs() * 30));

        if (mesesActividad > 0) {
          if (ultimaVisita == null || ultimaVisita.isBefore(limite)) {
            return false;
          }
        } else {
          if (ultimaVisita != null && ultimaVisita.isAfter(limite)) {
            return false;
          }
        }
      }

      if (localidad.isNotEmpty) {
        final loc = (d['localidad'] ?? d['direccion'] ?? '')
            .toString()
            .toLowerCase();
        if (!loc.contains(localidad.toLowerCase())) return false;
      }

      return true;
    }).toList();
  }

  // ── ETIQUETAS PERSONALIZADAS ──────────────────────────────────────────────

  Stream<List<String>> watchEtiquetasCustom(String empresaId) =>
      _docEtiquetas(empresaId).snapshots().map((snap) {
        if (!snap.exists) return [];
        return List<String>.from(snap.data()?['lista'] ?? []);
      });

  Future<void> agregarEtiquetaCustom(
      String empresaId, String etiqueta) async {
    final tag = etiqueta.trim();
    if (tag.isEmpty || kEtiquetasPredefinidas.contains(tag)) return;
    await _docEtiquetas(empresaId).set(
      {'lista': FieldValue.arrayUnion([tag])},
      SetOptions(merge: true),
    );
  }

  Future<void> eliminarEtiquetaCustom(
      String empresaId, String etiqueta) async {
    await _docEtiquetas(empresaId).set(
      {'lista': FieldValue.arrayRemove([etiqueta])},
      SetOptions(merge: true),
    );
  }

  Future<void> actualizarEtiquetasCliente(
      String empresaId, String clienteId, List<String> etiquetas) async {
    await _clientes(empresaId)
        .doc(clienteId)
        .update({'etiquetas': etiquetas});
  }

  // ── UTILIDADES VISUALES ───────────────────────────────────────────────────

  static Color colorEtiqueta(String tag) {
    switch (tag) {
      case 'VIP':       return const Color(0xFF7B1FA2);
      case 'Frecuente': return const Color(0xFFF57C00);
      case 'Moroso':    return const Color(0xFFD32F2F);
      case 'Proveedor': return const Color(0xFF0D47A1);
      case 'Potencial': return const Color(0xFF00796B);
      default:          return const Color(0xFF607D8B);
    }
  }

  static IconData iconoEtiqueta(String tag) {
    switch (tag) {
      case 'VIP':       return Icons.diamond;
      case 'Frecuente': return Icons.star;
      case 'Moroso':    return Icons.warning_amber;
      case 'Proveedor': return Icons.business;
      case 'Potencial': return Icons.trending_up;
      default:          return Icons.label_outline;
    }
  }
}