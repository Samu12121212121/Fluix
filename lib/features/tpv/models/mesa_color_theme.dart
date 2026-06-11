import 'package:flutter/material.dart';

class MesaColorTheme {
  final String id;
  final String nombre;
  final Color fondoApp;
  final Color mesaLibre;
  final Color mesaOcupada;
  final Color textoLibre;
  final Color textoOcupada;

  const MesaColorTheme({
    required this.id,
    required this.nombre,
    required this.fondoApp,
    required this.mesaLibre,
    required this.mesaOcupada,
    required this.textoLibre,
    required this.textoOcupada,
  });

  // ── 5 paletas predefinidas ────────────────────────────────────────────────

  // Fondo unificado para que coincida con la columna izquierda del TPV
  static const _fondo = Color(0xFF1A1A1A);

  static const slateSage = MesaColorTheme(
    id: 'slate_sage',
    nombre: 'Slate Sage',
    fondoApp:    _fondo,
    mesaLibre:   Color(0xFF6B8F71),
    mesaOcupada: Color(0xFFC17C74),
    textoLibre:  Color(0xFFFFFFFF),
    textoOcupada: Color(0xFFFFFFFF),
  );

  static const navyAmber = MesaColorTheme(
    id: 'navy_amber',
    nombre: 'Navy Amber',
    fondoApp:    _fondo,
    mesaLibre:   Color(0xFF5B8DB8),
    mesaOcupada: Color(0xFFD4956A),
    textoLibre:  Color(0xFFFFFFFF),
    textoOcupada: Color(0xFFFFFFFF),
  );

  static const charcoalMint = MesaColorTheme(
    id: 'charcoal_mint',
    nombre: 'Charcoal Mint',
    fondoApp:    _fondo,
    mesaLibre:   Color(0xFF4ECDC4),
    mesaOcupada: Color(0xFFE8897A),
    textoLibre:  Color(0xFF1A2A29),
    textoOcupada: Color(0xFFFFFFFF),
  );

  static const warmDark = MesaColorTheme(
    id: 'warm_dark',
    nombre: 'Warm Dark',
    fondoApp:    _fondo,
    mesaLibre:   Color(0xFF7BAE7F),
    mesaOcupada: Color(0xFFBC6C6C),
    textoLibre:  Color(0xFFFFFFFF),
    textoOcupada: Color(0xFFFFFFFF),
  );

  static const monoPro = MesaColorTheme(
    id: 'mono_pro',
    nombre: 'Mono Pro',
    fondoApp:    _fondo,
    mesaLibre:   Color(0xFF5C85D6),
    mesaOcupada: Color(0xFF7A7A7A),
    textoLibre:  Color(0xFFFFFFFF),
    textoOcupada: Color(0xFFFFFFFF),
  );

  static const List<MesaColorTheme> todos = [
    slateSage,
    navyAmber,
    charcoalMint,
    warmDark,
    monoPro,
  ];

  static MesaColorTheme porId(String id) {
    return todos.firstWhere((t) => t.id == id, orElse: () => warmDark);
  }
}
