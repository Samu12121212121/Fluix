import 'dart:convert';
import 'dart:io';
import 'dart:async'; // Add import
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sonido_notificacion_service.dart';

/// Handler global para mensajes en background (debe ser función top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Notificación en background: ${message.notification?.title}');
}

/// Servicio de notificaciones push con Firebase Cloud Messaging
class NotificacionesService {
  static final NotificacionesService _instance = NotificacionesService._internal();
  factory NotificacionesService() => _instance;
  NotificacionesService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream para eventos de navegación
  final StreamController<Map<String, dynamic>> _tapStreamCtrl =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get onTap => _tapStreamCtrl.stream;

  bool _inicializado = false;

  // Canal Android para notificaciones
  static const AndroidNotificationChannel _canal = AndroidNotificationChannel(
    'fluixcrm_canal_principal',
    'Fluix CRM',
    description: 'Notificaciones de reservas, pedidos y alertas del negocio',
    importance: Importance.high,
    playSound: true,
  );

  /// Canal de alta prioridad para reseñas negativas
  static const AndroidNotificationChannel _canalResenasNegativas =
      AndroidNotificationChannel(
    'fluixcrm_resenas_negativas',
    'Alertas de reseñas negativas',
    description:
        'Alertas urgentes cuando recibes reseñas de 1, 2 o 3 estrellas',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Inicializar el servicio completo de notificaciones
  Future<void> inicializar() async {
    if (_inicializado) return;

    // Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Solicitar permisos
    await _solicitarPermisos();

    // Configurar notificaciones locales
    await _configurarNotificacionesLocales();

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Crear canal principal
    await androidPlugin?.createNotificationChannel(_canal);

    // Crear canal de reseñas negativas (alta prioridad)
    await androidPlugin?.createNotificationChannel(_canalResenasNegativas);

    // Escuchar mensajes en primer plano
    FirebaseMessaging.onMessage.listen(_manejarMensajePrimerPlano);

    // Escuchar tap en notificación con app en background
    FirebaseMessaging.onMessageOpenedApp.listen(_manejarTapNotificacion);

    // Guardar token del dispositivo en Firestore
    await _guardarTokenDispositivo();

    // Escuchar renovación del token
    _messaging.onTokenRefresh.listen((token) {
      _actualizarTokenEnFirestore(token);
    });

    _inicializado = true;
    print('✅ Servicio de notificaciones inicializado');
  }

  /// Solicitar permisos de notificaciones
  Future<void> _solicitarPermisos() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print('📱 Permisos notificaciones: ${settings.authorizationStatus}');
  }

