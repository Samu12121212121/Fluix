import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoCupon { porcentaje, importe, bono }

class Cupon {
  final String id;
  final String empresaId;
  final String codigo;
  final TipoCupon tipo;
  final double valor;
  final double? minCompra;
  final DateTime? caducidad;
  final int? usosMax;
  final int usosActuales;
  final bool activo;

  const Cupon({
    required this.id,
    required this.empresaId,
    required this.codigo,
    required this.tipo,
    required this.valor,
    this.minCompra,
    this.caducidad,
    this.usosMax,
    this.usosActuales = 0,
    this.activo = true,
  });

  bool get esBono => tipo == TipoCupon.bono;
  bool get expirado => caducidad != null && DateTime.now().isAfter(caducidad!);
  bool get agotado => usosMax != null && usosActuales >= usosMax!;
  bool get valido => activo && !expirado && !agotado;

  double calcularDescuento(double totalBase) {
    if (!valido) return 0;
    if (minCompra != null && totalBase < minCompra!) return 0;
    if (tipo == TipoCupon.porcentaje) return totalBase * valor / 100;
    return valor.clamp(0, totalBase);
  }

  factory Cupon.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Cupon(
      id: doc.id,
      empresaId: d['empresa_id'] as String? ?? '',
      codigo: d['codigo'] as String? ?? '',
      tipo: TipoCupon.values.firstWhere(
        (t) => t.name == d['tipo'],
        orElse: () => TipoCupon.importe,
      ),
      valor: (d['valor'] as num?)?.toDouble() ?? 0,
      minCompra: (d['min_compra'] as num?)?.toDouble(),
      caducidad: d['caducidad'] != null
          ? (d['caducidad'] as Timestamp).toDate()
          : null,
      usosMax: (d['usos_max'] as num?)?.toInt(),
      usosActuales: (d['usos_actuales'] as num?)?.toInt() ?? 0,
      activo: d['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'codigo': codigo,
    'tipo': tipo.name,
    'valor': valor,
    'min_compra': minCompra,
    'caducidad': caducidad != null ? Timestamp.fromDate(caducidad!) : null,
    'usos_max': usosMax,
    'usos_actuales': usosActuales,
    'activo': activo,
  };

  Cupon copyWith({
    String? id,
    String? empresaId,
    String? codigo,
    TipoCupon? tipo,
    double? valor,
    double? minCompra,
    DateTime? caducidad,
    int? usosMax,
    int? usosActuales,
    bool? activo,
  }) => Cupon(
    id: id ?? this.id,
    empresaId: empresaId ?? this.empresaId,
    codigo: codigo ?? this.codigo,
    tipo: tipo ?? this.tipo,
    valor: valor ?? this.valor,
    minCompra: minCompra ?? this.minCompra,
    caducidad: caducidad ?? this.caducidad,
    usosMax: usosMax ?? this.usosMax,
    usosActuales: usosActuales ?? this.usosActuales,
    activo: activo ?? this.activo,
  );
}
