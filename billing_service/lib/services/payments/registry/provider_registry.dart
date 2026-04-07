// lib/services/payments/registry/provider_registry.dart
// Registro central de todos los proveedores de pago.

import '../interfaces/payment_provider.dart';

class ProviderRegistry {
  final Map<String, PaymentProvider> _providers = {};

  void register(PaymentProvider provider) {
    _providers[provider.providerId] = provider;
  }

  PaymentProvider? getById(String providerId) => _providers[providerId];

  List<PaymentProvider> get all        => _providers.values.toList();
  List<PaymentProvider> get webhooks   => all.where((p) => p.supportsWebhook).toList();
  List<PaymentProvider> get pollable   => all.where((p) => p.requiresPolling).toList();

  Map<String, dynamic> toJson() => {
    'providers': all.map((p) => {
      'id':               p.providerId,
      'name':             p.displayName,
      'supports_webhook': p.supportsWebhook,
      'requires_polling': p.requiresPolling,
    }).toList(),
  };
}

