part of 'pantalla_contenido_web.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB SECCIONES (lógica existente extraída a clase separada)
// ═════════════════════════════════════════════════════════════════════════════


class _TabSecciones extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;
  final void Function(SeccionWeb? seccion, String? pagina)? onAbrirEditor;

  const _TabSecciones({
    required this.empresaId,
    required this.svc,
    required this.color,
    this.onAbrirEditor,
  });

  @override
  State<_TabSecciones> createState() => _TabSeccionesState();
}

class _TabSeccionesState extends State<_TabSecciones> {
  String _paginaFiltro = 'todas';

  static const _paginasBase = [
    ('todas', 'Todas'),
    ('inicio', 'Inicio'),
    ('sobre-nosotros', 'Sobre nosotros'),
    ('servicios', 'Servicios'),
    ('galeria', 'Galería'),
    ('contacto', 'Contacto'),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SeccionWeb>>(
      stream: widget.svc.obtenerSecciones(widget.empresaId),
      builder: (_, snap) {
        final todas = snap.data ?? [];
        // Recoger páginas personalizadas que no están en la lista base
        final baseIds = _paginasBase.map((p) => p.$1).toSet();
        final paginasExtra = todas.map((s) => s.pagina)
            .where((p) => !baseIds.contains(p))
            .toSet()
            .toList()..sort();
        final todasPaginas = [..._paginasBase, ...paginasExtra.map((p) => (p, p))];

        final secciones = _paginaFiltro == 'todas'
            ? todas
            : todas.where((s) => s.pagina == _paginaFiltro).toList();
        final activas = secciones.where((s) => s.activa).length;

        return Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${secciones.length} secciones',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                Text('$activas activa${activas == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
              ]),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _abrirEditor(context, null),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Nueva sección'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          // ── Filtro por página ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: todasPaginas.map((p) {
                  final sel = _paginaFiltro == p.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _paginaFiltro = p.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? widget.color : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(p.$2,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel ? Colors.white : const Color(0xFF64748B))),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: secciones.isEmpty
                ? _buildVacio(context)
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: secciones.length,
                    onReorder: (oldIdx, newIdx) async {
                      if (newIdx > oldIdx) newIdx--;
                      final lista = List<SeccionWeb>.from(secciones);
                      final item = lista.removeAt(oldIdx);
                      lista.insert(newIdx, item);
                      // Recalcular orden sobre la lista global (todas), no solo el filtro
                      final completa = List<SeccionWeb>.from(todas);
                      for (var i = 0; i < lista.length; i++) {
                        final idx = completa.indexWhere((s) => s.id == lista[i].id);
                        if (idx >= 0) {
                          completa[idx] = lista[i];
                        }
                      }
                      await widget.svc.reordenarSecciones(widget.empresaId, lista);
                    },
                    itemBuilder: (_, i) => _TarjetaSeccion(
                      key: ValueKey(secciones[i].id),
                      seccion: secciones[i],
                      empresaId: widget.empresaId,
                      svc: widget.svc,
                      color: widget.color,
                      onAbrirEditor: (s) => widget.onAbrirEditor?.call(s, s.pagina),
                    ),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _buildVacio(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: Icon(Icons.web_outlined,
              size: 34, color: widget.color.withValues(alpha: 0.45)),
        ),
        const SizedBox(height: 16),
        const Text('Sin secciones todavía',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: Color(0xFF334155))),
        const SizedBox(height: 6),
        const Text('Añade secciones para que se muestren en tu web',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _abrirEditor(context, null),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Crear primera sección'),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ]),
    );
  }

  void _abrirEditor(BuildContext context, SeccionWeb? seccion) {
    if (widget.onAbrirEditor != null) {
      widget.onAbrirEditor!(seccion,
          seccion?.pagina ?? (_paginaFiltro == 'todas' ? 'inicio' : _paginaFiltro));
      return;
    }
    // NO Navigator.push cuando hay callback
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PantallaEditorSeccion(
        empresaId: widget.empresaId,
        seccion: seccion,
        svc: widget.svc,
        paginaInicial: seccion?.pagina ?? (_paginaFiltro == 'todas' ? 'inicio' : _paginaFiltro),
      ),
    ));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TARJETA de cada sección en la lista principal
// ═════════════════════════════════════════════════════════════════════════════

class _TarjetaSeccion extends StatefulWidget {
  final SeccionWeb seccion;
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;
  final void Function(SeccionWeb seccion)? onAbrirEditor;

  const _TarjetaSeccion({
    super.key,
    required this.seccion,
    required this.empresaId,
    required this.svc,
    required this.color,
    this.onAbrirEditor,
  });

