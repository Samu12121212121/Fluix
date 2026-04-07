import 'package:flutter/material.dart';
import '../services/certificado_digital_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET DE ESTADO DEL CERTIFICADO DIGITAL
//
// Reutilizable en cabecera de cualquier pantalla de modelo fiscal:
//   - MOD 303, 390, 111, 115, 130...
//   - Verifactu
//
// Muestra:
//   ✅ Certificado válido — expira el DD/MM/AAAA
//   ⚠️ Certificado expira en X días
//   ❌ Sin certificado — los modelos no se podrán firmar
//   🔴 Certificado expirado
// ═══════════════════════════════════════════════════════════════════════════════

class EstadoCertificadoWidget extends StatelessWidget {
  final String empresaId;
  final bool compact;

  const EstadoCertificadoWidget({
    super.key,
    required this.empresaId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final svc = CertificadoDigitalService(empresaId: empresaId);

    return StreamBuilder<CertificadoDigitalMeta?>(
      stream: svc.metaStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 32, child: Center(child: LinearProgressIndicator()));
        }

        final meta = snap.data;
        if (meta == null) return _buildBanner(_EstadoViz.sinCertificado, null);

        final estado = meta.estado;
        return _buildBanner(_estadoToViz(estado, meta), meta);
      },
    );
  }

  _EstadoViz _estadoToViz(EstadoCertDigital estado, CertificadoDigitalMeta meta) {
    switch (estado) {
      case EstadoCertDigital.valido:
        return _EstadoViz.valido;
      case EstadoCertDigital.proximoAExpirar:
        return meta.diasParaExpirar <= 7
            ? _EstadoViz.urgente
            : _EstadoViz.proximoAExpirar;
      case EstadoCertDigital.expirado:
        return _EstadoViz.expirado;
      case EstadoCertDigital.sinCertificado:
      case EstadoCertDigital.error:
        return _EstadoViz.sinCertificado;
    }
  }

  Widget _buildBanner(_EstadoViz viz, CertificadoDigitalMeta? meta) {
    final cfg = _vizConfig[viz]!;
    final diasText = meta != null
        ? (meta.diasParaExpirar >= 0
            ? 'expira el ${_fmtDate(meta.validoHasta)}'
            : 'expirado el ${_fmtDate(meta.validoHasta)}')
        : null;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cfg.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cfg.border, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cfg.icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(cfg.label,
                style: TextStyle(
                    fontSize: 10,
                    color: cfg.textColor,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cfg.border, width: 0.8),
      ),
      child: Row(
        children: [
          Text(cfg.icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cfg.label,
                    style: TextStyle(
                        fontSize: 12,
                        color: cfg.textColor,
                        fontWeight: FontWeight.w600)),
                if (diasText != null)
                  Text(diasText,
                      style: TextStyle(
                          fontSize: 10,
                          color: cfg.textColor.withValues(alpha: 0.75))),
                if (meta?.nif != null)
                  Text('NIF: ${meta!.nif}',
                      style: TextStyle(
                          fontSize: 10,
                          color: cfg.textColor.withValues(alpha: 0.75))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Enum interno de visualización ─────────────────────────────────────────────

enum _EstadoViz {
  valido,
  proximoAExpirar,
  urgente,
  expirado,
  sinCertificado,
}

class _VizConfig {
  final String icon;
  final String label;
  final Color bg;
  final Color border;
  final Color textColor;

  const _VizConfig({
    required this.icon,
    required this.label,
    required this.bg,
    required this.border,
    required this.textColor,
  });
}

const _vizConfig = <_EstadoViz, _VizConfig>{
  _EstadoViz.valido: _VizConfig(
    icon: '✅',
    label: 'Firmado digitalmente con certificado FNMT',
    bg: Color(0xFFE8F5E9),
    border: Color(0xFF4CAF50),
    textColor: Color(0xFF2E7D32),
  ),
  _EstadoViz.proximoAExpirar: _VizConfig(
    icon: '⚠️',
    label: 'Certificado próximo a expirar',
    bg: Color(0xFFFFF3E0),
    border: Color(0xFFFF9800),
    textColor: Color(0xFFE65100),
  ),
  _EstadoViz.urgente: _VizConfig(
    icon: '⚠️',
    label: 'URGENTE: Certificado expira en menos de 7 días',
    bg: Color(0xFFFFF3E0),
    border: Color(0xFFFF5722),
    textColor: Color(0xFFBF360C),
  ),
  _EstadoViz.expirado: _VizConfig(
    icon: '🔴',
    label: 'Certificado expirado — renuévelo',
    bg: Color(0xFFFFEBEE),
    border: Color(0xFFF44336),
    textColor: Color(0xFFB71C1C),
  ),
  _EstadoViz.sinCertificado: _VizConfig(
    icon: '❌',
    label: 'Sin certificado digital — presentación manual',
    bg: Color(0xFFFFFDE7),
    border: Color(0xFFFFC107),
    textColor: Color(0xFF5D4037),
  ),
};


