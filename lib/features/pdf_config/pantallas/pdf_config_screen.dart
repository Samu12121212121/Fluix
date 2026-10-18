import 'package:flutter/material.dart';
import '../../../domain/modelos/pdf_configuracion.dart';
import '../../../services/pdf_config_service.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import 'pdf_config_diseno_tab.dart';
import 'pdf_config_emisor_tab.dart';
import 'pdf_config_pago_tab.dart';
import 'pdf_config_tipos_tab.dart';

// ── Pantalla de Configuración de PDFs ─────────────────────────────────────────
// Perfil → Configuración de PDFs (propietario / admin)
// Guarda en empresas/{empresaId}/configuracion/pdf

class PdfConfigScreen extends StatefulWidget {
  final String empresaId;
  const PdfConfigScreen({super.key, required this.empresaId});

  @override
  State<PdfConfigScreen> createState() => _State();
}

class _State extends State<PdfConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  PdfConfiguracion? _cfg;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  static const _kPurple = Color(0xFF6D5EF8);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final cfg = await PdfConfigService.cargar(widget.empresaId);
      if (mounted) setState(() { _cfg = cfg; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  void _onChanged(PdfConfiguracion cfg) => setState(() => _cfg = cfg);

  Future<void> _guardar() async {
    if (_cfg == null || _guardando) return;
    setState(() => _guardando = true);
    try {
      await PdfConfigService.guardar(widget.empresaId, _cfg!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Configuración guardada'),
        backgroundColor: Color(0xFF16A34A),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Error al guardar: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FluixAppBar(
        titulo: 'Configuración de PDFs',
        showLeading: true,
        bottom: TabBar(
          controller: _tabs,
          labelColor: _kPurple,
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: _kPurple,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.business_rounded, size: 18), text: 'Emisor'),
            Tab(icon: Icon(Icons.account_balance_rounded, size: 18), text: 'Pago'),
            Tab(icon: Icon(Icons.description_outlined, size: 18), text: 'Por tipo'),
            Tab(icon: Icon(Icons.palette_outlined, size: 18), text: 'Diseño'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _cargar)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    PdfConfigEmisorTab(
                      cfg: _cfg!, onChanged: _onChanged, empresaId: widget.empresaId),
                    PdfConfigPagoTab(cfg: _cfg!, onChanged: _onChanged),
                    PdfConfigTiposTab(cfg: _cfg!, onChanged: _onChanged),
                    PdfConfigDisenoTab(
                      cfg: _cfg!, onChanged: _onChanged, empresaId: widget.empresaId),
                  ],
                ),
      floatingActionButton: _cfg == null ? null : FloatingActionButton.extended(
        onPressed: _guardando ? null : _guardar,
        backgroundColor: _kPurple,
        icon: _guardando
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_rounded, color: Colors.white),
        label: Text(_guardando ? 'Guardando…' : 'Guardar',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text('No se pudo cargar la configuración', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
    ],
  ));
}
