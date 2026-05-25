import 'package:cloud_firestore/cloud_firestore.dart';

/// Línea de comanda (agregada a la comanda abierta)
class LineaComanda {
  final String productoId;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double ivaPorcentaje;
  final String? notas;
  final bool esNuevo; // badge "nuevo" en UI

  const LineaComanda({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    this.ivaPorcentaje = 21,
    this.notas,
    this.esNuevo = false,
  });

  double get total => precioUnitario * cantidad;
  double get baseImponible => total / (1 + ivaPorcentaje / 100);
  double get  cuotaIva => total - baseImponible;

  factory LineaComanda.fromMap(Map<String, dynamic> m) => LineaComanda(
    productoId: m['producto_id'] as String?
        ?? m['productoId'] as String? ?? '',
    nombre: m['nombre'] as String? ?? '',
    cantidad: (m['cantidad'] as num?)?.toInt() ?? 1,
    precioUnitario: (m['precio_unitario'] as num?)?.toDouble()
        ?? (m['precioUnitario'] as num?)?.toDouble() ?? 0,
    ivaPorcentaje: (m['iva_porcentaje'] as num?)?.toDouble()
        ?? (m['ivaPorcentaje'] as num?)?.toDouble() ?? 21,
    notas: m['notas'] as String?,
    esNuevo: m['es_nuevo'] as bool? ?? m['esNuevo'] as bool? ?? false,
  );


  Map<String, dynamic> toMap() => {
    'producto_id': productoId,
    'nombre': nombre,
    'cantidad': cantidad,
    'precio_unitario': precioUnitario,
    'iva_porcentaje': ivaPorcentaje,
    'subtotal': total,
    'notas': notas,
    'es_nuevo': esNuevo,
  };

  LineaComanda copyWith({
    int? cantidad,
    double? precioUnitario,
    double? ivaPorcentaje,
    String? notas,
    bool clearNotas = false,
    bool? esNuevo,
  }) => LineaComanda(
    productoId: productoId,
    nombre: nombre,
    cantidad: cantidad ?? this.cantidad,
    precioUnitario: precioUnitario ?? this.precioUnitario,
    ivaPorcentaje: ivaPorcentaje ?? this.ivaPorcentaje,
    notas: clearNotas ? null : (notas ?? this.notas),
    esNuevo: esNuevo ?? this.esNuevo,
  );
}

/// Comanda abierta (tab) de una mesa o caja rápida
class Comanda {
  final String id;
  final String? mesaId;
  final String camareroUid;
  final List<LineaComanda> lineas;
  final String estado; // abierta | cobrada
  final Timestamp apertura;
  final double importeTotal;
  final double? descuento;      // importe € descontado
  final double? descuentoPct;   // porcentaje (5, 10, 15…)
  final String? notaGeneral;    // nota libre de toda la comanda

  const Comanda({
    required this.id,
    this.mesaId,
    required this.camareroUid,
    required this.lineas,
    required this.estado,
    required this.apertura,
    required this.importeTotal,
    this.descuento,
    this.descuentoPct,
    this.notaGeneral,
  });

  bool get esAbierta => estado == 'abierta';
  bool get esCobrada => estado == 'cobrada';
  bool get esCajaRapida => mesaId == null;

  double get total => (lineas.fold(0.0, (sum, l) => sum + l.total) - (descuento ?? 0)).clamp(0.0, double.infinity);
  double get baseImponible => lineas.fold(0.0, (sum, l) => sum + l.baseImponible);
  double get cuotaIva => lineas.fold(0.0, (sum, l) => sum + l.cuotaIva);

  factory Comanda.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final lineasRaw = data['lineas'] as List? ?? [];
    return Comanda(
      id: doc.id,
      mesaId: data['mesa_id'] as String?,
      camareroUid: data['camarero_uid'] as String? ?? '',
      lineas: lineasRaw
          .whereType<Map>()
          .map((m) => LineaComanda.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      estado: data['estado'] as String? ?? 'abierta',
      apertura: data['apertura'] as Timestamp? ?? Timestamp.now(),
      importeTotal: (data['importe_total'] as num?)?.toDouble() ?? 0,
      descuento: (data['descuento'] as num?)?.toDouble(),
      descuentoPct: (data['descuento_pct'] as num?)?.toDouble(),
      notaGeneral: data['nota_general'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'mesa_id': mesaId,
    'camarero_uid': camareroUid,
    'lineas': lineas.map((l) => l.toMap()).toList(),
    'estado': estado,
    'apertura': apertura,
    'importe_total': importeTotal,
    'descuento': descuento,
    'descuento_pct': descuentoPct,
    'nota_general': notaGeneral,
  };

  Comanda copyWith({
    String? mesaId,
    List<LineaComanda>? lineas,
    String? estado,
    double? importeTotal,
    double? descuento,
    bool clearDescuento = false,
    double? descuentoPct,
    String? notaGeneral,
    bool clearNota = false,
  }) => Comanda(
    id: id,
    mesaId: mesaId ?? this.mesaId,
    camareroUid: camareroUid,
    lineas: lineas ?? this.lineas,
    estado: estado ?? this.estado,
    apertura: apertura,
    importeTotal: importeTotal ?? this.importeTotal,
    descuento: clearDescuento ? null : (descuento ?? this.descuento),
    descuentoPct: clearDescuento ? null : (descuentoPct ?? this.descuentoPct),
    notaGeneral: clearNota ? null : (notaGeneral ?? this.notaGeneral),
  );
}







