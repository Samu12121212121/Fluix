import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Servicio real de cierre de caja — sustituye el stub mock del TPV.
class CierreCajaService {

  Future<Map<String, dynamic>> calcularCierreCaja(
      String empresaId, DateTime fecha) async {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));

    final snap = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos')
        .where('fecha_hora',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_hora', isLessThan: Timestamp.fromDate(fin))
        .where('estado_pago', isEqualTo: 'pagado')
        .get();

    double efectivo = 0, tarjeta = 0;
    final topServicios = <String, int>{};

    for (final d in snap.docs) {
      final m = d.data();
      final metodo = m['metodo_pago'] as String? ?? 'efectivo';
      if (metodo == 'efectivo') {
        efectivo += (m['importe_efectivo'] as num?)?.toDouble() ??
            (m['importe_total'] as num?)?.toDouble() ??
            0;
      } else {
        tarjeta += (m['importe_tarjeta'] as num?)?.toDouble() ??
            (m['importe_total'] as num?)?.toDouble() ??
            0;
      }
      for (final linea in m['lineas'] as List? ?? []) {
        final nombre = linea['producto_nombre'] as String? ?? '';
        topServicios[nombre] = (topServicios[nombre] ?? 0) + 1;
      }
    }

    final total = efectivo + tarjeta;
    final numTickets = snap.docs.length;

    return {
      'fecha': Timestamp.fromDate(fecha),
      'fecha_legible': DateFormat('yyyy-MM-dd').format(fecha),
      'total': total,
      'efectivo': efectivo,
      'tarjeta': tarjeta,
      'num_tickets': numTickets,
      'ticket_medio': numTickets == 0 ? 0.0 : total / numTickets,
      'base_imponible': total / 1.21,
      'cuota_iva': total - total / 1.21,
      'top_servicios': (topServicios.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(5)
          .map((e) => {'nombre': e.key, 'cantidad': e.value})
          .toList(),
    };
  }

  Future<void> guardarCierreCaja(
      String empresaId, Map<String, dynamic> cierre) async {
    final fechaStr = cierre['fecha_legible'] as String;
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('cierres_caja')
        .doc(fechaStr)
        .set(cierre, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> obtenerCierres(String empresaId) {
    return FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('cierres_caja')
        .orderBy('fecha', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}

