import 'package:flutter/material.dart';
import '../../../domain/modelos/nomina.dart';
import '../../../services/nominas_service.dart';
import '../../../services/nomina_pdf_service.dart';

/// Pantalla de detalle de una nómina individual.
/// Muestra desglose completo y permite aprobar/pagar/exportar PDF.
class DetalleNominaScreen extends StatefulWidget {
  final Nomina nomina;
  final String empresaId;
  final bool esPropietario;

  const DetalleNominaScreen({
    super.key,
    required this.nomina,
    required this.empresaId,
    this.esPropietario = false,
  });

  @override
  State<DetalleNominaScreen> createState() => _DetalleNominaScreenState();
}

class _DetalleNominaScreenState extends State<DetalleNominaScreen> {
  final NominasService _svc = NominasService();
  late Nomina _nomina;
  bool _procesando = false;
  double _horasExtraTemp = 0;
  double _precioHoraTemp = 0;
  double _complementosTemp = 0;
  String _notasTemp = '';
  late TipoHoraExtra _tipoHoraExtraTemp;

  @override
  void initState() {
    super.initState();
    _nomina = widget.nomina;
    _horasExtraTemp = _nomina.horasExtra;
    _precioHoraTemp = _nomina.precioHoraExtra;
    _complementosTemp = 0;
    _notasTemp = _nomina.notas ?? '';
    _tipoHoraExtraTemp = _nomina.tipoHoraExtra;
  }

