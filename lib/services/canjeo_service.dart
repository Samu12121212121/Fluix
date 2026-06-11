import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/tienda_monedas/modelos/item_canje.dart';

class CanjeoService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _canjesRef(String uid) =>
      _db.collection('usuarios').doc(uid).collection('canjes');

  // ── Canjear item normal ─────────────────────────────────────────
  static Future<void> canjear(
    String uid,
    ItemCanje item, {
    String? datoExtra,
    bool sinCoste = false, // usado por Caja Misteriosa al dar el premio
  }) async {
    final userRef = _db.collection('usuarios').doc(uid);
    final userSnap = await userRef.get();
    final saldo = (userSnap.data()?['monedas'] as int?) ?? 0;

    if (!sinCoste && saldo < item.costo) throw Exception('Saldo insuficiente');

    // Permanentes/duración: bloquear si ya lo tiene (excepto items siempreComprables)
    if (!item.esSiempreComprable && item.tipo != TipoCanje.usoUnico) {
      final activo = await tieneItemActivo(uid, item.id);
      if (activo) throw Exception('Ya tienes este item activo');
    }

    final ahora = DateTime.now();
    final expiraAt = item.duracionDias != null
        ? ahora.add(Duration(days: item.duracionDias!))
        : null;
    final usosIniciales = item.usos ?? (item.tipo == TipoCanje.usoUnico ? 1 : null);

    final batch = _db.batch();

    final canjeRef = _canjesRef(uid).doc();
    batch.set(canjeRef, {
      'item_id':     item.id,
      'nombre':      item.nombre,
      'costo':       sinCoste ? 0 : item.costo,
      'tipo':        item.tipo.name,
      'canjeado_at': FieldValue.serverTimestamp(),
      if (expiraAt != null) 'expira_at': Timestamp.fromDate(expiraAt),
      'activo':      true,
      if (usosIniciales != null) 'usos_restantes': usosIniciales,
      if (datoExtra != null) 'dato_extra': datoExtra,
    });

    if (!sinCoste) {
      batch.update(userRef, {'monedas': FieldValue.increment(-item.costo)});
    }

    // Escribir campo en doc usuario para acceso rápido
    final campos = _camposUsuarioPorItem(item.id, expiraAt, datoExtra, usosIniciales);
    if (campos.isNotEmpty) batch.update(userRef, campos);

    await batch.commit();
  }

  // ── Caja Misteriosa ─────────────────────────────────────────────
  static Future<ItemCanje> canjearCajaMisteriosa(String uid) async {
    final userRef = _db.collection('usuarios').doc(uid);
    final userSnap = await userRef.get();
    final saldo = (userSnap.data()?['monedas'] as int?) ?? 0;

    const coste = 100;
    if (saldo < coste) throw Exception('Saldo insuficiente');

    // Elegir item aleatorio ponderado por rareza (más baratos = más probables)
    final candidatos = kItemsCajaMisteriosa;
    // Peso inverso al coste: un item de 200 tiene 4× más prob que uno de 800
    final totalPeso = candidatos.fold<double>(0, (s, i) => s + (1000 / i.costo));
    double rand = Random().nextDouble() * totalPeso;
    ItemCanje premio = candidatos.last;
    for (final item in candidatos) {
      rand -= 1000 / item.costo;
      if (rand <= 0) { premio = item; break; }
    }

    // Descontar coste de caja + otorgar premio (sin coste adicional)
    final batch = _db.batch();
    batch.update(userRef, {'monedas': FieldValue.increment(-coste)});

    final canjeRef = _canjesRef(uid).doc();
    final expiraAt = premio.duracionDias != null
        ? DateTime.now().add(Duration(days: premio.duracionDias!))
        : null;
    final usosIniciales = premio.usos ?? (premio.tipo == TipoCanje.usoUnico ? 1 : null);

    batch.set(canjeRef, {
      'item_id':     premio.id,
      'nombre':      premio.nombre,
      'costo':       0,
      'tipo':        premio.tipo.name,
      'canjeado_at': FieldValue.serverTimestamp(),
      if (expiraAt != null) 'expira_at': Timestamp.fromDate(expiraAt),
      'activo':      true,
      if (usosIniciales != null) 'usos_restantes': usosIniciales,
      'de_caja':     true,
    });

    final campos = _camposUsuarioPorItem(premio.id, expiraAt, null, usosIniciales);
    if (campos.isNotEmpty) batch.update(userRef, campos);

    // Registro de la caja en historial
    final cajaRef = _canjesRef(uid).doc();
    batch.set(cajaRef, {
      'item_id':     'caja_misteriosa',
      'nombre':      'Caja Misteriosa',
      'costo':       coste,
      'tipo':        TipoCanje.usoUnico.name,
      'canjeado_at': FieldValue.serverTimestamp(),
      'activo':      false,
      'premio_obtenido': premio.id,
    });

    await batch.commit();
    return premio;
  }

  // ── Consumir un uso (modo_anonimo, etc.) ────────────────────────
  static Future<bool> consumirUso(String uid, String itemId) async {
    final snap = await _canjesRef(uid)
        .where('item_id', isEqualTo: itemId)
        .where('activo', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return false;

    final doc = snap.docs.first;
    final usos = (doc.data()['usos_restantes'] as int?) ?? 0;
    if (usos <= 1) {
      await doc.reference.update({'activo': false, 'usos_restantes': 0});
      // Limpiar campo en usuario
      final campo = _campoCleanupPorItem(itemId);
      if (campo != null) {
        await _db.collection('usuarios').doc(uid).update({campo: FieldValue.delete()});
      }
    } else {
      await doc.reference.update({'usos_restantes': FieldValue.increment(-1)});
      // Actualizar campo contador en usuario
      if (itemId == 'modo_anonimo') {
        await _db.collection('usuarios').doc(uid)
            .update({'canje_anonimo_usos': FieldValue.increment(-1)});
      }
    }
    return true;
  }

  // ── Tiene item activo ───────────────────────────────────────────
  static Future<bool> tieneItemActivo(String uid, String itemId) async {
    final snap = await _canjesRef(uid)
        .where('item_id', isEqualTo: itemId)
        .where('activo', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return false;

    final doc = snap.docs.first.data();
    final expira = doc['expira_at'] as Timestamp?;
    if (expira != null && expira.toDate().isBefore(DateTime.now())) {
      await snap.docs.first.reference.update({'activo': false});
      return false;
    }
    return true;
  }

  // ── Stream de canjes activos ────────────────────────────────────
  static Stream<List<CanjeActivo>> streamCanjesActivos(String uid) {
    return _canjesRef(uid)
        .where('activo', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final ahora = DateTime.now();
          return snap.docs
              .map((d) => CanjeActivo.fromMap(d.data(), d.id))
              .where((c) => c.expiraAt == null || c.expiraAt!.isAfter(ahora))
              .toList();
        });
  }

  // ── Campos en doc usuario por item ─────────────────────────────
  static Map<String, dynamic> _camposUsuarioPorItem(
    String itemId,
    DateTime? expiraAt,
    String? datoExtra,
    int? usos,
  ) {
    return switch (itemId) {
      'marco_bronce'       => {'canje_marco': 'bronce'},
      'marco_oro'          => {'canje_marco': 'oro'},
      'marco_platino'      => {'canje_marco': 'platino'},
      'titulo_custom'      => {'canje_titulo': datoExtra ?? ''},
      'color_nombre'       => {'canje_color_nombre': datoExtra ?? '#00FFC8'},
      'avatar_pulsante'    => {'canje_avatar_pulsante': true},
      'flash_vip'          => {'canje_flash_vip_expira': expiraAt != null ? Timestamp.fromDate(expiraAt) : null},
      'resena_destacada'   => {'canje_resena_destacada': true},
      'prioridad_reserva'  => {'canje_prioridad_expira': expiraAt != null ? Timestamp.fromDate(expiraAt) : null},
      'modo_anonimo'       => {'canje_anonimo_usos': usos ?? 3},
      'multiplicador_x2'   => {'canje_multi_expira': expiraAt != null ? Timestamp.fromDate(expiraAt) : null},
      'trofeo_coleccionista'=> {'canje_trofeo_col': true},
      'categoria_leyendas' => {'canje_leyendas': true},
      'retos_exclusivos'   => {'canje_retos_expira': expiraAt != null ? Timestamp.fromDate(expiraAt) : null},
      'tema_midnight'      => {'canje_tema': 'midnight'},
      'firma_personal'     => {'canje_firma': datoExtra ?? '✨'},
      'perfil_publico'     => {'canje_perfil_publico': true},
      'animacion_logro'    => {'canje_animacion': true},
      'vitrina_trofeos'    => {'canje_vitrina': datoExtra ?? ''},
      _                    => <String, dynamic>{},
    };
  }

  static String? _campoCleanupPorItem(String itemId) => switch (itemId) {
    'modo_anonimo'      => 'canje_anonimo_usos',
    'resena_destacada'  => 'canje_resena_destacada',
    _                   => null,
  };
}

// ── Modelo CanjeActivo ──────────────────────────────────────────────
class CanjeActivo {
  final String id;
  final String itemId;
  final String nombre;
  final DateTime? expiraAt;
  final String? datoExtra;
  final int? usosRestantes;

  CanjeActivo({
    required this.id,
    required this.itemId,
    required this.nombre,
    this.expiraAt,
    this.datoExtra,
    this.usosRestantes,
  });

  factory CanjeActivo.fromMap(Map<String, dynamic> m, String id) => CanjeActivo(
    id:             id,
    itemId:         m['item_id'] as String? ?? '',
    nombre:         m['nombre'] as String? ?? '',
    expiraAt:       (m['expira_at'] as Timestamp?)?.toDate(),
    datoExtra:      m['dato_extra'] as String?,
    usosRestantes:  m['usos_restantes'] as int?,
  );
}
