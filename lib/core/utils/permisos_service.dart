import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../constantes/constantes_app.dart';
import 'package:planeag_flutter/services/suscripcion_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SISTEMA DE ROLES Y PERMISOS — Fluix CRM
// ═══════════════════════════════════════════════════════════════════════════════

/// Roles disponibles en la app
enum RolApp { propietario, admin, staff, clienteFinal, desconocido }

/// Datos del usuario actual en sesión
class SesionUsuario {
  final String uid;
  final String nombre;
  final String correo;
  final String empresaId;
  final RolApp rol;
  final bool activo;
  final List<String>? modulosPersonalizados;
  final bool esPropietarioPlatforma;

  const SesionUsuario({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.empresaId,
    required this.rol,
    required this.activo,
    this.modulosPersonalizados,
    this.esPropietarioPlatforma = false,
  });

  bool get esPropietario => rol == RolApp.propietario;
  bool get esAdmin => rol == RolApp.admin || rol == RolApp.propietario;
  bool get esStaff => rol == RolApp.staff;
  bool get esClienteFinal => rol == RolApp.clienteFinal;

  bool get puedeVerFinanzas => esAdmin;
  bool get puedeGestionarEmpleados => esAdmin;
  bool get puedeConfigurarDashboard => esAdmin;
  bool get puedeGestionarServicios => esAdmin;
  bool get puedeGestionarClientes => esAdmin;
  bool get puedeGestionarReservas => esAdmin;
  bool get puedeGestionarCitas => puedeGestionarReservas;
  bool get puedeVerReservas => true;
  bool get puedeCambiarEstadoReserva => true;
  bool get puedeGestionarPedidos => esAdmin;
  bool get puedeCrearFacturas => esAdmin;
  bool get puedeGestionarNominas => esAdmin;
  bool get puedeVerResumenFiscal => esAdmin;
  bool get puedeEditarWeb => esAdmin;
  bool get puedeVerTareas => esAdmin;
  bool get puedeAsignarTareas => esAdmin;
  bool get puedeGestionarSuscripcion => esAdmin;
  bool get puedeVerValoraciones => true;
  bool get puedeGestionarValoraciones => esAdmin;

  List<String> get _modulosPorRol {
    switch (rol) {
      case RolApp.propietario:
        return [
          'propietario', 'dashboard', 'reservas', 'clientes', 'valoraciones',
          'estadisticas', 'servicios', 'pedidos', 'tpv', 'whatsapp', 'tareas',
          'empleados', 'facturacion', 'nominas', 'vacaciones', 'fichaje', 'web',
        ];
      case RolApp.admin:
        return [
          'dashboard', 'reservas', 'clientes', 'valoraciones', 'estadisticas',
          'servicios', 'pedidos', 'tpv', 'whatsapp', 'tareas', 'empleados',
          'facturacion', 'nominas', 'vacaciones', 'fichaje', 'web',
        ];
      case RolApp.staff:
        return ['reservas', 'clientes', 'valoraciones', 'fichaje'];
      case RolApp.clienteFinal:
        return ['explorar'];
      default:
        return ['reservas'];
    }
  }

  List<String> get modulosVisibles {
    if (rol == RolApp.propietario || rol == RolApp.admin) {
      return _modulosPorRol;
    }
    if (modulosPersonalizados != null && modulosPersonalizados!.isNotEmpty) {
      return modulosPersonalizados!;
    }
    return _modulosPorRol;
  }

  static const todosLosModulos = [
    'dashboard', 'reservas', 'clientes', 'valoraciones',
    'estadisticas', 'servicios', 'pedidos', 'tpv', 'whatsapp', 'tareas',
    'empleados', 'facturacion', 'nominas', 'vacaciones', 'fichaje', 'web',
  ];

  String get rolNombre {
    switch (rol) {
      case RolApp.propietario:  return 'Propietario';
      case RolApp.admin:        return 'Administrador';
      case RolApp.staff:        return 'Staff';
      case RolApp.clienteFinal: return 'Cliente';
      default:                  return 'Usuario';
    }
  }

  String get rolEmoji {
    switch (rol) {
      case RolApp.propietario:  return '👑';
      case RolApp.admin:        return '🛡️';
      case RolApp.staff:        return '👤';
      case RolApp.clienteFinal: return '🙋';
      default:                  return '❓';
    }
  }
}

/// Servicio singleton que carga y cachea los datos del usuario actual
class PermisosService {
  static final PermisosService _instancia = PermisosService._();
  factory PermisosService() => _instancia;
  PermisosService._();

  SesionUsuario? _sesionActual;
  SesionUsuario? get sesion => _sesionActual;

  Future<SesionUsuario?> cargarSesion() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _sesionActual = null;
      return null;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final empresaId = data['empresa_id'] as String? ?? '';
      var rolStr = data['rol'] as String? ?? 'staff';

      // ── GUARD DEMO ──
      final correoUsuario = (data['correo'] as String? ?? '').toLowerCase();
      if (correoUsuario.contains('demo') && rolStr == 'propietario') {
        rolStr = 'admin';
        debugPrint('🔒 PermisosService: cuenta demo forzada a admin');
      }

