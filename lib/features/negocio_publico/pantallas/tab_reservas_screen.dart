import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/negocio_publico_model.dart';

// ═══════════════════════════════════════════════════════════════════
// COLORES (mismo design system que DetalleNegocioScreen)
// ═══════════════════════════════════════════════════════════════════
class _C {
  static const negro      = Color(0xFF0A0F23);
  static const grisOscuro = Color(0xFF151932);
  static const grisMedio  = Color(0xFF1E2139);
  static const grisClaro  = Color(0xFF2A2E45);
  static const accent     = Color(0xFF00FFC8);
  static const accentRosa = Color(0xFFFF3296);
  static const oro        = Color(0xFFFFB830);
  static const texto      = Color(0xFFFFFFFF);
  static const textoMuted = Color(0xFFB0B3C1);
  static const textoHint  = Color(0xFF6B6E82);

  // Colores de carga calendario
  static const cargaLibre     = Color(0xFF00C896); // verde  — 0 reservas
  static const cargaBaja      = Color(0xFFFFD166); // amarillo — 1–4
  static const cargaMedia     = Color(0xFFFF9A3C); // naranja — 5–9
  static const cargaAlta      = Color(0xFFFF4444); // rojo   — 10+
}

// ═══════════════════════════════════════════════════════════════════
// MODELO INTERNO
// ═══════════════════════════════════════════════════════════════════
class _ServicioUI {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? categoria;
  final double? precio;
  final double? precioDesde;
  final int? duracion;
  final String? publico; // 'masculino' | 'femenino' | 'todos'
  final String? imagenUrl; // ← NUEVO: URL de imagen del servicio
  final bool activo;

  const _ServicioUI({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.categoria,
    this.precio,
    this.precioDesde,
    this.duracion,
    this.publico,
    this.imagenUrl,
    this.activo = true,
  });

  factory _ServicioUI.fromMap(String id, Map<String, dynamic> d) => _ServicioUI(
    id: id,
    nombre: d['nombre'] as String? ?? '',
    descripcion: d['descripcion'] as String?,
    categoria: d['categoria'] as String?,
    precio: (d['precio'] as num?)?.toDouble(),
    precioDesde: (d['precio_desde'] as num?)?.toDouble(),
    duracion: d['duracion'] as int?,
    publico: d['publico'] as String?,
    imagenUrl: d['imagen_url'] as String?,
    activo: d['activo'] as bool? ?? true,
  );

  String get precioTexto {
    if (precio != null) return '€${precio!.toStringAsFixed(precio! % 1 == 0 ? 0 : 2)}';
    if (precioDesde != null) return 'Desde €${precioDesde!.toStringAsFixed(precioDesde! % 1 == 0 ? 0 : 2)}';
    return 'Consultar';
  }

  String get duracionTexto {
    if (duracion == null) return '';
    if (duracion! >= 60) {
      final h = duracion! ~/ 60;
      final m = duracion! % 60;
      return m > 0 ? '${h}h ${m}min' : '${h}h';
    }
    return '${duracion}min';
  }

  IconData get icono {
    switch ((categoria ?? '').toLowerCase()) {
      case 'corte': case 'pelo': return Icons.content_cut_rounded;
      case 'color': case 'tinte': return Icons.color_lens_rounded;
      case 'manicura': case 'pedicura': case 'uñas': return Icons.spa_rounded;
      case 'masaje': case 'relajacion': return Icons.self_improvement_rounded;
      case 'facial': case 'estetica': return Icons.face_retouching_natural_rounded;
      case 'barba': case 'barberia': return Icons.face_rounded;
      case 'cejas': case 'depilacion': return Icons.auto_fix_high_rounded;
      default: return Icons.star_rounded;
    }
  }

  Color get publicoColor {
    switch ((publico ?? '').toLowerCase()) {
      case 'masculino': case 'hombre': return const Color(0xFF4A9EFF);
      case 'femenino': case 'mujer': return _C.accentRosa;
      default: return _C.accent;
    }
  }

