import 'package:flutter/material.dart';
import '../../../models/vacacion_model.dart';
import '../../../services/cobertura_equipo_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET DE COBERTURA SEMANAL DEL EQUIPO
// Vista columnar con semáforo verde/amarillo/rojo por día.
// ═══════════════════════════════════════════════════════════════════════════════

class CoberturaSemanalWidget extends StatefulWidget {
  final String empresaId;
  final bool compacto; // Para versión dashboard (5 días, sin detalle)

  const CoberturaSemanalWidget({
    super.key,
    required this.empresaId,
    this.compacto = false,
  });

  @override
  State<CoberturaSemanalWidget> createState() => _CoberturaSemanalWidgetState();
}

class _CoberturaSemanalWidgetState extends State<CoberturaSemanalWidget> {
  final CoberturaEquipoService _svc = CoberturaEquipoService();

  late DateTime _lunesActual;
  List<CoberturaDia> _cobertura = [];
  bool _cargando = false;
  int? _diaExpandido;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _lunesActual = ahora.subtract(Duration(days: ahora.weekday - 1));
    _lunesActual = DateTime(_lunesActual.year, _lunesActual.month, _lunesActual.day);
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final cobertura = await _svc.calcularCoberturaSemana(
        widget.empresaId,
        _lunesActual,
      );
      if (mounted) {
        setState(() {
          _cobertura = cobertura;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('CoberturaSemanal: error $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _semanaAnterior() {
    _lunesActual = _lunesActual.subtract(const Duration(days: 7));
    _diaExpandido = null;
    _cargar();
  }

  void _semanaSiguiente() {
    _lunesActual = _lunesActual.add(const Duration(days: 7));
    _diaExpandido = null;
    _cargar();
  }

  void _irAHoy() {
    final ahora = DateTime.now();
    _lunesActual = ahora.subtract(Duration(days: ahora.weekday - 1));
    _lunesActual = DateTime(_lunesActual.year, _lunesActual.month, _lunesActual.day);
    _diaExpandido = null;
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compacto) return _buildCompacto();
    return _buildCompleto();
  }

  // ── VERSIÓN COMPLETA (tab Cobertura) ──────────────────────────────────────

  Widget _buildCompleto() {
    final diasReducidos =
        _cobertura.where((c) => c.nivel != NivelCobertura.verde).length;

    return Column(
      children: [
        // Cabecera
        _buildCabecera(),

        // Resumen mensual
        if (diasReducidos > 0)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Esta semana hay $diasReducidos día${diasReducidos > 1 ? 's' : ''} con cobertura reducida',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

        // Columnas de días
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _cobertura.length,
              itemBuilder: (context, i) => _buildDiaCard(i),
            ),
          ),
      ],
    );
  }

