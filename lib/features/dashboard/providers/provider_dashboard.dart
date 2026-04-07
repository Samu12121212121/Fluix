import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

final _log = Logger();

/// Provider para el dashboard — carga módulos y suscripción desde Firestore
class ProviderDashboard with ChangeNotifier {
  bool _cargando = false;
  String? _error;
  List<String> _modulosActivos = [];
  List<String> _modulosDisponibles = [
    'Reservas',
    'Clientes',
    'Servicios',
    'Ofertas',
    'Valoraciones',
    'Finanzas',
    'Empleados',
    'Estadísticas',
    'Alertas',
    'Citas',
    'Tareas',
    'Pedidos',
    'Facturación',
    'Nóminas',
    'WhatsApp',
    'Web',
  ];

  // Getters
  List<String> get modulosActivos => _modulosActivos;
  List<String> get modulosDisponibles => _modulosDisponibles;
  bool get cargando => _cargando;
  String? get error => _error;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Carga los módulos activos desde Firestore (empresas/{id}/configuracion/modulos)
  Future<void> cargarDatos(String empresaId) async {
    _cambiarCargando(true);
    _limpiarError();

    try {
      final doc = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('modulos')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final lista = <String>[];
        for (final entry in data.entries) {
          if (entry.value == true) {
            lista.add(entry.key);
          }
        }
        _modulosActivos = lista;
      } else {
        _modulosActivos = ['Reservas', 'Clientes', 'Servicios'];
      }

      notifyListeners();
    } catch (e) {
      _log.e('Error cargando módulos del dashboard', error: e);
      _manejarError('Error al cargar datos: $e');
    } finally {
      _cambiarCargando(false);
    }
  }

  Future<void> toggleModulo(String empresaId, String modulo) async {
    _limpiarError();

    try {
      if (_modulosActivos.contains(modulo)) {
        _modulosActivos.remove(modulo);
      } else {
        _modulosActivos.add(modulo);
      }

      // Persistir en Firestore
      final mapa = <String, bool>{};
      for (final m in _modulosDisponibles) {
        mapa[m] = _modulosActivos.contains(m);
      }
      await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('modulos')
          .set(mapa, SetOptions(merge: true));

      notifyListeners();
    } catch (e) {
      _log.e('Error al cambiar módulo', error: e);
      _manejarError('Error al cambiar módulo: $e');
    }
  }

  /// Verifica que la suscripción esté activa
  Future<bool> verificarSuscripcion(String empresaId) async {
    try {
      final doc = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('suscripcion')
          .doc('actual')
          .get();

      if (!doc.exists) return true;

      final data = doc.data()!;
      final estado = data['estado'] as String? ?? 'ACTIVA';

      if (estado == 'ACTIVA' || estado == 'TRIAL') return true;

      final raw = data['fecha_fin'];
      if (raw is Timestamp) {
        final fechaFin = raw.toDate();
        if (DateTime.now().isAfter(fechaFin)) {
          _log.w('Suscripción vencida para empresa $empresaId');
          return false;
        }
      }

      return estado != 'VENCIDA' && estado != 'SUSPENDIDA';
    } catch (e) {
      _log.e('Error verificando suscripción', error: e);
      return true;
    }
  }

  void _cambiarCargando(bool valor) {
    _cargando = valor;
    notifyListeners();
  }

  void _manejarError(String mensaje) {
    _error = mensaje;
    notifyListeners();
  }

  void _limpiarError() {
    _error = null;
    notifyListeners();
  }

  void limpiarError() => _limpiarError();
}
