import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../constantes/constantes_app.dart';
import 'package:planeag_flutter/services/suscripcion_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SISTEMA DE ROLES Y PERMISOS — Fluix CRM
//
// ROLES:
//   - propietario: EXCLUSIVO de la empresa FluixTech (plataforma).
//     Solo el admin de la plataforma tiene este rol.
//     ID fijo: ConstantesApp.empresaPropietariaId
//
//   - admin: Dueño de una empresa cliente. Tiene acceso completo a todos
//     los módulos de SU empresa (igual que propietario excepto el módulo
//     'propietario' de la plataforma). Puede gestionar empleados,
//     facturación, configuración, suscripción, etc.
//
//   - staff: Empleado invitado. Solo ve los módulos que el admin le
//     haya asignado (o los del rol por defecto: reservas, citas, clientes,
//     valoraciones).
//
// PROTECCIONES AUTOMÁTICAS (en cargarSesion):
//   1. Si empresa == empresaPropietariaId → fuerza rol a 'propietario'
//   2. Si no hay admin/propietario en la empresa → promueve al usuario
//   3. Si correo usuario == correo empresa → promueve al usuario
//
// Ver documentación completa: FLUJO_CREACION_CUENTAS.md
// ═══════════════════════════════════════════════════════════════════════════════

/// Roles disponibles en la app
enum RolApp { propietario, admin, staff, desconocido }

/// Datos del usuario actual en sesión
class SesionUsuario {
  final String uid;
  final String nombre;
  final String correo;
  final String empresaId;
  final RolApp rol;
  final bool activo;
  /// Módulos personalizados asignados por el admin. null = usar los del rol.
  final List<String>? modulosPersonalizados;

  /// true si es el administrador de la PLATAFORMA FluxTech (Samu).
  /// Solo él puede crear/gestionar cuentas de clientes.
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

  // ── Comprobaciones de rol ──────────────────────────────────────────────────
  bool get esPropietario => rol == RolApp.propietario;
  bool get esAdmin => rol == RolApp.admin || rol == RolApp.propietario;
  bool get esStaff => rol == RolApp.staff;

  // ── Permisos por módulo ────────────────────────────────────────────────────

  /// Puede ver estadísticas financieras y facturación
  bool get puedeVerFinanzas => esAdmin;

  /// Puede crear/editar/borrar empleados
  bool get puedeGestionarEmpleados => esAdmin;

  /// Puede cambiar la configuración de módulos del dashboard
  bool get puedeConfigurarDashboard => esAdmin;

  /// Puede crear/editar servicios
  bool get puedeGestionarServicios => esAdmin;

  /// Puede crear/editar clientes (staff solo puede ver)
  bool get puedeGestionarClientes => esAdmin;

  /// Puede crear/editar/cancelar reservas
  bool get puedeGestionarReservas => esAdmin;

  /// Alias para reutilizar permisos del módulo de citas
  bool get puedeGestionarCitas => puedeGestionarReservas;

  /// Puede ver reservas
  bool get puedeVerReservas => true; // todos

  /// Puede marcar estado de reservas (staff puede confirmar/completar)
  bool get puedeCambiarEstadoReserva => true; // todos

  /// Puede gestionar pedidos
  bool get puedeGestionarPedidos => esAdmin;

  /// Puede crear facturas
  bool get puedeCrearFacturas => esAdmin;

  /// Puede gestionar nóminas (generar, recalcular, editar, eliminar, exportar)
  bool get puedeGestionarNominas => esAdmin;

  /// Puede ver el resumen fiscal
  bool get puedeVerResumenFiscal => esAdmin;

  /// Puede editar contenido web
  bool get puedeEditarWeb => esAdmin;

  /// Puede ver tareas propias
  bool get puedeVerTareas => esAdmin;

  /// Puede crear tareas para otros
  bool get puedeAsignarTareas => esAdmin;

  /// Puede gestionar la suscripción
  bool get puedeGestionarSuscripcion => esAdmin;

  /// Puede ver valoraciones
  bool get puedeVerValoraciones => true; // todos

  /// Puede responder/eliminar valoraciones
  bool get puedeGestionarValoraciones => esAdmin;

  // ── Módulos visibles según rol ─────────────────────────────────────────────
  
