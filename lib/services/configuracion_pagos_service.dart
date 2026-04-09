import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de configuración de pagos de una empresa.
class ConfiguracionPagos {
  // ── Stripe ───────────────────────────────────────────────────────────────
  final bool stripeConectado;
  final String? stripeAccountId;
  final String? stripeDisplayName;
  final DateTime? stripeFechaConexion;

  // ── Redsys (TPV bancario) ────────────────────────────────────────────────
  final bool redsysConectado;
  final String? redsysMerchantCode;
  final String? redsysTerminal;
  final DateTime? redsysFechaConexion;

  // ── PSD2 / Open Banking ──────────────────────────────────────────────────
  final bool bancoConectado;
  final String? bancoId;        // 'caixabank', 'santander', 'bbva'...
  final String? bancoNombre;
  final String? bancoIban;
  final DateTime? bancoFechaConexion;
  final DateTime? bancoFechaExpiracion;

  // ── Métodos de cobro aceptados ───────────────────────────────────────────
  final bool aceptaTarjeta;
  final bool aceptaBizum;
  final bool aceptaTransferencia;
  final bool aceptaEfectivo;
  final bool aceptaPaypal;

  const ConfiguracionPagos({
    this.stripeConectado = false,
    this.stripeAccountId,
    this.stripeDisplayName,
    this.stripeFechaConexion,
    this.redsysConectado = false,
    this.redsysMerchantCode,
    this.redsysTerminal,
    this.redsysFechaConexion,
    this.bancoConectado = false,
    this.bancoId,
    this.bancoNombre,
    this.bancoIban,
    this.bancoFechaConexion,
    this.bancoFechaExpiracion,
    this.aceptaTarjeta = true,
    this.aceptaBizum = false,
    this.aceptaTransferencia = false,
    this.aceptaEfectivo = true,
    this.aceptaPaypal = false,
  });

  factory ConfiguracionPagos.fromFirestore(Map<String, dynamic> d) {
    return ConfiguracionPagos(
      stripeConectado: d['stripe_conectado'] as bool? ?? false,
      stripeAccountId: d['stripe_account_id'] as String?,
      stripeDisplayName: d['stripe_display_name'] as String?,
      stripeFechaConexion: (d['stripe_fecha_conexion'] as Timestamp?)?.toDate(),
      redsysConectado: d['redsys_conectado'] as bool? ?? false,
      redsysMerchantCode: d['redsys_merchant_code'] as String?,
      redsysTerminal: d['redsys_terminal'] as String?,
      redsysFechaConexion: (d['redsys_fecha_conexion'] as Timestamp?)?.toDate(),
      bancoConectado: d['banco_conectado'] as bool? ?? false,
      bancoId: d['banco_id'] as String?,
      bancoNombre: d['banco_nombre'] as String?,
      bancoIban: d['banco_iban'] as String?,
      bancoFechaConexion: (d['banco_fecha_conexion'] as Timestamp?)?.toDate(),
      bancoFechaExpiracion: (d['banco_fecha_expiracion'] as Timestamp?)?.toDate(),
      aceptaTarjeta: d['acepta_tarjeta'] as bool? ?? true,
      aceptaBizum: d['acepta_bizum'] as bool? ?? false,
      aceptaTransferencia: d['acepta_transferencia'] as bool? ?? false,
      aceptaEfectivo: d['acepta_efectivo'] as bool? ?? true,
      aceptaPaypal: d['acepta_paypal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'stripe_conectado': stripeConectado,
    'stripe_account_id': stripeAccountId,
    'stripe_display_name': stripeDisplayName,
    if (stripeFechaConexion != null)
      'stripe_fecha_conexion': Timestamp.fromDate(stripeFechaConexion!),
    'redsys_conectado': redsysConectado,
    'redsys_merchant_code': redsysMerchantCode,
    'redsys_terminal': redsysTerminal,
    if (redsysFechaConexion != null)
      'redsys_fecha_conexion': Timestamp.fromDate(redsysFechaConexion!),
    'banco_conectado': bancoConectado,
    'banco_id': bancoId,
    'banco_nombre': bancoNombre,
    'banco_iban': bancoIban,
    if (bancoFechaConexion != null)
      'banco_fecha_conexion': Timestamp.fromDate(bancoFechaConexion!),
    if (bancoFechaExpiracion != null)
      'banco_fecha_expiracion': Timestamp.fromDate(bancoFechaExpiracion!),
    'acepta_tarjeta': aceptaTarjeta,
    'acepta_bizum': aceptaBizum,
    'acepta_transferencia': aceptaTransferencia,
    'acepta_efectivo': aceptaEfectivo,
    'acepta_paypal': aceptaPaypal,
  };

  /// Días que faltan para que expire la conexión bancaria PSD2.
  int? get diasHastaExpiracionBanco {
    if (bancoFechaExpiracion == null) return null;
    return bancoFechaExpiracion!.difference(DateTime.now()).inDays;
  }

  bool get bancoProximoAExpirar {
    final d = diasHastaExpiracionBanco;
    return d != null && d <= 7 && d > 0;
  }

  bool get bancoExpirado {
    final d = diasHastaExpiracionBanco;
    return d != null && d <= 0;
  }
}

/// Servicio Firestore para la configuración de pagos de cada empresa.
class ConfiguracionPagosService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String empresaId) =>
      _fs.collection('empresas').doc(empresaId)
          .collection('configuracion').doc('pagos');

