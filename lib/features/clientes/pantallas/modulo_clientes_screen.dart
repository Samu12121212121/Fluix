import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctions, FirebaseFunctionsException, HttpsCallableOptions;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../core/utils/app_settings.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/widgets/flux_toast.dart';
import '../../facturacion/pantallas/formulario_factura_screen.dart';
import '../../../domain/modelos/factura.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MÓDULO CLIENTES — misma UI que empleados
// ═════════════════════════════════════════════════════════════════════════════

// Mismo set de colores que empleados
const _kBlue   = Color(0xFF3B82F6);
const _kGreen  = Color(0xFF22C55E);
const _kOrange = Color(0xFFF59E0B);
const _kRed    = Color(0xFFEF4444);
const _kText   = Color(0xFF111827);
const _kSub    = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF8F9FA);

const _kEtiquetas = ['VIP', 'Frecuente', 'Moroso', 'Proveedor', 'Potencial'];

class ModuloClientesScreen extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  const ModuloClientesScreen({super.key, required this.empresaId, this.sesion});
  @override
  State<ModuloClientesScreen> createState() => _ModuloClientesScreenState();
}

class _ModuloClientesScreenState extends State<ModuloClientesScreen> {
  final _firestore = FirebaseFirestore.instance;

  int    _paginaGrid = 0;
  QueryDocumentSnapshot? _seleccionado;
  bool   _isDark = false;

  bool get _esPropietario =>
      widget.sesion?.esAdmin ?? (PermisosService().sesion?.esAdmin ?? false);

  // ── Colores reactivos al modo oscuro ──────────────────────────────────────
  Color get _bg      => _isDark ? const Color(0xFF0F172A) : _kBg;
  Color get _surface => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _card    => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _text    => _isDark ? const Color(0xFFF1F5F9) : _kText;
  Color get _sub     => _isDark ? const Color(0xFF94A3B8) : _kSub;
  Color get _border  => _isDark ? const Color(0xFF334155) : _kBorder;

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

  // ── Helpers ───────────────────────────────────────────────────────────────

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Color _avatarColor(String nombre) {
    const cols = [_kBlue, _kGreen, _kOrange, const Color(0xFF8B5CF6),
                  const Color(0xFFEC4899), _kRed, const Color(0xFF0891B2),
                  const Color(0xFF16A34A), const Color(0xFF9333EA)];
    if (nombre.isEmpty) return _kBlue;
    return cols[nombre.codeUnitAt(0) % cols.length];
  }

  String _iniciales(String nombre) => nombre.trim().split(' ').take(2)
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();

  // ── Filtrado (igual que empleados) ────────────────────────────────────────

  List<QueryDocumentSnapshot> _filtrar(List<QueryDocumentSnapshot> lista) {
    final sorted = List<QueryDocumentSnapshot>.from(lista);
    sorted.sort((a, b) {
      final na = ((a.data() as Map)['nombre'] as String?) ?? '';
      final nb = ((b.data() as Map)['nombre'] as String?) ?? '';
      return na.toLowerCase().compareTo(nb.toLowerCase());
    });
    return sorted;
  }

