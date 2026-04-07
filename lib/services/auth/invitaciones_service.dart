import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO
// ─────────────────────────────────────────────────────────────────────────────

enum EstadoInvitacion { pendiente, usada, expirada }

class Invitacion {
  final String token;
  final String email;
  final String rol;          // 'admin' | 'staff'
  final String empresaId;
  final String empresaNombre;
  final String creadoPorUid;
  final DateTime expira;
  final bool usado;
  final String? usadoPorUid;

  const Invitacion({
    required this.token,
    required this.email,
    required this.rol,
    required this.empresaId,
    required this.empresaNombre,
    required this.creadoPorUid,
    required this.expira,
    required this.usado,
    this.usadoPorUid,
  });

  EstadoInvitacion get estado {
    if (usado) return EstadoInvitacion.usada;
    if (expira.isBefore(DateTime.now())) return EstadoInvitacion.expirada;
    return EstadoInvitacion.pendiente;
  }

  bool get valida => estado == EstadoInvitacion.pendiente;

  factory Invitacion.fromFirestore(Map<String, dynamic> data) => Invitacion(
        token: data['token'] as String? ?? '',
        email: data['email'] as String? ?? '',
        rol: data['rol'] as String? ?? 'staff',
        empresaId: data['empresa_id'] as String? ?? '',
        empresaNombre: data['empresa_nombre'] as String? ?? '',
        creadoPorUid: data['creado_por'] as String? ?? '',
        expira: (data['expira'] as Timestamp?)?.toDate() ?? DateTime.now(),
        usado: data['usado'] as bool? ?? false,
        usadoPorUid: data['usado_por'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO
//
// Estructura Firestore:
//   invitaciones/{token}
//     token:          string (UUID v4)
//     email:          string
//     rol:            'admin' | 'staff'
//     empresa_id:     string
//     empresa_nombre: string
//     creado_por:     string (UID del admin)
//     expira:         Timestamp (ahora + 72h)
//     usado:          bool
//     usado_por:      string? (UID del nuevo usuario)
//     fecha_creacion: Timestamp
//
// El envío del email se hace vía Cloud Function 'enviarInvitacion'.
// El deep link tiene la forma:  fluixcrm://invite?token=XXX
// ─────────────────────────────────────────────────────────────────────────────

class InvitacionesService {
  static final InvitacionesService _i = InvitacionesService._();
  factory InvitacionesService() => _i;
  InvitacionesService._();

  final _db = FirebaseFirestore.instance;

  // ── CREAR Y ENVIAR (llama a la Cloud Function) ───────────────────────────

  /// Crea el documento de invitación en Firestore y dispara el email
  /// via Cloud Function.
  /// El admin solo necesita pasar email, rol y el contexto de empresa.
  Future<void> enviarInvitacion({
    required String email,
    required String rol,
    required String empresaId,
    required String empresaNombre,
    required String creadoPorUid,
  }) async {
    // Generar token único
    final token = _generarToken();
    final expira = DateTime.now().add(const Duration(hours: 72));

    // Guardar en Firestore
    await _db.collection('invitaciones').doc(token).set({
      'token':          token,
      'email':          email.toLowerCase().trim(),
      'rol':            rol,
      'empresa_id':     empresaId,
      'empresa_nombre': empresaNombre,
      'creado_por':     creadoPorUid,
      'expira':         Timestamp.fromDate(expira),
      'usado':          false,
      'usado_por':      null,
      'fecha_creacion': FieldValue.serverTimestamp(),
    });

    // La Cloud Function escucha onDocumentCreated en 'invitaciones/{token}'
    // y envía el email automáticamente. No se necesita llamada explícita.
  }

  // ── VALIDAR TOKEN ────────────────────────────────────────────────────────

  Future<Invitacion?> validarToken(String token) async {
    final doc = await _db.collection('invitaciones').doc(token).get();
    if (!doc.exists) return null;
    return Invitacion.fromFirestore(doc.data()!);
  }

  // ── COMPLETAR REGISTRO ───────────────────────────────────────────────────

  /// Llama tras crear el usuario en Firebase Auth.
  /// Crea el documento en /usuarios y marca la invitación como usada.
  Future<void> completarRegistro({
    required String token,
    required User firebaseUser,
    required String nombre,
    required Invitacion invitacion,
  }) async {
    final batch = _db.batch();

    // Crear documento del nuevo usuario
    final userRef = _db.collection('usuarios').doc(firebaseUser.uid);
    batch.set(userRef, {
      'nombre':         nombre.trim(),
      'correo':         invitacion.email,
      'telefono':       '',
      'empresa_id':     invitacion.empresaId,
      'rol':            invitacion.rol,
      'activo':         true,
      'fecha_creacion': FieldValue.serverTimestamp(),
      'invitado_por':   invitacion.creadoPorUid,
    });

    // Marcar invitación como usada
    final invRef = _db.collection('invitaciones').doc(token);
    batch.update(invRef, {
      'usado':    true,
      'usado_por': firebaseUser.uid,
      'fecha_uso': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── LISTAR INVITACIONES DE UNA EMPRESA ──────────────────────────────────

  Stream<List<Invitacion>> invitacionesStream(String empresaId) => _db
      .collection('invitaciones')
      .where('empresa_id', isEqualTo: empresaId)
      .orderBy('fecha_creacion', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => Invitacion.fromFirestore(d.data()))
          .toList());

  // ── REVOCAR ─────────────────────────────────────────────────────────────

  Future<void> revocar(String token) async {
    await _db.collection('invitaciones').doc(token).update({
      'expira': Timestamp.fromDate(DateTime.now().subtract(const Duration(seconds: 1))),
    });
  }

  // ── PRIVADO ──────────────────────────────────────────────────────────────

  String _generarToken() {
    // UUID v4 sin dependencia externa
    final now = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = List.generate(16, (_) {
      final val = (DateTime.now().microsecondsSinceEpoch ^
              (now.hashCode * 31)) %
          256;
      return val.toRadixString(16).padLeft(2, '0');
    }).join();
    return '${random.substring(0, 8)}-${random.substring(8, 12)}-'
        '4${random.substring(13, 16)}-'
        '${(8 + (random.codeUnitAt(16) % 4)).toRadixString(16)}'
        '${random.substring(17, 20)}-${random.substring(20)}';
  }
}

