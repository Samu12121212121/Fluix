import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// No requiere Cloud Functions — escribe en Firestore desde el cliente.
/// Requiere que la cuenta de Google tenga verificado
/// el scope adicional `business.manage`.
class GmbAuthService extends ChangeNotifier {
  static final GmbAuthService _i = GmbAuthService._();
  factory GmbAuthService() => _i;
  GmbAuthService._();

  // Scope específico de Google Business Profile
  static const _gmbScope =
      'https://www.googleapis.com/auth/business.manage';

  static const _keyConectado        = 'gmb_conectado';
  static const _keyNombreFicha      = 'gmb_nombre_ficha';
  static const _keyDireccionFicha   = 'gmb_direccion_ficha';
  static const _keyUltimaSync       = 'gmb_ultima_sync';

  final _db        = FirebaseFirestore.instance;
  final _storage   = const FlutterSecureStorage();
  // ignore: unused_field
  final _functions = FirebaseFunctions.instance;

  final _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      _gmbScope,
    ],
  );

  // ── Estado observable ─────────────────────────────────────────────────────

  bool      _conectado      = false;
  String?   _nombreFicha;
  String?   _direccionFicha;
  DateTime? _ultimaSync;
  bool      _cargando       = false;
  String?   _error;

  bool      get conectado      => _conectado;
  String?   get nombreFicha    => _nombreFicha;
  String?   get direccionFicha => _direccionFicha;
  DateTime? get ultimaSync     => _ultimaSync;
  bool      get cargando       => _cargando;
  String?   get error          => _error;

  // ── Inicialización ────────────────────────────────────────────────────────

  Future<void> init(String empresaId) async {
    try {
      // Cargar desde storage local primero (acceso sin red)
      final localConectado = await _storage.read(key: _keyConectado);
      _conectado = localConectado == 'true';
      if (_conectado) {
        _nombreFicha    = await _storage.read(key: _keyNombreFicha);
        _direccionFicha = await _storage.read(key: _keyDireccionFicha);
        final syncStr   = await _storage.read(key: _keyUltimaSync);
        if (syncStr != null) _ultimaSync = DateTime.tryParse(syncStr);
      }
    } catch (_) {}

    try {
      // Primero, comprobar Firestore (fuente de verdad)
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('gmb_config')
          .get();

      if (snap.exists) {
        _conectado      = snap.data()?['conectado']       as bool?   ?? false;
        _nombreFicha    = snap.data()?['nombre_ficha']    as String? ?? '';
        _direccionFicha = snap.data()?['direccion_ficha'] as String? ?? '';
        final tsSync    = snap.data()?['ultima_sync']     as Timestamp?;
        _ultimaSync     = tsSync?.toDate();

        // Persistir localmente para acceso sin red
        await _storage.write(key: _keyConectado,      value: _conectado ? 'true' : 'false');
        await _storage.write(key: _keyNombreFicha,    value: _nombreFicha    ?? '');
        await _storage.write(key: _keyDireccionFicha, value: _direccionFicha ?? '');
        if (_ultimaSync != null) {
          await _storage.write(
              key: _keyUltimaSync, value: _ultimaSync!.toIso8601String());
        }
      }
    } catch (_) {}

    notifyListeners();
  }

  // ── Conectar con Google Business ─────────────────────────────────────────

  /// Inicia el flujo OAuth2:
  ///   1. Sign-in con Google (pide permiso business.manage)
  ///   2. Obtiene accessToken
  ///   3. Escribe estado en Firestore
  ///   4. Devuelve null si va bien, o mensaje de error.
  Future<String?> conectar(String empresaId) async {
    _cargando = true;
    _error    = null;
    notifyListeners();

    try {
      // Intentar login silencioso primero
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
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

      // 3. Guardar token en secure storage / estado en Firestore
      await _db
          .collection('empresas').doc(empresaId)
          .collection('configuracion').doc('gmb_config')
          .set({
        'conectado':     true,
        'email_google':  account.email,
        'nombre_google': account.displayName ?? '',
        'conectado_en':  FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _conectado = true;
      _cargando  = false;
      notifyListeners();
      return null; // éxito

    } on FirebaseFunctionsException catch (e) {
      _cargando = false;
      _error    = e.message;
      notifyListeners();
      return _mapearErrorGmb(e.message ?? e.toString());
    } catch (e) {
      _cargando = false;
      _error    = e.toString();
      notifyListeners();
      return 'Error inesperado: $e';
    }
  }

  // ── Obtener fichas de negocio ─────────────────────────────────────────────

  /// Obtiene la lista de fichas de negocio del usuario.
  Future<({List<FichaNegocio> fichas, String? error})> obtenerFichas(
      String empresaId) async {
    try {
      final account = _googleSignIn.currentUser
          ?? await _googleSignIn.signInSilently();

      if (account == null) {
        return (fichas: <FichaNegocio>[],
            error:
                'Necesitas tener una ficha de Google Business para usar esta función.');
      }

      final auth        = await account.authentication;
      final accessToken = auth.accessToken;

      if (accessToken == null) {
        return (fichas: <FichaNegocio>[],
            error:
                'No se pudo obtener el token de acceso. Vuelve a conectar tu cuenta.');
      }

      final dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $accessToken';

      // Obtener cuentas de Google Business
      final accountsResp = await dio.get(
          'https://mybusinessaccountmanagement.googleapis.com/v1/accounts');
      final accounts =
          (accountsResp.data['accounts'] as List<dynamic>?) ?? [];

      final fichas = <FichaNegocio>[];

      for (final acc in accounts) {
        final accountName = acc['name'] as String? ?? '';
        try {
          final locsResp = await dio.get(
              'https://mybusinessbusinessinformation.googleapis.com/v1'
              '/$accountName/locations'
              '?readMask=name,title,storefrontAddress');
          final locs =
              (locsResp.data['locations'] as List<dynamic>?) ?? [];

          for (final loc in locs) {
            final locName = loc['name']  as String? ?? '';
            final titulo  = loc['title'] as String? ?? 'Sin nombre';
            final addr =
                loc['storefrontAddress'] as Map<String, dynamic>?;
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
        return (
          fichas: <FichaNegocio>[],
          error:
              'No encontramos ninguna ubicación en tu cuenta de Google Business.'
        );
      }

      return (fichas: fichas, error: null);

    } on FirebaseFunctionsException catch (e) {
      return (fichas: <FichaNegocio>[], error: e.message);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return (
          fichas: <FichaNegocio>[],
          error: 'Token expirado o sin permisos.\n'
              'Cierra sesión y vuelve a conectar tu cuenta de Google.'
        );
      }
      return (fichas: <FichaNegocio>[], error: 'Error de red: ${e.message}');
    } catch (e) {
      return (fichas: <FichaNegocio>[], error: 'Error inesperado: $e');
    }
  }

  // ── Guardar ficha seleccionada ────────────────────────────────────────────

  Future<String?> guardarFicha(
      String empresaId, FichaNegocio ficha) async {
    try {
      // Escribir directamente en Firestore (sin Cloud Function)
      await _db
          .collection('empresas').doc(empresaId)
          .collection('configuracion').doc('gmb_config')
          .set({
        'conectado':       true,
        'account_id':      ficha.accountId,
        'location_id':     ficha.locationId,
        'nombre_ficha':    ficha.nombre,
        'direccion_ficha': ficha.direccion,
        'ultima_sync':     FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _conectado      = true;
      _nombreFicha    = ficha.nombre;
      _direccionFicha = ficha.direccion;
      _ultimaSync     = DateTime.now();

      // Persistir localmente
      await _storage.write(key: _keyConectado,      value: 'true');
      await _storage.write(key: _keyNombreFicha,    value: ficha.nombre);
      await _storage.write(key: _keyDireccionFicha, value: ficha.direccion);
      await _storage.write(
          key: _keyUltimaSync, value: _ultimaSync!.toIso8601String());

      notifyListeners();
      return null; // éxito

    } on FirebaseFunctionsException catch (e) {
      _cargando = false;
      _error    = e.message;
      notifyListeners();
      return 'Error inesperado: $e';
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  // ── Mapear errores GMB ────────────────────────────────────────────────────

  String _mapearErrorGmb(String error) {
    if (error.contains('business.manage') || error.contains('scope')) {
      return 'Necesitas tener una ficha de Google Business para usar esta función.';
    }
    if (error.contains('suspended')) {
      return 'Tu ficha de Google Business está suspendida. Contáctate con Google para resolverlo.';
    }
    if (error.contains('access_denied') || error.contains('denied')) {
      return 'Has denegado el permiso. Vuelve a intentarlo y acepta los permisos de Google Business.';
    }
    if (error.contains('not_found') || error.contains('No se encontró')) {
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
        accountId:  map['accountId']  as String? ?? '',
        locationId: map['locationId'] as String? ?? '',
        nombre:     map['nombre']     as String? ?? 'Sin nombre',
        direccion:  map['direccion']  as String? ?? '',
      );
}



