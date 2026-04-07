import 'package:flutter/material.dart';
import '../../vacaciones/widgets/cobertura_semanal_widget.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET DE COBERTURA PARA EL DASHBOARD — Versión compacta (5 días)
// ═══════════════════════════════════════════════════════════════════════════════

class WidgetCoberturaResumen extends StatelessWidget {
  final String empresaId;

  const WidgetCoberturaResumen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return CoberturaSemanalWidget(
      empresaId: empresaId,
      compacto: true,
    );
  }
}

