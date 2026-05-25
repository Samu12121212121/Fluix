import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─── Paleta TPV ───────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFF111111);
  static const azul     = Color(0xFF1565C0);
  static const card     = Color(0xFF1E2139);
  static const divider  = Color(0xFF333333);
  static const cian     = Color(0xFF00BCD4);
  static const neon     = Color(0xFF00FFC8);
  static const texto    = Colors.white;
  static const muted    = Colors.white70;
  static const hint     = Colors.white38;
  // Estados
  static const pendiente  = Colors.orangeAccent;
  static const preparando = Color(0xFF00BCD4);
  static const terminada  = Color(0xFF00FFC8);
  static const urgente    = Color(0xFFFF4757);
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class PantallaCocinaScreen extends StatefulWidget {
  final String empresaId;
  const PantallaCocinaScreen({super.key, required this.empresaId});

  @override
  State<PantallaCocinaScreen> createState() => _PantallaCocinaScreenState();
}

class _PantallaCocinaScreenState extends State<PantallaCocinaScreen> {
  final _db = FirebaseFirestore.instance;
  final Map<String, String> _nombresMesa = {};

  Future<String> _nombreMesa(String mesaId) async {
    if (mesaId.isEmpty) return 'Sin mesa';
    if (_nombresMesa.containsKey(mesaId)) return _nombresMesa[mesaId]!;
    try {
      final doc = await _db
          .collection('empresas').doc(empresaId)
          .collection('mesas').doc(mesaId)
          .get();
      final n = doc.data()?['nombre'] as String?
          ?? doc.data()?['name'] as String?
          ?? 'Mesa';
      _nombresMesa[mesaId] = n;
      return n;
    } catch (_) {
      return 'Mesa';
    }
  }

  String get empresaId => widget.empresaId;

  Future<void> _cambiarEstado(String id, String estado) async {
    final u = <String, dynamic>{
      'estado_cocina': estado,
      'actualizado_at': FieldValue.serverTimestamp(),
    };
    if (estado == 'en_preparacion') u['inicio_preparacion'] = FieldValue.serverTimestamp();
    if (estado == 'terminada')      u['fin_preparacion']    = FieldValue.serverTimestamp();
    await _db.collection('empresas').doc(empresaId)
        .collection('comandas').doc(id).update(u);
  }

