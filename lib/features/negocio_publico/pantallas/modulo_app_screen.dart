import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:csv/csv.dart';
import 'dart:async';
import '../../../models/negocio_publico_model.dart';
import '../../../models/flash_slot_model.dart';
import '../../../services/flash_slot_service.dart';
import '../../flash_slots/pantallas/pantalla_crear_flash_slot.dart';
import 'terminos_condiciones_screen.dart';
import 'resenas_fluix_screen.dart';

const _kBg     = Color(0xFF0A0F23);
const _kCard   = Color(0xFF1E2139);
const _kCard2  = Color(0xFF252A45);
const _kAccent = Color(0xFF00FFC8);
const _kRosa   = Color(0xFFFF3296);
const _kOro    = Color(0xFFFFB830);
const _kTexto  = Colors.white;
const _kMuted  = Color(0xFFB0B3C1);
const _kBorde  = Color(0xFF2A2E45);

class ModuloAppScreen extends StatefulWidget {
  final String empresaId;
  const ModuloAppScreen({super.key, required this.empresaId});
  @override
  State<ModuloAppScreen> createState() => _ModuloAppScreenState();
}

class _ModuloAppScreenState extends State<ModuloAppScreen> {
  bool _cargando = true;
  bool _guardando = false;
  bool _subiendo = false;
  String? _negocioId;
  String _nombreNegocio = '';
  int _tabIndex = 0;

  final _nombreCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _igCtrl     = TextEditingController();
  final _fbCtrl     = TextEditingController();
  final _waCtrl     = TextEditingController();
  final _webCtrl    = TextEditingController();

  String _categoria     = 'general';
  List<String> _fotos   = [];
  Map<int, HorarioDia> _horarios = {};
  List<String> _servicios = [];
  List<String> _caracteristicas = [];
  List<CampoPersonalizado> _campos = [];
  List<ResenaFluix> _resenas = [];
  String _nivelPrecio = '€€';
  int _duracion       = 60;
  bool _activo        = true;

  static const _categorias = [
    ('general','🏢','General'), ('restaurantes','🍽️','Restaurante / Bar'),
    ('peluquerias','✂️','Peluquería'), ('esteticas','💅','Estética / Beauty'),
    ('clinicas','🏥','Clínica / Salud'), ('gimnasios','🏋️','Gimnasio / Deporte'),
    ('hoteles','🏨','Hotel / Alojamiento'), ('tiendas','🛍️','Tienda / Comercio'),
  ];

