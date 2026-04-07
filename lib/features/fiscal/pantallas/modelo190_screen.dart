import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/domain/modelos/modelo190.dart';
import 'package:planeag_flutter/domain/modelos/empresa_config.dart';
import 'package:planeag_flutter/services/modelo190_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA MODELO 190 — Resumen anual retenciones IRPF
// ═════════════════════════════════════════════════════════════════════════════

class Modelo190Screen extends StatefulWidget {
  final String empresaId;
  final int? anioInicial;

  const Modelo190Screen({
    super.key,
    required this.empresaId,
    this.anioInicial,
  });

  @override
  State<Modelo190Screen> createState() => _Modelo190ScreenState();
}

class _Modelo190ScreenState extends State<Modelo190Screen> {
  final _svc = Modelo190Service();
  late int _anio;
  bool _procesando = false;
  EmpresaConfig? _empresaConfig;

  @override
  void initState() {
    super.initState();
    // Por defecto el ejercicio anterior (el 190 se presenta en enero del año siguiente)
    _anio = widget.anioInicial ?? DateTime.now().year - 1;
    _cargarEmpresa();
  }

  Future<void> _cargarEmpresa() async {
    final db = FirebaseFirestore.instance;
    final empDoc = await db.collection('empresas').doc(widget.empresaId).get();
    final fiscalDoc = await db.collection('empresas').doc(widget.empresaId)
        .collection('configuracion').doc('fiscal').get();
    if (mounted) {
      setState(() {
        _empresaConfig = EmpresaConfig.fromSources(
          empresaDoc: empDoc.data(),
          fiscalDoc: fiscalDoc.data(),
        );
      });
    }
  }

