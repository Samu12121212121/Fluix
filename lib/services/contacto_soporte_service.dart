import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constantes/constantes_app.dart';
import 'bandeja_notificaciones_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ContactoSoporteService
//
// Guarda el mensaje en `contacto_soporte/{id}` (colección raíz).
// El trigger Cloud Function `onNuevoContactoSoporte` se encarga de:
//   1. Enviar email a sacoor80@gmail.com
//   2. Crear notificación in-app para el propietario de plataforma
// ─────────────────────────────────────────────────────────────────────────────

class ContactoSoporteService {
  static final _i = ContactoSoporteService._();
  factory ContactoSoporteService() => _i;
  ContactoSoporteService._();

  final _db = FirebaseFirestore.instance;

  Future<void> enviar({
    required String empresaId,
    required String empresaNombre,
    required String nombreContacto,
    required String emailContacto,
    required String asunto,
    required String mensaje,
  }) async {
    // 1. Guardar en Firestore (el trigger CF envía el email automáticamente)
    await _db.collection('contacto_soporte').add({
      'empresa_id':      empresaId,
      'empresa_nombre':  empresaNombre,
      'nombre_contacto': nombreContacto,
      'email_contacto':  emailContacto,
      'asunto':          asunto,
      'mensaje':         mensaje,
      'fecha':           FieldValue.serverTimestamp(),
      'estado':          'nuevo',
    });

    // 2. Notificación in-app inmediata al propietario de plataforma
    try {
      final resumen = mensaje.length > 80 ? '${mensaje.substring(0, 80)}…' : mensaje;
      await BandejaNotificacionesService().crear(
        empresaId: ConstantesApp.empresaPropietariaId,
        titulo: '📨 Soporte: $asunto',
        cuerpo: '$empresaNombre — $resumen',
        tipo: TipoNotificacion.generica,
        remitenteNombre: empresaNombre,
        remitenteEmail: emailContacto,
      );
    } catch (_) {
      // No bloquear si falla la notificación in-app
    }
  }
}