  Color get _colorEstado {
    switch (_nomina.estado) {
      case EstadoNomina.borrador: return Colors.orange;
      case EstadoNomina.aprobada: return const Color(0xFF1976D2);
      case EstadoNomina.pagada:   return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Nómina — ${_nomina.empleadoNombre}'),
        backgroundColor: _colorEstado,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed: () => NominaPdfService.verNominaPdf(context, _nomina, widget.empresaId),
          ),
          IconButton(
            icon: const Icon(Icons.email_outlined),
            tooltip: 'Enviar por correo',
            onPressed: () => NominaPdfService.enviarNominaPorCorreo(context, _nomina, widget.empresaId),
          ),
          if (widget.esPropietario) ...[
            if (_nomina.estado == EstadoNomina.borrador)
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Aprobar',
                onPressed: _procesando ? null : _aprobar,
              ),
            if (_nomina.estado == EstadoNomina.aprobada)
              IconButton(
                icon: const Icon(Icons.payments),
                tooltip: 'Marcar pagada',
                onPressed: _procesando ? null : _pagar,
              ),
            if (_nomina.estado == EstadoNomina.borrador)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar',
                onPressed: _procesando ? null : _eliminar,
              ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            _cabeceraCard(),
            const SizedBox(height: 12),
            _seccionDevengos(),
            if (widget.esPropietario && _nomina.estado == EstadoNomina.borrador)
              _seccionEditarNomina(),
            const SizedBox(height: 12),
            _seccionDeduccionesSS(),
            const SizedBox(height: 12),
            _seccionIRPF(),
            const SizedBox(height: 12),
            if (_nomina.lineasAusencias.isNotEmpty || _nomina.descuentoAusencias > 0)
              ...[
                _seccionAusencias(),
                const SizedBox(height: 12),
              ],
            _seccionNeto(),
            const SizedBox(height: 12),
            _seccionCosteEmpresa(),
            const SizedBox(height: 12),
            if (_nomina.notas != null && _nomina.notas!.isNotEmpty)
              _seccionNotas(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _cabeceraCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: _colorEstado.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(Icons.person, color: _colorEstado, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_nomina.empleadoNombre,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text(_nomina.periodo,
                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _colorEstado.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_nomina.estado.etiqueta,
                      style: TextStyle(color: _colorEstado, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _datoPequeno('NIF', _nomina.empleadoNif ?? '—'),
                _datoPequeno('Nº SS', _nomina.empleadoNss ?? '—'),
                _datoPequeno('Periodo', _nomina.periodo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionDevengos() {
    return _seccionCard(
      titulo: 'I. DEVENGOS',
      color: const Color(0xFF1976D2),
      icono: Icons.add_circle_outline,
      children: [
        _fila('Salario base', _nomina.salarioBrutoMensual),
        if (_nomina.pagaExtra > 0)
          _filaDestacada('Paga extra (junio/diciembre)', _nomina.pagaExtra,
              const Color(0xFF1976D2)),
        if (_nomina.importeHorasExtra > 0)
          _fila(
            'Horas extra (${_nomina.horasExtra.toStringAsFixed(0)}h'
            '${_nomina.precioHoraExtra > 0 ? ' × ${_nomina.precioHoraExtra.toStringAsFixed(2)}€/h' : ''})',
            _nomina.importeHorasExtra,
          ),
        if (_nomina.complementos > 0)
          _fila('Complementos salariales', _nomina.complementos),
        if (_nomina.plusAntiguedad > 0)
          _filaDestacada(
            _nomina.descripcionAntiguedad ?? 'Plus antigüedad',
            _nomina.plusAntiguedad,
            const Color(0xFF00796B),
          ),
        if (_nomina.pagaExtraProrrata > 0)
          _fila('Prorrata pagas extra', _nomina.pagaExtraProrrata),
        const Divider(height: 16),
        _filaTotal('TOTAL DEVENGOS', _nomina.totalDevengos, const Color(0xFF1976D2)),
      ],
    );
  }

  Widget _seccionDeduccionesSS() {
    return _seccionCard(
      titulo: 'II. SEGURIDAD SOCIAL (Trabajador)',
      color: const Color(0xFFF57C00),
      icono: Icons.security,
      children: [
        _filaPct('Contingencias comunes', 4.70, _nomina.ssTrabajadorCC),
        _filaPct('Desempleo', _nomina.ssTrabajadorDesempleo > _nomina.baseCotizacion * 0.016 ? 1.60 : 1.55, _nomina.ssTrabajadorDesempleo),
        _filaPct('Formación profesional', 0.10, _nomina.ssTrabajadorFP),
        _filaPct('MEI', 0.12, _nomina.ssMeiTrabajador),
        if (_nomina.ssSolidaridadTrabajador > 0)
          _filaPct('Solidaridad', 0, _nomina.ssSolidaridadTrabajador),
        if (_nomina.ssHorasExtraTrabajador > 0) ...[
          const Divider(height: 12),
          _filaPct(
            'H.E. ${_nomina.tipoHoraExtra.etiqueta} (cot. adicional)',
            _nomina.tipoHoraExtra.tipoTrabajador,
            _nomina.ssHorasExtraTrabajador,
          ),
        ],
        const Divider(height: 16),
        _filaTotal('Total SS Trabajador', _nomina.totalSSTrabajador, const Color(0xFFF57C00)),
        const SizedBox(height: 4),
        Text('Base cotización: €${_nomina.baseCotizacion.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _seccionIRPF() {
    return _seccionCard(
      titulo: 'III. IRPF',
      color: const Color(0xFF7B1FA2),
      icono: Icons.account_balance,
      children: [
        if (_nomina.irpfAjustado) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7B1FA2).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF7B1FA2).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.sync, size: 14, color: Color(0xFF7B1FA2)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'IRPF recalculado por regularización anual (YTD). '
                    'El tipo refleja los ingresos acumulados en el año.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF7B1FA2)),
                  ),
                ),
              ],
            ),
          ),
        ],
        _fila('Base IRPF', _nomina.baseIrpf),
        _filaPct('Tipo efectivo', _nomina.porcentajeIrpf, _nomina.retencionIrpf),
        const Divider(height: 16),
        _filaTotal('Retención IRPF', _nomina.retencionIrpf, const Color(0xFF7B1FA2)),
      ],
    );
  }

  Widget _seccionAusencias() {
    return _seccionCard(
      titulo: 'IV. VACACIONES / AUSENCIAS',
      color: const Color(0xFF00796B),
      icono: Icons.beach_access,
      children: [
        for (final linea in _nomina.lineasAusencias) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  linea['concepto'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: (linea['tipo'] as String?) == 'descuento'
                        ? Colors.red
                        : Colors.black87,
                  ),
                ),
              ),
              Text(
                (linea['tipo'] as String?) == 'descuento'
                    ? '−€${((linea['importe'] as num?)?.abs() ?? 0).toStringAsFixed(2)}'
                    : (linea['tipo'] as String?) == 'informativo'
                        ? '(informativo)'
                        : '€${((linea['importe'] as num?) ?? 0).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: (linea['tipo'] as String?) == 'descuento'
                      ? Colors.red
                      : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        if (_nomina.descuentoAusencias > 0) ...[
          const Divider(height: 16),
          _filaTotal('Descuento total ausencias', _nomina.descuentoAusencias,
              Colors.red),
        ],
      ],
    );
  }

