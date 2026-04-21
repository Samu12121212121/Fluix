import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/empresa_config_provider.dart';
import '../../../domain/modelos/factura.dart';
import '../../../domain/modelos/factura_recibida.dart';
import '../../facturacion/pantallas/tab_mod_349.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA MODELO 349 — Operaciones intracomunitarias
// ═════════════════════════════════════════════════════════════════════════════

class Modelo349Screen extends StatefulWidget {
  final String empresaId;
  final int? anioInicial;

  const Modelo349Screen({
    super.key,
    required this.empresaId,
    this.anioInicial,
  });

  @override
  State<Modelo349Screen> createState() => _Modelo349ScreenState();
}

class _Modelo349ScreenState extends State<Modelo349Screen> {
  final _db = FirebaseFirestore.instance;
  late int _anio;
  bool _cargando = true;
  List<Factura> _facturas = [];
  List<FacturaRecibida> _facturasRecibidas = [];

  @override
  void initState() {
    super.initState();
    _anio = widget.anioInicial ?? DateTime.now().year;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final snap = await _db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('facturas')
          .get();
      final snapRec = await _db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('facturas_recibidas')
          .get();

      final facturas = snap.docs
          .map((d) => Factura.fromFirestore(d))
          .where((f) => f.fechaEmision.year == _anio)
          .toList();
      final recibidas = snapRec.docs
          .map((d) => FacturaRecibida.fromFirestore(d))
          .where((f) => f.fechaRecepcion.year == _anio)
          .toList();

      if (mounted) {
        setState(() {
          _facturas = facturas;
          _facturasRecibidas = recibidas;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empresaConfig = context.watch<EmpresaConfigProvider>().config;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modelo 349 — Intracomunitarias'),
        actions: [
          // Selector de año
          DropdownButton<int>(
            value: _anio,
            dropdownColor: Colors.white,
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
            items: List.generate(5, (i) => DateTime.now().year - i)
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _anio = v);
              _cargar();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Mod349Tab(
              empresa: empresaConfig,
              ejercicio: _anio,
              facturas: _facturas,
              facturasRecibidas: _facturasRecibidas,
            ),
    );
  }
}



