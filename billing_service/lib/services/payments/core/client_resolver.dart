// lib/services/payments/core/client_resolver.dart
// Determina si el cliente es B2B (con NIF) o B2C a partir del evento de pago.

import '../../../database/database.dart';
import '../interfaces/payment_event.dart';

class ClientResolver {
  final Database _db;

  ClientResolver(this._db);

  Future<CustomerInfo?> resolve(PaymentEvent event) async {
    // 1. Si el evento ya trae datos del cliente, usarlos directamente
    if (event.customer != null) return event.customer;

    // 2. Buscar en el CRM si existe un cliente con la referencia externa
    if (event.externalReference != null) {
      final found = await _findByReference(event.externalReference!);
      if (found != null) return found;
    }

    // 3. Sin datos suficientes — B2C anónimo
    return null;
  }

  Future<CustomerInfo?> _findByReference(String reference) async {
    // Busca en la tabla de clientes por referencia externa (p.ej. Stripe customer ID)
    final row = await _db.queryOne('''
      SELECT nif, name, email, address, tipo
      FROM   clients
      WHERE  external_reference = @ref
         OR  stripe_customer_id = @ref
      LIMIT  1
    ''', {'ref': reference});

    if (row == null) return null;

    return CustomerInfo(
      nif:     row['nif'] as String?,
      name:    row['name'] as String?,
      email:   row['email'] as String?,
      address: row['address'] as String?,
      type:    (row['nif'] as String?)?.isNotEmpty == true
          ? CustomerType.b2b
          : CustomerType.b2c,
    );
  }
}