  String get publicoLabel {
    switch ((publico ?? '').toLowerCase()) {
      case 'masculino': case 'hombre': return 'Hombre';
      case 'femenino': case 'mujer': return 'Mujer';
      default: return 'Todos';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL — TAB RESERVAS
// ═══════════════════════════════════════════════════════════════════
class TabReservasScreen extends StatefulWidget {
  final NegocioPublico negocio;
  const TabReservasScreen({super.key, required this.negocio});

  @override
  State<TabReservasScreen> createState() => _TabReservasScreenState();
}

class _TabReservasScreenState extends State<TabReservasScreen> {
  String? _categoriaSeleccionada;
  _ServicioUI? _servicioSeleccionado;

  // Controlador para el DraggableScrollable del booking sheet
  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  void _seleccionarServicio(_ServicioUI s) {
    setState(() => _servicioSeleccionado = s);
  }

  void _cerrarSheet() {
    setState(() => _servicioSeleccionado = null);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Fondo: lista de servicios ──────────────────────────
        _CuerpoServicios(
          negocio: widget.negocio,
          categoriaActiva: _categoriaSeleccionada,
          onCategoriaChanged: (c) => setState(() => _categoriaSeleccionada = c),
          onServicioTap: _seleccionarServicio,
          bloqueado: _servicioSeleccionado != null,
        ),

        // ── Overlay oscuro cuando el sheet está abierto ────────
        if (_servicioSeleccionado != null)
          GestureDetector(
            onTap: _cerrarSheet,
            child: AnimatedOpacity(
              opacity: _servicioSeleccionado != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),

        // ── Sheet de booking ───────────────────────────────────
        if (_servicioSeleccionado != null)
          _BookingSheet(
            negocio: widget.negocio,
            servicio: _servicioSeleccionado!,
            onClose: _cerrarSheet,
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CUERPO — LISTA DE SERVICIOS CON FILTROS POR CATEGORÍA
// ═══════════════════════════════════════════════════════════════════
class _CuerpoServicios extends StatelessWidget {
  final NegocioPublico negocio;
  final String? categoriaActiva;
  final ValueChanged<String?> onCategoriaChanged;
  final ValueChanged<_ServicioUI> onServicioTap;
  final bool bloqueado;

  const _CuerpoServicios({
    required this.negocio,
    required this.categoriaActiva,
    required this.onCategoriaChanged,
    required this.onServicioTap,
    required this.bloqueado,
  });

  @override
  Widget build(BuildContext context) {
    // Fuente única: empresas/{empresaIdVinculada}/servicios (mismo módulo de Mi App)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(negocio.empresaIdVinculada)
          .collection('servicios')
          .orderBy('nombre')
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.accent));
        }

        final todos = (snap.data?.docs ?? [])
            .map((d) => _ServicioUI.fromMap(d.id, d.data() as Map<String, dynamic>))
            .where((s) => s.activo)
            .toList();

        if (todos.isEmpty) {
          return _EmptyServicios();
        }

        // Categorías únicas (manteniendo orden de aparición)
        final cats = <String>[];
        for (final s in todos) {
          final c = s.categoria?.trim() ?? '';
          if (c.isNotEmpty && !cats.contains(c)) cats.add(c);
        }

        final filtrados = categoriaActiva == null
            ? todos
            : todos.where((s) => s.categoria == categoriaActiva).toList();

        return AbsorbPointer(
          absorbing: bloqueado,
          child: CustomScrollView(
            physics: bloqueado
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────
              SliverToBoxAdapter(child: _Header(nombre: negocio.nombre, total: todos.length)),

              // ── Chips de categoría ───────────────────────────
              if (cats.isNotEmpty)
                SliverToBoxAdapter(
                  child: _CategoriasChips(
                    categorias: cats,
                    activa: categoriaActiva,
                    onTap: (c) => onCategoriaChanged(categoriaActiva == c ? null : c),
                  ),
                ),

              // ── Grid de servicios ────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _CardServicio(
                      servicio: filtrados[i],
                      onTap: () => onServicioTap(filtrados[i]),
                    ),
                    childCount: filtrados.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String nombre;
  final int total;
  const _Header({required this.nombre, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Reservar cita',
                  style: TextStyle(
                      color: _C.texto, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('$total servicios disponibles',
                  style: const TextStyle(color: _C.textoMuted, fontSize: 13)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF00FFC8), Color(0xFF00D4AA)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: _C.negro),
              SizedBox(width: 5),
              Text('Agenda', style: TextStyle(
                  color: _C.negro, fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Chips categorías ────────────────────────────────────────────────
class _CategoriasChips extends StatelessWidget {
  final List<String> categorias;
  final String? activa;
  final ValueChanged<String> onTap;
  const _CategoriasChips(
      {required this.categorias, required this.activa, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          // "Todos"
          _Chip(
            label: 'Todos',
            activo: activa == null,
            onTap: () => onTap(''),
          ),
          const SizedBox(width: 8),
          ...categorias.map((c) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _Chip(
              label: c,
              activo: activa == c,
              onTap: () => onTap(c),
            ),
          )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? _C.accent : _C.grisOscuro,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? _C.accent : _C.grisClaro,
            width: activo ? 0 : 0.8,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: activo ? _C.negro : _C.textoMuted,
              fontSize: 13,
              fontWeight: activo ? FontWeight.w800 : FontWeight.w500,
            )),
      ),
    );
  }
}

// ── Card Servicio ────────────────────────────────────────────────────
class _CardServicio extends StatelessWidget {
  final _ServicioUI servicio;
  final VoidCallback onTap;
  const _CardServicio({required this.servicio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _C.grisOscuro,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.grisClaro, width: 0.8),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Barra lateral accent
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: servicio.publicoColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),

              // Imagen o icono
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: servicio.imagenUrl != null && servicio.imagenUrl!.isNotEmpty
                        ? Colors.transparent
                        : servicio.publicoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    image: servicio.imagenUrl != null && servicio.imagenUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(servicio.imagenUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: servicio.imagenUrl == null || servicio.imagenUrl!.isEmpty
                      ? Icon(servicio.icono, size: 26, color: servicio.publicoColor)
                      : null,
                ),
              ),

              // Contenido
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre + público
                      Row(children: [
                        Expanded(
                          child: Text(servicio.nombre,
                              style: const TextStyle(
                                  color: _C.texto,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ),
                        // Badge público
                        _BadgePublico(
                            label: servicio.publicoLabel,
                            color: servicio.publicoColor),
                      ]),

                      if (servicio.descripcion?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(servicio.descripcion!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _C.textoMuted, fontSize: 12, height: 1.4)),
                      ],

                      const SizedBox(height: 10),

                      // Precio + duración + CTA
                      Row(children: [
                        // Precio
                        Text(servicio.precioTexto,
                            style: TextStyle(
                                color: servicio.publicoColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),

                        if (servicio.duracionTexto.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _C.grisMedio,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 11, color: _C.textoHint),
                              const SizedBox(width: 3),
                              Text(servicio.duracionTexto,
                                  style: const TextStyle(
                                      color: _C.textoHint, fontSize: 11)),
                            ]),
                          ),
                        ],

                        const Spacer(),

                        // Botón reservar
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                servicio.publicoColor,
                                servicio.publicoColor.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Reservar',
                              style: TextStyle(
                                  color: _C.negro,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ],
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

class _BadgePublico extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgePublico({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyServicios extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _C.grisOscuro,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.content_cut_rounded,
              size: 36, color: _C.textoHint),
        ),
        const SizedBox(height: 16),
        const Text('Sin servicios disponibles',
            style: TextStyle(color: _C.textoMuted, fontSize: 15)),
        const SizedBox(height: 6),
        const Text('El negocio aún no ha añadido servicios',
            style: TextStyle(color: _C.textoHint, fontSize: 12)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOOKING SHEET — sube desde abajo con AnimatedPositioned
// ═══════════════════════════════════════════════════════════════════
class _BookingSheet extends StatefulWidget {
  final NegocioPublico negocio;
  final _ServicioUI servicio;
  final VoidCallback onClose;

  const _BookingSheet({
    required this.negocio,
    required this.servicio,
    required this.onClose,
  });

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

// Pasos del flow
enum _Paso { calendario, hora, profesional, confirmacion }

class _BookingSheetState extends State<_BookingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<Offset> _slide;

  _Paso _paso = _Paso.calendario;
  DateTime? _diaSeleccionado;
  String? _horaSeleccionada;
  String? _profesionalId;  // ← Guardamos ID en lugar de nombre
  String? _profesionalNombre;  // ← Nombre para mostrar

  // Cache de conteos de reservas por día (date-string → int)
  final Map<String, int> _cargaDias = {};
  bool _cargandoCarga = true;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
    _cargarCargaCalendario();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // Carga cuántas reservas hay por día para el mes actual y el siguiente
  Future<void> _cargarCargaCalendario() async {
    if (mounted) setState(() => _cargandoCarga = false);
    final empresaId = widget.negocio.empresaIdVinculada;
    if (empresaId.isEmpty) return;

    final now = DateTime.now();
    final inicio = DateTime(now.year, now.month, 1);
    final fin = DateTime(now.year, now.month + 2, 0);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .where('fecha_hora',
          isGreaterThanOrEqualTo: Timestamp.fromDate(inicio),
          isLessThanOrEqualTo: Timestamp.fromDate(fin))
          .where('servicio_id', isEqualTo: widget.servicio.id)
          .get();

      final Map<String, int> conteos = {};
      for (final doc in snap.docs) {
        final ts = doc.data()['fecha_hora'] as Timestamp?;
        if (ts == null) continue;
        final d = ts.toDate();
        final key = '${d.year}-${d.month}-${d.day}';
        conteos[key] = (conteos[key] ?? 0) + 1;
      }

      if (mounted) setState(() => _cargaDias.addAll(conteos));
    } catch (_) {}
  }

  Color _colorCarga(int reservas) {
    if (reservas == 0) return _C.cargaLibre;
    if (reservas < 5)  return _C.cargaBaja;
    if (reservas < 10) return _C.cargaMedia;
    return _C.cargaAlta;
  }

  int _reservasDia(DateTime d) =>
      _cargaDias['${d.year}-${d.month}-${d.day}'] ?? 0;

  Future<void> _cerrar() async {
    await _anim.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: SlideTransition(
        position: _slide,
        child: Container(
          constraints: BoxConstraints(maxHeight: screenH * 0.88),
          decoration: const BoxDecoration(
            color: Color(0xFF131728),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black54,
                  blurRadius: 40,
                  offset: Offset(0, -8)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle + header
            _SheetHeader(
              servicio: widget.servicio,
              paso: _paso,
              onClose: _cerrar,
            ),

            // Indicador de pasos
            _PasoIndicador(paso: _paso),

            // Contenido según paso
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _buildPaso(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPaso() {
    switch (_paso) {
      case _Paso.calendario:
        return _PasoCalendario(
          key: const ValueKey('cal'),
          colorCarga: _colorCarga,
          reservasDia: _reservasDia,
          cargando: _cargandoCarga,
          onDiaSeleccionado: (d) => setState(() {
            _diaSeleccionado = d;
            _paso = _Paso.hora;
          }),
        );

      case _Paso.hora:
        return _PasoHora(
          key: const ValueKey('hora'),
          negocio: widget.negocio,
          servicio: widget.servicio,
          dia: _diaSeleccionado!,
          onHoraSeleccionada: (h) => setState(() {
            _horaSeleccionada = h;
            _paso = _Paso.profesional;
          }),
          onVolver: () => setState(() {
            _diaSeleccionado = null;
            _paso = _Paso.calendario;
          }),
        );

      case _Paso.profesional:
        return _PasoProfesional(
          key: const ValueKey('pro'),
          negocio: widget.negocio,
          onProfesionalSeleccionado: (datos) => setState(() {
            _profesionalId = datos['id'] as String;
            _profesionalNombre = datos['nombre'] as String;
            _paso = _Paso.confirmacion;
          }),
          onVolver: () => setState(() {
            _horaSeleccionada = null;
            _paso = _Paso.hora;
          }),
        );

      case _Paso.confirmacion:
        return _PasoConfirmacion(
          key: const ValueKey('conf'),
          negocio: widget.negocio,
          servicio: widget.servicio,
          dia: _diaSeleccionado!,
          hora: _horaSeleccionada!,
          profesionalNombre: _profesionalNombre!,
          onConfirmar: _confirmarReserva,
          onVolver: () => setState(() {
            _profesionalId = null;
            _profesionalNombre = null;
            _paso = _Paso.profesional;
          }),
        );
    }
  }

  Future<void> _confirmarReserva() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Inicia sesión para confirmar la reserva'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    try {
      // Combinar día + hora
      final partes = _horaSeleccionada!.split(':');
      final fechaHora = DateTime(
        _diaSeleccionado!.year,
        _diaSeleccionado!.month,
        _diaSeleccionado!.day,
        int.parse(partes[0]),
        int.parse(partes[1]),
      );

      final user = FirebaseAuth.instance.currentUser;
      final clienteNombre = user?.displayName ?? user?.email?.split('@').first ?? 'Cliente';
      final clienteEmail = user?.email ?? '';

      // Crear reserva en Firestore — si hay empresa vinculada, allí; si no, en negocios_publicos
      final empresaId = widget.negocio.empresaIdVinculada;
      final reservasCol = empresaId.isNotEmpty
          ? FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('reservas')
          : FirebaseFirestore.instance.collection('negocios_publicos').doc(widget.negocio.id).collection('reservas');
      final citaRef = await reservasCol.add({
        // Datos del cliente
        'cliente_uid': uid,
        'cliente_nombre': clienteNombre,
        'cliente_email': clienteEmail,
        
        // Datos de la reserva
        'servicio_id': widget.servicio.id,
        'servicio_nombre': widget.servicio.nombre,
        'empleado_id': _profesionalId,
        'empleado_nombre': _profesionalNombre,
        'fecha_hora': Timestamp.fromDate(fechaHora),
        'duracion': widget.servicio.duracion,
        'precio': widget.servicio.precio ?? widget.servicio.precioDesde,
        
        // Estado y metadata
        'estado': 'pendiente',  // ← Owner debe aceptar/rechazar
        'origen': 'fluix_b2c',
        'negocio_id': widget.negocio.id,
        'negocio_nombre': widget.negocio.nombre,
        'fecha_creacion': FieldValue.serverTimestamp(),
        'modificado_en': FieldValue.serverTimestamp(),
      });

      // Crear notificación para el owner
      final notifCol = empresaId.isNotEmpty
          ? FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('notificaciones_reservas')
          : FirebaseFirestore.instance.collection('negocios_publicos').doc(widget.negocio.id).collection('notificaciones_reservas');
      await notifCol.add({
        'reserva_id': citaRef.id,
        'tipo': 'nueva_reserva_b2c',
        'cliente_nombre': clienteNombre,
        'servicio_nombre': widget.servicio.nombre,
        'fecha_hora': Timestamp.fromDate(fechaHora),
        'leida': false,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        await _cerrar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: _C.negro),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¡Reserva enviada!',
                      style: TextStyle(color: _C.negro, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('El negocio confirmará tu reserva pronto',
                      style: TextStyle(color: _C.negro, fontSize: 11)),
                ],
              ),
            ),
          ]),
          backgroundColor: _C.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al confirmar: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ── Header del sheet ────────────────────────────────────────────────
class _SheetHeader extends StatelessWidget {
  final _ServicioUI servicio;
  final _Paso paso;
  final VoidCallback onClose;
  const _SheetHeader(
      {required this.servicio, required this.paso, required this.onClose});

  String get _titulo {
    switch (paso) {
      case _Paso.calendario:   return 'Elige fecha';
      case _Paso.hora:         return 'Elige hora';
      case _Paso.profesional:  return 'Elige profesional';
      case _Paso.confirmacion: return 'Confirmar reserva';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(children: [
        // Handle
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: _C.grisClaro, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),

        Row(children: [
          // Icono servicio
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: servicio.publicoColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(servicio.icono, size: 20, color: servicio.publicoColor),
          ),
          const SizedBox(width: 12),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_titulo,
                style: const TextStyle(
                    color: _C.texto, fontSize: 17, fontWeight: FontWeight.w800)),
            Text(servicio.nombre,
                style: TextStyle(color: servicio.publicoColor, fontSize: 12)),
          ])),

          // Precio
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(servicio.precioTexto,
                style: TextStyle(
                    color: servicio.publicoColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            if (servicio.duracionTexto.isNotEmpty)
              Text(servicio.duracionTexto,
                  style: const TextStyle(color: _C.textoHint, fontSize: 11)),
          ]),

          const SizedBox(width: 12),

          // Cerrar
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _C.grisClaro,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded, size: 16, color: _C.textoMuted),
            ),
          ),
        ]),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ── Indicador de pasos ───────────────────────────────────────────────
class _PasoIndicador extends StatelessWidget {
  final _Paso paso;
  const _PasoIndicador({required this.paso});

  @override
  Widget build(BuildContext context) {
    final pasos = ['Fecha', 'Hora', 'Profesional', 'Confirmar'];
    final idx = _Paso.values.indexOf(paso);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(children: List.generate(pasos.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Línea
          final lineaIdx = i ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: lineaIdx < idx
                  ? _C.accent
                  : _C.grisClaro,
            ),
          );
        }
        final pIdx = i ~/ 2;
        final activo = pIdx == idx;
        final completado = pIdx < idx;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completado
                  ? _C.accent
                  : activo
                  ? _C.accent.withValues(alpha: 0.2)
                  : _C.grisClaro,
              border: Border.all(
                color: activo ? _C.accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: completado
                  ? const Icon(Icons.check_rounded, size: 14, color: _C.negro)
                  : Text('${pIdx + 1}',
                  style: TextStyle(
                      color: activo ? _C.accent : _C.textoHint,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 3),
          Text(pasos[pIdx],
              style: TextStyle(
                  color: activo ? _C.accent : _C.textoHint,
                  fontSize: 9,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w400)),
        ]);
      })),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PASO 1 — CALENDARIO CON COLORES DE CARGA
// ═══════════════════════════════════════════════════════════════════
class _PasoCalendario extends StatefulWidget {
  final Color Function(int) colorCarga;
  final int Function(DateTime) reservasDia;
  final bool cargando;
  final ValueChanged<DateTime> onDiaSeleccionado;

  const _PasoCalendario({
    super.key,
    required this.colorCarga,
    required this.reservasDia,
    required this.cargando,
    required this.onDiaSeleccionado,
  });

  @override
  State<_PasoCalendario> createState() => _PasoCalendarioState();
}

class _PasoCalendarioState extends State<_PasoCalendario> {
  late DateTime _mesVisible;

  @override
  void initState() {
    super.initState();
    _mesVisible = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        // Leyenda de colores
        _Leyenda(),

        const SizedBox(height: 16),

        // Cabecera mes
        _MesHeader(
          mes: _mesVisible,
          onAnterior: () => setState(() =>
          _mesVisible = DateTime(_mesVisible.year, _mesVisible.month - 1)),
          onSiguiente: () => setState(() =>
          _mesVisible = DateTime(_mesVisible.year, _mesVisible.month + 1)),
          puedeRetroceder: _mesVisible.isAfter(
              DateTime(hoy.year, hoy.month - 1)),
        ),

        const SizedBox(height: 12),

        // Días de la semana
        _DiasHeader(),

        const SizedBox(height: 6),

        // Grid del mes
        _GridMes(
          mes: _mesVisible,
          hoy: hoy,
          colorCarga: widget.colorCarga,
          reservasDia: widget.reservasDia,
          cargando: widget.cargando,
          onDiaTap: widget.onDiaSeleccionado,
        ),
      ]),
    );
  }
}

class _Leyenda extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (color: _C.cargaLibre,  label: 'Libre'),
      (color: _C.cargaBaja,   label: 'Poco trabajo'),
      (color: _C.cargaMedia,  label: 'Algo ocupado'),
      (color: _C.cargaAlta,   label: 'Muy ocupado'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.grisOscuro,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: item.color),
          ),
          const SizedBox(width: 5),
          Text(item.label,
              style: const TextStyle(color: _C.textoHint, fontSize: 10)),
        ])).toList(),
      ),
    );
  }
}

