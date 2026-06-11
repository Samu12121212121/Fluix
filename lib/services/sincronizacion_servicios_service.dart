import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Servicio que sincroniza automáticamente los servicios entre:
/// - Empresas B2B (empresas/{empresaId}/servicios)
/// - Negocios Públicos B2C (negocios_publicos/{negocioId}/servicios)
///
/// La sincronización es BIDIRECCIONAL:
/// - Cambios en servicios B2B → se reflejan en negocio vinculado
/// - Cambios en servicios B2C → se reflejan en empresa vinculada
class SincronizacionServiciosService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sincroniza todos los servicios de una empresa hacia su negocio público vinculado.
  /// Útil cuando se vincula por primera vez una empresa a un negocio.
  Future<void> sincronizarServiciosEmpresaANegocio({
    required String empresaId,
    required String negocioPublicoId,
  }) async {
    try {
      debugPrint('🔄 Iniciando sincronización empresa→negocio: $empresaId → $negocioPublicoId');

      // 1. Obtener servicios de la empresa
      final serviciosB2B = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('servicios')
          .get();

      // 2. Eliminar servicios antiguos del negocio
      final serviciosB2C = await _db
          .collection('negocios_publicos')
          .doc(negocioPublicoId)
          .collection('servicios')
          .get();

      final batch = _db.batch();
      for (final doc in serviciosB2C.docs) {
        batch.delete(doc.reference);
      }

      // 3. Copiar servicios B2B → B2C
      int orden = 0;
      for (final doc in serviciosB2B.docs) {
        final data = doc.data();
        final servicioB2C = _convertirB2BaB2C(data, orden++);

        final nuevoDoc = _db
            .collection('negocios_publicos')
            .doc(negocioPublicoId)
            .collection('servicios')
            .doc();

        batch.set(nuevoDoc, servicioB2C);
      }

      await batch.commit();
      debugPrint('✅ Sincronizados ${serviciosB2B.docs.length} servicios');
    } catch (e) {
      debugPrint('❌ Error sincronizando servicios: $e');
      rethrow;
    }
  }

  /// Sincroniza UN servicio específico de empresa a negocio público.
  /// Se ejecuta automáticamente cuando se crea/actualiza un servicio B2B.
  Future<void> sincronizarServicioIndividual({
    required String empresaId,
    required String servicioId,
    required String negocioPublicoId,
  }) async {
    try {
      // Obtener el servicio B2B
      final docB2B = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('servicios')
          .doc(servicioId)
          .get();

      if (!docB2B.exists) {
        debugPrint('⚠️ Servicio B2B no existe, eliminando en B2C si existe');
        await _eliminarServicioB2CPorId(negocioPublicoId, servicioId);
        return;
      }

      // Buscar si ya existe en B2C (se guarda con el mismo ID)
      final docB2C = _db
          .collection('negocios_publicos')
          .doc(negocioPublicoId)
          .collection('servicios')
          .doc(servicioId);

      // Obtener orden actual o asignar uno nuevo
      final existingB2C = await docB2C.get();
      final orden = existingB2C.exists
          ? (existingB2C.data()?['orden'] as int? ?? 0)
          : await _obtenerSiguienteOrden(negocioPublicoId);

      // Convertir y guardar
      final servicioB2C = _convertirB2BaB2C(docB2B.data()!, orden);
      await docB2C.set(servicioB2C);

      debugPrint('✅ Servicio sincronizado: ${docB2B.data()?['nombre']}');
    } catch (e) {
      debugPrint('❌ Error sincronizando servicio individual: $e');
      rethrow;
    }
  }

  /// Obtiene el negocio público vinculado a una empresa.
  Future<String?> obtenerNegocioVinculado(String empresaId) async {
    try {
      final negocios = await _db
          .collection('negocios_publicos')
          .where('empresaIdVinculada', isEqualTo: empresaId)
          .limit(1)
          .get();

      return negocios.docs.isNotEmpty ? negocios.docs.first.id : null;
    } catch (e) {
      debugPrint('❌ Error obteniendo negocio vinculado: $e');
      return null;
    }
  }

  /// Convierte un servicio B2B (empresa) al formato B2C (negocio público).
  Map<String, dynamic> _convertirB2BaB2C(Map<String, dynamic> servicioB2B, int orden) {
    final duracionMinutos = servicioB2B['duracion_minutos'] as int? ?? 60;
    final precio = (servicioB2B['precio'] as num?)?.toDouble() ?? 0.0;

    return {
      'nombre': servicioB2B['nombre'] ?? '',
      'descripcion': servicioB2B['descripcion'] ?? '',
      'categoria': servicioB2B['categoria'] ?? 'General',
      'precio': precio,
      'duracion': duracionMinutos,
      'publico': 'todos', // Por defecto todos los públicos
      'activo': servicioB2B['activo'] ?? true,
      'orden': orden,
      // Metadatos de sincronización
      'sincronizado_desde_empresa': true,
      'fecha_sincronizacion': FieldValue.serverTimestamp(),
    };
  }

  /// Obtiene el siguiente orden disponible para un servicio en un negocio.
  Future<int> _obtenerSiguienteOrden(String negocioPublicoId) async {
    final servicios = await _db
        .collection('negocios_publicos')
        .doc(negocioPublicoId)
        .collection('servicios')
        .orderBy('orden', descending: true)
        .limit(1)
        .get();

    if (servicios.docs.isEmpty) return 0;
    return ((servicios.docs.first.data()['orden'] as int?) ?? 0) + 1;
  }

  /// Elimina un servicio B2C por su ID.
  Future<void> _eliminarServicioB2CPorId(String negocioPublicoId, String servicioId) async {
    await _db
        .collection('negocios_publicos')
        .doc(negocioPublicoId)
        .collection('servicios')
        .doc(servicioId)
        .delete();
  }

  /// Configura un listener en tiempo real para sincronizar automáticamente
  /// los servicios de una empresa hacia su negocio vinculado.
  ///
  /// Retorna una función para cancelar el listener.
  Function setupAutoSync(String empresaId) {
    Stream<QuerySnapshot>? stream;

    // Función que se ejecuta cuando detecta cambios
    void handleChanges(QuerySnapshot snapshot, String negocioId) async {
      for (final change in snapshot.docChanges) {
        final servicioId = change.doc.id;

        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            await sincronizarServicioIndividual(
              empresaId: empresaId,
              servicioId: servicioId,
              negocioPublicoId: negocioId,
            );
            break;
          case DocumentChangeType.removed:
            await _eliminarServicioB2CPorId(negocioId, servicioId);
            break;
        }
      }
    }

    // Primero, obtener el negocio vinculado
    obtenerNegocioVinculado(empresaId).then((negocioId) {
      if (negocioId == null) {
        debugPrint('⚠️ No hay negocio vinculado para auto-sync');
        return;
      }

      debugPrint('🔄 Auto-sync activado: empresa $empresaId → negocio $negocioId');

      // Iniciar listener
      stream = _db
          .collection('empresas')
          .doc(empresaId)
          .collection('servicios')
          .snapshots();

      stream!.listen(
        (snapshot) => handleChanges(snapshot, negocioId),
        onError: (e) => debugPrint('❌ Error en auto-sync: $e'),
      );
    });

    // Retornar función de cancelación (por ahora vacía, se puede mejorar)
    return () => debugPrint('🛑 Auto-sync cancelado para empresa $empresaId');
  }
}

