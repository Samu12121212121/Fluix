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

  Future<void> _cambiarTipoTpv(String nuevoTipo) async {
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaIdPropia)
        .update({'tipo_tpv': nuevoTipo});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Tipo de TPV cambiado a: ${_nombreTipoTpv(nuevoTipo)}'),
        backgroundColor: Colors.green,
      ));
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
              stream: FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(widget.empresaIdPropia)
                  .collection('tpvs_personalizados')
                  .orderBy('nombre')
                  .snapshots(),
              builder: (ctx, snapTpvs) {
                final tpvsPersonalizados = snapTpvs.data?.docs ?? [];
                return StreamBuilder<QuerySnapshot>(
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

                // Filtrar: solo empresas con módulo TPV activo
                // (si no tienen 'modulos_activos' = cuenta antigua = mostrar por compatibilidad)
                final conTpv = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final modulos = data['modulos_activos'] as List?;
                  if (modulos == null) return true; // cuenta sin campo = compatible
                  return modulos.contains('tpv');
                }).toList();

                // Filtrar por búsqueda
                final filtrados = conTpv.where((doc) {
                  if (_busqueda.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  final ciudad = (data['ciudad'] ?? data['localidad'] ?? '')
                      .toString()
                      .toLowerCase();
                  return nombre.contains(_busqueda) ||
                      ciudad.contains(_busqueda);
                }).toList();

                // Total items: 1 base + N personalizados + M negocios
                final totalItems = 1 + tpvsPersonalizados.length + filtrados.length;

                if (totalItems == 1 && filtrados.isEmpty) {
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
                  itemCount: totalItems,
                  itemBuilder: (context, idx) {
                    // ── Tarjeta TPV Base (siempre primera) ────────────────
                    if (idx == 0) {
                      return _TarjetaTpvBase(
                        empresaIdPropia: widget.empresaIdPropia,
                        lanzando: _lanzando,
                        onTap: () => _abrirTpv(widget.empresaIdPropia, 'bar'),
                      );
                    }

                    // ── TPVs personalizados ────────────────────────────────
                    if (idx <= tpvsPersonalizados.length) {
                      final doc = tpvsPersonalizados[idx - 1];
                      final data = doc.data() as Map<String, dynamic>;
                      final nombre = data['nombre'] as String? ?? 'TPV ${idx}';
                      final ocultos = List<String>.from(data['productos_ocultos'] ?? []);
                      return _TarjetaTpvPersonalizadoSelector(
                        nombre: nombre,
                        ocultos: ocultos,
                        lanzando: _lanzando,
                        esSeleccionado: _empresaSeleccionadaId == '${widget.empresaIdPropia}_${doc.id}',
                        onTap: () => _abrirTpvPersonalizado(
                            widget.empresaIdPropia, doc.id, nombre),
                      );
                    }

                    final idx2 = idx - 1 - tpvsPersonalizados.length;
                    final doc = filtrados[idx2];
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
                              // Acciones: cambiar tipo + abrir
                              if (esSeleccionada && _lanzando)
                                const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  // ── Cambiar tipo ──────────────────
                                  PopupMenuButton<String>(
                                    tooltip: 'Cambiar tipo de TPV',
                                    offset: const Offset(0, 40),
                                    onSelected: (nuevoTipo) async {
                                      await FirebaseFirestore.instance
                                          .collection('empresas')
                                          .doc(empresaId)
                                          .update({'tipo_tpv': nuevoTipo});
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${nombre}: TPV cambiado a ${_nombreTipoTpv(nuevoTipo)}'),
                                            backgroundColor: Colors.green,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: color.withValues(alpha: 0.3)),
                                      ),
                                      child: Icon(Icons.swap_horiz, color: color, size: 16),
                                    ),
                                    itemBuilder: (_) => [
                                      PopupMenuItem(value: 'bar',
                                        child: Row(children: [
                                          Icon(Icons.restaurant, size: 16,
                                              color: tipoTpv == 'bar' ? Colors.blue : null),
                                          const SizedBox(width: 8),
                                          Text('Bar / Restaurante',
                                              style: TextStyle(
                                                  fontWeight: tipoTpv == 'bar' ? FontWeight.w700 : null)),
                                        ])),
                                      PopupMenuItem(value: 'peluqueria_estetica',
                                        child: Row(children: [
                                          Icon(Icons.content_cut, size: 16,
                                              color: tipoTpv == 'peluqueria_estetica' ? Colors.purple : null),
                                          const SizedBox(width: 8),
                                          Text('Peluquería / Estética',
                                              style: TextStyle(
                                                  fontWeight: tipoTpv == 'peluqueria_estetica' ? FontWeight.w700 : null)),
                                        ])),
                                      PopupMenuItem(value: 'tienda',
                                        child: Row(children: [
                                          Icon(Icons.store, size: 16,
                                              color: tipoTpv == 'tienda' ? Colors.green : null),
                                          const SizedBox(width: 8),
                                          Text('Tienda / Retail',
                                              style: TextStyle(
                                                  fontWeight: tipoTpv == 'tienda' ? FontWeight.w700 : null)),
                                        ])),
                                    ],
                                  ),
                                  // ── Abrir TPV ─────────────────────
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
                                    icon: const Icon(Icons.point_of_sale, size: 16),
                                    label: const Text('Abrir'),
                                  ),
                                ]),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ); // ListView.builder
              }, // _streamEmpresas builder
            ); // StreamBuilder empresas
              }, // tpvs_personalizados builder
            ), // StreamBuilder tpvs_personalizados
          ),
        ],
      ),
    );
  }

  Future<void> _abrirTpvPersonalizado(
      String empresaId, String tpvId, String nombre) async {
    final key = '${empresaId}_$tpvId';
    if (_lanzando) return;
    setState(() { _lanzando = true; _empresaSeleccionadaId = key; });

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TpvRootScreen(
          empresaId: empresaId,
          esAdmin: true,
          esPropietario: true,
          tpvPersonalizadoId: tpvId,
          tpvPersonalizadoNombre: nombre,
        ),
      ),
    );

    if (mounted) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      setState(() { _lanzando = false; _empresaSeleccionadaId = null; });
    }
  }
}

