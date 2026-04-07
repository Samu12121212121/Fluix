import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Resultado de la detección de duplicados.
class DuplicadoDetectado {
  final String clienteId;
  final Map<String, dynamic> data;
  final double confianza; // 0.0 a 1.0
  final List<String> motivos;

  const DuplicadoDetectado({
    required this.clienteId,
    required this.data,
    required this.confianza,
    required this.motivos,
  });
}

/// Servicio de detección y fusión de clientes duplicados.
class FusionClientesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _clientes(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('clientes');

  // ── DETECCIÓN DE DUPLICADOS ───────────────────────────────────────────────

  /// Busca posibles duplicados de un cliente.
  Future<List<DuplicadoDetectado>> buscarDuplicados({
    required String empresaId,
    required String clienteId,
    required Map<String, dynamic> clienteData,
  }) async {
    final snap = await _clientes(empresaId)
        .where('estado_fusionado', isEqualTo: false)
        .get();

    final duplicados = <DuplicadoDetectado>[];
    final nombre = (clienteData['nombre'] ?? '').toString().trim();
    final nif = (clienteData['nif'] ?? '').toString().trim();
    final correo = (clienteData['correo'] ?? '').toString().trim();
    final telefono = (clienteData['telefono'] ?? '').toString().trim();
    final localidad = (clienteData['localidad'] ?? '').toString().trim().toLowerCase();

    for (final doc in snap.docs) {
      if (doc.id == clienteId) continue;
      final d = doc.data();
      final motivos = <String>[];
      double puntuacion = 0;

      final otroNif = (d['nif'] ?? '').toString().trim();
      final otroCorreo = (d['correo'] ?? '').toString().trim();
      final otroTel = (d['telefono'] ?? '').toString().trim();
      final otroNombre = (d['nombre'] ?? '').toString().trim();
      final otraLocalidad = (d['localidad'] ?? '').toString().trim().toLowerCase();

      // 1. Mismo NIF (duplicado seguro)
      if (nif.isNotEmpty && otroNif.isNotEmpty &&
          nif.toUpperCase() == otroNif.toUpperCase()) {
        motivos.add('Mismo NIF/CIF: $nif');
        puntuacion += 0.95;
      }

      // 2. Mismo email
      if (correo.isNotEmpty && otroCorreo.isNotEmpty &&
          correo.toLowerCase() == otroCorreo.toLowerCase()) {
        motivos.add('Mismo email: $correo');
        puntuacion += 0.80;
      }

      // 3. Mismo teléfono
      if (telefono.isNotEmpty && otroTel.isNotEmpty) {
        final telLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
        final otroTelLimpio = otroTel.replaceAll(RegExp(r'[^0-9]'), '');
        if (telLimpio == otroTelLimpio && telLimpio.length >= 6) {
          motivos.add('Mismo teléfono: $telefono');
          puntuacion += 0.75;
        }
      }

      // 4. Nombre similar (Levenshtein < 3) + misma localidad
      if (nombre.isNotEmpty && otroNombre.isNotEmpty) {
        final distancia = _levenshtein(
          nombre.toLowerCase(),
          otroNombre.toLowerCase(),
        );
        if (distancia < 3 && distancia > 0) {
          if (localidad.isNotEmpty &&
              otraLocalidad.isNotEmpty &&
              localidad == otraLocalidad) {
            motivos.add(
                'Nombre muy similar ("$otroNombre") + misma localidad');
            puntuacion += 0.70;
          } else if (distancia <= 1) {
            motivos.add('Nombre casi idéntico: "$otroNombre"');
            puntuacion += 0.50;
          }
        }
      }

      if (motivos.isNotEmpty) {
        duplicados.add(DuplicadoDetectado(
          clienteId: doc.id,
          data: d,
          confianza: min(puntuacion, 1.0),
          motivos: motivos,
        ));
      }
    }

    duplicados.sort((a, b) => b.confianza.compareTo(a.confianza));
    return duplicados;
  }

  // ── FUSIONAR CLIENTES ─────────────────────────────────────────────────────

  /// Fusiona [duplicadoId] en [principalId].
  /// Transfiere facturas, reservas, pedidos, actividad y etiquetas.
  /// El duplicado queda marcado como fusionado (oculto).
  /// Se guarda un snapshot para rollback durante 30 días.
  Future<void> fusionar({
    required String empresaId,
    required String principalId,
    required String duplicadoId,
  }) async {
    final empresaRef = _db.collection('empresas').doc(empresaId);

    // Leer datos del duplicado para snapshot
    final dupDoc = await _clientes(empresaId).doc(duplicadoId).get();
    if (!dupDoc.exists) throw Exception('Cliente duplicado no encontrado');
    final dupData = dupDoc.data()!;

    final principalDoc = await _clientes(empresaId).doc(principalId).get();
    if (!principalDoc.exists) throw Exception('Cliente principal no encontrado');
    final principalData = principalDoc.data()!;

    // Guardar snapshot para rollback
    await _clientes(empresaId)
        .doc(duplicadoId)
        .collection('_fusion_snapshot')
        .doc('datos')
        .set({
      'datos_duplicado': dupData,
      'datos_principal_antes': principalData,
      'fecha_fusion': FieldValue.serverTimestamp(),
      'principal_id': principalId,
      'expira': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30))),
    });

    // Batch para transferencias
    WriteBatch batch = _db.batch();
    int batchCount = 0;

    // 1. Transferir facturas (actualizar cliente_nombre)
    final facturas = await empresaRef
        .collection('facturas')
        .where('cliente_nombre', isEqualTo: dupData['nombre'])
        .get();
    for (final doc in facturas.docs) {
      batch.update(doc.reference, {
        'cliente_nombre': principalData['nombre'],
        '_cliente_original': dupData['nombre'],
        '_fusion_desde': duplicadoId,
      });
      batchCount++;
      if (batchCount >= 450) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }
    }

    // 2. Transferir reservas
    final reservas = await empresaRef
        .collection('reservas')
        .where('cliente_id', isEqualTo: duplicadoId)
        .get();
    for (final doc in reservas.docs) {
      batch.update(doc.reference, {
        'cliente_id': principalId,
        '_cliente_original': duplicadoId,
      });
      batchCount++;
      if (batchCount >= 450) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }
    }

    // 3. Transferir pedidos
    final pedidos = await empresaRef
        .collection('pedidos')
        .where('cliente_nombre', isEqualTo: dupData['nombre'])
        .get();
    for (final doc in pedidos.docs) {
      batch.update(doc.reference, {
        'cliente_nombre': principalData['nombre'],
        '_cliente_original': dupData['nombre'],
        '_fusion_desde': duplicadoId,
      });
      batchCount++;
      if (batchCount >= 450) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }
    }

    // 4. Unir etiquetas
    final etiquetasPrincipal =
        List<String>.from(principalData['etiquetas'] ?? []);
    final etiquetasDup = List<String>.from(dupData['etiquetas'] ?? []);
    final etiquetasUnidas = {...etiquetasPrincipal, ...etiquetasDup}.toList();

    // 5. Actualizar totales del principal
    final totalPrincipal =
        ((principalData['total_gastado'] ?? 0) as num).toDouble();
    final totalDup = ((dupData['total_gastado'] ?? 0) as num).toDouble();
    final reservasPrincipal =
        (principalData['numero_reservas'] ?? 0) as int;
    final reservasDup = (dupData['numero_reservas'] ?? 0) as int;

    batch.update(_clientes(empresaId).doc(principalId), {
      'etiquetas': etiquetasUnidas,
      'total_gastado': totalPrincipal + totalDup,
      'numero_reservas': reservasPrincipal + reservasDup,
    });

    // 6. Marcar duplicado como fusionado
    batch.update(_clientes(empresaId).doc(duplicadoId), {
      'estado_fusionado': true,
      'fusionado_con_id': principalId,
      'fecha_fusion': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 7. Copiar actividad del duplicado al principal
    final actividadSnap = await _clientes(empresaId)
        .doc(duplicadoId)
        .collection('actividad')
        .get();
    if (actividadSnap.docs.isNotEmpty) {
      WriteBatch actBatch = _db.batch();
      int actCount = 0;
      for (final actDoc in actividadSnap.docs) {
        final newRef = _clientes(empresaId)
            .doc(principalId)
            .collection('actividad')
            .doc();
        actBatch.set(newRef, {
          ...actDoc.data(),
          'cliente_id': principalId,
          '_copiado_de': duplicadoId,
        });
        actCount++;
        if (actCount >= 450) {
          await actBatch.commit();
          actBatch = _db.batch();
          actCount = 0;
        }
      }
      if (actCount > 0) await actBatch.commit();
    }
  }

  // ── ROLLBACK (DESHACER FUSIÓN) ────────────────────────────────────────────

  /// Deshace la fusión de un cliente duplicado.
  /// Solo funciona si el snapshot no ha expirado (30 días).
  Future<bool> deshacerFusion({
    required String empresaId,
    required String duplicadoId,
  }) async {
    final snapDoc = await _clientes(empresaId)
        .doc(duplicadoId)
        .collection('_fusion_snapshot')
        .doc('datos')
        .get();

    if (!snapDoc.exists) return false;

    final snapData = snapDoc.data()!;
    final expira = (snapData['expira'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expira)) return false;

    final principalId = snapData['principal_id'] as String; // ignore: unused_local_variable
    final datosDuplicado =
        snapData['datos_duplicado'] as Map<String, dynamic>;

    // Restaurar datos del duplicado
    await _clientes(empresaId).doc(duplicadoId).set(datosDuplicado);

    // Revertir facturas transferidas
    final empresaRef = _db.collection('empresas').doc(empresaId);
    final facturas = await empresaRef
        .collection('facturas')
        .where('_fusion_desde', isEqualTo: duplicadoId)
        .get();
    WriteBatch batch = _db.batch();
    int count = 0;
    for (final doc in facturas.docs) {
      final original = doc.data()['_cliente_original'];
      if (original != null) {
        batch.update(doc.reference, {
          'cliente_nombre': original,
          '_fusion_desde': FieldValue.delete(),
          '_cliente_original': FieldValue.delete(),
        });
        count++;
        if (count >= 450) {
          await batch.commit();
          batch = _db.batch();
          count = 0;
        }
      }
    }

    // Revertir reservas
    final reservas = await empresaRef
        .collection('reservas')
        .where('_cliente_original', isEqualTo: duplicadoId)
        .get();
    for (final doc in reservas.docs) {
      batch.update(doc.reference, {
        'cliente_id': duplicadoId,
        '_cliente_original': FieldValue.delete(),
      });
      count++;
      if (count >= 450) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }

    // Revertir pedidos
    final pedidos = await empresaRef
        .collection('pedidos')
        .where('_fusion_desde', isEqualTo: duplicadoId)
        .get();
    for (final doc in pedidos.docs) {
      final original = doc.data()['_cliente_original'];
      if (original != null) {
        batch.update(doc.reference, {
          'cliente_nombre': original,
          '_fusion_desde': FieldValue.delete(),
          '_cliente_original': FieldValue.delete(),
        });
        count++;
        if (count >= 450) {
          await batch.commit();
          batch = _db.batch();
          count = 0;
        }
      }
    }

    if (count > 0) await batch.commit();

    // Eliminar snapshot
    await snapDoc.reference.delete();

    return true;
  }

  // ── LEVENSHTEIN ───────────────────────────────────────────────────────────

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) matrix[i][0] = i;
    for (int j = 0; j <= b.length; j++) matrix[0][j] = j;

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    return matrix[a.length][b.length];
  }
}


