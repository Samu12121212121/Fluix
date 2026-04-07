import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/modelo190.dart';
import '../domain/modelos/modelo111.dart';
import '../domain/modelos/nomina.dart';
import '../domain/modelos/empresa_config.dart';
import '../core/utils/validador_nif_cif.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO 190 SERVICE — Resumen anual retenciones IRPF
// Orden HAC/1431/2025 · DISENOS_LOGICOS_190_2025.pdf
// ═══════════════════════════════════════════════════════════════════════════════

class Modelo190Service {
  static final Modelo190Service _i = Modelo190Service._();
  factory Modelo190Service() => _i;
  Modelo190Service._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('modelos190');

  CollectionReference<Map<String, dynamic>> _nominas(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('nominas');

  CollectionReference<Map<String, dynamic>> _modelos111(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('modelos111');

  // ═══════════════════════════════════════════════════════════════════════════
  // TABLA DE PROVINCIAS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Map<String, String> _provincias = {
    'alava': '01', 'albacete': '02', 'alicante': '03', 'almeria': '04',
    'avila': '05', 'badajoz': '06', 'baleares': '07', 'barcelona': '08',
    'burgos': '09', 'caceres': '10', 'cadiz': '11', 'castellon': '12',
    'ciudad real': '13', 'ciudadreal': '13', 'cordoba': '14', 'coruña': '15',
    'cuenca': '16', 'gerona': '17', 'girona': '17', 'granada': '18',
    'guadalajara': '19', 'guipuzcoa': '20', 'huelva': '21', 'huesca': '22',
    'jaen': '23', 'leon': '24', 'lerida': '25', 'lleida': '25',
    'lugo': '27', 'madrid': '28', 'malaga': '29', 'murcia': '30',
    'navarra': '31', 'orense': '32', 'ourense': '32', 'asturias': '33',
    'palencia': '34', 'las palmas': '35', 'pontevedra': '36', 'salamanca': '37',
    'santa cruz de tenerife': '38', 'tenerife': '38', 'cantabria': '39',
    'segovia': '40', 'sevilla': '41', 'soria': '42', 'tarragona': '43',
    'teruel': '44', 'toledo': '45', 'valencia': '46', 'valladolid': '47',
    'vizcaya': '48', 'zamora': '49', 'zaragoza': '50',
    'ceuta': '51', 'melilla': '52',
  };

  static String codigoProvincia(String? provincia) {
    if (provincia == null || provincia.isEmpty) return '19'; // default Guadalajara
    final key = normalizarTexto(provincia).toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), '').trim();
    return _provincias[key] ?? '19';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NORMALIZACIÓN DE TEXTO (mayúsculas, sin acentos, sin ñ)
  // ═══════════════════════════════════════════════════════════════════════════