  /// Módulos por defecto del rol (sin personalización)
  List<String> get _modulosPorRol {
    switch (rol) {
      case RolApp.propietario:
        // Ve absolutamente todo
        return [
          'propietario',   // Panel exclusivo del dueño de la plataforma
          'dashboard',
          'reservas',
          'citas',
          'clientes',
          'valoraciones',
          'estadisticas',
          'servicios',
          'pedidos',
          'whatsapp',
          'tareas',
          'empleados',
          'facturacion',
          'nominas',
          'web',
        ];

      case RolApp.admin:
        // Dueño de empresa: ve todo excepto el módulo 'propietario' (exclusivo FluxTech)
        return [
          'dashboard',
          'reservas',
          'citas',
          'clientes',
          'valoraciones',
          'estadisticas',
          'servicios',
          'pedidos',
          'whatsapp',
          'tareas',
          'empleados',
          'facturacion',
          'nominas',
          'vacaciones',
          'web',
        ];

      case RolApp.staff:
        // Solo lo operativo básico: reservas, clientes y valoraciones
        return [
          'reservas',
          'citas',
          'clientes',
          'valoraciones',
        ];

      default:
        return ['reservas', 'citas'];
    }
  }

  /// Módulos visibles: personalizados si el admin los configuró, o los del rol.
  List<String> get modulosVisibles {
    if (modulosPersonalizados != null && modulosPersonalizados!.isNotEmpty) {
      return modulosPersonalizados!;
    }
    return _modulosPorRol;
  }

  /// Lista de TODOS los módulos posibles (para la pantalla de configuración)
  static const todosLosModulos = [
    'dashboard', 'reservas', 'citas', 'clientes', 'valoraciones',
    'estadisticas', 'servicios', 'pedidos', 'whatsapp', 'tareas',
    'empleados', 'facturacion', 'nominas', 'web',
  ];

  String get rolNombre {
    switch (rol) {
      case RolApp.propietario: return 'Propietario';
      case RolApp.admin:       return 'Administrador';
      case RolApp.staff:       return 'Staff';
      default:                 return 'Usuario';
    }
  }

  String get rolEmoji {
    switch (rol) {
      case RolApp.propietario: return '👑';
      case RolApp.admin:       return '🛡️';
      case RolApp.staff:       return '👤';
      default:                 return '❓';
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

  /// Carga los datos del usuario desde Firestore y los cachea
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

      // ── PROTECCIÓN 1: empresa propietaria de la plataforma ────────
      final esDocDePrueba = uid.startsWith('emp_fluix_');
      if (empresaId == ConstantesApp.empresaPropietariaId &&
          rolStr != 'propietario' &&
          !esDocDePrueba) {
        rolStr = 'propietario';
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .update({'rol': 'propietario'});
        debugPrint('👑 Rol corregido a propietario (empresa propietaria) para $uid');
      }

      // ── PROTECCIÓN 2: si no hay ningún propietario/admin en esta empresa,
      //    el usuario actual se promueve automáticamente. Esto evita
      //    que una empresa quede "huérfana" sin dueño.
      //    Nota: puede fallar con PERMISSION_DENIED para staff;
      //    en ese caso simplemente lo ignoramos. ─────────────────────
      if (rolStr != 'propietario' && rolStr != 'admin' && empresaId.isNotEmpty) {
        try {
          final propietariosSnap = await FirebaseFirestore.instance
              .collection('usuarios')
              .where('empresa_id', isEqualTo: empresaId)
              .where('rol', whereIn: ['propietario', 'admin'])
              .limit(1)
              .get();

          if (propietariosSnap.docs.isEmpty) {
            // Solo la empresa plataforma usa 'propietario'
            final nuevoRol = empresaId == ConstantesApp.empresaPropietariaId
                ? 'propietario'
                : 'admin';
            rolStr = nuevoRol;
            await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(uid)
                .update({'rol': nuevoRol});
            debugPrint('👑 Rol promovido a $nuevoRol (sin dueño en empresa) para $uid');
          }
        } catch (e) {
          debugPrint('ℹ️ Protección 2 omitida (sin permisos para consultar usuarios): $e');
        }
      }

      // ── PROTECCIÓN 3: si el correo del usuario coincide con el
      //    correo principal de la empresa, es el dueño real. ─────────
      if (rolStr != 'propietario' && rolStr != 'admin' && empresaId.isNotEmpty) {
        try {
          final correoUsuario = data['correo'] as String? ??
              FirebaseAuth.instance.currentUser?.email ?? '';
          if (correoUsuario.isNotEmpty) {
            final empresaDoc = await FirebaseFirestore.instance
                .collection('empresas')
                .doc(empresaId)
                .get();
            if (empresaDoc.exists) {
              final empresaData = empresaDoc.data()!;
              final correoEmpresa = empresaData['correo'] as String? ??
                  (empresaData['perfil'] as Map<String, dynamic>?)?['correo'] as String? ?? '';
              if (correoEmpresa.isNotEmpty &&
                  correoUsuario.toLowerCase() == correoEmpresa.toLowerCase()) {
                final nuevoRol = empresaId == ConstantesApp.empresaPropietariaId
                    ? 'propietario'
                    : 'admin';
                rolStr = nuevoRol;
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(uid)
                    .update({'rol': nuevoRol});
                debugPrint('👑 Rol promovido a $nuevoRol (correo coincide con empresa) para $uid');
              }
            }
          }
        } catch (_) {}
      }

      // Cargar módulos personalizados (si el admin los configuró)
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

      // Cargar suscripción para que el guard de módulos funcione
      if (empresaId.isNotEmpty) {
        await SuscripcionService().cargarSuscripcion(empresaId);
      }

      return _sesionActual;
    } catch (e) {
      return null;
    }
  }

