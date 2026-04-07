import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Cache local con SQLite para modo offline
//
// Tablas:
//   cache_kpis:         (id TEXT PK, datos TEXT, timestamp TEXT)
//   cache_notificaciones: (id TEXT PK, datos TEXT, timestamp TEXT)
//   cache_widgets:      (id TEXT PK, datos TEXT, timestamp TEXT)
//
// Estrategia:
//   1. Al abrir la app → leer cache → mostrar inmediatamente
//   2. Firestore devuelve datos → guardar en cache + reemplazar UI
//   3. Sin conexión → cache con banner "Datos del {fecha}"
//   4. Expiración: 24 horas
// ─────────────────────────────────────────────────────────────────────────────

class CacheService {
  static final CacheService _i = CacheService._();
  factory CacheService() => _i;
  CacheService._();

  static const _dbName = 'fluixcrm_cache.db';
  static const _version = 1;
  static const _duracionExpiracion = Duration(hours: 24);

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache_kpis (
            id TEXT PRIMARY KEY,
            datos TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cache_notificaciones (
            id TEXT PRIMARY KEY,
            datos TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cache_widgets (
            id TEXT PRIMARY KEY,
            datos TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ── GUARDAR ─────────────────────────────────────────────────────────────

  Future<void> guardar({
    required String tabla,
    required String id,
    required Map<String, dynamic> datos,
  }) async {
    final db = await _database;
    await db.insert(
      tabla,
      {
        'id': id,
        'datos': jsonEncode(datos),
        'timestamp': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── LEER ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> leer({
    required String tabla,
    required String id,
  }) async {
    final db = await _database;
    final results = await db.query(tabla, where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;

    final row = results.first;
    if (estaExpirado(row['timestamp'] as String)) return null;

    return jsonDecode(row['datos'] as String) as Map<String, dynamic>;
  }

  // ── EXPIRACIÓN ──────────────────────────────────────────────────────────

  bool estaExpirado(String timestampStr) {
    final guardado = DateTime.parse(timestampStr);
    return DateTime.now().difference(guardado) > _duracionExpiracion;
  }

  /// Obtiene la fecha de la última sincronización, formateada.
  Future<String?> ultimaSincronizacion({
    required String tabla,
    required String id,
  }) async {
    final db = await _database;
    final results = await db.query(tabla, where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    final ts = DateTime.parse(results.first['timestamp'] as String);
    return DateFormat('dd/MM/yyyy HH:mm').format(ts);
  }

  // ── LIMPIAR ─────────────────────────────────────────────────────────────

  Future<void> limpiar({String? tabla}) async {
    final db = await _database;
    if (tabla != null) {
      await db.delete(tabla);
    } else {
      await db.delete('cache_kpis');
      await db.delete('cache_notificaciones');
      await db.delete('cache_widgets');
    }
  }

  /// Elimina solo las entradas expiradas.
  Future<void> limpiarExpirados() async {
    final db = await _database;
    final limite = DateTime.now().subtract(_duracionExpiracion).toIso8601String();
    for (final tabla in ['cache_kpis', 'cache_notificaciones', 'cache_widgets']) {
      await db.delete(tabla, where: 'timestamp < ?', whereArgs: [limite]);
    }
  }
}