  static String normalizarTexto(String input) {
    const map = {
      'á': 'A', 'à': 'A', 'ä': 'A', 'â': 'A',
      'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A',
      'é': 'E', 'è': 'E', 'ë': 'E', 'ê': 'E',
      'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
      'í': 'I', 'ì': 'I', 'ï': 'I', 'î': 'I',
      'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
      'ó': 'O', 'ò': 'O', 'ö': 'O', 'ô': 'O',
      'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O',
      'ú': 'U', 'ù': 'U', 'ü': 'U', 'û': 'U',
      'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
      'ñ': 'N', 'Ñ': 'N', 'ç': 'C', 'Ç': 'C',
    };
    final sb = StringBuffer();
    for (final rune in input.runes) {
      final c = String.fromCharCode(rune);
      sb.write(map[c] ?? c);
    }
    // Solo A-Z, 0-9, espacios, guiones
    return sb.toString().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9 \-]'), '');
  }

  static String normalizarNif(String nif) {
    final limpio = nif.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return limpio.length <= 9 ? limpio : limpio.substring(0, 9);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FORMATEO DE IMPORTES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Separa un importe en parte entera y decimal.
  /// [enteraLen] y [decimalLen] son la longitud de cada campo.
  static ({String entera, String decimal}) formatearImporte(
    double valor,
    int enteraLen,
    int decimalLen,
  ) {
    final abs = valor.abs();
    final centimos = (abs * 100).round();
    final parteDecimal = centimos % 100;
    final parteEntera = centimos ~/ 100;
    return (
      entera: parteEntera.toString().padLeft(enteraLen, '0'),
      decimal: parteDecimal.toString().padLeft(decimalLen, '0'),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO AUTOMÁTICO DESDE NÓMINAS PAGADAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula el Modelo 190 para un ejercicio a partir de las nóminas pagadas.
  Future<Modelo190> calcularDesdeNominas({
    required String empresaId,
    required int ejercicio,
  }) async {
    // 1. Obtener todas las nóminas pagadas del ejercicio
    final snap = await _nominas(empresaId)
        .where('anio', isEqualTo: ejercicio)
        .where('estado', isEqualTo: EstadoNomina.pagada.name)
        .get();

    final nominas = snap.docs
        .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
        .toList();

    // 2. Agrupar por empleado
    final porEmpleado = <String, List<Nomina>>{};
    for (final n in nominas) {
      porEmpleado.putIfAbsent(n.empleadoId, () => []).add(n);
    }

    // 3. Obtener datos personales de cada empleado
    final empleadoIds = porEmpleado.keys.toList();
    final datosEmpleados = <String, DatosNominaEmpleado>{};
    final nombresEmpleados = <String, String>{};
    final provinciasEmpleados = <String, String>{};
    for (final empId in empleadoIds) {
      final doc = await _db.collection('usuarios').doc(empId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final datosMap = data['datos_nomina'] as Map<String, dynamic>?;
        if (datosMap != null) {
          datosEmpleados[empId] = DatosNominaEmpleado.fromMap(datosMap);
        }
        // Nombre completo para el registro
        final nombre = data['nombre'] as String? ?? '';
        final apellidos = data['apellidos'] as String? ?? '';
        nombresEmpleados[empId] = '$apellidos $nombre'.trim();
        provinciasEmpleados[empId] = data['provincia'] as String? ?? '';
      }
    }

    // 4. Construir perceptores
    final perceptores = <Perceptor190>[];
    for (final empId in empleadoIds) {
      final nominasEmp = porEmpleado[empId]!;
      final datos = datosEmpleados[empId];
      if (datos == null) continue;

      // Acumulados anuales
      double brutoDinerarioAnual = 0;
      double retencionesAnuales = 0;
      double especieAnual = 0;
      double ingresosCtaEspecieAnual = 0;
      double cuotaObreraAnual = 0;

      for (final n in nominasEmp) {
        brutoDinerarioAnual += n.totalDevengosCash;
        final especie = n.retribucionesEspecie;
        final totalDev = n.totalDevengos;
        if (especie > 0 && totalDev > 0) {
          especieAnual += especie;
          final propEspecie = especie / totalDev;
          ingresosCtaEspecieAnual += n.retencionIrpf * propEspecie;
          retencionesAnuales += n.retencionIrpf * (1 - propEspecie);
        } else {
          retencionesAnuales += n.retencionIrpf;
        }
        cuotaObreraAnual += n.totalSSTrabajador;
      }

      // Determinar situación familiar
      int situacion = 3;
      if (datos.estadoCivil == EstadoCivil.casado) {
        situacion = 2;
      } else if ((datos.estadoCivil == EstadoCivil.soltero ||
                  datos.estadoCivil == EstadoCivil.divorciado ||
                  datos.estadoCivil == EstadoCivil.viudoSinHijos) &&
                 datos.numHijos > 0) {
        situacion = 1;
      }

      // Código discapacidad
      int discap = 0;
      if (datos.discapacidad && datos.porcentajeDiscapacidad >= 65) {
        discap = 3;
      } else if (datos.discapacidad && datos.porcentajeDiscapacidad >= 33) {
        discap = 1; // 1 = ≥33% <65%; 2 sería con movilidad reducida
      }

      // Tipo contrato → código 190
      int codContrato = 1; // general
      if (datos.tipoContrato == TipoContrato.temporal ||
          datos.tipoContrato == TipoContrato.practicas) {
        codContrato = 2;
      }

      // Nombre normalizado
      final nombre = normalizarTexto(
        nombresEmpleados[empId] ?? nominasEmp.first.empleadoNombre,
      );

      // Año de nacimiento
      final anioNac = datos.fechaNacimiento?.year ?? 1990;

      // Provincia
      final codProv = codigoProvincia(provinciasEmpleados[empId]);

      // NIF perceptor
      final nifPerc = normalizarNif(
        datos.nif ?? nominasEmp.first.empleadoNif ?? '',
      );

      // Descendientes
      final descMenores3 = datos.numHijosMenores3;
      final descResto = (datos.numHijos - datos.numHijosMenores3).clamp(0, 99);

      // Hijos computados (simplificado para PYMEs)
      int h1 = 0, h2 = 0, h3 = 0;
      if (datos.numHijos >= 1) h1 = situacion == 1 ? 1 : 2;
      if (datos.numHijos >= 2) h2 = situacion == 1 ? 1 : 2;
      if (datos.numHijos >= 3) h3 = situacion == 1 ? 1 : 2;

      perceptores.add(Perceptor190(
        empleadoId: empId,
        nifPerceptor: nifPerc,
        apellidosNombre: nombre,
        codigoProvincia: codProv,
        percepcionDinIntegra: _r2(brutoDinerarioAnual),
        retencionesPracticadas: _r2(retencionesAnuales),
        valoracionEspecie: _r2(especieAnual),
        ingresosCuentaEspecie: _r2(ingresosCtaEspecieAnual),
        anioNacimiento: anioNac,
        situacionFamiliar: situacion,
        nifConyuge: '', // se rellena manualmente si sit=2
        discapacidad: discap,
        contrato: codContrato,
        movilidadGeografica: datos.movilidadGeografica,
        gastosDeducibles: _r2(cuotaObreraAnual),
        descendientesMenores3: descMenores3,
        descendientesMenores3Entero: descMenores3,
        descendientesResto: descResto,
        descendientesRestoEntero: descResto,
        hijo1: h1,
        hijo2: h2,
        hijo3: h3,
      ));
    }

    final totalBrutos = perceptores.fold(0.0, (s, p) => s + p.percepcionDinIntegra);
    final totalRetenciones = perceptores.fold(0.0, (s, p) => s + p.retencionesPracticadas);

    return Modelo190(
      id: ejercicio.toString(),
      empresaId: empresaId,
      ejercicio: ejercicio,
      plazoLimite: Modelo190.calcularPlazoLimite(ejercicio),
      nTotalPercepciones: perceptores.length,
      importeTotalPercepciones: _r2(totalBrutos),
      totalRetenciones: _r2(totalRetenciones),
      perceptores: perceptores,
      fechaCreacion: DateTime.now(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDACIONES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Valida el Modelo 190 antes de generar el fichero.
  List<String> validar(Modelo190 modelo, EmpresaConfig empresa) {
    final errores = <String>[];

    // Empresa
    if (!empresa.tieneNifValido) {
      errores.add('NIF declarante inválido');
    }

    for (final p in modelo.perceptores) {
      final label = p.apellidosNombre.isNotEmpty
          ? p.apellidosNombre : 'Empleado ${p.empleadoId}';

      // NIF empleado
      if (p.nifPerceptor.isEmpty) {
        errores.add('$label: NIF no informado');
      } else if (!ValidadorNifCif.esNifValido(p.nifPerceptor) &&
                 !ValidadorNifCif.esNieValido(p.nifPerceptor)) {
        errores.add('$label: NIF inválido (${p.nifPerceptor})');
      }

      // Año nacimiento
      if (p.anioNacimiento < 1920 || p.anioNacimiento > DateTime.now().year) {
        errores.add('$label: año nacimiento no informado o inválido');
      }

      // Situación familiar
      if (p.situacionFamiliar < 1 || p.situacionFamiliar > 3) {
        errores.add('$label: situación familiar inválida');
      }

      // Cónyuge si sit=2
      if (p.situacionFamiliar == 2 && p.nifConyuge.isEmpty) {
        errores.add('$label: falta NIF cónyuge (situación familiar 2)');
      }

      // Retenciones > bruto
      if (p.retencionesPracticadas > p.percepcionDinIntegra) {
        errores.add('$label: retenciones (${p.retencionesPracticadas.toStringAsFixed(2)}) > '
            'bruto (${p.percepcionDinIntegra.toStringAsFixed(2)})');
      }
    }

    // Nº perceptores coherente
    if (modelo.nTotalPercepciones != modelo.perceptores.length) {
      errores.add('Nº percepciones (${modelo.nTotalPercepciones}) ≠ '
          'perceptores (${modelo.perceptores.length})');
    }

    return errores;
  }

  /// Comprueba coherencia entre Modelo 190 y los 4 Modelos 111 del año.
  /// Devuelve null si OK, o un mensaje de discrepancia.
  Future<String?> verificarCoherencia111(
    String empresaId, Modelo190 m190,
  ) async {
    final snap = await _modelos111(empresaId)
        .where('ejercicio', isEqualTo: m190.ejercicio)
        .get();

    final modelos111 = snap.docs
        .map((d) => Modelo111.fromMap({...d.data(), 'id': d.id}))
        .toList();

    if (modelos111.isEmpty) return null; // no hay 111 aún

    final suma111 = modelos111.fold(0.0, (s, m) => s + m.c03 + m.c06);
    final diff = (m190.totalRetenciones - suma111).abs();

    if (diff > 1.0) {
      return 'Retenciones 190 (${m190.totalRetenciones.toStringAsFixed(2)}€) ≠ '
          'suma 111 (${suma111.toStringAsFixed(2)}€) — '
          'diferencia: ${diff.toStringAsFixed(2)}€';
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN DEL FICHERO AEAT (.txt posicional, 500 chars/reg, ISO-8859-1)
  // ═══════════════════════════════════════════════════════════════════════════

  static const int _regLen = 500;

  /// Genera el fichero AEAT como bytes ISO-8859-1.
  static Uint8List generarFicheroTxt({
    required Modelo190 modelo,
    required EmpresaConfig empresa,
    String telefonoContacto = '',
    String personaContacto = '',
    String emailContacto = '',
  }) {
    final nifDeclarante = normalizarNif(empresa.nifNormalizado);
    final razonSocial = normalizarTexto(empresa.razonSocial);

    // Registro tipo 1
    final reg1 = _buildRegistroTipo1(
      modelo: modelo,
      nifDeclarante: nifDeclarante,
      razonSocial: razonSocial,
      telefonoContacto: telefonoContacto,
      personaContacto: normalizarTexto(personaContacto),
      emailContacto: emailContacto,
    );
    assert(reg1.length == _regLen,
        'Registro Tipo 1: ${reg1.length} != $_regLen');

    // Registros tipo 2
    final regs2 = modelo.perceptores.map((p) => _buildRegistroTipo2(
      p: p,
      nifDeclarante: nifDeclarante,
      ejercicio: modelo.ejercicio,
    )).toList();
    for (var i = 0; i < regs2.length; i++) {
      assert(regs2[i].length == _regLen,
          'Registro Tipo 2 #$i: ${regs2[i].length} != $_regLen');
    }

    // Unir con CRLF
    final sb = StringBuffer();
    sb.write(reg1);
    sb.write('\r\n');
    for (final r in regs2) {
      sb.write(r);
      sb.write('\r\n');
    }

    return _encodeIso88591(sb.toString());
  }

  /// Genera como String (para tests).
  static String generarFicheroTexto({
    required Modelo190 modelo,
    required EmpresaConfig empresa,
    String telefonoContacto = '',
    String personaContacto = '',
    String emailContacto = '',
  }) {
    final bytes = generarFicheroTxt(
      modelo: modelo, empresa: empresa,
      telefonoContacto: telefonoContacto,
      personaContacto: personaContacto,
      emailContacto: emailContacto,
    );
    return String.fromCharCodes(bytes);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REGISTRO TIPO 1 — DECLARANTE
  // ═══════════════════════════════════════════════════════════════════════════

  static String _buildRegistroTipo1({
    required Modelo190 modelo,
    required String nifDeclarante,
    required String razonSocial,
    required String telefonoContacto,
    required String personaContacto,
    required String emailContacto,
  }) {
    final buf = List<String>.filled(_regLen, ' ');

    _w(buf, 0, '1');                                           // Pos 1: tipo reg
    _w(buf, 1, '190');                                         // Pos 2-4: modelo
    _w(buf, 4, _padNum(modelo.ejercicio, 4));                  // Pos 5-8: ejercicio
    _w(buf, 8, _padNif(nifDeclarante));                        // Pos 9-17: NIF (9)
    _w(buf, 17, _padAlpha(razonSocial, 40));                   // Pos 18-57: razón social
    _w(buf, 57, 'T');                                          // Pos 58: soporte telemático
    _w(buf, 58, _padNumStr(telefonoContacto, 9));              // Pos 59-67: teléfono
    _w(buf, 67, _padAlpha(personaContacto, 40));               // Pos 68-107: contacto
    _w(buf, 107, '0000000000000');                              // Pos 108-120: nº ident. (ceros)

    // Pos 121: complementaria
    _w(buf, 120, modelo.declaracionComplementaria ? 'C' : ' ');
    // Pos 122: sustitutiva
    _w(buf, 121, modelo.declaracionSustitutiva ? 'S' : ' ');
    // Pos 123-135: nº justificante anterior
    _w(buf, 122, _padNumStr(modelo.nJustificanteAnterior, 13));

    // Pos 136-144: nº total percepciones (9 chars)
    _w(buf, 135, _padNum(modelo.perceptores.length, 9));

    // Pos 145: signo importe total (" " positivo)
    _w(buf, 144, ' ');

    // Pos 146-158: parte entera importe total percepciones (13 chars)
    final impTotal = formatearImporte(modelo.importeTotalPercepciones, 13, 2);
    _w(buf, 145, impTotal.entera);
    // Pos 159-160: parte decimal
    _w(buf, 158, impTotal.decimal);

    // Pos 161-173: parte entera total retenciones (13 chars)
    final retTotal = formatearImporte(modelo.totalRetenciones, 13, 2);
    _w(buf, 160, retTotal.entera);
    // Pos 174-175: parte decimal
    _w(buf, 173, retTotal.decimal);

    // Pos 176-225: email (50 chars)
    _w(buf, 175, _padAlpha(emailContacto, 50));

    // Pos 226-487: blancos (ya están)
    // Pos 488-500: sello electrónico (blancos)

    return buf.join();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REGISTRO TIPO 2 — PERCEPTOR
  // ═══════════════════════════════════════════════════════════════════════════

  static String _buildRegistroTipo2({
    required Perceptor190 p,
    required String nifDeclarante,
    required int ejercicio,
  }) {
    final buf = List<String>.filled(_regLen, ' ');

    _w(buf, 0, '2');                                           // Pos 1
    _w(buf, 1, '190');                                         // Pos 2-4
    _w(buf, 4, _padNum(ejercicio, 4));                         // Pos 5-8
    _w(buf, 8, _padNif(nifDeclarante));                        // Pos 9-17
    _w(buf, 17, _padNif(p.nifPerceptor));                      // Pos 18-26
    // Pos 27-35: NIF representante legal (blancos)
    _w(buf, 35, _padAlpha(p.apellidosNombre, 40));             // Pos 36-75
    _w(buf, 75, _padNumStr(p.codigoProvincia, 2));             // Pos 76-77
    _w(buf, 77, p.clavePercepcion);                            // Pos 78
    _w(buf, 78, p.subclave.isEmpty ? '  ' : _padAlpha(p.subclave, 2)); // Pos 79-80

    // ── Percepciones dinerarias (no IT) ────────────────────────────────────
    _w(buf, 80, ' ');                                          // Pos 81: signo
    final din = formatearImporte(p.percepcionDinIntegra, 11, 2);
    _w(buf, 81, din.entera);                                   // Pos 82-92
    _w(buf, 92, din.decimal);                                  // Pos 93-94
    final ret = formatearImporte(p.retencionesPracticadas, 11, 2);
    _w(buf, 94, ret.entera);                                   // Pos 95-105
    _w(buf, 105, ret.decimal);                                 // Pos 106-107

    // ── Percepciones en especie (no IT) ────────────────────────────────────
    _w(buf, 107, ' ');                                         // Pos 108: signo
    final esp = formatearImporte(p.valoracionEspecie, 11, 2);
    _w(buf, 108, esp.entera);                                  // Pos 109-119
    _w(buf, 119, esp.decimal);                                 // Pos 120-121
    final ict = formatearImporte(p.ingresosCuentaEspecie, 11, 2);
    _w(buf, 121, ict.entera);                                  // Pos 122-132
    _w(buf, 132, ict.decimal);                                 // Pos 133-134
    final irep = formatearImporte(p.ingresosCuentaRepercutidosEspecie, 11, 2);
    _w(buf, 134, irep.entera);                                 // Pos 135-145
    _w(buf, 145, irep.decimal);                                // Pos 146-147

    // ── Datos adicionales clave A ──────────────────────────────────────────
    _w(buf, 147, _padNum(p.ejercicioDevengo, 4));              // Pos 148-151
    _w(buf, 151, p.ceutaMelilla ? '1' : '0');                  // Pos 152
    _w(buf, 152, _padNum(p.anioNacimiento, 4));                // Pos 153-156
    _w(buf, 156, p.situacionFamiliar.toString());              // Pos 157
    _w(buf, 157, _padNif(p.nifConyuge));                       // Pos 158-166
    _w(buf, 166, p.discapacidad.toString());                   // Pos 167
    _w(buf, 167, p.contrato.toString());                       // Pos 168
    _w(buf, 168, '0');                                         // Pos 169: titular unidad convivencia
    _w(buf, 169, p.movilidadGeografica ? '1' : '0');           // Pos 170

    // Pos 171-183: reducciones (11+2)
    final red = formatearImporte(p.reducciones, 11, 2);
    _w(buf, 170, red.entera);
    _w(buf, 181, red.decimal);

    // Pos 184-196: gastos deducibles (11+2)
    final gd = formatearImporte(p.gastosDeducibles, 11, 2);
    _w(buf, 183, gd.entera);
    _w(buf, 194, gd.decimal);

    // Pos 197-209: pensiones compensatorias (11+2)
    final pc = formatearImporte(p.pensionesCompensatorias, 11, 2);
    _w(buf, 196, pc.entera);
    _w(buf, 207, pc.decimal);

    // Pos 210-222: anualidades alimentos (11+2)
    final aa = formatearImporte(p.anualidadesAlimentos, 11, 2);
    _w(buf, 209, aa.entera);
    _w(buf, 220, aa.decimal);

    // Pos 223-254: descendientes y ascendientes
    _w(buf, 222, _n1(p.descendientesMenores3));                // Pos 223
    _w(buf, 223, _n1(p.descendientesMenores3Entero));          // Pos 224
    _w(buf, 224, _padNum(p.descendientesResto, 2));            // Pos 225-226
    _w(buf, 226, _padNum(p.descendientesRestoEntero, 2));      // Pos 227-228
    _w(buf, 228, _padNum(p.descDiscap33_65, 2));               // Pos 229-230
    _w(buf, 230, _padNum(p.descDiscap33_65Entero, 2));         // Pos 231-232
    _w(buf, 232, _padNum(p.descDiscapMovilidad, 2));           // Pos 233-234
    _w(buf, 234, _padNum(p.descDiscapMovilidadEntero, 2));     // Pos 235-236
    _w(buf, 236, _padNum(p.descDiscap65, 2));                  // Pos 237-238
    _w(buf, 238, _padNum(p.descDiscap65Entero, 2));            // Pos 239-240
    _w(buf, 240, _n1(p.ascendientesMenor75));                  // Pos 241
    _w(buf, 241, _n1(p.ascendientesMenor75Entero));            // Pos 242
    _w(buf, 242, _n1(p.ascendientesMayor75));                  // Pos 243
    _w(buf, 243, _n1(p.ascendientesMayor75Entero));            // Pos 244
    _w(buf, 244, _n1(p.ascDiscap33_65));                       // Pos 245
    _w(buf, 245, _n1(p.ascDiscap33_65Entero));                 // Pos 246
    _w(buf, 246, _n1(p.ascDiscapMovilidad));                   // Pos 247
    _w(buf, 247, _n1(p.ascDiscapMovilidadEntero));             // Pos 248
    _w(buf, 248, _n1(p.ascDiscap65));                          // Pos 249
    _w(buf, 249, _n1(p.ascDiscap65Entero));                    // Pos 250
    _w(buf, 250, p.hijo1.toString());                          // Pos 251
    _w(buf, 251, p.hijo2.toString());                          // Pos 252
    _w(buf, 252, p.hijo3.toString());                          // Pos 253
    _w(buf, 253, p.prestamoVivienda ? '1' : '0');              // Pos 254

    // ── Incapacidad laboral (pos 255-321) ──────────────────────────────────
    _w(buf, 254, ' ');                                         // Pos 255: signo IT din
    final itd = formatearImporte(p.percepcionITDineraria, 11, 2);
    _w(buf, 255, itd.entera);                                  // Pos 256-266
    _w(buf, 266, itd.decimal);                                 // Pos 267-268
    final itr = formatearImporte(p.retencionesIT, 11, 2);
    _w(buf, 268, itr.entera);                                  // Pos 269-279
    _w(buf, 279, itr.decimal);                                 // Pos 280-281
    _w(buf, 281, ' ');                                         // Pos 282: signo IT especie
    final ite = formatearImporte(p.valoracionITEspecie, 11, 2);
    _w(buf, 282, ite.entera);                                  // Pos 283-293
    _w(buf, 293, ite.decimal);                                 // Pos 294-295
    final itei = formatearImporte(p.ingresosCuentaITEspecie, 11, 2);
    _w(buf, 295, itei.entera);                                 // Pos 296-306
    _w(buf, 306, itei.decimal);                                // Pos 307-308
    final iter = formatearImporte(p.ingresosCuentaRepercutidosITEspecie, 11, 2);
    _w(buf, 308, iter.entera);                                 // Pos 309-319
    _w(buf, 319, iter.decimal);                                // Pos 320-321

    // ── Campos específicos (pos 322-394) ───────────────────────────────────
    _w(buf, 321, '0');                                         // Pos 322: complemento ayuda infancia
    // Pos 323-387: retenciones forales → ceros
    for (var i = 322; i < 387; i++) buf[i] = '0';
    _w(buf, 387, '0');                                         // Pos 388: excesos acciones
    _w(buf, 388, '0');                                         // Pos 389: fondos emprendimiento
    _w(buf, 389, '00000');                                     // Pos 390-394: tipo prestación

    // Pos 395-500: blancos (ya están)

    return buf.join();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD FIRESTORE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Modelo190> guardar(String empresaId, Modelo190 modelo) async {
    final docId = modelo.ejercicio.toString();
    final data = modelo.toMap();
    data['id'] = docId;
    await _col(empresaId).doc(docId).set(data, SetOptions(merge: true));
    return Modelo190.fromMap(data);
  }

  Future<Modelo190?> obtener(String empresaId, int ejercicio) async {
    final doc = await _col(empresaId).doc(ejercicio.toString()).get();
    if (!doc.exists) return null;
    return Modelo190.fromMap({...doc.data()!, 'id': doc.id});
  }

  Stream<List<Modelo190>> obtenerTodos(String empresaId) {
    return _col(empresaId)
        .orderBy('ejercicio', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Modelo190.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> marcarPresentado(String empresaId, int ejercicio) async {
    await _col(empresaId).doc(ejercicio.toString()).update({
      'estado': EstadoModelo190.presentado.name,
      'fecha_presentacion': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> eliminar(String empresaId, int ejercicio) async {
    final doc = await _col(empresaId).doc(ejercicio.toString()).get();
    if (doc.exists && doc.data()?['estado'] == 'borrador') {
      await doc.reference.delete();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILIDADES PRIVADAS
  // ═══════════════════════════════════════════════════════════════════════════

  static void _w(List<String> buf, int pos, String texto) {
    for (var i = 0; i < texto.length && (pos + i) < buf.length; i++) {
      buf[pos + i] = texto[i];
    }
  }

  static String _padAlpha(String valor, int len) {
    final v = valor.length > len ? valor.substring(0, len) : valor;
    return v.padRight(len);
  }

  static String _padNum(int valor, int len) {
    return valor.abs().toString().padLeft(len, '0');
  }

  static String _padNumStr(String valor, int len) {
    final v = valor.replaceAll(RegExp(r'[^0-9]'), '');
    return v.padLeft(len, '0');
  }

  static String _padNif(String nif) {
    final clean = nif.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    if (clean.length >= 9) return clean.substring(0, 9);
    return clean.padLeft(9, '0');
  }

  static String _n1(int v) => (v.clamp(0, 9)).toString();

  static double _r2(double v) => (v * 100).roundToDouble() / 100;

  static Uint8List _encodeIso88591(String s) {
    return Uint8List.fromList(
      s.codeUnits.map((c) => c > 255 ? 0x3F : c).toList(),
    );
  }
}

