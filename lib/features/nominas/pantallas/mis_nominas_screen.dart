import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/core/widgets/fluix_app_bar.dart';
import '../../../domain/modelos/nomina.dart';
import '../../../services/nomina_pdf_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MIS NÓMINAS — Vista del empleado (rol staff)
// Lee de empresas/{id}/nominas filtrando por empleado_id == uid.
// PDF se genera on-demand — no hay URL almacenada.
// ═════════════════════════════════════════════════════════════════════════════

const _kBlue   = Color(0xFF3B82F6);
const _kGreen  = Color(0xFF16A34A);
const _kAmber  = Color(0xFFF59E0B);
const _kBorder = Color(0xFFE2E8F0);
const _kBg     = Color(0xFFF5F7FA);
const _kText   = Color(0xFF0F172A);
const _kSub    = Color(0xFF64748B);

const _meses = [
  '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  'Paga extra 1', 'Paga extra 2',
];

class MisNominasScreen extends StatefulWidget {
  final String empresaId;
  final String? empleadoUid; // si null, usa el usuario autenticado actual

  const MisNominasScreen({super.key, required this.empresaId, this.empleadoUid});

  @override
  State<MisNominasScreen> createState() => _MisNominasScreenState();
}

class _MisNominasScreenState extends State<MisNominasScreen> {
  final _db  = FirebaseFirestore.instance;

  String get _uid => widget.empleadoUid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  int _anioFiltro = DateTime.now().year;

  Stream<List<Nomina>> get _stream => _db
      .collection('empresas').doc(widget.empresaId)
      .collection('nominas')
      .where('empleado_id', isEqualTo: _uid)
      .where('anio', isEqualTo: _anioFiltro)
      .orderBy('mes', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
          .toList());

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.isFirst == false;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: canPop ? FluixAppBar(
        titulo: 'Mis Nóminas',
        showLeading: true,
        extraActions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _anioFiltro,
              style: const TextStyle(fontSize: 13, color: _kText),
              icon: const Icon(Icons.arrow_drop_down, size: 16, color: _kSub),
              items: List.generate(5, (i) => DateTime.now().year - i)
                  .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                  .toList(),
              onChanged: (v) => setState(() => _anioFiltro = v!),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ) : null,
      body: StreamBuilder<List<Nomina>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _kBlue));
          }
          final nominas = snap.data ?? [];

          if (nominas.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_outlined, size: 64,
                    color: const Color(0xFFCBD5E1)),
                const SizedBox(height: 16),
                Text('No hay nóminas en $_anioFiltro',
                    style: const TextStyle(fontSize: 15, color: _kSub,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Aparecerán aquí cuando tu empresa las genere',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ]),
            );
          }

          final totalNeto = nominas.fold<double>(0, (s, n) => s + n.salarioNeto);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildResumen(nominas.length, totalNeto),
              const SizedBox(height: 12),
              ...nominas.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildItem(n),
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResumen(int count, double totalNeto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Expanded(child: _kpi('Nóminas en $_anioFiltro', '$count')),
        Container(width: 1, height: 40,
            color: _kGreen.withValues(alpha: 0.2)),
        Expanded(child: _kpi('Neto acumulado',
            '${totalNeto.toStringAsFixed(0)} €')),
      ]),
    );
  }

  Widget _kpi(String label, String valor) => Column(children: [
    Text(valor, style: const TextStyle(fontSize: 18,
        fontWeight: FontWeight.bold, color: _kText)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 10, color: _kSub),
        textAlign: TextAlign.center),
  ]);

  Widget _buildItem(Nomina n) {
    final mes = n.mes.clamp(1, 14);
    final colorEstado = switch (n.estado) {
      EstadoNomina.pagada   => _kGreen,
      EstadoNomina.aprobada => _kBlue,
      EstadoNomina.borrador => _kAmber,
    };

    return GestureDetector(
      onTap: () => NominaPdfService.verNominaPdf(context, n, widget.empresaId, modoEmpleado: true),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: Color(0xFFEF4444), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_meses[mes],
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: _kText)),
              const SizedBox(height: 3),
              Row(children: [
                Text('${n.anio}',
                    style: const TextStyle(fontSize: 12, color: _kSub)),
                const Text(' · ',
                    style: TextStyle(fontSize: 12, color: _kSub)),
                Text('${n.salarioNeto.toStringAsFixed(2)} € neto',
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700, color: colorEstado)),
              ]),
              const SizedBox(height: 2),
              Text('Coste empresa: ${n.costeTotalEmpresa.toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 11,
                      color: Color(0xFF94A3B8))),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(n.estado.etiqueta,
                style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, color: colorEstado)),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded,
              color: const Color(0xFFCBD5E1), size: 20),
        ]),
      ),
    );
  }
}
