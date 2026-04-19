import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

  factory FichaNegocio.fromMap(Map<String, dynamic> map) {
    return FichaNegocio(
      accountId: map['accountId'] as String? ?? '',
      locationId: map['locationId'] as String? ?? '',
      nombre: map['nombre'] as String? ?? 'Sin nombre',
      direccion: map['direccion'] as String? ?? '',
    );
  }
}

// ── Servicio GMB Auth ─────────────────────────────────────────────────────────
/// Usa accessToken directamente (no serverAuthCode).
/// No requiere Cloud Functions — escribe en Firestore desde el cliente.
/// Reutiliza la sesión de Google existente en la app y solicita
/// el scope adicional `business.manage`.

class GmbAuthService extends ChangeNotifier {
  static const _keyConectado        = 'gmb_conectado';
  static const _keyNombreFicha      = 'gmb_nombre_ficha';
  static const _keyDireccionFicha   = 'gmb_direccion_ficha';
  static const _keyUltimaSync       = 'gmb_ultima_sync';
  static const _keyAccessToken      = 'gmb_access_token';
  static const _gmbScope = 'https://www.googleapis.com/auth/business.manage';

  final _storage   = const FlutterSecureStorage();
  final _db        = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  final _dio       = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', _gmbScope],
  );

  bool _conectado = false;
  String? _nombreFicha;
  String? _direccionFicha;
  DateTime? _ultimaSync;
  bool _cargando = false;
  String? _error;

  bool get conectado       => _conectado;
  String? get nombreFicha  => _nombreFicha;
  String? get direccionFicha => _direccionFicha;
  DateTime? get ultimaSync => _ultimaSync;
  bool get cargando        => _cargando;
  String? get error        => _error;

  /// Carga el estado de conexión guardado localmente.
  Future<void> inicializar(String empresaId) async {
    try {
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('gmb_config')
          .get();

      if (snap.exists && snap.data()?['conectado'] == true) {
        _conectado     = true;
        _nombreFicha   = snap.data()?['nombre_ficha']    as String? ?? '';
        _direccionFicha= snap.data()?['direccion_ficha'] as String? ?? '';
        final ts       = snap.data()?['ultima_sync'] as Timestamp?;
        _ultimaSync    = ts?.toDate();
        await _storage.write(key: _keyConectado,     value: 'true');
        await _storage.write(key: _keyNombreFicha,   value: _nombreFicha ?? '');
        await _storage.write(key: _keyDireccionFicha,value: _direccionFicha ?? '');
        if (_ultimaSync != null) {
          await _storage.write(key: _keyUltimaSync,
              value: _ultimaSync!.toIso8601String());
        }
        notifyListeners();
        return;
      }
    } catch (_) {}

    // Fallback: leer del storage local
    final local = await _storage.read(key: _keyConectado);
    _conectado = local == 'true';
    if (_conectado) {
      _nombreFicha    = await _storage.read(key: _keyNombreFicha);
      _direccionFicha = await _storage.read(key: _keyDireccionFicha);
      final syncStr   = await _storage.read(key: _keyUltimaSync);
      if (syncStr != null) _ultimaSync = DateTime.tryParse(syncStr);
    }
    notifyListeners();
  }

  /// Inicia el flujo OAuth2:
  ///   1. Sign-in con Google (pide permiso business.manage)
  ///   2. Obtiene accessToken
  ///   3. Escribe estado en Firestore
  ///   4. Devuelve null si va bien, o mensaje de error.
  Future<String?> conectar(String empresaId) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Login silencioso primero, luego interactivo
      var account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        _cargando = false;
        notifyListeners();
        return 'Inicio de sesión cancelado.';
      }

      // 2. Obtener accessToken
      final auth        = await account.authentication;
      final accessToken = auth.accessToken;

      if (accessToken == null) {
        _cargando = false;
        notifyListeners();
        return 'No se pudo obtener el token de acceso de Google.\n'
            'Asegúrate de aceptar todos los permisos solicitados.';
      }

      // 3. Guardar token en secure storage
      await _storage.write(key: _keyAccessToken, value: accessToken);

      // 4. Marcar como conectado en Firestore (sin Cloud Function)
      await _db
          .collection('empresas').doc(empresaId)
          .collection('configuracion').doc('gmb_config')
          .set({
        'conectado':    true,
        'email_google': account.email,
        'nombre_google': account.displayName ?? '',
        'conectado_en': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _conectado = true;
      _cargando = false;
      notifyListeners();
      return null;
    } catch (e) {
      _cargando = false;
      _error = e.toString();
      notifyListeners();
      return _mapearError(e.toString());
    }
  }

  // ── Obtener fichas de negocio ─────────────────────────────────────────────
  /// Llama a la Business Account Management API para listar cuentas y fichas.
  Future<({List<FichaNegocio> fichas, String? error})> obtenerFichas(
      String empresaId) async {
    final token = await _obtenerToken();
    if (token == null) {
      return (fichas: <FichaNegocio>[],
          error: 'Sesión expirada. Vuelve a conectar tu cuenta de Google.');
    }

    try {
      // 1. Obtener cuentas de Business Profile
      final rAccounts = await _dio.get(
        'https://mybusinessaccountmanagement.googleapis.com/v1/accounts',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final accounts = (rAccounts.data['accounts'] as List<dynamic>? ?? []);
      if (accounts.isEmpty) {
        return (fichas: <FichaNegocio>[],
            error: 'No encontramos ninguna ficha de Google Business en tu cuenta.\n'
                'Asegúrate de tener un perfil creado en business.google.com');
      }

      final fichas = <FichaNegocio>[];

      // 2. Para cada cuenta, obtener sus ubicaciones
      for (final account in accounts.take(5)) {
        final accountName = account['name'] as String? ?? '';
        if (accountName.isEmpty) continue;

        try {
          final rLoc = await _dio.get(
            'https://mybusinessbusinessinformation.googleapis.com/v1/'
                '$accountName/locations?readMask=name,title,storefrontAddress',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );

          final locations = rLoc.data['locations'] as List<dynamic>? ?? [];
          for (final loc in locations) {
            final locName  = loc['name']  as String? ?? '';
            final titulo   = loc['title'] as String? ?? 'Sin nombre';
            final addr     = (loc['storefrontAddress'] as Map<String, dynamic>?);
            final direccion = addr != null
                ? [
                    addr['addressLines']?.first,
                    addr['locality'],
                    addr['administrativeArea'],
                  ].whereType<String>().join(', ')
                : '';

            fichas.add(FichaNegocio(
              accountId:  accountName.replaceFirst('accounts/', ''),
              locationId: locName.split('/').last,
              nombre:     titulo,
              direccion:  direccion,
            ));
          }
        } catch (_) {
          // Si falla una cuenta, continúa con las demás
        }
      }

      if (fichas.isEmpty) {
        return (fichas: <FichaNegocio>[],
            error: 'No encontramos ninguna ubicación en tu cuenta de Google Business.');
      }

      return (fichas: fichas, error: null);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return (fichas: <FichaNegocio>[],
            error: 'Token expirado o sin permisos.\n'
                'Cierra sesión y vuelve a conectar tu cuenta de Google.');
      }
      return (fichas: <FichaNegocio>[],
          error: 'Error de red: ${e.message}');
    } catch (e) {
      return (fichas: <FichaNegocio>[],
          error: 'Error inesperado: $e');
    }
  }

  // ── Guardar ficha seleccionada ────────────────────────────────────────────
  Future<String?> guardarFicha(String empresaId, FichaNegocio ficha) async {
    try {
      // Escribir directamente en Firestore (sin Cloud Function)
      await _db
          .collection('empresas').doc(empresaId)
          .collection('configuracion').doc('gmb_config')
          .set({
        'conectado':      true,
        'account_id':     ficha.accountId,
        'location_id':    ficha.locationId,
        'nombre_ficha':   ficha.nombre,
        'direccion_ficha':ficha.direccion,
        'ultima_sync':    FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _conectado      = true;
      _nombreFicha    = ficha.nombre;
      _direccionFicha = ficha.direccion;
      _ultimaSync     = DateTime.now();
      _cargando = false;

      await _storage.write(key: _keyConectado,      value: 'true');
      await _storage.write(key: _keyNombreFicha,    value: ficha.nombre);
      await _storage.write(key: _keyDireccionFicha, value: ficha.direccion);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Error al guardar la ficha: $e';
    }
  }

  // ── Desconectar ───────────────────────────────────────────────────────────
  Future<void> desconectar(String empresaId) async {
    try {
      await _db
          .collection('empresas').doc(empresaId)
          .collection('configuracion').doc('gmb_config')
          .set({'conectado': false}, SetOptions(merge: true));
    } catch (_) {}

    try { await _googleSignIn.signOut(); } catch (_) {}

    _conectado      = false;
    _nombreFicha    = null;
    _direccionFicha = null;
    _ultimaSync     = null;

    await _storage.delete(key: _keyConectado);
    await _storage.delete(key: _keyNombreFicha);
    await _storage.delete(key: _keyDireccionFicha);
    await _storage.delete(key: _keyUltimaSync);
    await _storage.delete(key: _keyAccessToken);

    notifyListeners();
  }

  // ── Token helper ──────────────────────────────────────────────────────────
  /// Obtiene el accessToken: primero del storage local; si ha expirado,
  /// intenta un login silencioso para renovarlo.
  Future<String?> _obtenerToken() async {
    final stored = await _storage.read(key: _keyAccessToken);
    if (stored != null) return stored;

    // Intentar renovar silenciosamente
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      final auth  = await account.authentication;
      final token = auth.accessToken;
      if (token != null) {
        await _storage.write(key: _keyAccessToken, value: token);
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  String _mapearError(String error) {
    final e = error.toLowerCase();
    if (e.contains('oauth') || e.contains('credentials')) {
      return 'Error de configuración OAuth. Contacta con soporte.';
    }
    if (e.contains('suspended')) {
      return 'Tu ficha de Google Business está suspendida. Contáctate con Google para resolverlo.';
    }
    if (e.contains('access_denied') || e.contains('denied')) {
      return 'Has denegado el permiso. Vuelve a intentarlo y acepta los permisos de Google Business.';
    }
    if (e.contains('network') || e.contains('socket') || e.contains('connection')) {
      return 'Sin conexión a internet. Comprueba tu red e inténtalo de nuevo.';
    }
    if (e.contains('sign_in_failed') || e.contains('sign_in_cancelled')) {
      return 'Inicio de sesión cancelado o fallido.\nInténtalo de nuevo.';
    }
    if (e.contains('business.manage') || e.contains('scope')) {
      return 'Necesitas tener una ficha de Google Business activa\n'
          'para usar esta función.';
    }
    debugPrint('❌ GmbAuthService error: $error');
    return 'Error al conectar con Google: $error';
  }
}
