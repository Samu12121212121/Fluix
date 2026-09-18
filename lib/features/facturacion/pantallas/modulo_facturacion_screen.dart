import 'package:flutter/material.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/tab_facturas.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/utils/app_settings.dart';
import 'pantalla_contabilidad.dart';

class ModuloFacturacionScreen extends StatefulWidget {
  final String empresaId;
  /// En desktop, en vez de pushear una ruta, llama a este callback para
  /// mostrar PantallaContabilidad integrada en el sidebar del dashboard.
  final VoidCallback? onOpenContabilidad;
  const ModuloFacturacionScreen({super.key, required this.empresaId, this.onOpenContabilidad});

  @override
  State<ModuloFacturacionScreen> createState() => _ModuloFacturacionScreenState();
}

class _ModuloFacturacionScreenState extends State<ModuloFacturacionScreen> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _isDark = AppSettings.darkMode.value;
    AppSettings.darkMode.addListener(_onDarkChange);
  }

  @override
  void dispose() {
    AppSettings.darkMode.removeListener(_onDarkChange);
    super.dispose();
  }

  void _onDarkChange() {
    if (mounted) setState(() => _isDark = AppSettings.darkMode.value);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FB),
      appBar: canPop
          ? const FluixAppBar(
              titulo:             'Facturación',
              titleNavigatesBack: true,
            )
          : null,
      body: TabFacturas(
        empresaId: widget.empresaId,
        showTitle: !canPop,
        onNavigateToTab: (tabIndex) {
          if (widget.onOpenContabilidad != null) {
            widget.onOpenContabilidad!();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PantallaContabilidad(
                  empresaId: widget.empresaId,
                  initialTab: tabIndex,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
