// personalizacion_app_screen.dart
// Pestaña completa de personalización del perfil público del negocio

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/negocio_publico_model.dart';

const _kPrimario = Color(0xFF0A0F23);
const _kCard = Color(0xFF1E2139);
const _kAccent = Color(0xFF00FFC8);
const _kAccentRosa = Color(0xFFFF3296);
const _kTexto = Colors.white;
const _kMuted = Color(0xFFB0B3C1);
const _kBorde = Color(0xFF2A2E45);

class PersonalizacionAppScreen extends StatefulWidget {
  final String empresaId;
  const PersonalizacionAppScreen({super.key, required this.empresaId});

  @override
  State<PersonalizacionAppScreen> createState() => _PersonalizacionAppScreenState();
}

class _PersonalizacionAppScreenState extends State<PersonalizacionAppScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _guardando = false;
  String? _negocioId;

  // Controllers
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _igCtrl = TextEditingController();
  final _fbCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _webCtrl = TextEditingController();
  final _tycCtrl = TextEditingController();

  // Estado
  List<String> _fotos = [];
  Map<int, HorarioDia> _horarios = {};
  List<String> _servicios = [];
  List<String> _caracteristicas = [];
  List<CampoPersonalizado> _campos = [];
  String _nivelPrecio = '€€';
  int _duracion = 60;

  static const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _initHorarios();
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [_descCtrl, _emailCtrl, _igCtrl, _fbCtrl, _waCtrl, _webCtrl, _tycCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _initHorarios() {
    for (int i = 0; i < 7; i++) {
      _horarios[i] = HorarioDia(abierto: i < 5, horaApertura: '09:00', horaCierre: '20:00');
    }
  }

  Future<void> _cargar() async {
    try {
      // Buscar el negocio vinculado a esta empresa
      final snap = await FirebaseFirestore.instance
          .collection('negocios_publicos')
          .where('empresaIdVinculada', isEqualTo: widget.empresaId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return;
      final doc = snap.docs.first;
      final n = NegocioPublico.fromJson(doc.id, doc.data());

      if (!mounted) return;
      setState(() {
        _negocioId = doc.id;
        _descCtrl.text = n.descripcionDetallada ?? '';
        _emailCtrl.text = n.emailNotificaciones ?? '';
        _igCtrl.text = n.instagram ?? '';
        _fbCtrl.text = n.facebook ?? '';
        _waCtrl.text = n.whatsapp ?? '';
        _webCtrl.text = n.website ?? '';
        _tycCtrl.text = n.terminosYCondiciones ?? '';
        _fotos = n.fotosGaleria ?? [];
        if (n.horarios != null) _horarios = Map.from(n.horarios!);
        _servicios = n.serviciosDestacados ?? [];
        _caracteristicas = n.caracteristicas ?? [];
        _campos = n.camposPersonalizados ?? [];
        _nivelPrecio = n.nivelPrecio ?? '€€';
        _duracion = n.duracionPromedio ?? 60;
      });
    } catch (e) {
      if (mounted) _snack('Error cargando: $e', error: true);
    }
  }

  Future<void> _guardar() async {
    if (_negocioId == null) {
      _snack('No hay negocio vinculado a esta empresa', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(_negocioId)
          .update({
        'descripcionDetallada': _descCtrl.text.trim(),
        'emailNotificaciones': _emailCtrl.text.trim(),
        'fotosGaleria': _fotos,
        'horarios': _horarios.map((k, v) => MapEntry(k.toString(), v.toJson())),
        'serviciosDestacados': _servicios,
        'caracteristicas': _caracteristicas,
        'camposPersonalizados': _campos.map((c) => c.toJson()).toList(),
        'nivelPrecio': _nivelPrecio,
        'duracionPromedio': _duracion,
        'instagram': _igCtrl.text.trim(),
        'facebook': _fbCtrl.text.trim(),
        'whatsapp': _waCtrl.text.trim(),
        'website': _webCtrl.text.trim(),
        'terminosYCondiciones': _tycCtrl.text.trim(),
      });
      _snack('✅ Cambios guardados');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFFF2850) : const Color(0xFF00FFC8),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPrimario,
      appBar: AppBar(
        backgroundColor: const Color(0xFF151932),
        foregroundColor: _kTexto,
        title: const Text('Personalización App', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent)),
            )
          else
            FilledButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Guardar'),
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: _kPrimario,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: _kAccent,
          labelColor: _kAccent,
          unselectedLabelColor: _kMuted,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Info'),
            Tab(icon: Icon(Icons.schedule, size: 18), text: 'Horarios'),
            Tab(icon: Icon(Icons.photo_library, size: 18), text: 'Fotos'),
            Tab(icon: Icon(Icons.link, size: 18), text: 'Contacto'),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Formulario'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TabInfo(
            descCtrl: _descCtrl,
            emailCtrl: _emailCtrl,
            servicios: _servicios,
            caracteristicas: _caracteristicas,
            nivelPrecio: _nivelPrecio,
            duracion: _duracion,
            onNivelPrecio: (v) => setState(() => _nivelPrecio = v),
            onDuracion: (v) => setState(() => _duracion = v),
            onAddServicio: _agregarServicio,
            onRemoveServicio: (i) => setState(() => _servicios.removeAt(i)),
            onAddCaracteristica: _agregarCaracteristica,
            onRemoveCaracteristica: (c) => setState(() => _caracteristicas.remove(c)),
          ),
          _TabHorarios(
            horarios: _horarios,
            dias: _dias,
            onChanged: (idx, h) => setState(() => _horarios[idx] = h),
          ),
          _TabFotos(
            fotos: _fotos,
            negocioId: _negocioId,
            onAdd: (url) => setState(() => _fotos.add(url)),
            onRemove: (i) => setState(() => _fotos.removeAt(i)),
          ),
          _TabContacto(
            igCtrl: _igCtrl, fbCtrl: _fbCtrl, waCtrl: _waCtrl,
            webCtrl: _webCtrl, tycCtrl: _tycCtrl,
          ),
          _TabFormulario(
            campos: _campos,
            onAdd: (c) => setState(() => _campos.add(c)),
            onEdit: (i, c) => setState(() => _campos[i] = c),
            onRemove: (i) => setState(() => _campos.removeAt(i)),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarServicio() async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoTexto(titulo: 'Servicio destacado', ctrl: ctrl, hint: 'Ej: Corte y color'),
    );
    if (r != null && r.isNotEmpty) setState(() => _servicios.add(r));
  }

  Future<void> _agregarCaracteristica() async {
    const opciones = ['WiFi Gratis', 'Parking', 'Terraza', 'A/C', 'Accesible', 'Pet-Friendly', 'Reserva Online', 'Pago con Tarjeta'];
    final r = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoOpciones(titulo: 'Característica', opciones: opciones),
    );
    if (r != null && !_caracteristicas.contains(r)) setState(() => _caracteristicas.add(r));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1: INFORMACIÓN
// ═══════════════════════════════════════════════════════════════════════════
class _TabInfo extends StatelessWidget {
  final TextEditingController descCtrl;
  final TextEditingController emailCtrl;
  final List<String> servicios;
  final List<String> caracteristicas;
  final String nivelPrecio;
  final int duracion;
  final ValueChanged<String> onNivelPrecio;
  final ValueChanged<int> onDuracion;
  final VoidCallback onAddServicio;
  final ValueChanged<int> onRemoveServicio;
  final VoidCallback onAddCaracteristica;
  final ValueChanged<String> onRemoveCaracteristica;

  const _TabInfo({
    required this.descCtrl, required this.emailCtrl,
    required this.servicios, required this.caracteristicas,
    required this.nivelPrecio, required this.duracion,
    required this.onNivelPrecio, required this.onDuracion,
    required this.onAddServicio, required this.onRemoveServicio,
    required this.onAddCaracteristica, required this.onRemoveCaracteristica,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Titulo('📝 Descripción Detallada'),
        _Card(child: TextField(
          controller: descCtrl, maxLines: 6, maxLength: 600,
          style: const TextStyle(color: _kTexto, fontSize: 14),
          decoration: _inputDec('Describe tu negocio en detalle para los clientes...'),
        )),
        const SizedBox(height: 20),
        _Titulo('📧 Email de Notificaciones'),
        _Card(child: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: _kTexto),
          decoration: _inputDec('reservas@tunegocio.com')
            .copyWith(prefixIcon: const Icon(Icons.email, color: _kAccent),
              helperText: 'A este correo llegarán las notificaciones de reservas',
              helperStyle: const TextStyle(color: _kMuted, fontSize: 11)),
        )),
        const SizedBox(height: 20),
        _Titulo('⭐ Servicios Destacados'),
        _Card(child: Column(children: [
          ...servicios.asMap().entries.map((e) => ListTile(
            dense: true,
            leading: const Icon(Icons.star_rounded, color: Colors.amber),
            title: Text(e.value, style: const TextStyle(color: _kTexto, fontSize: 14)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: _kAccentRosa, size: 20),
              onPressed: () => onRemoveServicio(e.key),
            ),
          )),
          TextButton.icon(onPressed: onAddServicio,
            icon: const Icon(Icons.add_circle_outline, color: _kAccent),
            label: const Text('Agregar servicio', style: TextStyle(color: _kAccent))),
        ])),
        const SizedBox(height: 20),
        _Titulo('✨ Características'),
        _Card(child: Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ...caracteristicas.map((c) => Chip(
              label: Text(c, style: const TextStyle(color: _kTexto, fontSize: 12)),
              backgroundColor: _kCard,
              side: const BorderSide(color: _kAccent, width: 0.5),
              deleteIconColor: _kAccentRosa,
              onDeleted: () => onRemoveCaracteristica(c),
            )),
            ActionChip(
              avatar: const Icon(Icons.add, color: _kAccent, size: 16),
              label: const Text('Agregar', style: TextStyle(color: _kAccent, fontSize: 12)),
              backgroundColor: _kCard,
              side: const BorderSide(color: _kBorde),
              onPressed: onAddCaracteristica,
            ),
          ],
        )),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Titulo('💰 Nivel de Precio'),
            _Card(child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '€', label: Text('€', style: TextStyle(color: _kTexto))),
                ButtonSegment(value: '€€', label: Text('€€', style: TextStyle(color: _kTexto))),
                ButtonSegment(value: '€€€', label: Text('€€€', style: TextStyle(color: _kTexto))),
              ],
              selected: {nivelPrecio},
              onSelectionChanged: (v) => onNivelPrecio(v.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((s) =>
                    s.contains(WidgetState.selected) ? _kAccent : _kCard),
              ),
            )),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Titulo('⏱️ Duración media'),
            _Card(child: Column(children: [
              Slider(
                value: duracion.toDouble(), min: 15, max: 180, divisions: 11,
                activeColor: _kAccent,
                onChanged: (v) => onDuracion(v.toInt()),
              ),
              Text('$duracion min', style: const TextStyle(color: _kAccent, fontWeight: FontWeight.bold)),
            ])),
          ])),
        ]),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2: HORARIOS
