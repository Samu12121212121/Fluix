// lib/services/payments/interfaces/payment_event.dart

enum PaymentStatus { succeeded, failed, refunded, pending }
enum PaymentMethod { card, transfer, bizum, other }
enum CustomerType  { b2b, b2c, unknown }

class CustomerInfo {
  final String? nif;
  final String? name;
  final String? email;
  final String? address;
  final CustomerType type;

  const CustomerInfo({
    this.nif,
    this.name,
    this.email,
    this.address,
    required this.type,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) => CustomerInfo(
    nif:     json['nif'] as String?,
    name:    json['name'] as String?,
    email:   json['email'] as String?,
    address: json['address'] as String?,
    type:    CustomerType.values.byName(json['type'] as String? ?? 'unknown'),
  );

  Map<String, dynamic> toJson() => {
    'nif': nif, 'name': name, 'email': email,
    'address': address, 'type': type.name,
  };
}

class PaymentEvent {
  final String         eventId;
  final String         providerId;
  final DateTime       timestamp;
  final double         amount;
  final String         currency;
  final PaymentStatus  status;
  final PaymentMethod  method;
  final CustomerInfo?  customer;
  final Map<String, dynamic> rawPayload;
  final String?        externalReference;

  const PaymentEvent({
    required this.eventId,
    required this.providerId,
    required this.timestamp,
    required this.amount,
    required this.currency,
    required this.status,
    required this.method,
    this.customer,
    required this.rawPayload,
    this.externalReference,
  });

  factory PaymentEvent.fromJson(Map<String, dynamic> json) => PaymentEvent(
    eventId:           json['event_id'] as String,
    providerId:        json['provider_id'] as String,
    timestamp:         DateTime.parse(json['timestamp'] as String),
    amount:            (json['amount'] as num).toDouble(),
    currency:          json['currency'] as String,
    status:            PaymentStatus.values.byName(json['status'] as String),
    method:            PaymentMethod.values.byName(json['method'] as String),
    customer:          json['customer'] != null
        ? CustomerInfo.fromJson(json['customer'] as Map<String, dynamic>)
        : null,
    rawPayload:        (json['raw_payload'] as Map<String, dynamic>?) ?? {},
    externalReference: json['external_reference'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'event_id':          eventId,
    'provider_id':       providerId,
    'timestamp':         timestamp.toIso8601String(),
    'amount':            amount,
    'currency':          currency,
    'status':            status.name,
    'method':            method.name,
    'customer':          customer?.toJson(),
    'raw_payload':       rawPayload,
    'external_reference': externalReference,
  };
}

