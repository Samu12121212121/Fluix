// lib/services/payments/core/invoice_series_repository.dart
// Numeración sin huecos usando SELECT FOR UPDATE (garantizado por la BD).

import '../../../database/database.dart';
import '../../../models/invoice.dart';
import '../../../models/business_config.dart';
import '../../../repositories/business_config_repository.dart';

class InvoiceSeriesRepository {
  final Database                 _db;
  final BusinessConfigRepository _config;

  InvoiceSeriesRepository(this._db, this._config);

  Future<InvoiceSeries> getNextNumber({required InvoiceType type}) async {
    final cfg   = await _config.get();
    final serie = _serieForType(type);

    late String numero;

    await _db.transaction((tx) async {
      // Lock exclusivo sobre la fila del contador — sin huecos
      await tx.execute('''
        INSERT INTO invoice_series_counters (serie, last_number)
        VALUES (@serie, 0)
        ON CONFLICT (serie) DO NOTHING
      ''', {'serie': serie});

      final row = await tx.queryOne('''
        SELECT last_number FROM invoice_series_counters
        WHERE serie = @serie
        FOR UPDATE
      ''', {'serie': serie});

      final last = (row?['last_number'] as int?) ?? 0;
      final next = last + 1;

      await tx.execute('''
        UPDATE invoice_series_counters
        SET last_number = @next, updated_at = NOW()
        WHERE serie = @serie
      ''', {'next': next, 'serie': serie});

      numero = next.toString().padLeft(8, '0');
    });

    return InvoiceSeries(
      serie:        serie,
      numero:       numero,
      emisorNif:    cfg.emisorNif,
      emisorNombre: cfg.emisorNombre,
    );
  }

  String _serieForType(InvoiceType type) {
    final year = DateTime.now().year;
    return switch (type) {
      InvoiceType.complete      => 'F-$year',
      InvoiceType.simplified    => 'FS-$year',
      InvoiceType.rectificativa => 'R-$year',
    };
  }
}

