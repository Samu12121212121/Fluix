import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/modelo190.dart';
import 'package:planeag_flutter/domain/modelos/empresa_config.dart';
import 'package:planeag_flutter/services/modelo190_service.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // NORMALIZACIÓN DE TEXTO
  // ═══════════════════════════════════════════════════════════════════════════
  group('normalizarTexto', () {
    test('García Martínez José Ángel → GARCIA MARTINEZ JOSE ANGEL', () {
      expect(
        Modelo190Service.normalizarTexto('García Martínez José Ángel'),
        'GARCIA MARTINEZ JOSE ANGEL',
      );
    });

    test('Núñez Peña → NUNEZ PENA', () {
      expect(Modelo190Service.normalizarTexto('Núñez Peña'), 'NUNEZ PENA');
    });

    test('Ñoño Müller → NONO MULLER', () {
      expect(Modelo190Service.normalizarTexto('Ñoño Müller'), 'NONO MULLER');
    });

    test('elimina caracteres especiales', () {
      expect(
        Modelo190Service.normalizarTexto("O'Brien & Cía"),
        'OBRIEN  CIA',
      );
    });

    test('mantiene números', () {
      expect(
        Modelo190Service.normalizarTexto('Piso 3º Izq'),
        'PISO 3 IZQ',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // NORMALIZACIÓN DE NIF
  // ═══════════════════════════════════════════════════════════════════════════
  group('normalizarNif', () {
    test('limpia espacios y guiones', () {
      expect(Modelo190Service.normalizarNif('12 345 678-Z'), '12345678Z');
    });

    test('convierte a mayúsculas', () {
      expect(Modelo190Service.normalizarNif('12345678z'), '12345678Z');
    });

    test('trunca a 9 caracteres', () {
      expect(Modelo190Service.normalizarNif('A1234567890'), 'A12345678');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FORMATEO DE IMPORTES
  // ═══════════════════════════════════════════════════════════════════════════
  group('formatearImporte', () {
    test('12345.67 → entera "0000000012345", decimal "67"', () {
      final r = Modelo190Service.formatearImporte(12345.67, 13, 2);
      expect(r.entera, '0000000012345');
      expect(r.decimal, '67');
    });

    test('1523.00 → entera con ceros, decimal "00"', () {
      final r = Modelo190Service.formatearImporte(1523.00, 13, 2);
      expect(r.entera, '0000000001523');
      expect(r.decimal, '00');
    });

    test('1523.40 → decimal "40"', () {
      final r = Modelo190Service.formatearImporte(1523.40, 13, 2);
      expect(r.entera, '0000000001523');
      expect(r.decimal, '40');
    });

    test('0.99 → entera "0000000000000", decimal "99"', () {
      final r = Modelo190Service.formatearImporte(0.99, 13, 2);
      expect(r.entera, '0000000000000');
      expect(r.decimal, '99');
    });

    test('importe con 11 chars entera', () {
      final r = Modelo190Service.formatearImporte(21600.00, 11, 2);
      expect(r.entera, '00000021600');
      expect(r.decimal, '00');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CÓDIGO DE PROVINCIA
  // ═══════════════════════════════════════════════════════════════════════════
  group('codigoProvincia', () {
    test('Guadalajara = 19', () {
      expect(Modelo190Service.codigoProvincia('Guadalajara'), '19');
    });

    test('guadalajara minúsculas = 19', () {
      expect(Modelo190Service.codigoProvincia('guadalajara'), '19');
    });

    test('Madrid = 28', () {
      expect(Modelo190Service.codigoProvincia('Madrid'), '28');
    });

    test('Toledo = 45', () {
      expect(Modelo190Service.codigoProvincia('Toledo'), '45');
    });

    test('Cuenca = 16', () {
      expect(Modelo190Service.codigoProvincia('Cuenca'), '16');
    });

    test('Ciudad Real = 13', () {
      expect(Modelo190Service.codigoProvincia('Ciudad Real'), '13');
    });

    test('Albacete = 02', () {
      expect(Modelo190Service.codigoProvincia('Albacete'), '02');
    });

    test('null → default 19', () {
      expect(Modelo190Service.codigoProvincia(null), '19');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MODELO DE DATOS
  // ═══════════════════════════════════════════════════════════════════════════
  group('Modelo190 modelo de datos', () {
    test('plazo límite es 31 enero del año siguiente', () {
      expect(Modelo190.calcularPlazoLimite(2025), DateTime(2026, 1, 31));
      expect(Modelo190.calcularPlazoLimite(2026), DateTime(2027, 1, 31));
    });

    test('fromMap/toMap ida y vuelta', () {
      final modelo = Modelo190(
        id: '2025',
        empresaId: 'emp1',
        ejercicio: 2025,
        plazoLimite: DateTime(2026, 1, 31),
        nTotalPercepciones: 3,
        importeTotalPercepciones: 64800.0,
        totalRetenciones: 6804.0,
        perceptores: [
          Perceptor190(
            empleadoId: 'e1',
            nifPerceptor: '12345678Z',
            apellidosNombre: 'GARCIA LOPEZ JUAN',
            anioNacimiento: 1985,
            percepcionDinIntegra: 21600.0,
            retencionesPracticadas: 2268.0,
            gastosDeducibles: 1454.40,
            situacionFamiliar: 2,
            nifConyuge: '87654321X',
            contrato: 1,
          ),
        ],
        fechaCreacion: DateTime(2026, 1, 15),
      );

      final map = modelo.toMap();
      expect(map['ejercicio'], 2025);
      expect(map['n_total_percepciones'], 3);
      expect(map['total_retenciones'], 6804.0);
      expect((map['perceptores'] as List).length, 1);

      final perceptorMap = (map['perceptores'] as List).first as Map<String, dynamic>;
      expect(perceptorMap['nif_perceptor'], '12345678Z');
      expect(perceptorMap['percepcion_din_integra'], 21600.0);
    });

    test('copyWith actualiza estado', () {
      final modelo = Modelo190(
        id: '2025', empresaId: 'emp1', ejercicio: 2025,
        plazoLimite: DateTime(2026, 1, 31),
        fechaCreacion: DateTime.now(),
      );
      final presentado = modelo.copyWith(
        estado: EstadoModelo190.presentado,
        fechaPresentacion: DateTime(2026, 1, 20),
      );
      expect(presentado.estado, EstadoModelo190.presentado);
      expect(presentado.fechaPresentacion, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 1: Bar hostelería Guadalajara, 3 empleados, 2025
  // ═══════════════════════════════════════════════════════════════════════════
  group('Caso 1: fichero AEAT 3 empleados', () {
    final empresa = EmpresaConfig(
      nif: 'B76543210',
      razonSocial: 'Bar La Esquina S.L.',
      domicilioFiscal: 'Calle Mayor 1, 19001 Guadalajara',
    );

    final modelo = Modelo190(
      id: '2025',
      empresaId: 'emp1',
      ejercicio: 2025,
      plazoLimite: DateTime(2026, 1, 31),
      nTotalPercepciones: 3,
      importeTotalPercepciones: 64800.0,
      totalRetenciones: 6804.0,
      perceptores: [
        // Empleado A: 21.600€ bruto, 2.268€ retenciones, SS obrera 1.454,40€
        Perceptor190(
          empleadoId: 'e1',
          nifPerceptor: '12345678Z',
          apellidosNombre: 'GARCIA LOPEZ JUAN',
          codigoProvincia: '19',
          anioNacimiento: 1985,
          situacionFamiliar: 2,
          nifConyuge: '87654321X',
          percepcionDinIntegra: 21600.0,
          retencionesPracticadas: 2268.0,
          gastosDeducibles: 1454.40,
          contrato: 1,
        ),
        // Empleado B: 18.000€ bruto, 1.890€ retenciones
        Perceptor190(
          empleadoId: 'e2',
          nifPerceptor: '87654321X',
          apellidosNombre: 'MARTINEZ RUIZ ANA',
          codigoProvincia: '19',
          anioNacimiento: 1990,
          situacionFamiliar: 3,
          percepcionDinIntegra: 18000.0,
          retencionesPracticadas: 1890.0,
          gastosDeducibles: 1200.0,
          contrato: 1,
        ),
        // Empleado C: 25.200€ bruto, 2.646€ retenciones
        Perceptor190(
          empleadoId: 'e3',
          nifPerceptor: '11223344C',
          apellidosNombre: 'SANCHEZ VILLA PEDRO',
          codigoProvincia: '19',
          anioNacimiento: 1978,
          situacionFamiliar: 1,
          percepcionDinIntegra: 25200.0,
          retencionesPracticadas: 2646.0,
          gastosDeducibles: 1680.0,
          contrato: 1,
          descendientesMenores3: 1,
          descendientesMenores3Entero: 1,
          descendientesResto: 1,
          descendientesRestoEntero: 1,
          hijo1: 1,
          hijo2: 1,
        ),
      ],
      fechaCreacion: DateTime(2026, 1, 15),
    );

    late String texto;

    setUp(() {
      texto = Modelo190Service.generarFicheroTexto(
        modelo: modelo,
        empresa: empresa,
        telefonoContacto: '949123456',
        personaContacto: 'ADMINISTRADOR',
        emailContacto: 'admin@barlaesquina.es',
      );
    });

    test('fichero tiene CRLF entre registros', () {
      expect(texto.contains('\r\n'), isTrue);
    });

    test('registro tipo 1 tiene 500 chars', () {
      final lineas = texto.split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lineas[0].length, 500);
    });

    test('registros tipo 2 tienen 500 chars cada uno', () {
      final lineas = texto.split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lineas.length, 4); // 1 tipo1 + 3 tipo2
      for (var i = 1; i < lineas.length; i++) {
        expect(lineas[i].length, 500, reason: 'Línea ${i + 1}');
      }
    });

    test('tipo 1: posición 1 = "1"', () {
      final reg1 = texto.split('\r\n')[0];
      expect(reg1[0], '1');
    });

    test('tipo 1: posición 2-4 = "190"', () {
      final reg1 = texto.split('\r\n')[0];
      expect(reg1.substring(1, 4), '190');
    });

    test('tipo 1: posición 5-8 = ejercicio "2025"', () {
      final reg1 = texto.split('\r\n')[0];
      expect(reg1.substring(4, 8), '2025');
    });

    test('tipo 1: NIF declarante en pos 9-17', () {
      final reg1 = texto.split('\r\n')[0];
      expect(reg1.substring(8, 17), 'B76543210');
    });

    test('tipo 1: razón social en pos 18-57 (40 chars, mayúsc, sin acentos)', () {
      final reg1 = texto.split('\r\n')[0];
      final razon = reg1.substring(17, 57);
      expect(razon.trimRight(), 'BAR LA ESQUINA S.L.');
      expect(razon.length, 40);
    });

    test('tipo 1: soporte telemático "T" en pos 58', () {
      final reg1 = texto.split('\r\n')[0];
      expect(reg1[57], 'T');
    });

    test('tipo 1: nº percepciones "000000003" en pos 136-144', () {
      final reg1 = texto.split('\r\n')[0];
      expect(reg1.substring(135, 144), '000000003');
    });

    test('tipo 1: importe total percepciones en pos 146-160', () {
      final reg1 = texto.split('\r\n')[0];
      // 64800.00 → entera 13 chars + decimal 2 chars
      expect(reg1.substring(145, 158), '0000000064800');
      expect(reg1.substring(158, 160), '00');
    });

    test('tipo 1: total retenciones en pos 161-175', () {
      final reg1 = texto.split('\r\n')[0];
      // 6804.00 → entera 13 chars + decimal 2 chars
      expect(reg1.substring(160, 173), '0000000006804');
      expect(reg1.substring(173, 175), '00');
    });

    // ── Empleado A ──

    test('empleado A: tipo 2 empieza con "2"', () {
      final reg = texto.split('\r\n')[1];
      expect(reg[0], '2');
    });

    test('empleado A: modelo "190" en pos 2-4', () {
      final reg = texto.split('\r\n')[1];
      expect(reg.substring(1, 4), '190');
    });

    test('empleado A: NIF perceptor en pos 18-26', () {
      final reg = texto.split('\r\n')[1];
      expect(reg.substring(17, 26), '12345678Z');
    });

    test('empleado A: nombre en pos 36-75 (40 chars)', () {
      final reg = texto.split('\r\n')[1];
      final nombre = reg.substring(35, 75);
      expect(nombre.trimRight(), 'GARCIA LOPEZ JUAN');
      expect(nombre.length, 40);
    });

    test('empleado A: provincia "19" en pos 76-77', () {
      final reg = texto.split('\r\n')[1];
      expect(reg.substring(75, 77), '19');
    });

    test('empleado A: clave "A" en pos 78', () {
      final reg = texto.split('\r\n')[1];
      expect(reg[77], 'A');
    });

    test('empleado A: percepción íntegra 21600.00 en pos 82-94', () {
      final reg = texto.split('\r\n')[1];
      expect(reg.substring(81, 92), '00000021600');
      expect(reg.substring(92, 94), '00');
    });

    test('empleado A: retenciones 2268.00 en pos 95-107', () {
      final reg = texto.split('\r\n')[1];
      expect(reg.substring(94, 105), '00000002268');
      expect(reg.substring(105, 107), '00');
    });

    test('empleado A: gastos deducibles 1454.40 en pos 184-196', () {
      final reg = texto.split('\r\n')[1];
      expect(reg.substring(183, 194), '00000001454');
      expect(reg.substring(194, 196), '40');
    });

    test('empleado A: situación familiar "2" en pos 157', () {
      final reg = texto.split('\r\n')[1];
      expect(reg[156], '2');
    });

    test('empleado A: NIF cónyuge en pos 158-166', () {
      final reg = texto.split('\r\n')[1];
      expect(reg.substring(157, 166).trimLeft(), '87654321X');
    });

    test('empleado A: año nacimiento "1985" en pos 153-156', () {
      final reg = texto.split('\r\n')[1];
      expect(reg.substring(152, 156), '1985');
    });

    // ── Empleado C (con descendientes) ──

    test('empleado C: descendientes <3 años en pos 223', () {
      final reg = texto.split('\r\n')[3]; // 4ª línea
      expect(reg[222], '1'); // descendientesMenores3
    });

    test('empleado C: descendientes resto en pos 225-226', () {
      final reg = texto.split('\r\n')[3];
      expect(reg.substring(224, 226), '01');
    });

    test('empleado C: hijos computados en pos 251-253', () {
      final reg = texto.split('\r\n')[3];
      expect(reg[250], '1'); // hijo1
      expect(reg[251], '1'); // hijo2
      expect(reg[252], '0'); // hijo3
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 2: Empleado con baja IT
  // ═══════════════════════════════════════════════════════════════════════════
  group('Caso 2: empleado con IT', () {
    test('percepción IT y retención IT en posiciones correctas', () {
      final modelo = Modelo190(
        id: '2025', empresaId: 'emp1', ejercicio: 2025,
        plazoLimite: DateTime(2026, 1, 31),
        nTotalPercepciones: 1,
        importeTotalPercepciones: 21600.0,
        totalRetenciones: 2268.0,
        perceptores: [
          Perceptor190(
            empleadoId: 'e1', nifPerceptor: '12345678Z',
            apellidosNombre: 'GARCIA LOPEZ JUAN',
            anioNacimiento: 1985,
            percepcionDinIntegra: 21600.0,
            retencionesPracticadas: 2268.0,
            gastosDeducibles: 1454.40,
            percepcionITDineraria: 1080.0,  // 60% × 1800
            retencionesIT: 162.0,           // 15% sobre IT
          ),
        ],
        fechaCreacion: DateTime(2026, 1, 15),
      );

      final empresa = EmpresaConfig(nif: 'B76543210', razonSocial: 'Test S.L.');
      final texto = Modelo190Service.generarFicheroTexto(
          modelo: modelo, empresa: empresa);
      final reg = texto.split('\r\n')[1];

      // Pos 256-268: IT dineraria 1080.00
      expect(reg.substring(255, 266), '00000001080');
      expect(reg.substring(266, 268), '00');

      // Pos 269-281: retenciones IT 162.00
      expect(reg.substring(268, 279), '00000000162');
      expect(reg.substring(279, 281), '00');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 3: Retribución en especie
  // ═══════════════════════════════════════════════════════════════════════════
  group('Caso 3: retribución en especie', () {
    test('valoración especie e ingresos a cuenta en posiciones correctas', () {
      final modelo = Modelo190(
        id: '2025', empresaId: 'emp1', ejercicio: 2025,
        plazoLimite: DateTime(2026, 1, 31),
        nTotalPercepciones: 1,
        importeTotalPercepciones: 21600.0,
        totalRetenciones: 2268.0,
        perceptores: [
          Perceptor190(
            empleadoId: 'e1', nifPerceptor: '12345678Z',
            apellidosNombre: 'GARCIA LOPEZ JUAN',
            anioNacimiento: 1985,
            percepcionDinIntegra: 21600.0,
            retencionesPracticadas: 2268.0,
            valoracionEspecie: 1200.0,
            ingresosCuentaEspecie: 228.0,
          ),
        ],
        fechaCreacion: DateTime(2026, 1, 15),
      );

      final empresa = EmpresaConfig(nif: 'B76543210', razonSocial: 'Test S.L.');
      final texto = Modelo190Service.generarFicheroTexto(
          modelo: modelo, empresa: empresa);
      final reg = texto.split('\r\n')[1];

      // Pos 109-121: valoración especie 1200.00
      expect(reg.substring(108, 119), '00000001200');
      expect(reg.substring(119, 121), '00');

      // Pos 122-134: ingresos a cuenta 228.00
      expect(reg.substring(121, 132), '00000000228');
      expect(reg.substring(132, 134), '00');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 5: Caracteres ISO-8859-1
  // ═══════════════════════════════════════════════════════════════════════════
  group('Caso 5: codificación ISO-8859-1', () {
    test('fichero en bytes solo contiene chars ≤ 255', () {
      final modelo = Modelo190(
        id: '2025', empresaId: 'emp1', ejercicio: 2025,
        plazoLimite: DateTime(2026, 1, 31),
        nTotalPercepciones: 1,
        importeTotalPercepciones: 21600.0,
        totalRetenciones: 2268.0,
        perceptores: [
          Perceptor190(
            empleadoId: 'e1', nifPerceptor: '12345678Z',
            apellidosNombre: 'GARCIA MARTINEZ JOSE ANGEL',
            anioNacimiento: 1985,
            percepcionDinIntegra: 21600.0,
            retencionesPracticadas: 2268.0,
          ),
        ],
        fechaCreacion: DateTime(2026, 1, 15),
      );

      final empresa = EmpresaConfig(
        nif: 'B76543210',
        razonSocial: 'Núñez Peña S.L.', // acentos que deben normalizarse
      );
      final bytes = Modelo190Service.generarFicheroTxt(
          modelo: modelo, empresa: empresa);

      // Verificar que todos los bytes son ≤ 255
      for (var i = 0; i < bytes.length; i++) {
        expect(bytes[i], lessThanOrEqualTo(255),
            reason: 'Byte $i = ${bytes[i]}');
      }
    });

    test('normalización elimina acentos y ñ del fichero', () {
      final texto = Modelo190Service.generarFicheroTexto(
        modelo: Modelo190(
          id: '2025', empresaId: 'emp1', ejercicio: 2025,
          plazoLimite: DateTime(2026, 1, 31),
          nTotalPercepciones: 1,
          importeTotalPercepciones: 0,
          totalRetenciones: 0,
          perceptores: [
            Perceptor190(
              empleadoId: 'e1', nifPerceptor: '12345678Z',
              apellidosNombre: 'NUNEZ PENA',
              anioNacimiento: 1985,
            ),
          ],
          fechaCreacion: DateTime.now(),
        ),
        empresa: EmpresaConfig(nif: 'B76543210', razonSocial: 'Núñez Peña S.L.'),
      );

      // No debe contener ñ, á, é, etc.
      expect(texto.contains('ñ'), isFalse);
      expect(texto.contains('Ñ'), isFalse);
      expect(texto.contains('á'), isFalse);
      expect(texto.contains('é'), isFalse);
      // Debe contener las versiones normalizadas
      final reg1 = texto.split('\r\n')[0];
      expect(reg1.substring(17, 57).trimRight(), 'NUNEZ PENA S.L.');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDACIONES
  // ═══════════════════════════════════════════════════════════════════════════
  group('Validaciones', () {
    final svc = Modelo190Service();

    test('NIF inválido del empleado genera error', () {
      final modelo = Modelo190(
        id: '2025', empresaId: 'emp1', ejercicio: 2025,
        plazoLimite: DateTime(2026, 1, 31),
        nTotalPercepciones: 1,
        importeTotalPercepciones: 21600.0,
        totalRetenciones: 2268.0,
        perceptores: [
          Perceptor190(
            empleadoId: 'e1',
            nifPerceptor: '12345678A', // letra incorrecta (debería ser Z)
            apellidosNombre: 'GARCIA',
            anioNacimiento: 1985,
          ),
        ],
        fechaCreacion: DateTime.now(),
      );
      final empresa = EmpresaConfig(nif: 'B76543210', razonSocial: 'Test S.L.');
      final errores = svc.validar(modelo, empresa);
      expect(errores.any((e) => e.contains('NIF inválido')), isTrue);
    });

    test('retenciones > bruto genera error', () {
      final modelo = Modelo190(
        id: '2025', empresaId: 'emp1', ejercicio: 2025,
        plazoLimite: DateTime(2026, 1, 31),
        nTotalPercepciones: 1,
        perceptores: [
          Perceptor190(
            empleadoId: 'e1',
            nifPerceptor: '12345678Z',
            apellidosNombre: 'TEST',
            anioNacimiento: 1985,
            percepcionDinIntegra: 1000.0,
            retencionesPracticadas: 2000.0, // más que el bruto
          ),
        ],
        fechaCreacion: DateTime.now(),
      );
      final empresa = EmpresaConfig(nif: 'B76543210', razonSocial: 'Test S.L.');
      final errores = svc.validar(modelo, empresa);
      expect(errores.any((e) => e.contains('retenciones')), isTrue);
    });

    test('sit familiar 2 sin NIF cónyuge genera error', () {
      final modelo = Modelo190(
        id: '2025', empresaId: 'emp1', ejercicio: 2025,
        plazoLimite: DateTime(2026, 1, 31),
        nTotalPercepciones: 1,
        perceptores: [
          Perceptor190(
            empleadoId: 'e1',
            nifPerceptor: '12345678Z',
            apellidosNombre: 'TEST',
            anioNacimiento: 1985,
            situacionFamiliar: 2,
            nifConyuge: '', // falta
          ),
        ],
        fechaCreacion: DateTime.now(),
      );
      final empresa = EmpresaConfig(nif: 'B76543210', razonSocial: 'Test S.L.');
      final errores = svc.validar(modelo, empresa);
      expect(errores.any((e) => e.contains('cónyuge')), isTrue);
    });

    test('NIF empresa inválido genera error', () {
      final modelo = Modelo190(
        id: '2025', empresaId: 'emp1', ejercicio: 2025,
        plazoLimite: DateTime(2026, 1, 31),
        nTotalPercepciones: 0,
        perceptores: [],
        fechaCreacion: DateTime.now(),
      );
      final empresa = EmpresaConfig(nif: '', razonSocial: 'Test S.L.');
      final errores = svc.validar(modelo, empresa);
      expect(errores.any((e) => e.contains('NIF declarante')), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTRUCTURA GENERAL DEL FICHERO
  // ═══════════════════════════════════════════════════════════════════════════
  group('Estructura fichero', () {
    test('nº registros tipo 2 = nTotalPercepciones', () {
      final modelo = Modelo190(
        id: '2025', empresaId: 'emp1', ejercicio: 2025,
        plazoLimite: DateTime(2026, 1, 31),
        nTotalPercepciones: 2,
        perceptores: [
          Perceptor190(empleadoId: 'e1', nifPerceptor: '12345678Z',
              apellidosNombre: 'A', anioNacimiento: 1985),
          Perceptor190(empleadoId: 'e2', nifPerceptor: '87654321X',
              apellidosNombre: 'B', anioNacimiento: 1990),
        ],
        fechaCreacion: DateTime.now(),
      );
      final empresa = EmpresaConfig(nif: 'B76543210', razonSocial: 'Test S.L.');
      final texto = Modelo190Service.generarFicheroTexto(
          modelo: modelo, empresa: empresa);

      final lineas = texto.split('\r\n').where((l) => l.isNotEmpty).toList();
      final tipo1 = lineas.where((l) => l[0] == '1').length;
      final tipo2 = lineas.where((l) => l[0] == '2').length;
      expect(tipo1, 1);
      expect(tipo2, 2);
    });

    test('un solo empleado genera 2 líneas (1 tipo1 + 1 tipo2)', () {
      final modelo = Modelo190(
        id: '2025', empresaId: 'emp1', ejercicio: 2025,
        plazoLimite: DateTime(2026, 1, 31),
        nTotalPercepciones: 1,
        perceptores: [
          Perceptor190(empleadoId: 'e1', nifPerceptor: '12345678Z',
              apellidosNombre: 'TEST', anioNacimiento: 1985),
        ],
        fechaCreacion: DateTime.now(),
      );
      final empresa = EmpresaConfig(nif: 'B76543210', razonSocial: 'Test S.L.');
      final texto = Modelo190Service.generarFicheroTexto(
          modelo: modelo, empresa: empresa);

      final lineas = texto.split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lineas.length, 2);
    });
  });
}

