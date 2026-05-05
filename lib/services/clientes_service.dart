import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../domain/modelos/interaccion_cliente.dart';

// ── ETIQUETAS DEL SISTEMA ─────────────────────────────────────────────────────

/// Etiquetas predefinidas disponibles para todos los clientes.
const kEtiquetasPredefinidas = [
  'VIP',
  'Frecuente',
  'Moroso',
  'Proveedor',
  'Potencial',
];

// ── OPCIONES DE FILTROS ───────────────────────────────────────────────────────

/// Opciones de filtro por volumen de facturación (label, valor mínimo).
const kOpcionesFacturacion = [
  (label: '>500 €', value: 500.0),
  (label: '>1.000 €', value: 1000.0),
  (label: '>5.000 €', value: 5000.0),
];

/// Opciones de filtro por última actividad.
/// Valores positivos = activo en los últimos N meses.
/// Valores negativos = inactivo (sin visita en los últimos |N| meses).
const kOpcionesActividad = [
  (label: 'Últimos 30 días', value: 1),
  (label: 'Últimos 3 meses', value: 3),
  (label: 'Últimos 6 meses', value: 6),
  (label: 'Sin actividad +6 m', value: -6),
];

// ── SERVICIO ──────────────────────────────────────────────────────────────────

class ClientesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── COLECCIONES ──────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _clientes(String empresaId) =>
      _firestore.collection('empresas').doc(empresaId).collection('clientes');

  DocumentReference<Map<String, dynamic>> _docEtiquetas(String empresaId) =>
      _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('etiquetas_clientes');

  // ── FILTRADO LOCAL ────────────────────────────────────────────────────────────

  /// Filtra la lista de documentos de clientes aplicando todos los criterios.
  ///
  /// - [textoBusqueda]: filtra por nombre, teléfono o correo (case-insensitive).
  /// - [etiquetasActivas]: muestra clientes que tengan AL MENOS UNA de las etiquetas.
  /// - [minFacturacion]: importe mínimo de `total_gastado`.
  /// - [mesesActividad]: positivo → activo en los últimos N meses;
  ///                     negativo → sin visita en los últimos |N| meses.
  /// - [localidad]: filtra por campo `localidad` o, como fallback, `direccion`.
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

      // ── Búsqueda de texto ──────────────────────────────────────────────────
      if (textoBusqueda.isNotEmpty) {
        final q = textoBusqueda.toLowerCase();
        final nombre = (d['nombre'] ?? '').toString().toLowerCase();
        final tel = (d['telefono'] ?? '').toString().toLowerCase();
        final correo = (d['correo'] ?? '').toString().toLowerCase();
        if (!nombre.contains(q) && !tel.contains(q) && !correo.contains(q)) {
          return false;
        }
      }

      // ── Etiquetas (OR: debe tener alguna de las activas) ───────────────────
      if (etiquetasActivas.isNotEmpty) {
        final etiquetas = List<String>.from(d['etiquetas'] ?? []);
        if (!etiquetasActivas.any((e) => etiquetas.contains(e))) return false;
      }

      // ── Volumen de facturación ─────────────────────────────────────────────
      if (minFacturacion != null) {
        final total = ((d['total_gastado'] ?? 0.0) as num).toDouble();
        if (total < minFacturacion) return false;
      }

      // ── Última actividad ───────────────────────────────────────────────────
      if (mesesActividad != null) {
        final visStr = d['ultima_visita'] as String?;
        final ultimaVisita = visStr != null ? DateTime.tryParse(visStr) : null;
        final limite =
            DateTime.now().subtract(Duration(days: mesesActividad.abs() * 30));

        if (mesesActividad > 0) {
          // activo: ultima_visita dentro del rango
          if (ultimaVisita == null || ultimaVisita.isBefore(limite)) {
            return false;
          }
        } else {
          // inactivo: sin visita en los últimos |N| meses
          if (ultimaVisita != null && ultimaVisita.isAfter(limite)) {
            return false;
          }
        }
      }

      // ── Localidad ─────────────────────────────────────────────────────────
      if (localidad.isNotEmpty) {
        final loc = (d['localidad'] ?? d['direccion'] ?? '')
            .toString()
            .toLowerCase();
        if (!loc.contains(localidad.toLowerCase())) return false;
      }

      return true;
    }).toList();
  }

  // ── ETIQUETAS PERSONALIZADAS DE EMPRESA ──────────────────────────────────────

  /// Stream de etiquetas personalizadas guardadas a nivel de empresa.
  Stream<List<String>> watchEtiquetasCustom(String empresaId) =>
      _docEtiquetas(empresaId).snapshots().map((snap) {
        if (!snap.exists) return [];
        return List<String>.from(snap.data()?['lista'] ?? []);
      });

  /// Añade una etiqueta personalizada al catálogo de la empresa.
  Future<void> agregarEtiquetaCustom(
      String empresaId, String etiqueta) async {
    final tag = etiqueta.trim();
    if (tag.isEmpty || kEtiquetasPredefinidas.contains(tag)) return;
    await _docEtiquetas(empresaId).set(
      {'lista': FieldValue.arrayUnion([tag])},
      SetOptions(merge: true),
    );
  }

  /// Elimina una etiqueta personalizada del catálogo de la empresa.
  Future<void> eliminarEtiquetaCustom(
      String empresaId, String etiqueta) async {
    await _docEtiquetas(empresaId).set(
      {'lista': FieldValue.arrayRemove([etiqueta])},
      SetOptions(merge: true),
    );
  }

  /// Sobreescribe las etiquetas de un cliente concreto.
  Future<void> actualizarEtiquetasCliente(
      String empresaId, String clienteId, List<String> etiquetas) async {
    await _clientes(empresaId)
        .doc(clienteId)
        .update({'etiquetas': etiquetas});
  }

  // ── INTERACCIONES CRM ─────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _interacciones(
          String empresaId, String clienteId) =>
      _clientes(empresaId)
          .doc(clienteId)
          .collection('interacciones');

  /// Stream en tiempo real de todas las interacciones de un cliente,
  /// ordenadas por fecha descendente.
  Stream<List<InteraccionCliente>> watchInteracciones(
      String empresaId, String clienteId) {
    return _interacciones(empresaId, clienteId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(InteraccionCliente.fromFirestore).toList());
  }

  /// Registra una nueva interacción para el cliente indicado.
  Future<void> agregarInteraccion(
      String empresaId,
      String clienteId,
      InteraccionCliente interaccion,
  ) async {
    await _interacciones(empresaId, clienteId).add(interaccion.toMap());
    // Actualizar fecha de última interacción en el doc del cliente
    await _clientes(empresaId).doc(clienteId).set(
      {'ultima_interaccion': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ── UTILIDADES VISUALES ───────────────────────────────────────────────────────

  /// Color asociado a cada etiqueta (predefinida o personalizada).
  static Color colorEtiqueta(String tag) {
    switch (tag) {
      case 'VIP':
        return const Color(0xFF7B1FA2);
      case 'Frecuente':
        return const Color(0xFFF57C00);
      case 'Moroso':
        return const Color(0xFFD32F2F);
      case 'Proveedor':
        return const Color(0xFF0D47A1);
      case 'Potencial':
        return const Color(0xFF00796B);
      default:
        return const Color(0xFF607D8B);
    }
  }

  /// Icono asociado a cada etiqueta (predefinida o personalizada).
  static IconData iconoEtiqueta(String tag) {
    switch (tag) {
      case 'VIP':
        return Icons.diamond;
      case 'Frecuente':
        return Icons.star;
      case 'Moroso':
        return Icons.warning_amber;
      case 'Proveedor':
        return Icons.business;
      case 'Potencial':
        return Icons.trending_up;
      default:
        return Icons.label_outline;
    }
  }
}

