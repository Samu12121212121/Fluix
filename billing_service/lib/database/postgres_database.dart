// lib/database/postgres_database.dart
// Implementación PostgreSQL usando el paquete postgres.

import 'package:postgres/postgres.dart';
import 'database.dart';

class PostgresDatabase implements Database {
  final PostgreSQLConnection _conn;

  PostgresDatabase(this._conn);

  static Future<PostgresDatabase> connect({
    required String host,
    required int port,
    required String databaseName,
    required String username,
    required String password,
    bool useSSL = true,
  }) async {
    final conn = PostgreSQLConnection(
      host,
      port,
      databaseName,
      username: username,
      password: password,
      useSSL:   useSSL,
    );
    await conn.open();
    return PostgresDatabase(conn);
  }

  /// Crea una instancia desde DATABASE_URL:
  ///   postgresql://user:pass@host:5432/dbname
  static Future<PostgresDatabase> fromUrl(String url) async {
    final uri  = Uri.parse(url);
    final user = uri.userInfo.split(':');
    return connect(
      host:         uri.host,
      port:         uri.port == 0 ? 5432 : uri.port,
      databaseName: uri.path.replaceFirst('/', ''),
      username:     user.isNotEmpty ? Uri.decodeComponent(user[0]) : '',
      password:     user.length > 1 ? Uri.decodeComponent(user[1]) : '',
    );
  }

  @override
  Future<int> execute(String sql, [Map<String, dynamic>? params]) async {
    final result = await _conn.execute(
      _adaptSql(sql),
      substitutionValues: _adaptParams(params),
    );
    return result;
  }

  @override
  Future<Map<String, dynamic>?> queryOne(
    String sql, [
    Map<String, dynamic>? params,
  ]) async {
    final rows = await _conn.mappedResultsQuery(
      _adaptSql(sql),
      substitutionValues: _adaptParams(params),
    );
    if (rows.isEmpty) return null;
    return _flattenRow(rows.first);
  }

  @override
  Future<List<Map<String, dynamic>>> queryMany(
    String sql, [
    Map<String, dynamic>? params,
  ]) async {
    final rows = await _conn.mappedResultsQuery(
      _adaptSql(sql),
      substitutionValues: _adaptParams(params),
    );
    return rows.map(_flattenRow).toList();
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Database tx) action) async {
    late T result;
    await _conn.transaction((ctx) async {
      result = await action(_TransactionDb(ctx));
    });
    return result;
  }

  @override
  Future<void> close() => _conn.close();

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Convierte @paramName → $1, $2… (estilo postgres package)
  String _adaptSql(String sql) {
    final regex = RegExp(r'@(\w+)');
    int index   = 1;
    return sql.replaceAllMapped(regex, (_) => '\$${index++}');
  }

  Map<String, dynamic>? _adaptParams(Map<String, dynamic>? p) => p;

  Map<String, dynamic> _flattenRow(Map<String, Map<String, dynamic>> row) {
    final result = <String, dynamic>{};
    for (final table in row.values) result.addAll(table);
    return result;
  }
}

class _TransactionDb implements Database {
  final PostgreSQLExecutionContext _ctx;
  _TransactionDb(this._ctx);

  @override
  Future<int> execute(String sql, [Map<String, dynamic>? params]) =>
      _ctx.execute(sql, substitutionValues: params);

  @override
  Future<Map<String, dynamic>?> queryOne(
    String sql, [
    Map<String, dynamic>? params,
  ]) async {
    final rows = await _ctx.mappedResultsQuery(sql, substitutionValues: params);
    if (rows.isEmpty) return null;
    final result = <String, dynamic>{};
    for (final MapEntry<String, Map<String, dynamic>> entry in rows.first.entries) {
      result.addAll(entry.value);
    }
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> queryMany(
    String sql, [
    Map<String, dynamic>? params,
  ]) async {
    final rows = await _ctx.mappedResultsQuery(sql, substitutionValues: params);
    return rows.map((Map<String, Map<String, dynamic>> r) {
      final m = <String, dynamic>{};
      for (final MapEntry<String, Map<String, dynamic>> entry in r.entries) {
        m.addAll(entry.value);
      }
      return m;
    }).toList();
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Database tx) action) =>
      action(this);

  @override
  Future<void> close() async {}
}

