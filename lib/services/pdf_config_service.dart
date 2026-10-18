import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/modelos/pdf_configuracion.dart';

// ── PdfConfigService ──────────────────────────────────────────────────────────
// Carga y guarda PdfConfiguracion en empresas/{empresaId}/configuracion/pdf.
// Cachea en memoria por empresa; se invalida al guardar.
// Si el documento no existe, intenta migrar desde los campos raíz de la empresa.

class PdfConfigService {
  static final _db  = FirebaseFirestore.instance;
  static final _cache = <String, PdfConfiguracion>{};

  static DocumentReference<Map<String, dynamic>> _ref(String empresaId) =>
      _db.collection('empresas').doc(empresaId)
          .collection('configuracion').doc('pdf');

  // ── Cargar (con caché) ────────────────────────────────────────────────────

  static Future<PdfConfiguracion> cargar(String empresaId) async {
    if (_cache.containsKey(empresaId)) return _cache[empresaId]!;
    try {
      final doc = await _ref(empresaId).get();
      if (doc.exists && doc.data() != null) {
        final cfg = PdfConfiguracion.fromMap(doc.data()!);
        _cache[empresaId] = cfg;
        return cfg;
      }
    } catch (e) {
      debugPrint('⚠️ [PdfConfig] Error cargando: $e');
    }
    // Si no existe, migrar desde datos de empresa existentes
    final cfg = await _migrar(empresaId);
    return cfg;
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  static Future<void> guardar(String empresaId, PdfConfiguracion cfg) async {
    await _ref(empresaId).set(cfg.toMap());
    _cache[empresaId] = cfg;
  }

  // ── Invalidar caché ────────────────────────────────────────────────────────

  static void invalidarCache(String empresaId) => _cache.remove(empresaId);

  // ── Stream de cambios ─────────────────────────────────────────────────────

  static Stream<PdfConfiguracion> stream(String empresaId) =>
      _ref(empresaId).snapshots().map((s) {
        if (!s.exists || s.data() == null) return _defaults(empresaId);
        final cfg = PdfConfiguracion.fromMap(s.data()!);
        _cache[empresaId] = cfg;
        return cfg;
      });

  // ── Snapshot del emisor para guardar en cada documento ────────────────────
  // Llamar al emitir una factura; devuelve solo los datos del emisor.

  static Future<Map<String, dynamic>> snapshotEmisor(String empresaId) async {
    final cfg = await cargar(empresaId);
    return {
      'razon_social': cfg.razonSocial,
      'cif': cfg.cif,
      'domicilio': cfg.domicilioCompleto,
      'telefono': cfg.telefono,
      'email': cfg.email,
    };
  }

  // ── Validar antes de generar PDF ─────────────────────────────────────────
  // Retorna null si OK, o la lista de campos faltantes.

  static Future<List<String>?> validarParaFactura(String empresaId) async {
    final cfg = await cargar(empresaId);
    final faltantes = cfg.camposFaltantes;
    return faltantes.isEmpty ? null : faltantes;
  }

  // ── Migración desde datos existentes ─────────────────────────────────────

  static Future<PdfConfiguracion> _migrar(String empresaId) async {
    try {
      final futures = await Future.wait([
        _db.collection('empresas').doc(empresaId).get(),
        _db.collection('empresas').doc(empresaId)
            .collection('configuracion').doc('facturacionTpv').get(),
      ]);
      final raiz   = futures[0] as DocumentSnapshot<Map<String, dynamic>>;
      final cfgFact= futures[1] as DocumentSnapshot<Map<String, dynamic>>;

      final data = raiz.data() ?? {};
      final cfg  = cfgFact.data() ?? {};
      final perfil = data['perfil'] as Map<String, dynamic>? ?? {};

      final razonSocial = (data['nombre_empresa'] ?? data['razon_social'] ??
          data['nombre_fiscal'] ?? perfil['nombre_empresa'] ??
          cfg['razon_social'] ?? cfg['nombre_empresa'] ?? '').toString().trim();

      final cifRaw = (data['nif'] ?? data['cif'] ?? cfg['nif'] ?? cfg['cif'] ?? '').toString().trim();

      // Dirección — intentamos parsear algo razonable
      final dirRaw = (data['direccion'] ?? data['domicilio_fiscal'] ??
          perfil['direccion'] ?? cfg['domicilio_fiscal'] ?? '').toString().trim();

      final cp  = (data['codigo_postal'] ?? cfg['codigo_postal'] ?? '').toString().trim();
      final loc = (data['ciudad'] ?? data['municipio'] ?? cfg['municipio'] ?? '').toString().trim();
      final logoUrl = (data['logo_url'] ?? perfil['logo_url'] ?? '').toString().trim();
      final iban = (data['iban_empresa'] ?? cfg['iban'] ?? '').toString().trim();

      final migrado = PdfConfiguracion(
        razonSocial: razonSocial,
        cif: cifRaw,
        tipoVia: 'Calle',
        nombreVia: dirRaw,   // guardamos la dirección cruda en nombreVia
        numero: '',
        codigoPostal: cp,
        localidad: loc,
        provincia: loc,
        telefono: (data['telefono'] ?? perfil['telefono'] ?? cfg['telefono']).toString().trim().nullIfEmpty,
        email: (data['correo'] ?? data['email'] ?? perfil['correo'] ?? cfg['correo']).toString().trim().nullIfEmpty,
        logoUrl: logoUrl.nullIfEmpty,
        iban: iban.nullIfEmpty,
        configPorTipo: const {},
        updatedAt: DateTime.now(),
      );

      // Guardamos la migración para no repetirla
      await _ref(empresaId).set(migrado.toMap()).catchError((_) {});
      _cache[empresaId] = migrado;
      return migrado;
    } catch (e) {
      debugPrint('⚠️ [PdfConfig] Error migrando: $e');
    }
    return _defaults(empresaId);
  }

  static PdfConfiguracion _defaults(String empresaId) => PdfConfiguracion(
    razonSocial: '', cif: '',
    tipoVia: 'Calle', nombreVia: '', numero: '',
    codigoPostal: '', localidad: '', provincia: '',
    configPorTipo: const {},
    updatedAt: DateTime.now(),
  );
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
