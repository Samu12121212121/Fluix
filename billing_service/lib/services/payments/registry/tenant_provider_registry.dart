// lib/services/payments/registry/tenant_provider_registry.dart
// Registro dinámico de proveedores de pago por tenant.
// Carga credenciales cifradas de BD y construye el proveedor correspondiente.

import '../../../repositories/tenant_credentials_repository.dart';
import '../interfaces/payment_provider.dart';
import '../providers/stripe/stripe_provider.dart';
import '../providers/redsys/redsys_provider.dart';

class TenantProviderRegistry {
  final TenantCredentialsRepository _credsRepo;

  // Cache en memoria para evitar consultas a BD en cada webhook.
  // TTL de 5 minutos — si el tenant cambia sus credenciales, tarda max 5min en aplicar.
  final Map<String, _CachedProvider> _cache = {};

  TenantProviderRegistry(this._credsRepo);

  /// Obtiene un proveedor de pago configurado para un tenant específico.
  /// Devuelve null si el tenant no tiene ese proveedor configurado.
  Future<PaymentProvider?> getProvider({
    required String tenantId,
    required String providerType, // 'stripe' | 'redsys' | 'psd2_*'
  }) async {
    final cacheKey = '$tenantId:$providerType';
    final cached   = _cache[cacheKey];

    if (cached != null && !cached.isExpired) return cached.provider;

    // Cargar credenciales de BD (descifrado automático)
    final creds = await _credsRepo.get(
      tenantId: tenantId,
      provider: providerType,
    );

    if (creds == null) return null; // Tenant no tiene este proveedor configurado

    final provider = _buildProvider(providerType, creds);
    _cache[cacheKey] = _CachedProvider(
      provider:  provider,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

    return provider;
  }

  PaymentProvider _buildProvider(
    String type,
    Map<String, String> creds,
  ) {
    if (type == 'stripe') {
      return StripeProvider(
        webhookSecret: creds['webhook_secret']!,
      );
    }
    if (type == 'redsys') {
      return RedsysProvider(
        merchantKey: creds['merchant_key']!,
      );
    }
    // PSD2 providers podrían construirse aquí con adaptadores por banco
    if (type.startsWith('psd2_')) {
      // Por ahora, los proveedores PSD2 se manejan via polling
      // y se configuran de forma diferente (OAuth2 flow)
      throw ArgumentError(
        'PSD2 provider "$type" se configura mediante OAuth2, '
        'no directamente por credenciales.',
      );
    }
    throw ArgumentError('Proveedor desconocido: $type');
  }

  /// Invalida la caché de un tenant (tras cambiar credenciales).
  void invalidateCache(String tenantId) {
    _cache.removeWhere((key, _) => key.startsWith('$tenantId:'));
  }

  /// Invalida toda la caché.
  void invalidateAll() => _cache.clear();
}

class _CachedProvider {
  final PaymentProvider provider;
  final DateTime        expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  const _CachedProvider({required this.provider, required this.expiresAt});
}

