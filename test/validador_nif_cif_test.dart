import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/core/utils/validador_nif_cif.dart';

void main() {
  group('ValidadorNifCif', () {
    // ── PRUEBAS NIF ────────────────────────────────────────────────────────

    test('NIF válido debe retornar true', () {
      // NIF real de prueba: 12345678Z (verif: 12345678 % 23 = 20 = 'Z')
      expect(ValidadorNifCif.esNifValido('12345678Z'), true);
    });

    test('NIF con espacios debe ser válido', () {
      expect(ValidadorNifCif.esNifValido('12345678 Z'), true);
    });

    test('NIF con guiones debe ser válido', () {
      expect(ValidadorNifCif.esNifValido('12345678-Z'), true);
    });

    test('NIF en minúsculas debe ser válido', () {
      expect(ValidadorNifCif.esNifValido('12345678z'), true);
    });

    test('NIF inválido (letra incorrecta) debe retornar false', () {
      // 12345678 % 23 = 20 = 'Z', así que 'A' es incorrecto
      expect(ValidadorNifCif.esNifValido('12345678A'), false);
    });

    test('NIF vacío debe retornar false', () {
      expect(ValidadorNifCif.esNifValido(''), false);
    });

    test('NIF nulo debe retornar false', () {
      expect(ValidadorNifCif.esNifValido(null), false);
    });

    test('NIF con formato incorrecto debe retornar false', () {
      expect(ValidadorNifCif.esNifValido('ABC123'), false);
    });

    // ── PRUEBAS CIF ────────────────────────────────────────────────────────

    test('CIF válido debe retornar true', () {
      expect(ValidadorNifCif.esCifValido('A58818501'), true);
    });

    test('CIF con espacios debe ser válido', () {
      expect(ValidadorNifCif.esCifValido('A58818 501'), true);
    });

    test('CIF con guiones debe ser válido', () {
      expect(ValidadorNifCif.esCifValido('A-5881-8501'), true);
    });

    test('CIF con control alfabético válido debe retornar true', () {
      expect(ValidadorNifCif.esCifValido('P2345678D'), true);
    });

    test('CIF con letra inicial inválida debe retornar false', () {
      expect(ValidadorNifCif.esCifValido('Z12345678'), false);
    });

    test('CIF vacío debe retornar false', () {
      expect(ValidadorNifCif.esCifValido(''), false);
    });

    // ── PRUEBAS NIE ────────────────────────────────────────────────────────

    test('NIE válido debe retornar true', () {
      // X1234567 → 01234567 % 23 = 9 = 'L'
      expect(ValidadorNifCif.esNieValido('X1234567L'), true);
    });

    test('NIE con Y debe ser válido', () {
      // Y1234567 → 11234567 % 23 = 19 = 'T'
      expect(ValidadorNifCif.esNieValido('Y1234567T'), true);
    });

    test('NIE con Z debe ser válido', () {
      // Z1234567 → 21234567 % 23 = 3 = 'G'
      expect(ValidadorNifCif.esNieValido('Z1234567G'), true);
    });

    test('NIE inválido (letra incorrecta) debe retornar false', () {
      expect(ValidadorNifCif.esNieValido('X1234567A'), false);
    });

    // ── PRUEBAS DETECCIÓN AUTOMÁTICA ──────────────────────────────────────

    test('Validar NIF debe detectar tipo NIF', () {
      final resultado = ValidadorNifCif.validar('12345678Z');
      expect(resultado.valido, true);
      expect(resultado.tipo, 'NIF');
    });

    test('Validar CIF debe detectar tipo CIF', () {
      final resultado = ValidadorNifCif.validar('A58818501');
      expect(resultado.valido, true);
      expect(resultado.tipo, 'CIF');
    });

    test('Función validarNIF debe devolver true para CIF/NIF/NIE válidos', () {
      expect(validarNIF('12345678Z'), true);
      expect(validarNIF('A58818501'), true);
      expect(validarNIF('X1234567L'), true);
    });

    test('Validar NIE debe detectar tipo NIE', () {
      final resultado = ValidadorNifCif.validar('X1234567L');
      expect(resultado.valido, true);
      expect(resultado.tipo, 'NIE');
    });

    test('Validar inválido debe retornar false', () {
      final resultado = ValidadorNifCif.validar('INVALIDO');
      expect(resultado.valido, false);
      expect(resultado.tipo, 'desconocido');
    });

    test('Validar vacío debe retornar false', () {
      final resultado = ValidadorNifCif.validar('');
      expect(resultado.valido, false);
      expect(resultado.tipo, 'vacío');
    });

    // ── PRUEBAS NORMALIZACIÓN ──────────────────────────────────────────────

    test('Limpiar NIF debe remover espacios y convertir a mayúsculas', () {
      expect(ValidadorNifCif.limpiar('12345678 z'), '12345678Z');
    });

    test('Limpiar NIF debe remover guiones', () {
      expect(ValidadorNifCif.limpiar('12345678-z'), '12345678Z');
    });

    test('Limpiar CIF debe mantener formato', () {
      expect(ValidadorNifCif.limpiar('a 58818 501'), 'A58818501');
    });

    // ── NIFES REALES DE PRUEBA (según AEAT) ────────────────────────────────

    test('NIF real ejemplo 1: 12345678Z', () {
      expect(ValidadorNifCif.esNifValido('12345678Z'), true);
    });

    test('NIF real ejemplo 2: 11111111H', () {
      // 11111111 % 23 = 7 = 'H'
      expect(ValidadorNifCif.esNifValido('11111111H'), true);
    });

    test('NIF real ejemplo 3: 00000000T', () {
      // 0 % 23 = 0 = 'T'
      expect(ValidadorNifCif.esNifValido('00000000T'), true);
    });
  });
}


