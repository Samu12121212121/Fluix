// lib/database/database.dart
// Abstracción de base de datos. La implementación concreta usa PostgreSQL.

abstract class Database {
  /// Ejecuta una sentencia DML y devuelve el número de filas afectadas.
  Future<int> execute(String sql, [Map<String, dynamic>? params]);

  /// Ejecuta una query y devuelve la primera fila, o null si no hay resultados.
  Future<Map<String, dynamic>?> queryOne(
    String sql, [
    Map<String, dynamic>? params,
  ]);

  /// Ejecuta una query y devuelve todas las filas.
  Future<List<Map<String, dynamic>>> queryMany(
    String sql, [
    Map<String, dynamic>? params,
  ]);

  /// Ejecuta un bloque dentro de una transacción.
  Future<T> transaction<T>(Future<T> Function(Database tx) action);

  /// Cierra la conexión.
  Future<void> close();
}