  Widget _buildCabecera() {
    final domingo = _lunesActual.add(const Duration(days: 6));
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF00796B)),
            onPressed: _semanaAnterior,
            tooltip: 'Semana anterior',
          ),
          Expanded(
            child: Text(
              '${_formatFechaCorta(_lunesActual)} — ${_formatFechaCorta(domingo)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          TextButton.icon(
            onPressed: _irAHoy,
            icon: const Icon(Icons.today, size: 16),
            label: const Text('Hoy', style: TextStyle(fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF00796B)),
            onPressed: _semanaSiguiente,
            tooltip: 'Semana siguiente',
          ),
        ],
      ),
    );
  }

  Widget _buildDiaCard(int index) {
    final c = _cobertura[index];
    final expandido = _diaExpandido == index;
    final esFinde =
        c.fecha.weekday == DateTime.saturday || c.fecha.weekday == DateTime.sunday;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.esCritico
              ? Colors.red[300]!
              : Colors.grey[200]!,
          width: c.esCritico ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _diaExpandido = expandido ? null : index;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Fila principal
              Row(
                children: [
                  // Semáforo
                  _buildSemaforoCircle(c.nivel),
                  const SizedBox(width: 10),
                  // Día
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_diaSemana(c.fecha.weekday)} ${c.fecha.day}/${c.fecha.month}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: esFinde ? Colors.grey : Colors.black87,
                          ),
                        ),
                        if (c.esFestivo && c.nombreFestivo != null)
                          Text(
                            '🎉 ${c.nombreFestivo}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.orange[700]),
                          ),
                      ],
                    ),
                  ),
                  // Disponibles
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${c.empleadosPresentes}/${c.totalEmpleados}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: _colorNivel(c.nivel)),
                      ),
                      Text(
                        'disponibles',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.grey[400],
                  ),
                ],
              ),

              // Detalle expandido
              if (expandido) ...[
                const Divider(height: 16),
                if (c.ausentes.isEmpty)
                  Text('Todos los empleados disponibles',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12))
                else
                  ...c.ausentes.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              _iconoTipoAusencia(a.tipoAusencia),
                              size: 16,
                              color: _colorTipoAusencia(a.tipoAusencia),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(a.nombre,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _colorTipoAusencia(a.tipoAusencia)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                a.tipoAusencia.etiqueta,
                                style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        _colorTipoAusencia(a.tipoAusencia),
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── VERSIÓN COMPACTA (dashboard) ──────────────────────────────────────────

  Widget _buildCompacto() {
    final diasLaborables =
        _cobertura.where((c) => c.fecha.weekday <= 5).take(5).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups, size: 18, color: Color(0xFF00796B)),
              const SizedBox(width: 6),
              const Text('Cobertura esta semana',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              if (_cargando)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          if (diasLaborables.isEmpty)
            Text('Cargando...',
                style: TextStyle(color: Colors.grey[400], fontSize: 12))
          else
            Row(
              children: diasLaborables
                  .map((c) => Expanded(
                        child: Column(
                          children: [
                            Text(
                              _diaSemanaCorto(c.fecha.weekday),
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            _buildSemaforoCircle(c.nivel, size: 20),
                            const SizedBox(height: 2),
                            Text(
                              '${c.empleadosPresentes}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _colorNivel(c.nivel)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  Widget _buildSemaforoCircle(NivelCobertura nivel, {double size = 14}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorNivel(nivel),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: _colorNivel(nivel).withValues(alpha: 0.3),
              blurRadius: 3),
        ],
      ),
    );
  }

  Color _colorNivel(NivelCobertura nivel) {
    switch (nivel) {
      case NivelCobertura.verde:
        return Colors.green;
      case NivelCobertura.amarillo:
        return Colors.orange;
      case NivelCobertura.rojo:
        return Colors.red;
    }
  }

  IconData _iconoTipoAusencia(TipoAusencia tipo) {
    switch (tipo) {
      case TipoAusencia.vacaciones:
        return Icons.beach_access;
      case TipoAusencia.ausenciaJustificada:
        return Icons.event_busy;
      case TipoAusencia.ausenciaInjustificada:
        return Icons.cancel;
      case TipoAusencia.permisoRetribuido:
        return Icons.card_giftcard;
      case TipoAusencia.bajaMedica:
        return Icons.local_hospital;
    }
  }

  Color _colorTipoAusencia(TipoAusencia tipo) {
    switch (tipo) {
      case TipoAusencia.vacaciones:
        return Colors.green;
      case TipoAusencia.ausenciaJustificada:
        return Colors.orange;
      case TipoAusencia.ausenciaInjustificada:
        return Colors.red;
      case TipoAusencia.permisoRetribuido:
        return Colors.teal;
      case TipoAusencia.bajaMedica:
        return Colors.blue;
    }
  }

  String _diaSemana(int weekday) {
    const dias = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return dias[weekday];
  }

  String _diaSemanaCorto(int weekday) {
    const dias = ['', 'L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return dias[weekday];
  }

  String _formatFechaCorta(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

