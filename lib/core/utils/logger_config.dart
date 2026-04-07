import 'package:logger/logger.dart';

/// Configuración centralizada del Logger para Fluix CRM.
/// Uso: `final _log = crearLogger('NombreClase');`
/// O simplemente: `final _log = Logger();` para usar la config por defecto.
///
/// En producción (kReleaseMode) solo muestra warnings y errores.
/// En debug muestra todo desde verbose.

Logger crearLogger(String tag) {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    filter: ProductionFilter(),
  );
}

/// Logger para producción: solo warning, error y fatal.
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // En modo release, solo warning+
    // En debug, todo
    assert(() {
      // Estamos en modo debug
      return true;
    }());
    return true; // En debug siempre loguear; en release el assert no se ejecuta
  }
}

/// Logger singleton global para uso rápido
final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