  @override
  State<_TarjetaSeccion> createState() => _TarjetaSeccionState();
}

class _TarjetaSeccionState extends State<_TarjetaSeccion> {
  // Estado local del sync (se lee de Firestore al iniciar)
  bool _catalogoSync = false;
  bool _loadingSync  = false;

  @override
  void initState() {
    super.initState();
    _cargarEstadoSync();
  }

  Future<void> _cargarEstadoSync() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('contenido_web').doc(widget.seccion.id)
          .get();
      if (mounted) {
        setState(() => _catalogoSync = doc.data()?['catalogo_sync'] == true);
      }
    } catch (_) {}
  }

  Future<void> _toggleCatalogoSync(BuildContext context) async {
    setState(() => _loadingSync = true);
    final nuevoEstado = !_catalogoSync;
    final syncSvc = CatalogoWebSyncService();
    try {
      if (nuevoEstado) {
        await syncSvc.activarSincronizacion(widget.empresaId, widget.seccion.id);
      } else {
        await syncSvc.desactivarSincronizacion(widget.empresaId, widget.seccion.id);
      }
      if (mounted) {
        setState(() => _catalogoSync = nuevoEstado);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(nuevoEstado ? Icons.link_rounded : Icons.link_off_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(nuevoEstado
                ? '✅ Catálogo vinculado — los productos se sincronizarán automáticamente'
                : '⏹ Sincronización desactivada'),
          ]),
          backgroundColor: nuevoEstado ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loadingSync = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc      = widget.seccion.tipo.color;
    final activa  = widget.seccion.activa;
    final pagina  = widget.seccion.pagina;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _catalogoSync
            ? const Color(0xFF10B981).withValues(alpha: 0.4)
            : const Color(0xFFE8EDF2)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () => _irAEditar(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            // Icono de tipo
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: tc.withValues(alpha: activa ? 0.1 : 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.seccion.tipo.icono,
                  color: activa ? tc : const Color(0xFFCBD5E1), size: 19),
            ),
            const SizedBox(width: 12),
            // Nombre + tipo + página
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(widget.seccion.nombre,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                          color: activa ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                      overflow: TextOverflow.ellipsis),
                ),
                if (_catalogoSync) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.link_rounded, size: 9, color: Color(0xFF10B981)),
                      SizedBox(width: 3),
                      Text('Sync', style: TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                    ]),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: tc.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(widget.seccion.tipo.nombre,
                      style: TextStyle(fontSize: 10, color: tc, fontWeight: FontWeight.w600)),
                ),
                if (pagina.isNotEmpty && pagina != 'inicio') ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 2),
                  Text(pagina,
                      style: TextStyle(fontSize: 10.5, color: Colors.grey[500])),
                ],
              ]),
            ])),
            const SizedBox(width: 8),
            // Switch activo/inactivo
            Switch(
              value: activa,
              onChanged: (v) async {
                try {
                  await widget.svc.toggleSeccion(widget.empresaId, widget.seccion.id, v);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              activeThumbColor: tc,
              activeTrackColor: tc.withValues(alpha: 0.3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: Color(0xFFCBD5E1), size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (v) {
                if (v == 'editar')    _irAEditar(context);
                if (v == 'sync')      _toggleCatalogoSync(context);
                if (v == 'historial') _mostrarHistorial(context);
                if (v == 'eliminar')  _confirmarEliminar(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'editar', child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: Color(0xFF334155)),
                  SizedBox(width: 10),
                  Text('Editar'),
                ])),
                const PopupMenuItem(value: 'historial', child: Row(children: [
                  Icon(Icons.history_rounded, size: 18, color: Color(0xFF6366F1)),
                  SizedBox(width: 10),
                  Text('Ver historial', style: TextStyle(color: Color(0xFF6366F1))),
                ])),
                PopupMenuItem(value: 'sync', child: Row(children: [
                  _loadingSync
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _catalogoSync ? Icons.link_off_rounded : Icons.link_rounded,
                          size: 18, color: _catalogoSync ? Colors.orange : const Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  Text(_catalogoSync ? 'Desconectar catálogo' : 'Vincular al catálogo',
                      style: TextStyle(
                          color: _catalogoSync ? Colors.orange : const Color(0xFF10B981))),
                ])),
                const PopupMenuItem(value: 'eliminar', child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ])),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  void _irAEditar(BuildContext context) {
    final s   = widget.seccion;
    final eid = widget.empresaId;
    final sv  = widget.svc;
    final col = widget.color;

    // Preferir callback embebido (sin Navigator.push) para todos los tipos
    if (widget.onAbrirEditor != null) {
      widget.onAbrirEditor!(s);
      return;
    }

    // Fallback a Navigator.push cuando no hay callback (uso externo al módulo web)
    if (s.tipo == TipoSeccion.generico) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaItemsSeccion(empresaId: eid, seccion: s, svc: sv),
      ));
    } else if (s.tipo == TipoSeccion.eventos) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(title: Text(s.nombre),
              backgroundColor: col, foregroundColor: Colors.white, elevation: 0),
          body: TabEventosWeb(empresaId: eid, svc: sv),
        ),
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaEditorSeccion(empresaId: eid, seccion: s, svc: sv),
      ));
    }
  }

  void _mostrarHistorial(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Historial de versiones',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Últimas 10 versiones guardadas',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.svc.obtenerHistorial(widget.empresaId, widget.seccion.id),
              builder: (ctx, snap) {
                final versiones = snap.data ?? [];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (versiones.isEmpty) {
                  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history_rounded, size: 48, color: Colors.grey[200]),
                    const SizedBox(height: 12),
                    const Text('Sin versiones guardadas todavía',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    const Text('Las versiones se crean automáticamente\ncada vez que guardas cambios',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                  ]));
                }
                return ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: versiones.length,
                  itemBuilder: (_, i) {
                    final v = versiones[i];
                    final ts = v['guardado_en'];
                    DateTime? fecha;
                    if (ts is Timestamp) fecha = ts.toDate();
                    final nombre = v['nombre'] as String? ?? 'Sin nombre';
                    final tipo = v['tipo'] as String? ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('v${versiones.length - i}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: Color(0xFF6366F1))),
                        ),
                      ),
                      title: Text(nombre,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: fecha == null
                          ? Text(tipo, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                          : Text(
                              '$tipo · ${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour.toString().padLeft(2,'0')}:${fecha.minute.toString().padLeft(2,'0')}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      trailing: i == 0
                          ? const Chip(
                              label: Text('Anterior', style: TextStyle(fontSize: 10)),
                              backgroundColor: Color(0xFFEEF2FF),
                              labelStyle: TextStyle(color: Color(0xFF6366F1)),
                              padding: EdgeInsets.zero,
                            )
                          : TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await widget.svc.restaurarVersionSeccion(
                                    widget.empresaId, widget.seccion.id, v);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                    content: Text('✅ Versión restaurada'),
                                    backgroundColor: Colors.green,
                                  ));
                                }
                              },
                              child: const Text('Restaurar',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF6366F1))),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool eliminando = false;
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar sección'),
            ]),
            content: Text(
              '¿Eliminar "${widget.seccion.nombre}"?\n\n'
              'El contenido desaparecerá de tu web inmediatamente y no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: eliminando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: eliminando
                    ? null
                    : () async {
                        setDlg(() => eliminando = true);
                        try {
                          await widget.svc.eliminarSeccion(widget.empresaId, widget.seccion.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('"${widget.seccion.nombre}" eliminada'),
                                ]),
                                backgroundColor: Colors.red[700],
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          setDlg(() => eliminando = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('❌ Error al eliminar: $e'),
                              backgroundColor: Colors.red,
                            ));
                          }
                        }
                      },
                child: eliminando
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Sí, eliminar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA DE EDICIÓN — Formulario por tipo
// ═════════════════════════════════════════════════════════════════════════════

