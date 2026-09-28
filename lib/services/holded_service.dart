import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ia_service.dart';
import '../domain/modelos/factura.dart';
import '../domain/modelos/cliente.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO HOLDED
//
// API key guardada en:
//   usuarios/{uid}/configuracion/api_keys → holded
//
// Documentación: https://developers.holded.com/
// ─────────────────────────────────────────────────────────────────────────────

class HoldedService {
  static final HoldedService _i = HoldedService._();
  factory HoldedService() => _i;
  HoldedService._();

  static const _base = 'https://api.holded.com/api';
  final _ia = IaService();
  final _db = FirebaseFirestore.instance;

  Future<String?> _apiKey() => _ia.obtenerApiKey('holded');
  Future<bool> estaConfigurado() async {
    final k = await _apiKey();
    return k != null && k.isNotEmpty;
  }

  Map<String, String> _headers(String key) => {
    'key': key,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // ── CONTACTOS ────────────────────────────────────────────────────────────

  Future<String?> crearOActualizarContacto(Cliente cliente) async {
    final key = await _apiKey();
    if (key == null || key.isEmpty) return null;

    final body = {
      'name':  cliente.nombre,
      if (cliente.correo.isNotEmpty) 'email': cliente.correo,
      if (cliente.telefono.isNotEmpty) 'phone': cliente.telefono,
      if (cliente.nif != null) 'vatnumber': cliente.nif,
      'type':  'client',
    };

    try {
      String? existingId;
      if (cliente.correo.isNotEmpty) {
        existingId = await _buscarContactoPorEmail(key, cliente.correo);
      }

      http.Response resp;
      if (existingId != null) {
        resp = await http.put(
          Uri.parse('$_base/contacts/v1/contact/$existingId'),
          headers: _headers(key),
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 15));
        return existingId;
      } else {
        resp = await http.post(
          Uri.parse('$_base/contacts/v1/contact'),
          headers: _headers(key),
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          return data['id'] as String?;
        }
      }
      debugPrint('❌ Holded contacto: ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ Holded contacto error: $e');
      return null;
    }
  }

  Future<String?> _buscarContactoPorEmail(String key, String email) async {
    try {
      final resp = await http.get(
        Uri.parse('$_base/contacts/v1/contact?email=${Uri.encodeComponent(email)}'),
        headers: _headers(key),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List?;
        if (list != null && list.isNotEmpty) {
          return (list.first as Map<String, dynamic>)['id'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  // ── FACTURAS ─────────────────────────────────────────────────────────────

  Future<bool> enviarFactura(Factura factura, {String? holdedContactId}) async {
    final key = await _apiKey();
    if (key == null || key.isEmpty) return false;

    final items = factura.lineas.map((l) => {
      'name':     l.descripcion,
      'price':    l.precioUnitario,
      'quantity': l.cantidad,
      'tax':      l.porcentajeIva.toInt(),
      if (l.descuento > 0) 'discount': l.descuento,
    }).toList();

    final body = <String, dynamic>{
      if (holdedContactId != null) 'contactId': holdedContactId,
      'contactName': factura.clienteNombre,
      'date': (factura.fechaEmision.millisecondsSinceEpoch ~/ 1000),
      'notes':  factura.numeroFactura,
      'items':  items,
      'currency': 'EUR',
    };

    try {
      final resp = await http.post(
        Uri.parse('$_base/invoices/v1/invoice'),
        headers: _headers(key),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        debugPrint('✅ Holded factura enviada: ${data['id']}');
        return true;
      }
      debugPrint('❌ Holded factura: ${resp.statusCode} ${resp.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Holded factura error: $e');
      return false;
    }
  }

  // ── SINCRONIZACIÓN MASIVA DE CLIENTES ────────────────────────────────────

  Future<int> sincronizarClientesDesdeFirestore(String empresaId) async {
    if (!await estaConfigurado()) return 0;
    int ok = 0;
    try {
      final snap = await _db
          .collection('empresas').doc(empresaId)
          .collection('clientes')
          .where('activo', isEqualTo: true)
          .limit(100)
          .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        final cliente = Cliente(
          id:       doc.id,
          nombre:   d['nombre'] as String? ?? '',
          telefono: d['telefono'] as String? ?? '',
          correo:   d['correo'] as String? ?? d['email'] as String? ?? '',
          nif:      d['nif'] as String?,
          fechaRegistro:
              (d['fecha_registro'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
        final id = await crearOActualizarContacto(cliente);
        if (id != null) ok++;
        await Future.delayed(const Duration(milliseconds: 250));
      }
    } catch (e) {
      debugPrint('❌ Holded sync clientes: $e');
    }
    return ok;
  }

  // ── EXPORTAR FACTURAS DEL MES ─────────────────────────────────────────────

  Future<int> exportarFacturasDelMes(String empresaId, DateTime mes) async {
    if (!await estaConfigurado()) return 0;
    final inicio = DateTime(mes.year, mes.month, 1);
    final fin    = DateTime(mes.year, mes.month + 1, 1);
    int ok = 0;
    try {
      final snap = await _db
          .collection('empresas').doc(empresaId)
          .collection('facturas')
          .where('fecha_emision', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha_emision', isLessThan: Timestamp.fromDate(fin))
          .get();

      for (final doc in snap.docs) {
        if (doc.data()['holded_synced'] == true) continue;
        try {
          final factura = Factura.fromFirestore(doc);
          final exito = await enviarFactura(factura);
          if (exito) {
            await doc.reference.update({'holded_synced': true});
            ok++;
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      debugPrint('❌ Holded exportar facturas: $e');
    }
    return ok;
  }
}
