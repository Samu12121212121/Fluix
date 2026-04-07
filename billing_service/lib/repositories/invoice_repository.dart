// lib/repositories/invoice_repository.dart

import '../database/database.dart';
import '../models/invoice.dart';
import 'package:uuid/uuid.dart';

class InvoiceRepository {
  final Database _db;
  final _uuid = const Uuid();

  InvoiceRepository(this._db);

  Future<Invoice> save(Invoice invoice) async {
    final id = invoice.id.isEmpty ? _uuid.v4() : invoice.id;
    await _db.execute('''
      INSERT INTO invoices (
        id, tenant_id, serie, numero, tipo, tipo_verifactu, tipo_rectificativa,
        factura_rectificada_serie, factura_rectificada_numero,
        factura_rectificada_fecha, emisor_nif, emisor_nombre,
        destinatario_nif, destinatario_nombre, destinatario_direccion,
        destinatario_email, fecha_expedicion, fecha_operacion,
        base_imponible, tipo_iva, cuota_iva, retencion_irpf, recargo,
        importe_total, descripcion, clave_regimen, calificacion_operacion,
        referencia_externa, proveedor_pago, registro_verifactu, hash_verifactu
      ) VALUES (
        @id, @tenantId, @serie, @numero, @tipo, @tipoVerifactu, @tipoRectificativa,
        @facturaRectificadaSerie, @facturaRectificadaNumero,
        @facturaRectificadaFecha, @emisorNif, @emisorNombre,
        @destinatarioNif, @destinatarioNombre, @destinatarioDireccion,
        @destinatarioEmail, @fechaExpedicion, @fechaOperacion,
        @baseImponible, @tipoIva, @cuotaIva, @retencionIrpf, @recargo,
        @importeTotal, @descripcion, @claveRegimen, @calificacionOperacion,
        @referenciaExterna, @proveedorPago, @registroVerifactu, @hashVerifactu
      )
      ON CONFLICT (id) DO UPDATE SET
        registro_verifactu = EXCLUDED.registro_verifactu,
        hash_verifactu     = EXCLUDED.hash_verifactu
    ''', {
      'id':                        id,
      'tenantId':                  invoice.tenantId,
      'serie':                     invoice.serie,
      'numero':                    invoice.numero,
      'tipo':                      invoice.tipo.name,
      'tipoVerifactu':             invoice.tipoVerifactu,
      'tipoRectificativa':         invoice.tipoRectificativa,
      'facturaRectificadaSerie':   invoice.facturaRectificadaSerie,
      'facturaRectificadaNumero':  invoice.facturaRectificadaNumero,
      'facturaRectificadaFecha':   invoice.facturaRectificadaFecha,
      'emisorNif':                 invoice.emisorNif,
      'emisorNombre':              invoice.emisorNombre,
      'destinatarioNif':           invoice.destinatarioNif,
      'destinatarioNombre':        invoice.destinatarioNombre,
      'destinatarioDireccion':     invoice.destinatarioDireccion,
      'destinatarioEmail':         invoice.destinatarioEmail,
      'fechaExpedicion':           invoice.fechaExpedicion,
      'fechaOperacion':            invoice.fechaOperacion,
      'baseImponible':             invoice.baseImponible,
      'tipoIva':                   invoice.tipoIva,
      'cuotaIva':                  invoice.cuotaIva,
      'retencionIrpf':             invoice.retencionIrpf,
      'recargo':                   invoice.recargo,
      'importeTotal':              invoice.importeTotal,
      'descripcion':               invoice.descripcion,
      'claveRegimen':              invoice.claveRegimen,
      'calificacionOperacion':     invoice.calificacionOperacion,
      'referenciaExterna':         invoice.referenciaExterna,
      'proveedorPago':             invoice.proveedorPago,
      'registroVerifactu':         invoice.registroVerifactu,
      'hashVerifactu':             invoice.hashVerifactu,
    });
    return invoice.copyWith(id: id);
  }

  Future<Invoice?> findById(String id) async {
    final row = await _db.queryOne(
      'SELECT * FROM invoices WHERE id = @id',
      {'id': id},
    );
    return row != null ? _fromRow(row) : null;
  }

  Future<Invoice?> findByExternalReference(String? ref, {String? tenantId}) async {
    if (ref == null) return null;
    final sql = tenantId != null
        ? 'SELECT * FROM invoices WHERE referencia_externa = @ref AND tenant_id = @tid ORDER BY fecha_expedicion DESC LIMIT 1'
        : 'SELECT * FROM invoices WHERE referencia_externa = @ref ORDER BY fecha_expedicion DESC LIMIT 1';
    final params = tenantId != null
        ? {'ref': ref, 'tid': tenantId}
        : {'ref': ref};
    final row = await _db.queryOne(sql, params);
    return row != null ? _fromRow(row) : null;
  }

  Future<List<Invoice>> findRecent({int limit = 50, String? tenantId}) async {
    final sql = tenantId != null
        ? 'SELECT * FROM invoices WHERE tenant_id = @tid ORDER BY fecha_expedicion DESC LIMIT @limit'
        : 'SELECT * FROM invoices ORDER BY fecha_expedicion DESC LIMIT @limit';
    final params = tenantId != null
        ? {'limit': limit, 'tid': tenantId}
        : {'limit': limit};
    final rows = await _db.queryMany(sql, params);
    return rows.map(_fromRow).toList();
  }

  Invoice _fromRow(Map<String, dynamic> r) => Invoice(
    id:                       r['id'] as String,
    tenantId:                 r['tenant_id'] as String?,
    serie:                    r['serie'] as String,
    numero:                   r['numero'] as String,
    tipo:                     InvoiceType.values.byName(r['tipo'] as String),
    tipoVerifactu:            r['tipo_verifactu'] as String,
    tipoRectificativa:        r['tipo_rectificativa'] as String?,
    facturaRectificadaSerie:  r['factura_rectificada_serie'] as String?,
    facturaRectificadaNumero: r['factura_rectificada_numero'] as String?,
    facturaRectificadaFecha:  r['factura_rectificada_fecha'] != null
        ? DateTime.parse(r['factura_rectificada_fecha'].toString())
        : null,
    emisorNif:                r['emisor_nif'] as String,
    emisorNombre:             r['emisor_nombre'] as String,
    destinatarioNif:          r['destinatario_nif'] as String?,
    destinatarioNombre:       r['destinatario_nombre'] as String?,
    destinatarioDireccion:    r['destinatario_direccion'] as String?,
    destinatarioEmail:        r['destinatario_email'] as String?,
    fechaExpedicion:          DateTime.parse(r['fecha_expedicion'].toString()),
    fechaOperacion:           DateTime.parse(r['fecha_operacion'].toString()),
    baseImponible:            (r['base_imponible'] as num).toDouble(),
    tipoIva:                  (r['tipo_iva'] as num).toDouble(),
    cuotaIva:                 (r['cuota_iva'] as num).toDouble(),
    retencionIrpf:            (r['retencion_irpf'] as num).toDouble(),
    recargo:                  (r['recargo'] as num).toDouble(),
    importeTotal:             (r['importe_total'] as num).toDouble(),
    descripcion:              r['descripcion'] as String,
    claveRegimen:             r['clave_regimen'] as String,
    calificacionOperacion:    r['calificacion_operacion'] as String,
    referenciaExterna:        r['referencia_externa'] as String?,
    proveedorPago:            r['proveedor_pago'] as String,
    registroVerifactu:        r['registro_verifactu'] as String?,
    hashVerifactu:            r['hash_verifactu'] as String?,
  );
}




