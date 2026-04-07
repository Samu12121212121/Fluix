// lib/repositories/business_config_repository.dart

import '../database/database.dart';
import '../models/business_config.dart';

class BusinessConfigRepository {
  final Database       _db;
  BusinessConfig?      _cache;
  DateTime?            _cacheTime;

  BusinessConfigRepository(this._db);

  Future<BusinessConfig> get() async {
    // Caché de 5 minutos
    if (_cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < 5) {
      return _cache!;
    }

    final row = await _db.queryOne(
      'SELECT * FROM business_config WHERE id = 1',
    );

    if (row == null) {
      // Usar configuración desde variables de entorno si no hay BD
      _cache = BusinessConfig.fromEnv();
    } else {
      _cache = BusinessConfig(
        emisorNif:           row['emisor_nif'] as String,
        emisorNombre:        row['emisor_nombre'] as String,
        recargoEquivalencia: row['recargo_equivalencia'] as bool? ?? false,
        sujetaRetencionIRPF: row['sujeta_retencion_irpf'] as bool? ?? false,
        isNuevoAutonomo:     row['is_nuevo_autonomo'] as bool? ?? false,
        defaultProductCode:  row['default_product_code'] as String? ?? 'default',
      );
    }
    _cacheTime = DateTime.now();
    return _cache!;
  }

  /// Devuelve el tipo de IVA configurado para un código de producto.
  Future<dynamic> getVatMapping(String productCode) async {
    final cfg = await get();
    final code = cfg.vatMappings[productCode];
    return code;
  }
}