  static const _dias = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];

  static const _caracteristicasGrupos = <String, List<String>>{
    '📍 Acceso': ['Accesible silla ruedas','Parking propio','Parking cercano','Transporte público cercano','Entrada sin escalones'],
    '📅 Reservas': ['Reserva Online','Cita previa obligatoria','Sin cita previa','Presupuesto gratuito','Servicio a domicilio','Recogida en tienda','Envío a domicilio'],
    '💳 Pagos': ['Pago con Tarjeta','Efectivo','Bizum','PayPal','Financiación disponible','Factura disponible'],
    '🏠 Instalaciones': ['WiFi Gratis','A/C','Terraza','Sala de espera','TV en sala espera','Cafetería','Vestuario','Duchas','Taquillas','Zona privada'],
    '👥 Ambiente': ['Apto familias','Zona infantil','Solo adultos','Solo mujeres','Mixto','Ambiente tranquilo','Ambiente animado','Música en vivo','Pet-Friendly'],
    '🌱 Sostenibilidad': ['Productos ecológicos','Cruelty-free','Plástico reducido','Productos locales','Certificado sostenible'],
    '⭐ Servicios': ['Atención personalizada','Profesionales certificados','Productos de marca','Idiomas: Inglés','Idiomas: Francés','Idiomas: Alemán','Idiomas: Árabe','Abierto festivos','Horario nocturno'],
  };

  @override
  void initState() {
    super.initState();
    _initHorarios();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _descCtrl, _emailCtrl, _igCtrl, _fbCtrl, _waCtrl, _webCtrl]) c.dispose();
    super.dispose();
  }

  void _initHorarios() {
    for (int i = 0; i < 7; i++) {
      _horarios[i] = HorarioDia(abierto: i < 5, horaApertura: '09:00', horaCierre: '20:00');
    }
  }

  Future<void> _cargar() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('negocios_publicos').where('empresaIdVinculada', isEqualTo: widget.empresaId).limit(1).get();
      if (snap.docs.isEmpty) {
        final emp = await FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId).get();
        if (mounted && emp.data() != null) {
          _nombreCtrl.text = emp.data()!['nombre'] ?? '';
          _emailCtrl.text  = emp.data()!['email'] ?? '';
          _nombreNegocio   = _nombreCtrl.text;
        }
      } else {
        final doc = snap.docs.first;
        final n   = NegocioPublico.fromJson(doc.id, doc.data());
        if (mounted) setState(() {
          _negocioId       = doc.id;
          _nombreNegocio   = n.nombre;
          _nombreCtrl.text = n.nombre;
          _descCtrl.text   = n.descripcionDetallada ?? '';
          _emailCtrl.text  = n.emailNotificaciones ?? '';
          _igCtrl.text     = n.instagram ?? '';
          _fbCtrl.text     = n.facebook ?? '';
          _waCtrl.text     = n.whatsapp ?? '';
          _webCtrl.text    = n.website ?? '';
          _fotos           = n.fotosGaleria ?? [];
          _categoria       = n.categoria.name;
          _servicios       = n.serviciosDestacados ?? [];
          _caracteristicas = n.caracteristicas ?? [];
          _campos          = n.camposPersonalizados ?? [];
          _resenas         = n.resenasFluix ?? [];
          _nivelPrecio     = n.nivelPrecio ?? '€€';
          _duracion        = n.duracionPromedio ?? 60;
          _activo          = n.activo;
          if (n.horarios != null) _horarios = Map.from(n.horarios!);
        });
      }
    } catch (e) {
      _snack('Error cargando: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) { _snack('El nombre del negocio es obligatorio', error: true); return; }
    setState(() => _guardando = true);
    try {
      final datos = {
        'nombre': nombre, 'categoria': _categoria, 'activo': _activo,
        'descripcionDetallada': _descCtrl.text.trim(),
        'emailNotificaciones': _emailCtrl.text.trim(),
        'fotosGaleria': _fotos,
        'horarios': _horarios.map((k, v) => MapEntry(k.toString(), v.toJson())),
        'serviciosDestacados': _servicios,
        'caracteristicas': _caracteristicas,
        'camposPersonalizados': _campos.map((c) => c.toJson()).toList(),
        'resenasFluix': _resenas.map((r) => r.toJson()).toList(),
        'nivelPrecio': _nivelPrecio, 'duracionPromedio': _duracion,
        'instagram': _igCtrl.text.trim(), 'facebook': _fbCtrl.text.trim(),
        'whatsapp': _waCtrl.text.trim(), 'website': _webCtrl.text.trim(),
      };
      if (_negocioId == null) {
        datos['empresaIdVinculada'] = widget.empresaId;
        datos['creado_en'] = FieldValue.serverTimestamp();
        final ref = await FirebaseFirestore.instance.collection('negocios_publicos').add(datos);
        if (mounted) setState(() { _negocioId = ref.id; _nombreNegocio = nombre; });
        _snack('✅ Perfil público activado y publicado');
      } else {
        await FirebaseFirestore.instance.collection('negocios_publicos').doc(_negocioId).update(datos);
        if (mounted) setState(() => _nombreNegocio = nombre);
        _snack('✅ Cambios guardados y publicados en tiempo real');
      }
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _subirFoto() async {
    if (_subiendo || _guardando) return;
    Uint8List? bytes; String ext = 'jpg';
    try {
      final esDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
      if (esDesktop) {
        final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true, allowMultiple: false);
        if (result == null || result.files.isEmpty) return;
        bytes = result.files.first.bytes; ext = result.files.first.extension ?? 'jpg';
      } else {
        final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1080, imageQuality: 85);
        if (img == null) return;
        bytes = await img.readAsBytes(); ext = img.path.split('.').last;
      }
      if (bytes == null) return;
      if (_negocioId == null) { await _guardar(); if (_negocioId == null) return; }
      setState(() => _subiendo = true);
      final ref = FirebaseStorage.instance.ref('negocios_publicos/$_negocioId/galeria/${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: ext.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg'));
      final url = await ref.getDownloadURL();
      setState(() => _fotos.add(url));
      _snack('📸 Foto subida correctamente');
    } catch (e) {
      _snack('Error al subir foto: $e', error: true);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFFF2850) : _kAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _abrirTerminos() {
    if (_negocioId == null) { _snack('Guarda primero el perfil', error: true); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => TerminosCondicionesScreen(negocioId: _negocioId!, nombreNegocio: _nombreNegocio)));
  }

  Future<void> _abrirResenas() async {
    if (_negocioId == null) { _snack('Guarda primero el perfil', error: true); return; }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ResenasFluixScreen(
      negocioId: _negocioId!, empresaId: widget.empresaId, nombreNegocio: _nombreNegocio,
    )));
    _cargar();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator(color: _kAccent));
    return Container(
      color: _kBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildTabBar(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(key: ValueKey(_tabIndex), child: _tabContent()),
          ),
          const SizedBox(height: 24),
          _buildBotonGuardar(),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }

  Widget _tabContent() {
    switch (_tabIndex) {
      case 1:  return _buildTabServicios();
      case 2:  return _buildTabHorarios();
      case 3:  return _buildTabConfig();
      case 4:  return _buildTabResenas();
      default: return _buildTabPerfil();
    }
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = [
      (Icons.storefront_outlined,  'Perfil'),
      (Icons.content_cut_rounded,  'Servicios'),
      (Icons.schedule_rounded,     'Horarios'),
      (Icons.tune_rounded,         'Config'),
      (Icons.star_rounded,         'Reseñas'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorde, width: 0.5),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: List.generate(tabs.length, (i) {
        final sel = _tabIndex == i;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _tabIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: sel ? _kAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(tabs[i].$1, size: 15, color: sel ? _kBg : _kMuted),
              const SizedBox(width: 5),
              Text(tabs[i].$2, style: TextStyle(
                color: sel ? _kBg : _kMuted,
                fontSize: 12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              )),
            ]),
          ),
        ));
      })),
    );
  }

  // ── Tab content groups ─────────────────────────────────────────────────────

  Widget _buildTabPerfil() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _buildFotos()),
          const SizedBox(width: 16),
          Expanded(child: _buildInfoBasica()),
        ]),
      ),
      const SizedBox(height: 16),
      _buildContacto(),
    ]);
  }

  Widget _buildTabServicios() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildServiciosApp(),
      const SizedBox(height: 16),
      _buildFlashSlots(),
    ]);
  }

  Widget _buildTabHorarios() => _buildHorarios();

  Widget _buildTabConfig() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildCaracteristicas(),
      const SizedBox(height: 16),
      _buildFormulario(),
      const SizedBox(height: 16),
      _buildTerminos(),
    ]);
  }

  Widget _buildTabResenas() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('valoraciones')
          .where('origen', isEqualTo: 'fluix')
          .snapshots(),
      builder: (ctx, snap) {
        // Sort client-side mientras el índice compuesto se construye en Firebase
        final raw = snap.data?.docs ?? [];
        final docs = [...raw]..sort((a, b) {
            final ta = (a.data() as Map)['fecha'] as Timestamp?;
            final tb = (b.data() as Map)['fecha'] as Timestamp?;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        final total = docs.length;
        final media = total == 0 ? 0.0
            : docs.map((d) => ((d.data() as Map<String, dynamic>)['estrellas'] as num?)?.toDouble() ?? 0)
                  .reduce((a, b) => a + b) / total;

        return _Seccion(
          icono: Icons.star_rounded,
          titulo: 'Reseñas Fluix',
          subtitulo: 'Reseñas de clientes visibles en tu perfil público',
          accent: _kOro,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (snap.connectionState == ConnectionState.waiting && total == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: _kOro, strokeWidth: 2)),
              )
            else if (total > 0) ...[
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: _kBg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kOro.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Text(media.toStringAsFixed(1),
                      style: const TextStyle(color: _kOro, fontSize: 36, fontWeight: FontWeight.bold, height: 1)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: List.generate(5, (i) => Icon(
                      i < media.round() ? Icons.star_rounded : Icons.star_border_rounded,
                      color: _kOro, size: 16,
                    ))),
                    const SizedBox(height: 4),
                    Text('$total reseña${total == 1 ? '' : 's'}',
                        style: const TextStyle(color: _kMuted, fontSize: 12)),
                  ]),
                ]),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.star_border_rounded, color: _kOro, size: 40),
                  SizedBox(height: 10),
                  Text('Aún no tienes reseñas',
                      style: TextStyle(color: _kTexto, fontSize: 14, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Pulsa "Ver y añadir reseñas" para empezar',
                      style: TextStyle(color: _kMuted, fontSize: 12), textAlign: TextAlign.center),
                ]),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _abrirResenas,
                icon: Icon(total > 0 ? Icons.reply_rounded : Icons.add_rounded, color: _kOro, size: 18),
                label: Text(
                  total > 0 ? 'Ver y responder reseñas ($total)' : 'Añadir primera reseña',
                  style: const TextStyle(color: _kOro, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kOro.withValues(alpha: 0.4), width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEADER con preview de Explorar
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.phone_android, color: _kAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mi App Pública', style: TextStyle(color: _kTexto, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              _negocioId == null
                  ? 'Rellena los datos y pulsa Activar para publicar'
                  : '✅ Publicado · cambios en tiempo real',
              style: const TextStyle(color: _kMuted, fontSize: 12),
            ),
          ])),
          const SizedBox(width: 12),
          if (_negocioId != null) ...[
            Text(_activo ? 'Visible' : 'Oculto',
                style: TextStyle(color: _activo ? _kAccent : _kMuted, fontSize: 11)),
            Switch(
              value: _activo, onChanged: (v) => setState(() => _activo = v),
              activeColor: _kAccent, activeTrackColor: _kAccent.withValues(alpha: 0.25),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
          ],
          FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _kBg))
                : const Icon(Icons.save_rounded, size: 17),
            label: Text(_guardando ? 'Guardando...' : (_negocioId == null ? 'Activar' : 'Guardar')),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent, foregroundColor: _kBg,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ]),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECCIONES INDIVIDUALES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildInfoBasica() {
    return _Seccion(icono: Icons.storefront_outlined, titulo: 'Información Básica',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Label('Nombre del negocio *'),
        _Input(ctrl: _nombreCtrl, hint: 'Ej: Peluquería Marina'),
        const SizedBox(height: 14),
        const _Label('Descripción para tus clientes'),
        TextField(controller: _descCtrl, maxLines: 4, maxLength: 3000,
            style: const TextStyle(color: _kTexto, fontSize: 13), decoration: _dec('Cuéntales qué ofreces...')),
        const SizedBox(height: 14),
        const _Label('Categoría'),
        Wrap(spacing: 8, runSpacing: 8, children: _categorias.map((cat) {
          final sel = _categoria == cat.$1;
          return ChoiceChip(
            label: Text('${cat.$2} ${cat.$3}', style: TextStyle(color: sel ? _kBg : _kMuted, fontSize: 12)),
            selected: sel, onSelected: (_) => setState(() => _categoria = cat.$1),
            selectedColor: _kAccent, backgroundColor: _kBg,
            side: BorderSide(color: sel ? _kAccent : _kBorde, width: sel ? 1.5 : 0.5),
          );
        }).toList()),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Nivel de Precio'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '€',   label: Text('€',   style: TextStyle(color: _kTexto))),
                ButtonSegment(value: '€€',  label: Text('€€',  style: TextStyle(color: _kTexto))),
                ButtonSegment(value: '€€€', label: Text('€€€', style: TextStyle(color: _kTexto))),
              ],
              selected: {_nivelPrecio},
              onSelectionChanged: (v) => setState(() => _nivelPrecio = v.first),
              style: ButtonStyle(backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? _kAccent : _kCard2)),
            ),
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Duración media'),
            Row(children: [
              Expanded(child: Slider(
                  value: _duracion.toDouble(), min: 15, max: 180, divisions: 11,
                  activeColor: _kAccent, inactiveColor: _kBorde,
                  onChanged: (v) => setState(() => _duracion = v.toInt()))),
              Text('$_duracion min', style: const TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          ])),
        ]),
      ]));
  }

  Widget _buildHorarios() {
    return _Seccion(icono: Icons.schedule_rounded, titulo: 'Horario de Atención',
      subtitulo: 'Los clientes ven estos horarios en tu perfil',
      child: Column(children: List.generate(7, (i) {
        final h = _horarios[i] ?? HorarioDia(abierto: false);
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
          SizedBox(width: 86, child: Text(_dias[i], style: const TextStyle(color: _kTexto, fontSize: 13))),
          Switch(value: h.abierto, activeColor: _kAccent, activeTrackColor: _kAccent.withValues(alpha: 0.25),
              inactiveTrackColor: _kBg,
              onChanged: (v) => setState(() => _horarios[i] = HorarioDia(
                  abierto: v, horaApertura: h.horaApertura ?? '09:00', horaCierre: h.horaCierre ?? '20:00'))),
          if (h.abierto) ...[
            Expanded(child: _BotonHora(hora: h.horaApertura ?? '09:00', onTap: () async {
              final t = await _pickTime(context, h.horaApertura ?? '09:00');
              if (t != null) setState(() => _horarios[i] = HorarioDia(abierto: h.abierto, horaApertura: t, horaCierre: h.horaCierre));
            })),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('—', style: TextStyle(color: _kMuted))),
            Expanded(child: _BotonHora(hora: h.horaCierre ?? '20:00', onTap: () async {
              final t = await _pickTime(context, h.horaCierre ?? '20:00');
              if (t != null) setState(() => _horarios[i] = HorarioDia(abierto: h.abierto, horaApertura: h.horaApertura, horaCierre: t));
            })),
          ] else const Padding(padding: EdgeInsets.only(left: 4), child: Text('Cerrado', style: TextStyle(color: _kMuted, fontSize: 12))),
        ]));
      })),
    );
  }

  Future<String?> _pickTime(BuildContext ctx, String actual) async {
    final parts = actual.split(':');
    final t = await showTimePicker(context: ctx,
        initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
        builder: (ctx2, child) => Theme(data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _kAccent),
          timePickerTheme: TimePickerThemeData(backgroundColor: _kCard, hourMinuteColor: _kBg, dialBackgroundColor: _kBg),
        ), child: child!));
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildFotos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorde, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header igual que _Seccion
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.photo_library_outlined, color: _kAccent, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Galería de Fotos', style: TextStyle(color: _kTexto, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('La primera foto aparece como portada en Explorar', style: TextStyle(color: _kMuted, fontSize: 11)),
          ])),
        ]),
        const Divider(color: _kBorde, height: 22),
        if (_subiendo) const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: LinearProgressIndicator(color: _kAccent),
        ),
        // Área de fotos con scroll cuando hay muchas
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              ..._fotos.asMap().entries.map((e) => Stack(children: [
                Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: e.key == 0 ? Border.all(color: _kAccent, width: 2) : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(e.key == 0 ? 11 : 12),
                    child: Image.network(e.value, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: _kCard2, child: const Icon(Icons.broken_image, color: _kMuted))),
                  ),
                ),
                if (e.key == 0) Positioned(
                  bottom: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(4)),
                    child: const Text('portada', style: TextStyle(color: _kBg, fontSize: 8, fontWeight: FontWeight.w800)),
                  ),
                ),
                Positioned(top: 4, right: 4, child: GestureDetector(
                  onTap: () => setState(() => _fotos.removeAt(e.key)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                )),
              ])),
              GestureDetector(
                onTap: _subiendo ? null : _subirFoto,
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    color: _kCard2, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _subiendo ? _kBorde : _kAccent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 30, color: _subiendo ? _kMuted : _kAccent),
                    const SizedBox(height: 6),
                    Text(_subiendo ? 'Subiendo...' : 'Añadir foto',
                        style: TextStyle(color: _subiendo ? _kMuted : _kAccent, fontSize: 11)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        if (_fotos.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('${_fotos.length} foto${_fotos.length == 1 ? '' : 's'} · La primera es la portada en Explorar',
              style: const TextStyle(color: _kMuted, fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _buildContacto() {
    return _Seccion(icono: Icons.link_rounded, titulo: 'Contacto y Redes Sociales',
      subtitulo: 'Aparecen en el perfil público de tu negocio',
      child: Column(children: [
        _InputIcon(ctrl: _emailCtrl, icon: Icons.email_outlined,     label: 'Email notificaciones', hint: 'reservas@tunegocio.com'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _igCtrl,   icon: Icons.camera_alt_outlined, label: 'Instagram',            hint: '@tu_negocio'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _fbCtrl,   icon: Icons.facebook,            label: 'Facebook',             hint: 'https://facebook.com/tu-negocio'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _waCtrl,   icon: Icons.phone_outlined,      label: 'WhatsApp',             hint: '+34 612 345 678'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _webCtrl,  icon: Icons.language_outlined,   label: 'Sitio Web',            hint: 'https://tu-negocio.com'),
      ]));
  }

  // ── Servicios ──────────────────────────────────────────────────────────────

  Widget _buildServiciosApp() {
    if (_negocioId == null) {
      return _Seccion(
        icono: Icons.content_cut_rounded, titulo: 'Catálogo de Servicios',
        subtitulo: 'Guarda el perfil primero para gestionar servicios',
        child: const Padding(padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Activa tu perfil público primero',
                style: TextStyle(color: _kMuted, fontSize: 13)))),
      );
    }
    return _Seccion(
      icono: Icons.content_cut_rounded, titulo: 'Catálogo de Servicios',
      subtitulo: 'Los clientes los ven en la pestaña ⚡ Reservar al entrar en tu perfil',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas').doc(widget.empresaId).collection('servicios')
            .where('activo', isNotEqualTo: false).orderBy('activo').orderBy('nombre').snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2)));
          }
          final docs = snap.data?.docs ?? [];
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (docs.isEmpty)
              Container(padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.spa_outlined, color: _kMuted, size: 32),
                  const SizedBox(height: 8),
                  const Text('Sin servicios todavía', style: TextStyle(color: _kMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Añade servicios para que los clientes puedan reservar',
                      style: TextStyle(color: _kBorde, fontSize: 11), textAlign: TextAlign.center),
                ])))
            else
              ...docs.asMap().entries.map((e) => _buildServicioItem(e.value, e.key)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: () => _mostrarDialogoServicio(orden: docs.length),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Añadir servicio', style: TextStyle(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              )),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _importarServiciosCsv,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('CSV', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: OutlinedButton.styleFrom(foregroundColor: _kAccent,
                    side: const BorderSide(color: _kAccent, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14)),
              ),
            ]),
            if (docs.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
                child: Text('${docs.length} servicio${docs.length == 1 ? '' : 's'} · Los cambios se publican al instante',
                    style: const TextStyle(color: _kMuted, fontSize: 11))),
          ]);
        },
      ),
    );
  }

  Widget _buildServicioItem(QueryDocumentSnapshot doc, int idx) {
    final data     = doc.data() as Map<String, dynamic>;
    final nombre   = data['nombre'] as String? ?? '';
    final categoria = data['categoria'] as String? ?? '';
    final precio   = data['precio'] as num?;
    final precioD  = data['precio_desde'] as num?;
    final duracion = data['duracion'] as int?;
    final publico  = (data['publico'] as String? ?? '').toLowerCase();
    final activo   = data['activo'] as bool? ?? true;
    final precioTxt = precio != null
        ? '€${precio.toStringAsFixed(precio % 1 == 0 ? 0 : 2)}'
        : precioD != null ? 'Desde €${precioD.toStringAsFixed(precioD % 1 == 0 ? 0 : 2)}' : 'Consultar';
    final colorP = publico == 'femenino' || publico == 'mujer' ? _kRosa
        : publico == 'masculino' || publico == 'hombre' ? const Color(0xFF4A9EFF) : _kAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: activo ? _kBorde : _kBorde.withValues(alpha: 0.3), width: 0.5)),
      child: Row(children: [
        Container(width: 4, height: 68, decoration: BoxDecoration(color: activo ? colorP : _kBorde,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Opacity(opacity: activo ? 1.0 : 0.5,
            child: Container(width: 38, height: 38,
                decoration: BoxDecoration(color: colorP.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
                child: Icon(_iconCatServicio(categoria), size: 17, color: colorP)))),
        Expanded(child: Opacity(opacity: activo ? 1.0 : 0.5,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(nombre, style: const TextStyle(color: _kTexto, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              if (categoria.isNotEmpty)
                Container(margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: colorP.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorP.withValues(alpha: 0.3))),
                    child: Text(categoria, style: TextStyle(color: colorP, fontSize: 9, fontWeight: FontWeight.w700))),
              if (!activo)
                Container(margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFF2850).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Oculto', style: TextStyle(color: Color(0xFFFF2850), fontSize: 9))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text(precioTxt, style: TextStyle(color: colorP, fontSize: 13, fontWeight: FontWeight.w800)),
              if (duracion != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.access_time_rounded, size: 11, color: _kMuted),
                const SizedBox(width: 2),
                Text(duracion >= 60
                    ? '${duracion ~/ 60}h${duracion % 60 > 0 ? ' ${duracion % 60}m' : ''}'
                    : '${duracion}min',
                    style: const TextStyle(color: _kMuted, fontSize: 11)),
              ],
            ]),
          ])))),
        Column(mainAxisSize: MainAxisSize.min, children: [
          IconButton(onPressed: () => _mostrarDialogoServicio(doc: doc, orden: idx),
              icon: const Icon(Icons.edit_outlined, size: 17, color: _kAccent),
              padding: const EdgeInsets.all(6), constraints: const BoxConstraints()),
          IconButton(onPressed: () => _eliminarServicio(doc.id, nombre),
              icon: const Icon(Icons.delete_outline, size: 17, color: Color(0xFFFF2850)),
              padding: const EdgeInsets.all(6), constraints: const BoxConstraints()),
        ]),
        const SizedBox(width: 4),
      ]),
    );
  }

  // ── Flash Slots ────────────────────────────────────────────────────────────

  Widget _buildFlashSlots() {
    return _Seccion(icono: Icons.bolt_rounded, titulo: '⚡ Ofertas Flash',
      subtitulo: 'Huecos de última hora con descuento — aparecen en "Ahorra ahora" de la app',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_negocioId == null)
          Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Guarda el perfil primero para crear ofertas flash',
                  style: const TextStyle(color: _kMuted, fontSize: 13)))
        else ...[
          const SizedBox(height: 8),
          StreamBuilder<List<FlashSlotModel>>(
            stream: FlashSlotService.escucharActivos(_negocioId!),
            builder: (ctx, snap) {
              final slots = snap.data ?? [];
              if (snap.connectionState == ConnectionState.waiting && slots.isEmpty) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFFFBB00), strokeWidth: 2)));
              }
              if (slots.isEmpty) {
                return Container(padding: const EdgeInsets.symmetric(vertical: 16), alignment: Alignment.center,
                    child: const Text('Sin ofertas flash activas', style: TextStyle(color: _kMuted, fontSize: 13)));
              }
              return Column(children: slots.map((s) => _FlashSlotCard(slot: s, negocioId: _negocioId!)).toList());
            },
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PantallaCrearFlashSlot(
                    negocioId: _negocioId!, negocioNombre: _nombreNegocio,
                    empresaId: widget.empresaId, negocioFotoUrl: _fotos.isNotEmpty ? _fotos.first : null,
                  ))),
              icon: const Icon(Icons.add_rounded, color: Color(0xFFFFBB00)),
              label: const Text('+ Nueva oferta flash', style: TextStyle(color: Color(0xFFFFBB00), fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFFBB00)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ]));
  }

  // ── Características ────────────────────────────────────────────────────────

  Widget _buildCaracteristicas() {
    return _Seccion(icono: Icons.local_offer_outlined, titulo: 'Características',
      subtitulo: 'Etiquetas visibles en tu perfil: WiFi, Parking, Terraza…',
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        ..._caracteristicas.map((c) => Chip(
          label: Text(c, style: const TextStyle(color: _kTexto, fontSize: 12)),
          backgroundColor: _kCard2, side: const BorderSide(color: _kAccent, width: 0.5),
          deleteIconColor: _kRosa, onDeleted: () => setState(() => _caracteristicas.remove(c)),
        )),
        ActionChip(
          avatar: const Icon(Icons.add, color: _kAccent, size: 16),
          label: const Text('Añadir', style: TextStyle(color: _kAccent, fontSize: 12)),
          backgroundColor: _kCard2, side: const BorderSide(color: _kBorde),
          onPressed: () async {
            final r = await showDialog<String>(context: context,
                builder: (_) => _DialogoCaracteristicas(grupos: _caracteristicasGrupos, yaSeleccionadas: _caracteristicas));
            if (r != null && !_caracteristicas.contains(r)) setState(() => _caracteristicas.add(r));
          },
        ),
      ]));
  }

  // ── Formulario ─────────────────────────────────────────────────────────────

  Widget _buildFormulario() {
    return _Seccion(icono: Icons.list_alt_rounded, titulo: 'Campos del Formulario de Reserva',
      subtitulo: 'Campos extra que el cliente rellena al hacer una reserva',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ..._campos.asMap().entries.map((e) {
          final c = e.value;
          return Container(margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kBorde, width: 0.5)),
            child: Row(children: [
              Icon(_iconTipoCampo(c.tipo), color: _kAccent, size: 18), const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.label, style: const TextStyle(color: _kTexto, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${c.tipo} · ${c.obligatorio ? "obligatorio" : "opcional"}', style: const TextStyle(color: _kMuted, fontSize: 11)),
              ])),
              IconButton(icon: const Icon(Icons.edit_outlined, color: _kAccent, size: 18), onPressed: () async {
                final r = await showDialog<CampoPersonalizado>(context: context, builder: (_) => _DialogoCampo(campo: c));
                if (r != null) setState(() => _campos[e.key] = r);
              }),
              IconButton(icon: const Icon(Icons.delete_outline, color: _kRosa, size: 18),
                  onPressed: () => setState(() => _campos.removeAt(e.key))),
            ]),
          );
        }),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: () async {
            final r = await showDialog<CampoPersonalizado>(context: context, builder: (_) => const _DialogoCampo());
            if (r != null) setState(() => _campos.add(r));
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Añadir Campo Personalizado'),
          style: FilledButton.styleFrom(backgroundColor: _kRosa, foregroundColor: _kTexto,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ]));
  }

  IconData _iconTipoCampo(String tipo) => switch (tipo) {
    'numero' => Icons.numbers, 'email' => Icons.email_outlined,
    'telefono' => Icons.phone_outlined, 'selector' => Icons.arrow_drop_down_circle_outlined,
    'checkbox' => Icons.check_box_outlined, _ => Icons.text_fields,
  };

  // ── Reseñas ────────────────────────────────────────────────────────────────


  // ── Términos ───────────────────────────────────────────────────────────────

  Widget _buildTerminos() {
    return _Seccion(icono: Icons.gavel_rounded, titulo: 'Términos y Condiciones',
      subtitulo: 'El cliente los acepta al confirmar una reserva',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorde, width: 0.5)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: _kMuted, size: 16), SizedBox(width: 10),
              Expanded(child: Text('Los T&C se editan en su propia pantalla con editor completo y vista previa.',
                  style: TextStyle(color: _kMuted, fontSize: 12, height: 1.4))),
            ])),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: _abrirTerminos,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Editar Términos y Condiciones', style: TextStyle(fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(backgroundColor: _kCard2, foregroundColor: _kAccent,
              side: const BorderSide(color: _kBorde, width: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
        if (_negocioId == null) ...[
          const SizedBox(height: 8),
          const Center(child: Text('Guarda el perfil primero para acceder al editor', style: TextStyle(color: _kMuted, fontSize: 11))),
        ],
      ]));
  }

  Widget _buildBotonGuardar() {
    return SizedBox(width: double.infinity, height: 54,
      child: FilledButton.icon(
        onPressed: _guardando ? null : _guardar,
        icon: _guardando
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _kBg))
            : const Icon(Icons.cloud_upload_rounded),
        label: Text(_guardando ? 'Guardando...' : '💾  Guardar y publicar cambios'),
        style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
    );
  }

  // ── Diálogos y helpers de servicio ────────────────────────────────────────

  Future<void> _mostrarDialogoServicio({QueryDocumentSnapshot? doc, required int orden}) async {
    final data = doc?.data() as Map<String, dynamic>?;
    final nombreCtrl     = TextEditingController(text: data?['nombre'] ?? '');
    final descCtrl       = TextEditingController(text: data?['descripcion'] ?? '');
    final catCtrl        = TextEditingController(text: data?['categoria'] ?? '');
    final precioCtrl     = TextEditingController(text: data?['precio']?.toString() ?? '');
    final precioDesdeCtrl = TextEditingController(text: data?['precio_desde']?.toString() ?? '');
    String? fotoUrl      = data?['imagen_url'] as String? ?? data?['imagen'] as String?;
    bool subiendoFoto    = false;
    bool usaPrecioDesde  = data?['precio_desde'] != null;
    int duracion = data?['duracion'] as int? ?? 60;
    String publico = data?['publico'] as String? ?? 'todos';
    bool activo = data?['activo'] as bool? ?? true;

    Future<void> subirFotoServicio(StateSetter setSt) async {
      Uint8List? bytes; String ext = 'jpg';
      try {
        final esDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
        if (esDesktop) {
          final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true, allowMultiple: false);
          if (result == null || result.files.isEmpty) return;
          bytes = result.files.first.bytes; ext = result.files.first.extension ?? 'jpg';
        } else {
          final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
          if (img == null) return;
          bytes = await img.readAsBytes(); ext = img.path.split('.').last;
        }
        if (bytes == null) return;
        setSt(() => subiendoFoto = true);
        final ref = FirebaseStorage.instance.ref(
            'negocios_publicos/$_negocioId/servicios/${DateTime.now().millisecondsSinceEpoch}.$ext');
        await ref.putData(bytes, SettableMetadata(contentType: ext.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg'));
        fotoUrl = await ref.getDownloadURL();
        setSt(() => subiendoFoto = false);
      } catch (e) {
        if (mounted) _snack('Error al subir foto: $e', error: true);
        setSt(() => subiendoFoto = false);
      }
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Dialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 780),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(color: Color(0xFF151932),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.content_cut_rounded, color: _kAccent, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Text(doc == null ? 'Nuevo servicio' : 'Editar servicio',
                    style: const TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.bold))),
                Row(children: [
                  Text(activo ? 'Visible' : 'Oculto', style: TextStyle(color: activo ? _kAccent : _kMuted, fontSize: 11)),
                  Switch(value: activo, onChanged: (v) => setSt(() => activo = v),
                      activeColor: _kAccent, activeTrackColor: _kAccent.withValues(alpha: 0.25),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ]),
              ]),
            ),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Label('Nombre del servicio *'),
                TextField(controller: nombreCtrl, autofocus: true,
                    style: const TextStyle(color: _kTexto, fontSize: 13), decoration: _dec('Ej: Corte de cabello mujer')),
                const SizedBox(height: 12),
                const _Label('Descripción (opcional)'),
                TextField(controller: descCtrl, maxLines: 2,
                    style: const TextStyle(color: _kTexto, fontSize: 13), decoration: _dec('Breve descripción para el cliente')),
                const SizedBox(height: 12),
                const _Label('Categoría'),
                TextField(controller: catCtrl, onChanged: (_) => setSt(() {}),
                    style: const TextStyle(color: _kTexto, fontSize: 13), decoration: _dec('Ej: Corte, Color, Masaje…')),
                const SizedBox(height: 12),
                const _Label('Foto del servicio (opcional)'),
                GestureDetector(
                  onTap: subiendoFoto ? null : () => subirFotoServicio(setSt),
                  child: Container(height: 90,
                    decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: fotoUrl != null ? _kAccent.withValues(alpha: 0.4) : _kBorde, width: 1)),
                    child: subiendoFoto
                        ? const Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2))
                        : fotoUrl != null
                        ? Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(9),
                          child: Image.network(fotoUrl!, fit: BoxFit.cover, width: double.infinity, height: 90,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: _kMuted))),
                      Positioned(top: 4, right: 4, child: GestureDetector(
                        onTap: () => setSt(() => fotoUrl = null),
                        child: Container(padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14)),
                      )),
                    ])
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined, color: _kAccent, size: 28),
                      SizedBox(height: 4),
                      Text('Pulsa para subir foto', style: TextStyle(color: _kAccent, fontSize: 11)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const _Label('Precio'),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setSt(() => usaPrecioDesde = !usaPrecioDesde),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: usaPrecioDesde ? _kAccent.withValues(alpha: 0.15) : _kBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: usaPrecioDesde ? _kAccent : _kBorde, width: 0.8)),
                          child: Text('Desde', style: TextStyle(color: usaPrecioDesde ? _kAccent : _kMuted,
                              fontSize: 10, fontWeight: usaPrecioDesde ? FontWeight.w700 : FontWeight.w400)),
                        ),
                      ),
                    ]),
                    TextField(controller: usaPrecioDesde ? precioDesdeCtrl : precioCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: _kTexto, fontSize: 13),
                        decoration: _dec(usaPrecioDesde ? 'Precio mínimo €' : 'Precio fijo €')),
                  ])),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _Label('Duración'),
                    Row(children: [
                      Expanded(child: Slider(value: duracion.toDouble(), min: 10, max: 240, divisions: 23,
                          activeColor: _kAccent, inactiveColor: _kBorde,
                          onChanged: (v) => setSt(() => duracion = v.toInt()))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(duracion >= 60 ? '${duracion ~/ 60}h${duracion % 60 > 0 ? '${duracion % 60}m' : ''}' : '${duracion}m',
                              style: const TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.w700))),
                    ]),
                  ])),
                ]),
                const SizedBox(height: 12),
                const _Label('Público objetivo'),
                Row(children: [
                  for (final opt in [('todos','Todos',_kAccent), ('femenino','Mujer',_kRosa), ('masculino','Hombre',Color(0xFF4A9EFF))])
                    Expanded(child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setSt(() => publico = opt.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                              color: publico == opt.$1 ? opt.$3.withValues(alpha: 0.15) : _kBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: publico == opt.$1 ? opt.$3 : _kBorde,
                                  width: publico == opt.$1 ? 1.5 : 0.8)),
                          child: Text(opt.$2, textAlign: TextAlign.center,
                              style: TextStyle(color: publico == opt.$1 ? opt.$3 : _kMuted, fontSize: 12,
                                  fontWeight: publico == opt.$1 ? FontWeight.w800 : FontWeight.w400)),
                        ),
                      ),
                    )),
                ]),
              ]),
            )),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(color: Color(0xFF151932),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: _kBorde), foregroundColor: _kMuted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Cancelar'),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: FilledButton(
                  onPressed: () async {
                    final nombre = nombreCtrl.text.trim();
                    if (nombre.isEmpty) return;
                    final precioVal = double.tryParse((usaPrecioDesde ? precioDesdeCtrl : precioCtrl).text.trim());
                    final datos = <String, dynamic>{
                      'nombre': nombre, 'descripcion': descCtrl.text.trim(),
                      'categoria': catCtrl.text.trim(), 'duracion': duracion,
                      'publico': publico, 'activo': activo, 'orden': orden,
                      if (fotoUrl != null) 'imagen_url': fotoUrl,
                    };
                    if (precioVal != null) {
                      if (usaPrecioDesde) datos['precio_desde'] = precioVal;
                      else datos['precio'] = precioVal;
                    }
                    Navigator.pop(ctx);
                    try {
                      final col = FirebaseFirestore.instance
                          .collection('empresas').doc(widget.empresaId).collection('servicios');
                      if (doc == null) await col.add(datos);
                      else await col.doc(doc.id).update(datos);
                      _snack(doc == null ? '✅ Servicio añadido' : '✅ Servicio actualizado');
                    } catch (e) { _snack('Error: $e', error: true); }
                  },
                  style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: Text(doc == null ? 'Añadir servicio' : 'Guardar cambios',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                )),
              ]),
            ),
          ]),
        ),
      )),
    );
    nombreCtrl.dispose(); descCtrl.dispose(); catCtrl.dispose(); precioCtrl.dispose(); precioDesdeCtrl.dispose();
  }

  Future<void> _importarServiciosCsv() async {
    if (_negocioId == null) { _snack('Guarda el perfil primero para importar servicios', error: true); return; }
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final rows = const CsvToListConverter(eol: '\n').convert(String.fromCharCodes(bytes));
    if (rows.isEmpty) { _snack('El CSV está vacío', error: true); return; }
    final headers = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    final iNombre = headers.indexOf('nombre');
    if (iNombre == -1) { _snack('El CSV debe tener columna "nombre"', error: true); return; }
    final iDesc = headers.indexWhere((h) => h.startsWith('desc'));
    final iCat  = headers.indexWhere((h) => h.startsWith('cat'));
    final iPrecio  = headers.indexOf('precio');
    final iPrecioD = headers.indexWhere((h) => h.contains('desde'));
    final iDuracion = headers.indexWhere((h) => h.startsWith('dur'));
    final iPublico  = headers.indexWhere((h) => h.startsWith('pub'));
    final servicios = <Map<String, dynamic>>[];
    for (final row in rows.skip(1)) {
      final nombre = iNombre < row.length ? row[iNombre].toString().trim() : '';
      if (nombre.isEmpty) continue;
      final map = <String, dynamic>{'nombre': nombre, 'activo': true};
      if (iDesc >= 0 && iDesc < row.length)    { final v = row[iDesc].toString().trim();    if (v.isNotEmpty) map['descripcion'] = v; }
      if (iCat >= 0 && iCat < row.length)      { final v = row[iCat].toString().trim();     if (v.isNotEmpty) map['categoria'] = v; }
      if (iPrecio >= 0 && iPrecio < row.length){ final v = double.tryParse(row[iPrecio].toString().replaceAll(',', '.')); if (v != null) map['precio'] = v; }
      if (iPrecioD >= 0 && iPrecioD < row.length){ final v = double.tryParse(row[iPrecioD].toString().replaceAll(',', '.')); if (v != null) map['precio_desde'] = v; }
      if (iDuracion >= 0 && iDuracion < row.length){ final v = int.tryParse(row[iDuracion].toString()); if (v != null) map['duracion'] = v; }
      if (iPublico >= 0 && iPublico < row.length) { final v = row[iPublico].toString().trim().toLowerCase(); if (v.isNotEmpty) map['publico'] = v; }
      servicios.add(map);
    }
    if (servicios.isEmpty) { _snack('No se encontraron servicios válidos', error: true); return; }
    final ok = await showDialog<bool>(context: context, builder: (dlgCtx) => AlertDialog(
      backgroundColor: _kCard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Importar ${servicios.length} servicio${servicios.length == 1 ? '' : 's'}',
          style: const TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.bold)),
      content: SizedBox(width: double.maxFinite, height: 280, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Formato: nombre · categoría · precio', style: TextStyle(color: _kMuted, fontSize: 11)),
        const SizedBox(height: 10),
        Expanded(child: ListView.separated(
          itemCount: servicios.length,
          separatorBuilder: (_, __) => const Divider(color: _kBorde, height: 1),
          itemBuilder: (_, i) {
            final s = servicios[i];
            final precio = s['precio'] != null ? '€${s['precio']}' : s['precio_desde'] != null ? 'Desde €${s['precio_desde']}' : '';
            return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(child: Text(s['nombre'] as String, style: const TextStyle(color: _kTexto, fontSize: 13))),
                if ((s['categoria'] as String?) != null) Text(s['categoria'] as String, style: const TextStyle(color: _kMuted, fontSize: 11)),
                if (precio.isNotEmpty) ...[const SizedBox(width: 8), Text(precio, style: const TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w700))],
              ]));
          },
        )),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
        FilledButton(onPressed: () => Navigator.pop(dlgCtx, true),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Importar', style: TextStyle(fontWeight: FontWeight.w800))),
      ],
    ));
    if (ok != true || !mounted) return;
    final col = FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId).collection('servicios');
    int importados = 0;
    for (final s in servicios) { try { await col.add({...s, 'creado_en': FieldValue.serverTimestamp()}); importados++; } catch (_) {} }
    if (mounted) _snack('✅ $importados servicio${importados == 1 ? '' : 's'} importado${importados == 1 ? '' : 's'}');
  }

  Future<void> _eliminarServicio(String docId, String nombre) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: _kCard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Eliminar servicio', style: TextStyle(color: _kTexto, fontSize: 16)),
      content: Text('¿Eliminar "$nombre"? No se puede deshacer.', style: const TextStyle(color: _kMuted, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
        FilledButton(onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF2850), foregroundColor: Colors.white),
            child: const Text('Eliminar')),
      ],
    ));
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId).collection('servicios').doc(docId).delete();
    _snack('🗑️ Servicio eliminado');
  }

  IconData _iconCatServicio(String cat) {
    switch (cat.toLowerCase()) {
      case 'corte': case 'pelo':        return Icons.content_cut_rounded;
      case 'color': case 'tinte':       return Icons.color_lens_rounded;
      case 'manicura': case 'pedicura': return Icons.spa_rounded;
      case 'masaje':                    return Icons.self_improvement_rounded;
      case 'facial':                    return Icons.face_retouching_natural_rounded;
      case 'barba':                     return Icons.face_rounded;
      case 'depilación':                return Icons.auto_fix_high_rounded;
      case 'tratamientos':              return Icons.science_rounded;
      default:                          return Icons.star_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════════════

class _Seccion extends StatelessWidget {
  final IconData icono; final String titulo; final String? subtitulo;
  final Widget child; final Color? accent;
  const _Seccion({required this.icono, required this.titulo, this.subtitulo, required this.child, this.accent});
  @override
  Widget build(BuildContext context) {
    final color = accent ?? _kAccent;
    return Container(width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: _kBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icono, color: color, size: 16)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(color: _kTexto, fontWeight: FontWeight.bold, fontSize: 14)),
            if (subtitulo != null) Text(subtitulo!, style: const TextStyle(color: _kMuted, fontSize: 11)),
          ])),
        ]),
        const Divider(color: _kBorde, height: 22),
        child,
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  final String text; const _Label(this.text);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w600)));
}

