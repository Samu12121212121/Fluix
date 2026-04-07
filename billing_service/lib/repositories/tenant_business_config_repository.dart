// lib/repositories/tenant_business_config_repository.dart

import '../database/database.dart';
import '../models/tenant_business_config.dart';

class TenantBusinessConfigRepository {
  final Database _db;

  // Cache por tenant — TTL 5 minutos
  final Map<String, _CachedConfig> _cache = {};

  TenantBusinessConfigRepository(this._db);

  Future<TenantBusinessConfig?> get(String tenantId) async {
    // Verificar caché
    final cached = _cache[tenantId];
    if (cached != null && !cached.isExpired) return cached.config;

    final row = await _db.queryOne(
      'SELECT * FROM tenant_business_config WHERE tenant_id = @tid',
      {'tid': tenantId},
    );

    if (row == null) return null;

    final config = TenantBusinessConfig.fromRow(row);
    _cache[tenantId] = _CachedConfig(
      config:    config,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    return config;
  }

  Future<void> upsert(TenantBusinessConfig config) async {
    await _db.execute('''
      INSERT INTO tenant_business_config
        (tenant_id, emisor_nif, emisor_nombre, emisor_direccion,
         emisor_cp, emisor_municipio, sujeta_retencion_irpf,
         is_nuevo_autonomo, recargo_equivalencia, default_product_code,
         updated_at)
      VALUES
        (@tid, @nif, @nombre, @dir, @cp, @muni, @irpf,
         @nuevo, @recargo, @product, NOW())
      ON CONFLICT (tenant_id)
      DO UPDATE SET
        emisor_nif            = @nif,
        emisor_nombre         = @nombre,
        emisor_direccion      = @dir,
        emisor_cp             = @cp,
        emisor_municipio      = @muni,
        sujeta_retencion_irpf = @irpf,
        is_nuevo_autonomo     = @nuevo,
        recargo_equivalencia  = @recargo,
        default_product_code  = @product,
        updated_at            = NOW()
    ''', {
      'tid':     config.tenantId,
      'nif':     config.emisorNif,
      'nombre':  config.emisorNombre,
      'dir':     config.emisorDireccion,
      'cp':      config.emisorCp,
      'muni':    config.emisorMunicipio,
      'irpf':    config.sujetaRetencionIrpf,
      'nuevo':   config.isNuevoAutonomo,
      'recargo': config.recargoEquivalencia,
      'product': config.defaultProductCode,
    });

    // Invalidar caché
    _cache.remove(config.tenantId);
  }

  /// Obtener mapeo de IVA para un producto de un tenant.
  Future<String?> getVatMapping(String tenantId, String productCode) async {
    final row = await _db.queryOne('''
      SELECT vat_rate FROM tenant_vat_mappings
      WHERE tenant_id = @tid AND product_code = @code
    ''', {'tid': tenantId, 'code': productCode});
    return row?['vat_rate'] as String?;
  }

  void invalidateCache(String tenantId) {
    _cache.remove(tenantId);
  }
}

class _CachedConfig {
  final TenantBusinessConfig config;
  final DateTime             expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  const _CachedConfig({required this.config, required this.expiresAt});
}

