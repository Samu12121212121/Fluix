// resenas_fluix_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/negocio_publico_model.dart';

// ─── Paleta ──────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF0A0F23);
const _kCard   = Color(0xFF1E2139);
const _kCard2  = Color(0xFF252A45);
const _kAccent = Color(0xFF00FFC8);
const _kRosa   = Color(0xFFFF3296);
const _kOro    = Color(0xFFFFB830);
const _kTexto  = Colors.white;
const _kMuted  = Color(0xFFB0B3C1);
const _kBorde  = Color(0xFF2A2E45);

class ResenasFluixScreen extends StatefulWidget {
  final String negocioId;
  final String nombreNegocio;

  const ResenasFluixScreen({
    super.key,
    required this.negocioId,
    required this.nombreNegocio,
  });

  @override
  State<ResenasFluixScreen> createState() => _ResenasFluixScreenState();
}

class _ResenasFluixScreenState extends State<ResenasFluixScreen> {
  List<ResenaFluix> _resenas = [];
  bool _cargando = true;
  bool _guardando = false;
  final _pageCtrl = PageController(viewportFraction: 0.88);
  int _paginaActual = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(widget.negocioId)
          .get();
      final data = doc.data();
      if (data != null && data['resenasFluix'] != null) {
        final lista = (data['resenasFluix'] as List<dynamic>)
            .map((e) => ResenaFluix.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() => _resenas = lista);
      }
    } catch (e) {
      _snack('Error cargando resenas: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(widget.negocioId)
          .update({
        'resenasFluix': _resenas.map((r) => r.toJson()).toList(),
      });
      _snack('✅ Resenas publicadas');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFFF2850) : _kAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  double get _mediaEstrellas {
    if (_resenas.isEmpty) return 0;
    return _resenas.map((r) => r.estrellas).reduce((a, b) => a + b) /
        _resenas.length;
  }

  Map<int, int> get _distribucion {
    final m = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _resenas) {
      m[r.estrellas.round()] = (m[r.estrellas.round()] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF151932),
        foregroundColor: _kTexto,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resenas Fluix',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.nombreNegocio,
                style: const TextStyle(color: _kMuted, fontSize: 12)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kBg))
                  : const Icon(Icons.cloud_upload_rounded, size: 16),
              label: Text(_guardando ? 'Publicando…' : 'Publicar'),
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: _kBg,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormulario,
        backgroundColor: _kRosa,
        foregroundColor: _kTexto,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Añadir resena',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kAccent))
          : _resenas.isEmpty
          ? _buildEmpty()
          : SingleChildScrollView(
        child: Column(children: [
          _buildStats(),
          _buildCarrusel(),
          _buildListado(),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: _kCard,
            shape: BoxShape.circle,
            border: Border.all(color: _kBorde),
          ),
          child: const Icon(Icons.star_border_rounded, size: 48, color: _kOro),
        ),
        const SizedBox(height: 20),
        const Text('Sin resenas todavía',
            style: TextStyle(
                color: _kTexto, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Añade las primeras resenas de clientes\npara que aparezcan en tu perfil público.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _kMuted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _mostrarFormulario,
          icon: const Icon(Icons.add_comment_rounded),
          label: const Text('Añadir primera resena'),
          style: FilledButton.styleFrom(
            backgroundColor: _kRosa,
            foregroundColor: _kTexto,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }

  // ── Estadísticas ───────────────────────────────────────────────────────────
  Widget _buildStats() {
    final media = _mediaEstrellas;
    final dist = _distribucion;
    final total = _resenas.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorde, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              media.toStringAsFixed(1),
              style: const TextStyle(
                  color: _kOro,
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  height: 1),
            ),
            const SizedBox(height: 6),
            _Estrellas(media, size: 18),
            const SizedBox(height: 4),
            Text('$total resena${total == 1 ? '' : 's'}',
                style: const TextStyle(color: _kMuted, fontSize: 12)),
          ]),
          const SizedBox(width: 24),
          const VerticalDivider(color: _kBorde, width: 1),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((n) {
                final cnt = dist[n] ?? 0;
                final pct = total > 0 ? cnt / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Text('$n',
                        style: const TextStyle(
                            color: _kMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    const Icon(Icons.star_rounded, color: _kOro, size: 12),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: _kBg,
                          valueColor:
                          const AlwaysStoppedAnimation<Color>(_kOro),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 20,
                      child: Text('$cnt',
                          style:
                          const TextStyle(color: _kMuted, fontSize: 11),
                          textAlign: TextAlign.right),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Carrusel ───────────────────────────────────────────────────────────────
  Widget _buildCarrusel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(children: [
            const Icon(Icons.view_carousel_rounded, color: _kAccent, size: 16),
            const SizedBox(width: 8),
            const Text('Vista previa del carrusel',
                style: TextStyle(
                    color: _kTexto,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const Spacer(),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border:
                Border.all(color: _kAccent.withValues(alpha: 0.3)),
              ),
              child: const Text('Así lo verá el cliente',
                  style: TextStyle(color: _kAccent, fontSize: 10)),
            ),
          ]),
        ),
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _resenas.length,
            onPageChanged: (i) => setState(() => _paginaActual = i),
            itemBuilder: (_, i) => _TarjetaResena(
              resena: _resenas[i],
              activa: i == _paginaActual,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _resenas.length,
                (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _paginaActual ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _paginaActual ? _kAccent : _kBorde,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Listado ────────────────────────────────────────────────────────────────
  Widget _buildListado() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Icon(Icons.list_alt_rounded, color: _kAccent, size: 16),
              SizedBox(width: 8),
              Text('Todas las resenas',
                  style: TextStyle(
                      color: _kTexto,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ]),
          ),
          ..._resenas.asMap().entries.map((e) => _FilaResena(
            resena: e.value,
            onEditar: () =>
                _mostrarFormulario(resena: e.value, idx: e.key),
            onEliminar: () => _confirmarEliminar(e.key),
          )),
        ],
      ),
    );
  }

  // ── Diálogos ───────────────────────────────────────────────────────────────
  Future<void> _mostrarFormulario({ResenaFluix? resena, int? idx}) async {
    final result = await showDialog<ResenaFluix>(
      context: context,
      builder: (_) => _DialogoResena(resena: resena),
    );
    if (result == null) return;
    setState(() {
      if (idx != null) {
        _resenas[idx] = result;
      } else {
        _resenas.add(result);
      }
    });
  }

  Future<void> _confirmarEliminar(int idx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('¿Eliminar resena?',
            style: TextStyle(color: _kTexto)),
        content: const Text('Esta acción no se puede deshacer.',
            style: TextStyle(color: _kMuted, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
              const Text('Cancelar', style: TextStyle(color: _kMuted))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: _kRosa, foregroundColor: _kTexto),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => _resenas.removeAt(idx));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TARJETA CARRUSEL
// ═══════════════════════════════════════════════════════════════════════════
class _TarjetaResena extends StatelessWidget {
  final ResenaFluix resena;
  final bool activa;

  const _TarjetaResena({required this.resena, required this.activa});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: activa ? 1.0 : 0.95,
      duration: const Duration(milliseconds: 250),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activa ? _kAccent.withValues(alpha: 0.4) : _kBorde,
            width: activa ? 1.5 : 0.5,
          ),
          boxShadow: activa
              ? [
            BoxShadow(
              color: _kAccent.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _Avatar(
                  nombre: resena.autorNombre,
                  avatarUrl: resena.autorAvatarUrl,
                  size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(resena.autorNombre,
                            style: const TextStyle(
                                color: _kTexto,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (resena.verificado)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded,
                                    color: _kAccent, size: 11),
                                SizedBox(width: 3),
                                Text('Verificado',
                                    style: TextStyle(
                                        color: _kAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)),
                              ]),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    _Estrellas(resena.estrellas, size: 15),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: Text(
                '"${resena.comentario}"',
                style: const TextStyle(
                    color: Color(0xFFD0D3E0),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              if (resena.servicioUsado != null) ...[
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kRosa.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(resena.servicioUsado!,
                      style: const TextStyle(
                          color: _kRosa,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Text(_formatFecha(resena.fecha),
                  style: const TextStyle(color: _kMuted, fontSize: 11)),
            ]),
          ],
        ),
      ),
    );
  }

  String _formatFecha(DateTime d) {
    const meses = [
      '',
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    return '${d.day} ${meses[d.month]} ${d.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FILA LISTADO
// ═══════════════════════════════════════════════════════════════════════════
class _FilaResena extends StatelessWidget {
  final ResenaFluix resena;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _FilaResena({
    required this.resena,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorde, width: 0.5),
      ),
      child: Row(children: [
        _Avatar(
            nombre: resena.autorNombre,
            avatarUrl: resena.autorAvatarUrl,
            size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(resena.autorNombre,
                        style: const TextStyle(
                            color: _kTexto,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  _Estrellas(resena.estrellas, size: 13),
                ]),
                const SizedBox(height: 4),
                Text(resena.comentario,
                    style: const TextStyle(
                        color: _kMuted, fontSize: 12, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (resena.servicioUsado != null) ...[
                  const SizedBox(height: 5),
                  Text(resena.servicioUsado!,
                      style: const TextStyle(color: _kRosa, fontSize: 11)),
                ],
              ]),
        ),
        const SizedBox(width: 8),
        Column(children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _kAccent, size: 18),
            onPressed: onEditar,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _kRosa, size: 18),
            onPressed: onEliminar,
            visualDensity: VisualDensity.compact,
          ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO FORMULARIO RESEÑA
// ═══════════════════════════════════════════════════════════════════════════
class _DialogoResena extends StatefulWidget {
  final ResenaFluix? resena;
  const _DialogoResena({this.resena});

  @override
  State<_DialogoResena> createState() => _DialogoResenaState();
}

class _DialogoResenaState extends State<_DialogoResena> {
  final _nombreCtrl = TextEditingController();
  final _comentCtrl = TextEditingController();
  final _servicioCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();
  double _estrellas = 5.0;
  bool _verificado = false;
  DateTime _fecha = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.resena != null) {
      final r = widget.resena!;
      _nombreCtrl.text = r.autorNombre;
      _comentCtrl.text = r.comentario;
      _servicioCtrl.text = r.servicioUsado ?? '';
      _avatarCtrl.text = r.autorAvatarUrl ?? '';
      _estrellas = r.estrellas;
      _verificado = r.verificado;
      _fecha = r.fecha;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _comentCtrl.dispose();
    _servicioCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _kAccent),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _fecha = d);
  }

  String _formatFecha(DateTime d) {
    const meses = [
      '',
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    return '${d.day} de ${meses[d.month]} de ${d.year}';
  }

  bool _puedeGuardar() =>
      _nombreCtrl.text.trim().isNotEmpty &&
          _comentCtrl.text.trim().isNotEmpty;

  void _guardar() {
    Navigator.pop(
      context,
      ResenaFluix(
        id: widget.resena?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        autorNombre: _nombreCtrl.text.trim(),
        autorAvatarUrl: _avatarCtrl.text.trim().isEmpty
            ? null
            : _avatarCtrl.text.trim(),
        estrellas: _estrellas,
        comentario: _comentCtrl.text.trim(),
        fecha: _fecha,
        verificado: _verificado,
        servicioUsado: _servicioCtrl.text.trim().isEmpty
            ? null
            : _servicioCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kCard,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF151932),
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                const Icon(Icons.star_rounded, color: _kOro, size: 22),
                const SizedBox(width: 10),
                Text(
                  widget.resena == null ? 'Nueva resena' : 'Editar resena',
                  style: const TextStyle(
                      color: _kTexto,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
              ]),
            ),
            // Cuerpo
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_nombreCtrl.text.isNotEmpty ||
                        _comentCtrl.text.isNotEmpty)
                      _buildMiniPreview(),
                    _Label('Nombre del cliente *'),
                    TextField(
                      controller: _nombreCtrl,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: _kTexto),
                      decoration: _inputDec('Ej: María García'),
                    ),
                    const SizedBox(height: 14),
                    _Label('Valoración'),
                    _SelectorEstrellas(
                      valor: _estrellas,
                      onChange: (v) => setState(() => _estrellas = v),
                    ),
                    const SizedBox(height: 14),
                    _Label('Comentario *'),
                    TextField(
                      controller: _comentCtrl,
                      maxLines: 4,
                      maxLength: 500,
                      onChanged: (_) => setState(() {}),
                      style:
                      const TextStyle(color: _kTexto, fontSize: 13),
                      decoration: _inputDec(
                          'Escribe el comentario del cliente...'),
                    ),
                    const SizedBox(height: 14),
                    _Label('Servicio usado (opcional)'),
                    TextField(
                      controller: _servicioCtrl,
                      style: const TextStyle(color: _kTexto),
                      decoration: _inputDec('Ej: Corte y color'),
                    ),
                    const SizedBox(height: 14),
                    _Label('URL de foto de perfil (opcional)'),
                    TextField(
                      controller: _avatarCtrl,
                      style:
                      const TextStyle(color: _kTexto, fontSize: 12),
                      decoration: _inputDec('https://...'),
                    ),
                    const SizedBox(height: 14),
                    _Label('Fecha de la resena'),
                    GestureDetector(
                      onTap: _pickFecha,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _kBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_rounded,
                              color: _kAccent, size: 16),
                          const SizedBox(width: 10),
                          Text(_formatFecha(_fecha),
                              style: const TextStyle(
                                  color: _kTexto, fontSize: 13)),
                          const Spacer(),
                          const Icon(Icons.edit_calendar_rounded,
                              color: _kMuted, size: 14),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: _kBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CheckboxListTile(
                        value: _verificado,
                        activeColor: _kAccent,
                        onChanged: (v) =>
                            setState(() => _verificado = v!),
                        title: const Text('Resena verificada',
                            style: TextStyle(
                                color: _kTexto, fontSize: 13)),
                        subtitle: const Text(
                            'Marca si el cliente es real y puedes confirmarlo',
                            style: TextStyle(
                                color: _kMuted, fontSize: 11)),
                        secondary: const Icon(Icons.verified_rounded,
                            color: _kAccent, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Acciones
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF151932),
                borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar',
                        style: TextStyle(color: _kMuted)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _puedeGuardar() ? _guardar : null,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Guardar resena',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kRosa,
                      foregroundColor: _kTexto,
                      disabledBackgroundColor:
                      _kRosa.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.preview_rounded, color: _kAccent, size: 12),
            SizedBox(width: 5),
            Text('Preview',
                style: TextStyle(
                    color: _kAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _Avatar(
                nombre:
                _nombreCtrl.text.isEmpty ? '?' : _nombreCtrl.text,
                avatarUrl: _avatarCtrl.text.isEmpty
                    ? null
                    : _avatarCtrl.text,
                size: 36),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _nombreCtrl.text.isEmpty
                    ? 'Nombre del cliente'
                    : _nombreCtrl.text,
                style: TextStyle(
                    color:
                    _nombreCtrl.text.isEmpty ? _kMuted : _kTexto,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
              const SizedBox(height: 3),
              _Estrellas(_estrellas, size: 13),
            ]),
          ]),
          if (_comentCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${_comentCtrl.text}"',
              style: const TextStyle(
                  color: _kMuted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════════════

class _SelectorEstrellas extends StatelessWidget {
  final double valor;
  final ValueChanged<double> onChange;
  const _SelectorEstrellas({required this.valor, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final estrella = i + 1.0;
          return GestureDetector(
            onTap: () => onChange(estrella),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                valor >= estrella
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: _kOro,
                size: 32,
              ),
            ),
          );
        }),
        const SizedBox(width: 12),
        Text(
          '${valor.toStringAsFixed(0)} / 5',
          style: const TextStyle(
              color: _kOro, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String nombre;
  final String? avatarUrl;
  final double size;
  const _Avatar(
      {required this.nombre,
        required this.avatarUrl,
        required this.size});

  Color get _color {
    const colors = [
      Color(0xFF6C5CE7),
      Color(0xFF00B894),
      Color(0xFFE17055),
      Color(0xFF0984E3),
      Color(0xFFD63031),
      Color(0xFFFDAB3D),
    ];
    final idx =
    nombre.isEmpty ? 0 : nombre.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  String get _iniciales {
    final partes = nombre.trim().split(' ');
    if (partes.isEmpty || partes[0].isEmpty) return '?';
    if (partes.length == 1) return partes[0][0].toUpperCase();
    return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color,
        border: Border.all(color: _kBorde, width: 1.5),
        image: avatarUrl != null
            ? DecorationImage(
          image: NetworkImage(avatarUrl!),
          fit: BoxFit.cover,
          onError: (_, __) {},
        )
            : null,
      ),
      child: avatarUrl == null
          ? Center(
        child: Text(
          _iniciales,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.36,
              fontWeight: FontWeight.bold),
        ),
      )
          : null,
    );
  }
}

class _Estrellas extends StatelessWidget {
  final double valor;
  final double size;
  const _Estrellas(this.valor, {required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final estrella = i + 1.0;
        IconData icono;
        if (valor >= estrella) {
          icono = Icons.star_rounded;
        } else if (valor >= estrella - 0.5) {
          icono = Icons.star_half_rounded;
        } else {
          icono = Icons.star_border_rounded;
        }
        return Icon(icono, color: _kOro, size: size);
      }),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(
            color: _kAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600)),
  );
}

InputDecoration _inputDec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFF5A5D72), fontSize: 13),
  filled: true,
  fillColor: _kBg,
  contentPadding:
  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide.none,
  ),
);