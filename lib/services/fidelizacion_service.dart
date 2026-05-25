import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/programa_fidelizacion_model.dart';
import '../models/tarjeta_sellos_model.dart';
import '../models/qr_canje_model.dart';

class FidelizacionService {
  static final _db = FirebaseFirestore.instance;
  static final _uuid = const Uuid();

  // PROGRAMAS
  static Stream<ProgramaFidelizacionModel?> escucharPrograma(String negocioId) =>
      _db.collection('negocios_publicos').doc(negocioId).collection('programa_fidelizacion')
          .limit(1).snapshots().map((s) => s.docs.isEmpty ? null : ProgramaFidelizacionModel.fromFirestore(s.docs.first));

  static Future<ProgramaFidelizacionModel?> obtenerPrograma(String negocioId) async {
    final snap = await _db.collection('negocios_publicos').doc(negocioId).collection('programa_fidelizacion').limit(1).get();
    return snap.docs.isEmpty ? null : ProgramaFidelizacionModel.fromFirestore(snap.docs.first);
  }

  static Future<void> guardarPrograma({required String negocioId, required String nombre, required String descripcion,
      required int sellosParaRecompensa, required List<RecompensaPrograma> recompensas, required bool activo, int? caducidadMeses, String? programaId}) async {
    final data = {
      'negocio_id': negocioId, 'nombre': nombre, 'descripcion': descripcion, 'sellos_para_recompensa': sellosParaRecompensa,
      'recompensas': recompensas.map((r) => r.toMap()).toList(), 'activo': activo,
      if (caducidadMeses != null) 'caducidad_meses': caducidadMeses, 'actualizado_at': FieldValue.serverTimestamp(),
    };
    if (programaId != null) {
      await _db.collection('negocios_publicos').doc(negocioId).collection('programa_fidelizacion').doc(programaId).update(data);
    } else {
      data['creado_at'] = FieldValue.serverTimestamp();
      await _db.collection('negocios_publicos').doc(negocioId).collection('programa_fidelizacion').add(data);
    }
  }

  // TARJETAS
  static Stream<TarjetaSelloModel?> escucharTarjeta(String uid, String negocioId) =>
      _db.collection('usuarios').doc(uid).collection('tarjetas_sellos').doc(negocioId).snapshots()
          .map((s) => s.exists ? TarjetaSelloModel.fromFirestore(s) : null);

  static Stream<List<TarjetaSelloModel>> escucharTodasLasTarjetas(String uid) =>
      _db.collection('usuarios').doc(uid).collection('tarjetas_sellos').orderBy('ultimo_checkin', descending: true)
          .snapshots().map((s) => s.docs.map((d) => TarjetaSelloModel.fromFirestore(d)).toList());

