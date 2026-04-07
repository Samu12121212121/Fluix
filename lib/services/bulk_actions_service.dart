import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio de operaciones masivas sobre clientes usando batch writes.
class BulkActionsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _clientes(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('clientes');

  // ── ASIGNAR ETIQUETA ──────────────────────────────────────────────────────

  /// Asigna una etiqueta a todos los clientes seleccionados.
  Future<int> asignarEtiqueta({
    required String empresaId,
    required List<String> clienteIds,
    required String etiqueta,
    void Function(int actual, int total)? onProgreso,
  }) async {
    return _ejecutarBatch(
      empresaId: empresaId,
      clienteIds: clienteIds,
      operacion: (batch, ref) {
        batch.update(ref, {
          'etiquetas': FieldValue.arrayUnion([etiqueta]),
        });
      },
      onProgreso: onProgreso,
    );
  }

  // ── ELIMINAR ETIQUETA ─────────────────────────────────────────────────────

  Future<int> eliminarEtiqueta({
    required String empresaId,
    required List<String> clienteIds,
    required String etiqueta,
    void Function(int actual, int total)? onProgreso,
  }) async {
    return _ejecutarBatch(
      empresaId: empresaId,
      clienteIds: clienteIds,
      operacion: (batch, ref) {
        batch.update(ref, {
          'etiquetas': FieldValue.arrayRemove([etiqueta]),
        });
      },
      onProgreso: onProgreso,
    );
  }

  // ── CAMBIAR ESTADO ────────────────────────────────────────────────────────

  /// Cambia el estado (contacto/activo/inactivo) de los clientes seleccionados.
  Future<int> cambiarEstado({
    required String empresaId,
    required List<String> clienteIds,
    required String nuevoEstado,
    void Function(int actual, int total)? onProgreso,
  }) async {
    return _ejecutarBatch(
      empresaId: empresaId,
      clienteIds: clienteIds,
      operacion: (batch, ref) {
        batch.update(ref, {'estado_cliente': nuevoEstado});
      },
      onProgreso: onProgreso,
    );
  }

  // ── MARCAR NO CONTACTAR ───────────────────────────────────────────────────

  Future<int> marcarNoContactar({
    required String empresaId,
    required List<String> clienteIds,
    required bool noContactar,
    void Function(int actual, int total)? onProgreso,
  }) async {
    return _ejecutarBatch(
      empresaId: empresaId,
      clienteIds: clienteIds,
      operacion: (batch, ref) {
        batch.update(ref, {'no_contactar': noContactar});
      },
      onProgreso: onProgreso,
    );
  }

  // ── ELIMINAR CLIENTES ─────────────────────────────────────────────────────

  /// Elimina clientes que NO tienen facturas asociadas.
  /// Devuelve cuántos se eliminaron y cuántos tenían facturas (omitidos).
  Future<({int eliminados, int omitidos})> eliminarClientes({
    required String empresaId,
    required List<String> clienteIds,
    void Function(int actual, int total)? onProgreso,
  }) async {
    int eliminados = 0;
    int omitidos = 0;
    int batchCount = 0;
    WriteBatch batch = _db.batch();

    for (int i = 0; i < clienteIds.length; i++) {
      final id = clienteIds[i];

      // Verificar si tiene facturas
      final clienteDoc = await _clientes(empresaId).doc(id).get();
      if (!clienteDoc.exists) continue;

      final nombre = clienteDoc.data()?['nombre'] ?? '';
      final factSnap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('facturas')
          .where('cliente_nombre', isEqualTo: nombre)
          .limit(1)
          .get();

      if (factSnap.docs.isNotEmpty) {
        omitidos++;
      } else {
        batch.delete(_clientes(empresaId).doc(id));
        eliminados++;
        batchCount++;
      }

      if (batchCount >= 450) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }

      onProgreso?.call(i + 1, clienteIds.length);
    }

    if (batchCount > 0) await batch.commit();
    return (eliminados: eliminados, omitidos: omitidos);
  }

  // ── EJECUTAR BATCH GENÉRICO ───────────────────────────────────────────────

  Future<int> _ejecutarBatch({
    required String empresaId,
    required List<String> clienteIds,
    required void Function(WriteBatch batch, DocumentReference ref) operacion,
    void Function(int actual, int total)? onProgreso,
  }) async {
    int procesados = 0;
    int batchCount = 0;
    WriteBatch batch = _db.batch();

    for (int i = 0; i < clienteIds.length; i++) {
      final ref = _clientes(empresaId).doc(clienteIds[i]);
      operacion(batch, ref);
      batchCount++;
      procesados++;

      if (batchCount >= 450) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }

      onProgreso?.call(i + 1, clienteIds.length);
    }

    if (batchCount > 0) await batch.commit();
    return procesados;
  }
}