  Future<void> _eliminarComanda(BuildContext ctx, String id) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('¿Eliminar comanda?',
            style: TextStyle(color: _C.texto, fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
          'Desaparecerá de cocina. El pedido en el TPV no se ve afectado.',
          style: TextStyle(color: _C.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _C.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _C.urgente,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _db.collection('empresas').doc(empresaId)
          .collection('comandas').doc(id)
          .update({'enviada_cocina': false, 'estado_cocina': 'eliminada_cocina'});
    }
  }

  void _abrirDetalle(BuildContext ctx, ComandaCocina c) {
    showDialog(
      context: ctx,
      barrierColor: Colors.black87,
      builder: (_) => _ModalDetalle(
        comanda: c,
        onCambiarEstado: (e) => _cambiarEstado(c.id, e),
        onEliminar: c.estadoCocina == 'terminada'
            ? () => _eliminarComanda(ctx, c.id)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(children: [
        _AppBarCocina(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('empresas').doc(empresaId)
                .collection('comandas')
                .where('enviada_cocina', isEqualTo: true)
                .where('estado', isEqualTo: 'abierta')
                .orderBy('fecha_envio_cocina', descending: false)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: _C.cian, strokeWidth: 2));
              }
              if (snap.hasError) {
                return _EstadoError(error: snap.error.toString());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const _EstadoVacio();

              final all = docs.map((d) => ComandaCocina.fromFirestore(d)).toList();
              final pendientes = all.where((c) =>
              c.estadoCocina == null ||
                  c.estadoCocina == 'pendiente' ||
                  c.estadoCocina == 'en_preparacion').toList();
              final listas = all.where((c) => c.estadoCocina == 'terminada').toList();

              return Row(children: [
                // ── IZQUIERDA: Pendientes + Preparando ──────────────────
                Expanded(
                  flex: 2,
                  child: _ColPendientes(
                    comandas: pendientes,
                    onCambiarEstado: (c, e) => _cambiarEstado(c.id, e),
                    onTap: (c) => _abrirDetalle(ctx, c),
                    nombreMesa: _nombreMesa,
                  ),
                ),
                // Divisor vertical
                Container(width: 1, color: _C.divider),
                // ── DERECHA: Listos ──────────────────────────────────────
                Expanded(
                  child: _ColListos(
                    comandas: listas,
                    onTap: (c) => _abrirDetalle(ctx, c),
                    onEliminar: (c) => _eliminarComanda(ctx, c.id),
                    nombreMesa: _nombreMesa,
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _AppBarCocina extends StatelessWidget {
  const _AppBarCocina();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFF2A2E45),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(alignment: Alignment.center, children: [
        // Botón volver
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.white),
            splashRadius: 20,
          ),
        ),
        // Título
        const Text('COCINA',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 3)),
        // Reloj
        const Align(
          alignment: Alignment.centerRight,
          child: _RelojWidget(),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLUMNA IZQUIERDA — PENDIENTES (incluye en_preparacion)
// ─────────────────────────────────────────────────────────────────────────────
class _ColPendientes extends StatelessWidget {
  final List<ComandaCocina> comandas;
  final void Function(ComandaCocina, String) onCambiarEstado;
  final void Function(ComandaCocina) onTap;
  final Future<String> Function(String) nombreMesa;

  const _ColPendientes({
    required this.comandas, required this.onCambiarEstado,
    required this.onTap, required this.nombreMesa,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header columna
      Container(
        height: 48,
        color: _C.pendiente.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          const Icon(Icons.hourglass_top_rounded,
              color: _C.pendiente, size: 18),
          const SizedBox(width: 8),
          const Text('PENDIENTES',
              style: TextStyle(
                  color: _C.pendiente,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(width: 10),
          _Badge('${comandas.length}', _C.pendiente),
        ]),
      ),
      const Divider(height: 1, color: _C.divider),
      // Contenido
      Expanded(
        child: comandas.isEmpty
            ? _VacioCol(
            icon: Icons.check_circle_outline_rounded,
            msg: 'Sin pendientes')
            : LayoutBuilder(builder: (_, bc) {
          final ncols = (bc.maxWidth / 260).floor().clamp(1, 4);
          return _WrapComandas(
            comandas: comandas,
            ncols: ncols,
            nombreMesa: nombreMesa,
            onTap: onTap,
            onCambiarEstado: onCambiarEstado,
          );
        }),
      ),
    ]);
  }
}

class _WrapComandas extends StatelessWidget {
  final List<ComandaCocina> comandas;
  final int ncols;
  final Future<String> Function(String) nombreMesa;
  final void Function(ComandaCocina) onTap;
  final void Function(ComandaCocina, String) onCambiarEstado;

  const _WrapComandas({
    required this.comandas, required this.ncols,
    required this.nombreMesa, required this.onTap,
    required this.onCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <List<ComandaCocina>>[];
    for (int i = 0; i < comandas.length; i += ncols) {
      rows.add(comandas.sublist(i, (i + ncols).clamp(0, comandas.length)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(children: rows.map((row) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...row.map((c) => Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 10),
              child: _TarjetaPendiente(
                comanda: c,
                nombreMesa: nombreMesa,
                onTap: () => onTap(c),
                onAccion: () => onCambiarEstado(
                    c,
                    c.estadoCocina == 'en_preparacion'
                        ? 'terminada'
                        : 'en_preparacion'),
              ),
            ),
          )),
          ...List.generate(
              ncols - row.length, (_) => const Expanded(child: SizedBox())),
        ],
      )).toList()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA PENDIENTE
// ─────────────────────────────────────────────────────────────────────────────
class _TarjetaPendiente extends StatelessWidget {
  final ComandaCocina comanda;
  final Future<String> Function(String) nombreMesa;
  final VoidCallback onTap;
  final VoidCallback onAccion;

  const _TarjetaPendiente({
    required this.comanda, required this.nombreMesa,
    required this.onTap, required this.onAccion,
  });

  bool get _enPreparacion => comanda.estadoCocina == 'en_preparacion';

  int get _minutos {
    if (comanda.fechaEnvioCocina == null) return 0;
    return DateTime.now()
        .difference(comanda.fechaEnvioCocina!.toDate())
        .inMinutes;
  }

  Color get _colorTiempo {
    final m = _minutos;
    if (m < 10) return _C.terminada;
    if (m < 20) return _C.pendiente;
    return _C.urgente;
  }

  String get _textoTiempo {
    final m = _minutos;
    if (m == 0) return 'Ahora';
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _enPreparacion ? _C.cian : _C.pendiente;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _minutos >= 20
                ? _C.urgente
                : accentColor.withValues(alpha: 0.4),
            width: _minutos >= 20 ? 1.5 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header tarjeta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(children: [
              // Badge estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _enPreparacion ? 'HACIENDO' : 'NUEVO',
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FutureBuilder<String>(
                  future: nombreMesa(comanda.mesaId),
                  builder: (_, s) => Text(
                    s.data ?? comanda.mesaNombre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Tiempo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _colorTiempo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_textoTiempo,
                    style: TextStyle(
                        color: _colorTiempo,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          // Productos — TODOS
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: comanda.lineas.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text('${l.cantidad.toInt()}',
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(l.nombre,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (l.notas?.isNotEmpty ?? false) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.notes_rounded,
                        size: 12, color: _C.pendiente),
                  ],
                ]),
              )).toList(),
            ),
          ),
          // Nota general
          if (comanda.notaGeneral?.isNotEmpty ?? false)
            Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _C.pendiente.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _C.pendiente.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.sticky_note_2_rounded,
                    size: 11, color: _C.pendiente),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(comanda.notaGeneral!,
                      style: const TextStyle(
                          color: _C.pendiente, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          // Botón acción
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: FilledButton.icon(
                onPressed: onAccion,
                icon: Icon(
                    _enPreparacion
                        ? Icons.check_rounded
                        : Icons.play_arrow_rounded,
                    size: 16),
                label: Text(
                    _enPreparacion ? 'Listo' : 'Iniciar',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor:
                  _enPreparacion ? _C.terminada : _C.azul,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLUMNA DERECHA — LISTOS
// ─────────────────────────────────────────────────────────────────────────────
class _ColListos extends StatelessWidget {
  final List<ComandaCocina> comandas;
  final void Function(ComandaCocina) onTap;
  final void Function(ComandaCocina) onEliminar;
  final Future<String> Function(String) nombreMesa;

  const _ColListos({
    required this.comandas, required this.onTap,
    required this.onEliminar, required this.nombreMesa,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        height: 48,
        color: _C.terminada.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: _C.terminada, size: 18),
          const SizedBox(width: 8),
          const Text('LISTOS',
              style: TextStyle(
                  color: _C.terminada,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(width: 10),
          _Badge('${comandas.length}', _C.terminada),
          const Spacer(),
          const Text('Pulsa ✕ para eliminar',
              style: TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      ),
      const Divider(height: 1, color: _C.divider),
      // Lista
      Expanded(
        child: comandas.isEmpty
            ? const _VacioCol(
            icon: Icons.done_all_rounded,
            msg: 'Sin pedidos listos')
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: comandas.length,
          itemBuilder: (_, i) => _TarjetaLista(
            comanda: comandas[i],
            nombreMesa: nombreMesa,
            onTap: () => onTap(comandas[i]),
            onEliminar: () => onEliminar(comandas[i]),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA LISTA
// ─────────────────────────────────────────────────────────────────────────────
class _TarjetaLista extends StatelessWidget {
  final ComandaCocina comanda;
  final Future<String> Function(String) nombreMesa;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  const _TarjetaLista({
    required this.comanda, required this.nombreMesa,
    required this.onTap, required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _C.terminada.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _C.terminada.withValues(alpha: 0.08),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  size: 13, color: _C.terminada),
              const SizedBox(width: 6),
              Expanded(
                child: FutureBuilder<String>(
                  future: nombreMesa(comanda.mesaId),
                  builder: (_, s) => Text(
                    s.data ?? comanda.mesaNombre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Botón eliminar
              GestureDetector(
                onTap: onEliminar,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _C.urgente.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: _C.urgente),
                ),
              ),
            ]),
          ),
          // Productos
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: comanda.lineas.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Text('${l.cantidad.toInt()}×',
                      style: const TextStyle(
                          color: _C.terminada,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(l.nombre,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              )).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL DETALLE
// ─────────────────────────────────────────────────────────────────────────────
class _ModalDetalle extends StatelessWidget {
  final ComandaCocina comanda;
  final void Function(String) onCambiarEstado;
  final VoidCallback? onEliminar;

  const _ModalDetalle({
    required this.comanda, required this.onCambiarEstado, this.onEliminar,
  });

  Color get _col {
    switch (comanda.estadoCocina) {
      case 'en_preparacion': return _C.cian;
      case 'terminada':      return _C.terminada;
      default:               return _C.pendiente;
    }
  }

  String get _label {
    switch (comanda.estadoCocina) {
      case 'en_preparacion': return 'En preparación';
      case 'terminada':      return 'Listo para servir';
      default:               return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.50,
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.divider),
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            decoration: BoxDecoration(
              color: _C.azul,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(comanda.mesaNombre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_label,
                    style: TextStyle(
                        color: _col,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                ),
              ),
            ]),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiempos
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (comanda.fechaEnvioCocina != null)
                        _Chip(Icons.send_rounded, 'Enviada',
                            DateFormat('HH:mm:ss').format(
                                comanda.fechaEnvioCocina!.toDate()),
                            Colors.white54),
                      if (comanda.inicioPreparacion != null)
                        _Chip(Icons.play_arrow_rounded, 'Iniciada',
                            DateFormat('HH:mm:ss').format(
                                comanda.inicioPreparacion!.toDate()),
                            _C.cian),
                      if (comanda.finPreparacion != null)
                        _Chip(Icons.check_rounded, 'Lista',
                            DateFormat('HH:mm:ss').format(
                                comanda.finPreparacion!.toDate()),
                            _C.terminada),
                    ]),
                    const SizedBox(height: 16),

                    // Nota
                    if (comanda.notaGeneral?.isNotEmpty ?? false) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _C.pendiente.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _C.pendiente.withValues(alpha: 0.35)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.sticky_note_2_rounded,
                              color: _C.pendiente, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(comanda.notaGeneral!,
                                style: const TextStyle(
                                    color: _C.pendiente, fontSize: 13)),
                          ),
                        ]),
                      ),
                    ],

                    // Productos
                    const Text('PRODUCTOS',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 8),

                    ...comanda.lineas.map((l) => Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _C.divider),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _col.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text('${l.cantidad.toInt()}',
                              style: TextStyle(
                                  color: _col,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.nombre,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                if (l.notas?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: 3),
                                  Text(l.notas!,
                                      style: const TextStyle(
                                          color: _C.cian,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic)),
                                ],
                              ]),
                        ),
                      ]),
                    )),
                  ]),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _C.divider)),
            ),
            child: Column(children: [
              _BotonAccion(
                estado: comanda.estadoCocina,
                onAccion: (e) {
                  onCambiarEstado(e);
                  Navigator.pop(context);
                },
              ),
              if (onEliminar != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onEliminar!();
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 15),
                    label: const Text('Eliminar comanda',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.urgente,
                      side: BorderSide(
                          color: _C.urgente.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  final String? estado;
  final void Function(String) onAccion;
  const _BotonAccion({this.estado, required this.onAccion});

  @override
  Widget build(BuildContext context) {
    if (estado == 'terminada') {
      return Container(
        width: double.infinity, height: 44,
        decoration: BoxDecoration(
          color: _C.terminada.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.terminada.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.done_all_rounded, color: _C.terminada, size: 18),
          SizedBox(width: 8),
          Text('Lista para servir',
              style: TextStyle(
                  color: _C.terminada,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      );
    }
    final esPrep = estado == 'en_preparacion';
    return SizedBox(
      width: double.infinity, height: 44,
      child: FilledButton.icon(
        onPressed: () => onAccion(esPrep ? 'terminada' : 'en_preparacion'),
        icon: Icon(
            esPrep ? Icons.check_rounded : Icons.play_arrow_rounded,
            size: 18),
        label: Text(
            esPrep ? 'Marcar como listo' : 'Iniciar preparación',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: esPrep ? _C.terminada : _C.azul,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w900)),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final Color color;
  const _Chip(this.icon, this.label, this.valor, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 12),
      const SizedBox(width: 5),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w600)),
        Text(valor,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ]),
    ]),
  );
}

class _VacioCol extends StatelessWidget {
  final IconData icon;
  final String msg;
  const _VacioCol({required this.icon, required this.msg});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 44, color: Colors.white12),
      const SizedBox(height: 10),
      Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    ]),
  );
}

class _EstadoError extends StatelessWidget {
  final String error;
  const _EstadoError({required this.error});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded,
          size: 48, color: _C.urgente),
      const SizedBox(height: 12),
      const Text('Error al cargar',
          style: TextStyle(color: Colors.white, fontSize: 15,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(error,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
          textAlign: TextAlign.center),
    ]),
  );
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.kitchen_rounded, size: 56, color: Colors.white12),
      const SizedBox(height: 16),
      const Text('Sin comandas en cocina',
          style: TextStyle(color: Colors.white,
              fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 5),
      const Text('Las comandas aparecerán cuando se envíen desde el TPV',
          style: TextStyle(color: Colors.white38, fontSize: 12)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// RELOJ
// ─────────────────────────────────────────────────────────────────────────────
class _RelojWidget extends StatefulWidget {
  const _RelojWidget();

  @override
  State<_RelojWidget> createState() => _RelojWidgetState();
}

class _RelojWidgetState extends State<_RelojWidget> {
  late Timer _timer;
  late String _hora;

  @override
  void initState() {
    super.initState();
    _hora = DateFormat('HH:mm:ss').format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _hora = DateFormat('HH:mm:ss').format(DateTime.now()));
      }
    });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Text(
    _hora,
    style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
        letterSpacing: 0.5),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS
