import 'package:cloud_firestore/cloud_firestore.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PROVEEDOR
// ═════════════════════════════════════════════════════════════════════════════

class Proveedor {
  final String id;
  final String nombre;
  final String? nif;
  final String? email;
  final String? telefono;
  final String? direccion;
  final String? ciudad;
  final String? codigoPostal;
  final String categoria; // 'suministros', 'servicios', 'software', 'alquiler', etc.
  final bool activo;
  final bool esIntracomunitario;
  final String? nifIvaComunitario;
  final DateTime fechaAlta;
  final String? notas;

  const Proveedor({
    required this.id,
    required this.nombre,
    this.nif,
    this.email,
    this.telefono,
    this.direccion,
    this.ciudad,
    this.codigoPostal,
    this.categoria = 'general',
    this.activo = true,
    this.esIntracomunitario = false,
    this.nifIvaComunitario,
    required this.fechaAlta,
    this.notas,
  });

  factory Proveedor.fromMap(Map<String, dynamic> m) => Proveedor(
    id:           m['id'] as String? ?? '',
    nombre:       m['nombre'] as String? ?? '',
    nif:          m['nif'] as String?,
    email:        m['email'] as String?,
    telefono:     m['telefono'] as String?,
    direccion:    m['direccion'] as String?,
    ciudad:       m['ciudad'] as String?,
    codigoPostal: m['codigo_postal'] as String?,
    categoria:    m['categoria'] as String? ?? 'general',
    activo:       m['activo'] as bool? ?? true,
    esIntracomunitario: m['es_intracomunitario'] as bool? ?? false,
    nifIvaComunitario: m['nif_iva_comunitario'] as String?,
    fechaAlta:    _parseDate(m['fecha_alta']),
    notas:        m['notas'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    if (nif != null) 'nif': nif,
    if (email != null) 'email': email,
    if (telefono != null) 'telefono': telefono,
    if (direccion != null) 'direccion': direccion,
    if (ciudad != null) 'ciudad': ciudad,
    if (codigoPostal != null) 'codigo_postal': codigoPostal,
    'categoria': categoria,
    'activo': activo,
    'es_intracomunitario': esIntracomunitario,
    if (nifIvaComunitario != null) 'nif_iva_comunitario': nifIvaComunitario,
    'fecha_alta': Timestamp.fromDate(fechaAlta),
    if (notas != null) 'notas': notas,
  };

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GASTO EMPRESARIAL
// ═════════════════════════════════════════════════════════════════════════════

enum CategoriaGasto {
  suministros,
  servicios,
  alquiler,
  software,
  marketing,
  personal,
  transporte,
  equipamiento,
  formacion,
  seguros,
  gestor,
  otros,
}

extension CategoriaGastoExt on CategoriaGasto {
  String get nombre {
    switch (this) {
      case CategoriaGasto.suministros:  return 'Suministros';
      case CategoriaGasto.servicios:    return 'Servicios externos';
      case CategoriaGasto.alquiler:     return 'Alquiler';
      case CategoriaGasto.software:     return 'Software / SaaS';
      case CategoriaGasto.marketing:    return 'Marketing';
      case CategoriaGasto.personal:     return 'Personal / Nóminas';
      case CategoriaGasto.transporte:   return 'Transporte';
      case CategoriaGasto.equipamiento: return 'Equipamiento';
      case CategoriaGasto.formacion:    return 'Formación';
      case CategoriaGasto.seguros:      return 'Seguros';
      case CategoriaGasto.gestor:       return 'Gestoría / Asesoría';
      case CategoriaGasto.otros:        return 'Otros';
    }
  }

  static CategoriaGasto fromId(String id) {
    return CategoriaGasto.values.firstWhere(
      (e) => e.name == id,
      orElse: () => CategoriaGasto.otros,
    );
  }
}

enum EstadoGasto { pendiente, pagado, anulado }

class Gasto {
  final String id;
  final String empresaId;
  final String concepto;
  final CategoriaGasto categoria;
  final String? proveedorId;
  final String? proveedorNombre;
  final String? numeroFacturaProveedor; // Nº factura recibida
  final double baseImponible;
  final double porcentajeIva;   // IVA soportado deducible
  final double importeIva;
  final double total;
  final EstadoGasto estado;
  final DateTime fechaGasto;
  final DateTime? fechaPago;
  final String? metodoPago;
  final bool ivaDeducible;      // Algunos gastos no tienen IVA deducible
  final String? notas;
  final String? facturaArchivoUrl; // URL del PDF/imagen de la factura
  final DateTime fechaCreacion;
  final String creadoPor;

  const Gasto({
    required this.id,
    required this.empresaId,
    required this.concepto,
    required this.categoria,
    this.proveedorId,
    this.proveedorNombre,
    this.numeroFacturaProveedor,
    required this.baseImponible,
    this.porcentajeIva = 21.0,
    required this.importeIva,
    required this.total,
    this.estado = EstadoGasto.pendiente,
    required this.fechaGasto,
    this.fechaPago,
    this.metodoPago,
    this.ivaDeducible = true,
    this.notas,
    this.facturaArchivoUrl,
    required this.fechaCreacion,
    this.creadoPor = '',
  });

  factory Gasto.fromMap(Map<String, dynamic> m) => Gasto(
    id:                       m['id'] as String? ?? '',
    empresaId:                m['empresa_id'] as String? ?? '',
    concepto:                 m['concepto'] as String? ?? '',
    categoria:                CategoriaGastoExt.fromId(m['categoria'] as String? ?? 'otros'),
    proveedorId:              m['proveedor_id'] as String?,
    proveedorNombre:          m['proveedor_nombre'] as String?,
    numeroFacturaProveedor:   m['numero_factura_proveedor'] as String?,
    baseImponible:            (m['base_imponible'] as num?)?.toDouble() ?? 0,
    porcentajeIva:            (m['porcentaje_iva'] as num?)?.toDouble() ?? 21.0,
    importeIva:               (m['importe_iva'] as num?)?.toDouble() ?? 0,
    total:                    (m['total'] as num?)?.toDouble() ?? 0,
    estado:                   EstadoGasto.values.firstWhere(
      (e) => e.name == (m['estado'] as String?),
      orElse: () => EstadoGasto.pendiente,
    ),
    fechaGasto:               _parseDate(m['fecha_gasto']),
    fechaPago:                m['fecha_pago'] != null ? _parseDate(m['fecha_pago']) : null,
    metodoPago:               m['metodo_pago'] as String?,
    ivaDeducible:             m['iva_deducible'] as bool? ?? true,
    notas:                    m['notas'] as String?,
    facturaArchivoUrl:        m['factura_archivo_url'] as String?,
    fechaCreacion:            _parseDate(m['fecha_creacion']),
    creadoPor:                m['creado_por'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'empresa_id': empresaId,
    'concepto': concepto,
    'categoria': categoria.name,
    if (proveedorId != null) 'proveedor_id': proveedorId,
    if (proveedorNombre != null) 'proveedor_nombre': proveedorNombre,
    if (numeroFacturaProveedor != null)
      'numero_factura_proveedor': numeroFacturaProveedor,
    'base_imponible': baseImponible,
    'porcentaje_iva': porcentajeIva,
    'importe_iva': importeIva,
    'total': total,
    'estado': estado.name,
    'fecha_gasto': Timestamp.fromDate(fechaGasto),
    if (fechaPago != null) 'fecha_pago': Timestamp.fromDate(fechaPago!),
    if (metodoPago != null) 'metodo_pago': metodoPago,
    'iva_deducible': ivaDeducible,
    if (notas != null) 'notas': notas,
    if (facturaArchivoUrl != null) 'factura_archivo_url': facturaArchivoUrl,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    'creado_por': creadoPor,
  };

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RESUMEN CONTABLE TRIMESTRAL / ANUAL
// ═════════════════════════════════════════════════════════════════════════════

class ResumenContable {
  final int anio;
  final int? trimestre; // null = anual
  final int? mes;

  // IVA REPERCUTIDO (facturas emitidas)
  final double baseImponibleEmitida;
  final double ivaRepercutido;
  final double totalFacturado;

  // IVA SOPORTADO (gastos con factura)
  final double baseImponibleRecibida;
  final double ivaSoportado;
  final double totalGastado;

  // RESULTADO IVA (modelo 303)
  double get ivaAIngresar => ivaRepercutido - ivaSoportado;
  bool get hayDevolucion => ivaAIngresar < 0;

  // RESULTADO (para IRPF / IS)
  double get beneficioNeto => baseImponibleEmitida - baseImponibleRecibida;
  bool get hayBeneficio => beneficioNeto > 0;

  // PAGO A CUENTA IRPF (modelo 130) — 20% del beneficio neto positivo
  double get pagoFraccionadoIRPF =>
      hayBeneficio ? beneficioNeto * 0.20 : 0;

  // Estadísticas
  final int numFacturasEmitidas;
  final int numGastos;
  final int numFacturasPendientes;

  const ResumenContable({
    required this.anio,
    this.trimestre,
    this.mes,
    required this.baseImponibleEmitida,
    required this.ivaRepercutido,
    required this.totalFacturado,
    required this.baseImponibleRecibida,
    required this.ivaSoportado,
    required this.totalGastado,
    required this.numFacturasEmitidas,
    required this.numGastos,
    required this.numFacturasPendientes,
  });

  String get periodo {
    if (mes != null) {
      const meses = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo',
        'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre',
        'Noviembre', 'Diciembre'];
      return '${meses[mes!]} $anio';
    }
    if (trimestre != null) return 'T$trimestre/$anio';
    return 'Anual $anio';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LÍNEA DEL LIBRO CONTABLE (para exportación)
// ═════════════════════════════════════════════════════════════════════════════

class LineaLibroContable {
  final String tipo; // 'ingreso' | 'gasto'
  final DateTime fecha;
  final String numero;
  final String concepto;
  final String? nifContraparte;
  final String? nombreContraparte;
  final double baseImponible;
  final double porcentajeIva;
  final double importeIva;
  final double total;
  final String estado;

  const LineaLibroContable({
    required this.tipo,
    required this.fecha,
    required this.numero,
    required this.concepto,
    this.nifContraparte,
    this.nombreContraparte,
    required this.baseImponible,
    required this.porcentajeIva,
    required this.importeIva,
    required this.total,
    required this.estado,
  });

  /// Fila CSV
  String toCsvRow() {
    String _esc(String? s) {
      if (s == null) return '';
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }
    final d = fecha;
    final fechaStr = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    return [
      _esc(tipo),
      _esc(fechaStr),
      _esc(numero),
      _esc(concepto),
      _esc(nifContraparte),
      _esc(nombreContraparte),
      baseImponible.toStringAsFixed(2),
      porcentajeIva.toStringAsFixed(0),
      importeIva.toStringAsFixed(2),
      total.toStringAsFixed(2),
      _esc(estado),
    ].join(',');
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DATO MENSUAL — para gráficos de evolución anual
// ═════════════════════════════════════════════════════════════════════════════

class DatoMensual {
  final int mes;
  final double ingresos;
  final double gastos;

  double get beneficio => ingresos - gastos;
  bool get hayBeneficio => beneficio >= 0;

  const DatoMensual({
    required this.mes,
    required this.ingresos,
    required this.gastos,
  });

  static const List<String> _nombresMes = [
    '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  String get nombreCorto => _nombresMes[mes];
}

// ═════════════════════════════════════════════════════════════════════════════
// MODELO FISCAL — representa un modelo trimestral (303, 130)
// ═════════════════════════════════════════════════════════════════════════════

enum EstadoAlertaFiscal { ok, proximo, vencido }

class ModeloFiscalTrimestral {
  final int anio;
  final int trimestre;
  final ResumenContable resumen;

  const ModeloFiscalTrimestral({
    required this.anio,
    required this.trimestre,
    required this.resumen,
  });

  DateTime get fechaLimite {
    switch (trimestre) {
      case 1: return DateTime(anio, 4, 20);
      case 2: return DateTime(anio, 7, 20);
      case 3: return DateTime(anio, 10, 20);
      case 4: return DateTime(anio + 1, 1, 30);
      default: return DateTime(anio, 4, 20);
    }
  }

  DateTime get _finTrimestre {
    final mesInicio = (trimestre - 1) * 3 + 1;
    return DateTime(anio, mesInicio + 3, 1);
  }

  EstadoAlertaFiscal get estadoAlerta {
    final ahora = DateTime.now();
    final deadline = fechaLimite;
    if (ahora.isBefore(_finTrimestre)) return EstadoAlertaFiscal.ok;
    if (ahora.isAfter(deadline)) return EstadoAlertaFiscal.vencido;
    if (deadline.difference(ahora).inDays <= 15) return EstadoAlertaFiscal.proximo;
    return EstadoAlertaFiscal.ok;
  }

  double get ivaRepercutido => resumen.ivaRepercutido;
  double get ivaSoportado => resumen.ivaSoportado;
  double get resultadoIva => resumen.ivaAIngresar;
  bool get hayDevolucionIva => resumen.hayDevolucion;

  double get beneficioNeto => resumen.beneficioNeto;
  double get pagoFraccionadoIrpf => resumen.pagoFraccionadoIRPF;
  bool get hayBeneficio => resumen.hayBeneficio;

  String get nombreTrimestre => 'T$trimestre/$anio';

  String get periodoTexto {
    const meses = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    final mesInicio = (trimestre - 1) * 3 + 1;
    final mesFin = mesInicio + 2;
    return '${meses[mesInicio]} – ${meses[mesFin]} $anio';
  }

  String get fechaLimiteTexto {
    final d = fechaLimite;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
