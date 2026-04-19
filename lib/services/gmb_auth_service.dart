  final String locationId;
  final String nombre;
      final fichas = fichasRaw
          .map((f) => FichaNegocio.fromMap(f as Map<String, dynamic>))
          .toList();
      return (fichas: fichas, error: null);
    } on FirebaseFunctionsException catch (e) {
      final callable =
          _functions.httpsCallable('obtenerFichasNegocio');
      final result = await callable.call({'empresaId': empresaId});
      final fichasRaw =
          (result.data['fichas'] as List<dynamic>?) ?? [];
      final fichas = fichasRaw
          .map((f) => FichaNegocio.fromMap(f as Map<String, dynamic>))
          .toList();
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
      String empresaId) async {
        'empresaId': empresaId,
  }
}

// ── Modelo de ficha de negocio ────────────────────────────────────────────────

class FichaNegocio {
  final String accountId;
        direccion: map['direccion'] as String? ?? '',
      );
    if (error.contains('OAuth') || error.contains('credentials')) {
    } on FirebaseFunctionsException catch (e) {
      final callable =
          _functions.httpsCallable('obtenerFichasNegocio');
      final result = await callable.call({'empresaId': empresaId});
      final fichasRaw =
          (result.data['fichas'] as List<dynamic>?) ?? [];
      final fichas = fichasRaw
      return 'Tu ficha de Google Business está suspendida. Contáctate con Google para resolverlo.';
    if (error.contains('access_denied') || error.contains('denied')) {
      return 'Has denegado el permiso. Vuelve a intentarlo y acepta los permisos de Google Business.';

  String _mapearErrorGmb(String error) {
    if (error.contains('business.manage') || error.contains('scope')) {
      await _storage.write(key: _keyConectado, value: 'true');
      await _storage.write(key: _keyNombreFicha, value: ficha.nombre);
      await _storage.write(
  Future<String?> guardarFicha(
      _ultimaSync = null;
      _conectado = true;
  factory GmbAuthService() => _i;
  GmbAuthService._();

  static const _keyConectado = 'gmb_conectado';
  static const _keyNombreFicha = 'gmb_nombre_ficha';
  static const _keyDireccionFicha = 'gmb_direccion_ficha';
  static const _keyUltimaSync = 'gmb_ultima_sync';
  final _db = FirebaseFirestore.instance;
  final _storage = const FlutterSecureStorage();
  final _db = FirebaseFirestore.instance;
        accountId: map['accountId'] as String? ?? '',

class FichaNegocio {
      _gmbScope,
    ],
    return 'Error al conectar con Google Business: $error';
    required this.direccion,
  });
        'direccionFicha': ficha.direccion,
  factory FichaNegocio.fromMap(Map<String, dynamic> map) {
    return FichaNegocio(
      accountId: map['accountId'] as String? ?? '',
      locationId: map['locationId'] as String? ?? '',
  // ── Estado observable ─────────────────────────────────────────────────────

  // Scope específico de Google Business Profile
  static const _gmbScope =
  bool get conectado => _conectado;
  String? get nombreFicha => _nombreFicha;
      return 'Necesitas tener una ficha de Google Business para usar esta función.';
        _conectado = true;
        _nombreFicha = snap.data()?['nombre_ficha'] as String? ?? '';
        _direccionFicha = snap.data()?['direccion_ficha'] as String? ?? '';
        // Persistir localmente para acceso sin red
        await _storage.write(key: _keyConectado, value: 'true');
        _ultimaSync = tsSync?.toDate();
/// No requiere Cloud Functions — escribe en Firestore desde el cliente.
      });
/// el scope adicional `business.manage`.

  static final GmbAuthService _i = GmbAuthService._();
  static const _keyConectado        = 'gmb_conectado';
  static const _keyNombreFicha      = 'gmb_nombre_ficha';
        _conectado = localConectado == 'true';
        if (_conectado) {
          _nombreFicha = await _storage.read(key: _keyNombreFicha);
          _direccionFicha = await _storage.read(key: _keyDireccionFicha);
          final syncStr = await _storage.read(key: _keyUltimaSync);
          if (syncStr != null) _ultimaSync = DateTime.tryParse(syncStr);
        }
      }
    } catch (_) {}
        if (_conectado) {
  /// Inicia el flujo OAuth2 simplificado:
  /// 1. Intenta login silencioso (si ya tiene sesión)
  /// 2. Si no, muestra pantalla de Google
  /// 3. Obtiene serverAuthCode
  /// 4. Llama a Cloud Function para guardar tokens en Secret Manager
  /// Devuelve `null` si va bien, o un mensaje de error.
        }
      }
    } catch (_) {}
      // Intentar login silencioso primero
  }

      // Intentar login silencioso primero
        return 'No se pudo obtener el código de autorización. '
            'Asegúrate de que el Client ID está configurado correctamente.';
      // Enviar a Cloud Function para intercambiar y guardar en Secret Manager
      final callable =
          _functions.httpsCallable('storeGmbToken');
            key: _keyNombreFicha, value: _nombreFicha ?? '');
        await _storage.write(
            key: _keyDireccionFicha, value: _direccionFicha ?? '');
        'empresaId': empresaId,
        'serverAuthCode': serverAuthCode,
      });
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
      'https://www.googleapis.com/auth/business.manage';
    scopes: [
      'email',
        _nombreFicha   = snap.data()?['nombre_ficha']    as String? ?? '';
        _direccionFicha= snap.data()?['direccion_ficha'] as String? ?? '';
    ],
  String? _direccionFicha;
  DateTime? _ultimaSync;
  bool _cargando = false;
  String? _error;

      return 'Error inesperado: $e';
  /// Obtiene la lista de fichas de negocio del usuario.
  bool get cargando => _cargando;
  String? get error => _error;

  /// Obtiene la lista de fichas de negocio del usuario.
    try {
      // Primero, comprobar Firestore (fuente de verdad)
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('gmb_config')
        _ultimaSync = tsSync?.toDate();
  }
      await callable.call({
  /// Inicia el flujo OAuth2:
  ///   1. Sign-in con Google (pide permiso business.manage)
  ///   2. Obtiene accessToken
  ///   3. Escribe estado en Firestore
  ///   4. Devuelve null si va bien, o mensaje de error.
  Future<String?> conectar(String empresaId) async {

  // ── Estado observable ─────────────────────────────────────────────────────

  // Scope específico de Google Business Profile
  static const _gmbScope =
      // 1. Login silencioso primero, luego interactivo
        await _storage.write(
      final fichas = fichasRaw
        notifyListeners();
        return 'Inicio de sesión cancelado.';
      }

      // 2. Obtener accessToken
      final auth        = await account.authentication;

        return 'No se pudo obtener el token de acceso de Google.\n'
            'Asegúrate de aceptar todos los permisos solicitados.';
      }

      // 3. Guardar token en secure storage
          .set({
        'conectado':    true,
        'email_google': account.email,
        'nombre_google': account.displayName ?? '',
        'conectado_en': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _conectado = true;

    } on FirebaseFunctionsException catch (e) {
      _cargando = false;
      _error = e.message;
      notifyListeners();
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

    } on FirebaseFunctionsException catch (e) {
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
      _error = e.message;
      notifyListeners();
      return 'Error inesperado: $e';
    } catch (e) {
  /// Obtiene la lista de fichas de negocio del usuario.
    }
  }

  /// Obtiene la lista de fichas de negocio del usuario.
    required this.direccion,
  });

  factory FichaNegocio.fromMap(Map<String, dynamic> map) => FichaNegocio(
        accountId: map['accountId'] as String? ?? '',
        locationId: map['locationId'] as String? ?? '',
        nombre: map['nombre'] as String? ?? 'Sin nombre',
        direccion: map['direccion'] as String? ?? '',
      );
}




