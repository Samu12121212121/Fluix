import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio para integración con Stripe Connect
class StripeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String stripeConnectClientId = 'ca_xxxxx'; // TODO: Reemplazar con tu Client ID
  static const String redirectUri = 'https://tudominio.com/stripe/callback';

  /// Verificar si la empresa tiene Stripe conectado
  Future<bool> tieneStripeConectado(String empresaId) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('integraciones')
          .doc('stripe')
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      return data?['connected'] == true && data?['stripe_account_id'] != null;
    } catch (e) {
      print('Error verificando conexión Stripe: $e');
      return false;
    }
  }

  /// Obtener datos de la integración de Stripe
  Future<Map<String, dynamic>?> obtenerIntegracion(String empresaId) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('integraciones')
          .doc('stripe')
          .get();

      return doc.data();
    } catch (e) {
      print('Error obteniendo integración Stripe: $e');
      return null;
    }
  }

  /// Construir URL de OAuth para conectar Stripe
  String construirUrlOAuth(String empresaId) {
    final nonce = DateTime.now().millisecondsSinceEpoch.toString();
    final state = '${empresaId}__$nonce';

    final params = {
      'response_type': 'code',
      'client_id': stripeConnectClientId,
      'scope': 'read_write',
      'redirect_uri': redirectUri,
      'state': state,
    };

    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return 'https://connect.stripe.com/oauth/authorize?$query';
  }

  /// Desconectar Stripe (Cloud Function se encarga de revocar el token)
  Future<void> desconectarStripe(String empresaId) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('integraciones')
          .doc('stripe')
          .update({
        'connected': false,
        'activo': false,
        'fecha_desconexion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error desconectando Stripe: $e');
      rethrow;
    }
  }

  /// Sincronizar productos con Stripe (crear/actualizar en Stripe)
  Future<void> sincronizarProducto(
    String empresaId,
    String productoId,
    Map<String, dynamic> productoData,
  ) async {
    try {
      // Esta función llamará a una Cloud Function que sincroniza con Stripe
      // y devuelve el stripe_product_id y stripe_price_id
      
      // Por ahora solo guardamos en Firestore
      // La Cloud Function onProductoWrite se encargará de sincronizar
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('productos_tienda')
          .doc(productoId)
          .set(productoData, SetOptions(merge: true));
    } catch (e) {
      print('Error sincronizando producto: $e');
      rethrow;
    }
  }

  /// Actualizar precio de producto (crea nuevo Price en Stripe)
  Future<void> actualizarPrecioProducto(
    String empresaId,
    String productoId,
    double nuevoPrecio,
  ) async {
    try {
      // Stripe no permite editar precios existentes, hay que crear uno nuevo
      // La Cloud Function se encargará de esto
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('productos_tienda')
          .doc(productoId)
          .update({
        'precio': nuevoPrecio,
        'precio_actualizado': FieldValue.serverTimestamp(),
        'requiere_sync_stripe': true, // Flag para Cloud Function
      });
    } catch (e) {
      print('Error actualizando precio: $e');
      rethrow;
    }
  }

  /// Obtener pedidos de tienda online
  Stream<QuerySnapshot> obtenerPedidos(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos')
        .where('origen', isEqualTo: 'tienda_online')
        .orderBy('fecha_creacion', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Actualizar estado de pedido
  Future<void> actualizarEstadoPedido(
    String empresaId,
    String pedidoId,
    String nuevoEstado,
  ) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos')
          .doc(pedidoId)
          .update({
        'estado': nuevoEstado,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error actualizando estado de pedido: $e');
      rethrow;
    }
  }

  /// Obtener productos de tienda
  Stream<QuerySnapshot> obtenerProductos(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('productos_tienda')
        .orderBy('nombre')
        .snapshots();
  }

  /// Crear producto de tienda
  Future<String> crearProducto(
    String empresaId,
    Map<String, dynamic> productoData,
  ) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('productos_tienda')
          .add({
        ...productoData,
        'fecha_creacion': FieldValue.serverTimestamp(),
        'activo': true,
      });

      return doc.id;
    } catch (e) {
      print('Error creando producto: $e');
      rethrow;
    }
  }

  /// Eliminar producto
  Future<void> eliminarProducto(String empresaId, String productoId) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('productos_tienda')
          .doc(productoId)
          .update({
        'activo': false,
        'fecha_eliminacion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error eliminando producto: $e');
      rethrow;
    }
  }
}