  /// Limpia la sesión al cerrar sesión
  void limpiarSesion() {
    _sesionActual = null;
    SuscripcionService().limpiar();
  }

  // ── GUARD DE MÓDULOS ────────────────────────────────────────────────────────

  /// Resultado de verificar acceso a un módulo.
  /// - [permitido]: puede acceder libremente
  /// - [upgradeRequerido]: la suscripción está activa pero el módulo no está
  ///   en el plan → mostrar pantalla de upgrade
  /// - [sinAcceso]: el rol del usuario no permite acceder al módulo
  /// - [suscripcionInactiva]: la suscripción está vencida/suspendida
  ResultadoAccesoModulo puedeAccederModulo(String moduloId) {
    final sesion = _sesionActual;
    if (sesion == null) return ResultadoAccesoModulo.sinAcceso;

    // 1. El propietario de la plataforma (Samu) siempre tiene acceso total
    if (sesion.esPropietarioPlatforma) return ResultadoAccesoModulo.permitido;

    // 2. Verificar que el rol del usuario permite ver el módulo
    if (!sesion.modulosVisibles.contains(moduloId)) {
      return ResultadoAccesoModulo.sinAcceso;
    }

    // 3. Verificar suscripción activa
    final svc = SuscripcionService();
    if (!svc.estaActiva) {
      return ResultadoAccesoModulo.suscripcionInactiva;
    }

    // 4. Verificar que el módulo está incluido en el plan contratado
    if (!svc.tieneModulo(moduloId)) {
      return ResultadoAccesoModulo.upgradeRequerido;
    }

    return ResultadoAccesoModulo.permitido;
  }

  /// Versión simplificada: retorna true si se puede acceder, false si no.
  bool puedeAcceder(String moduloId) {
    return puedeAccederModulo(moduloId) == ResultadoAccesoModulo.permitido;
  }

  RolApp _parsearRol(String rol) {
    switch (rol.toLowerCase()) {
      case 'propietario': return RolApp.propietario;
      case 'admin':       return RolApp.admin;
      case 'staff':       return RolApp.staff;
      default:            return RolApp.desconocido;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENUM: Resultado de verificar acceso a un módulo
// ─────────────────────────────────────────────────────────────────────────────

enum ResultadoAccesoModulo {
  /// El usuario puede acceder al módulo sin restricciones
  permitido,

  /// La suscripción está activa pero el módulo no está en el plan contratado.
  /// Se debe mostrar la pantalla de upgrade.
  upgradeRequerido,

  /// El rol del usuario no permite acceder al módulo
  sinAcceso,

  /// La suscripción está vencida o suspendida
  suscripcionInactiva,
}



