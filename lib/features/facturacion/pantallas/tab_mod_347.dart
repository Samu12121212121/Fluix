import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/empresa_config_provider.dart';
import '../../../services/mod_347_service.dart';
import '../../../services/exportadores_aeat/mod_347_exporter.dart';
import 'pantalla_configuracion_fiscal_empresa.dart';

class TabMod347 extends StatefulWidget {
  final String empresaId;
  final int anio;

  const TabMod347({
    super.key,
    required this.empresaId,
    required this.anio,
  });

  @override
  State<TabMod347> createState() => _TabMod347State();
}

class _TabMod347State extends State<TabMod347> {
  final _svc = Mod347Service();
  Resumen347? _resumen;
  bool _cargando = true;
  bool _descargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(TabMod347 old) {
    super.didUpdateWidget(old);
    if (old.anio != widget.anio || old.empresaId != widget.empresaId) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final r = await _svc.calcular(widget.empresaId, widget.anio);
      if (mounted) setState(() { _resumen = r; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    final empresaConfig = context.watch<EmpresaConfigProvider>().config;

    if (_cargando) return const Center(child: CircularProgressIndicator());

    final r = _resumen;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Banner informativo ─────────────────────────────────────────────
        _buildBannerInfo(color),
        if (!empresaConfig.tieneNifConfigurado || !empresaConfig.tieneNifValido) ...[
          const SizedBox(height: 12),
          _buildBannerNifFaltante(color),
        ],
        const SizedBox(height: 16),

        // ── Resumen ────────────────────────────────────────────────────────
        if (r != null) ...[
          _buildCardResumen(r, color),
          const SizedBox(height: 16),

          // Ventas declarables
          if (r.operacionesVenta.isNotEmpty) ...[
            _buildSeccionTitulo('📤 Ventas a clientes (>3.005€)', color),
            ...r.operacionesVenta.map((op) => _buildTarjetaOp(op, color)),
            const SizedBox(height: 8),
          ],

          // Compras declarables
          if (r.operacionesCompra.isNotEmpty) ...[
            _buildSeccionTitulo('📥 Compras a proveedores (>3.005€)', color),
            ...r.operacionesCompra.map((op) => _buildTarjetaOp(op, color)),
            const SizedBox(height: 8),
          ],

          if (r.numDeclaraciones == 0)
            _buildSinOperaciones(color),

          const SizedBox(height: 16),
          // Botón descargar
          _buildBotonDescargar(color),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  // ── WIDGETS ────────────────────────────────────────────────────────────────

  Widget _buildBannerInfo(Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modelo 347 — Operaciones con terceros',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Declaración anual obligatoria de operaciones con proveedores '
                  'y clientes que superen 3.005,06€ en el ejercicio.',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerNifFaltante(Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configura el NIF de tu empresa antes de generar modelos fiscales',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _abrirConfiguracionFiscal,
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Ir a configuración fiscal'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardResumen(Resumen347 r, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Ejercicio ${r.anio}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetrica(
                    'Clientes declarables',
                    '${r.operacionesVenta.length}',
                    Icons.person_outline,
                    color,
                  ),
                ),
                Expanded(
                  child: _buildMetrica(
                    'Proveedores declarables',
                    '${r.operacionesCompra.length}',
                    Icons.business_outlined,
                    Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMetrica(
                    'Total ventas',
                    '${r.totalVentas.toStringAsFixed(0)}€',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetrica(
                    'Total compras',
                    '${r.totalCompras.toStringAsFixed(0)}€',
                    Icons.trending_down,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildMetrica(
              'Total operaciones a declarar',
              '${r.numDeclaraciones}',
              Icons.assignment_outlined,
              color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrica(String label, String valor, IconData icono, Color c) {
    return Column(
      children: [
        Icon(icono, color: c, size: 26),
        const SizedBox(height: 6),
        Text(valor,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: c)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildSeccionTitulo(String titulo, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTarjetaOp(Operacion347 op, Color color) {
    final esVenta = op.tipo == TipoOperacion347.venta;
    final c = esVenta ? Colors.green : Colors.deepPurple;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                esVenta ? Icons.arrow_upward : Icons.arrow_downward,
                color: c,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(op.nombreTercero,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    'NIF: ${op.nifTercero}  ·  ${op.numOperaciones} operaciones',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${op.totalAnual.toStringAsFixed(2)}€',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: c),
                ),
                Text(
                  'IVA: ${op.ivaAnual.toStringAsFixed(2)}€',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinOperaciones(Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 40),
          const SizedBox(height: 12),
          const Text(
            '✅ Sin operaciones declarables',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Ningún proveedor ni cliente supera el umbral de 3.005,06€ '
            'en el ejercicio ${widget.anio}. No es obligatorio presentar MOD 347.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonDescargar(Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _descargando ? null : _descargar,
        icon: _descargando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.download),
        label: Text(
          _descargando ? 'Generando...' : 'Descargar MOD 347 (AEAT)',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _descargar() async {
    final empresaConfig = context.read<EmpresaConfigProvider>().config;
    if (!empresaConfig.tieneNifValido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configura un NIF válido antes de generar el MOD 347'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _descargando = true);
    await _svc.descargarFichero(
      empresaId: widget.empresaId,
      nifDeclarante: empresaConfig.nifNormalizado,
      nombreDeclarante: empresaConfig.razonSocial.isNotEmpty
          ? empresaConfig.razonSocial
          : 'Empresa sin razón social',
      anio: widget.anio,
      onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
        }
      },
      onSuccess: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ MOD 347 generado'),
                backgroundColor: Colors.green),
          );
        }
      },
    );
    if (mounted) setState(() => _descargando = false);
  }

  Future<void> _abrirConfiguracionFiscal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<EmpresaConfigProvider>(),
          child: const PantallaConfiguracionFiscalEmpresa(),
        ),
      ),
    );
  }
}



