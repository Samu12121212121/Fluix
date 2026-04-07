import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/sugerencia_empresa.dart';
import '../domain/modelos/tarea.dart';
import 'tareas_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Sugerencias de mejora de empresa
//
// Flujo:
//   1. Empresa escribe una sugerencia en su perfil.
//   2. Se guarda en empresas/{empresaId}/sugerencias/{id}.
//   3. Se crea AUTOMÁTICAMENTE una Tarea (solo_propietario: true) con el
//      título "Revisar mejoras – {nombreEmpresa}" y el texto como descripción.
//   4. La tarea queda enlazada a la sugerencia (tarea_id) y viceversa
//      (sugerencia_id en la tarea).
//
// Edge cases contemplados:
//   - Borrar sugerencia → la tarea asociada pasa a estado "cancelada"
//     (no se elimina para conservar el historial).
//   - Nueva sugerencia siempre crea una nueva tarea (sin deduplicación).
//   - Si la creación de tarea falla, la sugerencia se guarda igualmente
//     y tarea_id queda null (se puede reintentar).
// ─────────────────────────────────────────────────────────────────────────────

class SugerenciasService {
  static final SugerenciasService _i = SugerenciasService._();
  factory SugerenciasService() => _i;
  SugerenciasService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TareasService _tareasSvc = TareasService();

  // ── COLECCIÓN ────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _col(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('sugerencias');

  // ── LEER ─────────────────────────────────────────────────────────────────

  /// Stream de todas las sugerencias de la empresa, ordenadas de más reciente
  /// a más antigua.
  Stream<List<SugerenciaEmpresa>> obtenerSugerencias(String empresaId) =>
      _col(empresaId)
          .orderBy('fecha_creacion', descending: true)
          .snapshots()
          .map((s) => s.docs.map(SugerenciaEmpresa.fromFirestore).toList());

  // ── CREAR ─────────────────────────────────────────────────────────────────

  /// Guarda una nueva sugerencia y crea automáticamente la tarea para el
  /// propietario de la plataforma.
  ///
  /// Parámetros:
  ///   [empresaId]    — ID del documento de la empresa en Firestore.
  ///   [texto]        — Texto libre escrito por la empresa.
  ///   [nombreEmpresa]— Nombre visible del negocio (para el título de la tarea).
  ///   [autorUid]     — UID del usuario que envía la sugerencia.
  Future<SugerenciaEmpresa> guardarSugerencia({
    required String empresaId,
    required String texto,
    required String nombreEmpresa,
    required String autorUid,
  }) async {
    // ── 1. Guardar la sugerencia ───────────────────────────────────────────
    final ref = _col(empresaId).doc();
    final sugerencia = SugerenciaEmpresa(
      id: ref.id,
      texto: texto,
      fechaCreacion: DateTime.now(),
      estado: EstadoSugerencia.pendiente,
      autorUid: autorUid,
    );
    await ref.set(sugerencia.toFirestore());

    // ── 2. Crear tarea automática ─────────────────────────────────────────
    try {
      final tarea = await _tareasSvc.crearTarea(
        empresaId: empresaId,
        titulo: 'Revisar mejoras – $nombreEmpresa',
        descripcion: texto,
        creadoPorId: autorUid,
        tipo: TipoTarea.normal,
        prioridad: PrioridadTarea.alta,
        etiquetas: ['💡 Sugerencia'],
        soloPropietario: true,
        sugerenciaId: ref.id,
      );

      // ── 3. Enlazar la tarea a la sugerencia ────────────────────────────
      await ref.update({'tarea_id': tarea.id});
      return sugerencia.copyWith(tareaId: tarea.id);
    } catch (e) {
      // Si la tarea no se puede crear, la sugerencia sigue guardada.
      // tarea_id quedará null y se puede reintentar desde el panel de admin.
      return sugerencia;
    }
  }

  // ── ELIMINAR ──────────────────────────────────────────────────────────────

  /// Elimina una sugerencia.
  ///
  /// Si tiene una tarea asociada, la pone en estado "cancelada" en lugar de
  /// eliminarla, para conservar el historial de revisión.
  Future<void> eliminarSugerencia(
    String empresaId,
    SugerenciaEmpresa sugerencia,
  ) async {
    // Cancelar la tarea vinculada (si existe y no está ya completada)
    if (sugerencia.tareaId != null) {
      try {
        await _db
            .collection('empresas')
            .doc(empresaId)
            .collection('tareas')
            .doc(sugerencia.tareaId)
            .update({
          'estado': EstadoTarea.cancelada.name,
          'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
        });
      } catch (_) {
        // Si la tarea ya no existe, continuar con la eliminación.
      }
    }

    // Eliminar el documento de sugerencia
    await _col(empresaId).doc(sugerencia.id).delete();
  }

  // ── ACTUALIZAR ESTADO ─────────────────────────────────────────────────────

  /// Cambia el estado de una sugerencia (lo hace el propietario de plataforma
  /// desde su panel de gestión de cuentas o desde la tarea).
  Future<void> actualizarEstado(
    String empresaId,
    String sugerenciaId,
    EstadoSugerencia nuevoEstado,
  ) async {
    await _col(empresaId).doc(sugerenciaId).update({
      'estado': nuevoEstado.name,
    });
  }
}