  // CHECK-IN
  static Future<({bool exito, String mensaje, bool recompensaDesbloqueada, RecompensaPrograma? recompensa})>
      hacerCheckin({required String negocioId, required String programaId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return (exito: false, mensaje: 'No autenticado', recompensaDesbloqueada: false, recompensa: null);

    try {
      final programa = await obtenerPrograma(negocioId);
      if (programa == null || !programa.activo) return (exito: false, mensaje: 'Programa no disponible', recompensaDesbloqueada: false, recompensa: null);

      final negocioSnap = await _db.collection('negocios_publicos').doc(negocioId).get();
      final negocioData = negocioSnap.data() ?? {};
      final negocioNombre = negocioData['nombre'] as String? ?? 'Negocio';
      final negocioFoto = negocioData['foto_url'] as String?;

      final userDoc = await _db.collection('usuarios').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final clienteNombre = userData['nombre'] as String? ?? user.displayName ?? 'Cliente';
      final clienteFoto = userData['foto_url'] as String? ?? user.photoURL;

      final tarjetaRef = _db.collection('usuarios').doc(user.uid).collection('tarjetas_sellos').doc(negocioId);

      return await _db.runTransaction((tx) async {
        final tarjetaSnap = await tx.get(tarjetaRef);
        TarjetaSelloModel? tarjeta;
        if (tarjetaSnap.exists) {
          tarjeta = TarjetaSelloModel.fromFirestore(tarjetaSnap);
          if (!tarjeta.puedeHacerCheckin) {
            final min = tarjeta.tiempoHastaProximoCheckin!.inMinutes;
            return (exito: false, mensaje: 'Espera $min minutos', recompensaDesbloqueada: false, recompensa: null);
          }
        }

        final sellosAntes = tarjeta?.sellosActuales ?? 0;
        final sellosDespues = sellosAntes + 1;
        final sellosCiclo = sellosDespues % programa.sellosParaRecompensa;
        final sellosActualesNuevos = sellosCiclo == 0 ? programa.sellosParaRecompensa : sellosCiclo;

        bool desbloqueada = false;
        RecompensaPrograma? recompensaObj;
        var recompensas = tarjeta?.recompensasDesbloqueadas ?? <RecompensaDesbloqueada>[];

        if (sellosDespues > 0 && sellosDespues % programa.sellosParaRecompensa == 0) {
          desbloqueada = true;
          recompensaObj = programa.obtenerRecompensaPorSellos(programa.sellosParaRecompensa);
          if (recompensaObj != null) {
            recompensas = [...recompensas, RecompensaDesbloqueada(
              recompensaId: recompensaObj.id, titulo: recompensaObj.titulo,
              estado: 'disponible', desbloqueadaAt: DateTime.now())];
          }
        }

        tx.set(tarjetaRef, {
          'negocio_id': negocioId, 'negocio_nombre': negocioNombre,
          if (negocioFoto != null) 'negocio_foto': negocioFoto,
          'programa_id': programaId, 'sellos_actuales': sellosActualesNuevos,
          'sellos_totales_historico': (tarjeta?.sellosTotalesHistorico ?? 0) + 1,
          'recompensas_desbloqueadas': recompensas.map((r) => r.toMap()).toList(),
          'ultimo_checkin': FieldValue.serverTimestamp(),
          'actualizado_at': FieldValue.serverTimestamp(),
          if (tarjeta == null) 'creado_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(_db.collection('negocios_publicos').doc(negocioId).collection('checkins').doc(), {
          'negocio_id': negocioId, 'cliente_id': user.uid, 'cliente_nombre': clienteNombre,
          if (clienteFoto != null) 'cliente_foto': clienteFoto,
          'sellos_antes': sellosAntes, 'sellos_despues': sellosDespues,
          'recompensa_desbloqueada': desbloqueada,
          if (recompensaObj != null) 'recompensa_id': recompensaObj.id,
          if (recompensaObj != null) 'recompensa_titulo': recompensaObj.titulo,
          'creado_at': FieldValue.serverTimestamp(),
        });

        final restantes = programa.sellosParaRecompensa - sellosActualesNuevos;
        final msg = desbloqueada ? '¡Recompensa desbloqueada! 🎉' : '¡+1 sello! Te faltan $restantes';
        return (exito: true, mensaje: msg, recompensaDesbloqueada: desbloqueada, recompensa: recompensaObj);
      });
    } catch (e) {
      return (exito: false, mensaje: 'Error: $e', recompensaDesbloqueada: false, recompensa: null);
    }
  }

  // QR CANJE
  static Future<String?> generarQrCanje({required String negocioId, required RecompensaPrograma recompensa}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final userDoc = await _db.collection('usuarios').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final clienteNombre = userData['nombre'] as String? ?? user.displayName ?? 'Cliente';
    final clienteFoto = userData['foto_url'] as String? ?? user.photoURL;
    final qrId = _uuid.v4();
    final ahora = DateTime.now();
    await _db.collection('negocios_publicos').doc(negocioId).collection('qr_canjes').doc(qrId).set({
      'negocio_id': negocioId, 'cliente_id': user.uid, 'cliente_nombre': clienteNombre,
      if (clienteFoto != null) 'cliente_foto': clienteFoto,
      'recompensa_id': recompensa.id, 'recompensa_titulo': recompensa.titulo,
      'recompensa_descripcion': recompensa.descripcion, 'recompensa_tipo': recompensa.tipo,
      'recompensa_valor': recompensa.valor, 'estado': 'pendiente',
      'generado_at': Timestamp.fromDate(ahora),
      'expira_at': Timestamp.fromDate(ahora.add(const Duration(minutes: 10))),
    });
    return qrId;
  }

  static Stream<QrCanjeModel?> escucharQrCanje(String negocioId, String qrId) =>
      _db.collection('negocios_publicos').doc(negocioId).collection('qr_canjes').doc(qrId)
          .snapshots().map((s) => s.exists ? QrCanjeModel.fromFirestore(s) : null);

  static Future<({bool exito, String mensaje})> confirmarCanje({required String negocioId, required String qrId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return (exito: false, mensaje: 'No autenticado');
    try {
      return await _db.runTransaction((tx) async {
        final qrRef = _db.collection('negocios_publicos').doc(negocioId).collection('qr_canjes').doc(qrId);
        final qrSnap = await tx.get(qrRef);
        if (!qrSnap.exists) return (exito: false, mensaje: 'QR no encontrado');
        final qrCanje = QrCanjeModel.fromFirestore(qrSnap);
        if (qrCanje.estaExpirado) return (exito: false, mensaje: 'QR expirado');
        if (qrCanje.estaCanjeado) return (exito: false, mensaje: 'Ya canjeado');
        tx.update(qrRef, {'estado': 'canjeado', 'canjeado_at': FieldValue.serverTimestamp(), 'canjeado_por_uid': user.uid});
        final tarjetaRef = _db.collection('usuarios').doc(qrCanje.clienteId).collection('tarjetas_sellos').doc(negocioId);
        final tarjetaSnap = await tx.get(tarjetaRef);
        if (tarjetaSnap.exists) {
          final tarjeta = TarjetaSelloModel.fromFirestore(tarjetaSnap);
          final recompensasActualizadas = tarjeta.recompensasDesbloqueadas.map((r) {
            if (r.recompensaId == qrCanje.recompensaId && r.estaDisponible) {
              return r.copyWith(estado: 'canjeada', canjeadaAt: DateTime.now(), qrCanjeId: qrId);
            }
            return r;
          }).toList();
          tx.update(tarjetaRef, {
            'recompensas_desbloqueadas': recompensasActualizadas.map((r) => r.toMap()).toList(),
            'actualizado_at': FieldValue.serverTimestamp()});
        }
        return (exito: true, mensaje: '¡Canje confirmado!');
      });
    } catch (e) {
      return (exito: false, mensaje: 'Error: $e');
    }
  }

  // ESTADÍSTICAS
  static Future<Map<String, dynamic>> obtenerEstadisticas(String negocioId) async {
    final inicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final tarjetas = await _db.collectionGroup('tarjetas_sellos').where('negocio_id', isEqualTo: negocioId).get();
    final checkins = await _db.collection('negocios_publicos').doc(negocioId).collection('checkins')
        .where('creado_at', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio)).get();
    final clientesMap = <String, int>{};
    for (final d in checkins.docs) {
      final cid = d.data()['cliente_id'] as String?;
      if (cid != null) clientesMap[cid] = (clientesMap[cid] ?? 0) + 1;
    }
    return {
      'total_clientes': tarjetas.docs.length,
      'checkins_este_mes': checkins.docs.length,
      'clientes_recurrentes': clientesMap.values.where((v) => v >= 2).length,
    };
  }

  static Stream<List<CheckinModel>> escucharCheckinsRecientes(String negocioId, {int limite = 50}) =>
      _db.collection('negocios_publicos').doc(negocioId).collection('checkins')
          .orderBy('creado_at', descending: true).limit(limite).snapshots()
          .map((s) => s.docs.map((d) => CheckinModel.fromFirestore(d)).toList());
}