class _Input extends StatelessWidget {
  final TextEditingController ctrl; final String hint;
  const _Input({required this.ctrl, required this.hint});
  @override Widget build(BuildContext context) => TextField(controller: ctrl, style: const TextStyle(color: _kTexto), decoration: _dec(hint));
}

class _InputIcon extends StatelessWidget {
  final TextEditingController ctrl; final IconData icon; final String label; final String hint;
  const _InputIcon({required this.ctrl, required this.icon, required this.label, required this.hint});
  @override Widget build(BuildContext context) => TextField(controller: ctrl, style: const TextStyle(color: _kTexto, fontSize: 13),
      decoration: _dec(hint).copyWith(labelText: label, labelStyle: const TextStyle(color: _kMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: _kRosa, size: 18)));
}

class _BotonHora extends StatelessWidget {
  final String hora; final VoidCallback onTap;
  const _BotonHora({required this.hora, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorde)),
          child: Text(hora, textAlign: TextAlign.center, style: const TextStyle(color: _kTexto, fontSize: 12, fontWeight: FontWeight.w500))));
}

InputDecoration _dec(String hint) => InputDecoration(
  hintText: hint, hintStyle: const TextStyle(color: Color(0xFF5A5D72), fontSize: 13),
  filled: true, fillColor: _kBg, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: _kBorde, width: 0.5)),
  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: _kAccent, width: 1)),
  border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: _kBorde, width: 0.5)),
);

