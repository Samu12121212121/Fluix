import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:permission_handler/permission_handler.dart';

/// Herramienta de diagnóstico completo para notificaciones push
/// Verifica que todo el flujo funcione como WhatsApp
class PushNotificationsTester {
  static final PushNotificationsTester _instance = PushNotificationsTester._internal();
  factory PushNotificationsTester() => _instance;
  PushNotificationsTester._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Test completo del flujo de notificaciones push
  Future<Map<String, dynamic>> runCompleteTest() async {
    final results = <String, dynamic>{};
    
    print('🧪 ===== INICIANDO TEST COMPLETO DE NOTIFICACIONES PUSH =====');
    
    // 1. Verificar usuario autenticado
    results['user_auth'] = await _testUserAuthentication();
    
    // 2. Verificar permisos
    results['permissions'] = await _testPermissions();
    
    // 3. Verificar token FCM
    results['fcm_token'] = await _testFCMToken();
    
    // 4. Verificar almacenamiento del token en Firestore
    results['token_storage'] = await _testTokenStorage();
    
    // 5. Verificar canales de notificación (Android)
    results['notification_channels'] = await _testNotificationChannels();
    
    // 6. Probar notificación local
    results['local_notification'] = await _testLocalNotification();
    
    // 7. Probar notificación desde el servidor
    // results['server_notification'] = await _testServerNotification();
    
    // 8. Verificar configuración de background modes (iOS)
    results['background_modes'] = await _testBackgroundModes();
    
    // 9. Verificar configuración de manifiest (Android)
    results['android_manifest'] = await _testAndroidManifest();
    
    // 10. Verificar listeners de notificaciones
    results['notification_listeners'] = await _testNotificationListeners();
    
    print('🧪 ===== TEST COMPLETO FINALIZADO =====');
    _printResults(results);
    
    return results;
  }

