import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/finiquito.dart';
import 'package:planeag_flutter/services/finiquito_service.dart';
import 'package:planeag_flutter/services/finiquito_pdf_service.dart';
import 'package:planeag_flutter/services/baja_empleado_service.dart';
import 'package:planeag_flutter/services/carta_cese_service.dart';
import 'package:planeag_flutter/services/certificado_empresa_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'revision_finiquito_empleado_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// DETALLE DE FINIQUITO — con firma, carta, certificado SEPE, baja y email
// ═════════════════════════════════════════════════════════════════════════════

class FiniquitoDetalle extends StatefulWidget {
  final Finiquito finiquito;
  final String empresaId;

  const FiniquitoDetalle({
    super.key,
    required this.finiquito,
    required this.empresaId,
  });

  @override
  State<FiniquitoDetalle> createState() => _FiniquitoDetalleState();
}

class _FiniquitoDetalleState extends State<FiniquitoDetalle> {
  final _svc = FiniquitoService();
  final _bajaSvc = BajaEmpleadoService();
  final _cartaSvc = CartaCeseService();
  final _certSvc = CertificadoEmpresaService();
  final _db = FirebaseFirestore.instance;

  late Finiquito _f;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _f = widget.finiquito;
  }

  Future<void> _recargar() async {
    final actualizado = await _svc.obtenerFiniquito(widget.empresaId, _f.id);
    if (actualizado != null && mounted) setState(() => _f = actualizado);
  }

  // ── FIRMA TÁCTIL ──────────────────────────────────────────────────────────

  Future<void> _obtenerFirma() async {
    if (_f.firmado) {
      _snack('Este finiquito ya está firmado y es inmutable.', Colors.orange);
      return;
    }
    final firmado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RevisionFiniquitoEmpleadoScreen(
          finiquito: _f,
          empresaId: widget.empresaId,
        ),
      ),
    );
    if (firmado == true) await _recargar();
  }

  // ── PAGAR ─────────────────────────────────────────────────────────────────

  Future<void> _pagar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar pago'),
        content: Text(
          '¿Marcar como pagado el finiquito de ${_f.empleadoNombre}?\n\n'
          'Se generará un gasto contable por ${_f.totalBruto.toStringAsFixed(2)} €.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmar pago'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _procesando = true);
    try {
      await _svc.pagarFiniquito(widget.empresaId, _f.id);
      await _recargar();
      _snack('✅ Finiquito pagado y contabilizado', Colors.green);
      // Mostrar bottom sheet de envío de documentación
      if (mounted) await _mostrarEnvioDocumentacion();
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ── CARTA DE CESE ─────────────────────────────────────────────────────────

  Future<void> _generarCarta() async {
    final datosEmpresa = await _obtenerDatosEmpresa();
    if (!mounted) return;

    // Editor de texto previo
    final textoTemplate = CartaCeseService.templateTexto(
      causaBaja: _f.causaBaja,
      nombreEmpleado: _f.empleadoNombre,
      nombreEmpresa: datosEmpresa['nombre'] as String? ?? '',
      fechaCese: _f.fechaBaja,
    );

    final textoEditado = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditorCartaDialog(textoInicial: textoTemplate),
    );
    if (textoEditado == null) return;

    setState(() => _procesando = true);
    try {
      await _cartaSvc.generar(
        finiquito: _f,
        textoCarta: textoEditado,
        datosEmpresa: datosEmpresa,
      );
      await _recargar();
      _snack('✅ Carta de cese generada', Colors.green);
      await _cartaSvc.generarYCompartir(
        finiquito: _f,
        textoCarta: textoEditado,
        datosEmpresa: datosEmpresa,
      );
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ── CERTIFICADO SEPE ──────────────────────────────────────────────────────

  Future<void> _generarCertificadoSEPE() async {
    setState(() => _procesando = true);
    try {
      await _certSvc.generar(widget.empresaId, _f.id);
      await _recargar();
      _snack('✅ Certificado SEPE generado', Colors.green);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ── BAJA EMPLEADO ─────────────────────────────────────────────────────────

  Future<void> _procesarBaja() async {
    if (_f.bajaAplicada) {
      _snack('La baja ya está aplicada en el sistema.', Colors.orange);
      return;
    }
    if (!_f.firmado && _f.estado != EstadoFiniquito.pagado) {
      _snack('El finiquito debe estar firmado o pagado para procesar la baja.',
          Colors.orange);
      return;
    }

    // Doble confirmación
    final paso1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('Procesar baja'),
        ]),
        content: Text(
          'Esta acción dará de baja a ${_f.empleadoNombre} en todos los módulos:\n\n'
          '• Empleado marcado como "Baja"\n'
          '• Acceso a la app bloqueado\n'
          '• Solicitudes de vacaciones canceladas\n'
          '• Tareas reasignadas al propietario\n\n'
          '¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (paso1 != true) return;

    final paso2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmación final'),
        content: const Text('¿Está SEGURO de que desea procesar la baja?\n'
            'Esta acción solo puede revertirse manualmente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, procesar baja'),
          ),
        ],
      ),
    );
    if (paso2 != true) return;

    setState(() => _procesando = true);
    try {
      final resultado = await _bajaSvc.procesarBaja(
        empresaId: widget.empresaId,
        empleadoId: _f.empleadoId,
        finiquitoId: _f.id,
        causaBaja: _f.causaBaja,
        fechaBaja: _f.fechaBaja,
      );

      if (resultado.exito) {
        await _recargar();
        _snack(
          '✅ Baja procesada. '
          '${resultado.tareasReasignadas} tareas reasignadas, '
          '${resultado.solicitudesCerradas} solicitudes canceladas.',
          Colors.green,
        );
      } else {
        _snack('Error: ${resultado.error}', Colors.red);
      }
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ── ENVIAR DOCUMENTACIÓN POR EMAIL ────────────────────────────────────────

  Future<void> _mostrarEnvioDocumentacion() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _EnvioDocumentacionSheet(
        finiquito: _f,
        empresaId: widget.empresaId,
      ),
    );
  }

  // ── ELIMINAR ──────────────────────────────────────────────────────────────

  Future<void> _eliminar() async {
    if (_f.estado != EstadoFiniquito.borrador) {
      _snack('Solo se pueden eliminar borradores', Colors.orange);
      return;
    }
    if (_f.firmado) {
      _snack('No se puede eliminar un finiquito firmado', Colors.red);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar finiquito?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.eliminarFiniquito(widget.empresaId, _f.id);
    if (mounted) Navigator.pop(context);
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _obtenerDatosEmpresa() async {
    final doc = await _db.collection('empresas').doc(widget.empresaId).get();
    return doc.data() ?? {};
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Detalle del finiquito'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          if (_f.estado == EstadoFiniquito.borrador && !_f.firmado)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _eliminar,
              tooltip: 'Eliminar',
            ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.deepOrange),
            onPressed: () => FiniquitoPdfService.generarYCompartir(context, _f),
            tooltip: 'PDF finiquito',
          ),
          IconButton(
            icon: const Icon(Icons.email_outlined, color: Colors.indigo),
            onPressed: _mostrarEnvioDocumentacion,
            tooltip: 'Enviar por email',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCabeceraEstado(),
            const SizedBox(height: 16),
            _buildInfoEmpleado(),
            const SizedBox(height: 12),
            _buildConceptos(),
            const SizedBox(height: 12),
            if (_f.indemnizacion > 0) ...[
              _buildIndemnizacion(),
              const SizedBox(height: 12),
            ],
            _buildRetenciones(),
            const SizedBox(height: 12),
            _buildTotales(),
            const SizedBox(height: 16),
            _buildDocumentosGenerados(),
            const SizedBox(height: 20),
            _buildAcciones(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Secciones ─────────────────────────────────────────────────────────────

  Widget _buildCabeceraEstado() {
    final color = _colorEstado(_f.estado);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_iconoEstado(_f.estado), color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(_f.estado.etiqueta,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
                  if (_f.firmado) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('✍️ Firmado', style: TextStyle(
                          fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                Text(_f.causaBaja.etiqueta,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                if (_f.bajaAplicada)
                  Text('• Baja aplicada en el sistema',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_f.liquidoPercibir.toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('líquido', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoEmpleado() {
    return _card('Datos del trabajador', [
      _fila('Empleado', _f.empleadoNombre),
      _fila('NIF', _f.empleadoNif ?? '—'),
      if (_f.naf != null) _fila('NAF', _f.naf!),
      _fila('Inicio contrato', _fmtDate(_f.fechaInicioContrato)),
      _fila('Fecha baja', _fmtDate(_f.fechaBaja)),
      _fila('Antigüedad', _f.antiguedadTexto),
      _fila('Salario bruto anual', '${_f.salarioBrutoAnual.toStringAsFixed(2)} €'),
      if (_f.numPagas != 12)
        _fila('Pagas', '${_f.numPagas} pagas${_f.pagasProrrateadas ? " (prorrateadas)" : ""}'),
    ]);
  }

  Widget _buildConceptos() {
    return _card('Conceptos salariales', [
      _filaImporte('Salario pendiente (${_f.diasTrabajadosMes}/${_f.diasMesBaja} días)',
          _f.salarioPendiente),
      _filaImporte('Vacaciones pendientes (${_f.diasVacacionesPendientes} días)',
          _f.importeVacaciones),
      ..._f.prorrataPagasExtra.map((p) =>
          _filaImporte('${p.nombre} (${p.diasDevengados} días)', p.importe)),
    ]);
  }

  Widget _buildIndemnizacion() {
    return _card('Indemnización', [
      _filaImporte('${_f.causaBaja.diasPorAnio.toInt()} días/año × '
          '${_f.aniosAntiguedad.toStringAsFixed(2)} años', _f.indemnizacion),
      if (_f.indemnizacionTramoAnterior != null) ...[
        _filaImporte('  Tramo pre-12/02/2012 (45 d/año)',
            _f.indemnizacionTramoAnterior!, color: Colors.orange.shade700),
        _filaImporte('  Tramo post-12/02/2012 (33 d/año)',
            _f.indemnizacionTramoPosterior!, color: Colors.orange.shade700),
      ],
      const Divider(height: 8),
      if (_f.indemnizacionExenta > 0)
        _filaImporte('Exenta IRPF (art. 7.e LIRPF)',
            _f.indemnizacionExenta, color: Colors.green.shade700),
      if (_f.indemnizacionSujeta > 0)
        _filaImporte('Sujeta a IRPF', _f.indemnizacionSujeta, color: Colors.red.shade700),
    ]);
  }

  Widget _buildRetenciones() {
    return _card('Retenciones', [
      _filaImporte('IRPF (${_f.porcentajeIrpf.toStringAsFixed(2)}%)',
          _f.importeIrpf, color: Colors.red),
      _fila('Base IRPF', '${_f.baseIrpf.toStringAsFixed(2)} €'),
      const Divider(height: 8),
      _filaImporte('Cuota obrera SS', _f.cuotaObreraSSFiniquito, color: Colors.red),
      _fila('Base SS', '${_f.baseSS.toStringAsFixed(2)} €'),
    ]);
  }

  Widget _buildTotales() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(children: [
        _filaImporte('Total bruto', _f.totalBruto, bold: true),
        _filaImporte('Total retenciones', -_f.totalRetenciones, color: Colors.red),
        const Divider(thickness: 2),
        _filaImporte('LÍQUIDO A PERCIBIR', _f.liquidoPercibir,
            bold: true, fontSize: 18, color: Colors.green.shade700),
      ]),
    );
  }

  Widget _buildDocumentosGenerados() {
    final docs = [
      _DocItem('PDF Finiquito', Icons.description, _f.pdfFirmadoUrl != null || true,
          _f.pdfFirmadoUrl != null),
      _DocItem('Carta de cese', Icons.mail_outline, _f.cartaCeseUrl != null,
          _f.cartaCeseUrl != null),
      _DocItem('Certificado SEPE', Icons.account_balance, _f.certificadoSEPEUrl != null,
          _f.certificadoSEPEUrl != null),
      _DocItem('Email enviado', Icons.send, _f.emailEnviado != null, _f.emailEnviado != null,
          subtitulo: _f.emailEnviado),
    ];

    return _card('Documentación', [
      ...docs.map((d) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(d.icono, size: 18,
              color: d.generado ? Colors.green : Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.titulo, style: TextStyle(
                  fontSize: 13,
                  color: d.generado ? Colors.black87 : Colors.grey.shade500)),
              if (d.subtitulo != null)
                Text(d.subtitulo!, style: TextStyle(fontSize: 11,
                    color: Colors.grey.shade500)),
            ],
          )),
          if (d.generado)
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade600)
          else
            Icon(Icons.radio_button_unchecked, size: 16, color: Colors.grey.shade300),
        ]),
      )),
    ]);
  }

  Widget _buildAcciones() {
    if (_procesando) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Firma táctil ────────────────────────────────────────────────────
        if (!_f.firmado)
          _boton('✍️  Obtener firma del empleado', Colors.indigo, _obtenerFirma,
              icon: Icons.draw),
        if (_f.firmado)
          _botonOutline('✍️  Firmado — ver revisión', Colors.green,
              _obtenerFirma),

        // ── Pagar ───────────────────────────────────────────────────────────
        if (_f.estado == EstadoFiniquito.firmado) ...[
          const SizedBox(height: 8),
          _boton('💳  Marcar como pagado', Colors.green, _pagar,
              icon: Icons.payment),
        ],

        // ── Carta de cese ───────────────────────────────────────────────────
        const SizedBox(height: 8),
        _botonOutline(
          _f.cartaCeseUrl != null
              ? '📝  Carta de cese (regenerar)'
              : '📝  Generar carta de cese',
          Colors.teal,
          _generarCarta,
        ),

        // ── Certificado SEPE ────────────────────────────────────────────────
        const SizedBox(height: 8),
        _botonOutline(
          _f.certificadoSEPEUrl != null
              ? '🏛️  Certificado SEPE (regenerar)'
              : '🏛️  Generar certificado SEPE',
          Colors.blue.shade700,
          _generarCertificadoSEPE,
        ),

        // ── PDF finiquito ───────────────────────────────────────────────────
        const SizedBox(height: 8),
        _botonOutline('📄  Generar y compartir PDF', Colors.deepOrange,
            () => FiniquitoPdfService.generarYCompartir(context, _f)),

        // ── Enviar por email ────────────────────────────────────────────────
        const SizedBox(height: 8),
        _botonOutline('📧  Enviar documentación por email', Colors.indigo,
            _mostrarEnvioDocumentacion),

        // ── Baja del empleado ───────────────────────────────────────────────
        if (!_f.bajaAplicada && _f.estado != EstadoFiniquito.borrador) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _boton(
            '🔴  Procesar baja del empleado',
            Colors.red.shade700,
            _procesarBaja,
            icon: Icons.person_off,
          ),
        ],
        if (_f.bajaAplicada) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              Icon(Icons.person_off, color: Colors.red.shade700, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Baja aplicada — el empleado está dado de baja '
                    'en todos los módulos.',
                    style: TextStyle(fontSize: 12)),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _boton(String label, Color color, VoidCallback onPressed,
      {IconData? icon}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.check, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _botonOutline(String label, Color color, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  Widget _card(String titulo, List<Widget> hijos) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...hijos,
          ],
        ),
      ),
    );
  }

  Widget _fila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _filaImporte(String label, double valor, {
    bool bold = false, double fontSize = 13, Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color ?? Colors.grey.shade800,
          ))),
          Text('${valor.toStringAsFixed(2)} €', style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          )),
        ],
      ),
    );
  }

  Color _colorEstado(EstadoFiniquito e) {
    switch (e) {
      case EstadoFiniquito.borrador: return Colors.orange;
      case EstadoFiniquito.firmado: return Colors.blue;
      case EstadoFiniquito.pagado: return Colors.green;
    }
  }

  IconData _iconoEstado(EstadoFiniquito e) {
    switch (e) {
      case EstadoFiniquito.borrador: return Icons.edit_document;
      case EstadoFiniquito.firmado: return Icons.draw;
      case EstadoFiniquito.pagado: return Icons.check_circle;
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET: ENVÍO DE DOCUMENTACIÓN POR EMAIL
// ═══════════════════════════════════════════════════════════════════════════════

class _EnvioDocumentacionSheet extends StatefulWidget {
  final Finiquito finiquito;
  final String empresaId;

  const _EnvioDocumentacionSheet({
    required this.finiquito,
    required this.empresaId,
  });

  @override
  State<_EnvioDocumentacionSheet> createState() =>
      _EnvioDocumentacionSheetState();
}

class _EnvioDocumentacionSheetState extends State<_EnvioDocumentacionSheet> {
  late TextEditingController _emailCtrl;
  bool _incluyeFiniquito = true;
  bool _incluyCarta = true;
  bool _incluyeCertificado = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    // Cargar email del empleado
    FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.finiquito.empleadoId)
        .get()
        .then((doc) {
      final email = doc.data()?['email'] as String? ?? '';
      if (mounted) setState(() => _emailCtrl.text = email);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un email válido')),
      );
      return;
    }

    final docs = <String>[];
    if (_incluyeFiniquito) docs.add('finiquito');
    if (_incluyCarta) docs.add('carta_cese');
    if (_incluyeCertificado) docs.add('certificado_sepe');

    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un documento')),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('enviarDocumentacionFiniquito');
      final result = await callable.call({
        'finiquitoId': widget.finiquito.id,
        'empresaId': widget.empresaId,
        'emailDestino': email,
        'documentos': docs,
      });

      final data = result.data as Map;
      final archivos = data['archivosEnviados'] as int? ?? 0;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Documentación enviada ($archivos archivos) a $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.finiquito;
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 16),
          const Text('Enviar documentación al empleado',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('${f.empleadoNombre} · ${f.causaBaja.etiqueta}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 16),

          // Email
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email del empleado',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          // Documentos
          const Text('Documentos a incluir:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          CheckboxListTile(
            value: _incluyeFiniquito,
            onChanged: (v) => setState(() => _incluyeFiniquito = v ?? false),
            title: Row(children: [
              const Icon(Icons.description, size: 18),
              const SizedBox(width: 8),
              const Text('Finiquito y liquidación', style: TextStyle(fontSize: 13)),
              if (f.pdfFirmadoUrl != null)
                Container(margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('firmado', style: TextStyle(
                      fontSize: 10, color: Colors.green.shade700))),
            ]),
            dense: true, contentPadding: EdgeInsets.zero,
            activeColor: Colors.indigo,
          ),
          CheckboxListTile(
            value: _incluyCarta,
            onChanged: f.cartaCeseUrl != null
                ? (v) => setState(() => _incluyCarta = v ?? false)
                : null,
            title: Row(children: [
              Icon(Icons.mail_outline, size: 18,
                  color: f.cartaCeseUrl != null ? null : Colors.grey),
              const SizedBox(width: 8),
              Text('Carta de cese',
                  style: TextStyle(fontSize: 13,
                      color: f.cartaCeseUrl != null ? null : Colors.grey)),
              if (f.cartaCeseUrl == null)
                Text(' (no generada)',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ]),
            dense: true, contentPadding: EdgeInsets.zero,
            activeColor: Colors.indigo,
          ),
          CheckboxListTile(
            value: _incluyeCertificado,
            onChanged: f.certificadoSEPEUrl != null
                ? (v) => setState(() => _incluyeCertificado = v ?? false)
                : null,
            title: Row(children: [
              Icon(Icons.account_balance, size: 18,
                  color: f.certificadoSEPEUrl != null ? null : Colors.grey),
              const SizedBox(width: 8),
              Text('Certificado empresa (SEPE)',
                  style: TextStyle(fontSize: 13,
                      color: f.certificadoSEPEUrl != null ? null : Colors.grey)),
              if (f.certificadoSEPEUrl == null)
                Text(' (no generado)',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ]),
            dense: true, contentPadding: EdgeInsets.zero,
            activeColor: Colors.indigo,
          ),
          const SizedBox(height: 16),

          // Botones
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Omitir'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _enviar,
                icon: _enviando
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: Colors.white))
                    : const Icon(Icons.send, size: 18),
                label: Text(_enviando ? 'Enviando...' : 'Enviar documentación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR DE CARTA DE CESE
// ─────────────────────────────────────────────────────────────────────────────

class _EditorCartaDialog extends StatefulWidget {
  final String textoInicial;
  const _EditorCartaDialog({required this.textoInicial});

  @override
  State<_EditorCartaDialog> createState() => _EditorCartaDialogState();
}

class _EditorCartaDialogState extends State<_EditorCartaDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.textoInicial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar carta de cese'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _ctrl,
          maxLines: 15,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Texto de la carta...',
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal,
              foregroundColor: Colors.white),
          child: const Text('Generar PDF'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DocItem {
  final String titulo;
  final IconData icono;
  final bool disponible;
  final bool generado;
  final String? subtitulo;
  const _DocItem(this.titulo, this.icono, this.disponible, this.generado,
      {this.subtitulo});
}
