import 'package:http/http.dart' as http;

/// Servicio de validación de NIF/CIF/NIE española + consulta VIES (UE)
///
/// Cubre:
///   - DNI: 8 dígitos + letra (módulo 23)
///   - NIE: X/Y/Z + 7 dígitos + letra (módulo 23 tras sustituir prefijo)
///   - CIF: letra + código 2 dígitos + 6 dígitos + carácter de control
///   - NIF-IVA comunitario (VIES) para operaciones intracomunitarias
class ValidacionFiscalService {
  // ───────────────────────────── CONSTANTES ─────────────────────────────────

  /// Letras válidas para DNI/NIE (tabla módulo 23)
  static const _letrasDni = 'TRWAGMYFPDXBNJZSQVHLCKE';

  /// Sustitución prefijo NIE: X→0, Y→1, Z→2
  static const _prefijosNie = {'X': '0', 'Y': '1', 'Z': '2'};

  /// Letras válidas como primer carácter de CIF
  static const _letrasCif = 'ABCDEFGHJKLMNPQRSUVW';

  /// CIFs con control por LETRA (no dígito)
  static const _cifLetraControl = 'PQRSW';

  /// CIFs con control por DÍGITO
  static const _cifDigitoControl = 'ABEH';

  /// Tabla de letras control CIF
  static const _letrasCifControl = 'JABCDEFGHI';

  // ───────────────────────────── VALIDACIÓN NIF ─────────────────────────────

  /// Resultado detallado de una validación fiscal
  static ValidacionFiscalResult validarNif(String nif) {
    if (nif.isEmpty) {
      return ValidacionFiscalResult.invalido(nif, 'El NIF/CIF está vacío');
    }

    final clean = nif.trim().toUpperCase().replaceAll(RegExp(r'[\s\-.]+'), '');

    if (clean.isEmpty) {
      return ValidacionFiscalResult.invalido(nif, 'El NIF/CIF solo contiene espacios o separadores');
    }

    final firstChar = clean[0];

    // ── CIF ──────────────────────────────────────────────────────────────────
    if (_letrasCif.contains(firstChar)) {
      return _validarCif(clean);
    }

    // ── NIE (extranjeros)────────────────────────────────────────────────────
    if (_prefijosNie.containsKey(firstChar)) {
      return _validarNie(clean);
    }

    // ── DNI ──────────────────────────────────────────────────────────────────
    if (RegExp(r'^\d').hasMatch(clean)) {
      return _validarDni(clean);
    }

    return ValidacionFiscalResult.invalido(nif, 'Formato no reconocido');
  }

  // ── VALIDACIÓN DNI ────────────────────────────────────────────────────────

  static ValidacionFiscalResult _validarDni(String clean) {
    if (!RegExp(r'^\d{8}[A-Z]$').hasMatch(clean)) {
      return ValidacionFiscalResult.invalido(
        clean,
        'DNI inválido: debe ser 8 dígitos seguidos de 1 letra (ej: 12345678A)',
      );
    }

    final numero = int.parse(clean.substring(0, 8));
    final letraProporcionada = clean[8];
    final letraCalculada = _letrasDni[numero % 23];

    if (letraProporcionada != letraCalculada) {
      return ValidacionFiscalResult.invalido(
        clean,
        'DNI con letra incorrecta (letra válida: $letraCalculada)',
      );
    }

    return ValidacionFiscalResult.valido(clean, TipoNif.dni);
  }

  // ── VALIDACIÓN NIE ────────────────────────────────────────────────────────

  static ValidacionFiscalResult _validarNie(String clean) {
    if (!RegExp(r'^[XYZ]\d{7}[A-Z]$').hasMatch(clean)) {
      return ValidacionFiscalResult.invalido(
        clean,
        'NIE inválido: formato X/Y/Z + 7 dígitos + letra (ej: X1234567A)',
      );
    }

    final prefijo = _prefijosNie[clean[0]]!;
    final nifEquivalente = prefijo + clean.substring(1, 8);
    final numero = int.parse(nifEquivalente);
    final letraProporcionada = clean[8];
    final letraCalculada = _letrasDni[numero % 23];

    if (letraProporcionada != letraCalculada) {
      return ValidacionFiscalResult.invalido(
        clean,
        'NIE con letra incorrecta (letra válida: $letraCalculada)',
      );
    }

    return ValidacionFiscalResult.valido(clean, TipoNif.nie);
  }

  // ── VALIDACIÓN CIF ────────────────────────────────────────────────────────

  static ValidacionFiscalResult _validarCif(String clean) {
    if (!RegExp(r'^[A-Z]\d{7}[0-9A-J]$').hasMatch(clean)) {
      return ValidacionFiscalResult.invalido(
        clean,
        'CIF inválido: letra + 7 dígitos + carácter control (ej: B12345678)',
      );
    }

    final letra = clean[0];
    final digitos = clean.substring(1, 8);
    final control = clean[8];

    // Suma pares (posiciones 2,4,6 del CIF — índice 1,3,5 en digitos)
    int sumaPares = 0;
    for (int i = 1; i < 7; i += 2) {
      sumaPares += int.parse(digitos[i]);
    }

    // Suma impares (posiciones 1,3,5,7 — índice 0,2,4,6 en digitos)
    // Cada dígito impar se multiplica x2 y se suman sus cifras si ≥ 10
    int sumaImpares = 0;
    for (int i = 0; i < 7; i += 2) {
      final prod = int.parse(digitos[i]) * 2;
      sumaImpares += prod < 10 ? prod : (prod ~/ 10) + (prod % 10);
    }

    final suma = sumaPares + sumaImpares;
    final unidades = suma % 10;
    final digitoControl = unidades == 0 ? 0 : 10 - unidades;
    final letraControl = _letrasCifControl[digitoControl];

    // Determinar si el control es letra o dígito
    final bool soloLetra   = _cifLetraControl.contains(letra);
    final bool soloDigito  = _cifDigitoControl.contains(letra);

    if (soloLetra) {
      if (control != letraControl) {
        return ValidacionFiscalResult.invalido(
          clean,
          'CIF con carácter de control incorrecto (carácter válido: $letraControl)',
        );
      }
    } else if (soloDigito) {
      if (control != digitoControl.toString()) {
        return ValidacionFiscalResult.invalido(
          clean,
          'CIF con dígito de control incorrecto (dígito válido: $digitoControl)',
        );
      }
    } else {
      // Acepta tanto letra como dígito
      if (control != letraControl && control != digitoControl.toString()) {
        return ValidacionFiscalResult.invalido(
          clean,
          'CIF con carácter de control incorrecto '
          '(válidos: $letraControl o $digitoControl)',
        );
      }
    }

    return ValidacionFiscalResult.valido(clean, TipoNif.cif);
  }

