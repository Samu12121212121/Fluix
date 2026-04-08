import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/empresa_config.dart';

void main() {
  group('EmpresaConfig NIF', () {
    test('ignora el placeholder legacy si existe un NIF real en empresa', () {
      final config = EmpresaConfig.fromSources(
        empresaDoc: const {
          'nif': 'B76543214',
          'razon_social': 'Empresa Real SL',
        },
        fiscalDoc: const {
          'nif': 'A12345678',
          'razon_social': 'Empresa Legacy SL',
        },
      );

      expect(config.nifNormalizado, 'B76543214');
      expect(config.tieneNifValido, isTrue);
      expect(config.usaNifPlaceholderLegacy, isFalse);
    });

    test('marca el placeholder legacy como configuración no válida', () {
      const config = EmpresaConfig(nif: 'A12345678');

      expect(config.usaNifPlaceholderLegacy, isTrue);
      expect(config.tieneNifConfigurado, isFalse);
      expect(config.tieneNifValido, isFalse);
      expect(config.errorNif, 'Configura el NIF real de la empresa');
      expect(
        config.validar(),
        contains('Debes configurar el NIF real de la empresa'),
      );
    });

    test('prioriza el NIF fiscal si es real aunque empresa tenga placeholder', () {
      final config = EmpresaConfig.fromSources(
        empresaDoc: const {
          'nif': 'A12345678',
          'razon_social': 'Empresa Legacy SL',
        },
        fiscalDoc: const {
          'nif': 'B76543214',
          'razon_social': 'Empresa Fiscal Real SL',
        },
      );

      expect(config.nifNormalizado, 'B76543214');
      expect(config.tieneNifValido, isTrue);
      expect(config.usaNifPlaceholderLegacy, isFalse);
    });

    test('detecta placeholder legacy con espacios y minúsculas', () {
      const config = EmpresaConfig(nif: ' a12345678 ');

      expect(config.nifNormalizado, 'A12345678');
      expect(config.usaNifPlaceholderLegacy, isTrue);
      expect(config.tieneNifConfigurado, isFalse);
    });
  });
}


