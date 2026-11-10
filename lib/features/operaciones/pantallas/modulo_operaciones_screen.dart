import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../fichajes/pantallas/pantalla_alerta_despacho.dart';
import 'cad_operaciones_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO OPERACIONES — Despacho de emergencias
//
// Solo visible para admin/propietario.
// Permite crear alertas de despacho que llegan como FCM a los operarios.
// ═══════════════════════════════════════════════════════════════════════════════

const _kRed    = Color(0xFFDC2626);
const _kAmber  = Color(0xFFD97706);
const _kGreen  = Color(0xFF16A34A);
const _kBlue   = Color(0xFF1D4ED8);
const _kBg     = Color(0xFFF8FAFC);
const _kSurf   = Colors.white;
const _kSub    = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);

class ModuloOperacionesScreen extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;

  const ModuloOperacionesScreen({
    super.key,
    required this.empresaId,
    this.esAdmin = false,
  });

  @override
  State<ModuloOperacionesScreen> createState() => _ModuloOperacionesScreenState();
}

class _ModuloOperacionesScreenState extends State<ModuloOperacionesScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.esAdmin ? 0 : 1;
  }

  @override
  Widget build(BuildContext context) {
    // Admin → CAD completo con mapa OSRM
    if (widget.esAdmin) {
      return CADOperacionesScreen(empresaId: widget.empresaId);
    }

    // Staff → pantalla de alertas con tab bar siempre visible (funciona en modo embebido y pushed)
    final canPop = ModalRoute.of(context)?.isFirst == false;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: canPop ? FluixAppBar(titulo: 'Operaciones', showLeading: true) : null,
      body: Column(children: [
        Container(
          color: _kSurf,
          child: Row(children: [
            Expanded(child: _tabBtn(1, Icons.radio_button_checked_rounded, 'Activas')),
            Expanded(child: _tabBtn(2, Icons.history_rounded, 'Historial')),
          ]),
        ),
        const Divider(height: 1, color: _kBorder),
        Expanded(
          child: IndexedStack(index: _tab - 1, children: [
            _ListaAlertas(empresaId: widget.empresaId, soloActivas: true),
            _ListaAlertas(empresaId: widget.empresaId, soloActivas: false),
          ]),
        ),
      ]),
    );
  }

  Widget _tabBtn(int idx, IconData icon, String label) {
    final sel = _tab == idx;
    return InkWell(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: sel ? _kRed : Colors.transparent, width: 2)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: sel ? _kRed : _kSub),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontSize: 12,
            color: sel ? _kRed : _kSub,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
          )),
        ]),
      ),
    );
  }
}

// ── Lista de alertas (activas / historial) ─────────────────────────────────────

class _ListaAlertas extends StatelessWidget {
  final String empresaId;
  final bool soloActivas;
  const _ListaAlertas({required this.empresaId, required this.soloActivas});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('empresas').doc(empresaId)
        .collection('alertas_despacho')
        .orderBy('fecha_hora', descending: true)
        .limit(50);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kRed));
        }
        final docs = (snap.data?.docs ?? []).where((d) {
          final estado = d['estado'] as String? ?? '';
          if (soloActivas) return estado == 'pendiente' || estado == 'aceptada' || estado == 'activa';
          return estado == 'rechazada' || estado == 'atendida';
        }).toList();

        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(soloActivas ? Icons.radio_button_unchecked_rounded : Icons.history_rounded,
                size: 48, color: _kBorder),
            const SizedBox(height: 12),
            Text(soloActivas ? 'No hay alertas activas' : 'Sin historial',
                style: const TextStyle(color: _kSub)),
          ]));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _AlertaCard(doc: docs[i], empresaId: empresaId),
        );
      },
    );
  }
}

class _AlertaCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String empresaId;
  const _AlertaCard({required this.doc, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final tipo      = d['tipo_codigo'] as String? ?? '?';
    final prioridad = d['prioridad']   as String? ?? 'alta';
    final estado    = d['estado']      as String? ?? 'pendiente';
    final dir       = d['direccion']   as String? ?? '';
    final loc       = d['localidad']   as String? ?? '';
    final ts        = (d['fecha_hora'] as Timestamp?)?.toDate();
    final fmt       = ts != null ? DateFormat('dd/MM HH:mm').format(ts) : '?';

    final col = switch (prioridad) {
      'critica' => _kRed,
      'alta'    => const Color(0xFFEA580C),
      'media'   => _kAmber,
      _         => _kGreen,
    };
    final estadoCol = switch (estado) {
      'aceptada'  => _kGreen,
      'rechazada' => _kRed,
      'atendida'  => _kBlue,
      _           => _kAmber,
    };

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PantallaAlertaDespacho(
          empresaId: empresaId,
          alertaId: doc.id,
        ),
      )),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurf,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: col.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(child: Text(tipo.length > 3 ? tipo.substring(0,3) : tipo,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: col))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(tipo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: col)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: estadoCol.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(estado.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: estadoCol)),
              ),
            ]),
            Text('$dir, $loc', style: const TextStyle(fontSize: 12, color: _kSub)),
          ])),
          Text(fmt, style: const TextStyle(fontSize: 11, color: _kSub)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: _kBorder, size: 20),
        ]),
      ),
    );
  }
}
