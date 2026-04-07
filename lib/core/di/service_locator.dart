import 'package:get_it/get_it.dart';
import '../../services/facturacion_service.dart';
import '../../services/nominas_service.dart';
import '../../services/pedidos_service.dart';
import '../../services/empresa_config_service.dart';
import '../../core/utils/permisos_service.dart';

final getIt = GetIt.instance;

/// Registra todos los servicios en get_it.
/// Llamar una vez en main() antes de runApp().
void configurarServiceLocator() {
  // Servicios singleton (lazy)
  getIt.registerLazySingleton<FacturacionService>(() => FacturacionService());
  getIt.registerLazySingleton<NominasService>(() => NominasService());
  getIt.registerLazySingleton<PedidosService>(() => PedidosService());
  getIt.registerLazySingleton<EmpresaConfigService>(() => EmpresaConfigService());
  getIt.registerLazySingleton<PermisosService>(() => PermisosService());
}

/// Resetea todos los servicios (útil para tests)
void resetearServiceLocator() {
  getIt.reset();
}

