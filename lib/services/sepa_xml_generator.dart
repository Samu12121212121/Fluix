import '../domain/modelos/nomina.dart';
import '../domain/modelos/empresa_config.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SEPA XML GENERATOR — pain.001.001.03 (ISO 20022)
// Cuaderno 34-XML CaixaBank / Norma SEPA Credit Transfer
// ═══════════════════════════════════════════════════════════════════════════════

/// Datos del ordenante (empresa) necesarios para la remesa SEPA.
class DatosOrdenante {
  final String nif;
  final String razonSocial;
  final String direccion;
  final String ibanEmpresa;
  final String bicEmpresa;

  const DatosOrdenante({
    required this.nif,
    required this.razonSocial,
    required this.direccion,
    required this.ibanEmpresa,
    this.bicEmpresa = 'NOTPROVIDED',
  });

  /// Crea DatosOrdenante desde EmpresaConfig + IBAN/BIC adicionales.
  factory DatosOrdenante.fromConfig(
    EmpresaConfig config, {
    required String ibanEmpresa,
    String? bicEmpresa,
  }) => DatosOrdenante(
    nif: config.nifNormalizado,
    razonSocial: config.razonSocial,
    direccion: config.domicilioFiscal,
    ibanEmpresa: ibanEmpresa,
    bicEmpresa: bicEmpresa ?? 'NOTPROVIDED',
  );
}

/// Datos de un beneficiario (empleado) para una transferencia SEPA.
class DatosBeneficiario {
  final String nombre;
  final String nif;
  final String iban;
  final double importeNeto;
  final String nominaId;

  const DatosBeneficiario({
    required this.nombre,
    required this.nif,
    required this.iban,
    required this.importeNeto,
    required this.nominaId,
  });
}

class SepaXmlGenerator {
  SepaXmlGenerator._();

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDACIÓN IBAN COMPLETA (módulo 97 + CCC español)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Valida un IBAN español algorítmicamente. Devuelve null si válido,
  /// o mensaje de error específico.
  ///
  /// Algoritmo:
  ///  1. Limpiar espacios/guiones, convertir a mayúsculas
  ///  2. Longitud = 24 chars y empieza por "ES"
  ///  3. Mover primeros 4 chars al final: BBAN + "ES" + dígitos control
  ///  4. Convertir letras a números: A=10, B=11 ... Z=35
  ///  5. BigInt módulo 97 debe ser exactamente 1
  ///  6. Validar CCC interno (20 dígitos): Entidad(4)+Oficina(4)+DC(2)+Cuenta(10)
  static String? validarIBAN(String? iban) {
    if (iban == null || iban.trim().isEmpty) return 'IBAN requerido';

    // 1. Limpiar
    final clean = iban.replaceAll(' ', '').replaceAll('-', '').toUpperCase();

    // 2. Longitud y prefijo
    if (clean.length != 24) {
      return 'IBAN debe tener 24 caracteres (tiene ${clean.length})';
    }
    if (!clean.startsWith('ES')) {
      return 'IBAN debe empezar por ES (encontrado: ${clean.substring(0, 2)})';
    }
    if (!RegExp(r'^ES\d{22}$').hasMatch(clean)) {
      return 'IBAN contiene caracteres no numéricos después de ES';
    }

    // 3–5. Algoritmo módulo 97 (ISO 7064)
    final rearranged = clean.substring(4) + clean.substring(0, 4);
    final numeric = rearranged.split('').map((c) {
      final code = c.codeUnitAt(0);
      return code >= 65 ? (code - 55).toString() : c;
    }).join();

    final value = BigInt.parse(numeric);
    if (value % BigInt.from(97) != BigInt.one) {
      return 'Dígitos de control IBAN inválidos';
    }

    // 6. Validar CCC interno (20 dígitos tras ES + 2 dígitos de control IBAN)
    final ccc = clean.substring(4); // 20 dígitos: EEEE OOOO DC CCCCCCCCCC
    final errorCCC = validarCCC(ccc);
    if (errorCCC != null) return errorCCC;

    return null; // ✅ IBAN válido
  }