class PantallaEditorSeccion extends StatefulWidget {
  final String empresaId;
  final SeccionWeb? seccion; // null = nueva
  final ContenidoWebService svc;
  final String paginaInicial;
  final bool noScaffold;
  final VoidCallback? onGuardado;
  final VoidCallback? onCancelar;

  const PantallaEditorSeccion({
    super.key,
    required this.empresaId,
    required this.seccion,
    required this.svc,
    this.paginaInicial = 'inicio',
    this.noScaffold = false,
    this.onGuardado,
    this.onCancelar,
  });

  @override
  State<PantallaEditorSeccion> createState() => _PantallaEditorSeccionState();
}

class _PantallaEditorSeccionState extends State<PantallaEditorSeccion> {
  late TipoSeccion _tipo;
  late String _pagina;
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _idCtrl = TextEditingController(); // ID personalizado para genérico
  final _paginaCtrl = TextEditingController();

  // ── Tipo TEXTO ────────────────────────────────────────────────────────────
  final _tituloCtrl = TextEditingController();
  final _textoCtrl  = TextEditingController();
  String? _imagenUrl;
  bool _subiendoImagen = false;

  // ── Tipo CARTA ────────────────────────────────────────────────────────────
  List<ItemCarta> _carta = [];

  // ── Tipo GALERIA ──────────────────────────────────────────────────────────
  List<ItemGaleria> _galeria = [];

