import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA DE DETALLE EXPANDIDO DE RESERVA/CITA
// ─────────────────────────────────────────────────────────────────────────────

class DetalleReservaScreen extends StatefulWidget {
  final DocumentSnapshot doc;
  final String empresaId;

  const DetalleReservaScreen({
    super.key,
    required this.doc,
    required this.empresaId,
  });

  @override
  State<DetalleReservaScreen> createState() => _DetalleReservaScreenState();
}

class _DetalleReservaScreenState extends State<DetalleReservaScreen> {
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(
        (widget.doc.data() as Map<String, dynamic>?) ?? {});
  }

  static DateTime _parseTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  String get _cliente =>
      (_data['cliente'] ?? _data['nombre_cliente'] ?? 'Anónimo').toString();
  String get _servicio =>
      (_data['servicio'] ?? _data['tipo'] ?? '').toString();
  String get _telefono =>
      (_data['telefono'] ?? _data['telefono_cliente'] ?? '').toString();
  String get _profesional =>
      (_data['profesional'] ?? _data['empleado'] ?? '').toString();
  String get _notas =>
      (_data['notas'] ?? _data['observaciones'] ?? _data['comentarios'] ?? '').toString();
  String get _estado => (_data['estado'] as String? ?? 'PENDIENTE').toUpperCase();
  String get _coleccion =>
      widget.doc.reference.path.contains('citas') ? 'citas' : 'reservas';
  String get _emailCliente =>
      (_data['email_cliente'] ?? _data['correo_cliente'] ?? _data['email'] ?? '').toString();
  bool get _tieneAlergenos => _data['alergenos'] == true;
  String get _detalleAlergenos =>
      (_data['detalle_alergenos'] ?? _data['alergias_detalle'] ?? '').toString();
  String get _zona => (_data['zona'] ?? '').toString();

  Color get _colorEstado {
    switch (_estado) {
      case 'CONFIRMADA':
        return const Color(0xFF4CAF50);
      case 'CANCELADA':
        return const Color(0xFFD32F2F);
      case 'COMPLETADA':
        return const Color(0xFF607D8B);
      case 'POR_CONFIRMAR':
      case 'SOLICITADA':
        return const Color(0xFF1976D2);
      default:
        return const Color(0xFFF57C00);
    }
  }

  IconData get _iconoEstado {
    switch (_estado) {
      case 'CONFIRMADA':
        return Icons.check_circle;
      case 'CANCELADA':
        return Icons.cancel;
      case 'COMPLETADA':
        return Icons.task_alt;
      case 'POR_CONFIRMAR':
      case 'SOLICITADA':
        return Icons.schedule;
      default:
        return Icons.pending;
    }
  }

  Future<void> _actualizarEstado(String nuevoEstado) async {
    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection(_coleccion)
          .doc(widget.doc.id)
          .update({
        'estado': nuevoEstado,
        'fecha_modificacion': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _data['estado'] = nuevoEstado);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _dialogoCancelacion() async {
    final motivoCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Seguro que quieres cancelar esta reserva?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Cliente: $_cliente'),
            if (_servicio.isNotEmpty) Text('Servicio: $_servicio'),
            Text(
              'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(_parseTs(_data['fecha_hora']))}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo de cancelación (opcional)',
                border: OutlineInputBorder(),
                hintText: 'Ej: Cliente canceló, cambio de fecha...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final motivo = motivoCtrl.text.trim().isEmpty
                  ? 'Sin motivo especificado'
                  : motivoCtrl.text.trim();
              try {
                await FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(widget.empresaId)
                    .collection(_coleccion)
                    .doc(widget.doc.id)
                    .update({
                  'estado': 'CANCELADA',
                  'motivo_cancelacion': motivo,
                  'fecha_cancelacion': FieldValue.serverTimestamp(),
                  'fecha_modificacion': FieldValue.serverTimestamp(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                setState(() {
                  _data['estado'] = 'CANCELADA';
                  _data['motivo_cancelacion'] = motivo;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Reserva cancelada')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    motivoCtrl.dispose();
  }

  void _abrirEditar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditarReservaSheet(
        doc: widget.doc,
        empresaId: widget.empresaId,
        coleccion: _coleccion,
        onActualizado: (nuevosDatos) {
          setState(() => _data = nuevosDatos);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fecha = _parseTs(_data['fecha_hora'] ?? _data['fecha']);
    final precio = _data['precio'];
    
    // Convertir comensales a int de forma segura
    final comensalesRaw = _data['numero_personas'] ?? _data['comensales'] ?? _data['personas'];
    int? comensales;
    if (comensalesRaw != null) {
      if (comensalesRaw is num) {
        comensales = comensalesRaw.toInt();
      } else if (comensalesRaw is String) {
        comensales = int.tryParse(comensalesRaw);
      }
    }
    
    final motivoCancelacion = _data['motivo_cancelacion'] as String?;
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Reserva'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _abrirEditar,
            tooltip: 'Editar reserva',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge de estado
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _colorEstado.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _colorEstado, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconoEstado, color: _colorEstado, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _estado,
                    style: TextStyle(
                      color: _colorEstado,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Información del cliente
            _buildSeccion('👤 Cliente', [
              _buildFila('Nombre', _cliente),
              if (_telefono.isNotEmpty) _buildFila('Teléfono', _telefono),
              if (_emailCliente.isNotEmpty) _buildFila('Email', _emailCliente),
            ]),

            const Divider(height: 32),

            // Información de la reserva
            _buildSeccion('📅 Reserva', [
              _buildFila(
                'Fecha y hora',
                DateFormat('EEEE, d MMMM yyyy · HH:mm', 'es')
                    .format(fecha)
                    ._cap(),
              ),
              if (_servicio.isNotEmpty) _buildFila('Servicio', _servicio),
              if (_profesional.isNotEmpty)
                _buildFila('Profesional', _profesional),
              if (comensales != null && comensales > 0)
                _buildFila(
                  'Comensales',
                  '$comensales ${comensales == 1 ? "persona" : "personas"}',
                ),
              if (_zona.isNotEmpty) _buildFila('Zona', _zona.toUpperCase()),
              if (precio != null)
                _buildFila(
                    'Precio', '€${(precio as num).toStringAsFixed(2)}'),
              if (_notas.isNotEmpty) _buildFila('Notas', _notas),
            ]),

            // Alérgenos (campos extra Damajuana)
            if (_tieneAlergenos || _detalleAlergenos.isNotEmpty) ...[
              const Divider(height: 32),
              _buildSeccion('🌾 Alérgenos', [
                _buildFila('¿Tiene alérgenos?', _tieneAlergenos ? 'Sí' : 'No'),
                if (_detalleAlergenos.isNotEmpty)
                  _buildFila('Detalle', _detalleAlergenos),
              ]),
            ],

            if (_estado == 'CANCELADA' && motivoCancelacion != null) ...[
              const Divider(height: 32),
              _buildSeccion('❌ Cancelación', [
                _buildFila('Motivo', motivoCancelacion),
                if (_data['fecha_cancelacion'] != null)
                  _buildFila(
                    'Fecha de cancelación',
                    DateFormat('dd/MM/yyyy HH:mm')
                        .format(_parseTs(_data['fecha_cancelacion'])),
                  ),
              ]),
            ],

            const Divider(height: 32),

            // Metadatos
            _buildSeccion('ℹ️ Sistema', [
              _buildFila('ID', widget.doc.id),
              if (_data['created_at'] != null || _data['fecha_creacion'] != null)
                _buildFila(
                  'Creada',
                  DateFormat('dd/MM/yyyy HH:mm')
                      .format(_parseTs(_data['created_at'] ?? _data['fecha_creacion'])),
                ),
              if (_data['fecha_modificacion'] != null)
                _buildFila(
                  'Última modificación',
                  DateFormat('dd/MM/yyyy HH:mm')
                      .format(_parseTs(_data['fecha_modificacion'])),
                ),
            ]),

            const SizedBox(height: 32),

            // Botón Confirmar (si toca)
            if (_estado == 'PENDIENTE' ||
                _estado == 'SOLICITADA' ||
                _estado == 'POR_CONFIRMAR') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar Reserva'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _actualizarEstado('CONFIRMADA'),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Botón Cancelar
            if (_estado != 'CANCELADA' && _estado != 'COMPLETADA')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar Reserva'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F),
                    side: const BorderSide(color: Color(0xFFD32F2F)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _dialogoCancelacion,
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccion(String titulo, List<Widget> filas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...filas,
      ],
    );
  }

  Widget _buildFila(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}

extension _CapStr on String {
  String _cap() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO DE EDICIÓN DE RESERVA
// ─────────────────────────────────────────────────────────────────────────────

class _EditarReservaSheet extends StatefulWidget {
  final DocumentSnapshot doc;
  final String empresaId;
  final String coleccion;
  final void Function(Map<String, dynamic>) onActualizado;

  const _EditarReservaSheet({
    required this.doc,
    required this.empresaId,
    required this.coleccion,
    required this.onActualizado,
  });

  @override
  State<_EditarReservaSheet> createState() => _EditarReservaSheetState();
}

class _EditarReservaSheetState extends State<_EditarReservaSheet> {
  late final TextEditingController _clienteCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _servicioCtrl;
  late final TextEditingController _notasCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _comensalesCtrl;
  late final TextEditingController _detalleAlergenosCtrl;
  late DateTime _fecha;
  late TimeOfDay _hora;
  late String _estadoSel;
  late bool _alergenos;
  late String _zonaSel; // 'terraza' | 'salon' | ''

  static DateTime _parseTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    final d = (widget.doc.data() as Map<String, dynamic>?) ?? {};
    final fechaHora = _parseTs(d['fecha_hora']);

    _clienteCtrl = TextEditingController(
        text: (d['cliente'] ?? d['nombre_cliente'] ?? '').toString());
    _telefonoCtrl = TextEditingController(
        text: (d['telefono'] ?? d['telefono_cliente'] ?? '').toString());
    _servicioCtrl = TextEditingController(
        text: (d['servicio'] ?? d['tipo'] ?? '').toString());
    _notasCtrl = TextEditingController(
        text: (d['notas'] ?? d['observaciones'] ?? '').toString());
    _precioCtrl = TextEditingController(
        text: d['precio'] != null ? '${d['precio']}' : '');
    _comensalesCtrl = TextEditingController(
        text: (d['numero_personas'] ?? d['comensales'] ?? 1).toString());
    _detalleAlergenosCtrl = TextEditingController(
        text: (d['detalle_alergenos'] ?? d['alergenos_descripcion'] ?? '').toString());

    _fecha = DateTime(fechaHora.year, fechaHora.month, fechaHora.day);
    _hora = TimeOfDay(hour: fechaHora.hour, minute: fechaHora.minute);
    _estadoSel = (d['estado'] as String? ?? 'PENDIENTE').toUpperCase();
    _alergenos = d['alergenos'] == true;
    _zonaSel = (d['zona'] as String? ?? '').toLowerCase();
  }

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _telefonoCtrl.dispose();
    _servicioCtrl.dispose();
    _notasCtrl.dispose();
    _precioCtrl.dispose();
    _comensalesCtrl.dispose();
    _detalleAlergenosCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_clienteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El nombre del cliente es obligatorio')));
      return;
    }
    final dt = DateTime(
        _fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);
    try {
      final nuevosDatos = {
        'cliente': _clienteCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'servicio': _servicioCtrl.text.trim(),
        'precio': double.tryParse(_precioCtrl.text.trim()),
        'numero_personas': int.tryParse(_comensalesCtrl.text.trim()) ?? 1,
        'notas': _notasCtrl.text.trim(),
        'estado': _estadoSel,
        'fecha_hora': Timestamp.fromDate(dt),
        'fecha_modificacion': FieldValue.serverTimestamp(),
        'alergenos': _alergenos,
        'detalle_alergenos': _alergenos ? _detalleAlergenosCtrl.text.trim() : '',
        'zona': _zonaSel,
      };
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection(widget.coleccion)
          .doc(widget.doc.id)
          .update(nuevosDatos);

      if (!mounted) return;
      Navigator.pop(context);

      // Merge datos actualizados con los existentes para refrescar la pantalla
      final datosActuales =
          Map<String, dynamic>.from(
              (widget.doc.data() as Map<String, dynamic>?) ?? {});
      datosActuales.addAll({
        'cliente': _clienteCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'servicio': _servicioCtrl.text.trim(),
        'precio': double.tryParse(_precioCtrl.text.trim()),
        'numero_personas': int.tryParse(_comensalesCtrl.text.trim()) ?? 1,
        'notas': _notasCtrl.text.trim(),
        'estado': _estadoSel,
        'fecha_hora': Timestamp.fromDate(dt),
        'alergenos': _alergenos,
        'detalle_alergenos': _alergenos ? _detalleAlergenosCtrl.text.trim() : '',
        'zona': _zonaSel,
      });
      widget.onActualizado(datosActuales);

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Reserva actualizada')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
              child: Row(
                children: [
                  const Text('Editar Reserva',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  _campo(_clienteCtrl, 'Cliente *', Icons.person_outline),
                  _campo(_telefonoCtrl, 'Teléfono', Icons.phone_outlined),
                  _campo(_servicioCtrl, 'Servicio', Icons.spa_outlined),
                  Row(
                    children: [
                      Expanded(
                        child: _campo(_precioCtrl, 'Precio (€)',
                            Icons.euro_outlined,
                            keyboard: TextInputType.number),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _campo(_comensalesCtrl, 'Comensales',
                            Icons.people_outlined,
                            keyboard: TextInputType.number),
                      ),
                    ],
                  ),
                  // Selector de fecha y hora
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined,
                        color: Colors.grey),
                    title: Text(
                      DateFormat('EEEE d MMMM · HH:mm', 'es')
                          .format(DateTime(_fecha.year, _fecha.month,
                              _fecha.day, _hora.hour, _hora.minute))
                          ._cap(),
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _fecha,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                            );
                            if (d != null) setState(() => _fecha = d);
                          },
                          child: const Text('Fecha'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final t = await showTimePicker(
                                context: context, initialTime: _hora);
                            if (t != null) setState(() => _hora = t);
                          },
                          child: const Text('Hora'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Estado',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      'PENDIENTE',
                      'CONFIRMADA',
                      'POR_CONFIRMAR',
                      'COMPLETADA',
                      'CANCELADA',
                    ]
                        .map((e) => ChoiceChip(
                              label: Text(e,
                                  style:
                                      const TextStyle(fontSize: 12)),
                              selected: _estadoSel == e,
                              onSelected: (_) =>
                                  setState(() => _estadoSel = e),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  _campo(_notasCtrl, 'Notas', Icons.notes_outlined,
                      maxLines: 3),

                  // ── Campos extra Damajuana ──────────────────────────────
                  const SizedBox(height: 8),
                  const Text('Zona',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['terraza', 'salon', '']
                        .map((z) => ChoiceChip(
                              label: Text(
                                z.isEmpty ? 'Sin especificar' : z[0].toUpperCase() + z.substring(1),
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: _zonaSel == z,
                              onSelected: (_) => setState(() => _zonaSel = z),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('¿Tiene alérgenos?',
                        style: TextStyle(fontSize: 14)),
                    value: _alergenos,
                    onChanged: (v) => setState(() {
                      _alergenos = v;
                      if (!v) _detalleAlergenosCtrl.clear();
                    }),
                  ),
                  if (_alergenos) ...[
                    _campo(_detalleAlergenosCtrl, 'Detalle de alérgenos',
                        Icons.warning_amber_outlined,
                        maxLines: 2),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ElevatedButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar cambios'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 14),
          ),
        ),
      );
}

