import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/constantes/constantes_app.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Contacto de interés (formulario en pantalla de login)
//
// Guarda:
//   1. contactos_interesados/{docId}  — datos del lead
//   2. mail/{docId}                   — correo de confirmación (Firebase Trigger Email)
//   3. empresas/{propietariaId}/tareas/{tareaId} — tarea de alta prioridad
// ─────────────────────────────────────────────────────────────────────────────

class ContactoService {
  static final ContactoService _i = ContactoService._();
  factory ContactoService() => _i;
  ContactoService._();

  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  // ── Enviar el formulario de interés ───────────────────────────────────────
  Future<void> enviarContactoInteres({
    required String nombre,
    required String correo,
    String? telefono,
    required String nombreEmpresa,
    required String actividad,
    String? numTrabajadores,
  }) async {
    final ahora = Timestamp.now();

    // 1. Guardar lead en colección pública
    final leadRef = _db.collection('contactos_interesados').doc();
    await leadRef.set({
      'nombre':           nombre,
      'correo':           correo,
      'telefono':         telefono ?? '',
      'nombre_empresa':   nombreEmpresa,
      'actividad':        actividad,
      'num_trabajadores': numTrabajadores ?? '',
      'timestamp':        ahora,
      'estado':           'nuevo',
    });

    // 2. Llamar a Cloud Function para enviar los 2 emails con Resend
    try {
      print('📧 Enviando emails de contacto...');
      final resultado = await _functions.httpsCallable('enviarEmailsContactoInteres').call({
        'nombre':           nombre,
        'correo':           correo,
        'telefono':         telefono ?? '',
        'nombreEmpresa':    nombreEmpresa,
        'actividad':        actividad,
        'numTrabajadores':  numTrabajadores ?? '',
        'leadId':           leadRef.id,
        'fechaSolicitud':   _formatearFecha(ahora.toDate()),
      });
      print('✅ Emails enviados correctamente: ${resultado.data}');
    } catch (e, stack) {
      print('⚠️ ERROR enviando emails: $e');
      print('Stack trace: $stack');
      // No lanzamos error para que el usuario no vea fallo,
      // pero mostramos el error en consola para debugging
    }

    // 3. Crear tarea de alta prioridad en el módulo propietario
    //    ⚠️ Requiere regla Firestore que permita create con origen='lead_contacto'
    final tareaRef = _db
        .collection('empresas')
        .doc(ConstantesApp.empresaPropietariaId)
        .collection('tareas')
        .doc();

    await tareaRef.set({
      'empresa_id':          ConstantesApp.empresaPropietariaId,
      'titulo':              'Hablar posible nuevo cliente',
      'descripcion':         _generarDescripcionTarea(
        nombre:          nombre,
        correo:          correo,
        telefono:        telefono,
        nombreEmpresa:   nombreEmpresa,
        actividad:       actividad,
        numTrabajadores: numTrabajadores,
        leadId:          leadRef.id,
      ),
      'tipo':               'normal',
      'estado':             'pendiente',
      'prioridad':          'alta',
      'equipo_id':          null,
      'usuario_asignado_id': null,
      'creado_por_id':      'sistema_contacto',
      'fecha_limite':       null,
      'etiquetas':          ['lead', 'contacto_web'],
      'ubicacion':          null,
      'tiempo_estimado_min': null,
      'subtareas':          [],
      'registro_tiempo':    [],
      'historial': [
        {
          'usuario_id':   'sistema_contacto',
          'accion':       'creacion',
          'descripcion':  'Tarea creada automáticamente desde formulario de contacto',
          'fecha':        ahora,
        }
      ],
      'es_recurrente':              false,
      'frecuencia_recurrencia':     null,
      'fecha_creacion':             ahora,
      'fecha_actualizacion':        null,
      'solo_propietario':           true,
      'sugerencia_id':              null,
      'cliente_id':                 null,
      'configuracion_recurrencia':  null,
      'recordatorio':               null,
      'es_plantilla_recurrencia':   false,
      'plantilla_id':               null,
      'proxima_fecha_recurrencia':  null,
      // Campo especial para la regla de Firestore
      'origen':                     'lead_contacto',
    });
  }

  // ── Descripción de la tarea ───────────────────────────────────────────────
  String _generarDescripcionTarea({
    required String nombre,
    required String correo,
    String? telefono,
    required String nombreEmpresa,
    required String actividad,
    String? numTrabajadores,
    required String leadId,
  }) {
    final buf = StringBuffer();
    buf.writeln('📋 LEAD RECIBIDO DESDE EL FORMULARIO DE CONTACTO');
    buf.writeln('─────────────────────────────────────────');
    buf.writeln('👤 Nombre:       $nombre');
    buf.writeln('📧 Correo:       $correo');
    if (telefono != null && telefono.isNotEmpty) {
      buf.writeln('📞 Teléfono:     $telefono');
    }
    buf.writeln('🏢 Empresa:      $nombreEmpresa');
    buf.writeln('💼 Actividad:    $actividad');
    if (numTrabajadores != null && numTrabajadores.isNotEmpty) {
      buf.writeln('👥 Trabajadores: $numTrabajadores');
    }
    buf.writeln('─────────────────────────────────────────');
    buf.writeln('📌 Lead ID: $leadId');
    buf.writeln();
    buf.writeln('⚡ ACCIÓN: Ponerse en contacto con este potencial cliente lo antes posible.');
    buf.writeln('📧 Se ha enviado email de confirmación a: $correo');
    buf.writeln('📧 Se ha enviado notificación a: sacoor80@gmail.com');
    return buf.toString();
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year;
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio a las $hora:$minuto';
  }
}