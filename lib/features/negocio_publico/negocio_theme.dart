import 'package:flutter/material.dart';

// ── Colores de acento (fijos) ─────────────────────────────────────────────
const kAccent = Color(0xFF00BFA5);
const kRosa   = Color(0xFFFF3296);
const kOro    = Color(0xFFFFB830);
const kRojo   = Color(0xFFFF2850);
const kAzul   = Color(0xFF4A9EFF);

// ── Colores reactivos al modo oscuro ─────────────────────────────────────
Color kBg(bool d)    => d ? const Color(0xFF0A0F23) : const Color(0xFFF8F9FA);
Color kCard(bool d)  => d ? const Color(0xFF1E2139) : Colors.white;
Color kCard2(bool d) => d ? const Color(0xFF252A45) : const Color(0xFFF1F5F9);
Color kTexto(bool d) => d ? Colors.white             : const Color(0xFF0F172A);
Color kMuted(bool d) => d ? const Color(0xFFB0B3C1) : const Color(0xFF6B7280);
Color kBorde(bool d) => d ? const Color(0xFF2A2E45) : const Color(0xFFE5E7EB);

// ── InputDecoration compartida ────────────────────────────────────────────
InputDecoration kDec(bool dark, String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: kMuted(dark), fontSize: 13),
  filled: true, fillColor: kBg(dark),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  enabledBorder: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: kBorde(dark), width: 0.5),
  ),
  focusedBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: kAccent, width: 1),
  ),
  border: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: kBorde(dark), width: 0.5),
  ),
);
