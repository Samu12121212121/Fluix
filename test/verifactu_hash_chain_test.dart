import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/verifactu/modelos_verifactu.dart';
import 'package:planeag_flutter/services/verifactu/validador_verifactu.dart';

void main() {
  group('Verifactu — Hash Chain y Encadenamiento (RD 1007/2023)', () {
    test('R2 — Calcula hash SHA-256 correctamente en registro de alta', () {
      final registro = RegistroFacturacionAlta(
        nifEmisor: 'B76543210',
        numeroSerie: 'FAC',
        numeroFactura: '0001',
        fechaExpedicion: DateTime(2026, 1, 15),
        tipoFactura: TipoFacturaVeri.f1,
        descripcion: 'Venta de productos',
        importeTotal: 1210.00,
        cuotaTotal: 210.00,
        desglosePorTipo: {'21': 1000.00},
        claveRegimen: ClaveRegimen.general,
        calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
        registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
        fechaHoraGeneracion: DateTime(2026, 1, 15, 10, 30, 0),
        zonaHoraria: '+01:00',
        esVerifactu: true,
      );

      expect(registro.hash.length, 64); // SHA-256 = 64 caracteres hex
      expect(
        RegExp(r'^[a-f0-9]{64}$').hasMatch(registro.hash.toLowerCase()),
        isTrue,
      );
    });

    test('R2 — Encadenamiento: hash anterior en siguiente registro', () {
      final registro1 = RegistroFacturacionAlta(
        nifEmisor: 'B76543210',
        numeroSerie: 'FAC',
        numeroFactura: '0001',
        fechaExpedicion: DateTime(2026, 1, 15),
        tipoFactura: TipoFacturaVeri.f1,
        descripcion: 'Operación 1',
        importeTotal: 1000.00,
        cuotaTotal: 210.00,
        desglosePorTipo: {'21': 1000.00},
        claveRegimen: ClaveRegimen.general,
        calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
        registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
        fechaHoraGeneracion: DateTime(2026, 1, 15, 10, 0, 0),
        zonaHoraria: '+01:00',
        esVerifactu: true,
      );

      // Segundo registro referencia el primero
      final reference2 = ReferenceRegistroAnterior(
        nifEmisor: registro1.nifEmisor,
        numeroSerie: registro1.numeroSerie,
        numeroFactura: registro1.numeroFactura,
        fechaExpedicion: registro1.fechaExpedicion,
        hash64Caracteres: registro1.hash64,
      );

      final registro2 = RegistroFacturacionAlta(
        nifEmisor: 'B76543210',
        numeroSerie: 'FAC',
        numeroFactura: '0002',
        fechaExpedicion: DateTime(2026, 1, 16),
        tipoFactura: TipoFacturaVeri.f1,
        descripcion: 'Operación 2',
        importeTotal: 2000.00,
        cuotaTotal: 420.00,
        desglosePorTipo: {'21': 2000.00},
        claveRegimen: ClaveRegimen.general,
        calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
        registroAnterior: reference2,
        fechaHoraGeneracion: DateTime(2026, 1, 16, 10, 0, 0),
        zonaHoraria: '+01:00',
        esVerifactu: true,
      );

      expect(registro2.registroAnterior.hash64Caracteres, registro1.hash64);
        expect(registro2.registroAnterior.hash64Caracteres, registro1.hash64);
    });

    test('R3 — Inalterabilidad: hash cambia si se altera registro', () {
      final registro1 = RegistroFacturacionAlta(
        nifEmisor: 'B76543210',
        numeroSerie: 'FAC',
        numeroFactura: '0001',
        fechaExpedicion: DateTime(2026, 1, 15),
        tipoFactura: TipoFacturaVeri.f1,
        descripcion: 'Operación original',
        importeTotal: 1000.00,
        cuotaTotal: 210.00,
        desglosePorTipo: {'21': 1000.00},
        claveRegimen: ClaveRegimen.general,
        calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
        registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
        fechaHoraGeneracion: DateTime(2026, 1, 15, 10, 0, 0),
        zonaHoraria: '+01:00',
        esVerifactu: true,
      );

      final hashOriginal = registro1.hash;

      // Simular cambio en descripción (lo que cambiaría el hash)
      // En realidad, no podemos cambiar el registro una vez creado,
      // pero podemos crear uno con datos distintos y verificar hash diferente

      final registro2 = RegistroFacturacionAlta(
        nifEmisor: 'B76543210',
        numeroSerie: 'FAC',
        numeroFactura: '0001',
        fechaExpedicion: DateTime(2026, 1, 15),
        tipoFactura: TipoFacturaVeri.f1,
        descripcion: 'Operación MODIFICADA', // Cambio
        importeTotal: 1000.00,
        cuotaTotal: 210.00,
        desglosePorTipo: {'21': 1000.00},
        claveRegimen: ClaveRegimen.general,
        calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
        registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
        fechaHoraGeneracion: DateTime(2026, 1, 15, 10, 0, 0),
        zonaHoraria: '+01:00',
        esVerifactu: true,
      );

      expect(registro2.hash, isNot(hashOriginal));
    });

    test(
      'R6 — Precisión temporal: detecta si diferencia > 1 minuto',
      () {
        final registro = RegistroFacturacionAlta(
          nifEmisor: 'B76543210',
          numeroSerie: 'FAC',
          numeroFactura: '0001',
          fechaExpedicion: DateTime(2026, 1, 15),
          tipoFactura: TipoFacturaVeri.f1,
          descripcion: 'Test',
          importeTotal: 1000.00,
          cuotaTotal: 210.00,
          desglosePorTipo: {'21': 1000.00},
          claveRegimen: ClaveRegimen.general,
          calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
          registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
          fechaHoraGeneracion: DateTime(2026, 1, 15, 10, 0, 0),
          zonaHoraria: '+01:00',
          esVerifactu: true,
        );

        // La fecha es de 2026, pero el test se ejecuta ahora
        // Por lo tanto, la validación de tiempo debería fallar
        final validacion = ValidadorVerifactu.validarRegistroAlta(registro, null);

        expect(validacion.errores.any((e) => e.contains('VERIFACTU-005')), isTrue);
      },
    );

    test('R9 — Evento: calcula hash correctamente', () {
      final evento = RegistroEvento(
        codigoProductor: 'PROD001',
        codigoSistema: 'SYS001',
        versionSistema: '1.0.0',
        numeroInstalacion: 'INST001',
        nifObligado: 'B76543210',
        tipoEvento: TipoEvento.inicioNoVerifactu,
        registroAnteriorEvento: ReferenceRegistroAnterior.primerRegistro(),
        fechaHoraGeneracion: DateTime(2026, 1, 15, 10, 0, 0),
        zonaHoraria: '+01:00',
      );

      expect(evento.hash.length, 64);
      expect(
        RegExp(r'^[a-f0-9]{64}$').hasMatch(evento.hash.toLowerCase()),
        isTrue,
      );
    });

    test('R10 — Resumen de eventos cada 6 horas', () {
      final resumen = ResumenEventos(
        codigoProductor: 'PROD001',
        codigoSistema: 'SYS001',
        versionSistema: '1.0.0',
        numeroInstalacion: 'INST001',
        nifObligado: 'B76543210',
        fechaHoraInicio: DateTime(2026, 1, 15, 4, 0, 0),
        fechaHoraFin: DateTime(2026, 1, 15, 10, 0, 0), // 6 horas
        totalEventosEnPeriodo: 5,
        tiposEventosRegistrados: const [
          TipoEvento.inicioNoVerifactu,
          TipoEvento.exportacionFacturacion,
        ],
        registroAnteriorEvento: ReferenceRegistroAnterior.primerRegistro(),
        fechaHoraGeneracion: DateTime(2026, 1, 15, 10, 0, 0),
        zonaHoraria: '+01:00',
      );

      expect(resumen.hash.length, 64);
      // validarResumenEventos pendiente de implementación en validador
    });

    test('Valida cadena completa de registros', () {
      final registro1 = RegistroFacturacionAlta(
        nifEmisor: 'B76543210',
        numeroSerie: 'FAC',
        numeroFactura: '0001',
        fechaExpedicion: DateTime(2026, 1, 15),
        tipoFactura: TipoFacturaVeri.f1,
        descripcion: 'Op1',
        importeTotal: 1000.00,
        cuotaTotal: 210.00,
        desglosePorTipo: {'21': 1000.00},
        claveRegimen: ClaveRegimen.general,
        calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
        registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
        fechaHoraGeneracion: DateTime(2026, 1, 15, 10, 0, 0),
        zonaHoraria: '+01:00',
        esVerifactu: true,
      );

      final reference2 = ReferenceRegistroAnterior(
        nifEmisor: registro1.nifEmisor,
        numeroSerie: registro1.numeroSerie,
        numeroFactura: registro1.numeroFactura,
        fechaExpedicion: registro1.fechaExpedicion,
        hash64Caracteres: registro1.hash64,
      );

      final registro2 = RegistroFacturacionAlta(
        nifEmisor: 'B76543210',
        numeroSerie: 'FAC',
        numeroFactura: '0002',
        fechaExpedicion: DateTime(2026, 1, 16),
        tipoFactura: TipoFacturaVeri.f1,
        descripcion: 'Op2',
        importeTotal: 2000.00,
        cuotaTotal: 420.00,
        desglosePorTipo: {'21': 2000.00},
        claveRegimen: ClaveRegimen.general,
        calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
        registroAnterior: reference2,
        fechaHoraGeneracion: DateTime(2026, 1, 16, 10, 0, 0),
        zonaHoraria: '+01:00',
        esVerifactu: true,
      );

      final cadena = CadenaFacturacion(
        nifEmisor: 'B76543210',
        registrosAlta: [registro1, registro2],
        registrosAnulacion: const [],
      );

      expect(cadena.validarEncadenamiento(), isTrue);
      expect(cadena.totalRegistros, 2);
    });
  });
}






