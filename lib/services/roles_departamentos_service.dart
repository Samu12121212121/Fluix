import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/rol_empresa.dart';
import '../domain/modelos/departamento_empresa.dart';

/// Servicio CRUD para roles personalizados y departamentos.
/// Colecciones:
///   empresas/{id}/roles_empresa/{roleId}
///   empresas/{id}/departamentos/{deptId}
class RolesDepartamentosService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _rolesCol(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('roles_empresa');

  CollectionReference<Map<String, dynamic>> _deptsCol(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('departamentos');

  // ═══════════════════════════════════════════════
  // ROLES
  // ═══════════════════════════════════════════════

  Stream<List<RolEmpresa>> rolesStream(String empresaId) =>
      _rolesCol(empresaId)
          .where('activo', isEqualTo: true)
          .orderBy('nivel')
          .snapshots()
          .map((s) => s.docs.map(RolEmpresa.fromFirestore).toList());

  Future<List<RolEmpresa>> getRoles(String empresaId) async {
    final snap = await _rolesCol(empresaId)
        .where('activo', isEqualTo: true)
        .orderBy('nivel')
        .get();
    return snap.docs.map(RolEmpresa.fromFirestore).toList();
  }

  Future<RolEmpresa> crearRol(String empresaId, RolEmpresa rol) async {
    final ref = await _rolesCol(empresaId).add(rol.toFirestore());
    final doc = await ref.get();
    return RolEmpresa.fromFirestore(doc);
  }

  Future<void> actualizarRol(String empresaId, RolEmpresa rol) async {
    final data = rol.toFirestore()..remove('creado_at');
    await _rolesCol(empresaId).doc(rol.id).update(data);
  }

  Future<void> eliminarRol(String empresaId, String rolId) async {
    await _rolesCol(empresaId).doc(rolId).update({'activo': false});
  }

  // ═══════════════════════════════════════════════
  // DEPARTAMENTOS
  // ═══════════════════════════════════════════════

  Stream<List<DepartamentoEmpresa>> departamentosStream(String empresaId) =>
      _deptsCol(empresaId)
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .snapshots()
          .map((s) => s.docs.map(DepartamentoEmpresa.fromFirestore).toList());

  Future<List<DepartamentoEmpresa>> getDepartamentos(String empresaId) async {
    final snap = await _deptsCol(empresaId)
        .where('activo', isEqualTo: true)
        .orderBy('nombre')
        .get();
    return snap.docs.map(DepartamentoEmpresa.fromFirestore).toList();
  }

  Future<DepartamentoEmpresa> crearDepartamento(
      String empresaId, DepartamentoEmpresa dept) async {
    final ref = await _deptsCol(empresaId).add(dept.toFirestore());
    final doc = await ref.get();
    return DepartamentoEmpresa.fromFirestore(doc);
  }

  Future<void> actualizarDepartamento(
      String empresaId, DepartamentoEmpresa dept) async {
    final data = dept.toFirestore()..remove('creado_at');
    await _deptsCol(empresaId).doc(dept.id).update(data);
  }

  Future<void> eliminarDepartamento(
      String empresaId, String deptId) async {
    await _deptsCol(empresaId).doc(deptId).update({'activo': false});
  }

  // ═══════════════════════════════════════════════
  // ASIGNACIÓN A EMPLEADO
  // ═══════════════════════════════════════════════

  /// Asigna rol y departamento a un empleado y actualiza nivel_jerarquico.
  /// La Cloud Function `actualizarClaimsEmpleado` detecta el cambio
  /// y actualiza los Custom Claims automáticamente.
  Future<void> asignarRolEmpleado({
    required String uid,
    required String empresaId,
    String? rolEmpresaId,
    int? nivelJerarquico,
    String? departamentoId,
    String? departamentoNombre,
    String? managerUid,
  }) async {
    await _db.collection('usuarios').doc(uid).update({
      if (rolEmpresaId != null)       'rol_empresa_id':    rolEmpresaId,
      if (nivelJerarquico != null)    'nivel_jerarquico':  nivelJerarquico,
      if (departamentoId != null)     'departamento_id':   departamentoId,
      if (departamentoNombre != null) 'departamento':      departamentoNombre,
      if (managerUid != null)         'manager_uid':       managerUid,
      'empresa_id': empresaId,
    });
  }
}
