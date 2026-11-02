import 'package:flutter/material.dart';

const Color kFGreen  = Color(0xFF22C55E);
const Color kFOrange = Color(0xFFF59E0B);
const Color kFGray   = Color(0xFF9CA3AF);
const Color kFBg     = Color(0xFFF8F9FA);
const Color kFBorder = Color(0xFFE5E7EB);
const Color kFText   = Color(0xFF111827);
const Color kFSub    = Color(0xFF6B7280);

Widget fichajeCard({required Widget child}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    )],
  ),
  child: child,
);