  /// Lee la configuración actual.
  Future<ConfiguracionPagos> obtener(String empresaId) async {
    final snap = await _ref(empresaId).get();
    if (!snap.exists) return const ConfiguracionPagos();
    return ConfiguracionPagos.fromFirestore(snap.data()!);
  }

  /// Stream en tiempo real.
  Stream<ConfiguracionPagos> stream(String empresaId) {
    return _ref(empresaId).snapshots().map((snap) {
      if (!snap.exists) return const ConfiguracionPagos();
      return ConfiguracionPagos.fromFirestore(snap.data()!);
    });
  }

  /// Guarda la configuración completa (merge).
  Future<void> guardar(String empresaId, ConfiguracionPagos config) async {
    await _ref(empresaId).set(config.toFirestore(), SetOptions(merge: true));
  }

  // ── Acciones específicas ─────────────────────────────────────────────────

  /// Conectar Stripe (tras OAuth callback).
  Future<void> conectarStripe(String empresaId, {
    required String accountId,
    String? displayName,
  }) async {
    await _ref(empresaId).set({
      'stripe_conectado': true,
      'stripe_account_id': accountId,
      'stripe_display_name': displayName,
      'stripe_fecha_conexion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Desconectar Stripe.
  Future<void> desconectarStripe(String empresaId) async {
    await _ref(empresaId).set({
      'stripe_conectado': false,
      'stripe_account_id': null,
      'stripe_display_name': null,
      'stripe_fecha_conexion': null,
    }, SetOptions(merge: true));
  }

  /// Conectar Redsys (TPV).
  Future<void> conectarRedsys(String empresaId, {
    required String merchantCode,
    required String terminal,
  }) async {
    await _ref(empresaId).set({
      'redsys_conectado': true,
      'redsys_merchant_code': merchantCode,
      'redsys_terminal': terminal,
      'redsys_fecha_conexion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Desconectar Redsys.
  Future<void> desconectarRedsys(String empresaId) async {
    await _ref(empresaId).set({
      'redsys_conectado': false,
      'redsys_merchant_code': null,
      'redsys_terminal': null,
      'redsys_fecha_conexion': null,
    }, SetOptions(merge: true));
  }

  /// Conectar banco PSD2.
  Future<void> conectarBanco(String empresaId, {
    required String bancoId,
    required String bancoNombre,
    String? iban,
    required DateTime fechaExpiracion,
  }) async {
    await _ref(empresaId).set({
      'banco_conectado': true,
      'banco_id': bancoId,
      'banco_nombre': bancoNombre,
      'banco_iban': iban,
      'banco_fecha_conexion': FieldValue.serverTimestamp(),
      'banco_fecha_expiracion': Timestamp.fromDate(fechaExpiracion),
    }, SetOptions(merge: true));
  }

  /// Desconectar banco.
  Future<void> desconectarBanco(String empresaId) async {
    await _ref(empresaId).set({
      'banco_conectado': false,
      'banco_id': null,
      'banco_nombre': null,
      'banco_iban': null,
      'banco_fecha_conexion': null,
      'banco_fecha_expiracion': null,
    }, SetOptions(merge: true));
  }

  /// Actualizar métodos de cobro aceptados.
  Future<void> actualizarMetodosCobro(String empresaId, {
    bool? tarjeta,
    bool? bizum,
    bool? transferencia,
    bool? efectivo,
    bool? paypal,
  }) async {
    final data = <String, dynamic>{};
    if (tarjeta != null) data['acepta_tarjeta'] = tarjeta;
    if (bizum != null) data['acepta_bizum'] = bizum;
    if (transferencia != null) data['acepta_transferencia'] = transferencia;
    if (efectivo != null) data['acepta_efectivo'] = efectivo;
    if (paypal != null) data['acepta_paypal'] = paypal;
    if (data.isNotEmpty) {
      await _ref(empresaId).set(data, SetOptions(merge: true));
    }
  }
}