// ─────────────────────────────────────────────────────────────────────────────
class ComandaCocina {
  final String id;
  final String mesaId;
  final String mesaNombre;
  final List<LineaComandaCocina> lineas;
  final String? notaGeneral;
  final String? estadoCocina;
  final Timestamp? fechaEnvioCocina;
  final Timestamp? inicioPreparacion;
  final Timestamp? finPreparacion;

  ComandaCocina({
    required this.id, required this.mesaId, required this.mesaNombre,
    required this.lineas, this.notaGeneral, this.estadoCocina,
    this.fechaEnvioCocina, this.inicioPreparacion, this.finPreparacion,
  });

  factory ComandaCocina.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final mesaId = d['mesa_id'] as String? ?? '';
    return ComandaCocina(
      id:                doc.id,
      mesaId:            mesaId,
      mesaNombre:        d['mesa_nombre'] ?? d['mesaNombre']
          ?? d['nombre_mesa'] ?? d['mesa']
          ?? (mesaId.isNotEmpty ? mesaId : 'Mesa'),
      lineas:            (d['lineas'] as List<dynamic>?)
          ?.map((l) => LineaComandaCocina.fromMap(
          l as Map<String, dynamic>))
          .toList() ?? [],
      notaGeneral:       d['nota_general'] as String?,
      estadoCocina:      d['estado_cocina'] as String?,
      fechaEnvioCocina:  d['fecha_envio_cocina'] as Timestamp?,
      inicioPreparacion: d['inicio_preparacion'] as Timestamp?,
      finPreparacion:    d['fin_preparacion'] as Timestamp?,
    );
  }
}

class LineaComandaCocina {
  final String nombre;
  final double cantidad;
  final String? notas;

  LineaComandaCocina(
      {required this.nombre, required this.cantidad, this.notas});

  factory LineaComandaCocina.fromMap(Map<String, dynamic> m) =>
      LineaComandaCocina(
        nombre:   m['nombre'] as String? ?? 'Producto',
        cantidad: (m['cantidad'] as num? ?? 1).toDouble(),
        notas:    m['notas'] as String?,
      );
}