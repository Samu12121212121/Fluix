import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/modelos/pedido.dart';

class WhatsappMessageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Map<EstadoPedido, String> _defaultTemplates = {
    EstadoPedido.confirmado: 'Hola {nombre_cliente}! Tu pedido #{numero_pedido} ha sido confirmado y esta en preparacion.\nGracias por confiar en {nombre_empresa}.',
    EstadoPedido.enPreparacion: 'Hola {nombre_cliente}! Tu pedido #{numero_pedido} esta siendo preparado.\n{nombre_empresa}',
    EstadoPedido.listo: 'Hola {nombre_cliente}! Tu pedido #{numero_pedido} esta listo para recoger.\nTe esperamos en {nombre_empresa}.',
    EstadoPedido.entregado: 'Hola {nombre_cliente}! Tu pedido #{numero_pedido} ha sido entregado. Gracias!\n{nombre_empresa}',
    EstadoPedido.cancelado: 'Hola {nombre_cliente}, tu pedido #{numero_pedido} ha sido cancelado. Disculpa las molestias.\n{nombre_empresa}',
  };

  Future<Map<String, String>> obtenerTemplates(String empresaId) async {
    final doc = await _db.collection('empresas').doc(empresaId)
        .collection('configuracion').doc('whatsapp_templates').get();
    if (!doc.exists) {
      return _defaultTemplates.map((k, v) => MapEntry(k.name, v));
    }
    final data = doc.data() ?? {};
    return {
      for (final e in EstadoPedido.values)
        e.name: data[e.name] as String? ?? _defaultTemplates[e] ?? '',
    };
  }

  Future<void> guardarTemplates(String empresaId, Map<String, String> t) =>
      _db.collection('empresas').doc(empresaId)
          .collection('configuracion').doc('whatsapp_templates')
          .set(t, SetOptions(merge: true));

  Future<String> generarMensaje({
    required String empresaId,
    required Pedido pedido,
    required EstadoPedido estado,
  }) async {
    final templates = await obtenerTemplates(empresaId);
    String t = templates[estado.name] ?? '';
    if (t.isEmpty) return '';

    String nombreEmpresa = 'Nuestro negocio';
    try {
      final d = await _db.collection('empresas').doc(empresaId).get();
      nombreEmpresa = d.data()?['nombre'] ?? nombreEmpresa;
    } catch (_) {}

    final resumen = pedido.lineas.take(3)
        .map((l) => '${l.cantidad}x ${l.productoNombre}').join(', ');
    final mas = pedido.lineas.length > 3
        ? ' y ${pedido.lineas.length - 3} mas' : '';

    return t
        .replaceAll('{nombre_cliente}', pedido.clienteNombre)
        .replaceAll('{numero_pedido}', pedido.id.substring(0, 8).toUpperCase())
        .replaceAll('{nombre_empresa}', nombreEmpresa)
        .replaceAll('{total}', '${pedido.total.toStringAsFixed(2)} EUR')
        .replaceAll('{productos}', '$resumen$mas');
  }

  Future<bool> abrirWhatsapp({
    required String telefono,
    required String mensaje,
  }) async {
    String tel = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    if (tel.startsWith('0')) tel = '+34${tel.substring(1)}';
    if (!tel.startsWith('+')) tel = '+34$tel';
    tel = tel.replaceAll('+', '');
    final url = Uri.parse(
        'https://wa.me/$tel?text=${Uri.encodeComponent(mensaje)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  Future<void> registrarEnvio({
    required String empresaId,
    required String pedidoId,
    required EstadoPedido estado,
    required bool enviado,
  }) => _db.collection('empresas').doc(empresaId)
      .collection('pedidos').doc(pedidoId).update({
    'mensajes_whatsapp': FieldValue.arrayUnion([{
      'estado': estado.name,
      'enviado': enviado,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    }]),
  });

  static bool tieneTelefonoValido(Pedido p) =>
      (p.clienteTelefono ?? '').replaceAll(RegExp(r'[^\d]'), '').length >= 9;

  static bool estadoGeneraMensaje(EstadoPedido e) => const {
    EstadoPedido.confirmado, EstadoPedido.enPreparacion,
    EstadoPedido.listo, EstadoPedido.entregado, EstadoPedido.cancelado,
  }.contains(e);
}