  // ── Build (IDÉNTICO a empleados) ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canPop  = ModalRoute.of(context)?.isFirst == false;
    final screenW = MediaQuery.of(context).size.width;
    final wide    = screenW > 860;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: _bg,
        // FluixAppBar solo cuando es una ruta empujada (mobile)
        appBar: canPop
            ? FluixAppBar(
                titulo:              'Clientes',
                titleNavigatesBack:  true,
                extraActions: [
                  IconButton(
                    tooltip: 'Descargar CSV',
                    onPressed: () => _descargarCSV(context),
                    icon: Icon(Icons.download_outlined, size: 19, color: _sub),
                  ),
                  IconButton(
                    tooltip: 'Compartir CSV',
                    onPressed: () => _compartirCSV(context),
                    icon: Icon(Icons.share_outlined, size: 19, color: _sub),
                  ),
                  if (_esPropietario)
                    IconButton(
                      tooltip: 'Nuevo cliente',
                      onPressed: () => _mostrarPopupCliente(),
                      icon: const Icon(Icons.add_rounded, size: 20, color: _kBlue),
                    ),
                ],
              )
            : null,
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('empresas').doc(widget.empresaId)
              .collection('clientes').orderBy('nombre').snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _kBlue));
            }
            if (snap.hasError) return _buildError(snap.error);
            final todos     = snap.data?.docs ?? [];
            final filtrados = _filtrar(List.from(todos));
            if (!wide) {
              return Column(children: [
                // Header solo cuando está embebido (sin appBar de Scaffold)
                if (!canPop) _buildHeader(context, todos),
                _buildKpis(todos),
                Expanded(child: todos.isEmpty ? _buildVacio() : _buildGrid(filtrados, context)),
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: Column(children: [
                if (!canPop) _buildHeader(context, todos),
                _buildKpis(todos),
                Expanded(child: todos.isEmpty ? _buildVacio() : _buildGrid(filtrados, context)),
              ])),
              _buildDetailPanel(context),
            ]);
          },
        ),
      ),
    );
  }

  // ── Header (IDÉNTICO a empleados) ─────────────────────────────────────────

  Widget _buildHeader(BuildContext context, List<QueryDocumentSnapshot> todos) {
    final canPop  = ModalRoute.of(context)?.isFirst == false;
    // En mobile (pantalla pequeña empujada como ruta), header compacto
    final compact = canPop || MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 20,
        compact ? 6 : 16,
        compact ? 8 : 20,
        compact ? 6 : 12,
      ),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [
        if (canPop)
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: _text),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        Expanded(child: Padding(
          padding: EdgeInsets.only(left: canPop ? 4 : 0),
          child: Text('Clientes',
            style: TextStyle(
              fontSize: compact ? 17 : 22,
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
        )),
        IconButton(
          tooltip: 'Descargar CSV',
          onPressed: () => _descargarCSV(context),
          icon: Icon(Icons.download_outlined, size: 19, color: _sub),
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        IconButton(
          tooltip: 'Compartir CSV',
          onPressed: () => _compartirCSV(context),
          icon: Icon(Icons.share_outlined, size: 19, color: _sub),
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        if (_esPropietario) ...[
          const SizedBox(width: 4),
          compact
              ? IconButton(
                  onPressed: () => _mostrarPopupCliente(),
                  icon: const Icon(Icons.add_rounded, size: 20, color: _kBlue),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                )
              : FilledButton.icon(
                  onPressed: () => _mostrarPopupCliente(),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Nuevo', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
        ],
      ]),
    );
  }

  // ── KPIs (mismo widget _kpi que empleados) ────────────────────────────────

  Widget _buildKpis(List<QueryDocumentSnapshot> todos) {
    final mes30      = DateTime.now().subtract(const Duration(days: 30));
    final total      = todos.length;
    final activos    = todos.where((e) {
      final uv = _parseDate((e.data() as Map)['ultima_visita'] ??
                            (e.data() as Map)['ultima_actividad']);
      return uv != null && uv.isAfter(mes30);
    }).length;
    final vips       = todos.where((e) =>
        ((e.data() as Map)['etiquetas'] as List?)?.contains('VIP') == true).length;
    final nuevos     = todos.where((e) {
      final r = _parseDate((e.data() as Map)['fecha_registro']);
      return r != null && r.isAfter(mes30);
    }).length;
    final totalGasto = todos.fold(0.0, (s, e) =>
        s + (((e.data() as Map)['total_gastado'] ?? 0) as num).toDouble());

    const kpiW = 160.0;
    final kpis = [
      _kpi(Icons.people_alt_outlined, const Color(0xFFDBEAFE), _kBlue,
          'Total clientes', '$total', 'en la base de datos'),
      _kpi(Icons.check_circle_outline, const Color(0xFFDCFCE7), _kGreen,
          'Activos (30d)', '$activos', '$activos de $total'),
      _kpi(Icons.star_rounded, const Color(0xFFFEF3C7), _kOrange,
          'VIP', '$vips', vips == 0 ? 'Ninguno' : '$vips cliente(s)'),
      _kpi(Icons.fiber_new_outlined, const Color(0xFFF3E8FF), const Color(0xFF8B5CF6),
          'Nuevos (30d)', '$nuevos', 'este mes'),
      _kpi(Icons.euro_rounded, const Color(0xFFFCE7F3), const Color(0xFFEC4899),
          'Facturado', '${totalGasto.toStringAsFixed(0)}€', 'acumulado'),
    ];

    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: LayoutBuilder(builder: (_, constraints) {
        final totalW = kpiW * kpis.length + 10.0 * (kpis.length - 1);
        if (totalW <= constraints.maxWidth) {
          return Row(children: [
            for (int i = 0; i < kpis.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: kpis[i]),
            ],
          ]);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (int i = 0; i < kpis.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              SizedBox(width: kpiW, child: kpis[i]),
            ],
          ]),
        );
      }),
    );
  }

  Widget _kpi(IconData icon, Color bgIcon, Color iconColor,
      String label, String valor, String sub) =>
      Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDark ? 0.15 : 0.03),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 30, height: 30,
              decoration: BoxDecoration(color: bgIcon, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 15)),
            const SizedBox(height: 8),
            Text(valor, style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.bold, color: _text),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: _sub),
                overflow: TextOverflow.ellipsis, maxLines: 1),
            const SizedBox(height: 1),
            Text(sub, style: TextStyle(fontSize: 9, color: _sub),
                overflow: TextOverflow.ellipsis, maxLines: 1),
          ],
        ),
      );

  // ── Grid (IDÉNTICO a empleados, misma lógica LayoutBuilder) ──────────────

  Widget _buildGrid(List<QueryDocumentSnapshot> lista, BuildContext context) {
    if (lista.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline, size: 56, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text('Sin resultados', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
      ]));
    }

    const porPagina  = 6;
    final totalPaginas = (lista.length / porPagina).ceil();
    final paginaActual = _paginaGrid.clamp(0, totalPaginas - 1);
    final inicio = paginaActual * porPagina;
    final fin    = (inicio + porPagina).clamp(0, lista.length);
    final pagina = lista.sublist(inicio, fin);

    return LayoutBuilder(builder: (ctx, constraints) {
      const gap    = 12.0;
      const padH   = 16.0;
      const padV   = 10.0;
      const paginH = 48.0;

      final availW = constraints.maxWidth - padH * 2;
      final cols   = availW < 440 ? 1 : availW < 660 ? 2 : 3;

      // Mobile: ListView sin altura fija
      if (cols == 1) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(padH, padV, padH, padV),
          itemCount: lista.length,
          separatorBuilder: (_, __) => const SizedBox(height: gap),
          itemBuilder: (_, i) => _clienteCard(lista[i], context),
        );
      }

      // Altura fija por tarjeta — evita overflow en pantallas pequeñas
      const cardH = 258.0;

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(padH, padV, padH, padV),
        child: Column(children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            mainAxisExtent: cardH,
          ),
          itemCount: pagina.length,
          itemBuilder: (_, i) => _clienteCard(pagina[i], context),
        ),
        if (totalPaginas > 1)
          SizedBox(
            height: paginH,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: paginaActual > 0
                    ? () => setState(() => _paginaGrid = paginaActual - 1) : null,
                color: _kBlue,
              ),
              ...List.generate(totalPaginas, (i) => GestureDetector(
                onTap: () => setState(() => _paginaGrid = i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: i == paginaActual ? _kBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: i == paginaActual ? _kBlue : _kBorder),
                  ),
                  child: Center(child: Text('${i + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: i == paginaActual ? Colors.white : _kSub))),
                ),
              )),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: paginaActual < totalPaginas - 1
                    ? () => setState(() => _paginaGrid = paginaActual + 1) : null,
                color: _kBlue,
              ),
            ]),
          ),
        ]));
    });
  }

  // ── Tarjeta cliente (MISMA ESTRUCTURA que _empCard de empleados) ──────────

  Widget _clienteCard(QueryDocumentSnapshot doc, BuildContext context) {
    final d          = doc.data() as Map<String, dynamic>;
    final nombre     = d['nombre'] as String? ?? 'Sin nombre';
    final correo     = d['correo'] as String? ?? '';
    final telefono   = d['telefono'] as String? ?? '';
    final etiquetas  = (d['etiquetas'] as List?)?.cast<String>() ?? <String>[];
    final total      = ((d['total_gastado'] ?? 0) as num).toDouble();
    final reservas   = ((d['numero_reservas'] ?? 0) as num).toInt();
    final uv         = _parseDate(d['ultima_visita'] ?? d['ultima_actividad']);
    final mes30      = DateTime.now().subtract(const Duration(days: 30));
    final isActivo   = uv != null && uv.isAfter(mes30);
    final isVip      = etiquetas.contains('VIP');
    final isNuevo    = _parseDate(d['fecha_registro'])?.isAfter(mes30) == true;
    final color      = _avatarColor(nombre);
    final ini        = _iniciales(nombre);
    final sel        = _seleccionado?.id == doc.id;

    final badgeLabel = isVip ? 'VIP' : isActivo ? 'Cliente activo' : 'Inactivo';
    final badgeColor = isVip ? _kOrange : isActivo ? _kGreen : _kRed;
    final visitaStr  = uv != null ? DateFormat('dd/MM/yy').format(uv) : '—';

    return GestureDetector(
      onTap: () {
        final wide = MediaQuery.of(context).size.width > 860;
        if (wide) {
          setState(() => _seleccionado = sel ? null : doc);
        } else {
          _mostrarDetalleSheet(context, doc);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? _kBlue : _border, width: sel ? 2 : 1),
          boxShadow: [BoxShadow(
            color: sel ? _kBlue.withValues(alpha: 0.12) : Colors.black.withValues(alpha: _isDark ? 0.2 : 0.04),
            blurRadius: sel ? 12 : 6, offset: const Offset(0, 2),
          )],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(children: [

            // ── Cabecera: avatar izq + info dcha (IGUAL que empCard) ──────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: badgeColor, width: 2.5),
                    boxShadow: [BoxShadow(color: badgeColor.withValues(alpha: 0.2),
                        blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Text(ini.isEmpty ? '?' : ini,
                        style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.bold, color: color)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(nombre,
                        style: TextStyle(fontSize: 12.5,
                            fontWeight: FontWeight.bold, color: _text),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(correo.isNotEmpty ? correo
                        : telefono.isNotEmpty ? telefono : 'Sin contacto',
                        style: TextStyle(fontSize: 10, color: _sub),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Wrap(spacing: 4, runSpacing: 2, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                        ),
                        child: Text('• $badgeLabel', style: TextStyle(fontSize: 8.5,
                            fontWeight: FontWeight.w700, color: badgeColor)),
                      ),
                      if (isNuevo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Nuevo', style: TextStyle(
                              fontSize: 8.5, color: Color(0xFF8B5CF6))),
                        )
                      else if (etiquetas.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(etiquetas.first, style: TextStyle(
                              fontSize: 8.5, color: _sub),
                              overflow: TextOverflow.ellipsis),
                        ),
                    ]),
                  ],
                )),
              ]),
            ),

            // ── Barra de gasto acumulado (IGUAL que barra vacaciones) ─────
            Container(
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _border))),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.euro_rounded, size: 11, color: _kGreen),
                  const SizedBox(width: 5),
                  Text('Gasto acumulado',
                      style: TextStyle(fontSize: 10, color: _sub)),
                  const Spacer(),
                  Text('${total.toStringAsFixed(0)}€',
                      style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w700, color: _text)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (total / 1000).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: _kBlue.withValues(alpha: 0.10),
                    valueColor: const AlwaysStoppedAnimation<Color>(_kBlue),
                  ),
                ),
              ]),
            ),

            // ── Celdas: última visita | reservas (IGUAL que fichaje) ──────
            Container(
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _border))),
              child: Row(children: [
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                  child: Row(children: [
                    const Icon(Icons.schedule_outlined, size: 11, color: _kBlue),
                    const SizedBox(width: 5),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(visitaStr, style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700, color: _text)),
                      Text('Última visita',
                          style: TextStyle(fontSize: 8.5, color: _sub)),
                    ]),
                  ]),
                )),
                Container(width: 1, height: 32, color: _border),
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                  child: Row(children: [
                    const Icon(Icons.confirmation_number_outlined, size: 11, color: _kOrange),
                    const SizedBox(width: 5),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$reservas', style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700, color: _text)),
                      Text('Reservas',
                          style: TextStyle(fontSize: 8.5, color: _sub)),
                    ]),
                  ]),
                )),
              ]),
            ),

            // ── Botones de acción ────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _border))),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _cliBtn(Icons.edit_outlined, 'Editar', _kBlue,
                    () => _mostrarDetalleCliente(doc.id, d)),
                _cliBtn(Icons.description_outlined, 'Presup.', const Color(0xFF8B5CF6),
                    () => _nuevoPresupuestoCliente(context, nombre, correo, doc.id)),
                if (telefono.isNotEmpty)
                  _cliBtn(Icons.phone_outlined, 'Llamar', _kGreen,
                      () => launchUrl(Uri.parse('tel:$telefono'))),
                if (correo.isNotEmpty)
                  _cliBtn(Icons.email_outlined, 'Email', _kOrange,
                      () => launchUrl(Uri.parse('mailto:$correo'))),
                _cliBtn(
                  isVip ? Icons.star_rounded : Icons.star_outline_rounded,
                  'VIP', _kOrange,
                  () {
                    final tags = List<String>.from(etiquetas);
                    isVip ? tags.remove('VIP') : tags.add('VIP');
                    _firestore.collection('empresas').doc(widget.empresaId)
                        .collection('clientes').doc(doc.id)
                        .update({'etiquetas': tags});
                  },
                ),
              ]),
            ),

          ]),
        ),
      ),
    );
  }

  // ── Historial de pedidos y compras del cliente ────────────────────────────
  void _mostrarPedidosCliente(BuildContext context, String nombre,
      String correo, String clienteId, Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PedidosClienteSheet(
        empresaId:  widget.empresaId,
        clienteId:  clienteId,
        nombre:     nombre,
        correo:     correo,
        telefono:   d['telefono'] as String? ?? '',
        isDark:     _isDark,
        surface:    _surface,
        text:       _text,
        sub:        _sub,
        border:     _border,
        card:       _card,
        bg:         _bg,
      ),
    );
  }

  void _nuevoPresupuestoCliente(BuildContext context, String nombre, String correo, String clienteId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: FormularioFacturaScreen(
          empresaId: widget.empresaId,
          tipoInicial: TipoFactura.proforma,
          clienteNombreInicial: nombre,
        ),
      ),
    );
  }

  // IDÉNTICO a _empBtn de empleados
  Widget _cliBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: _sub)),
        ]),
      );

  // ── Panel derecho — detalle del cliente seleccionado ─────────────────────

  Widget _buildDetailPanel(BuildContext context) {
    if (_seleccionado == null) {
      return Container(
        width: 280,
        decoration: BoxDecoration(
          color: _surface,
          border: Border(left: BorderSide(color: _border)),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_search_rounded, size: 48, color: _border),
            const SizedBox(height: 12),
            Text('Selecciona un cliente\npara ver su detalle',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _sub)),
          ]),
        ),
      );
    }
    final doc = _seleccionado!;
    final d   = doc.data() as Map<String, dynamic>;
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _surface,
        border: Border(left: BorderSide(color: _border)),
      ),
      child: Column(children: [
        _detalleHeader(doc, d, onClose: () => setState(() => _seleccionado = null)),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _detalleContenido(doc, d),
        )),
      ]),
    );
  }

  // Cabecera del panel / sheet
  Widget _detalleHeader(QueryDocumentSnapshot doc, Map<String, dynamic> d, {VoidCallback? onClose}) {
    final nombre = d['nombre'] as String? ?? '';
    final correo = d['correo'] as String? ?? '';
    final color  = _avatarColor(nombre);
    final ini    = _iniciales(nombre);
    final total    = ((d['total_gastado'] ?? 0) as num).toDouble();
    final reservas = ((d['numero_reservas'] ?? 0) as num).toInt();
    final ticketMedio = reservas > 0 ? total / reservas : 0.0;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
        child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: color.withValues(alpha: 0.12),
              child: Text(ini, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 13.5, color: _text), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (correo.isNotEmpty)
              Text(correo, style: TextStyle(fontSize: 10, color: _sub),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (onClose != null)
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: _sub),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          _miniKpi('$reservas', 'Reservas', _kBlue),
          const SizedBox(width: 8),
          _miniKpi('${total.toStringAsFixed(0)}€', 'Facturado', _kGreen),
          const SizedBox(width: 8),
          _miniKpi('${ticketMedio.toStringAsFixed(0)}€', 'Ticket', _kOrange),
        ]),
      ),
    ]);
  }

  // Contenido scrollable del detalle — usado tanto en panel como en sheet
  Widget _detalleContenido(QueryDocumentSnapshot doc, Map<String, dynamic> d,
      {bool showActions = true}) {
    final nombre      = d['nombre'] as String? ?? '';
    final correo      = d['correo'] as String? ?? '';
    final telefono    = d['telefono'] as String? ?? '';
    final notas       = d['notas'] as String? ?? '';
    final ciudad      = d['ciudad'] as String? ?? '';
    final direccion   = d['direccion'] as String? ?? '';
    final cumple      = d['fecha_nacimiento'] as String? ?? '';
    final instagram   = d['instagram'] as String? ?? '';
    final preferencias = d['preferencias'] as String? ?? '';
    final origen      = d['origen'] as String? ?? '';
    final nif         = d['nif'] as String? ?? '';
    final total       = ((d['total_gastado'] ?? 0) as num).toDouble();
    final etiquetas   = (d['etiquetas'] as List?)?.cast<String>() ?? <String>[];
    final uv          = _parseDate(d['ultima_visita'] ?? d['ultima_actividad']);
    final reg         = _parseDate(d['fecha_registro']);

    final categoria = total >= 2000 ? ('💎 Platino', const Color(0xFF7C3AED))
        : total >= 500  ? ('🥇 Oro',    const Color(0xFFF59E0B))
        : total >= 100  ? ('🥈 Plata',  const Color(0xFF94A3B8))
        :                 ('🥉 Bronce', const Color(0xFFD97706));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Wrap(spacing: 6, runSpacing: 4, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: categoria.$2.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: categoria.$2.withValues(alpha: 0.3)),
            ),
            child: Text(categoria.$1, style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: categoria.$2)),
          ),
          if (origen.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border)),
              child: Text('Origen: $origen', style: TextStyle(fontSize: 10, color: _sub)),
            ),
        ]),
      ),
      if (telefono.isNotEmpty)
        _detailRow(Icons.phone_outlined, 'Teléfono', telefono,
            onTap: () => launchUrl(Uri.parse('tel:$telefono'))),
      if (correo.isNotEmpty)
        _detailRow(Icons.email_outlined, 'Correo', correo,
            onTap: () => launchUrl(Uri.parse('mailto:$correo'))),
      if (instagram.isNotEmpty)
        _detailRow(Icons.alternate_email_rounded, 'Instagram', instagram,
            onTap: () => launchUrl(Uri.parse('https://instagram.com/${instagram.replaceAll('@', '')}'))),
      if (ciudad.isNotEmpty)
        _detailRow(Icons.location_city_outlined, 'Ciudad', ciudad),
      if (direccion.isNotEmpty)
        _detailRow(Icons.home_outlined, 'Dirección', direccion),
      if (nif.isNotEmpty)
        _detailRow(Icons.badge_outlined, 'NIF / CIF', nif),
      if (cumple.isNotEmpty)
        _detailRow(Icons.cake_outlined, 'Cumpleaños', cumple),
      if (uv != null)
        _detailRow(Icons.schedule_outlined, 'Última visita',
            DateFormat('dd MMM yyyy', 'es').format(uv)),
      if (reg != null)
        _detailRow(Icons.person_add_outlined, 'Cliente desde',
            DateFormat('dd MMM yyyy', 'es').format(reg)),
      if (preferencias.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Preferencias / Alergias', style: TextStyle(fontSize: 10,
            color: _sub, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF2D2410) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3))),
          child: Text(preferencias, style: TextStyle(fontSize: 11.5,
              color: _isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E))),
        ),
      ],
      if (etiquetas.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('Etiquetas', style: TextStyle(fontSize: 10, color: _sub, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: etiquetas.map((t) => _tagChip(t)).toList()),
      ],
      if (notas.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Notas', style: TextStyle(fontSize: 10, color: _sub, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border)),
          child: Text(notas, style: TextStyle(fontSize: 11.5, color: _sub)),
        ),
      ],
      if (showActions) ...[
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).maybePop();
              setState(() => _seleccionado = null);
              _mostrarPopupCliente({'id': doc.id, ...d});
            },
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('Editar', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(foregroundColor: _kBlue,
                side: BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(vertical: 8)),
          )),
        ]),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _recalcularStats(doc.id, nombre),
          icon: const Icon(Icons.sync_rounded, size: 14),
          label: const Text('Recalcular stats', style: TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _sub,
            side: BorderSide(color: _border),
            minimumSize: const Size(double.infinity, 36),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        // ── Email de bienvenida ───────────────────────────────────────────────
        if ((d['correo'] as String? ?? '').contains('@')) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _enviarEmailBienvenida(doc.id, nombre, d['correo'] as String),
            icon: const Icon(Icons.mark_email_read_outlined, size: 14),
            label: Text(
              (d['email_bienvenida_enviado'] == true)
                  ? 'Email bienvenida enviado ✓'
                  : 'Enviar email de bienvenida',
              style: const TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: (d['email_bienvenida_enviado'] == true)
                  ? _kGreen : _kBlue,
              side: BorderSide(color: (d['email_bienvenida_enviado'] == true)
                  ? _kGreen : _kBlue, width: 1),
              minimumSize: const Size(double.infinity, 36),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
        const SizedBox(height: 8),
        // ── Segmentación automática ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: _isDark ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Segmentación automática',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                      color: Color(0xFF8B5CF6))),
              Text('Basada en historial de compras — próximamente',
                  style: TextStyle(fontSize: 10, color: _sub)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Próximo', style: TextStyle(
                  fontSize: 8.5, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }

  Future<void> _enviarEmailBienvenida(String clienteId, String nombre, String correo) async {
    FluxToast.info(context, 'Enviando email a $correo…');
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
      await fn.httpsCallable('enviarEmailBienvenidaCliente',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 20)))
        .call({'empresaId': widget.empresaId, 'clienteId': clienteId});
      if (mounted) FluxToast.exito(context, 'Email de bienvenida enviado a $correo',
          title: 'Enviado');
    } on FirebaseFunctionsException catch (e) {
      if (mounted) FluxToast.error(context, 'Error ${e.code}: ${e.message}');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }

  Widget _miniKpi(String valor, String label, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: color.withValues(alpha: _isDark ? 0.15 : 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(valor, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 9.5, color: _sub)),
    ]),
  ));

  Widget _detailRow(IconData icon, String label, String value, {VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Icon(icon, size: 15, color: _sub),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 9.5, color: _sub)),
              Text(value, style: TextStyle(fontSize: 12.5, color: onTap != null ? _kBlue : _text,
                  decoration: onTap != null ? TextDecoration.underline : null),
                  overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),
      );

  Widget _tagChip(String tag) {
    const colors = {'VIP': _kOrange, 'Frecuente': _kGreen, 'Moroso': _kRed,
                    'Proveedor': _kBlue, 'Potencial': Color(0xFF8B5CF6)};
    final color = colors[tag] ?? _kBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)));
  }

  // ── Estados vacío / error ─────────────────────────────────────────────────

  Widget _buildVacio() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.people_outline, size: 56, color: Colors.grey[300]),
    const SizedBox(height: 12),
    Text('No hay clientes todavía', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
    const SizedBox(height: 12),
    FilledButton.icon(
      onPressed: () => _mostrarPopupCliente(),
      icon: const Icon(Icons.add_rounded, size: 15),
      label: const Text('Añadir primer cliente'),
      style: FilledButton.styleFrom(backgroundColor: _kBlue),
    ),
  ]));

  Widget _buildError(Object? e) => Center(
    child: Text('Error: $e', style: const TextStyle(color: _kRed)));

  // ── Popup crear / editar cliente ──────────────────────────────────────────

  void _mostrarDetalleSheet(BuildContext outerCtx, QueryDocumentSnapshot doc) {
    setState(() => _seleccionado = doc);
    final d      = doc.data() as Map<String, dynamic>;
    final nombre = d['nombre'] as String? ?? '';
    showModalBottomSheet(
      context: outerCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Handle
            Center(child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
            )),
            // Cabecera con X para cerrar
            _detalleHeader(doc, d, onClose: () => Navigator.of(sheetCtx).pop()),
            Divider(height: 1, color: _border),
            // Contenido scrollable (sin botones inline)
            Expanded(child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _detalleContenido(doc, d, showActions: false),
            )),
            // Footer fijo con acciones siempre visibles
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(sheetCtx).padding.bottom + 12),
              decoration: BoxDecoration(
                color: _surface,
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    _mostrarPopupCliente({'id': doc.id, ...d});
                  },
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Editar', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kBlue,
                    side: BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _recalcularStats(doc.id, nombre),
                  icon: const Icon(Icons.sync_rounded, size: 14),
                  label: const Text('Recalcular', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _sub,
                    side: BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                )),
              ]),
            ),
          ]),
        ),
      ),
    ).whenComplete(() => setState(() => _seleccionado = null));
  }

  void _mostrarDetalleCliente(String id, Map<String, dynamic> d) =>
      _mostrarPopupCliente({'id': id, ...d});

  void _mostrarPopupCliente([Map<String, dynamic>? data]) {
    final esEdicion     = data != null && data.containsKey('id');
    final id            = esEdicion ? data['id'] as String : null;
    final nombreCtrl    = TextEditingController(text: data?['nombre'] ?? '');
    final telCtrl       = TextEditingController(text: data?['telefono'] ?? '');
    final correoCtrl    = TextEditingController(text: data?['correo'] ?? '');
    final nifCtrl       = TextEditingController(text: data?['nif'] ?? '');
    final dirCtrl       = TextEditingController(text: data?['direccion'] ?? '');
    final ciudadCtrl    = TextEditingController(text: data?['ciudad'] ?? '');
    final cumpleCtrl    = TextEditingController(text: data?['fecha_nacimiento'] ?? '');
    final instagramCtrl = TextEditingController(text: data?['instagram'] ?? '');
    final prefCtrl      = TextEditingController(text: data?['preferencias'] ?? '');
    final notasCtrl     = TextEditingController(text: data?['notas'] ?? '');
    final etiqSel       = <String>{...((data?['etiquetas'] as List?)?.cast<String>() ?? [])};
    String? origenSel   = data?['origen'] as String?;
    bool guardando = false;
    final isDark   = _isDark;
    final sheetBg  = isDark ? const Color(0xFF1E293B) : Colors.white;
    final sheetBdr = isDark ? const Color(0xFF334155) : _kBorder;
    final sheetTxt = isDark ? const Color(0xFFF1F5F9) : _kText;
    final sheetSub = isDark ? const Color(0xFF94A3B8) : _kSub;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.fromBorderSide(BorderSide(color: sheetBdr))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: sheetBdr, borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  Container(width: 32, height: 32,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(9),
                      color: _kBlue.withValues(alpha: 0.1),
                      border: Border.all(color: _kBlue.withValues(alpha: 0.25))),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: _kBlue, size: 16)),
                  const SizedBox(width: 10),
                  Text(esEdicion ? 'Editar cliente' : 'Nuevo cliente',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: sheetTxt)),
                  const Spacer(),
                  GestureDetector(onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close_rounded, size: 20, color: sheetSub)),
                ])),
              Divider(height: 20, indent: 20, endIndent: 20, color: sheetBdr),
              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _field(nombreCtrl, 'Nombre *', 'Ej. Juan García'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(telCtrl, 'Teléfono', '+34 600 000 000')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(correoCtrl, 'Correo', 'juan@mail.com')),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(nifCtrl, 'NIF / CIF', '12345678A')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(ciudadCtrl, 'Ciudad', 'Madrid')),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(dirCtrl, 'Dirección', 'Calle...')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(cumpleCtrl, 'Cumpleaños', 'DD/MM')),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(instagramCtrl, 'Instagram', '@usuario')),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('CÓMO NOS CONOCIÓ', style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w600, color: sheetSub, letterSpacing: 0.4)),
                      const SizedBox(height: 5),
                      StatefulBuilder(builder: (ctx2, setO) => DropdownButtonFormField<String>(
                        value: origenSel,
                        dropdownColor: sheetBg,
                        style: TextStyle(fontSize: 12, color: sheetTxt),
                        decoration: InputDecoration(
                          filled: true, fillColor: _bg, isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: sheetBdr)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: sheetBdr)),
                        ),
                        hint: Text('Seleccionar', style: TextStyle(fontSize: 12, color: sheetSub)),
                        items: ['Web', 'Reserva online', 'Referido', 'Redes sociales',
                                'Directo', 'Publicidad', 'Otro']
                            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                            .toList(),
                        onChanged: (v) { setO(() => origenSel = v); },
                      )),
                    ])),
                  ]),
                  const SizedBox(height: 10),
                  _field(prefCtrl, 'Preferencias / Alergias', 'Sin gluten, alergia a frutos secos...', maxLines: 2),
                  const SizedBox(height: 10),
                  _field(notasCtrl, 'Notas internas', 'Observaciones...', maxLines: 2),
                  const SizedBox(height: 12),
                  Text('ETIQUETAS', style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w600, color: sheetSub, letterSpacing: 0.4)),
                  const SizedBox(height: 7),
                  Wrap(spacing: 7, runSpacing: 7, children: _kEtiquetas.map((tag) {
                    const colors = {'VIP': _kOrange, 'Frecuente': _kGreen,
                                    'Moroso': _kRed, 'Proveedor': _kBlue,
                                    'Potencial': Color(0xFF8B5CF6)};
                    final color = colors[tag] ?? _kBlue;
                    final sel   = etiqSel.contains(tag);
                    return GestureDetector(
                      onTap: () => setS(() { sel ? etiqSel.remove(tag) : etiqSel.add(tag); }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel ? color.withValues(alpha: 0.15) : _bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? color.withValues(alpha: 0.5) : sheetBdr)),
                        child: Text(tag, style: TextStyle(fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                          color: sel ? color : sheetSub))));
                  }).toList()),
                  const SizedBox(height: 20),
                ]),
              )),
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Row(children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(foregroundColor: sheetSub),
                    child: const Text('Cancelar')),
                  const Spacer(),
                  FilledButton(
                    onPressed: guardando ? null : () async {
                      final nombre = nombreCtrl.text.trim();
                      if (nombre.isEmpty) return;
                      setS(() => guardando = true);
                      try {
                        final datos = {
                          'nombre':    nombre,
                          'telefono':  telCtrl.text.trim(),
                          'correo':    correoCtrl.text.trim(),
                          if (nifCtrl.text.trim().isNotEmpty)       'nif':          nifCtrl.text.trim(),
                          if (ciudadCtrl.text.trim().isNotEmpty)    'ciudad':       ciudadCtrl.text.trim(),
                          if (dirCtrl.text.trim().isNotEmpty)       'direccion':    dirCtrl.text.trim(),
                          if (cumpleCtrl.text.trim().isNotEmpty)    'fecha_nacimiento': cumpleCtrl.text.trim(),
                          if (instagramCtrl.text.trim().isNotEmpty) 'instagram':    instagramCtrl.text.trim(),
                          if (prefCtrl.text.trim().isNotEmpty)      'preferencias': prefCtrl.text.trim(),
                          if (notasCtrl.text.trim().isNotEmpty)     'notas':        notasCtrl.text.trim(),
                          if (origenSel != null)                    'origen':       origenSel,
                          'etiquetas': etiqSel.toList(),
                          'activo': true,
                        };
                        final col = _firestore.collection('empresas')
                            .doc(widget.empresaId).collection('clientes');
                        if (esEdicion) {
                          await col.doc(id).update(datos);
                        } else {
                          datos['fecha_registro']  = Timestamp.now();
                          datos['total_gastado']   = 0.0;
                          datos['numero_reservas'] = 0;
                          final docRef = await col.add(datos);
                          // Notificación interna para el propietario
                          _firestore
                              .collection('notificaciones')
                              .doc(widget.empresaId)
                              .collection('items')
                              .add({
                            'tipo': 'nuevo_cliente',
                            'titulo': 'Nuevo cliente añadido',
                            'cuerpo': 'Se ha registrado el cliente: $nombre',
                            'creado_en': Timestamp.now(),
                            'leida': false,
                            'remitente_nombre': nombre,
                          }).ignore();
                          // Email de bienvenida si tiene correo
                          final correoCliente = correoCtrl.text.trim();
                          if (correoCliente.isNotEmpty && correoCliente.contains('@')) {
                            FirebaseFunctions.instanceFor(region: 'europe-west1')
                              .httpsCallable('enviarEmailBienvenidaCliente',
                                options: HttpsCallableOptions(timeout: const Duration(seconds: 15)))
                              .call({'empresaId': widget.empresaId, 'clienteId': docRef.id})
                              .then((_) {
                                if (mounted) FluxToast.exito(context,
                                  'Email de bienvenida enviado a $correoCliente',
                                  title: 'Email enviado');
                              })
                              .catchError((_) {}); // no bloquea si falla
                          }
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } finally {
                        if (ctx.mounted) setS(() => guardando = false);
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: _kBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: guardando
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(esEdicion ? 'Guardar' : 'Crear cliente',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ])),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _recalcularStats(String clienteId, String nombre) async {
    if (!mounted) return;
    FluxToast.aviso(context, 'Recalculando stats de $nombre...');
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final result = await fn
          .httpsCallable('recalcularStatsCliente',
              options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
          .call({'empresaId': widget.empresaId, 'clienteId': clienteId});
      final data   = result.data as Map<Object?, Object?>;
      final total  = (data['totalGastado'] as num?)?.toDouble() ?? 0.0;
      final nRes   = (data['numReservas']  as num?)?.toInt()    ?? 0;
      if (mounted) {
        FluxToast.exito(context,
          '${total.toStringAsFixed(2)}€ · $nRes reservas',
          title: 'Stats actualizados',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) FluxToast.error(context, 'Error ${e.code}: ${e.message}');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }

  Future<String?> _generarCSV(BuildContext context) async {
    FluxToast.aviso(context, 'Generando CSV...');
    final snap = await _firestore
        .collection('empresas').doc(widget.empresaId)
        .collection('clientes').get();
    final rows = <List<dynamic>>[
      ['Nombre', 'Teléfono', 'Correo', 'Ciudad', 'NIF', 'Etiquetas',
       'Gasto total', 'Reservas', 'Origen', 'Fecha registro'],
    ];
    for (final doc in snap.docs) {
      final d = doc.data();
      final reg = _parseDate(d['fecha_registro']);
      rows.add([
        d['nombre'] ?? '',  d['telefono'] ?? '', d['correo'] ?? '',
        d['ciudad'] ?? '',  d['nif'] ?? '',
        ((d['etiquetas'] as List?)?.join(', ')) ?? '',
        (d['total_gastado'] ?? 0).toString(),
        (d['numero_reservas'] ?? 0).toString(),
        d['origen'] ?? '',
        reg != null ? DateFormat('dd/MM/yyyy').format(reg) : '',
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  Future<void> _descargarCSV(BuildContext context) async {
    try {
      final csv      = await _generarCSV(context);
      if (csv == null) return;
      final fileName = 'clientes_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      if (!kIsWeb && Platform.isAndroid) {
        final downloads = await getDownloadsDirectory();
        final dir = downloads ?? await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(csv, flush: true);
        if (mounted) FluxToast.exito(context, 'Guardado en Descargas:\n$fileName', title: 'CSV descargado');
      } else {
        final tmp  = await getTemporaryDirectory();
        final file = File('${tmp.path}/$fileName');
        await file.writeAsString(csv);
        if (mounted) FluxToast.exito(context, 'Archivo guardado localmente', title: 'CSV guardado');
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al descargar: $e');
    }
  }

  Future<void> _compartirCSV(BuildContext context) async {
    try {
      final csv      = await _generarCSV(context);
      if (csv == null) return;
      final fileName = 'clientes_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final tmp  = await getTemporaryDirectory();
      final file = File('${tmp.path}/$fileName');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Clientes exportados',
      );
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al compartir: $e');
    }
  }

  Widget _field(TextEditingController ctrl, String label, String hint, {int maxLines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: _sub, letterSpacing: 0.4)),
        const SizedBox(height: 5),
        TextField(controller: ctrl, maxLines: maxLines,
          style: TextStyle(color: _text, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _sub, fontSize: 13),
            filled: true, fillColor: _bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBlue, width: 1.5)))),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// SHEET: Historial de pedidos y compras del cliente
// ══════════════════════════════════════════════════════════════════════════════

class _PedidosClienteSheet extends StatelessWidget {
  final String empresaId, clienteId, nombre, correo, telefono;
  final bool isDark;
  final Color surface, text, sub, border, card, bg;

  const _PedidosClienteSheet({
    required this.empresaId, required this.clienteId,
    required this.nombre, required this.correo, required this.telefono,
    required this.isDark, required this.surface, required this.text,
    required this.sub, required this.border, required this.card, required this.bg,
  });

  static const _purple = Color(0xFF8B5CF6);
  static const _green  = Color(0xFF22C55E);
  static const _orange = Color(0xFFF59E0B);
  static const _red    = Color(0xFFEF4444);
  static const _blue   = Color(0xFF3B82F6);

  Color _estadoColor(String? e) => switch (e) {
    'completado' || 'entregado' || 'pagado' => _green,
    'pendiente' || 'nuevo'                  => _orange,
    'cancelado' || 'rechazado'              => _red,
    _                                       => const Color(0xFF6B7280),
  };

  String _estadoLabel(String? e) => switch (e) {
    'completado' => 'Completado',
    'entregado'  => 'Entregado',
    'pagado'     => 'Pagado',
    'pendiente'  => 'Pendiente',
    'nuevo'      => 'Nuevo',
    'cancelado'  => 'Cancelado',
    'rechazado'  => 'Rechazado',
    'enviado'    => 'Enviado',
    _            => e ?? 'Desconocido',
  };

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    // Consulta por correo o nombre (dos queries independientes)
    final qEmail = correo.isNotEmpty
        ? db.collection('empresas').doc(empresaId).collection('pedidos')
            .where('cliente_correo', isEqualTo: correo)
            .orderBy('fecha_creacion', descending: true).limit(30)
        : null;
    final qNombre = db.collection('empresas').doc(empresaId).collection('pedidos')
        .where('cliente_nombre', isEqualTo: nombre)
        .orderBy('fecha_creacion', descending: true).limit(30);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
        ),
        child: Column(children: [
          // Handle
          Center(child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)),
          )),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _purple.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.shopping_bag_outlined, color: _purple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pedidos de $nombre',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(correo.isNotEmpty ? correo : 'Sin email registrado',
                    style: TextStyle(fontSize: 11, color: sub)),
              ])),
              // Acción rápida: enviar email
              if (correo.isNotEmpty)
                IconButton(
                  tooltip: 'Enviar email',
                  onPressed: () => launchUrl(Uri.parse('mailto:$correo')),
                  icon: Icon(Icons.email_outlined, color: sub, size: 20),
                ),
              if (telefono.isNotEmpty)
                IconButton(
                  tooltip: 'Llamar',
                  onPressed: () => launchUrl(Uri.parse('tel:$telefono')),
                  icon: Icon(Icons.phone_outlined, color: sub, size: 20),
                ),
            ]),
          ),
          Divider(height: 1, color: border),

          // Lista de pedidos
          Expanded(child: FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _cargarPedidos(db, qEmail, qNombre),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data ?? [];
              if (docs.isEmpty) return _buildVacio(context);
              // KPIs rápidos
              final totalGasto = docs.fold(0.0, (s, d) =>
                  s + ((d.data() as Map)['total'] as num? ?? 0).toDouble());
              return ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                // KPIs
                Row(children: [
                  _kpiChip(Icons.receipt_long_rounded, '${docs.length} pedidos', _purple),
                  const SizedBox(width: 8),
                  _kpiChip(Icons.euro_rounded, '${totalGasto.toStringAsFixed(2)} € total', _green),
                ]),
                const SizedBox(height: 16),
                // Pedidos
                ...docs.map((doc) => _pedidoTile(context, doc)),
              ]);
            },
          )),
        ]),
      ),
    );
  }

  Future<List<QueryDocumentSnapshot>> _cargarPedidos(
      FirebaseFirestore db,
      Query? qEmail,
      Query qNombre) async {
    final results = <QueryDocumentSnapshot>[];
    final ids     = <String>{};

    // 1. Buscar por cliente_id (más fiable - no depende de nombre exacto)
    final qId = db.collection('empresas').doc(empresaId).collection('pedidos')
        .where('cliente_id', isEqualTo: clienteId)
        .orderBy('fecha_creacion', descending: true).limit(30);
    final sId = await qId.get();
    for (final d in sId.docs) { results.add(d); ids.add(d.id); }

    // 2. Por email
    if (qEmail != null) {
      final s = await qEmail.get();
      for (final d in s.docs) { if (!ids.contains(d.id)) { results.add(d); ids.add(d.id); } }
    }

    // 3. Por nombre (fallback)
    final s2 = await qNombre.get();
    for (final d in s2.docs) {
      if (!ids.contains(d.id)) results.add(d);
    }

    results.sort((a, b) {
      final ta = (a.data() as Map)['fecha_creacion'];
      final tb = (b.data() as Map)['fecha_creacion'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });
    return results;
  }

  Widget _kpiChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ]),
  );

  Widget _pedidoTile(BuildContext context, QueryDocumentSnapshot doc) {
    final d      = doc.data() as Map<String, dynamic>;
    final estado = d['estado'] as String?;
    final total  = ((d['total'] as num?) ?? 0).toDouble();
    final lineas = (d['lineas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final ts     = d['fecha_creacion'];
    final fecha  = ts is Timestamp
        ? DateFormat('dd/MM/yy HH:mm').format(ts.toDate().toLocal())
        : '—';
    final numTicket = d['numero_ticket'] ?? d['numero_pedido'] ?? doc.id.substring(0, 6);
    final color   = _estadoColor(estado);
    final hasFactura = d['factura_id'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cabecera
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.shopping_bag_outlined, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pedido #$numTicket',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text)),
              Text(fecha, style: TextStyle(fontSize: 10, color: sub)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${total.toStringAsFixed(2)} €',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: text)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_estadoLabel(estado),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
          ]),
        ),
        // Líneas del pedido (máx 3)
        if (lineas.isNotEmpty) ...[
          Divider(height: 1, color: border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Builder(builder: (_) {
              final tiles = lineas.take(3).map((l) {
                final nom = l['nombre'] ?? l['producto_nombre'] ?? '—';
                final qty = l['cantidad'] ?? l['qty'] ?? 1;
                final p   = ((l['precio_unitario'] ?? l['precio'] ?? 0) as num).toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Container(width: 16, height: 16,
                      decoration: BoxDecoration(color: _purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: Center(child: Text('$qty',
                          style: const TextStyle(fontSize: 9, color: _purple, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 6),
                    Expanded(child: Text(nom,
                        style: TextStyle(fontSize: 11, color: text),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${p.toStringAsFixed(2)} €',
                        style: TextStyle(fontSize: 11, color: sub)),
                  ]),
                );
              }).toList();
              if (lineas.length > 3) {
                tiles.add(Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('+${lineas.length - 3} artículo(s) más',
                      style: TextStyle(fontSize: 10, color: sub)),
                ));
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: tiles);
            }),
          ),
        ],
        // Acciones
        Divider(height: 1, color: border),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Row(children: [
            if (hasFactura)
              _accionBtn(Icons.receipt_outlined, 'Ver factura', _blue, () {
                FluxToast.aviso(context, 'Abre el módulo Facturación para ver la factura.');
              })
            else
              _accionBtn(Icons.receipt_long_outlined, 'Crear factura', _green, () {
                _crearFacturaDesd(context, doc.id, d, total, lineas);
              }),
            const SizedBox(width: 6),
            if (correo.isNotEmpty)
              _accionBtn(Icons.send_outlined, 'Enviar email', _orange, () =>
                  launchUrl(Uri.parse(
                    'mailto:$correo?subject=Tu pedido %23$numTicket&body=Hola $nombre,%0A%0AAdjuntamos los detalles de tu pedido.'))),
            const SizedBox(width: 6),
            _accionBtn(Icons.copy_outlined, 'Copiar ref.', sub, () {
              FluxToast.exito(context, 'Referencia: $numTicket');
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _accionBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );

  void _crearFacturaDesd(BuildContext context, String pedidoId,
      Map<String, dynamic> d, double total, List<Map<String, dynamic>> lineas) {
    // Marca el pedido con la intención de crear factura y redirige
    FluxToast.aviso(context,
      'Ve a Facturación → Nueva factura y selecciona a "$nombre" como cliente.',
      title: 'Tip',
    );
  }

  Widget _buildVacio(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.shopping_bag_outlined, size: 52, color: Color(0xFFD1D5DB)),
      const SizedBox(height: 14),
      Text('Sin pedidos registrados',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sub)),
      const SizedBox(height: 6),
      Text('Los pedidos vinculados a "$nombre"\naparecerán aquí automáticamente.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: sub, height: 1.5)),
    ]),
  );
}