  // ── Tipo OFERTAS ──────────────────────────────────────────────────────────
  List<ItemOferta> _ofertas = [];

  // ── Tipo HORARIOS ─────────────────────────────────────────────────────────
  List<ItemHorario> _horarios = [];

  static const _paginasOpciones = [
    ('inicio', 'Inicio'),
    ('sobre-nosotros', 'Sobre nosotros'),
    ('servicios', 'Servicios'),
    ('galeria', 'Galería'),
    ('contacto', 'Contacto'),
    ('personalizada', 'Otra página…'),
  ];

  bool _guardando = false;

  bool get _esNueva => widget.seccion == null;

  @override
  void initState() {
    super.initState();
    if (widget.seccion != null) {
      final s = widget.seccion!;
      _tipo = s.tipo;
      _pagina = s.pagina;
      _nombreCtrl.text = s.nombre;
      _tituloCtrl.text = s.contenido.titulo;
      _textoCtrl.text  = s.contenido.texto;
      _imagenUrl = s.contenido.imagenUrl;
      _carta   = List.from(s.contenido.itemsCarta);
      _galeria = List.from(s.contenido.imagenesGaleria);
      _ofertas = List.from(s.contenido.ofertas);
      _horarios = s.contenido.horarios.isEmpty
          ? ItemHorario.porDefecto()
          : List.from(s.contenido.horarios);
      // Si la página no está entre las predefinidas, poner modo personalizada
      final conocida = _paginasOpciones.any((p) => p.$1 == _pagina && p.$1 != 'personalizada');
      if (!conocida) _paginaCtrl.text = _pagina;
    } else {
      _tipo = TipoSeccion.texto;
      _pagina = widget.paginaInicial;
      _nombreCtrl.text = TipoSeccion.texto.nombre; // auto-fill inicial
      _horarios = ItemHorario.porDefecto();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _tituloCtrl.dispose(); _textoCtrl.dispose();
    _idCtrl.dispose(); _paginaCtrl.dispose();
    super.dispose();
  }

  Widget _buildFormBody(BuildContext context) {
    final tipoColor = _tipo.color;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
            // ── Selector de tipo (solo en nuevas secciones) ───────────────
            if (_esNueva) ...[
              _buildCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('¿Qué tipo de sección quieres añadir?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: TipoSeccion.values.map((t) {
                      final sel = t == _tipo;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _tipo = t;
                          // Auto-rellenar nombre con el del tipo
                          _nombreCtrl.text = t.nombre;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? t.color
                                : t.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? t.color
                                  : t.color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(t.icono,
                                color: sel ? Colors.white : t.color, size: 16),
                            const SizedBox(width: 6),
                            Text(t.nombre,
                                style: TextStyle(
                                    color: sel ? Colors.white : t.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  // Nombre editable (pre-rellenado con el tipo)
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la sección',
                      hintText: 'Se rellena automáticamente con el tipo',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.label_outline, color: _tipo.color),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Escribe un nombre' : null,
                  ),
                ],
              )),
              const SizedBox(height: 12),
            ] else ...[
              // Edición — mostrar tipo + nombre editable
              _buildCard(child: Column(children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tipoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_tipo.icono, color: tipoColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_tipo.nombre,
                          style: TextStyle(color: tipoColor,
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const Text('Tipo fijo — no se puede cambiar',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  )),
                ]),
                const Divider(height: 16),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la sección',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.label_outline),
                    isDense: true,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Escribe un nombre' : null,
                ),
              ])),
              const SizedBox(height: 12),
            ],

            // ── Selector de página ────────────────────────────────────────
            _buildSelectorPagina(tipoColor),
            const SizedBox(height: 12),

            // ── Editor específico por tipo ─────────────────────────────────
            _buildEditorPorTipo(context, tipoColor),
          ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    final body = _buildFormBody(context);

    if (widget.noScaffold) {
      return LayoutBuilder(builder: (_, constraints) {
        final h = constraints.maxHeight.isInfinite ? null : constraints.maxHeight;
        return SizedBox(
          width: double.infinity,
          height: h,
          child: Column(children: [
            // Barra de acciones: sin color propio, integrada con el layout del dashboard
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE8EAED))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Text(
                    _esNueva ? 'Nueva sección' : (_nombreCtrl.text.isEmpty ? 'Editar sección' : _nombreCtrl.text),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                if (_guardando)
                  SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: color))
                else
                  FilledButton(
                    onPressed: () => _guardar(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Guardar cambios'),
                  ),
              ]),
            ),
            Expanded(child: body),
          ]),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_esNueva ? 'Nueva sección' : 'Editar sección'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            child: Text(
              _guardando ? 'Guardando...' : 'Guardar',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildSelectorPagina(Color c) {
    final esPersonalizada = !_paginasOpciones
        .where((p) => p.$1 != 'personalizada')
        .any((p) => p.$1 == _pagina);
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.folder_open_rounded, color: c, size: 18),
          const SizedBox(width: 8),
          const Text('¿En qué página de WordPress aparece?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7, runSpacing: 7,
          children: _paginasOpciones.map((op) {
            final selActual = op.$1 == 'personalizada' ? esPersonalizada : _pagina == op.$1;
            return GestureDetector(
              onTap: () => setState(() {
                if (op.$1 == 'personalizada') {
                  _pagina = _paginaCtrl.text.trim().isEmpty ? 'personalizada' : _paginaCtrl.text.trim();
                } else {
                  _pagina = op.$1;
                  _paginaCtrl.clear();
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selActual ? c : c.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selActual ? c : c.withValues(alpha: 0.25)),
                ),
                child: Text(op.$2,
                    style: TextStyle(
                        color: selActual ? Colors.white : c,
                        fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
            );
          }).toList(),
        ),
        if (esPersonalizada) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _paginaCtrl,
            decoration: InputDecoration(
              labelText: 'Slug de la página (ej: mi-pagina)',
              hintText: 'solo-minusculas-y-guiones',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.link_rounded, color: c),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _pagina = v.trim().isEmpty ? 'personalizada' : v.trim()),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'data-fluix-pagina="${esPersonalizada && _paginaCtrl.text.isNotEmpty ? _paginaCtrl.text.trim() : _pagina}"',
          style: TextStyle(fontSize: 10.5, color: Colors.grey[400], fontFamily: 'monospace'),
        ),
      ],
    ));
  }

  Widget _buildEditorPorTipo(BuildContext context, Color tipoColor) {
    switch (_tipo) {
      case TipoSeccion.texto:    return _buildEditorTexto(context, tipoColor);
      case TipoSeccion.carta:    return _buildEditorCarta(context, tipoColor);
      case TipoSeccion.galeria:  return _buildEditorGaleria(context, tipoColor);
      case TipoSeccion.ofertas:  return _buildEditorOfertas(context, tipoColor);
      case TipoSeccion.horarios: return _buildEditorHorarios(tipoColor);
      case TipoSeccion.generico: return _buildEditorGenericoInfo(tipoColor);
      case TipoSeccion.eventos:  return _buildEditorEventosInfo(tipoColor);
    }
  }

  Widget _buildEditorEventosInfo(Color c) {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.event_note_rounded, color: c, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text(
            'Sección de Eventos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          )),
        ]),
        const SizedBox(height: 10),
        Text(
          'Esta sección mostrará los próximos eventos de tu negocio en la web.\n\n'
          'Los eventos se gestionan desde la tarjeta — al guardar y pulsar "Editar" '
          'accederás directamente al gestor de eventos.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
        ),
      ],
    ));
  }

  // ── INFO GENÉRICO (solo informativo — la edición real es en PantallaItemsSeccion)
  Widget _buildEditorGenericoInfo(Color c) {
    return Column(children: [
      _buildCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, color: c, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text(
              'Sección genérica (Data-Fluix)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            )),
          ]),
          const SizedBox(height: 10),
          if (_esNueva) ...[
            TextFormField(
              controller: _idCtrl,
              decoration: InputDecoration(
                labelText: 'ID de la sección (slug)',
                hintText: 'ej: carta_entrantes, nuestros_vinos',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag, color: c),
                helperText: 'Este ID se usará en data-fluix-seccion="..."',
                helperMaxLines: 2,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
              ],
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Escribe un ID (solo minúsculas y _)' : null,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _esNueva
                ? 'Guarda esta sección y después pulsa "Editar" en la tarjeta para gestionar los items.'
                : 'Pulsa "Editar" en la tarjeta para gestionar los items.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Los items se sincronizan en tiempo real con la web del cliente '
            'mediante los atributos data-fluix-*.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      )),
    ]);
  }

  // ── EDITOR TEXTO ──────────────────────────────────────────────────────────
  Widget _buildEditorTexto(BuildContext context, Color c) {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _tituloCtrl,
          decoration: const InputDecoration(
            labelText: 'Título',
            border: InputBorder.none,
          ),
        ),
        const Divider(height: 1),
        TextFormField(
          controller: _textoCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Texto / descripción',
            border: InputBorder.none,
            alignLabelWithHint: true,
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        // Imagen
        if (_imagenUrl != null && _imagenUrl!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(_imagenUrl!, height: 160, width: double.infinity,
                fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextButton.icon(
              onPressed: () => _subirImagen(context, 'texto'),
              icon: Icon(Icons.swap_horiz, color: c),
              label: Text('Cambiar imagen', style: TextStyle(color: c)),
            )),
            TextButton.icon(
              onPressed: () => setState(() => _imagenUrl = null),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Quitar', style: TextStyle(color: Colors.red)),
            ),
          ]),
        ] else
          OutlinedButton.icon(
            onPressed: _subiendoImagen ? null : () => _subirImagen(context, 'texto'),
            icon: _subiendoImagen
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.add_photo_alternate, color: c),
            label: Text(_subiendoImagen ? 'Subiendo...' : 'Añadir imagen',
                style: TextStyle(color: c)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.withValues(alpha: 0.4))),
          ),
      ],
    ));
  }

  // ── EDITOR CARTA ──────────────────────────────────────────────────────────
  Widget _buildEditorCarta(BuildContext context, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._carta.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return _buildCard(
            child: Column(children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: item.imagenUrl != null
                        ? null : c.withValues(alpha: 0.1),
                    image: item.imagenUrl != null
                        ? DecorationImage(
                            image: NetworkImage(item.imagenUrl!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: item.imagenUrl == null
                      ? Icon(Icons.restaurant, color: c, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nombre.isEmpty ? 'Nuevo plato' : item.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${item.precio.toStringAsFixed(2)}€',
                        style: TextStyle(color: c, fontWeight: FontWeight.w600)),
                  ],
                )),
                Switch(
                  value: item.disponible,
                  onChanged: (v) => setState(() {
                    _carta[i] = item.copyWith(disponible: v);
                  }),
                  activeThumbColor: c,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _editarItemCarta(context, i, c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _carta.removeAt(i)),
                ),
              ]),
              if (!item.disponible)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('No disponible temporalmente',
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
                ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _editarItemCarta(context, null, c),
            icon: Icon(Icons.add, color: c),
            label: Text('Añadir plato', style: TextStyle(color: c)),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: c.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }

  // ── EDITOR GALERÍA ────────────────────────────────────────────────────────
  Widget _buildEditorGaleria(BuildContext context, Color c) {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fotos de la galería',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Las fotos aparecen en tu web en tiempo real',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
          ),
          itemCount: _galeria.length + 1,
          itemBuilder: (ctx, i) {
            if (i == _galeria.length) {
              // Botón añadir
              return GestureDetector(
                onTap: _subiendoImagen ? null : () => _subirFotoGaleria(context, c),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: c.withValues(alpha: 0.3), style: BorderStyle.solid),
                  ),
                  child: _subiendoImagen
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate, color: c, size: 28),
                          const SizedBox(height: 4),
                          Text('Añadir', style: TextStyle(color: c, fontSize: 11)),
                        ]),
                ),
              );
            }
            final img = _galeria[i];
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(img.url, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _galeria.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text('${_galeria.length} foto(s)',
            style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    ));
  }

  // ── EDITOR OFERTAS ────────────────────────────────────────────────────────
  Widget _buildEditorOfertas(BuildContext context, Color c) {
    return Column(
      children: [
        ..._ofertas.asMap().entries.map((entry) {
          final i = entry.key;
          final o = entry.value;
          return _buildCard(child: Column(
            children: [
              Row(children: [
                if (o.imagenUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(o.imagenUrl!,
                        width: 56, height: 56, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.local_offer, color: c, size: 28),
                  ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.titulo.isEmpty ? 'Nueva oferta' : o.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(children: [
                      if (o.precioOriginal != null)
                        Text('${o.precioOriginal!.toStringAsFixed(2)}€ ',
                            style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey, fontSize: 12)),
                      if (o.precioOferta != null)
                        Text('${o.precioOferta!.toStringAsFixed(2)}€',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  ],
                )),
                Switch(
                  value: o.activa,
                  onChanged: (v) => setState(() {
                    _ofertas[i] = o.copyWith(activa: v);
                  }),
                  activeThumbColor: c,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _editarOferta(context, i, c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _ofertas.removeAt(i)),
                ),
              ]),
            ],
          ));
        }),
        const SizedBox(height: 8),
        // Botón "Añadir oferta" ELIMINADO - Las ofertas las añade el administrador
      ],
    );
  }

  // ── EDITOR HORARIOS ───────────────────────────────────────────────────────
  Widget _buildEditorHorarios(Color c) {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Horarios de apertura',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        ..._horarios.asMap().entries.map((entry) {
          final i = entry.key;
          final h = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(width: 84,
                child: Text(h.dia,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              if (h.cerrado)
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Cerrado',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                ))
              else ...[
                Expanded(child: GestureDetector(
                  onTap: () => _seleccionarHora(i, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(h.apertura,
                        style: TextStyle(color: c, fontWeight: FontWeight.w600,
                            fontSize: 13), textAlign: TextAlign.center),
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: Colors.grey[400])),
                ),
                Expanded(child: GestureDetector(
                  onTap: () => _seleccionarHora(i, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(h.cierre,
                        style: TextStyle(color: c, fontWeight: FontWeight.w600,
                            fontSize: 13), textAlign: TextAlign.center),
                  ),
                )),
              ],
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() {
                  _horarios[i] = h.copyWith(cerrado: !h.cerrado);
                }),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: h.cerrado
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    h.cerrado ? Icons.lock_open : Icons.lock,
                    color: h.cerrado ? Colors.green : Colors.red,
                    size: 18,
                  ),
                ),
              ),
            ]),
          );
        }),
      ],
    ));
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Future<void> _seleccionarHora(int idx, bool esApertura) async {
    final h = _horarios[idx];
    final parts = (esApertura ? h.apertura : h.cierre).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      ),
    );
    if (picked == null) return;
    final str = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      _horarios[idx] = esApertura
          ? h.copyWith(apertura: str)
          : h.copyWith(cierre: str);
    });
  }

  Future<void> _subirImagen(BuildContext context, String carpeta) async {
    setState(() => _subiendoImagen = true);
    final url = await widget.svc.subirImagenDesdeGaleria(widget.empresaId, carpeta);
    if (mounted) {
      setState(() { _imagenUrl = url; _subiendoImagen = false; });
    }
  }

  Future<void> _subirFotoGaleria(BuildContext context, Color c) async {
    setState(() => _subiendoImagen = true);
    final url = await widget.svc.subirImagenDesdeGaleria(
        widget.empresaId, 'galeria');
    if (url != null && mounted) {
      setState(() {
        _galeria.add(ItemGaleria(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          url: url,
        ));
      });
    }
    if (mounted) setState(() => _subiendoImagen = false);
  }

  void _editarItemCarta(BuildContext context, int? idx, Color c) {
    final item        = idx != null ? _carta[idx] : null;
    final nombreCtrl  = TextEditingController(text: item?.nombre ?? '');
    final descCtrl    = TextEditingController(text: item?.descripcion ?? '');
    final precioCtrl  = TextEditingController(
        text: item != null ? item.precio.toStringAsFixed(2) : '');
    final catCtrl     = TextEditingController(text: item?.categoria ?? 'General');

    // Estado local del modal (imagen + spinner)
    String? imagenLocal = item?.imagenUrl;
    bool   subiendoImg  = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {

          Future<void> subirImg() async {
            setModalState(() => subiendoImg = true);
            final url = await widget.svc.subirImagenDesdeGaleria(
                widget.empresaId, 'carta/${widget.seccion?.id ?? 'items'}');
            if (url != null) imagenLocal = url;
            setModalState(() => subiendoImg = false);
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 20, right: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // Handle
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),

                Text(idx == null ? 'Nuevo producto' : 'Editar producto',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),

                // ── IMAGEN ───────────────────────────────────────────────
                GestureDetector(
                  onTap: subiendoImg ? null : subirImg,
                  child: Container(
                    width: double.infinity, height: 160,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: imagenLocal != null
                              ? Colors.transparent
                              : c.withValues(alpha: 0.3),
                          style: BorderStyle.solid),
                      image: imagenLocal != null
                          ? DecorationImage(
                              image: NetworkImage(imagenLocal!),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: subiendoImg
                        ? Center(child: CircularProgressIndicator(color: c))
                        : imagenLocal == null
                            ? Column(mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      color: c, size: 36),
                                  const SizedBox(height: 6),
                                  Text('Toca para añadir imagen\ndesde la galería',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: c, fontSize: 13)),
                                ])
                            : Align(
                                alignment: Alignment.topRight,
                                child: GestureDetector(
                                  onTap: () => setModalState(() => imagenLocal = null),
                                  child: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                  ),
                ),
                if (imagenLocal != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: subiendoImg ? null : subirImg,
                    child: Text('Cambiar imagen',
                        style: TextStyle(color: c, fontSize: 12,
                            decoration: TextDecoration.underline)),
                  ),
                ],
                const SizedBox(height: 14),

                // ── CAMPOS ───────────────────────────────────────────────
                TextField(controller: nombreCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nombre', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(
                      controller: precioCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                          labelText: 'Precio (€)',
                          border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 16),

                // ── BOTÓN GUARDAR ────────────────────────────────────────
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final nombre = nombreCtrl.text.trim();
                      if (nombre.isEmpty) return;
                      final precio = double.tryParse(
                          precioCtrl.text.replaceAll(',', '.')) ?? 0.0;
                      final nuevo = ItemCarta(
                        id:          item?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        nombre:      nombre,
                        descripcion: descCtrl.text.trim(),
                        precio:      precio,
                        categoria:   catCtrl.text.trim().isEmpty
                            ? 'General' : catCtrl.text.trim(),
                        imagenUrl:   imagenLocal,
                        disponible:  item?.disponible ?? true,
                      );
                      setState(() {
                        if (idx != null) _carta[idx] = nuevo;
                        else _carta.add(nuevo);
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: c,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text(idx == null ? 'Añadir' : 'Guardar cambios'),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _editarOferta(BuildContext context, int? idx, Color c) {
    final o = idx != null ? _ofertas[idx] : null;
    final tituloCtrl = TextEditingController(text: o?.titulo ?? '');
    final descCtrl   = TextEditingController(text: o?.descripcion ?? '');
    final precOrigCtrl = TextEditingController(
        text: o?.precioOriginal?.toStringAsFixed(2) ?? '');
    final precOfCtrl = TextEditingController(
        text: o?.precioOferta?.toStringAsFixed(2) ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(idx == null ? 'Nueva oferta' : 'Editar oferta',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(controller: tituloCtrl,
              decoration: const InputDecoration(labelText: 'Título de la oferta',
                  border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: descCtrl, maxLines: 2,
              decoration: const InputDecoration(labelText: 'Descripción',
                  border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: precOrigCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Precio original (€)',
                    border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: precOfCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                    labelText: 'Precio oferta (€)',
                    border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final titulo = tituloCtrl.text.trim();
                if (titulo.isEmpty) return;
                final nuevo = ItemOferta(
                  id: o?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  titulo: titulo,
                  descripcion: descCtrl.text.trim(),
                  precioOriginal: double.tryParse(
                      precOrigCtrl.text.replaceAll(',', '.')),
                  precioOferta: double.tryParse(
                      precOfCtrl.text.replaceAll(',', '.')),
                  imagenUrl: o?.imagenUrl,
                  activa: o?.activa ?? true,
                );
                setState(() {
                  if (idx != null) _ofertas[idx] = nuevo;
                  else _ofertas.add(nuevo);
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: c, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(idx == null ? 'Añadir' : 'Guardar cambios'),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _guardar(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final contenido = ContenidoSeccion(
      titulo: _tituloCtrl.text.trim(),
      texto:  _textoCtrl.text.trim(),
      imagenUrl: _imagenUrl,
      itemsCarta: _carta,
      imagenesGaleria: _galeria,
      ofertas: _ofertas,
      horarios: _horarios,
      items: widget.seccion?.contenido.items ?? [],
    );

    // Para genéricos nuevos, usar el ID personalizado
    String seccionId = widget.seccion?.id ?? '';
    if (_esNueva && _tipo == TipoSeccion.generico && _idCtrl.text.trim().isNotEmpty) {
      seccionId = _idCtrl.text.trim();
    }

    final seccion = SeccionWeb(
      id: seccionId,
      nombre: _nombreCtrl.text.trim(),
      descripcion: '',
      activa: widget.seccion?.activa ?? true,
      tipo: _tipo,
      contenido: contenido,
      fechaCreacion: widget.seccion?.fechaCreacion ?? DateTime.now(),
      fechaActualizacion: DateTime.now(),
      pagina: _pagina,
    );

    try {
      await widget.svc.guardarSeccion(widget.empresaId, seccion);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('¡Guardado! Los cambios ya se ven en tu web'),
          ]),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ));
        if (widget.noScaffold) {
          widget.onGuardado?.call();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB GALERÍA WEB — imágenes y medios del sitio
// ═════════════════════════════════════════════════════════════════════════════

