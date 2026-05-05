import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../../domain/modelos/factura.dart';
import '../../../domain/modelos/factura_recibida.dart';
import '../../../services/exportadores_aeat/libro_registro_iva_exporter.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA LIBROS REGISTRO IVA
// Art. 62-64 RIVA — Obligación de llevar libros registro de IVA
// Genera fichero AEAT formato ASCII (LL0 emitidas / LL1 recibidas)
// ═════════════════════════════════════════════════════════════════════════════

class PantallaLibrosRegistro extends StatefulWidget {
  final String empresaId;

  const PantallaLibrosRegistro({super.key, required this.empresaId});

  @override
  State<PantallaLibrosRegistro> createState() => _PantallaLibrosRegistroState();
}

class _PantallaLibrosRegistroState extends State<PantallaLibrosRegistro>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _anio = DateTime.now().year;
  int _mes  = DateTime.now().month;

  bool _generandoEmitidas  = false;
  bool _generandoRecibidas = false;

  String _nifEmpresa    = '';
  String _nombreEmpresa = '';

  final _db = FirebaseFirestore.instance;
  final _fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarEmpresa();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarEmpresa() async {
    final doc = await _db.collection('empresas').doc(widget.empresaId).get();
    final data = doc.data();
    if (data != null && mounted) {
      final perfil = data['perfil'] as Map<String, dynamic>? ?? {};
      setState(() {
        _nifEmpresa    = (perfil['nif'] as String?) ?? '';
        _nombreEmpresa = (perfil['nombre'] as String?) ?? '';
      });
    }
  }

  // ── Helpers de periodo ─────────────────────────────────────────────────────

  DateTime get _fechaInicio => DateTime(_anio, _mes, 1);
  DateTime get _fechaFin    => DateTime(_anio, _mes + 1, 0, 23, 59, 59);

  String get _periodoLabel {
    final m = DateFormat('MMMM yyyy', 'es_ES').format(DateTime(_anio, _mes));
    return m[0].toUpperCase() + m.substring(1);
  }

  // ── Exportar emitidas ──────────────────────────────────────────────────────

  Future<void> _exportarEmitidas() async {
    if (_nifEmpresa.isEmpty) {
      _snack('La empresa no tiene NIF configurado');
      return;
    }
    setState(() => _generandoEmitidas = true);

    try {
      final snap = await _db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('facturas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(_fechaInicio))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(_fechaFin))
          .orderBy('fecha')
          .get();

      final facturas = snap.docs
          .map((d) => Factura.fromFirestore(d))
          .toList();

      if (facturas.isEmpty) {
        _snack('No hay facturas emitidas en $_periodoLabel');
        return;
      }

      final contenido = LibroRegistroIvaExporter.generarLibroEmitidas(
        _nifEmpresa, _mes, _anio, facturas,
      );

      await _compartir(
        contenido,
        'libro_emitidas_${_anio}_${_mes.toString().padLeft(2, '0')}.txt',
        'Libro Registro Facturas Emitidas — $_periodoLabel (${facturas.length} registros)',
      );
    } catch (e) {
      _snack('Error al generar el libro: $e');
    } finally {
      if (mounted) setState(() => _generandoEmitidas = false);
    }
  }

  // ── Exportar recibidas ─────────────────────────────────────────────────────

  Future<void> _exportarRecibidas() async {
    if (_nifEmpresa.isEmpty) {
      _snack('La empresa no tiene NIF configurado');
      return;
    }
    setState(() => _generandoRecibidas = true);

    try {
      final snap = await _db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('facturas_recibidas')
          .where('fecha_recepcion',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_fechaInicio))
          .where('fecha_recepcion',
              isLessThanOrEqualTo: Timestamp.fromDate(_fechaFin))
          .orderBy('fecha_recepcion')
          .get();

      final facturas = snap.docs
          .map((d) => FacturaRecibida.fromFirestore(d))
          .toList();

      if (facturas.isEmpty) {
        _snack('No hay facturas recibidas en $_periodoLabel');
        return;
      }

      final contenido = LibroRegistroIvaExporter.generarLibroRecibidas(
        _nifEmpresa, _mes, _anio, facturas,
      );

      await _compartir(
        contenido,
        'libro_recibidas_${_anio}_${_mes.toString().padLeft(2, '0')}.txt',
        'Libro Registro Facturas Recibidas — $_periodoLabel (${facturas.length} registros)',
      );
    } catch (e) {
      _snack('Error al generar el libro: $e');
    } finally {
      if (mounted) setState(() => _generandoRecibidas = false);
    }
  }

  // ── Compartir fichero ──────────────────────────────────────────────────────

  Future<void> _compartir(
    String contenido,
    String nombreFichero,
    String asunto,
  ) async {
    final dir    = await getTemporaryDirectory();
    final file   = File('${dir.path}/$nombreFichero');
    await file.writeAsString(contenido, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/plain')],
      subject: asunto,
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libros Registro IVA'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file), text: 'Emitidas'),
            Tab(icon: Icon(Icons.download_for_offline), text: 'Recibidas'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Selector de periodo ─────────────────────────────────────────────
          _SelectorPeriodo(
            anio: _anio,
            mes: _mes,
            onChanged: (a, m) => setState(() {
              _anio = a;
              _mes  = m;
            }),
          ),
          // ── Contenido por tab ───────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── TAB 1: Emitidas ──────────────────────────────────────────
                _TabLibro(
                  empresaId:   widget.empresaId,
                  coleccion:   'facturas',
                  campofecha:  'fecha',
                  fechaInicio: _fechaInicio,
                  fechaFin:    _fechaFin,
                  tipo:        _TipoLibro.emitidas,
                  fmt:         _fmt,
                  generando:   _generandoEmitidas,
                  onExportar:  _exportarEmitidas,
                ),
                // ── TAB 2: Recibidas ─────────────────────────────────────────
                _TabLibro(
                  empresaId:   widget.empresaId,
                  coleccion:   'facturas_recibidas',
                  campofecha:  'fecha_recepcion',
                  fechaInicio: _fechaInicio,
                  fechaFin:    _fechaFin,
                  tipo:        _TipoLibro.recibidas,
                  fmt:         _fmt,
                  generando:   _generandoRecibidas,
                  onExportar:  _exportarRecibidas,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SELECTOR DE PERIODO
// ═════════════════════════════════════════════════════════════════════════════

class _SelectorPeriodo extends StatelessWidget {
  final int anio;
  final int mes;
  final void Function(int anio, int mes) onChanged;

  const _SelectorPeriodo({
    required this.anio,
    required this.mes,
    required this.onChanged,
  });

  static const _meses = [
    'Enero','Febrero','Marzo','Abril','Mayo','Junio',
    'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE3F2FD),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18, color: Color(0xFF1565C0)),
          const SizedBox(width: 8),
          const Text('Periodo:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),

          // Mes
          DropdownButton<int>(
            value: mes,
            underline: const SizedBox(),
            items: List.generate(12, (i) => DropdownMenuItem(
              value: i + 1,
              child: Text(_meses[i]),
            )),
            onChanged: (m) => onChanged(anio, m!),
          ),

          const SizedBox(width: 8),

          // Año
          DropdownButton<int>(
            value: anio,
            underline: const SizedBox(),
            items: List.generate(6, (i) {
              final y = DateTime.now().year - i;
              return DropdownMenuItem(value: y, child: Text(y.toString()));
            }),
            onChanged: (a) => onChanged(a!, mes),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB GENÉRICO: EMITIDAS / RECIBIDAS
// ═════════════════════════════════════════════════════════════════════════════

enum _TipoLibro { emitidas, recibidas }

class _TabLibro extends StatelessWidget {
  final String empresaId;
  final String coleccion;
  final String campofecha;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final _TipoLibro tipo;
  final NumberFormat fmt;
  final bool generando;
  final VoidCallback onExportar;

  const _TabLibro({
    required this.empresaId,
    required this.coleccion,
    required this.campofecha,
    required this.fechaInicio,
    required this.fechaFin,
    required this.tipo,
    required this.fmt,
    required this.generando,
    required this.onExportar,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('empresas').doc(empresaId).collection(coleccion)
          .where(campofecha,
              isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio))
          .where(campofecha,
              isLessThanOrEqualTo: Timestamp.fromDate(fechaFin))
          .orderBy(campofecha)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return _buildVacio(context);
        }

        // Calcular totales
        double sumBase  = 0;
        double sumCuota = 0;
        double sumTotal = 0;

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          sumBase  += (d['base_imponible']  as num?)?.toDouble() ?? 0;
          sumCuota += (d['total_iva']       as num?)?.toDouble() ?? (d['cuota_iva'] as num?)?.toDouble() ?? 0;
          sumTotal += (d['total']           as num?)?.toDouble() ?? 0;
        }

        return Column(
          children: [
            // ── Resumen totales ─────────────────────────────────────────────
            _buildResumen(docs.length, sumBase, sumCuota, sumTotal),
            // ── Lista de registros ─────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) => _buildFila(docs[i]),
              ),
            ),
            // ── Botón exportar ─────────────────────────────────────────────
            _buildBotonExportar(context, docs.length),
          ],
        );
      },
    );
  }

  Widget _buildVacio(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tipo == _TipoLibro.emitidas
                ? Icons.upload_file_outlined
                : Icons.download_for_offline_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            tipo == _TipoLibro.emitidas
                ? 'Sin facturas emitidas en este periodo'
                : 'Sin facturas recibidas en este periodo',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen(int n, double base, double cuota, double total) {
    return Container(
      color: tipo == _TipoLibro.emitidas
          ? const Color(0xFFE8F5E9)
          : const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _resumenChip('Registros', n.toString()),
          const SizedBox(width: 12),
          _resumenChip('Base', fmt.format(base)),
          const SizedBox(width: 12),
          _resumenChip('IVA', fmt.format(cuota)),
          const SizedBox(width: 12),
          _resumenChip('Total', fmt.format(total), bold: true),
        ],
      ),
    );
  }

  Widget _resumenChip(String label, String value, {bool bold = false}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _buildFila(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final DateTime? fecha = _parseFecha(
      d[campofecha] ?? d['fecha'],
    );
    final String fechaStr = fecha != null
        ? DateFormat('dd/MM/yyyy').format(fecha)
        : '—';

    final String numFac   = (d['numero_factura'] as String?) ?? doc.id.substring(0, 8);
    final String nif      = tipo == _TipoLibro.emitidas
        ? ((d['datos_fiscales'] as Map?)?.['nif'] as String?) ?? '—'
        : (d['nif_proveedor'] as String?) ?? '—';
    final String razon    = tipo == _TipoLibro.emitidas
        ? ((d['datos_fiscales'] as Map?)?.['razon_social'] as String?) ??
          (d['nombre_cliente'] as String?) ?? '—'
        : (d['nombre_proveedor'] as String?) ?? '—';
    final double base     = (d['base_imponible']  as num?)?.toDouble() ?? 0;
    final double cuota    = (d['total_iva']       as num?)?.toDouble() ??
                            (d['cuota_iva']       as num?)?.toDouble() ?? 0;
    final double total    = (d['total']           as num?)?.toDouble() ?? 0;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: tipo == _TipoLibro.emitidas
            ? const Color(0xFF1565C0)
            : const Color(0xFFE65100),
        child: Icon(
          tipo == _TipoLibro.emitidas ? Icons.arrow_upward : Icons.arrow_downward,
          color: Colors.white,
          size: 14,
        ),
      ),
      title: Row(
        children: [
          Text(numFac,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Text(fechaStr,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$nif — $razon',
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Row(
            children: [
              _miniChip('Base ${fmt.format(base)}', Colors.blue.shade50),
              const SizedBox(width: 4),
              _miniChip('IVA ${fmt.format(cuota)}', Colors.orange.shade50),
            ],
          ),
        ],
      ),
      trailing: Text(
        fmt.format(total),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: tipo == _TipoLibro.emitidas
              ? const Color(0xFF1B5E20)
              : const Color(0xFFB71C1C),
        ),
      ),
    );
  }

  Widget _miniChip(String text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text, style: const TextStyle(fontSize: 10)),
  );

  Widget _buildBotonExportar(BuildContext context, int n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: generando ? null : onExportar,
          style: ElevatedButton.styleFrom(
            backgroundColor: tipo == _TipoLibro.emitidas
                ? const Color(0xFF1565C0)
                : const Color(0xFFE65100),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: generando
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,
                  ),
                )
              : const Icon(Icons.download),
          label: Text(
            generando
                ? 'Generando fichero…'
                : 'Exportar fichero AEAT ($n registros)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  DateTime? _parseFecha(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}