  Widget _seccionNeto() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Text('LÍQUIDO A PERCIBIR', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            '€${_nomina.salarioNeto.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Devengos €${_nomina.totalDevengos.toStringAsFixed(2)} − Deducciones €${_nomina.totalDeducciones.toStringAsFixed(2)}'
            '${_nomina.descuentoAusencias > 0 ? ' − Ausencias €${_nomina.descuentoAusencias.toStringAsFixed(2)}' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _seccionCosteEmpresa() {
    return _seccionCard(
      titulo: 'COSTE EMPRESA (SS Patronal)',
      color: const Color(0xFF455A64),
      icono: Icons.business,
      children: [
        _filaPct('Contingencias comunes', 23.60, _nomina.ssEmpresaCC),
        _filaPct('Desempleo', _nomina.ssEmpresaDesempleo > _nomina.baseCotizacion * 0.06 ? 6.70 : 5.50, _nomina.ssEmpresaDesempleo),
        _filaPct('FOGASA', 0.20, _nomina.ssEmpresaFogasa),
        _filaPct('Formación profesional', 0.60, _nomina.ssEmpresaFP),
        _filaPct('AT/EP', 1.50, _nomina.ssEmpresaAT),
        _filaPct('MEI', 0.58, _nomina.ssMeiEmpresa),
        if (_nomina.ssSolidaridadEmpresa > 0)
          _filaPct('Solidaridad', 0, _nomina.ssSolidaridadEmpresa),
        if (_nomina.ssHorasExtraEmpresa > 0) ...[
          const Divider(height: 12),
          _filaPct(
            'H.E. ${_nomina.tipoHoraExtra.etiqueta} (cot. adicional)',
            _nomina.tipoHoraExtra.tipoEmpresa,
            _nomina.ssHorasExtraEmpresa,
          ),
        ],
        const Divider(height: 16),
        _filaTotal('Total SS Empresa', _nomina.totalSSEmpresa, const Color(0xFF455A64)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF44336).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('COSTE TOTAL EMPRESA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('€${_nomina.costeTotalEmpresa.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFF44336))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seccionNotas() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.notes, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Text('Notas', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Text(_nomina.notas!, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EDITAR HORAS EXTRA (solo en borrador)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _seccionEditarNomina() {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF0D47A1).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_calendar, size: 18, color: const Color(0xFF0D47A1)),
                const SizedBox(width: 8),
                const Text('Editar nómina (borrador)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                        color: Color(0xFF0D47A1))),
              ],
            ),
            const SizedBox(height: 12),
            // Horas extra
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _nomina.horasExtra > 0
                        ? _nomina.horasExtra.toStringAsFixed(0) : '',
                    decoration: InputDecoration(
                      labelText: 'Nº horas extra',
                      prefixIcon: const Icon(Icons.access_time, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _horasExtraTemp = double.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: _nomina.precioHoraExtra > 0
                        ? _nomina.precioHoraExtra.toStringAsFixed(2) : '',
                    decoration: InputDecoration(
                      labelText: '€ / hora',
                      prefixIcon: const Icon(Icons.euro, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => _precioHoraTemp = double.tryParse(v) ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Tipo horas extra (solo si hay horas)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.gavel, size: 14, color: Color(0xFF0D47A1)),
                  SizedBox(width: 6),
                  Text('Tipo de horas extra (cotización SS)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: Color(0xFF0D47A1))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _chipTipoHE('No estruct.', TipoHoraExtra.noEstructural),
                  const SizedBox(width: 6),
                  _chipTipoHE('Estructural', TipoHoraExtra.estructural),
                  const SizedBox(width: 6),
                  _chipTipoHE('Fuerza mayor', TipoHoraExtra.fuerzaMayor),
                ]),
                const SizedBox(height: 4),
                Text(
                  _tipoHoraExtraTemp == TipoHoraExtra.fuerzaMayor
                      ? '⚠️ Fuerza mayor: 2% tra + 12% emp (incendio, inundación…)'
                      : 'Normal: 4,70% tra + 23,60% emp',
                  style: TextStyle(
                    fontSize: 11,
                    color: _tipoHoraExtraTemp == TipoHoraExtra.fuerzaMayor
                        ? Colors.red[700]
                        : Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            // Advertencia 80h/año (art. 35 ET)
            if (_horasExtraTemp > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _horasExtraTemp > 80
                      ? Colors.red.withValues(alpha: 0.08)
                      : Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _horasExtraTemp > 80
                        ? Colors.red.withValues(alpha: 0.4)
                        : Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(children: [
                  Icon(
                    _horasExtraTemp > 80 ? Icons.error_outline : Icons.info_outline,
                    size: 14,
                    color: _horasExtraTemp > 80 ? Colors.red : Colors.amber[700],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _horasExtraTemp > 80
                          ? 'ATENCIÓN: supera el límite de 80 h/año (art. 35 ET)'
                          : 'Límite legal: 80 horas extra/año (art. 35 ET)',
                      style: TextStyle(
                        fontSize: 11,
                        color: _horasExtraTemp > 80 ? Colors.red[700] : Colors.amber[700],
                        fontWeight: _horasExtraTemp > 80
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 10),
            // Complementos variables
            TextFormField(
              initialValue: '',
              decoration: InputDecoration(
                labelText: 'Complementos variables (€)',
                prefixIcon: const Icon(Icons.add_chart, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                helperText: 'Bonus, comisiones, dietas, etc.',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _complementosTemp = double.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 10),
            // Notas
            TextFormField(
              initialValue: _nomina.notas ?? '',
              decoration: InputDecoration(
                labelText: 'Notas internas',
                prefixIcon: const Icon(Icons.note, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: (v) => _notasTemp = v,
            ),
            const SizedBox(height: 8),
            // Preview
            if (_horasExtraTemp > 0 && _precioHoraTemp > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  'HE: ${_horasExtraTemp.toStringAsFixed(0)}h × '
                  '${_precioHoraTemp.toStringAsFixed(2)}€/h = '
                  '€${(_horasExtraTemp * _precioHoraTemp).toStringAsFixed(2)}'
                  '  [${_tipoHoraExtraTemp.etiqueta}]',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600],
                      fontStyle: FontStyle.italic),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _procesando ? null : _recalcularNomina,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: _procesando
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                label: Text(
                  _procesando ? 'Recalculando...' : 'Recalcular nómina',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recalcularNomina() async {
    setState(() => _procesando = true);
    try {
      final nueva = await _svc.editarNominaBorrador(
        empresaId: widget.empresaId,
        nominaId: _nomina.id,
        horasExtra: _horasExtraTemp,
        precioHoraExtra: _precioHoraTemp,
        complementosOverride: _complementosTemp,
        notas: _notasTemp.isNotEmpty ? _notasTemp : null,
        tipoHoraExtra: _tipoHoraExtraTemp,
      );

      setState(() => _nomina = nueva);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Nómina recalculada correctamente'),
            backgroundColor: Color(0xFF2E7D32),
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
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _aprobar() async {
    setState(() => _procesando = true);
    try {
      await _svc.aprobarNomina(widget.empresaId, _nomina.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Nómina aprobada'), backgroundColor: Color(0xFF1976D2)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _pagar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar pago'),
        content: Text(
          '¿Marcar esta nómina como pagada?\n\n'
          'Se creará automáticamente un gasto en contabilidad '
          'por €${_nomina.costeTotalEmpresa.toStringAsFixed(2)} (coste total empresa).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Confirmar pago', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesando = true);
    try {
      await _svc.pagarNomina(widget.empresaId, _nomina.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Nómina pagada y gasto registrado'), backgroundColor: Color(0xFF2E7D32)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar nómina?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _svc.eliminarNomina(widget.empresaId, _nomina.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Nómina eliminada')),
      );
      Navigator.pop(context);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS AUXILIARES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _seccionCard({
    required String titulo,
    required Color color,
    required IconData icono,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(icono, size: 18, color: color),
              const SizedBox(width: 8),
              Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(String concepto, double importe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(concepto, style: const TextStyle(fontSize: 13)),
          Text('€${importe.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _filaDestacada(String concepto, double importe, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(concepto, style: TextStyle(fontSize: 13, color: color,
                  fontWeight: FontWeight.w500)),
            ],
          ),
          Text('€${importe.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _filaPct(String concepto, double porcentaje, double importe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(concepto, style: const TextStyle(fontSize: 13))),
          Text('${porcentaje.toStringAsFixed(2)}%',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text('€${importe.toStringAsFixed(2)}',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _filaTotal(String label, double importe, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
        Text('€${importe.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }

  Widget _datoPequeno(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// Chip selector para el tipo de hora extra.
  Widget _chipTipoHE(String label, TipoHoraExtra tipo) {
    final sel = _tipoHoraExtraTemp == tipo;
    final color = tipo == TipoHoraExtra.fuerzaMayor
        ? Colors.red[700]!
        : const Color(0xFF0D47A1);
    return GestureDetector(
      onTap: () => setState(() => _tipoHoraExtraTemp = tipo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? color : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: sel ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}


















