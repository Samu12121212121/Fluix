import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/modelos/campana_email.dart';
import '../../../services/campanas_email_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB — Campañas de Email Marketing
// ═════════════════════════════════════════════════════════════════════════════

class TabCampanasEmail extends StatelessWidget {
  final String empresaId;
  final Color color;

  const TabCampanasEmail({
    super.key,
    required this.empresaId,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final svc = CampanasEmailService();
    return Column(children: [
      _buildHeader(context, svc),
      Expanded(child: StreamBuilder<List<CampanaEmail>>(
        stream: svc.obtenerCampanas(empresaId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: color));
          }
          final campanas = snap.data ?? [];
          if (campanas.isEmpty) return _buildVacio(context, svc);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
            itemCount: campanas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _TarjetaCampana(
              campana: campanas[i],
              color: color,
              empresaId: empresaId,
              svc: svc,
              onEdit: () => _abrirEditor(context, svc, campana: campanas[i]),
            ),
          );
        },
      )),
    ]);
  }

  Widget _buildHeader(BuildContext context, CampanasEmailService svc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Campañas de email',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          Text('Crea y envía newsletters a tus clientes',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ])),
        FilledButton.icon(
          onPressed: () => _abrirEditor(context, svc),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Nueva', style: TextStyle(fontSize: 13)),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          ),
        ),
      ]),
    );
  }

  Widget _buildVacio(BuildContext context, CampanasEmailService svc) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.mail_outline_rounded, size: 72, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('Todavía no tienes campañas de email',
          style: TextStyle(fontSize: 17, color: Colors.grey[600], fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('Crea tu primera campaña y envíala a tus lectores',
          style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => _abrirEditor(context, svc),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear campaña'),
        style: FilledButton.styleFrom(backgroundColor: color),
      ),
    ]));
  }

  void _abrirEditor(BuildContext context, CampanasEmailService svc,
      {CampanaEmail? campana}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditorCampana(
        empresaId: empresaId,
        color: color,
        svc: svc,
        campana: campana,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA CAMPAÑA
// ─────────────────────────────────────────────────────────────────────────────

class _TarjetaCampana extends StatelessWidget {
  final CampanaEmail campana;
  final Color color;
  final String empresaId;
  final CampanasEmailService svc;
  final VoidCallback onEdit;

  const _TarjetaCampana({
    required this.campana,
    required this.color,
    required this.empresaId,
    required this.svc,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final esBorrador = campana.estado == EstadoCampana.borrador ||
        campana.estado == EstadoCampana.programada;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(campana.nombre,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A)))),
            _estadoBadge(campana.estado),
          ]),
          const SizedBox(height: 4),
          Text(campana.asunto,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          if (campana.estado == EstadoCampana.enviada) ...[
            const SizedBox(height: 10),
            Row(children: [
              _statChip(Icons.send_rounded, '${campana.totalEnviados}', 'Enviados', color),
              const SizedBox(width: 8),
              _statChip(Icons.visibility_outlined,
                  '${(campana.tasaApertura * 100).toStringAsFixed(1)}%', 'Abiertos',
                  const Color(0xFF059669)),
              const SizedBox(width: 8),
              _statChip(Icons.touch_app_outlined,
                  '${(campana.tasaClick * 100).toStringAsFixed(1)}%', 'Clicks',
                  const Color(0xFF7C3AED)),
            ]),
          ],
          if (campana.fechaEnvio != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                campana.estado == EstadoCampana.enviada
                    ? 'Enviada el ${DateFormat('dd/MM/yyyy HH:mm').format(campana.fechaEnvio!)}'
                    : 'Programada para ${DateFormat('dd/MM/yyyy HH:mm').format(campana.fechaEnvio!)}',
                style: TextStyle(fontSize: 10.5, color: Colors.grey[400]),
              ),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            if (esBorrador) ...[
              _botonAccion(
                label: 'Editar',
                icono: Icons.edit_outlined,
                onTap: onEdit,
                color: color,
              ),
              const SizedBox(width: 8),
              _botonAccion(
                label: 'Enviar ahora',
                icono: Icons.send_rounded,
                onTap: () => _confirmarEnvio(context),
                color: const Color(0xFF059669),
              ),
            ],
            if (campana.estado == EstadoCampana.programada) ...[
              _botonAccion(
                label: 'Cancelar',
                icono: Icons.cancel_outlined,
                onTap: () => svc.cancelarProgramacion(empresaId, campana.id),
                color: Colors.orange,
              ),
            ],
            const Spacer(),
            IconButton(
              onPressed: () => _confirmarEliminar(context),
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Color(0xFFCB2121)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              onPressed: () => svc.duplicarCampana(empresaId, campana),
              icon: Icon(Icons.copy_outlined, size: 18, color: Colors.grey[400]),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Duplicar',
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _botonAccion(
      {required String label, required IconData icono,
      required VoidCallback onTap, required Color color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _statChip(IconData icono, String valor, String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 12, color: c),
          const SizedBox(width: 4),
          Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
        ]),
        Text(label, style: TextStyle(fontSize: 9, color: c.withValues(alpha: 0.7))),
      ]),
    );
  }

  Widget _estadoBadge(EstadoCampana estado) {
    final (bg, fg) = switch (estado) {
      EstadoCampana.borrador   => (const Color(0xFFF1F5F9), const Color(0xFF64748B)),
      EstadoCampana.programada => (const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
      EstadoCampana.enviando   => (const Color(0xFFFEF3C7), const Color(0xFFD97706)),
      EstadoCampana.enviada    => (const Color(0xFFD1FAE5), const Color(0xFF059669)),
      EstadoCampana.fallida    => (const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(estado.label, style: TextStyle(fontSize: 10.5, color: fg, fontWeight: FontWeight.w700)),
    );
  }

  void _confirmarEnvio(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enviar campaña'),
        content: Text('¿Enviar "${campana.nombre}" ahora a todos los destinatarios?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              svc.enviarAhora(empresaId, campana.id);
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar campaña'),
        content: Text('¿Eliminar "${campana.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              svc.eliminarCampana(empresaId, campana.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR DE CAMPAÑA (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _EditorCampana extends StatefulWidget {
  final String empresaId;
  final Color color;
  final CampanasEmailService svc;
  final CampanaEmail? campana;

  const _EditorCampana({
    required this.empresaId,
    required this.color,
    required this.svc,
    this.campana,
  });

  @override
  State<_EditorCampana> createState() => _EditorCampanaState();
}

class _EditorCampanaState extends State<_EditorCampana> {
  final _nombreCtrl    = TextEditingController();
  final _asuntoCtrl    = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  final _manualCtrl    = TextEditingController();
  SegmentoCampana _segmento  = SegmentoCampana.todos;
  bool _guardando    = false;
  bool _programando  = false;
  DateTime? _fechaProgram;
  TimeOfDay? _horaProgram;

  @override
  void initState() {
    super.initState();
    final c = widget.campana;
    if (c != null) {
      _nombreCtrl.text    = c.nombre;
      _asuntoCtrl.text    = c.asunto;
      _contenidoCtrl.text = c.contenidoHtml;
      _segmento           = c.segmento;
      _manualCtrl.text    = c.destinatariosManual.join('\n');
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _asuntoCtrl.dispose();
    _contenidoCtrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty || _asuntoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y asunto son obligatorios')));
      return;
    }
    setState(() => _guardando = true);
    final manual = _segmento == SegmentoCampana.manual
        ? _manualCtrl.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.contains('@'))
            .toList()
        : <String>[];
    final campana = CampanaEmail(
      id:                  widget.campana?.id ?? '',
      nombre:              _nombreCtrl.text.trim(),
      asunto:              _asuntoCtrl.text.trim(),
      contenidoHtml:       _contenidoCtrl.text.trim(),
      estado:              widget.campana?.estado ?? EstadoCampana.borrador,
      segmento:            _segmento,
      destinatariosManual: manual,
      fechaCreacion:       widget.campana?.fechaCreacion ?? DateTime.now(),
    );
    try {
      await widget.svc.guardarCampana(widget.empresaId, campana);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.94,
          maxChildSize: 0.97,
          minChildSize: 0.5,
          expand: false,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Center(child: Container(
                width: 38, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Text(
                  widget.campana == null ? 'Nueva campaña' : 'Editar campaña',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                )),
                if (_guardando)
                  const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  FilledButton(
                    onPressed: _guardar,
                    style: FilledButton.styleFrom(
                      backgroundColor: c,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Guardar', style: TextStyle(fontSize: 13)),
                  ),
              ]),
              const SizedBox(height: 20),
              _campo('Nombre de la campaña *', _nombreCtrl, Icons.campaign_outlined),
              const SizedBox(height: 12),
              _campo('Asunto del email *', _asuntoCtrl, Icons.subject_rounded),
              const SizedBox(height: 16),
              // Segmento
              Text('Destinatarios',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              const SizedBox(height: 8),
              ...SegmentoCampana.values.map((seg) => RadioListTile<SegmentoCampana>(
                value: seg,
                groupValue: _segmento,
                onChanged: (v) => setState(() => _segmento = v!),
                title: Text(seg.label, style: const TextStyle(fontSize: 13)),
                activeColor: c,
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
              if (_segmento == SegmentoCampana.manual) ...[
                const SizedBox(height: 8),
                _campoMultilinea(
                  'Emails (uno por línea)', _manualCtrl,
                  Icons.alternate_email_rounded, 6,
                ),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text('Contenido del email',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]))),
                TextButton.icon(
                  onPressed: _contenidoCtrl.text.isNotEmpty ? _mostrarPreview : null,
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('Vista previa', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: c,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Puedes usar HTML básico: <b>, <a>, <p>, <img>',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              const SizedBox(height: 8),
              _campoMultilinea('Escribe el contenido aquí...', _contenidoCtrl,
                  Icons.code_rounded, 12),
              const SizedBox(height: 20),
              // ── Programar envío ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    const Text('Programar envío para más tarde',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: Color(0xFF1E40AF))),
                    const Spacer(),
                    if (_fechaProgram != null)
                      GestureDetector(
                        onTap: () => setState(() { _fechaProgram = null; _horaProgram = null; }),
                        child: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _fechaProgram ?? DateTime.now().add(const Duration(hours: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) setState(() => _fechaProgram = d);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.calendar_today_rounded, size: 14,
                                color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Text(
                              _fechaProgram != null
                                  ? '${_fechaProgram!.day.toString().padLeft(2,'0')}/'
                                    '${_fechaProgram!.month.toString().padLeft(2,'0')}/'
                                    '${_fechaProgram!.year}'
                                  : 'Fecha',
                              style: TextStyle(fontSize: 12,
                                  color: _fechaProgram != null
                                      ? const Color(0xFF0F172A)
                                      : Colors.grey[400]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _horaProgram ??
                                TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))),
                          );
                          if (t != null) setState(() => _horaProgram = t);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.access_time_rounded, size: 14,
                                color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Text(
                              _horaProgram != null
                                  ? '${_horaProgram!.hour.toString().padLeft(2,'0')}:'
                                    '${_horaProgram!.minute.toString().padLeft(2,'0')}'
                                  : 'Hora',
                              style: TextStyle(fontSize: 12,
                                  color: _horaProgram != null
                                      ? const Color(0xFF0F172A)
                                      : Colors.grey[400]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                  if (_fechaProgram != null && _horaProgram != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _programando ? null : _programarEnvio,
                        icon: _programando
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.schedule_send_rounded, size: 16),
                        label: const Text('Confirmar programación'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _programarEnvio() async {
    if (_fechaProgram == null || _horaProgram == null) return;
    if (_nombreCtrl.text.trim().isEmpty || _asuntoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guarda la campaña primero')));
      return;
    }
    setState(() => _programando = true);
    try {
      // Primero guardar borrador si es nueva
      final manual = _segmento == SegmentoCampana.manual
          ? _manualCtrl.text.split('\n')
              .map((e) => e.trim()).where((e) => e.contains('@')).toList()
          : <String>[];
      final campana = CampanaEmail(
        id:                  widget.campana?.id ?? '',
        nombre:              _nombreCtrl.text.trim(),
        asunto:              _asuntoCtrl.text.trim(),
        contenidoHtml:       _contenidoCtrl.text.trim(),
        estado:              EstadoCampana.borrador,
        segmento:            _segmento,
        destinatariosManual: manual,
        fechaCreacion:       widget.campana?.fechaCreacion ?? DateTime.now(),
      );
      final savedId = await widget.svc.guardarCampana(widget.empresaId, campana);
      final id = savedId.isNotEmpty ? savedId : (widget.campana?.id ?? '');
      if (id.isEmpty) throw Exception('No se pudo obtener el ID de la campaña');

      final fecha = DateTime(
        _fechaProgram!.year, _fechaProgram!.month, _fechaProgram!.day,
        _horaProgram!.hour, _horaProgram!.minute,
      );
      await widget.svc.programar(widget.empresaId, id, fecha);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Envío programado para el '
              '${_fechaProgram!.day}/${_fechaProgram!.month} '
              'a las ${_horaProgram!.hour.toString().padLeft(2,'0')}:'
              '${_horaProgram!.minute.toString().padLeft(2,'0')}'),
          backgroundColor: const Color(0xFF2563EB),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        setState(() => _programando = false);
      }
    }
  }

  void _mostrarPreview() {
    final html = _contenidoCtrl.text.trim();
    if (html.isEmpty) return;
    // Renderizar como texto legible (sin webview)
    final plain = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>',  caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<').replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_asuntoCtrl.text.isNotEmpty ? _asuntoCtrl.text : '(Sin asunto)',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('De: ${_nombreCtrl.text.isNotEmpty ? _nombreCtrl.text : "Tu empresa"}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ]),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20)),
            ]),
          ),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(plain,
                style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF1F2937))),
          )),
        ]),
      ),
    );
  }

  Widget _campo(String label, TextEditingController ctrl, IconData icono) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
          prefixIcon: Icon(icono, size: 17, color: Colors.grey[400]),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _campoMultilinea(String hint, TextEditingController ctrl,
      IconData icono, int lines) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: lines,
        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(top: 12, left: 12, right: 8),
            child: Icon(icono, size: 17, color: Colors.grey[400]),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
        ),
      ),
    );
  }
}
