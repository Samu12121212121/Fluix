import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'notificaciones_service.dart';
import 'push_notifications_tester.dart';

/// Widget flotante de debug para verificar y renovar el token FCM
/// Solo visible en modo DEBUG
class DebugFCMWidget extends StatefulWidget {
  const DebugFCMWidget({super.key});

  @override
  State<DebugFCMWidget> createState() => _DebugFCMWidgetState();
}

class _DebugFCMWidgetState extends State<DebugFCMWidget> {
  bool _visible = false;
  String? _tokenActual;
  String? _tokenFirestore;
  bool _cargando = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Botón flotante para mostrar/ocultar
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'debug_fcm',
            backgroundColor: Colors.orange,
            child: Icon(_visible ? Icons.close : Icons.bug_report),
            onPressed: () {
              setState(() => _visible = !_visible);
              if (_visible && _tokenActual == null) {
                _cargarTokens();
              }
            },
          ),
        ),

        // Panel de debug
        if (_visible)
          Positioned(
            bottom: 160,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bug_report, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Debug FCM',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    
                    if (_cargando)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      // Token actual del dispositivo
                      const Text(
                        'Token actual:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _tokenActual ?? 'Cargando...',
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 12),

                      // Token en Firestore
                      const Text(
                        'Token en Firestore:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _tokenFirestore ?? 'Cargando...',
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 4),
                      
                      // Indicador de coincidencia
                      if (_tokenActual != null && _tokenFirestore != null)
                        Row(
                          children: [
                            Icon(
                              _tokenActual == _tokenFirestore
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: _tokenActual == _tokenFirestore
                                  ? Colors.green
                                  : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _tokenActual == _tokenFirestore
                                  ? 'Tokens coinciden ✓'
                                  : '¡Tokens diferentes!',
                              style: TextStyle(
                                fontSize: 11,
                                color: _tokenActual == _tokenFirestore
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 12),

                      // Botones de acción
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Renovar', style: TextStyle(fontSize: 11)),
                              onPressed: _renovarToken,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copiar', style: TextStyle(fontSize: 11)),
                              onPressed: _copiarToken,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      
                      // Botón de prueba
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.notification_add, size: 16),
                          label: const Text('Probar notificación local', style: TextStyle(fontSize: 11)),
                          onPressed: _probarNotificacion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Botón de prueba PUSH via Cloud Function
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.cloud, size: 16),
                          label: const Text('🔥 Probar PUSH (Cloud)', style: TextStyle(fontSize: 11)),
                          onPressed: _probarPushCloud,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Botón de test completo estilo WhatsApp
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.analytics, size: 16),
                          label: const Text('🧪 TEST COMPLETO', style: TextStyle(fontSize: 11)),
                          onPressed: _runCompleteTest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Botón de notificación estilo WhatsApp
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.message, size: 16),
                          label: const Text('💬 Test WhatsApp Style', style: TextStyle(fontSize: 11)),
                          onPressed: _testWhatsAppStyle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _cargarTokens() async {
    setState(() => _cargando = true);
    
    try {
      // Token actual del dispositivo
      final token = await FirebaseMessaging.instance.getToken();
      
      // Token en Firestore
      final uid = FirebaseAuth.instance.currentUser?.uid;
      String? tokenFS;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .get();
        tokenFS = doc.data()?['token_dispositivo'] as String?;
      }
      
      setState(() {
        _tokenActual = token;
        _tokenFirestore = tokenFS;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando tokens: $e')),
        );
      }
    }
  }

  Future<void> _renovarToken() async {
    setState(() => _cargando = true);
    
    try {
      // Borrar token actual
      await FirebaseMessaging.instance.deleteToken();
      
      // Esperar un momento
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Obtener nuevo token
      final nuevoToken = await FirebaseMessaging.instance.getToken();
      
      if (nuevoToken != null) {
        // Guardar en Firestore
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .set({
            'token_dispositivo': nuevoToken,
            'token_actualizado': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // También en dispositivos
          final userDoc = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .get();
          final empresaId = userDoc.data()?['empresa_id'] as String?;
          if (empresaId != null) {
            await FirebaseFirestore.instance
                .collection('empresas')
                .doc(empresaId)
                .collection('dispositivos')
                .doc(uid)
                .set({
              'token': nuevoToken,
              'ultima_actualizacion': FieldValue.serverTimestamp(),
              'activo': true,
            }, SetOptions(merge: true));
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Token renovado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Recargar
        await _cargarTokens();
      }
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error renovando token: $e')),
        );
      }
    }
  }

  void _copiarToken() {
    if (_tokenActual != null) {
      Clipboard.setData(ClipboardData(text: _tokenActual!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token copiado al portapapeles'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _probarNotificacion() async {
    await NotificacionesService().notificarNuevaReserva(
      clienteNombre: 'Cliente de Prueba',
      servicio: 'Servicio Test',
      fecha: DateTime.now().toString(),
      empresaId: 'test',
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📱 Notificación local enviada'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _probarPushCloud() async {
    setState(() => _cargando = true);
    
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('testPushNotification');
      final result = await callable.call<Map<String, dynamic>>();
      
      final data = result.data;
      final ok = data['ok'] as bool? ?? false;
      final diagnostico = data['diagnostico'] as Map<String, dynamic>? ?? {};
      
      setState(() => _cargando = false);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(ok ? Icons.check_circle : Icons.error, 
                     color: ok ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(ok ? 'Push enviado' : 'Error'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ok)
                    Text('Message ID: ${data['message_id']}')
                  else
                    Text('Error: ${data['error']}\nCode: ${data['error_code'] ?? 'N/A'}'),
                  const SizedBox(height: 16),
                  const Text('Diagnóstico:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...diagnostico.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${e.key}: ${e.value}', 
                           style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                  )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Ejecutar test completo de notificaciones push
  Future<void> _runCompleteTest() async {
    setState(() => _cargando = true);
    
    try {
      final tester = PushNotificationsTester();
      final results = await tester.runCompleteTest();
      
      if (!mounted) return;
      
      // Mostrar resultados en un dialog detallado
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('🧪 Resultados del Test Completo'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: results.entries.map((entry) {
                  final testName = entry.key;
                  final result = entry.value as Map<String, dynamic>;
                  final status = result['status'] ?? 'UNKNOWN';
                  final emoji = _getStatusEmoji(status);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$emoji $testName',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status: $status',
                            style: TextStyle(
                              color: status == 'OK' 
                                  ? Colors.green 
                                  : status == 'ERROR' 
                                      ? Colors.red 
                                      : Colors.orange,
                            ),
                          ),
                          if (result['message'] != null) ...[
                            const SizedBox(height: 4),
                            Text(result['message'], style: const TextStyle(fontSize: 12)),
                          ],
                          if (result['solution'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '💡 ${result['solution']}',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en test completo: $e')),
        );
      }
    }
    
    setState(() => _cargando = false);
  }

  /// Probar notificación estilo WhatsApp
  Future<void> _testWhatsAppStyle() async {
    try {
      final tester = PushNotificationsTester();
      await tester.sendTestNotificationFromClient();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧪 Notificación estilo WhatsApp enviada!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enviando notificación: $e')),
        );
      }
    }
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
}