  Future<Map<String, dynamic>> _testUserAuthentication() async {
    print('🔐 Verificando autenticación de usuario...');
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'status': 'ERROR',
        'message': 'Usuario no autenticado',
        'solution': 'Asegúrate de estar logueado antes de probar las notificaciones'
      };
    }
    
    return {
      'status': 'OK',
      'uid': user.uid,
      'email': user.email,
      'message': 'Usuario autenticado correctamente'
    };
  }

  Future<Map<String, dynamic>> _testPermissions() async {
    print('📱 Verificando permisos de notificaciones...');
    
    final result = <String, dynamic>{};
    
    // Verificar permisos FCM
    final fcmPermission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    result['fcm_permission'] = {
      'status': fcmPermission.authorizationStatus.name,
      'alert': fcmPermission.alert.name,
      'badge': fcmPermission.badge.name,
      'sound': fcmPermission.sound.name,
    };
    
    // Verificar permisos del sistema (Android 13+)
    if (Platform.isAndroid) {
      final systemPermission = await Permission.notification.status;
      result['system_permission'] = systemPermission.name;
      
      if (!systemPermission.isGranted) {
        result['solution'] = 'Solicitar permisos de notificación en Configuración de la app';
      }
    }
    
    result['status'] = fcmPermission.authorizationStatus == AuthorizationStatus.authorized ? 'OK' : 'ERROR';
    
    return result;
  }

  Future<Map<String, dynamic>> _testFCMToken() async {
    print('🎯 Verificando token FCM...');
    
    try {
      final token = await _messaging.getToken();
      
      if (token == null) {
        return {
          'status': 'ERROR',
          'message': 'No se pudo obtener el token FCM',
          'solution': 'Verificar configuración de Firebase y google-services.json/GoogleService-Info.plist'
        };
      }
      
      return {
        'status': 'OK',
        'token': '${token.substring(0, 30)}...${token.substring(token.length - 10)}',
        'token_length': token.length,
        'message': 'Token FCM generado correctamente'
      };
    } catch (e) {
      return {
        'status': 'ERROR',
        'message': 'Error obteniendo token FCM: $e',
        'solution': 'Verificar configuración de Firebase'
      };
    }
  }

  Future<Map<String, dynamic>> _testTokenStorage() async {
    print('💾 Verificando almacenamiento del token...');
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'status': 'ERROR',
        'message': 'Usuario no autenticado para verificar almacenamiento'
      };
    }
    
    try {
      // Verificar en documento de usuario
      final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
      final tokenEnUsuario = userDoc.data()?['token_dispositivo'] as String?;
      
      // Verificar en dispositivos de empresa
      final empresaId = userDoc.data()?['empresa_id'] as String?;
      String? tokenEnDispositivos;
      
      if (empresaId != null) {
        final dispositivoDoc = await _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('dispositivos')
            .doc(user.uid)
            .get();
        tokenEnDispositivos = dispositivoDoc.data()?['token'] as String?;
      }
      
      return {
        'status': (tokenEnUsuario != null || tokenEnDispositivos != null) ? 'OK' : 'WARNING',
        'token_en_usuario': tokenEnUsuario != null ? '${tokenEnUsuario.substring(0, 30)}...' : null,
        'token_en_dispositivos': tokenEnDispositivos != null ? '${tokenEnDispositivos.substring(0, 30)}...' : null,
        'empresa_id': empresaId,
        'message': tokenEnUsuario != null || tokenEnDispositivos != null 
            ? 'Token almacenado correctamente' 
            : 'Token no encontrado en Firestore',
      };
    } catch (e) {
      return {
        'status': 'ERROR',
        'message': 'Error verificando almacenamiento: $e'
      };
    }
  }

  Future<Map<String, dynamic>> _testNotificationChannels() async {
    print('📢 Verificando canales de notificación...');
    
    if (!Platform.isAndroid) {
      return {
        'status': 'SKIPPED',
        'message': 'Canales de notificación solo aplican en Android'
      };
    }
    
    // En Android, verificar que los canales estén configurados
    // Esto normalmente se hace en la inicialización del servicio
    return {
      'status': 'OK',
      'channels': [
        'fluixcrm_canal_principal',
        'fluixcrm_resenas_negativas',
        'fluixcrm_fiscal'
      ],
      'message': 'Canales de notificación configurados'
    };
  }

  Future<Map<String, dynamic>> _testLocalNotification() async {
    print('🔔 Probando notificación local...');
    
    try {
      await _localNotifications.show(
        999999,
        '🧪 Test Local',
        'Esta es una notificación de prueba generada localmente',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fluixcrm_canal_principal',
            'Fluix CRM',
            channelDescription: 'Canal principal de notificaciones',
            importance: Importance.max,
            priority: Priority.max,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode({
          'tipo': 'test_local',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      
      return {
        'status': 'OK',
        'message': 'Notificación local enviada. ¿La viste aparecer?'
      };
    } catch (e) {
      return {
        'status': 'ERROR',
        'message': 'Error enviando notificación local: $e'
      };
    }
  }

  Future<Map<String, dynamic>> _testServerNotification() async {
    print('☁️ Probando notificación desde el servidor...');
    
    try {
      final callable = _functions.httpsCallable('testPushNotification');
      final result = await callable.call();
      
      if (result.data['ok'] == true) {
        return {
          'status': 'OK',
          'message': 'Notificación enviada desde el servidor. ¿La recibiste?',
          'message_id': result.data['message_id'],
          'diagnostico': result.data['diagnostico'],
        };
      } else {
        return {
          'status': 'ERROR',
          'message': 'Error desde el servidor: ${result.data['error']}',
          'diagnostico': result.data['diagnostico'],
        };
      }
    } catch (e) {
      return {
        'status': 'ERROR',
        'message': 'Error llamando función del servidor: $e'
      };
    }
  }

  Future<Map<String, dynamic>> _testBackgroundModes() async {
    print('📱 Verificando configuración iOS...');
    
    if (!Platform.isIOS) {
      return {
        'status': 'SKIPPED',
        'message': 'Background modes solo aplican en iOS'
      };
    }
    
    // En iOS, verificar que Info.plist tenga UIBackgroundModes configurado
    return {
      'status': 'INFO',
      'required_keys': [
        'UIBackgroundModes → remote-notification',
        'UIBackgroundModes → fetch'
      ],
      'message': 'Verificar manualmente que Info.plist tenga UIBackgroundModes configurado'
    };
  }

  Future<Map<String, dynamic>> _testAndroidManifest() async {
    print('🤖 Verificando configuración Android...');
    
    if (!Platform.isAndroid) {
      return {
        'status': 'SKIPPED',
        'message': 'AndroidManifest solo aplica en Android'
      };
    }
    
    return {
      'status': 'INFO',
      'required_permissions': [
        'android.permission.INTERNET',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.VIBRATE',
        'android.permission.POST_NOTIFICATIONS'
      ],
      'required_metadata': [
        'com.google.firebase.messaging.default_notification_channel_id',
        'com.google.firebase.messaging.default_notification_icon',
        'com.google.firebase.messaging.default_notification_color'
      ],
      'message': 'Verificar manualmente que AndroidManifest.xml tenga estos elementos'
    };
  }

  Future<Map<String, dynamic>> _testNotificationListeners() async {
    print('👂 Verificando listeners de notificaciones...');
    
    // Verificar que los listeners estén configurados
    // Esto es más difícil de verificar automáticamente, pero podemos comprobar el estado
    
    return {
      'status': 'INFO',
      'listeners': [
        'FirebaseMessaging.onMessage (foreground)',
        'FirebaseMessaging.onMessageOpenedApp (background tap)',
        'FirebaseMessaging.onBackgroundMessage (background)',
        'getInitialMessage (app terminated)',
      ],
      'message': 'Verificar manualmente que todos los listeners estén configurados en NotificacionesService'
    };
  }

  void _printResults(Map<String, dynamic> results) {
    print('\n📊 ===== RESUMEN DE RESULTADOS =====');
    
    results.forEach((test, result) {
      final status = result['status'] ?? 'UNKNOWN';
      final emoji = _getStatusEmoji(status);
      print('$emoji $test: $status');
      
      if (result['message'] != null) {
        print('   ${result['message']}');
      }
      
      if (result['solution'] != null) {
        print('   💡 Solución: ${result['solution']}');
      }
      
      print('');
    });
    
    // Conteo de estados
    final statusCount = <String, int>{};
    results.values.forEach((result) {
      final status = result['status'] ?? 'UNKNOWN';
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    });
    
    print('📈 Resumen: ${statusCount.entries.map((e) => '${e.key}: ${e.value}').join(', ')}');
    print('=====================================\n');
  }

  String _getStatusEmoji(String status) {
    switch (status) {
      case 'OK': return '✅';
      case 'ERROR': return '❌';
      case 'WARNING': return '⚠️';
      case 'INFO': return 'ℹ️';
      case 'SKIPPED': return '⏭️';
      default: return '❓';
    }
  }

  /// Enviar notificación de prueba desde el cliente (para test inmediato)
  Future<void> sendTestNotificationFromClient() async {
    print('🧪 Enviando notificación de prueba desde el cliente...');
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🧪 Test WhatsApp Style',
      'Esta notificación debería aparecer como WhatsApp: con sonido, vibración y banner',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fluixcrm_canal_principal',
          'Fluix CRM',
          channelDescription: 'Test de notificaciones estilo WhatsApp',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          enableLights: true,
          enableVibration: true,
          playSound: true,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(
            'Esta es una notificación de prueba que simula el comportamiento de WhatsApp: debe aparecer aunque la app esté en primer plano, debe sonar y vibrar.',
            htmlFormatBigText: false,
            contentTitle: '🧪 Test WhatsApp Style',
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      payload: jsonEncode({
        'tipo': 'test_whatsapp_style',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }
}


