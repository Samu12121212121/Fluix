import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Inicializa el usuario administrador y lo vincula siempre a la empresa propietaria.
///
/// ⚠️ SEGURIDAD: Este archivo SOLO funciona en modo debug.
/// En release, todas las funciones son no-op.
class AdminInitializer {

  // ╔══════════════════════════════════════════════════════════════════════╗
  // ║  ⚠️ Credenciales eliminadas — configura tu cuenta en Firebase Auth  ║
  // ╚══════════════════════════════════════════════════════════════════════╝
  static const String adminEmail    = '';
  static const String adminPassword = '';
  static const String empresaId     = 'ztZblwm1w71wNQtzHV7S';

  static const List<Map<String, dynamic>> _todosModulos = [
    {'id': 'propietario','activo': true},
    {'id': 'dashboard',    'activo': true},
    {'id': 'valoraciones', 'activo': true},
    {'id': 'estadisticas', 'activo': true},
    {'id': 'reservas',     'activo': true},
    {'id': 'web',          'activo': true},
    {'id': 'whatsapp',     'activo': true},
    {'id': 'facturacion',  'activo': true},
    {'id': 'pedidos',      'activo': true},
    {'id': 'tareas',       'activo': true},
    {'id': 'clientes',     'activo': true},
    {'id': 'empleados',    'activo': true},
    {'id': 'servicios',    'activo': true},
    {'id': 'nominas',      'activo': true},
  ];

  static const List<String> _subcoleccionesLimpiables = [
    'servicios', 'clientes', 'reservas', 'valoraciones',
    'secciones_web', 'catalogo', 'productos', 'facturas',
    'pedidos', 'pedidos_whatsapp', 'tareas', 'transacciones',
    'nominas', 'equipos', 'dispositivos',
  ];

  /// Crea o actualiza el usuario propietario y la empresa.
  /// Se puede llamar tanto autenticado como sin autenticar:
  /// si el email ya existe en Auth, hace signIn automáticamente.
  static Future<void> crearUsuarioAdmin() async {
    if (!kDebugMode) {
      debugPrint('⛔ AdminInitializer deshabilitado en release');
      return;
    }
    if (adminEmail.isEmpty || adminPassword.isEmpty) {
      debugPrint('⛔ AdminInitializer: credenciales no configuradas');
      return;
    }

    final auth = FirebaseAuth.instance;
    final db   = FirebaseFirestore.instance;

    debugPrint('🔧 Verificando cuenta propietaria...');

    // ── PASO 1: Obtener UID (crear cuenta o hacer login) ─────────────
    String uid;

    if (auth.currentUser?.email?.toLowerCase() == adminEmail.toLowerCase()) {
      // Ya estamos logueados con la cuenta correcta
      uid = auth.currentUser!.uid;
      debugPrint('✅ Ya autenticado: $uid');
    } else {
      // Intentar crear la cuenta en Firebase Auth
      try {
        final cred = await auth.createUserWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
        await cred.user!.updateDisplayName('Administrador Fluix CRM');
        uid = cred.user!.uid;
        debugPrint('✅ Cuenta Auth creada: $uid');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // La cuenta ya existe → hacer login (NO signOut hasta terminar)
          final cred = await auth.signInWithEmailAndPassword(
            email: adminEmail,
            password: adminPassword,
          );
          uid = cred.user!.uid;
          debugPrint('✅ Login correcto: $uid');
        } else if (e.code == 'network-request-failed') {
          debugPrint('ℹ️ Sin red — AdminInitializer pospuesto');
          return;
        } else {
          debugPrint('❌ Error Auth: ${e.code} — ${e.message}');
          rethrow;
        }
      }
    }

    final now        = DateTime.now();
    final empresaRef = db.collection('empresas').doc(empresaId);

    // ── PASO 2: Escribir /usuarios/{uid} PRIMERO ──────────────────────
    // Un usuario siempre puede escribir su propio doc (regla: uid == userId).
    // Esto es necesario ANTES de escribir empresas/ para que la regla
    // esPropietario() encuentre el doc con rol:'propietario'.
    await db.collection('usuarios').doc(uid).set({
      'nombre':            'Administrador Fluix CRM',
      'correo':            adminEmail,
      'telefono':          '+34 900 123 456',
      'rol':               'propietario',
      'empresa_id':        empresaId,
      'activo':            true,
      'permisos':          [],
      'fecha_creacion':    now.toIso8601String(),
      'token_dispositivo': null,
      'token_actualizado': null,
      'plataforma':        null,
    }, SetOptions(merge: true));
    debugPrint('✅ /usuarios/$uid → propietario');

