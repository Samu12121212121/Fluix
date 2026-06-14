import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/trofeos_service.dart';
import '../../../domain/modelos/monedero.dart';
import '../../tienda_monedas/pantalla_tienda_monedas.dart';

const _kBg      = Color(0xFF0A0F23);
const _kSurface = Color(0xFF151932);
const _kCard    = Color(0xFF1E2139);
const _kBorde   = Color(0xFF2A2E45);
const _kTexto   = Colors.white;
const _kMuted   = Color(0xFFB0B3C1);
const _kOro     = Color(0xFFFFB830);
const _kVerde   = Color(0xFF00FFC8);
const _kRojo    = Color(0xFFFF5C5C);

class PantallaMonedero extends StatelessWidget {
  const PantallaMonedero({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        foregroundColor: _kTexto,
        title: const Text('Mi Monedero', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaTiendaMonedas())),
            icon: const Text('🛍️'),
            label: const Text('Tienda', style: TextStyle(color: _kOro, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _HeaderMonedero(uid: _uid)),
        SliverToBoxAdapter(child: _SeccionStats(uid: _uid)),
        const SliverToBoxAdapter(child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('Historial de movimientos', style: TextStyle(color: _kTexto, fontSize: 15, fontWeight: FontWeight.bold)),
        )),
        _ListaTransacciones(uid: _uid),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }
}

// ── Header con saldo principal ────────────────────────────────────────────────

class _HeaderMonedero extends StatelessWidget {
  final String uid;
  const _HeaderMonedero({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MonederoModel>(
      stream: TrofeosService.streamMonedero(uid),
      builder: (_, snap) {
        final monedero = snap.data ?? const MonederoModel(saldo: 0, totalGanado: 0, totalCanjeado: 0);
        return StreamBuilder<int>(
          stream: TrofeosService.streamMonedas(uid),
          builder: (_, snapM) {
            final saldo = snapM.data ?? monedero.saldo;
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1A1F3E), const Color(0xFF252A45)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kOro.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [BoxShadow(color: _kOro.withValues(alpha: 0.15), blurRadius: 24, spreadRadius: 2)],
              ),
              child: Column(children: [
                const Text('Saldo disponible', style: TextStyle(color: _kMuted, fontSize: 13)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🪙', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 10),
                  Text('$saldo', style: const TextStyle(color: _kOro, fontSize: 48, fontWeight: FontWeight.w900, height: 1.0)),
                ]),
                const SizedBox(height: 6),
                const Text('monedas', style: TextStyle(color: _kMuted, fontSize: 12)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaTiendaMonedas())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kOro,
                      foregroundColor: const Color(0xFF0A0F23),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Text('🛍️'),
                    label: const Text('Ir a la Tienda', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Stats: total ganado / canjeado ────────────────────────────────────────────

class _SeccionStats extends StatelessWidget {
  final String uid;
  const _SeccionStats({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MonederoModel>(
      stream: TrofeosService.streamMonedero(uid),
      builder: (_, snap) {
        final m = snap.data ?? const MonederoModel(saldo: 0, totalGanado: 0, totalCanjeado: 0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: _StatCard(label: 'Total ganado', valor: m.totalGanado, color: _kVerde, emoji: '📈')),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'Total canjeado', valor: m.totalCanjeado, color: _kRojo, emoji: '🛒')),
          ]),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, emoji;
  final int valor;
  final Color color;
  const _StatCard({required this.label, required this.valor, required this.color, required this.emoji});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 6),
      Row(children: [
        const Text('🪙', style: TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text('$valor', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: _kMuted, fontSize: 11)),
    ]),
  );
}

// ── Lista de transacciones ────────────────────────────────────────────────────

class _ListaTransacciones extends StatelessWidget {
  final String uid;
  const _ListaTransacciones({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransaccionModel>>(
      stream: TrofeosService.streamTransacciones(uid),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: _kOro, strokeWidth: 2)),
          ));
        }
        final lista = snap.data ?? [];
        if (lista.isEmpty) {
          return const SliverToBoxAdapter(child: _EstadoVacio());
        }
        return SliverList(delegate: SliverChildBuilderDelegate(
          (_, i) => _FilaTransaccion(tx: lista[i]),
          childCount: lista.length,
        ));
      },
    );
  }
}

class _FilaTransaccion extends StatelessWidget {
  final TransaccionModel tx;
  const _FilaTransaccion({required this.tx});

  @override
  Widget build(BuildContext context) {
    final esGanancia = tx.tipo == TipoTransaccion.ganancia;
    final color = esGanancia ? _kVerde : _kRojo;
    final signo = esGanancia ? '+' : '-';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorde, width: 0.5),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Text(esGanancia ? '🏆' : '🛍️', style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx.concepto, style: const TextStyle(color: _kTexto, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(_formatFecha(tx.fecha), style: const TextStyle(color: _kMuted, fontSize: 11)),
        ])),
        Row(children: [
          const Text('🪙', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text('$signo${tx.cantidad}', style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }

  String _formatFecha(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24)  return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7)    return 'Hace ${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🪙', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('Sin movimientos aún', style: TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Completa trofeos para ganar monedas', style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}
