 import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de evento del historial de actividad.
enum TipoEventoActividad {
  facturaEmitida,
  facturaCobrada,
  citaCreada,
  citaCompletada,
  citaCancelada,
  pedidoCreado,
  pedidoEntregado,
  emailEnviado,
  notaManual,
  // ── Tareas vinculadas ──────────────────────────────────────
  tareaCreada,
  tareaCompletada,
  tareaVencida,
}

/// Subtipos para notas manuales.
enum TipoNotaManual { llamada, visita, email, notaInterna }

class ActividadCliente {
  final String id;
  final String clienteId;
  final TipoEventoActividad tipo;
  final String descripcion;
  final DateTime fecha;

  /// ID del documento relacionado (factura, pedido, reserva)
  final String? documentoId;

  /// Datos adicionales del evento
  final double? importe;
  final String? estado;
  final String? servicio;
  final String? profesional;
  final String? numeroFactura;

  // Nota manual
  final TipoNotaManual? tipoNota;
  final String? textoNota;
  final String? creadoPorId;
  final String? creadoPorNombre;

  const ActividadCliente({
    required this.id,
    required this.clienteId,
    required this.tipo,
    required this.descripcion,
    required this.fecha,
    this.documentoId,
    this.importe,
    this.estado,
    this.servicio,
    this.profesional,
    this.numeroFactura,
    this.tipoNota,
    this.textoNota,
    this.creadoPorId,
    this.creadoPorNombre,
  });

  factory ActividadCliente.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActividadCliente(
      id: doc.id,
      clienteId: d['cliente_id'] ?? '',
      tipo: TipoEventoActividad.values.firstWhere(
        (e) => e.name == d['tipo'],
        orElse: () => TipoEventoActividad.notaManual,
      ),
      descripcion: d['descripcion'] ?? '',
      fecha: d['fecha'] is Timestamp
          ? (d['fecha'] as Timestamp).toDate()
          : DateTime.parse(d['fecha'] ?? DateTime.now().toIso8601String()),
      documentoId: d['documento_id'],
      importe: (d['importe'] as num?)?.toDouble(),
      estado: d['estado'],
      servicio: d['servicio'],
      profesional: d['profesional'],
      numeroFactura: d['numero_factura'],
      tipoNota: d['tipo_nota'] != null
          ? TipoNotaManual.values.firstWhere(
              (e) => e.name == d['tipo_nota'],
              orElse: () => TipoNotaManual.notaInterna,
            )
          : null,
      textoNota: d['texto_nota'],
      creadoPorId: d['creado_por_id'],
      creadoPorNombre: d['creado_por_nombre'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'cliente_id': clienteId,
        'tipo': tipo.name,
        'descripcion': descripcion,
        'fecha': Timestamp.fromDate(fecha),
        'documento_id': documentoId,
        'importe': importe,
        'estado': estado,
        'servicio': servicio,
        'profesional': profesional,
        'numero_factura': numeroFactura,
        'tipo_nota': tipoNota?.name,
        'texto_nota': textoNota,
        'creado_por_id': creadoPorId,
        'creado_por_nombre': creadoPorNombre,
      };
}