  /// Configurar plugin de notificaciones locales
  Future<void> _configurarNotificacionesLocales() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('🔔 Tap en notificación local: ${details.payload}');
        _procesarPayload(details.payload);
      },
    );
  }

  /// Manejar mensajes cuando la app está en primer plano
  void _manejarMensajePrimerPlano(RemoteMessage message) {
    print('🔔 Notificación en primer plano: ${message.notification?.title}');
    final notif = message.notification;
    if (notif == null) return;

    _localNotifications.show(
      message.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canal.id,
          _canal.name,
          channelDescription: _canal.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF0D47A1),
          // Sonido del sistema como base; el custom se reproduce encima
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );

    // Reproducir el sonido configurado por el usuario para este tipo
    final tipoStr = message.data['tipo'] as String? ?? 'general';
    final tipo = TipoNotificacionExt.fromId(tipoStr);
    SonidoNotificacionService().reproducirParaTipo(tipo);
  }

  /// Manejar tap en notificación cuando la app estaba en background
  void _manejarTapNotificacion(RemoteMessage message) {
    print('🔔 Usuario tocó notificación: ${message.data}');
    _procesarPayload(jsonEncode(message.data));
    _tapStreamCtrl.add(message.data); // Agregar evento al stream
  }

  /// Procesar el payload de una notificación (navegación)
  void _procesarPayload(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final tipo = data['tipo'] as String?;
      print('🔔 Procesando notificación tipo: $tipo, data: $data');

      // Emitir al stream para que la UI pueda navegar
      _tapStreamCtrl.add(data);
    } catch (e) {
      print('❌ Error procesando payload: $e');
    }
  }

  /// Obtener y guardar el token FCM en Firestore
  Future<void> _guardarTokenDispositivo() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      print('📱 Token FCM: $token');
      await _actualizarTokenEnFirestore(token);
    } catch (e) {
      print('❌ Error obteniendo token FCM: $e');
    }
  }

  /// Actualizar token en Firestore para el usuario actual
  Future<void> _actualizarTokenEnFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Guardar en documento del usuario
      await _firestore.collection('usuarios').doc(uid).update({
        'token_dispositivo': token,
        'token_actualizado': FieldValue.serverTimestamp(),
        'plataforma': _obtenerPlataforma(),
      });

      // También guardar en la empresa para poder enviar a todos los empleados
      final userDoc =
          await _firestore.collection('usuarios').doc(uid).get();
      final empresaId = userDoc.data()?['empresa_id'] as String?;
      if (empresaId != null) {
        await _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('dispositivos')
            .doc(uid)
            .set({
          'token': token,
          'uid_usuario': uid,
          'plataforma': _obtenerPlataforma(),
          'ultima_actualizacion': FieldValue.serverTimestamp(),
          'activo': true,
        }, SetOptions(merge: true));
      }
      print('✅ Token guardado en Firestore');
    } catch (e) {
      print('❌ Error guardando token: $e');
    }
  }

  String _obtenerPlataforma() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Suscribirse a un topic (para notificaciones por empresa)
  Future<void> suscribirseATopic(String empresaId) async {
    await _messaging.subscribeToTopic('empresa_$empresaId');
    print('✅ Suscrito al topic: empresa_$empresaId');
  }

  /// Llamar explícitamente tras el login para garantizar que el token se guarda
  /// con el UID correcto (el usuario ya está autenticado en este punto)
  Future<void> guardarTokenTrasLogin() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      print('📱 Guardando token FCM tras login para UID: $uid');
      await _actualizarTokenEnFirestore(token);
    } catch (e) {
      print('❌ Error guardando token tras login: $e');
    }
  }

  /// Desuscribirse de un topic
  Future<void> desuscribirseDeTop(String empresaId) async {
    await _messaging.unsubscribeFromTopic('empresa_$empresaId');
  }

  /// Obtener el token actual del dispositivo
  Future<String?> obtenerToken() async {
    return await _messaging.getToken();
  }

  // ── NOTIFICACIONES LOCALES MANUALES ─────────────────────────────────────────
  // Útiles para notificaciones que se generan en el propio dispositivo

  /// Mostrar notificación local de nueva reserva
  Future<void> notificarNuevaReserva({
    required String clienteNombre,
    required String servicio,
    required String fecha,
    required String empresaId,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '📅 Nueva Reserva',
      '$clienteNombre — $servicio el $fecha',
      _detallesNotificacion(),
      payload: jsonEncode({
        'tipo': 'nueva_reserva',
        'empresa_id': empresaId,
      }),
    );
  }

  /// Mostrar notificación local de nueva valoración
  Future<void> notificarNuevaValoracion({
    required String clienteNombre,
    required int estrellas,
    required String empresaId,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '⭐ Nueva Valoración',
      '$clienteNombre te ha dejado $estrellas estrellas',
      _detallesNotificacion(),
      payload: jsonEncode({
        'tipo': 'nueva_valoracion',
        'empresa_id': empresaId,
      }),
    );
  }

  /// Mostrar notificación local de nuevo pedido
  Future<void> notificarNuevoPedido({
    required String clienteNombre,
    required double total,
    required String empresaId,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🛒 Nuevo Pedido',
      '$clienteNombre — €${total.toStringAsFixed(2)}',
      _detallesNotificacion(),
      payload: jsonEncode({
        'tipo': 'nuevo_pedido',
        'empresa_id': empresaId,
      }),
    );
  }

  /// Mostrar notificación de suscripción próxima a vencer
  Future<void> notificarSuscripcionPorVencer({
    required int diasRestantes,
    required String empresaId,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '⚠️ Suscripción por Vencer',
      'Tu suscripción vence en $diasRestantes días. Renueva para continuar.',
      _detallesNotificacion(importante: true),
      payload: jsonEncode({
        'tipo': 'suscripcion_por_vencer',
        'empresa_id': empresaId,
        'dias_restantes': diasRestantes,
      }),
    );
  }

  NotificationDetails _detallesNotificacion({bool importante = false}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _canal.id,
        _canal.name,
        channelDescription: _canal.description,
        importance: importante ? Importance.max : Importance.high,
        priority: importante ? Priority.max : Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF0D47A1),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: importante
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );
  }
}



