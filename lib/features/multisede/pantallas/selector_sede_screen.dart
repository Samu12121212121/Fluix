import 'package:flutter/material.dart';
import '../servicios/multisede_service.dart';
import '../../dashboard/pantallas/pantalla_dashboard.dart';

/// Pantalla de selección de sede para usuarios multi-sede.
/// Se muestra después del login cuando el usuario gestiona 2+ negocios
/// y no hay ninguna sede activa guardada en SharedPreferences.
class SelectorSedeScreen extends StatefulWidget {
  const SelectorSedeScreen({super.key});

  @override
  State<SelectorSedeScreen> createState() => _SelectorSedeScreenState();
}

class _SelectorSedeScreenState extends State<SelectorSedeScreen> {
  final _svc = MultisedeService();
  List<SedeInfo>? _sedes;
  bool _cargando = true;
  String? _seleccionando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final sedes = await _svc.obtenerSedes();
    if (mounted) setState(() { _sedes = sedes; _cargando = false; });
  }

  Future<void> _seleccionar(SedeInfo sede) async {
    setState(() => _seleccionando = sede.empresaId);
    await _svc.guardarEmpresaActiva(sede.empresaId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PantallaDashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Header
              const Row(children: [
                Icon(Icons.business_center_rounded,
                    color: Color(0xFF00FFC8), size: 32),
                SizedBox(width: 12),
                Text('Fluix CRM',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ]),
              const SizedBox(height: 8),
              Text(
                'Selecciona el negocio con el que quieres trabajar',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6)),
              ),

              const SizedBox(height: 40),
              const Text('Tus negocios',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00FFC8))),
              const SizedBox(height: 12),

              // Lista de sedes
              if (_cargando)
                const Expanded(
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF00FFC8))))
              else if (_sedes == null || _sedes!.isEmpty)
                const Expanded(
                    child: Center(
                        child: Text('Sin negocios disponibles',
                            style: TextStyle(color: Colors.white54))))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _sedes!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _TarjetaSede(
                      sede: _sedes![i],
                      cargando: _seleccionando == _sedes![i].empresaId,
                      onTap: () => _seleccionar(_sedes![i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaSede extends StatelessWidget {
  final SedeInfo sede;
  final bool cargando;
  final VoidCallback onTap;

  const _TarjetaSede({
    required this.sede,
    required this.cargando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E2139),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: cargando ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sede.esPrincipal
                  ? const Color(0xFF00FFC8).withValues(alpha: 0.4)
                  : const Color(0xFF2A2E45),
            ),
          ),
          child: Row(children: [
            // Avatar / logo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF00FFC8).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: sede.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(sede.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _inicial()))
                  : _inicial(),
            ),
            const SizedBox(width: 14),

            // Nombre + badge principal
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sede.nombre,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    if (sede.esPrincipal) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FFC8).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Principal',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00FFC8))),
                      ),
                    ],
                  ]),
            ),

            // Flecha / spinner
            if (cargando)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF00FFC8)))
            else
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF6B6E82)),
          ]),
        ),
      ),
    );
  }

  Widget _inicial() => Center(
        child: Text(
          sede.nombre.isNotEmpty ? sede.nombre[0].toUpperCase() : 'N',
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF00FFC8)),
        ),
      );
}