class _Avatar extends StatelessWidget {
  final String nombre; final String? avatarUrl; final double size;
  const _Avatar({required this.nombre, required this.avatarUrl, required this.size});
  Color get _color { const colors = [Color(0xFF6C5CE7),Color(0xFF00B894),Color(0xFFE17055),Color(0xFF0984E3),Color(0xFFD63031),Color(0xFFFDAB3D)]; return colors[nombre.isEmpty ? 0 : nombre.codeUnitAt(0) % colors.length]; }
  String get _iniciales { final p = nombre.trim().split(' '); if (p.isEmpty || p[0].isEmpty) return '?'; if (p.length == 1) return p[0][0].toUpperCase(); return '${p[0][0]}${p[1][0]}'.toUpperCase(); }
  @override Widget build(BuildContext context) => Container(width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _color, border: Border.all(color: _kBorde, width: 1.5),
          image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover, onError: (_, __) {}) : null),
      child: avatarUrl == null ? Center(child: Text(_iniciales, style: TextStyle(color: Colors.white, fontSize: size * 0.36, fontWeight: FontWeight.bold))) : null);
}

class _DialogoTexto extends StatelessWidget {
  final String titulo; final TextEditingController ctrl; final String hint;
  const _DialogoTexto({required this.titulo, required this.ctrl, required this.hint});
  @override Widget build(BuildContext context) => AlertDialog(backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(titulo, style: const TextStyle(color: _kTexto)),
      content: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: _kTexto), decoration: _dec(hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg), child: const Text('Añadir')),
      ]);
}