class _MesHeader extends StatelessWidget {
  final DateTime mes;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;
  final bool puedeRetroceder;

  const _MesHeader({
    required this.mes,
    required this.onAnterior,
    required this.onSiguiente,
    required this.puedeRetroceder,
  });

  static const _meses = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
        onPressed: puedeRetroceder ? onAnterior : null,
        icon: const Icon(Icons.chevron_left_rounded),
        color: puedeRetroceder ? _C.texto : _C.textoHint,
        iconSize: 22,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      Expanded(
        child: Text(
          '${_meses[mes.month]} ${mes.year}',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: _C.texto, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      IconButton(
        onPressed: onSiguiente,
        icon: const Icon(Icons.chevron_right_rounded),
        color: _C.texto,
        iconSize: 22,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    ]);
  }
}

class _DiasHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Row(
      children: dias.map((d) => Expanded(
        child: Center(
          child: Text(d,
              style: TextStyle(
                  color: (d == 'S' || d == 'D')
                      ? _C.accentRosa.withValues(alpha: 0.7)
                      : _C.textoHint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      )).toList(),
    );
  }
}

class _GridMes extends StatelessWidget {
  final DateTime mes;
  final DateTime hoy;
  final Color Function(int) colorCarga;
  final int Function(DateTime) reservasDia;
  final bool cargando;
  final ValueChanged<DateTime> onDiaTap;

  const _GridMes({
    required this.mes,
    required this.hoy,
    required this.colorCarga,
    required this.reservasDia,
    required this.cargando,
    required this.onDiaTap,
  });

  @override
  Widget build(BuildContext context) {
    // Primer día del mes (1=lunes, 7=domingo)
    final primerDia = DateTime(mes.year, mes.month, 1);
    final diasEnMes = DateTime(mes.year, mes.month + 1, 0).day;
    final offset = (primerDia.weekday - 1); // 0 para lunes

    final celdas = offset + diasEnMes;
    final filas = (celdas / 7).ceil();

    return Column(
      children: List.generate(filas, (fila) {
        return Row(
          children: List.generate(7, (col) {
            final celda = fila * 7 + col;
            final numDia = celda - offset + 1;

            if (numDia < 1 || numDia > diasEnMes) {
              return const Expanded(child: SizedBox(height: 52));
            }

            final fecha = DateTime(mes.year, mes.month, numDia);
            final esPasado = fecha.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
            final esHoy = fecha.year == hoy.year &&
                fecha.month == hoy.month &&
                fecha.day == hoy.day;
            final esFinDeSemana = fecha.weekday >= 6;
            final reservas = reservasDia(fecha);
            final color = cargando ? _C.grisClaro : colorCarga(reservas);

            return Expanded(
              child: GestureDetector(
                onTap: esPasado ? null : () => onDiaTap(fecha),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.all(2),
                  height: 52,
                  decoration: BoxDecoration(
                    color: esPasado
                        ? _C.grisOscuro.withValues(alpha: 0.4)
                        : esHoy
                        ? _C.negro
                        : _C.grisOscuro,
                    borderRadius: BorderRadius.circular(10),
                    border: esHoy
                        ? Border.all(color: _C.accent, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$numDia',
                          style: TextStyle(
                            color: esPasado
                                ? _C.textoHint.withValues(alpha: 0.3)
                                : esFinDeSemana
                                ? _C.accentRosa.withValues(alpha: 0.7)
                                : _C.texto,
                            fontSize: 15,
                            fontWeight: esHoy
                                ? FontWeight.w800
                                : FontWeight.w500,
                          )),
                      const SizedBox(height: 3),
                      // Indicador de carga
                      if (!esPasado)
                        Container(
                          width: cargando ? 16 : 20,
                          height: 4,
                          decoration: BoxDecoration(
                            color: cargando
                                ? _C.grisClaro
                                : color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PASO 2 — SELECCIÓN DE HORA
// ═══════════════════════════════════════════════════════════════════
class _PasoHora extends StatelessWidget {
  final NegocioPublico negocio;
  final _ServicioUI servicio;
  final DateTime dia;
  final ValueChanged<String> onHoraSeleccionada;
  final VoidCallback onVolver;

  const _PasoHora({
    super.key,
    required this.negocio,
    required this.servicio,
    required this.dia,
    required this.onHoraSeleccionada,
    required this.onVolver,
  });

  // Genera slots en base al horario del negocio
  // Por ahora genera slots fijos; en producción leer de horarios del negocio
  List<String> _generarSlots() {
    final slots = <String>[];
    // Mañana: 9:00 - 14:00 cada 30min
    for (int h = 9; h < 14; h++) {
      slots.add('${h.toString().padLeft(2, '0')}:00');
      slots.add('${h.toString().padLeft(2, '0')}:30');
    }
    // Tarde: 16:00 - 20:00 cada 30min
    for (int h = 16; h < 20; h++) {
      slots.add('${h.toString().padLeft(2, '0')}:00');
      slots.add('${h.toString().padLeft(2, '0')}:30');
    }
    return slots;
  }

  static const _meses = [
    '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  Widget build(BuildContext context) {
    final slots = _generarSlots();
    final ahora = DateTime.now();
    final esDiaHoy = dia.year == ahora.year &&
        dia.month == ahora.month &&
        dia.day == ahora.day;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Día seleccionado
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.grisOscuro,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: _C.accent),
            const SizedBox(width: 10),
            Text(
              '${dia.day} de ${_meses[dia.month]} de ${dia.year}',
              style: const TextStyle(
                  color: _C.texto, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onVolver,
              child: const Text('Cambiar',
                  style: TextStyle(color: _C.accent, fontSize: 12)),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        const Text('Mañana',
            style: TextStyle(color: _C.textoMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),

        // Slots mañana
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: slots.where((s) => int.parse(s.split(':')[0]) < 14).map((slot) {
            final hora = int.parse(slot.split(':')[0]);
            final min = int.parse(slot.split(':')[1]);
            final slotDt = DateTime(dia.year, dia.month, dia.day, hora, min);
            final pasado = esDiaHoy && slotDt.isBefore(ahora);
            return _SlotHora(
                hora: slot, disponible: !pasado, onTap: () => onHoraSeleccionada(slot));
          }).toList(),
        ),

        const SizedBox(height: 20),

        const Text('Tarde',
            style: TextStyle(color: _C.textoMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: slots.where((s) => int.parse(s.split(':')[0]) >= 16).map((slot) {
            final hora = int.parse(slot.split(':')[0]);
            final min = int.parse(slot.split(':')[1]);
            final slotDt = DateTime(dia.year, dia.month, dia.day, hora, min);
            final pasado = esDiaHoy && slotDt.isBefore(ahora);
            return _SlotHora(
                hora: slot, disponible: !pasado, onTap: () => onHoraSeleccionada(slot));
          }).toList(),
        ),
      ]),
    );
  }
}

class _SlotHora extends StatelessWidget {
  final String hora;
  final bool disponible;
  final VoidCallback onTap;
  const _SlotHora(
      {required this.hora, required this.disponible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disponible ? onTap : null,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: disponible ? _C.grisOscuro : _C.negro.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disponible ? _C.grisClaro : _C.negro,
            width: 0.8,
          ),
        ),
        child: Center(
          child: Text(hora,
              style: TextStyle(
                  color: disponible ? _C.texto : _C.textoHint,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PASO 3 — SELECCIÓN DE PROFESIONAL
// ═══════════════════════════════════════════════════════════════════
class _PasoProfesional extends StatelessWidget {
  final NegocioPublico negocio;
  final ValueChanged<Map<String, String>> onProfesionalSeleccionado;
  final VoidCallback onVolver;

  const _PasoProfesional({
    super.key,
    required this.negocio,
    required this.onProfesionalSeleccionado,
    required this.onVolver,
  });

  @override
  Widget build(BuildContext context) {
    // Cargar empleados desde la colección usuarios (sistema real de empleados)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('empresa_id', isEqualTo: negocio.empresaIdVinculada)
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _C.accent));
        }

        final docs = snap.data?.docs ?? [];

        // Si no hay profesionales configurados → "Cualquier profesional"
        final items = docs.isEmpty
            ? <Map<String, dynamic>>[
          {'id': 'cualquiera', 'nombre': 'Cualquier profesional', 'auto': true}
        ]
            : [
          {'id': 'cualquiera', 'nombre': 'Cualquier profesional', 'auto': true},
          ...docs.map((d) => {
            'id': d.id,
            ...d.data() as Map<String, dynamic>,
          }),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(children: [
            ...items.map((emp) {
              final nombre = emp['nombre'] as String? ?? 'Sin nombre';
              final rol = emp['rol'] as String? ?? emp['cargo'] as String? ?? '';
              final avatarUrl = emp['avatarUrl'] as String? ?? emp['foto_url'] as String?;
              final esAuto = emp['auto'] as bool? ?? false;

              return GestureDetector(
                onTap: () => onProfesionalSeleccionado({
                  'id': emp['id'] as String,
                  'nombre': nombre,
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _C.grisOscuro,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.grisClaro, width: 0.8),
                  ),
                  child: Row(children: [
                    // Avatar
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: esAuto
                            ? _C.accent.withValues(alpha: 0.1)
                            : _C.grisMedio,
                        border: Border.all(color: _C.grisClaro, width: 1.5),
                        image: avatarUrl != null
                            ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover)
                            : null,
                      ),
                      child: avatarUrl == null
                          ? Center(
                        child: esAuto
                            ? const Icon(Icons.shuffle_rounded,
                            size: 18, color: _C.accent)
                            : Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: _C.texto,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                          : null,
                    ),

                    const SizedBox(width: 12),

                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nombre,
                          style: const TextStyle(
                              color: _C.texto,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      if (rol.isNotEmpty)
                        Text(rol,
                            style: const TextStyle(
                                color: _C.textoMuted, fontSize: 12)),
                      if (esAuto)
                        const Text('Asignado automáticamente',
                            style: TextStyle(
                                color: _C.textoHint, fontSize: 11)),
                    ])),

                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: _C.textoHint),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 8),
            TextButton(
              onPressed: onVolver,
              child: const Text('← Cambiar hora',
                  style: TextStyle(color: _C.textoMuted, fontSize: 13)),
            ),
          ]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PASO 4 — CONFIRMACIÓN
// ═══════════════════════════════════════════════════════════════════
class _PasoConfirmacion extends StatelessWidget {
  final NegocioPublico negocio;
  final _ServicioUI servicio;
  final DateTime dia;
  final String hora;
  final String profesionalNombre;
  final VoidCallback onConfirmar;
  final VoidCallback onVolver;

  const _PasoConfirmacion({
    super.key,
    required this.negocio,
    required this.servicio,
    required this.dia,
    required this.hora,
    required this.profesionalNombre,
    required this.onConfirmar,
    required this.onVolver,
  });

  static const _dias = ['', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _meses = [
    '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(children: [
        // Resumen
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _C.grisOscuro,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.accent.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            // Icono centrado
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: _C.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(servicio.icono, size: 26, color: _C.accent),
            ),
            const SizedBox(height: 14),
            Text(servicio.nombre,
                style: const TextStyle(
                    color: _C.texto, fontSize: 18, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(negocio.nombre,
                style: const TextStyle(color: _C.textoMuted, fontSize: 13),
                textAlign: TextAlign.center),

            const SizedBox(height: 20),
            const Divider(color: _C.grisClaro, height: 1),
            const SizedBox(height: 16),

            // Detalles
            _fila(Icons.calendar_today_rounded,
                '${_dias[dia.weekday]}, ${dia.day} de ${_meses[dia.month]}'),
            const SizedBox(height: 10),
            _fila(Icons.access_time_rounded, hora),
            const SizedBox(height: 10),
            _fila(Icons.person_rounded, profesionalNombre),
            if (servicio.duracionTexto.isNotEmpty) ...[
              const SizedBox(height: 10),
              _fila(Icons.timelapse_rounded, servicio.duracionTexto),
            ],

            const SizedBox(height: 16),
            const Divider(color: _C.grisClaro, height: 1),
            const SizedBox(height: 16),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total',
                  style: TextStyle(
                      color: _C.texto, fontSize: 16, fontWeight: FontWeight.w700)),
              Text(servicio.precioTexto,
                  style: const TextStyle(
                      color: _C.accent, fontSize: 20, fontWeight: FontWeight.w900)),
            ]),
          ]),
        ),

        const SizedBox(height: 20),

        // Nota legal
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _C.accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.accent.withValues(alpha: 0.15)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 14, color: _C.accent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Al confirmar aceptas los términos y condiciones del negocio.',
                style: TextStyle(color: _C.textoMuted, fontSize: 11, height: 1.4),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // Botón confirmar
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onConfirmar,
            style: FilledButton.styleFrom(
              backgroundColor: _C.accent,
              foregroundColor: _C.negro,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_outline_rounded, size: 18),
              SizedBox(width: 8),
              Text('Confirmar reserva',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),

        const SizedBox(height: 10),

        TextButton(
          onPressed: onVolver,
          child: const Text('← Cambiar profesional',
              style: TextStyle(color: _C.textoMuted, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _fila(IconData icon, String texto) => Row(children: [
    Icon(icon, size: 15, color: _C.accentRosa),
    const SizedBox(width: 10),
    Text(texto,
        style: const TextStyle(color: _C.texto, fontSize: 14)),
  ]);
}