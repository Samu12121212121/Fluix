import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../../services/google_reviews_service.dart';
import '../../../services/respuesta_gmb_service.dart';
import '../../../services/demo_cuenta_service.dart';
import 'estado_conexion_google_widget.dart';
import 'estado_respuesta_widget.dart';
import 'grafico_evolucion_rating_widget.dart';
import 'kpis_rating_widget.dart';
import '../pantallas/configurar_google_reviews_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal de valoraciones
// ─────────────────────────────────────────────────────────────────────────────

class ModuloValoraciones extends StatefulWidget {
  final String empresaId;
  const ModuloValoraciones({super.key, required this.empresaId});

  @override
  State<ModuloValoraciones> createState() => _ModuloValoracionesState();
}

class _ModuloValoracionesState extends State<ModuloValoraciones> {
  final _svc = GoogleReviewsService();
  final List<Map<String, dynamic>> _resenas = [];

  double  _ratingGoogle   = 0;
  int     _totalGoogle    = 0;
  DocumentSnapshot? _ultimoDoc;
  bool    _hayMas         = false;
  bool    _cargando       = true;
  bool    _cargandoMas    = false;
  bool    _sincronizando  = false;
  String? _errorSync;
  bool    _mostrarAnaliticas = false;

  static const int _porPagina = 10;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('es', timeago.EsMessages());
    _init();
  }

  Future<void> _init() async {
    // 1. Leer rating del cache de Firestore primero (instantáneo)
    await _leerRatingCache();
    // 2. Borrar pruebas
    await _svc.borrarResenasDePrueba(widget.empresaId);
    // 3. Cargar primera página de reseñas guardadas
    await _cargarPagina(reset: true);
    // 4. Sincronizar con Google en background (actualiza rating + añade nuevas)
    _sincronizarEnBackground();
  }

  Future<void> _leerRatingCache() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('estadisticas').doc('resumen').get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _ratingGoogle = (data['rating_google'] as num?)?.toDouble() ?? 0;
          _totalGoogle  = (data['total_valoraciones_google'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarPagina({bool reset = false}) async {
    final resultado = await _svc.cargarResenas(widget.empresaId,
        limite: _porPagina, cursor: reset ? null : _ultimoDoc);

    if (!mounted) return;
    setState(() {
      if (reset) _resenas.clear();
      _resenas.addAll(resultado);
      if (resultado.isNotEmpty) {
        _ultimoDoc = resultado.last['_snap'] as DocumentSnapshot?;
      }
      _hayMas   = resultado.length == _porPagina;
      _cargando = false;
    });
  }

  Future<void> _cargarMas() async {
    if (_cargandoMas || _ultimoDoc == null) return;
    setState(() => _cargandoMas = true);
    await _cargarPagina();
    if (mounted) setState(() => _cargandoMas = false);
  }

  Future<void> _sincronizarEnBackground() async {
    if (!mounted) return;
    setState(() => _sincronizando = true);

    final resultado = await _svc.sincronizarDesdeGoogle(widget.empresaId);

    if (!mounted) return;
    setState(() {
      if (resultado.rating > 0) _ratingGoogle = resultado.rating;
      if (resultado.total  > 0) _totalGoogle  = resultado.total;
      _errorSync    = resultado.error;
      _sincronizando = false;
    });

    // Recargar reseñas tras sincronizar
    await _cargarPagina(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (DemoCuentaService().esDemo(email)) {
      return _buildModoDemo(context);
    }
    return CustomScrollView(
      slivers: [
        // ── Cabecera (scrollea con el contenido) ──────────────────────────
        SliverToBoxAdapter(
          child: _CabeceraCompleta(
            empresaId:          widget.empresaId,
            resenas:            _resenas,
            ratingGoogle:       _ratingGoogle,
            totalGoogle:        _totalGoogle,
            sincronizando:      _sincronizando,
            errorSync:          _errorSync,
            mostrarAnaliticas:  _mostrarAnaliticas,
            onSincronizar:      _sincronizarEnBackground,
            onAnadir:           () => _mostrarFormAnadir(context),
            onToggleAnaliticas: () => setState(() => _mostrarAnaliticas = !_mostrarAnaliticas),
            onGmbConectado:     () => _sincronizarEnBackground(),
            onConfigurar: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConfigurarGoogleReviewsScreen(empresaId: widget.empresaId),
              ),
            ).then((_) => _sincronizarEnBackground()),
          ),
        ),

        // ── Cuerpo ────────────────────────────────────────────────────────
        if (_cargando)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_resenas.isEmpty)
          SliverFillRemaining(
            child: _EstadoVacio(
              ratingGoogle: _ratingGoogle,
              totalGoogle:  _totalGoogle,
              onAnadir:     () => _mostrarFormAnadir(context),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  if (i == _resenas.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: _cargandoMas
                          ? const CircularProgressIndicator()
                          : OutlinedButton.icon(
                              onPressed: _cargarMas,
                              icon: const Icon(Icons.expand_more),
                              label: Text('Ver más (${_resenas.length} de máx 50)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1976D2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                      ),
                    );
                  }
                  final data = Map<String, dynamic>.from(_resenas[i])
                    ..remove('_snap');
                  return _TarjetaResena(
                    docId:     _resenas[i]['id'] as String,
                    empresaId: widget.empresaId,
                    data:      data,
                    svc:       _svc,
                  );
                },
                childCount: _resenas.length + (_hayMas ? 1 : 0),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ],
    );
  }

  // ── MODO DEMO ──────────────────────────────────────────────────────────────

  Widget _buildModoDemo(BuildContext context) {
    const resenasDemo = [
      _DemoResena('Laura Martínez', 5, 'Increíble atención, el mejor sitio. Volveré seguro.'),
      _DemoResena('Carlos Gómez', 4, 'Muy buena atención y rapidez en el servicio.'),
      _DemoResena('Ana Ruiz', 5, 'Todo perfecto, la comida estaba deliciosa.'),
      _DemoResena('Pedro López', 3, 'Bien en general, aunque tardaron un poco en atendernos.'),
      _DemoResena('María García', 5, 'Sitio muy agradable y trato excelente.'),
    ];

    return CustomScrollView(
      slivers: [
        // Banner explicativo
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.star, color: Color(0xFFFFC107), size: 20),
                  SizedBox(width: 8),
                  Text('Módulo de Valoraciones',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ]),
                SizedBox(height: 8),
                Text(
                  'Gestiona todas las reseñas de tu negocio desde un solo lugar. '
                  'Conecta tu perfil de Google Business para sincronizar reseñas reales, '
                  'responder directamente y ver analíticas de satisfacción.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ),

        // Rating demo
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
                ],
              ),
              child: Row(children: [
                Column(children: [
                  const Text('4.4',
                      style: TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF57C00))),
                  Row(children: List.generate(5, (i) => Icon(
                    i < 4 ? Icons.star : Icons.star_half,
                    color: const Color(0xFFF57C00), size: 20))),
                  const SizedBox(height: 4),
                  Text('5 reseñas de ejemplo',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ]),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [5, 4, 3, 2, 1].map((stars) {
                  final pct = stars == 5 ? 0.6 : stars == 4 ? 0.2 : stars == 3 ? 0.2 : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Text('$stars', style: const TextStyle(fontSize: 11)),
                      const Icon(Icons.star, size: 10, color: Color(0xFFF57C00)),
                      const SizedBox(width: 4),
                      Expanded(child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFF57C00)),
                          minHeight: 6)),
                    ]));
                }).toList())),
              ]),
            ),
          ),
        ),

        // Tarjetas de funcionalidades
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('¿Qué puedes hacer?',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[700])),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: const [
              _FuncionalidadChip(Icons.sync, 'Sincronizar con Google', Color(0xFF4285F4)),
              _FuncionalidadChip(Icons.reply, 'Responder reseñas', Color(0xFF34A853)),
              _FuncionalidadChip(Icons.bar_chart, 'Analíticas de rating', Color(0xFFFBBC05)),
              _FuncionalidadChip(Icons.add_comment_outlined, 'Reseñas manuales', Color(0xFFEA4335)),
              _FuncionalidadChip(Icons.trending_up, 'Evolución histórica', Color(0xFF7B1FA2)),
            ]),
          ),
        ),

        // Reseñas demo
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(children: [
              Text('Reseñas de ejemplo',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey[700])),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('DEMO',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange)),
              ),
            ]),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final r = resenasDemo[i];
                return _TarjetaResenaDemo(
                    nombre: r.nombre,
                    estrellas: r.estrellas,
                    comentario: r.comentario);
              },
              childCount: resenasDemo.length,
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarFormAnadir(BuildContext context) {
    final clienteCtrl    = TextEditingController();
    final comentarioCtrl = TextEditingController();
    int calificacion = 5;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Nueva valoración manual',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              Text('Para clientes que valoran en persona',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 16),
              TextField(controller: clienteCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre del cliente',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Calificación: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ...List.generate(5, (i) => GestureDetector(
                  onTap: () => setS(() => calificacion = i + 1),
                  child: Icon(i < calificacion ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF57C00), size: 32))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: comentarioCtrl, maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Comentario',
                  prefixIcon: const Icon(Icons.comment_outlined),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final cli = clienteCtrl.text.trim();
                    final com = comentarioCtrl.text.trim();
                    if (cli.isEmpty || com.isEmpty) return;
                    await _svc.anadirValoracionManual(
                      empresaId:    widget.empresaId,
                      cliente:      cli,
                      calificacion: calificacion,
                      comentario:   com);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      setState(() {});
                      _cargarPagina(reset: true);
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar valoración'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
            ])))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabecera completa con GMB, KPIs y analíticas colapsables