class _DialogoCampo extends StatefulWidget {
  final CampoPersonalizado? campo; const _DialogoCampo({this.campo});
  @override State<_DialogoCampo> createState() => _DialogoCampoState();
}

class _DialogoCampoState extends State<_DialogoCampo> {
  final _labelCtrl = TextEditingController(); final _placeCtrl = TextEditingController();
  String _tipo = 'texto'; bool _obligatorio = false; List<String> _opciones = [];
  @override void initState() { super.initState(); if (widget.campo != null) { final c = widget.campo!; _labelCtrl.text = c.label; _placeCtrl.text = c.placeholder ?? ''; _tipo = c.tipo; _obligatorio = c.obligatorio; _opciones = List.from(c.opciones ?? []); } }
  @override void dispose() { _labelCtrl.dispose(); _placeCtrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.campo == null ? 'Nuevo Campo' : 'Editar Campo', style: const TextStyle(color: _kTexto)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _labelCtrl, style: const TextStyle(color: _kTexto), decoration: _dec('Ej: Número de personas').copyWith(labelText: 'Etiqueta *', labelStyle: const TextStyle(color: _kMuted))),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _tipo, dropdownColor: _kCard, style: const TextStyle(color: _kTexto),
            decoration: InputDecoration(labelText: 'Tipo', labelStyle: const TextStyle(color: _kMuted), filled: true, fillColor: _kBg,
                enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: _kBorde, width: 0.5)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: _kAccent, width: 1)),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none)),
            items: const [
              DropdownMenuItem(value: 'texto', child: Text('Texto libre')), DropdownMenuItem(value: 'numero', child: Text('Número')),
              DropdownMenuItem(value: 'email', child: Text('Email')), DropdownMenuItem(value: 'telefono', child: Text('Teléfono')),
              DropdownMenuItem(value: 'selector', child: Text('Selector (opciones)')), DropdownMenuItem(value: 'checkbox', child: Text('Sí / No')),
            ],
            onChanged: (v) => setState(() => _tipo = v!)),
        const SizedBox(height: 12),
        TextField(controller: _placeCtrl, style: const TextStyle(color: _kTexto), decoration: _dec('Texto de ayuda (opcional)').copyWith(labelText: 'Placeholder', labelStyle: const TextStyle(color: _kMuted))),
        Container(margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10)),
            child: CheckboxListTile(contentPadding: EdgeInsets.zero, value: _obligatorio, activeColor: _kAccent,
                title: const Text('Campo obligatorio', style: TextStyle(color: _kTexto, fontSize: 13)),
                onChanged: (v) => setState(() => _obligatorio = v!))),
        if (_tipo == 'selector') ...[
          const Divider(color: _kBorde, height: 24),
          const Text('Opciones:', style: TextStyle(color: _kMuted, fontWeight: FontWeight.bold)),
          ..._opciones.map((o) => ListTile(dense: true, title: Text(o, style: const TextStyle(color: _kTexto, fontSize: 13)),
              trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: _kRosa, size: 18), onPressed: () => setState(() => _opciones.remove(o))))),
          TextButton.icon(onPressed: () async {
            final c = TextEditingController();
            final r = await showDialog<String>(context: context, builder: (_) => _DialogoTexto(titulo: 'Nueva opción', ctrl: c, hint: 'Ej: Mañana'));
            if (r != null && r.isNotEmpty) setState(() => _opciones.add(r));
          }, icon: const Icon(Icons.add_circle_outline, color: _kAccent, size: 16), label: const Text('Añadir opción', style: TextStyle(color: _kAccent, fontSize: 13))),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
        FilledButton(onPressed: () {
          if (_labelCtrl.text.trim().isEmpty) return;
          Navigator.pop(context, CampoPersonalizado(
              id: widget.campo?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              label: _labelCtrl.text.trim(), tipo: _tipo, obligatorio: _obligatorio,
              opciones: _tipo == 'selector' ? _opciones : null,
              placeholder: _placeCtrl.text.isEmpty ? null : _placeCtrl.text.trim()));
        }, style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg), child: const Text('Guardar')),
      ]);
}

