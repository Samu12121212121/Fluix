import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Servicio de autenticación con Google Business Profile API.
/// Reutiliza la sesión de Google existente en la app y solicita
/// el scope adicional `business.manage`.
class GmbAuthService extends ChangeNotifier {
  static final GmbAuthService _i = GmbAuthService._();
  factory GmbAuthService() => _i;
  GmbAuthService._();

  static const _keyConectado = 'gmb_conectado';
  static const _keyNombreFicha = 'gmb_nombre_ficha';
  static const _keyDireccionFicha = 'gmb_direccion_ficha';
  static const _keyUltimaSync = 'gmb_ultima_sync';

  final _storage = const FlutterSecureStorage();
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  // Scope específico de Google Business Profile
  static const _gmbScope =
      'https://www.googleapis.com/auth/business.manage';

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      _gmbScope,
    ],
  );

  // ── Estado observable ─────────────────────────────────────────────────────

  bool _conectado = false;
  String? _nombreFicha;
  String? _direccionFicha;
  DateTime? _ultimaSync;
  bool _cargando = false;
  String? _error;

  bool get conectado => _conectado;
  String? get nombreFicha => _nombreFicha;
  String? get direccionFicha => _direccionFicha;
  DateTime? get ultimaSync => _ultimaSync;
  bool get cargando => _cargando;
  String? get error => _error;

  // ── Inicialización ────────────────────────────────────────────────────────

  /// Carga el estado de conexión guardado localmente.
  Future<void> inicializar(String empresaId) async {
    try {
      // Primero, comprobar Firestore (fuente de verdad)
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('gmb_config')
          .get();

      if (snap.exists && snap.data()?['conectado'] == true) {
        _conectado = true;
        _nombreFicha = snap.data()?['nombre_ficha'] as String? ?? '';
        _direccionFicha = snap.data()?['direccion_ficha'] as String? ?? '';
        final tsSync = snap.data()?['ultima_sync'] as Timestamp?;
        _ultimaSync = tsSync?.toDate();

        // Persistir localmente para acceso sin red
        await _storage.write(key: _keyConectado, value: 'true');
        await _storage.write(
            key: _keyNombreFicha, value: _nombreFicha ?? '');
        await _storage.write(
            key: _keyDireccionFicha, value: _direccionFicha ?? '');
        if (_ultimaSync != null) {
          await _storage.write(
              key: _keyUltimaSync, value: _ultimaSync!.toIso8601String());
        }
      } else {
        // Fallback a storage local
        final localConectado = await _storage.read(key: _keyConectado);
        _conectado = localConectado == 'true';
        if (_conectado) {
          _nombreFicha = await _storage.read(key: _keyNombreFicha);
          _direccionFicha = await _storage.read(key: _keyDireccionFicha);
          final syncStr = await _storage.read(key: _keyUltimaSync);
          if (syncStr != null) _ultimaSync = DateTime.tryParse(syncStr);
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  // ── Flujo de conexión ─────────────────────────────────────────────────────

  /// Inicia el flujo OAuth2 simplificado:
  /// 1. Intenta login silencioso (si ya tiene sesión)
  /// 2. Si no, muestra pantalla de Google
  /// 3. Obtiene serverAuthCode
  /// 4. Llama a Cloud Function para guardar tokens en Secret Manager
  /// Devuelve `null` si va bien, o un mensaje de error.
  Future<String?> conectar(String empresaId) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      // Intentar login silencioso primero
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        _cargando = false;
        notifyListeners();
        return 'Inicio de sesión cancelado';
      }

      final serverAuthCode = account.serverAuthCode;
      if (serverAuthCode == null) {
        _cargando = false;
        notifyListeners();
        return 'No se pudo obtener el código de autorización. '
            'Asegúrate de que el Client ID está configurado correctamente.';
      }

      // Enviar a Cloud Function para intercambiar y guardar en Secret Manager
      final callable =
          _functions.httpsCallable('storeGmbToken');
      await callable.call({
        'empresaId': empresaId,
        'serverAuthCode': serverAuthCode,
      });

      _cargando = false;
      notifyListeners();
      return null; // éxito
    } on FirebaseFunctionsException catch (e) {
      _cargando = false;
      _error = e.message;
      notifyListeners();
      return _mapearErrorGmb(e.message ?? e.code);
    } catch (e) {
      _cargando = false;
      _error = e.toString();
      notifyListeners();
      return 'Error inesperado: $e';
    }
  }

  /// Obtiene la lista de fichas de negocio del usuario.
  Future<({List<FichaNegocio> fichas, String? error})> obtenerFichas(
      String empresaId) async {
    try {
      final callable =
          _functions.httpsCallable('obtenerFichasNegocio');
      final result = await callable.call({'empresaId': empresaId});
      final fichasRaw =
          (result.data['fichas'] as List<dynamic>?) ?? [];
      final fichas = fichasRaw
          .map((f) => FichaNegocio.fromMap(f as Map<String, dynamic>))
          .toList();
      return (fichas: fichas, error: null);
    } on FirebaseFunctionsException catch (e) {
      return (
        fichas: <FichaNegocio>[],
        error: _mapearErrorGmb(e.message ?? e.code)
      );
    } catch (e) {
      return (fichas: <FichaNegocio>[], error: e.toString());
    }
  }

  /// Guarda la ficha seleccionada y marca la empresa como conectada.
  Future<String?> guardarFicha(
      String empresaId, FichaNegocio ficha) async {
    try {
      final callable =
          _functions.httpsCallable('guardarFichaSeleccionada');
      await callable.call({
        'empresaId': empresaId,
        'accountId': ficha.accountId,
        'locationId': ficha.locationId,
        'nombreFicha': ficha.nombre,
        'direccionFicha': ficha.direccion,
      });

      _conectado = true;
      _nombreFicha = ficha.nombre;
      _direccionFicha = ficha.direccion;
      _ultimaSync = null;

      await _storage.write(key: _keyConectado, value: 'true');
      await _storage.write(key: _keyNombreFicha, value: ficha.nombre);
      await _storage.write(
          key: _keyDireccionFicha, value: ficha.direccion);

      notifyListeners();
      return null;
    } on FirebaseFunctionsException catch (e) {
      return _mapearErrorGmb(e.message ?? e.code);
    } catch (e) {
      return e.toString();
    }
  }

  /// Desconecta la cuenta de Google Business Profile.
  Future<void> desconectar(String empresaId) async {
    try {
      final callable =
          _functions.httpsCallable('desconectarGoogleBusiness');
      await callable.call({'empresaId': empresaId});
    } catch (_) {}

    _conectado = false;
    _nombreFicha = null;
    _direccionFicha = null;
    _ultimaSync = null;

    await _storage.deleteAll();
    notifyListeners();
  }

  // ── Mapeo de errores ──────────────────────────────────────────────────────

  String _mapearErrorGmb(String error) {
    if (error.contains('business.manage') || error.contains('scope')) {
      return 'Necesitas tener una ficha de Google Business para usar esta función.';
    }
    if (error.contains('access_denied') || error.contains('denied')) {
      return 'Has denegado el permiso. Vuelve a intentarlo y acepta los permisos de Google Business.';
    }
    if (error.contains('SUSPENDED') || error.contains('suspended')) {
      return 'Tu ficha de Google Business está suspendida. Contáctate con Google para resolverlo.';
    }
    if (error.contains('not-found') || error.contains('404')) {
      return 'No se encontró ninguna ficha de Google Business en tu cuenta.';
    }
    if (error.contains('OAuth') || error.contains('credentials')) {
      return 'Error de configuración OAuth. Contacta con soporte.';
    }
    return 'Error al conectar con Google Business: $error';
  }
}

// ── Modelo de ficha de negocio ────────────────────────────────────────────────

class FichaNegocio {
  final String accountId;
  final String locationId;
  final String nombre;
  final String direccion;

  const FichaNegocio({
    required this.accountId,
    required this.locationId,
    required this.nombre,
    required this.direccion,
  });

  factory FichaNegocio.fromMap(Map<String, dynamic> map) => FichaNegocio(
        accountId: map['accountId'] as String? ?? '',
        locationId: map['locationId'] as String? ?? '',
        nombre: map['nombre'] as String? ?? 'Sin nombre',
        direccion: map['direccion'] as String? ?? '',
      );
}