// ═══════════════════════════════════════════════════════════════════════════
class _TabHorarios extends StatelessWidget {
  final Map<int, HorarioDia> horarios;
  final List<String> dias;
  final void Function(int idx, HorarioDia h) onChanged;

  const _TabHorarios({required this.horarios, required this.dias, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⏰ Horario de Atención',
                style: TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Los clientes verán estos horarios en tu perfil',
                style: TextStyle(color: _kMuted, fontSize: 12)),
            const Divider(color: _kBorde, height: 24),
            ...List.generate(7, (i) => _FilaDia(
              dia: dias[i],
              horario: horarios[i] ?? HorarioDia(),
              conDivider: i < 6,
              onTogle: (v) => onChanged(i, HorarioDia(
                abierto: v,
                horaApertura: horarios[i]?.horaApertura ?? '09:00',
                horaCierre: horarios[i]?.horaCierre ?? '20:00',
              )),
              onTapApertura: () async {
                final t = await _pickTime(context, horarios[i]?.horaApertura ?? '09:00');
                if (t != null) {
                  final h = horarios[i]!;
                  onChanged(i, HorarioDia(abierto: h.abierto, horaApertura: t, horaCierre: h.horaCierre));
                }
              },
              onTapCierre: () async {
                final t = await _pickTime(context, horarios[i]?.horaCierre ?? '20:00');
                if (t != null) {
                  final h = horarios[i]!;
                  onChanged(i, HorarioDia(abierto: h.abierto, horaApertura: h.horaApertura, horaCierre: t));
                }
              },
            )),
          ],
        )),
      ],
    );
  }

  Future<String?> _pickTime(BuildContext context, String horaActual) async {
    final parts = horaActual.split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }
}