// ── Tarjeta TPV Base (siempre primera en la lista del propietario) ────────────

class _TarjetaTpvBase extends StatelessWidget {
  final String empresaIdPropia;
  final bool lanzando;
  final VoidCallback onTap;

  const _TarjetaTpvBase({
    required this.empresaIdPropia,
    required this.lanzando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF1565C0), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: lanzando ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.store,
                    color: Color(0xFF1565C0), size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TPV Base',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1565C0))),
                    SizedBox(height: 2),
                    Text('Catálogo estándar de la aplicación',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 11, color: Color(0xFF1565C0)),
                        SizedBox(width: 4),
                        Text('Por defecto',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: lanzando ? null : onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                icon: const Icon(Icons.point_of_sale, size: 16),
                label: const Text('Abrir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de TPV personalizado en el selector ───────────────────────────────

class _TarjetaTpvPersonalizadoSelector extends StatelessWidget {
  final String nombre;
  final List<String> ocultos;
  final bool lanzando;
  final bool esSeleccionado;
  final VoidCallback onTap;

  const _TarjetaTpvPersonalizadoSelector({
    required this.nombre,
    required this.ocultos,
    required this.lanzando,
    required this.esSeleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6A1B9A);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: esSeleccionado ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: esSeleccionado ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: lanzando ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.tablet_android, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      ocultos.isEmpty
                          ? 'Catálogo completo'
                          : '${ocultos.length} producto${ocultos.length != 1 ? 's' : ''} ocultado${ocultos.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.tune, size: 11, color: color),
                      SizedBox(width: 4),
                      Text('TPV personalizado',
                          style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ),
              if (esSeleccionado && lanzando)
                const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                FilledButton.icon(
                  onPressed: lanzando ? null : onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.point_of_sale, size: 16),
                  label: const Text('Abrir'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