// ─────────────────────────────────────────────────────────────────────────────

class _CabeceraCompleta extends StatelessWidget {
  final String empresaId;
  final List<Map<String, dynamic>> resenas;
  final double ratingGoogle;
  final int totalGoogle;
  final bool sincronizando;
  final String? errorSync;
  final bool mostrarAnaliticas;
  final VoidCallback onSincronizar;
  final VoidCallback onAnadir;
  final VoidCallback onToggleAnaliticas;
  final VoidCallback onGmbConectado;
  final VoidCallback? onConfigurar;

  const _CabeceraCompleta({
    required this.empresaId,
    required this.resenas,
    required this.ratingGoogle,
    required this.totalGoogle,
    required this.sincronizando,
    required this.errorSync,
    required this.mostrarAnaliticas,
    required this.onSincronizar,
    required this.onAnadir,
    required this.onToggleAnaliticas,
    required this.onGmbConectado,
    this.onConfigurar,
  });

  @override
  Widget build(BuildContext context) {
    final rating = ratingGoogle > 0 ? ratingGoogle : _promedioLocal();
    final total  = totalGoogle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Fila estado GMB + acciones ────────────────────────────────────
        Row(children: [
          Expanded(child: EstadoConexionGoogleWidget(
            empresaId: empresaId, onEstadoCambiado: onGmbConectado)),
          if (sincronizando) ...[
            const SizedBox(width: 8),
            const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 4),
            Text('Sync...', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
          const SizedBox(width: 4),
          IconButton(
            onPressed: onAnadir,
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            color: const Color(0xFF43A047),
            tooltip: 'Añadir valoración manual',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
       ]),

        const SizedBox(height: 10),

        // ── Rating grande + histograma ────────────────────────────────────
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(rating > 0 ? rating.toStringAsFixed(1) : '-',
              style: const TextStyle(fontSize: 46, fontWeight: FontWeight.bold,
                color: Color(0xFFF57C00))),
            Row(children: List.generate(5, (i) {
              if (rating <= 0) {
                return const Icon(Icons.star_border, color: Color(0xFFF57C00), size: 20);
              }
              final filled = i < rating.floor();
              final half   = !filled && i < rating;
              return Icon(
                filled ? Icons.star : (half ? Icons.star_half : Icons.star_border),
                color: const Color(0xFFF57C00), size: 20);
            })),
            const SizedBox(height: 4),
            Text(total > 0 ? '$total reseñas en Google' : 'Sin datos de Google',
              style: TextStyle(color: Colors.grey[600], fontSize: 11,
                fontWeight: FontWeight.w500)),
            if (resenas.isNotEmpty)
              Text('${resenas.length} guardadas aquí',
                style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(children: List.generate(5, (i) {
            final stars = 5 - i;
            final count = resenas.where((r) =>
              ((r['calificacion'] ?? r['estrellas'] ?? 0) as num).toInt() == stars).length;
            final pct = resenas.isEmpty ? 0.0 : count / resenas.length;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(children: [
                Text('$stars', style: const TextStyle(fontSize: 11)),
                const Icon(Icons.star, size: 10, color: Color(0xFFF57C00)),
                const SizedBox(width: 4),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFF57C00)),
                    minHeight: 7))),
                const SizedBox(width: 4),
                SizedBox(width: 22,
                  child: Text('$count', style: const TextStyle(fontSize: 11))),
              ]));
          })))
        ]),

        // ── Aviso limitación Google (solo descarga 5) ─────────────────────
        if (totalGoogle > 5) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.2))),
            child: Text(
              'Google solo devuelve las 5 más recientes al sincronizar. '
              'Se acumulan aquí hasta llegar a 50.',
              style: TextStyle(fontSize: 10, color: Colors.grey[700], height: 1.5))),
        ],

        // ── Error de sincronización ───────────────────────────────────────
        if (errorSync != null && !errorSync!.contains('último')) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.error_outline, size: 13, color: Colors.red[700]),
              const SizedBox(width: 6),
              Expanded(child: Text('Sync: $errorSync',
                style: const TextStyle(fontSize: 10, color: Colors.orange))),
            ])),
        ],

        // ── Botón analíticas ──────────────────────────────────────────────
        Row(children: [
          const Spacer(),
          TextButton.icon(
            onPressed: onToggleAnaliticas,
            icon: Icon(mostrarAnaliticas ? Icons.expand_less : Icons.bar_chart, size: 16),
            label: Text(mostrarAnaliticas ? 'Ocultar' : 'Ver análisis',
              style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1976D2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          ),
        ]),

        // ── Sección analíticas colapsable ─────────────────────────────────
        if (mostrarAnaliticas) ...[
          KPIsRatingWidget(empresaId: empresaId, ratingGoogle: ratingGoogle, totalGoogle: totalGoogle),
          const SizedBox(height: 16),
          GraficoEvolucionRatingWidget(empresaId: empresaId),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }

  double _promedioLocal() {
    if (resenas.isEmpty) return 0;
    final suma = resenas.fold<double>(0, (s, r) =>
      s + ((r['calificacion'] ?? r['estrellas'] ?? 0) as num).toDouble());
    return suma / resenas.length;
  }

  Widget _badge(IconData icono, String texto, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 14, color: color),
      const SizedBox(width: 4),
      Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vacío
// ─────────────────────────────────────────────────────────────────────────────

class _EstadoVacio extends StatelessWidget {
  final double ratingGoogle;
  final int totalGoogle;
  final VoidCallback onAnadir;

  const _EstadoVacio({
    required this.ratingGoogle,
    required this.totalGoogle,
    required this.onAnadir,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (totalGoogle > 0) ...[
            Icon(Icons.cloud_download_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('$totalGoogle reseñas en Google',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Las 5 más recientes se descargan al sincronizar\ny se acumulan aquí hasta llegar a 50.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center),
          ] else ...[
            Icon(Icons.star_border_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Sin valoraciones todavía',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            Text('Las reseñas de Google aparecerán aquí al sincronizar',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAnadir,
            icon: const Icon(Icons.add),
            label: const Text('Añadir valoración manual'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de reseña individual
// ─────────────────────────────────────────────────────────────────────────────

class _TarjetaResena extends StatelessWidget {
  final String docId;
  final String empresaId;
  final Map<String, dynamic> data;
  final GoogleReviewsService svc;

  const _TarjetaResena({
    required this.docId,
    required this.empresaId,
    required this.data,
    required this.svc,
  });

  @override
  Widget build(BuildContext context) {
    final cliente      = data['cliente']   as String? ?? 'Anónimo';
    final calificacion = ((data['calificacion'] ?? data['estrellas'] ?? 0) as num).toInt();
    final comentario   = data['comentario'] as String? ?? '';
    final respuesta    = data['respuesta']  as String?;
    final esGoogle     = (data['origen']    as String?) == 'google';
    final esNegativa   = calificacion <= 2;
    final sinResponder = respuesta == null || respuesta.isEmpty;
    final eliminadaPorGoogle = data['eliminada_google'] as bool? ?? false;
    final fecha        = _parseFecha(data['fecha']);

    final respuestaSubida = data['respuesta_subida_google'] as bool? ?? false;
    final respuestaEstado = respuestaSubida
        ? 'publicada'
        : (respuesta != null && respuesta.isNotEmpty ? 'guardada' : null);

    return Stack(children: [
      Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Cabecera: avatar + nombre + fuente + estrellas + fecha ──────
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _colorDesdeNombre(cliente),
                child: Text(
                  cliente.isNotEmpty ? cliente[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 15))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(cliente,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: esGoogle
                        ? const Color(0xFF4285F4).withValues(alpha: 0.1)
                        : const Color(0xFF43A047).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(esGoogle ? Icons.g_mobiledata : Icons.phone_android,
                        size: 12,
                        color: esGoogle ? const Color(0xFF4285F4) : const Color(0xFF43A047)),
                      const SizedBox(width: 2),
                      Text(esGoogle ? 'Google' : 'App',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                          color: esGoogle ? const Color(0xFF4285F4) : const Color(0xFF43A047))),
                    ])),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  ...List.generate(5, (i) => Icon(
                    i < calificacion ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF57C00), size: 14)),
                  const SizedBox(width: 6),
                  Text(timeago.format(fecha, locale: 'es'),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ]),
              ])),
            ]),

            // ── Comentario ────────────────────────────────────────────────
            if (comentario.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(comentario,
                style: const TextStyle(fontSize: 13.5, height: 1.45)),
            ],

            // ── Respuesta guardada ─────────────────────────────────────────
            if (respuesta != null && respuesta.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: Color(0xFF1976D2), width: 3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('Tu respuesta',
                      style: TextStyle(fontWeight: FontWeight.w600,
                        fontSize: 12, color: Color(0xFF1976D2))),
                    const SizedBox(width: 8),
                    EstadoRespuestaWidget(estado: respuestaEstado, esDeGoogle: esGoogle),
                  ]),
                  const SizedBox(height: 4),
                  Text(respuesta, style: const TextStyle(fontSize: 13, height: 1.35)),
                ])),
            ],

            // ── Botón responder ────────────────────────────────────────────
            const SizedBox(height: 4),
            Row(children: [
              const Spacer(),
              TextButton.icon(
                onPressed: () => _dialogoResponder(context, respuesta),
                icon: Icon(respuesta != null && respuesta.isNotEmpty
                  ? Icons.edit_outlined : Icons.reply, size: 16),
                label: Text(respuesta != null && respuesta.isNotEmpty
                  ? 'Editar respuesta' : 'Responder',
                  style: const TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
              ),
            ]),
          ])),
      ),

      // ── Badge rojo parpadeante para reseñas negativas sin responder ──────
      if (esNegativa && sinResponder && !eliminadaPorGoogle)
        const Positioned(top: 8, left: 8, child: _BadgeNegativa()),
    ]);
  }

  void _dialogoResponder(BuildContext context, String? actual) {
    final ctrl = TextEditingController(text: actual ?? '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.reply, color: Color(0xFF1976D2)),
        const SizedBox(width: 8),
        Expanded(child: Text(
          actual != null && actual.isNotEmpty ? 'Editar respuesta' : 'Responder reseña',
          style: const TextStyle(fontSize: 17))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (data['origen'] == 'google') ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
            child: Text(
              data['google_review_name'] != null
                ? 'Tu respuesta se publicará directamente en Google Maps.'
                : '1. Escribe tu respuesta y pulsa Guardar.\n'
                  '2. Se guarda en la app.\n'
                  '3. Conéctate a Google Business para publicar en Google Maps.',
              style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.5))),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: ctrl,
          maxLines: 5,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Escribe tu respuesta...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true, fillColor: Colors.grey[50])),
      ]),
      actions: [
        if (data['origen'] == 'google')
          TextButton.icon(
            onPressed: () => _abrirEnGoogle(ctx),
            icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF4285F4)),
            label: const Text('Abrir Google',
              style: TextStyle(color: Color(0xFF4285F4), fontSize: 13))),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white),
          onPressed: () async {
            final texto = ctrl.text.trim();
            if (texto.isEmpty) return;

            // 1. Guardar en Firestore
            await svc.guardarRespuesta(
              empresaId:    empresaId,
              valoracionId: docId,
              respuesta:    texto);

            bool publicadoEnGoogle = false;
            String msgExtra = '';

            // 2. Publicar en GMB si tiene review name
            if (data['origen'] == 'google') {
              if (data['google_review_name'] != null) {
                try {
                  final res = await RespuestaGmbService().publicar(
                    empresaId:    empresaId,
                    valoracionId: docId,
                    texto:        texto);
                  publicadoEnGoogle = res.publicadoEnGoogle;
                  if (res.enCola) {
                    msgExtra = ' (en cola, reintentando...)';
                  } else if (!publicadoEnGoogle && res.error != null) {
                    msgExtra = ' (${res.error})';
                  }
                } on PlatformException catch (_) {
                  msgExtra = ' (Conecta Google Business para publicar en Maps)';
                } catch (_) {
                  msgExtra = ' (Conecta Google Business para publicar en Maps)';
                }
              } else {
                // Sin review_name: intentar OAuth directo
                try {
                  final gs = GoogleSignIn(scopes: ['https://www.googleapis.com/auth/business.manage']);
                  var acc = await gs.signInSilently() ?? await gs.signIn();
                  if (acc != null) {
                    final auth = await acc.authentication;
                    if (auth.accessToken != null) {
                      await svc.responderResena(
                        'accounts/me/locations/me/reviews/$docId',
                        texto,
                        auth.accessToken!);
                      publicadoEnGoogle = true;
                    }
                  }
                } on PlatformException catch (_) {
                  msgExtra = ' (Se publicará en Maps más tarde)';
                }
              }
            }

            if (ctx.mounted) Navigator.pop(ctx);
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Row(children: [
                  Icon(publicadoEnGoogle ? Icons.check_circle : Icons.save,
                    color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(data['origen'] == 'google'
                    ? (publicadoEnGoogle
                        ? 'Respuesta publicada en Google Maps ✅'
                        : 'Guardada localmente$msgExtra')
                    : 'Respuesta guardada correctamente')),
                ]),
                backgroundColor: publicadoEnGoogle
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF1976D2),
                duration: const Duration(seconds: 4)));
            }
          },
          child: const Text('Guardar')),
      ]));
  }

  Future<void> _abrirEnGoogle(BuildContext context) async {
    final uri = Uri.parse('https://business.google.com/reviews');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Accede a business.google.com/reviews'),
        backgroundColor: Colors.orange));
    }
  }

  DateTime _parseFecha(dynamic f) {
    if (f is Timestamp) return f.toDate();
    if (f is String)   return DateTime.tryParse(f) ?? DateTime.now();
    return DateTime.now();
  }

  Color _colorDesdeNombre(String name) {
    final c = [
      const Color(0xFF1976D2), const Color(0xFF388E3C), const Color(0xFF7B1FA2),
      const Color(0xFFF57C00), const Color(0xFFD32F2F), const Color(0xFF00BCD4),
      const Color(0xFF5D4037), const Color(0xFF689F38), const Color(0xFFE91E63),
    ];
    return c[name.codeUnits.fold(0, (a, b) => a + b) % c.length];
  }
}

