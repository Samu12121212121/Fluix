/// Validador oficial de NIF/CIF/NIE españoles
/// Algoritmos según normativa de la AEAT
///
/// NIF: 8 dígitos + 1 letra (módulo 23)
/// CIF: 1 letra + 7 dígitos + 1 dígito/letra control
/// NIE: X/Y/Z + 7 dígitos + 1 letra (como NIF)

bool validarNIF(String nif) => ValidadorNifCif.validar(nif).valido;

class ValidadorNifCif {
  /// Tabla de letras para el algoritmo NIF (módulo 23)
  static const String _tablaNif = "TRWAGMYFPDXBNJZSQVHLCKE";

  /// Validar NIF: 8 dígitos + 1 letra
  /// Ejemplo: "12345678Z", "45678901K"
  static bool esNifValido(String? nif) {
    if (nif == null || nif.isEmpty) return false;

    // Limpiar: espacios, guiones, lowercase → uppercase
    final cleaned = nif
        .trim()
        .replaceAll(RegExp(r'[\s\-]'), '')
        .toUpperCase();

    // Validar formato: exactamente 8 dígitos + 1 letra
    if (!RegExp(r'^[0-9]{8}[A-Z]$').hasMatch(cleaned)) {
      return false;
    }

    // Validar dígito de control (módulo 23)
    try {
      final numero = int.parse(cleaned.substring(0, 8));
      final letraEsperada = _tablaNif[numero % 23];
      return cleaned[8] == letraEsperada;
    } catch (_) {
      return false;
    }
  }

  /// Validar CIF: [A-H,J,N,P-S,U,V,W] + 7 dígitos + [0-9,A-J]
  /// Ejemplo: "A12345678", "V98765432"
  static bool esCifValido(String? cif) {
    if (cif == null || cif.isEmpty) return false;

    final cleaned = cif
        .trim()
        .replaceAll(RegExp(r'[\s\-]'), '')
        .toUpperCase();

    // Validar formato: 1 letra + 7 dígitos + control alfanumérico
    if (!RegExp(r'^[ABCDEFGHJNPQRSUVW][0-9]{7}[0-9A-J]$').hasMatch(cleaned)) {
      return false;
    }

    final letraInicial = cleaned[0];
    final digitos = cleaned.substring(1, 8);
    final control = cleaned[8];

    int sumaPares = 0;
    int sumaImpares = 0;

    for (var i = 0; i < digitos.length; i++) {
      final n = int.parse(digitos[i]);
      final posicion = i + 1; // 1..7

      if (posicion.isEven) {
        sumaPares += n;
      } else {
        final doble = n * 2;
        sumaImpares += (doble ~/ 10) + (doble % 10);
      }
    }

    final sumaTotal = sumaPares + sumaImpares;
    final digitoControl = (10 - (sumaTotal % 10)) % 10;
    const letrasControl = 'JABCDEFGHI';
    final letraControl = letrasControl[digitoControl];

    // Tipos que exigen control numérico
    if ('ABEH'.contains(letraInicial)) {
      return control == digitoControl.toString();
    }

    // Tipos que exigen control alfabético
    if ('KNPQRSW'.contains(letraInicial)) {
      return control == letraControl;
    }

    // Tipos que aceptan cualquiera de los dos
    return control == digitoControl.toString() || control == letraControl;
  }

  /// Validar NIE: [X,Y,Z] + 7 dígitos + 1 letra
  /// Ejemplo: "X1234567L", "Y9876543M"
  static bool esNieValido(String? nie) {
    if (nie == null || nie.isEmpty) return false;

    final cleaned = nie
        .trim()
        .replaceAll(RegExp(r'[\s\-]'), '')
        .toUpperCase();

    // Validar formato: X/Y/Z + 7 dígitos + 1 letra
    if (!RegExp(r'^[XYZ][0-9]{7}[A-Z]$').hasMatch(cleaned)) {
      return false;
    }

    // Validar dígito de control (algoritmo NIF con sustitución inicial)
    try {
      // Reemplazar X→0, Y→1, Z→2 para aplicar módulo 23
      final nieNum = cleaned
          .replaceFirst('X', '0')
          .replaceFirst('Y', '1')
          .replaceFirst('Z', '2');

      final numero = int.parse(nieNum.substring(0, 8));
      final letraEsperada = _tablaNif[numero % 23];
      return cleaned[8] == letraEsperada;
    } catch (_) {
      return false;
    }
  }

  /// Detecta automáticamente el tipo y valida
  /// Retorna ValidacionNif con información completa
  static ValidacionNif validar(String? raw) {
    if (raw == null || raw.isEmpty) {
      return ValidacionNif(
        valido: false,
        tipo: 'vacío',
        razon: 'NIF/CIF/NIE es requerido',
      );
    }

    final cleaned = raw.trim();

    // Intentar como NIF
    if (esNifValido(cleaned)) {
      return ValidacionNif(
        valido: true,
        tipo: 'NIF',
        razon: 'NIF válido',
        nifNormalizado: cleaned.toUpperCase().replaceAll(RegExp(r'[\s\-]'), ''),
      );
    }

    // Intentar como CIF
    if (esCifValido(cleaned)) {
      return ValidacionNif(
        valido: true,
        tipo: 'CIF',
        razon: 'CIF válido',
        nifNormalizado: cleaned.toUpperCase().replaceAll(RegExp(r'[\s\-]'), ''),
      );
    }

    // Intentar como NIE
    if (esNieValido(cleaned)) {
      return ValidacionNif(
        valido: true,
        tipo: 'NIE',
        razon: 'NIE válido',
        nifNormalizado: cleaned.toUpperCase().replaceAll(RegExp(r'[\s\-]'), ''),
      );
    }

    // No válido
    return ValidacionNif(
      valido: false,
      tipo: 'desconocido',
      razon:
          'NIF/CIF/NIE inválido (formato o dígito control incorrecto). '
          'Formatos válidos: 12345678Z (NIF), A12345678 (CIF), X1234567L (NIE)',
    );
  }

  /// Limpia y normaliza NIF/CIF/NIE
  /// Retorna uppercase sin espacios ni guiones
  static String limpiar(String raw) {
    return raw.trim().replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
  }
}

/// Resultado de validación NIF/CIF/NIE
class ValidacionNif {
  /// ¿Es válido?
  final bool valido;

  /// Tipo detectado: 'NIF', 'CIF', 'NIE', 'vacío', 'desconocido'
  final String tipo;

  /// Mensaje descriptivo
  final String razon;

  /// NIF/CIF/NIE normalizado (sin espacios, mayúsculas)
  final String? nifNormalizado;

  ValidacionNif({
    required this.valido,
    required this.tipo,
    required this.razon,
    this.nifNormalizado,
  });

  @override
  String toString() => 'ValidacionNif(valido: $valido, tipo: $tipo, razon: $razon)';
}