      // ── PROTECCIÓN 1: empresa propietaria de la plataforma ──
      final esDocDePrueba = uid.startsWith('emp_fluix_');
      if (empresaId == ConstantesApp.empresaPropietariaId &&
          rolStr != 'propietario' &&
          !esDocDePrueba) {
        rolStr = 'propietario';
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .update({'rol': 'propietario', 'es_plataforma_admin': true});
        debugPrint('👑 Rol corregido a propietario para $uid');
      }

      if (empresaId == ConstantesApp.empresaPropietariaId &&
          rolStr == 'propietario' &&
          data['es_plataforma_admin'] != true) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .update({'es_plataforma_admin': true});
      }

      // ── PROTECCIÓN 2: sin admin en la empresa ──
      if (rolStr != 'propietario' && rolStr != 'admin' &&
          rolStr != 'clienteFinal' && empresaId.isNotEmpty) {
        try {
          final propietariosSnap = await FirebaseFirestore.instance
              .collection('usuarios')
              .where('empresa_id', isEqualTo: empresaId)
              .where('rol', whereIn: ['propietario', 'admin'])
              .limit(1)
              .get();

          if (propietariosSnap.docs.isEmpty) {
            final nuevoRol = empresaId == ConstantesApp.empresaPropietariaId
                ? 'propietario'
                : 'admin';
            rolStr = nuevoRol;
            await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(uid)
                .update({'rol': nuevoRol});
            debugPrint('👑 Rol promovido a $nuevoRol para $uid');
          }
        } catch (e) {
          debugPrint('ℹ️ Protección 2 omitida: $e');
        }
      }

      // ── PROTECCIÓN 3: correo coincide con el de la empresa ──
      if (rolStr != 'propietario' && rolStr != 'admin' &&
          rolStr != 'clienteFinal' && empresaId.isNotEmpty) {
        try {
          if (correoUsuario.isNotEmpty) {
            final empresaDoc = await FirebaseFirestore.instance
                .collection('empresas')
                .doc(empresaId)
                .get();
            if (empresaDoc.exists) {
              final empresaData = empresaDoc.data()!;
              final correoEmpresa = empresaData['correo'] as String? ??
                  (empresaData['perfil'] as Map<String, dynamic>?)?['correo']
                  as String? ?? '';
              if (correoEmpresa.isNotEmpty &&
                  correoUsuario == correoEmpresa.toLowerCase()) {
                final nuevoRol = empresaId == ConstantesApp.empresaPropietariaId
                    ? 'propietario'
                    : 'admin';
                rolStr = nuevoRol;
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(uid)
                    .update({'rol': nuevoRol});
                debugPrint('👑 Rol promovido a $nuevoRol (correo coincide) para $uid');
              }
            }
          }
        } catch (_) {}
      }

      final modulosPersonalizados = (data['modulos_permitidos'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList();

      final rolParsed = _parsearRol(rolStr);

      _sesionActual = SesionUsuario(
        uid: uid,
        nombre: data['nombre'] ?? '',
        correo: data['correo'] ?? FirebaseAuth.instance.currentUser?.email ?? '',
        empresaId: empresaId,
        rol: rolParsed,
        activo: data['activo'] ?? true,
        modulosPersonalizados: modulosPersonalizados,
        esPropietarioPlatforma: rolParsed == RolApp.propietario ||
            (data['es_plataforma_admin'] as bool? ?? false),
      );

      if (empresaId.isNotEmpty) {
        await SuscripcionService().cargarSuscripcion(empresaId);
      }

      return _sesionActual;
    } catch (e) {
      return null;
    }
  }

  void limpiarSesion() {
    _sesionActual = null;
    SuscripcionService().limpiar();
  }

  ResultadoAccesoModulo puedeAccederModulo(String moduloId) {
    final sesion = _sesionActual;
    if (sesion == null) return ResultadoAccesoModulo.sinAcceso;

    if (sesion.esPropietarioPlatforma) return ResultadoAccesoModulo.permitido;

    if (!sesion.modulosVisibles.contains(moduloId)) {
      return ResultadoAccesoModulo.sinAcceso;
    }

    final svc = SuscripcionService();
    if (!svc.estaActiva) {
      return ResultadoAccesoModulo.suscripcionInactiva;
    }

    if (!svc.tieneModulo(moduloId)) {
      return ResultadoAccesoModulo.upgradeRequerido;
    }

    return ResultadoAccesoModulo.permitido;
  }

  bool puedeAcceder(String moduloId) {
    return puedeAccederModulo(moduloId) == ResultadoAccesoModulo.permitido;
  }

  RolApp _parsearRol(String rol) {
    switch (rol.toLowerCase()) {
      case 'propietario':   return RolApp.propietario;
      case 'admin':         return RolApp.admin;
      case 'staff':         return RolApp.staff;
      case 'clientefinal':  return RolApp.clienteFinal;
      default:              return RolApp.desconocido;
    }
  }
}

enum ResultadoAccesoModulo {
  permitido,
  upgradeRequerido,
  sinAcceso,
  suscripcionInactiva,
}