    // ── PASO 3: Documento raíz de empresa ─────────────────────────────
    // Ahora la regla esPropietario() pasará porque el doc de usuarios existe.
    await empresaRef.set({
      'nombre':                'Fluix CRM',
      'correo':                adminEmail,
      'telefono':              '+34 900 123 456',
      'direccion':             '',
      'descripcion':           'Plataforma de gestión empresarial',
      'sitio_web':             'fluixtech.com',
      'dominio':               'fluixtech.com',
      'categoria':             'Tecnología',
      'onboarding_completado': true,
      'activa':                true,
      'fecha_creacion':        Timestamp.fromDate(now),
    }, SetOptions(merge: true));
    debugPrint('✅ Empresa actualizada');

    // ── PASO 4: Módulos (lista completa) ──────────────────────────────
    await _actualizarModulosInterno(empresaRef);

    // ── PASO 5: Suscripción (solo si no existe) ───────────────────────
    final suscDoc = await empresaRef.collection('suscripcion').doc('actual').get();
    if (!suscDoc.exists) {
      await empresaRef.collection('suscripcion').doc('actual').set({
        'estado':        'ACTIVA',
        'plan':          'enterprise',
        'fecha_inicio':  Timestamp.fromDate(now),
        'fecha_fin':     Timestamp.fromDate(now.add(const Duration(days: 3650))),
        'aviso_enviado': false,
        'ultimo_aviso':  null,
      });
      debugPrint('✅ Suscripción creada');
    }

    // ── PASO 6: Configuraciones auxiliares ───────────────────────────
    await empresaRef.collection('configuracion').doc('facturacion').set(
      {'ultimo_numero_factura': 0}, SetOptions(merge: true));

    await empresaRef.collection('configuracion').doc('general').set({
      'fecha_instalacion_script': null,
      'script_activo':            false,
      'dominio':                  'fluixtech.com',
      'modulos_activos': {
        'estadisticas': true, 'eventos': true, 'contenido_dinamico': true,
      },
    }, SetOptions(merge: true));

    // ── PASO 7: Estadísticas base ─────────────────────────────────────
    await empresaRef.collection('estadisticas').doc('resumen').set({
      'fecha_calculo': now.toIso8601String(),
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await empresaRef.collection('estadisticas').doc('web_resumen').set({
      'visitas_totales': 0, 'visitas_mes': 0, 'ultima_visita': null,
      'sitio_web': 'fluixtech.com', 'nombre_empresa': 'Fluix CRM',
      'total_valoraciones': 0, 'valoracion_promedio': 0.0,
      'fecha_inicio_estadisticas': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('🎉 AdminInitializer completado — $adminEmail / $empresaId');
  }

  static Future<void> _actualizarModulosInterno(DocumentReference empresaRef) async {
    await empresaRef.collection('configuracion').doc('modulos').set({
      'modulos': _todosModulos,
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ ${_todosModulos.length} módulos configurados');
  }

  /// Limpia subcolecciones de datos de prueba sin tocar config ni suscripción.
  static Future<void> limpiarDatosPrueba() async {
    final db  = FirebaseFirestore.instance;
    final ref = db.collection('empresas').doc(empresaId);

    debugPrint('🧹 Limpiando datos de $empresaId...');
    for (final col in _subcoleccionesLimpiables) {
      try {
        final snap = await ref.collection(col).get();
        if (snap.docs.isEmpty) continue;
        final batch = db.batch();
        for (final doc in snap.docs) batch.delete(doc.reference);
        await batch.commit();
        debugPrint('  🗑️ $col: ${snap.docs.length} eliminados');
      } catch (e) {
        debugPrint('  ⚠️ Error en $col: $e');
      }
    }
    debugPrint('✅ Limpieza completada');
  }

  /// Actualiza la lista de módulos a la versión completa.
  static Future<void> actualizarModulos() async {
    final empresaRef = FirebaseFirestore.instance
        .collection('empresas').doc(empresaId);
    await _actualizarModulosInterno(empresaRef);
  }
}
