import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelos/fichaje.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FICHAJE DEMO DATA
//
// Crea datos de demostración compatibles con la arquitectura de UN documento
// por jornada (modelos/fichaje.dart + servicios/fichaje_service.dart).
//
// USO:
//   await FichajeDemoData.crearTodosDatosDemo(
//     empresaId: 'empresa_abc',
//     adminUid: 'uid_del_admin',
//   );
//
// PINs de los empleados de demo:
//   María García   → 1234
//   Juan López     → 5678
//   Ana Torres     → 9012
//   Carlos Sánchez → 3456
//   Laura Fernández→ 7890
// ═══════════════════════════════════════════════════════════════════════════════

class FichajeDemoData {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _fichajes(
      String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('fichajes');

  static CollectionReference<Map<String, dynamic>> _empleados(
      String empresaId) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('empleados_fichaje');

  // ═══════════════════════════════════════════════════════════════════════════
  // CREAR EMPLEADOS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> crearEmpleadosDemo(String empresaId) async {
    final empleados = [
      {'uid': 'demo_maria_garcia', 'nombre': 'Maria Garcia Lopez', 'pin': '1234'},
      {'uid': 'demo_juan_lopez', 'nombre': 'Juan Lopez Martinez', 'pin': '5678'},
      {'uid': 'demo_ana_torres', 'nombre': 'Ana Torres Ruiz', 'pin': '9012'},
      {'uid': 'demo_carlos_sanchez', 'nombre': 'Carlos Sanchez Diaz', 'pin': '3456'},
      {'uid': 'demo_laura_fernandez', 'nombre': 'Laura Fernandez Gil', 'pin': '7890'},
    ];

    for (final e in empleados) {
      await _empleados(empresaId).doc(e['uid']).set({
        'nombre': e['nombre'],
        'pin': e['pin'],
        'empresa_id': empresaId,
        'activo': true,
        'creado_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREAR FICHAJES DE HOY
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> crearFichajesDemo(String empresaId) async {
    final hoy = DateTime.now();
    final f = (int h, int m) =>
        Timestamp.fromDate(DateTime(hoy.year, hoy.month, hoy.day, h, m, 0));
    final fechaHoy =
        '${hoy.year.toString().padLeft(4, '0')}-'
        '${hoy.month.toString().padLeft(2, '0')}-'
        '${hoy.day.toString().padLeft(2, '0')}';

    // ── María: jornada completa cerrada ──────────────────────────────────────
    await _fichajes(empresaId).add({
      'empleado_id': 'demo_maria_garcia',
      'empleado_nombre': 'Maria Garcia Lopez',
      'fecha': fechaHoy,
      'entrada': f(9, 0),
      'salida': f(17, 30),
      'pausas': [
        {'inicio': f(11, 0), 'fin': f(11, 15)},
        {'inicio': f(14, 0), 'fin': f(14, 30)},
      ],
      'tipo_horas': TipoHoras.ordinarias.name,
      'dispositivo_id': 'tablet_demo',
      'creado_at': f(9, 0),
      'es_correccion': false,
      'correccion_de': null,
      'motivo_correccion': null,
      'corregido_por_uid': null,
      'corregido_at': null,
    });

    // ── Juan: trabajando actualmente ─────────────────────────────────────────
    await _fichajes(empresaId).add({
      'empleado_id': 'demo_juan_lopez',
      'empleado_nombre': 'Juan Lopez Martinez',
      'fecha': fechaHoy,
      'entrada': f(10, 15),
      'salida': null,
      'pausas': [
        {'inicio': f(14, 0), 'fin': f(14, 30)},
      ],
      'tipo_horas': TipoHoras.ordinarias.name,
      'dispositivo_id': 'tablet_demo',
      'creado_at': f(10, 15),
      'es_correccion': false,
      'correccion_de': null,
      'motivo_correccion': null,
      'corregido_por_uid': null,
      'corregido_at': null,
    });

    // ── Ana: en pausa activa ahora mismo ─────────────────────────────────────
    final ahora = DateTime.now();
    final hace5 = DateTime(ahora.year, ahora.month, ahora.day,
        ahora.hour, ahora.minute - 5, 0);
    await _fichajes(empresaId).add({
      'empleado_id': 'demo_ana_torres',
      'empleado_nombre': 'Ana Torres Ruiz',
      'fecha': fechaHoy,
      'entrada': f(8, 45),
      'salida': null,
      'pausas': [
        // fin: null → pausa activa
        {'inicio': Timestamp.fromDate(hace5), 'fin': null},
      ],
      'tipo_horas': TipoHoras.ordinarias.name,
      'dispositivo_id': 'tablet_demo',
      'creado_at': f(8, 45),
      'es_correccion': false,
      'correccion_de': null,
      'motivo_correccion': null,
      'corregido_por_uid': null,
      'corregido_at': null,
    });

    // ── Carlos: sin fichar hoy (no se crea documento)  ───────────────────────
    // Intencionado: el dashboard mostrará estado "Sin fichar"

    // ── Laura: horas extraordinarias ─────────────────────────────────────────
    await _fichajes(empresaId).add({
      'empleado_id': 'demo_laura_fernandez',
      'empleado_nombre': 'Laura Fernandez Gil',
      'fecha': fechaHoy,
      'entrada': f(7, 30),
      'salida': f(19, 0),
      'pausas': [
        {'inicio': f(14, 0), 'fin': f(15, 0)},
      ],
      'tipo_horas': TipoHoras.extraordinarias.name,
      'dispositivo_id': 'tablet_demo',
      'creado_at': f(7, 30),
      'es_correccion': false,
      'correccion_de': null,
      'motivo_correccion': null,
      'corregido_por_uid': null,
      'corregido_at': null,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREAR EJEMPLO DE CORRECCIÓN (audit trail)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> crearCorreccionDemo(
      String empresaId, String adminUid) async {
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    final f = (int h, int m) =>
        Timestamp.fromDate(DateTime(ayer.year, ayer.month, ayer.day, h, m, 0));
    final fechaAyer =
        '${ayer.year.toString().padLeft(4, '0')}-'
        '${ayer.month.toString().padLeft(2, '0')}-'
        '${ayer.day.toString().padLeft(2, '0')}';

    // Documento original con error (salida: null)
    final original = await _fichajes(empresaId).add({
      'empleado_id': 'demo_carlos_sanchez',
      'empleado_nombre': 'Carlos Sanchez Diaz',
      'fecha': fechaAyer,
      'entrada': f(9, 0),
      'salida': null, // ← Error: olvidó fichar salida
      'pausas': [],
      'tipo_horas': TipoHoras.ordinarias.name,
      'dispositivo_id': 'tablet_demo',
      'creado_at': f(9, 0),
      'es_correccion': false,
      'correccion_de': null,
      'motivo_correccion': null,
      'corregido_por_uid': null,
      'corregido_at': null,
    });

    // Documento de corrección — el original NUNCA se modifica
    await _fichajes(empresaId).add({
      'empleado_id': 'demo_carlos_sanchez',
      'empleado_nombre': 'Carlos Sanchez Diaz',
      'fecha': fechaAyer,
      'entrada': f(9, 0),
      'salida': f(17, 0), // ← Corregido
      'pausas': [],
      'tipo_horas': TipoHoras.ordinarias.name,
      'dispositivo_id': 'tablet_demo',
      'creado_at': FieldValue.serverTimestamp(),
      // ── Audit trail ────────────────────────────────────────────────────────
      'es_correccion': true,
      'correccion_de': original.id,
      'motivo_correccion': 'Empleado olvido fichar salida',
      'corregido_por_uid': adminUid,
      'corregido_at': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ENTRADA PRINCIPAL
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> crearTodosDatosDemo({
    required String empresaId,
    required String adminUid,
  }) async {
    await crearEmpleadosDemo(empresaId);
    await crearFichajesDemo(empresaId);
    await crearCorreccionDemo(empresaId, adminUid);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIMPIAR DATOS DE DEMO
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> eliminarDatosDemo(String empresaId) async {
    // Empleados demo
    final empleados = await _empleados(empresaId)
        .where('pin', whereIn: ['1234', '5678', '9012', '3456', '7890'])
        .get();
    for (final doc in empleados.docs) {
      await doc.reference.delete();
    }

    // Fichajes demo
    final fichajes = await _fichajes(empresaId)
        .where('dispositivo_id', isEqualTo: 'tablet_demo')
        .get();
    for (final doc in fichajes.docs) {
      await doc.reference.delete();
    }
  }
}