  /// Valida los dígitos de control internos del CCC español (20 dígitos).
  ///
  /// Estructura: Entidad(4) + Oficina(4) + DC1 + DC2 + Cuenta(10)
  ///
  /// DC1 = dígito de control de "00" + Entidad + Oficina
  /// DC2 = dígito de control de Cuenta
  ///
  /// Algoritmo:
  ///   Pesos: [1, 2, 4, 8, 5, 10, 9, 7, 3, 6]
  ///   Suma ponderada mod 11 → resto
  ///   DC = 11 - resto (si 10 → fallo, si 11 → 0)
  static String? validarCCC(String ccc) {
    if (ccc.length != 20) return 'CCC debe tener 20 dígitos';
    if (!RegExp(r'^\d{20}$').hasMatch(ccc)) return 'CCC contiene caracteres no numéricos';

    final entidad = ccc.substring(0, 4);
    final oficina = ccc.substring(4, 8);
    final dc1 = int.parse(ccc[8]);
    final dc2 = int.parse(ccc[9]);
    final cuenta = ccc.substring(10, 20);

    // Calcular DC1: pesos sobre "00" + entidad + oficina
    final dc1Calculado = _calcularDigitoControl('00$entidad$oficina');
    if (dc1Calculado == null) {
      return 'Combinación entidad/oficina inválida ($entidad/$oficina)';
    }
    if (dc1 != dc1Calculado) {
      return 'Dígito de control 1 del CCC incorrecto '
          '(esperado $dc1Calculado, encontrado $dc1)';
    }

    // Calcular DC2: pesos sobre cuenta
    final dc2Calculado = _calcularDigitoControl(cuenta);
    if (dc2Calculado == null) {
      return 'Número de cuenta inválido ($cuenta)';
    }
    if (dc2 != dc2Calculado) {
      return 'Dígito de control 2 del CCC incorrecto '
          '(esperado $dc2Calculado, encontrado $dc2)';
    }

    return null; // ✅ CCC válido
  }

  /// Calcula un dígito de control CCC sobre 10 dígitos.
  /// Pesos: [1, 2, 4, 8, 5, 10, 9, 7, 3, 6]
  /// Devuelve null si no es calculable (resto = 10).
  static int? _calcularDigitoControl(String digitos) {
    if (digitos.length != 10) return null;
    const pesos = [1, 2, 4, 8, 5, 10, 9, 7, 3, 6];
    int suma = 0;
    for (int i = 0; i < 10; i++) {
      suma += int.parse(digitos[i]) * pesos[i];
    }
    final resto = suma % 11;
    final dc = 11 - resto;
    if (dc == 11) return 0;
    if (dc == 10) return null; // No existe DC válido
    return dc;
  }

  /// Limpia y normaliza un IBAN (mayúsculas, sin espacios).
  static String limpiarIBAN(String iban) =>
      iban.replaceAll(' ', '').replaceAll('-', '').toUpperCase();