class _DialogoCaracteristicas extends StatefulWidget {
  final Map<String, List<String>> grupos; final List<String> yaSeleccionadas;
  const _DialogoCaracteristicas({required this.grupos, required this.yaSeleccionadas});
  @override State<_DialogoCaracteristicas> createState() => _DialogoCaracteristicasState();
}

class _DialogoCaracteristicasState extends State<_DialogoCaracteristicas> {
  String _busqueda = ''; final _busqCtrl = TextEditingController();
  @override void dispose() { _busqCtrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Dialog(backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
          child: Column(children: [
            Container(padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                decoration: const BoxDecoration(color: Color(0xFF151932), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Añadir característica', style: TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(controller: _busqCtrl, onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
                      style: const TextStyle(color: _kTexto, fontSize: 13),
                      decoration: InputDecoration(hintText: 'Buscar...', hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: _kAccent, size: 18), filled: true, fillColor: _kBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                ])),
            Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8),
                children: widget.grupos.entries.map((grupo) {
                  final opciones = grupo.value.where((o) => _busqueda.isEmpty || o.toLowerCase().contains(_busqueda)).toList();
                  if (opciones.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Text(grupo.key, style: const TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                    ...opciones.map((opcion) {
                      final yaEsta = widget.yaSeleccionadas.contains(opcion);
                      return ListTile(dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                          title: Text(opcion, style: TextStyle(color: yaEsta ? _kMuted : _kTexto, fontSize: 13, decoration: yaEsta ? TextDecoration.lineThrough : null)),
                          trailing: yaEsta ? const Icon(Icons.check_circle_rounded, color: _kAccent, size: 18) : null,
                          onTap: yaEsta ? null : () => Navigator.pop(context, opcion));
                    }),
                    const Divider(color: _kBorde, height: 1, indent: 16, endIndent: 16),
                  ]);
                }).toList())),
            Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(color: Color(0xFF151932), borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
                child: SizedBox(width: double.infinity,
                    child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: _kMuted))))),
          ])));
}