  Future<void> _calcularEjercicio() async {
    setState(() => _procesando = true);
    try {
      final modelo = await _svc.calcularDesdeNominas(
        empresaId: widget.empresaId,
        ejercicio: _anio,
      );
      await _svc.guardar(widget.empresaId, modelo);

      // Verificar coherencia con 111
      final alerta = await _svc.verificarCoherencia111(widget.empresaId, modelo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Modelo 190 $_anio calculado — '
              '${modelo.perceptores.length} perceptores — '
              '${modelo.totalRetenciones.toStringAsFixed(2)} € retenciones'),
          backgroundColor: Colors.green,
        ));
        if (alerta != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('⚠️ $alerta'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _generarTxt(Modelo190 m) async {
    if (_empresaConfig == null) return;

    final errores = _svc.validar(m, _empresaConfig!);
    if (errores.isNotEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Validaciones pendientes'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: errores.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('❌ $e', style: const TextStyle(fontSize: 13)),
                )).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _generarTxtForzado(m);
                },
                child: const Text('Generar igualmente'),
              ),
            ],
          ),
        );
      }
      return;
    }

    await _generarTxtForzado(m);
  }

  Future<void> _generarTxtForzado(Modelo190 m) async {
    try {
      final bytes = Modelo190Service.generarFicheroTxt(
        modelo: m,
        empresa: _empresaConfig!,
      );
      final dir = await getTemporaryDirectory();
      final nombre = '190_${m.ejercicio}.txt';
      final archivo = File('${dir.path}/$nombre');
      await archivo.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(archivo.path)],
        text: 'Modelo 190 — Ejercicio ${m.ejercicio} — Fichero AEAT',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error fichero AEAT: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _marcarPresentado(int ejercicio) async {
    await _svc.marcarPresentado(widget.empresaId, ejercicio);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Marcado como presentado'),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Modelo 190 — Resumen anual IRPF'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _anio--),
          ),
          Center(child: Text('$_anio',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _anio++),
          ),
        ],
      ),
      body: _procesando
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Modelo190?>(
              future: _svc.obtener(widget.empresaId, _anio),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final modelo = snap.data;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoBanner(),
                    const SizedBox(height: 16),
                    if (modelo != null) ...[
                      _buildResumen(modelo),
                      const SizedBox(height: 16),
                      _buildAcciones(modelo),
                      const SizedBox(height: 16),
                      _buildTablaPerceptores(modelo),
                    ] else ...[
                      _buildSinDatos(),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildInfoBanner() {
    final plazo = Modelo190.calcularPlazoLimite(_anio);
    final dias = plazo.difference(DateTime.now()).inDays;
    Color? colorPlazo;
    if (dias < 0) colorPlazo = Colors.red;
    else if (dias <= 15) colorPlazo = Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('Ejercicio', '$_anio', Icons.calendar_today),
          _stat('Plazo',
              '31/01/${_anio + 1}',
              Icons.timer,
              color: colorPlazo),
          _stat('Días', dias < 0 ? 'Vencido' : '$dias',
              Icons.schedule,
              color: colorPlazo),
        ],
      ),
    );
  }

  Widget _stat(String label, String valor, IconData icono, {Color? color}) {
    return Column(
      children: [
        Icon(icono, color: color ?? Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(valor, style: TextStyle(color: color ?? Colors.white,
            fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildSinDatos() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No hay Modelo 190 para $_anio',
                style: TextStyle(fontSize: 16, color: Colors.grey[600],
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Calcula automáticamente desde las nóminas pagadas del año',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _calcularEjercicio,
              icon: const Icon(Icons.calculate, size: 18),
              label: Text('Calcular 190 — $_anio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen(Modelo190 m) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: m.estado == EstadoModelo190.presentado
                        ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(m.estado.etiqueta,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const Spacer(),
                Text('Modelo 190 — ${m.ejercicio}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(height: 20),
            _fila('Nº perceptores (registros tipo 2)', '${m.perceptores.length}'),
            _fila('Total percepciones dinerarias',
                '${m.importeTotalPercepciones.toStringAsFixed(2)} €'),
            _fila('Total retenciones IRPF',
                '${m.totalRetenciones.toStringAsFixed(2)} €',
                bold: true, color: const Color(0xFF1B5E20)),
          ],
        ),
      ),
    );
  }

  Widget _fila(String label, String valor, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal))),
          Text(valor, style: TextStyle(fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color)),
        ],
      ),
    );
  }

  Widget _buildAcciones(Modelo190 m) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _boton('Recalcular', Icons.refresh, Colors.indigo, _calcularEjercicio),
          const SizedBox(width: 8),
          _boton('Fichero AEAT .txt', Icons.file_download, Colors.teal,
              () => _generarTxt(m)),
          if (m.estado == EstadoModelo190.borrador) ...[
            const SizedBox(width: 8),
            _boton('Presentado', Icons.check, Colors.green,
                () => _marcarPresentado(m.ejercicio)),
          ],
        ],
      ),
    );
  }

  Widget _boton(String label, IconData icono, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icono, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildTablaPerceptores(Modelo190 m) {
    if (m.perceptores.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('Sin perceptores', style: TextStyle(color: Colors.grey[500])),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Perceptores (Registros Tipo 2)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          const Divider(height: 1),
          ...m.perceptores.map(_buildFilaPerceptor),
        ],
      ),
    );
  }

  Widget _buildFilaPerceptor(Perceptor190 p) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Text(p.apellidosNombre,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(
        'NIF: ${p.nifPerceptor} · Prov: ${p.codigoProvincia} · '
        'Clave: ${p.clavePercepcion}',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
      trailing: Text('${p.retencionesPracticadas.toStringAsFixed(2)} €',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
              color: Color(0xFF1B5E20))),
      children: [
        _fila('Percepción íntegra dineraria',
            '${p.percepcionDinIntegra.toStringAsFixed(2)} €'),
        _fila('Retenciones IRPF',
            '${p.retencionesPracticadas.toStringAsFixed(2)} €'),
        if (p.valoracionEspecie > 0)
          _fila('Valoración especie',
              '${p.valoracionEspecie.toStringAsFixed(2)} €'),
        _fila('Gastos deducibles (SS obrera)',
            '${p.gastosDeducibles.toStringAsFixed(2)} €'),
        _fila('Año nacimiento', '${p.anioNacimiento}'),
        _fila('Situación familiar', '${p.situacionFamiliar}'),
        _fila('Discapacidad', '${p.discapacidad}'),
        _fila('Contrato', '${p.contrato}'),
        if (p.movilidadGeografica)
          _fila('Movilidad geográfica', 'Sí'),
        if (p.descendientesMenores3 > 0)
          _fila('Descendientes <3 años', '${p.descendientesMenores3}'),
        if (p.descendientesResto > 0)
          _fila('Descendientes resto', '${p.descendientesResto}'),
        if (p.percepcionITDineraria > 0)
          _fila('Percepción IT', '${p.percepcionITDineraria.toStringAsFixed(2)} €'),
      ],
    );
  }
}