class _FilaDia extends StatelessWidget {
  final String dia;
  final HorarioDia horario;
  final bool conDivider;
  final ValueChanged<bool> onTogle;
  final VoidCallback onTapApertura;
  final VoidCallback onTapCierre;

  const _FilaDia({required this.dia, required this.horario, required this.conDivider,
    required this.onTogle, required this.onTapApertura, required this.onTapCierre});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        SizedBox(width: 88, child: Text(dia, style: const TextStyle(color: _kTexto, fontWeight: FontWeight.w500, fontSize: 13))),
        Switch(value: horario.abierto, onChanged: onTogle, activeColor: _kAccent, inactiveThumbColor: _kMuted),
        if (horario.abierto) ...[
          Expanded(child: Row(children: [
            Expanded(child: _HoraBtn(hora: horario.horaApertura ?? '09:00', onTap: onTapApertura)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('—', style: TextStyle(color: _kMuted))),
            Expanded(child: _HoraBtn(hora: horario.horaCierre ?? '20:00', onTap: onTapCierre)),
          ])),
        ] else
          const Text('Cerrado', style: TextStyle(color: _kMuted, fontSize: 12)),
      ]),
      if (conDivider) const Divider(color: _kBorde, height: 16),
    ]);
  }
}

class _HoraBtn extends StatelessWidget {
  final String hora;
  final VoidCallback onTap;
  const _HoraBtn({required this.hora, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: _kPrimario, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorde)),
        child: Text(hora, textAlign: TextAlign.center, style: const TextStyle(color: _kTexto, fontSize: 13)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3: FOTOS
// ═══════════════════════════════════════════════════════════════════════════
class _TabFotos extends StatefulWidget {
  final List<String> fotos;
  final String? negocioId;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;

  const _TabFotos({required this.fotos, required this.negocioId, required this.onAdd, required this.onRemove});

  @override
  State<_TabFotos> createState() => _TabFotosState();
}

class _TabFotosState extends State<_TabFotos> {
  bool _subiendo = false;

  Future<void> _agregar() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1080, imageQuality: 85);
    if (img == null || widget.negocioId == null) return;

    setState(() => _subiendo = true);
    try {
      final ref = FirebaseStorage.instance
          .ref('negocios_publicos/${widget.negocioId}/galeria/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(img.path));
      final url = await ref.getDownloadURL();
      widget.onAdd(url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('📸 Galería de Fotos', style: TextStyle(color: _kTexto, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Las fotos se muestran al cliente al ver tu negocio', style: TextStyle(color: _kMuted, fontSize: 12)),
        const SizedBox(height: 16),
        if (_subiendo) const LinearProgressIndicator(color: _kAccent),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: widget.fotos.length + 1,
          itemBuilder: (_, i) {
            if (i == widget.fotos.length) {
              return GestureDetector(
                onTap: _agregar,
                child: Container(
                  decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorde, style: BorderStyle.solid, width: 1.5)),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 36, color: _kAccent),
                    SizedBox(height: 4),
                    Text('Agregar', style: TextStyle(color: _kMuted, fontSize: 11)),
                  ]),
                ),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(children: [
                Positioned.fill(child: Image.network(widget.fotos[i], fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: _kCard))),
                Positioned(top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => widget.onRemove(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 4: CONTACTO
// ═══════════════════════════════════════════════════════════════════════════
class _TabContacto extends StatelessWidget {
  final TextEditingController igCtrl, fbCtrl, waCtrl, webCtrl, tycCtrl;

  const _TabContacto({required this.igCtrl, required this.fbCtrl, required this.waCtrl,
    required this.webCtrl, required this.tycCtrl});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Campo('Instagram', Icons.camera_alt_outlined, igCtrl, '@tu_negocio'),
        const SizedBox(height: 12),
        _Campo('Facebook', Icons.facebook, fbCtrl, 'https://facebook.com/tu-negocio'),
        const SizedBox(height: 12),
        _Campo('WhatsApp', Icons.phone, waCtrl, '+34 612 345 678'),
        const SizedBox(height: 12),
        _Campo('Sitio Web', Icons.language, webCtrl, 'https://tu-negocio.com'),
        const SizedBox(height: 20),
        _Titulo('📜 Términos y Condiciones'),
        _Card(child: TextField(
          controller: tycCtrl, maxLines: 8,
          style: const TextStyle(color: _kTexto, fontSize: 13),
          decoration: _inputDec('Escribe tus términos y condiciones de reserva...'),
        )),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController ctrl;
  final String hint;
  const _Campo(this.label, this.icon, this.ctrl, this.hint);

  @override
  Widget build(BuildContext context) {
    return _Card(child: TextField(
      controller: ctrl,
      style: const TextStyle(color: _kTexto),
      decoration: _inputDec(hint).copyWith(
        labelText: label,
        labelStyle: const TextStyle(color: _kMuted),
        prefixIcon: Icon(icon, color: _kAccentRosa),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 5: FORMULARIO PERSONALIZADO
// ═══════════════════════════════════════════════════════════════════════════
class _TabFormulario extends StatelessWidget {
  final List<CampoPersonalizado> campos;
  final ValueChanged<CampoPersonalizado> onAdd;
  final void Function(int, CampoPersonalizado) onEdit;
  final ValueChanged<int> onRemove;

  const _TabFormulario({required this.campos, required this.onAdd, required this.onEdit, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('📝 Campos del Formulario de Reserva',
            style: TextStyle(color: _kTexto, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Estos campos aparecerán cuando el cliente haga una reserva',
            style: TextStyle(color: _kMuted, fontSize: 12)),
        const SizedBox(height: 16),
        ...campos.asMap().entries.map((e) {
          final c = e.value;
          return _Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: _kPrimario,
                child: Icon(_iconTipo(c.tipo), color: _kAccent, size: 18),
              ),
              title: Text(c.label, style: const TextStyle(color: _kTexto, fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('${c.tipo} · ${c.obligatorio ? "obligatorio" : "opcional"}',
                  style: const TextStyle(color: _kMuted, fontSize: 11)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: _kAccent, size: 20),
                  onPressed: () async {
                    final r = await showDialog<CampoPersonalizado>(
                      context: context,
                      builder: (_) => _DialogoCampoPersonalizado(campo: c),
                    );
                    if (r != null) onEdit(e.key, r);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: _kAccentRosa, size: 20),
                  onPressed: () => onRemove(e.key),
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () async {
            final r = await showDialog<CampoPersonalizado>(
              context: context,
              builder: (_) => const _DialogoCampoPersonalizado(),
            );
            if (r != null) onAdd(r);
          },
          icon: const Icon(Icons.add),
          label: const Text('Agregar Campo Personalizado'),
          style: FilledButton.styleFrom(
            backgroundColor: _kAccentRosa, foregroundColor: _kTexto,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  IconData _iconTipo(String tipo) {
    switch (tipo) {
      case 'numero': return Icons.numbers;
      case 'email': return Icons.email_outlined;
      case 'telefono': return Icons.phone_outlined;
      case 'selector': return Icons.arrow_drop_down_circle_outlined;
      case 'checkbox': return Icons.check_box_outlined;
      default: return Icons.text_fields;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO: Campo Personalizado
// ═══════════════════════════════════════════════════════════════════════════
class _DialogoCampoPersonalizado extends StatefulWidget {
  final CampoPersonalizado? campo;
  const _DialogoCampoPersonalizado({this.campo});

  @override
  State<_DialogoCampoPersonalizado> createState() => _DialogoCampoPersonalizadoState();
}

class _DialogoCampoPersonalizadoState extends State<_DialogoCampoPersonalizado> {
  final _labelCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  String _tipo = 'texto';
  bool _obligatorio = false;
  List<String> _opciones = [];

  @override
  void initState() {
    super.initState();
    if (widget.campo != null) {
      _labelCtrl.text = widget.campo!.label;
      _placeCtrl.text = widget.campo!.placeholder ?? '';
      _tipo = widget.campo!.tipo;
      _obligatorio = widget.campo!.obligatorio;
      _opciones = List.from(widget.campo!.opciones ?? []);
    }
  }

  @override
  void dispose() { _labelCtrl.dispose(); _placeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2139),
      title: Text(widget.campo == null ? 'Nuevo Campo' : 'Editar Campo',
          style: const TextStyle(color: _kTexto)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _labelCtrl,
            style: const TextStyle(color: _kTexto),
            decoration: _inputDec('Ej: Número de personas').copyWith(labelText: 'Etiqueta *',
                labelStyle: const TextStyle(color: _kMuted)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _tipo,
            dropdownColor: const Color(0xFF1E2139),
            style: const TextStyle(color: _kTexto),
            decoration: const InputDecoration(labelText: 'Tipo', labelStyle: TextStyle(color: _kMuted),
                filled: true, fillColor: Color(0xFF0A0F23),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none)),
            items: const [
              DropdownMenuItem(value: 'texto', child: Text('Texto libre')),
              DropdownMenuItem(value: 'numero', child: Text('Número')),
              DropdownMenuItem(value: 'email', child: Text('Email')),
              DropdownMenuItem(value: 'telefono', child: Text('Teléfono')),
              DropdownMenuItem(value: 'selector', child: Text('Selector (opciones)')),
              DropdownMenuItem(value: 'checkbox', child: Text('Sí / No')),
            ],
            onChanged: (v) => setState(() => _tipo = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _placeCtrl,
            style: const TextStyle(color: _kTexto),
            decoration: _inputDec('Texto de ayuda (opcional)').copyWith(
                labelText: 'Placeholder', labelStyle: const TextStyle(color: _kMuted)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _obligatorio, activeColor: _kAccent,
            title: const Text('Campo obligatorio', style: TextStyle(color: _kTexto, fontSize: 13)),
            onChanged: (v) => setState(() => _obligatorio = v!),
          ),
          if (_tipo == 'selector') ...[
            const Divider(color: _kBorde),
            const Text('Opciones:', style: TextStyle(color: _kMuted, fontWeight: FontWeight.bold)),
            ..._opciones.map((o) => ListTile(dense: true,
              title: Text(o, style: const TextStyle(color: _kTexto, fontSize: 13)),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: _kAccentRosa, size: 18),
                onPressed: () => setState(() => _opciones.remove(o)),
              ),
            )),
            TextButton.icon(
              onPressed: () async {
                final c = TextEditingController();
                final r = await showDialog<String>(context: context,
                    builder: (_) => _DialogoTexto(titulo: 'Nueva opción', ctrl: c, hint: 'Ej: Mañana'));
                if (r != null && r.isNotEmpty) setState(() => _opciones.add(r));
              },
              icon: const Icon(Icons.add_circle_outline, color: _kAccent, size: 16),
              label: const Text('Agregar opción', style: TextStyle(color: _kAccent, fontSize: 13)),
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
        FilledButton(
          onPressed: () {
            if (_labelCtrl.text.isEmpty) return;
            Navigator.pop(context, CampoPersonalizado(
              id: widget.campo?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              label: _labelCtrl.text.trim(),
              tipo: _tipo, obligatorio: _obligatorio,
              opciones: _tipo == 'selector' ? _opciones : null,
              placeholder: _placeCtrl.text.isEmpty ? null : _placeCtrl.text.trim(),
            ));
          },
          style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kPrimario),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════════════

class _Titulo extends StatelessWidget {
  final String text;
  const _Titulo(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: _kAccent, fontSize: 14, fontWeight: FontWeight.w700)),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  const _Card({required this.child, this.margin});
  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorde, width: 0.5)),
    child: child,
  );
}

InputDecoration _inputDec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFF6B6E82), fontSize: 13),
  filled: true, fillColor: _kPrimario,
  border: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide.none,
  ),
);

class _DialogoTexto extends StatelessWidget {
  final String titulo;
  final TextEditingController ctrl;
  final String hint;
  const _DialogoTexto({required this.titulo, required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2139),
      title: Text(titulo, style: const TextStyle(color: _kTexto)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: const TextStyle(color: _kTexto),
        decoration: _inputDec(hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text),
          style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kPrimario),
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

class _DialogoOpciones extends StatelessWidget {
  final String titulo;
  final List<String> opciones;
  const _DialogoOpciones({required this.titulo, required this.opciones});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      backgroundColor: const Color(0xFF1E2139),
      title: Text(titulo, style: const TextStyle(color: _kTexto)),
      children: opciones.map((o) => SimpleDialogOption(
        onPressed: () => Navigator.pop(context, o),
        child: Text(o, style: const TextStyle(color: _kTexto)),
      )).toList(),
    );
  }
}