  // ── VALIDACIÓN NIF-IVA COMUNITARIO (VIES) ─────────────────────────────────

  /// Comprueba si un NIF-IVA europeo es válido consultando el servicio VIES
  /// de la Comisión Europea.
  ///
  /// El [nifIva] debe incluir el prefijo del país (ej: "ES12345678A", "DE123456789").
  /// Retorna [ViesResult] con el estado y los datos del operador si está registrado.
  ///
  /// ⚠️ Requiere conexión a internet. Puede fallar si VIES está en mantenimiento.
  static Future<ViesResult> validarVies(String nifIva) async {
    final clean = nifIva.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
    if (clean.length < 4) {
      return ViesResult(
        nifIva: clean,
        valido: false,
        error: 'El NIF-IVA es demasiado corto',
      );
    }

    final countryCode = clean.substring(0, 2);
    final vatNumber   = clean.substring(2);

    try {
      // VIES REST API (JSON) — reemplaza el SOAP legacy
      final uri = Uri.parse(
        'https://ec.europa.eu/taxation_customs/vies/rest-api/ms/$countryCode/vat/$vatNumber',
      );

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return ViesResult(
          nifIva: clean,
          valido: false,
          error: 'VIES respondió con código ${response.statusCode}',
        );
      }

      // Parse manual sin dependencias adicionales
      final body = response.body;
      final isValid   = body.contains('"isValid":true');
      final name      = _extraerCampoJson(body, 'name');
      final address   = _extraerCampoJson(body, 'address');

      return ViesResult(
        nifIva: clean,
        valido: isValid,
        nombreOperador: name,
        direccionOperador: address,
      );
    } on Exception catch (e) {
      return ViesResult(
        nifIva: clean,
        valido: false,
        error: 'No se pudo conectar con VIES: $e',
        serviceUnavailable: true,
      );
    }
  }

  static String? _extraerCampoJson(String body, String campo) {
    final regex = RegExp('"$campo":"([^"]*)"');
    final match = regex.firstMatch(body);
    return match?.group(1);
  }

  // ── VALIDACIÓN RÁPIDA DE FORMATO (sin algoritmo) ─────────────────────────

  /// Devuelve `true` si el NIF/CIF tiene formato válido y el algoritmo es correcto.
  static bool esValido(String nif) => validarNif(nif).esValido;

  /// Detecta el tipo de documento (DNI / NIE / CIF) sin validar el dígito.
  static TipoNif? detectarTipo(String nif) {
    final clean = nif.trim().toUpperCase();
    if (clean.isEmpty) return null;
    if (_prefijosNie.containsKey(clean[0])) return TipoNif.nie;
    if (_letrasCif.contains(clean[0]))      return TipoNif.cif;
    if (RegExp(r'^\d').hasMatch(clean))     return TipoNif.dni;
    return null;
  }
}

// ── MODELOS DE RESULTADO ──────────────────────────────────────────────────────

enum TipoNif { dni, nie, cif }

extension TipoNifExt on TipoNif {
  String get etiqueta {
    switch (this) {
      case TipoNif.dni: return 'DNI';
      case TipoNif.nie: return 'NIE';
      case TipoNif.cif: return 'CIF';
    }
  }
}

class ValidacionFiscalResult {
  final String nif;
  final bool esValido;
  final TipoNif? tipo;
  final String? error;

  const ValidacionFiscalResult._({
    required this.nif,
    required this.esValido,
    this.tipo,
    this.error,
  });

  factory ValidacionFiscalResult.valido(String nif, TipoNif tipo) =>
      ValidacionFiscalResult._(nif: nif, esValido: true, tipo: tipo);

  factory ValidacionFiscalResult.invalido(String nif, String error) =>
      ValidacionFiscalResult._(nif: nif, esValido: false, error: error);

  @override
  String toString() => esValido
      ? 'ValidacionFiscalResult(${tipo?.etiqueta}: $nif — VÁLIDO)'
      : 'ValidacionFiscalResult($nif — INVÁLIDO: $error)';
}

class ViesResult {
  final String nifIva;
  final bool valido;
  final String? nombreOperador;
  final String? direccionOperador;
  final String? error;
  final bool serviceUnavailable;

  const ViesResult({
    required this.nifIva,
    required this.valido,
    this.nombreOperador,
    this.direccionOperador,
    this.error,
    this.serviceUnavailable = false,
  });

  @override
  String toString() => valido
      ? 'ViesResult($nifIva — VÁLIDO | $nombreOperador)'
      : 'ViesResult($nifIva — INVÁLIDO: $error)';
}