// ── Badge rojo parpadeante ────────────────────────────────────────────────────

class _BadgeNegativa extends StatefulWidget {
  const _BadgeNegativa();
  @override
  State<_BadgeNegativa> createState() => _BadgeNegativaState();
}

class _BadgeNegativaState extends State<_BadgeNegativa>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Opacity(
      opacity: _anim.value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F),
          borderRadius: BorderRadius.circular(8)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.priority_high, color: Colors.white, size: 10),
          SizedBox(width: 3),
          Text('¡Responde!',
            style: TextStyle(color: Colors.white, fontSize: 9,
              fontWeight: FontWeight.bold)),
        ]),
      ),
    ),
  );
}

// ── Clases helper para modo demo ──────────────────────────────────────────────

class _DemoResena {
  final String nombre;
  final int estrellas;
  final String comentario;
  const _DemoResena(this.nombre, this.estrellas, this.comentario);
}

class _TarjetaResenaDemo extends StatelessWidget {
  final String nombre;
  final int estrellas;
  final String comentario;
  const _TarjetaResenaDemo({
    required this.nombre,
    required this.estrellas,
    required this.comentario,
  });

  @override
  Widget build(BuildContext context) {
    final iniciales = nombre.split(' ').where((s) => s.isNotEmpty).take(2)
        .map((s) => s[0]).join().toUpperCase();
    final colors = [
      const Color(0xFF1976D2), const Color(0xFF388E3C),
      const Color(0xFF7B1FA2), const Color(0xFFF57C00), const Color(0xFFD32F2F),
    ];
    final avatarColor = colors[nombre.codeUnits.fold(0, (a, b) => a + b) % colors.length];

    return Opacity(
      opacity: 0.75,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: avatarColor,
                child: Text(iniciales,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Row(children: List.generate(5, (i) => Icon(
                  i < estrellas ? Icons.star : Icons.star_border,
                  color: const Color(0xFFF57C00), size: 14))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('DEMO',
                    style: TextStyle(fontSize: 9, color: Colors.orange,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(comentario,
                style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black54)),
          ]),
        ),
      ),
    );
  }
}

class _FuncionalidadChip extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  const _FuncionalidadChip(this.icono, this.texto, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 6),
        Text(texto, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: color)),
      ]),
    );
  }
}
