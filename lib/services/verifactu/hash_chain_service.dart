import 'package:cloud_firestore/cloud_firestore.dart';
import 'modelos_verifactu.dart';
import '../../domain/modelos/factura.dart';

/// Gestiona el encadenamiento criptográfico de registros Verifactu.
///
/// Usa los modelos canónicos de [modelos_verifactu.dart] y persiste
/// la cadena en Firestore bajo `empresas/{id}/registros_verifactu`.
///
/// Normativa: RD 1007/2023 Bloque 6 (SHA-256 encadenado).
class HashChainService {
  final String empresaId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  HashChainService(this.empresaId);

  CollectionReference<Map<String, dynamic>> get _registros =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('registros_verifactu');

  // ── LECTURA ───────────────────────────────────────────────────────────────

  /// Obtiene la referencia al último registro de la cadena para usarla como
  /// `registroAnterior` en el siguiente alta.
  Future<ReferenceRegistroAnterior> obtenerReferenciaAnterior(
      String nifEmisor) async {
    final snap = await _registros
        .where('nif_emisor', isEqualTo: nifEmisor)
        .where('tipo', isEqualTo: 'alta')
        .orderBy('fecha_hora_generacion', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return ReferenceRegistroAnterior.primerRegistro();
    }

    final data = snap.docs.first.data();
    final hash = data['hash'] as String? ?? '';
    return ReferenceRegistroAnterior(
      nifEmisor: data['nif_emisor'] ?? '',
      numeroSerie: data['numero_serie'] ?? '',
      numeroFactura: data['numero_factura'] ?? '',
      fechaExpedicion: _parseTs(data['fecha_expedicion']),
      hash64Caracteres:
          hash.length >= 64 ? hash.substring(0, 64) : hash.padRight(64, '0'),
    );
  }

  /// Devuelve los primeros 64 chars del hash del último registro (compat).
  Future<String> obtenerUltimoHash(String nifEmisor) async {
    final ref = await obtenerReferenciaAnterior(nifEmisor);
    return ref.esPrimerRegistro ? '' : ref.hash64Caracteres;
  }

  // ── CONSTRUCCIÓN ─────────────────────────────────────────────────────────

  /// Construye un [RegistroFacturacionAlta] desde una [Factura] usando
  /// los modelos canónicos de RD 1007/2023.
  RegistroFacturacionAlta construirRegistroAlta({
    required Factura factura,
    required String nifEmisor,
    required ReferenceRegistroAnterior registroAnterior,
    required DateTime ahora,
  }) {
    final tipo = _mapearTipoFactura(factura);
    return RegistroFacturacionAlta(
      nifEmisor: nifEmisor,
      numeroSerie: factura.serie.prefijo,
      numeroFactura: _extraerNumero(factura.numeroFactura),
      fechaExpedicion: factura.fechaEmision,
      tipoFactura: tipo,
      descripcion: 'Factura ${factura.numeroFactura}',
      importeTotal: factura.total,
      cuotaTotal: factura.totalIva,
      desglosePorTipo: _construirDesglose(factura),
      claveRegimen: ClaveRegimen.general,
      calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
      registroAnterior: registroAnterior,
      fechaHoraGeneracion: ahora,
      zonaHoraria: '+01:00',
      esVerifactu: true,
    );
  }

  // ── VALIDACIÓN ────────────────────────────────────────────────────────────

  /// Verifica que el último registro almacenado sea íntegro (hash válido).
  Future<bool> verificarIntegridadUltimoRegistro(String nifEmisor) async {
    final snap = await _registros
        .where('nif_emisor', isEqualTo: nifEmisor)
        .where('tipo', isEqualTo: 'alta')
        .orderBy('fecha_hora_generacion', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return true;

    final hash = snap.docs.first.data()['hash'] as String? ?? '';
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(hash);
  }

  // ── ESCRITURA ─────────────────────────────────────────────────────────────

  /// Guarda el registro en Firestore como parte de la cadena auditada.
  Future<void> guardarRegistroAlta(RegistroFacturacionAlta registro) async {
    await _registros.add({
      'tipo': 'alta',
      'nif_emisor': registro.nifEmisor,
      'numero_serie': registro.numeroSerie,
      'numero_factura': registro.numeroFactura,
      'fecha_expedicion': Timestamp.fromDate(registro.fechaExpedicion),
      'tipo_factura': registro.tipoFactura.codigo,
      'importe_total': registro.importeTotal,
      'cuota_total': registro.cuotaTotal,
      'hash': registro.hash,
      'hash_64': registro.hash64,
      'es_primer_registro': registro.registroAnterior.esPrimerRegistro,
      'hash_anterior': registro.registroAnterior.hash64Caracteres,
      'fecha_hora_generacion':
          Timestamp.fromDate(registro.fechaHoraGeneracion),
      'zona_horaria': registro.zonaHoraria,
      'es_verifactu': registro.esVerifactu,
    });
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  TipoFacturaVeri _mapearTipoFactura(Factura factura) {
    if (factura.esRectificativa) return TipoFacturaVeri.r1;
    if (factura.total < 400 && (factura.datosFiscales?.nif ?? '').isEmpty) {
      return TipoFacturaVeri.f2;
    }
    return TipoFacturaVeri.f1;
  }

  /// Extrae el número final de la cadena "FAC-2027-0001" → "0001".
  String _extraerNumero(String numeroFactura) {
    final partes = numeroFactura.split('-');
    return partes.last;
  }

  Map<String, double> _construirDesglose(Factura factura) {
    final desglose = <String, double>{};
    for (final linea in factura.lineas) {
      final clave = linea.porcentajeIva.toInt().toString().padLeft(2, '0');
      desglose[clave] = (desglose[clave] ?? 0) + linea.subtotalSinIva;
    }
    return desglose;
  }

  DateTime _parseTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