// ── Flash Slot Card ──────────────────────────────────────────────────────────

class _FlashSlotCard extends StatefulWidget {
  final FlashSlotModel slot; final String negocioId;
  const _FlashSlotCard({required this.slot, required this.negocioId});
  @override State<_FlashSlotCard> createState() => _FlashSlotCardState();
}

class _FlashSlotCardState extends State<_FlashSlotCard> {
  static const _flash = Color(0xFFFFBB00);
  static const _rosa  = Color(0xFFFF3296);
  static const _rojo  = Color(0xFFFF2850);
  late Timer _timer;
  late Duration _restante;

  @override
  void initState() {
    super.initState();
    _restante = widget.slot.tiempoRestante;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _restante = widget.slot.tiempoRestante);
    });
  }

  @override void dispose() { _timer.cancel(); super.dispose(); }

  String _fmt(Duration d) {
    if (d.isNegative) return 'Expirado';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final urgente = _restante.inMinutes < 30;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: urgente ? _rojo.withValues(alpha: 0.5) : _flash.withValues(alpha: 0.3))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(slot.servicioNombre, style: const TextStyle(color: _kTexto, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Row(children: [
            Text('€${slot.precioFinal.toStringAsFixed(2)}', style: const TextStyle(color: _flash, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(width: 6),
            Text('€${slot.precioOriginal.toStringAsFixed(2)}', style: const TextStyle(color: _kMuted, fontSize: 11,
                decoration: TextDecoration.lineThrough, decorationColor: _kMuted)),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: _rosa.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(slot.descuentoTexto, style: const TextStyle(color: _rosa, fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.timer_outlined, size: 12, color: urgente ? _rojo : _kMuted),
            const SizedBox(width: 4),
            Text(_fmt(_restante), style: TextStyle(fontSize: 11, color: urgente ? _rojo : _kMuted, fontWeight: urgente ? FontWeight.w700 : FontWeight.normal)),
            const SizedBox(width: 10),
            Text('${slot.huecosReservados}/${slot.huecosTotal} reservados', style: const TextStyle(fontSize: 11, color: _kMuted)),
          ]),
        ])),
        TextButton(
          onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
              backgroundColor: _kCard,
              title: const Text('Cancelar oferta', style: TextStyle(color: _kTexto)),
              content: const Text('¿Seguro que quieres cancelar esta oferta flash?', style: TextStyle(color: _kMuted)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar', style: TextStyle(color: _rojo))),
              ],
            ));
            if (ok == true) await FlashSlotService.cancelarSlot(widget.negocioId, slot.id);
          },
          child: const Text('Cancelar', style: TextStyle(color: _rojo, fontSize: 12)),
        ),
      ]),
    );
  }
}
