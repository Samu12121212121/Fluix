import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tpv_root_screen.dart';
import 'tpv_peluqueria_screen.dart';
import 'tpv_tienda_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TPV SELECTOR DE NEGOCIO — Solo para rol Propietario
// Permite al propietario ver y seleccionar cualquier empresa para
// acceder a su TPV y visualizar cómo funciona.
// ═══════════════════════════════════════════════════════════════════════════

class TpvSelectorNegocioScreen extends StatefulWidget {
  /// UID del propietario actual
  final String propietarioUid;

  /// Si es true, puede ver TODOS los negocios de la plataforma
  final bool esPropietarioPlatforma;

  /// empresaId propia del propietario (como fallback)
  final String empresaIdPropia;

  const TpvSelectorNegocioScreen({
    super.key,
    required this.propietarioUid,
    required this.empresaIdPropia,
    this.esPropietarioPlatforma = false,
  });

  @override
  State<TpvSelectorNegocioScreen> createState() =>
      _TpvSelectorNegocioScreenState();
}

class _TpvSelectorNegocioScreenState extends State<TpvSelectorNegocioScreen> {
  final _db = FirebaseFirestore.instance;
  String _busqueda = '';
  String? _empresaSeleccionadaId;
  bool _lanzando = false;

  // ── Stream de empresas disponibles ─────────────────────────────────────────
  Stream<QuerySnapshot> get _streamEmpresas {
    if (widget.esPropietarioPlatforma) {
      // Propietario de la plataforma: ve TODAS las empresas
      return _db.collection('empresas').snapshots();
    } else {
      // Propietario normal: ve sus propias empresas
      return _db
          .collection('empresas')
          .where('propietario_uid', isEqualTo: widget.propietarioUid)
          .snapshots();
    }
  }

  Future<void> _abrirTpv(String empresaId, String tipoTpv) async {
    if (_lanzando) return;
    setState(() {
      _lanzando = true;
      _empresaSeleccionadaId = empresaId;
    });

    // Forzar orientación horizontal para el TPV
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    if (!mounted) return;

    Widget tpvScreen;
    switch (tipoTpv) {
      case 'peluqueria_estetica':
        tpvScreen = TpvPeluqueriaScreen(empresaId: empresaId, esAdmin: true, esPropietario: true);
        break;
      case 'tienda':
        tpvScreen = TpvTiendaScreen(empresaId: empresaId, esAdmin: true, esPropietario: true);
        break;
      default:
        tpvScreen = TpvRootScreen(empresaId: empresaId, esAdmin: true, esPropietario: true);
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => tpvScreen,
      ),
    );

    // Restaurar orientación al volver
    if (mounted) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      setState(() {
        _lanzando = false;
        _empresaSeleccionadaId = null;
      });
    }
  }

  IconData _iconoTipoTpv(String tipo) {
    switch (tipo) {
      case 'peluqueria_estetica': return Icons.content_cut;
      case 'tienda':              return Icons.store;
      default:                    return Icons.restaurant;
    }
  }

  String _nombreTipoTpv(String tipo) {
    switch (tipo) {
      case 'peluqueria_estetica': return 'Peluquería / Estética';
      case 'tienda':              return 'Tienda / Retail';
      default:                    return 'Bar / Restaurante';
    }
  }

  Color _colorTipoTpv(String tipo) {
    switch (tipo) {
      case 'peluqueria_estetica': return const Color(0xFF7B1FA2);
      case 'tienda':              return const Color(0xFF2E7D32);
      default:                    return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.point_of_sale, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TPV — Vista Propietario',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  widget.esPropietarioPlatforma
                      ? 'Todos los negocios de la plataforma'
                      : 'Tus negocios',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Indicador de modo propietario
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300, width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility, size: 13, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  'Modo Propietario',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Banner explicativo ────────────────────────────────────────────
          Container(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFF0D47A1)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Selecciona un negocio para acceder a su TPV como propietario. '
                    'Puedes visualizar y operar cualquier vista del TPV.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0D47A1)),
                  ),
                ),
              ],
            ),
          ),

          // ── Buscador ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar negocio...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Lista de negocios ─────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _streamEmpresas,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error cargando negocios: ${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];

                // Filtrar por búsqueda
                final filtrados = docs.where((doc) {
                  if (_busqueda.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  final ciudad = (data['ciudad'] ?? data['localidad'] ?? '')
                      .toString()
                      .toLowerCase();
                  return nombre.contains(_busqueda) ||
                      ciudad.contains(_busqueda);
                }).toList();

                if (filtrados.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store_mall_directory_outlined,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _busqueda.isEmpty
                              ? 'No hay negocios disponibles'
                              : 'Sin resultados para "$_busqueda"',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filtrados.length,
                  itemBuilder: (context, idx) {
                    final doc = filtrados[idx];
                    final data = doc.data() as Map<String, dynamic>;
                    final empresaId = doc.id;
                    final nombre = data['nombre'] as String? ?? 'Sin nombre';
                    final ciudad = data['ciudad'] ??
                        data['localidad'] ??
                        data['municipio'] ??
                        '';
                    final tipoTpv =
                        data['tipo_tpv'] as String? ?? 'bar';
                    final logoUrl = data['logo_url'] as String?;
                    final color = _colorTipoTpv(tipoTpv);
                    final esSeleccionada =
                        _empresaSeleccionadaId == empresaId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: esSeleccionada ? 4 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: esSeleccionada
                              ? color
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _lanzando
                            ? null
                            : () => _abrirTpv(empresaId, tipoTpv),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // Logo / Avatar
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: color.withValues(alpha: 0.3)),
                                ),
                                child: logoUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          logoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            _iconoTipoTpv(tipoTpv),
                                            color: color,
                                            size: 28,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        _iconoTipoTpv(tipoTpv),
                                        color: color,
                                        size: 28,
                                      ),
                              ),
                              const SizedBox(width: 14),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombre,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    if (ciudad.toString().isNotEmpty)
                                      Text(
                                        ciudad.toString(),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _iconoTipoTpv(tipoTpv),
                                            size: 11,
                                            color: color,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _nombreTipoTpv(tipoTpv),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: color,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Botón abrir TPV
                              if (esSeleccionada && _lanzando)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              else
                                FilledButton.icon(
                                  onPressed: _lanzando
                                      ? null
                                      : () => _abrirTpv(empresaId, tipoTpv),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: color,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  icon: const Icon(Icons.point_of_sale,
                                      size: 16),
                                  label: const Text('Abrir TPV'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}




