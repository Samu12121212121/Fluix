import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class OfflineQueueService {
  static final OfflineQueueService _i = OfflineQueueService._();
  factory OfflineQueueService() => _i;
  OfflineQueueService._();

  Database? _db;

  static const _tableName = 'pedidos_offline';

  // ── INIT ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, 'offline_queue.db');
    _db = await openDatabase(
      fullPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            empresa_id  TEXT    NOT NULL,
            pedido_json TEXT    NOT NULL,
            timestamp   INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<Database> get _database async {
    if (_db == null) await init();
    return _db!;
  }

  // ── ENCOLAR ───────────────────────────────────────────────────────────────

  Future<void> encolar(
      String empresaId, Map<String, dynamic> pedidoData) async {
    final db = await _database;
    await db.insert(_tableName, {
      'empresa_id': empresaId,
      'pedido_json': jsonEncode(pedidoData),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ── CONSULTAS ─────────────────────────────────────────────────────────────

  Future<int> contarPendientes(String empresaId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_tableName WHERE empresa_id = ?',
      [empresaId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> obtenerPendientes(
      String empresaId) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: 'empresa_id = ?',
      whereArgs: [empresaId],
      orderBy: 'timestamp ASC',
    );
    return rows.map((r) {
      final decoded =
          jsonDecode(r['pedido_json'] as String) as Map<String, dynamic>;
      decoded['_local_id'] = r['id'];
      return decoded;
    }).toList();
  }

  // ── SINCRONIZAR ───────────────────────────────────────────────────────────

  Future<void> sincronizarTodos(String empresaId) async {
    final pendientes = await obtenerPendientes(empresaId);
    if (pendientes.isEmpty) return;

    final pedidosRef = FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos');

    for (final pedido in pendientes) {
      final localId = pedido['_local_id'] as int?;
      final data = Map<String, dynamic>.from(pedido)..remove('_local_id');

      try {
        await pedidosRef.add(data);
        if (localId != null) await eliminar(localId);
      } catch (_) {
        // Deja el pedido en cola y continúa con el siguiente
        continue;
      }
    }
  }

  // ── ELIMINAR ──────────────────────────────────────────────────────────────

  Future<void> eliminar(int localId) async {
    final db = await _database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [localId],
    );
  }
}