  /// Formatea un IBAN con espacios cada 4 caracteres.
  static String formatearIBAN(String iban) {
    final clean = limpiarIBAN(iban);
    final buffer = StringBuffer();
    for (var i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDACIÓN DE LOTE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Valida un lote de nóminas antes de generar el XML SEPA.
  /// Devuelve lista de errores (vacía si todo OK).
  static List<String> validarLote({
    required List<Nomina> nominas,
    required DatosOrdenante ordenante,
    required Map<String, DatosNominaEmpleado> datosEmpleados,
    required DateTime fechaEjecucion,
  }) {
    final errores = <String>[];

    // 1. Empresa: IBAN válido
    final errIban = validarIBAN(ordenante.ibanEmpresa);
    if (errIban != null) errores.add('IBAN empresa: $errIban');
    if (ordenante.nif.isEmpty) errores.add('NIF empresa requerido');
    if (ordenante.razonSocial.isEmpty) errores.add('Razón social empresa requerida');

    // 2. Nóminas en estado aprobada
    for (final n in nominas) {
      if (n.estado != EstadoNomina.aprobada) {
        errores.add('${n.empleadoNombre}: nómina no está aprobada (${n.estado.etiqueta})');
      }
    }

    // 3. Importes > 0
    for (final n in nominas) {
      if (n.salarioNeto <= 0) {
        errores.add('${n.empleadoNombre}: importe neto ≤ 0');
      }
    }

    // 4. IBAN empleados
    final empleadosVistos = <String>{};
    for (final n in nominas) {
      final datos = datosEmpleados[n.empleadoId];
      final ibanEmp = datos?.cuentaBancaria;

      if (ibanEmp == null || ibanEmp.trim().isEmpty) {
        errores.add('${n.empleadoNombre}: sin IBAN configurado');
      } else {
        final errIbanEmp = validarIBAN(ibanEmp);
        if (errIbanEmp != null) {
          errores.add('${n.empleadoNombre}: $errIbanEmp');
        }
      }

      // 5. Duplicados
      final clave = '${n.empleadoId}_${n.mes}_${n.anio}';
      if (empleadosVistos.contains(clave)) {
        errores.add('${n.empleadoNombre}: duplicado en mes ${n.mes}/${n.anio}');
      }
      empleadosVistos.add(clave);
    }

    // 6. Fecha ejecución: día hábil (lunes-viernes, no festivo)
    if (fechaEjecucion.weekday == DateTime.saturday ||
        fechaEjecucion.weekday == DateTime.sunday) {
      errores.add('Fecha de ejecución cae en fin de semana');
    }
    if (_esFestivoNacional(fechaEjecucion)) {
      errores.add('Fecha de ejecución es festivo nacional');
    }

    return errores;
  }

  /// Sugiere el próximo día hábil a partir de la fecha dada.
  static DateTime sugerirDiaHabil(DateTime fecha) {
    var d = fecha;
    while (d.weekday == DateTime.saturday ||
           d.weekday == DateTime.sunday ||
           _esFestivoNacional(d)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN XML — pain.001.001.03
  // ═══════════════════════════════════════════════════════════════════════════

  /// Genera el XML SEPA pain.001.001.03 completo.
  ///
  /// [nominas]: lista de nóminas aprobadas del mes.
  /// [ordenante]: datos de la empresa ordenante.
  /// [datosEmpleados]: map empleadoId → DatosNominaEmpleado (para IBAN).
  /// [fechaEjecucion]: fecha de pago solicitada.
  /// [msgId]: identificador único del fichero (si null, se genera).
  static String generarXML({
    required List<Nomina> nominas,
    required DatosOrdenante ordenante,
    required Map<String, DatosNominaEmpleado> datosEmpleados,
    required DateTime fechaEjecucion,
    String? msgId,
  }) {
    final ahora = DateTime.now();
    final nif = ordenante.nif.replaceAll('-', '').replaceAll(' ', '');
    final id = msgId ??
        '${nif}${_f(ahora.year, 4)}${_f(ahora.month, 2)}${_f(ahora.day, 2)}'
        '${_f(ahora.hour, 2)}${_f(ahora.minute, 2)}${_f(ahora.second, 2)}';
    // Asegurar max 35 chars
    final msgIdFinal = id.length > 35 ? id.substring(0, 35) : id;

    final nbOfTxs = nominas.length;
    final ctrlSum = nominas.fold(0.0, (s, n) => s + n.salarioNeto);
    final ctrlSumStr = ctrlSum.toStringAsFixed(2);

    // Mes/año del lote (se toma de la primera nómina)
    final mes = nominas.first.mes;
    final anio = nominas.first.anio;

    final pmtInfId = '${nif}${_f(anio, 4)}${_f(mes, 2)}NOMINAS';
    final pmtInfIdFinal = pmtInfId.length > 35 ? pmtInfId.substring(0, 35) : pmtInfId;

    final fechaExStr = '${_f(fechaEjecucion.year, 4)}-${_f(fechaEjecucion.month, 2)}-${_f(fechaEjecucion.day, 2)}';
    final creDtTm = '${_f(ahora.year, 4)}-${_f(ahora.month, 2)}-${_f(ahora.day, 2)}'
        'T${_f(ahora.hour, 2)}:${_f(ahora.minute, 2)}:${_f(ahora.second, 2)}';

    final ibanEmpresa = limpiarIBAN(ordenante.ibanEmpresa);
    final bicEmpresa = ordenante.bicEmpresa.isNotEmpty
        ? ordenante.bicEmpresa : 'NOTPROVIDED';

    // Generar cada CdtTrfTxInf
    final transferencias = StringBuffer();
    for (final n in nominas) {
      final datos = datosEmpleados[n.empleadoId];
      final ibanEmp = limpiarIBAN(datos?.cuentaBancaria ?? '');
      final nifEmp = (n.empleadoNif ?? datos?.nif ?? '').replaceAll('-', '').replaceAll(' ', '');

      final instrId = '${nif}${_f(mes, 2)}$nifEmp';
      final instrIdFinal = instrId.length > 35 ? instrId.substring(0, 35) : instrId;

      final endToEndId = 'NOMINA-${_f(anio, 4)}-${_f(mes, 2)}-$nifEmp';
      final endToEndIdFinal = endToEndId.length > 35 ? endToEndId.substring(0, 35) : endToEndId;

      final nombreEmp = _truncar(_xmlEscape(n.empleadoNombre), 70);
      final importe = n.salarioNeto.toStringAsFixed(2);

      final concepto = _truncar(
        'NOMINA ${_f(mes, 2)}/${_f(anio, 4)} - ${_sinAcentos(ordenante.razonSocial)}',
        140,
      );

      transferencias.writeln('''      <CdtTrfTxInf>
        <PmtId>
          <InstrId>$instrIdFinal</InstrId>
          <EndToEndId>$endToEndIdFinal</EndToEndId>
        </PmtId>
        <Amt>
          <InstdAmt Ccy="EUR">$importe</InstdAmt>
        </Amt>
        <CdtrAgt>
          <FinInstnId>
            <BIC>NOTPROVIDED</BIC>
          </FinInstnId>
        </CdtrAgt>
        <Cdtr>
          <Nm>$nombreEmp</Nm>
        </Cdtr>
        <CdtrAcct>
          <Id>
            <IBAN>$ibanEmp</IBAN>
          </Id>
        </CdtrAcct>
        <RmtInf>
          <Ustrd>$concepto</Ustrd>
        </RmtInf>
      </CdtTrfTxInf>''');
    }

    final razonSocial = _truncar(_xmlEscape(ordenante.razonSocial), 70);
    final direccion = _truncar(_xmlEscape(ordenante.direccion), 70);

    return '''<?xml version="1.0" encoding="UTF-8"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <CstmrCdtTrfInitn>
    <GrpHdr>
      <MsgId>$msgIdFinal</MsgId>
      <CreDtTm>$creDtTm</CreDtTm>
      <NbOfTxs>$nbOfTxs</NbOfTxs>
      <CtrlSum>$ctrlSumStr</CtrlSum>
      <InitgPty>
        <Nm>$razonSocial</Nm>
        <Id>
          <OrgId>
            <Othr>
              <Id>$nif</Id>
            </Othr>
          </OrgId>
        </Id>
      </InitgPty>
    </GrpHdr>
    <PmtInf>
      <PmtInfId>$pmtInfIdFinal</PmtInfId>
      <PmtMtd>TRF</PmtMtd>
      <BtchBookg>true</BtchBookg>
      <NbOfTxs>$nbOfTxs</NbOfTxs>
      <CtrlSum>$ctrlSumStr</CtrlSum>
      <PmtTpInf>
        <InstrPrty>NORM</InstrPrty>
        <SvcLvl>
          <Cd>SEPA</Cd>
        </SvcLvl>
        <CtgyPurp>
          <Cd>SALA</Cd>
        </CtgyPurp>
      </PmtTpInf>
      <ReqdExctnDt>$fechaExStr</ReqdExctnDt>
      <Dbtr>
        <Nm>$razonSocial</Nm>
        <PstlAdr>
          <Ctry>ES</Ctry>
          <AdrLine>$direccion</AdrLine>
        </PstlAdr>
        <Id>
          <OrgId>
            <Othr>
              <Id>$nif</Id>
            </Othr>
          </OrgId>
        </Id>
      </Dbtr>
      <DbtrAcct>
        <Id>
          <IBAN>$ibanEmpresa</IBAN>
        </Id>
      </DbtrAcct>
      <DbtrAgt>
        <FinInstnId>
          <BIC>$bicEmpresa</BIC>
        </FinInstnId>
      </DbtrAgt>
      <ChrgBr>SLEV</ChrgBr>
$transferencias
    </PmtInf>
  </CstmrCdtTrfInitn>
</Document>''';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILIDADES PRIVADAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Pad a la izquierda con ceros.
  static String _f(int value, int width) =>
      value.toString().padLeft(width, '0');

  /// Truncar string a maxLen.
  static String _truncar(String s, int maxLen) =>
      s.length > maxLen ? s.substring(0, maxLen) : s;

  /// Escape entidades XML.
  static String _xmlEscape(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// Eliminar acentos y caracteres especiales (para concepto SEPA).
  static String _sinAcentos(String input) {
    const _from = 'ÁÉÍÓÚÜÑáéíóúüñ';
    const _to   = 'AEIOUUNaeiouun';
    var result = input;
    for (var i = 0; i < _from.length; i++) {
      result = result.replaceAll(_from[i], _to[i]);
    }
    return result.toUpperCase();
  }

  /// Festivos nacionales España (fijos + Semana Santa calculable).
  static bool _esFestivoNacional(DateTime fecha) {
    final md = fecha.month * 100 + fecha.day;
    // Festivos fijos nacionales
    const fijos = {
      101,  // Año Nuevo
      106,  // Reyes
      501,  // Día del Trabajador
      815,  // Asunción
      1012, // Fiesta Nacional
      1101, // Todos los Santos
      1206, // Constitución
      1208, // Inmaculada
      1225, // Navidad
    };
    if (fijos.contains(md)) return true;

    // Semana Santa (Jueves y Viernes Santo) — cálculo algorítmico
    final pascua = _calcularPascua(fecha.year);
    final juevesSanto = pascua.subtract(const Duration(days: 3));
    final viernesSanto = pascua.subtract(const Duration(days: 2));
    if (_mismaFecha(fecha, juevesSanto) || _mismaFecha(fecha, viernesSanto)) {
      return true;
    }

    return false;
  }

  /// Algoritmo de Gauss/Anonymous para calcular el Domingo de Pascua.
  static DateTime _calcularPascua(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final mes = (h + l - 7 * m + 114) ~/ 31;
    final dia = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, mes, dia);
  }

  static bool _mismaFecha(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}



