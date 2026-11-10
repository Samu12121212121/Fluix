import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import 'historial_empleado_sheet.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA FICHAJE EMPLEADO
// ═══════════════════════════════════════════════════════════════════════════════

const int _kNumFotos = 4;

class PantallaFichajeEmpleado extends StatefulWidget {
  final String empresaId;
  final String dispositivoId;

  const PantallaFichajeEmpleado({
    super.key,
    required this.empresaId,
    required this.dispositivoId,
  });

  @override
  State<PantallaFichajeEmpleado> createState() =>
      _PantallaFichajeEmpleadoState();
}

class _PantallaFichajeEmpleadoState extends State<PantallaFichajeEmpleado> {
  final FichajeService _service = FichajeService();
  final ImagePicker _picker = ImagePicker();

  EmpleadoFichaje? _empleado;
  Fichaje? _fichaje;
  bool _cargando = false;
  String? _error;
  String _pin = '';

  // Fotos de entrada — solo si la empresa tiene fichaje_fotos_entrada: true
  bool _fotosRequeridas = false;
  final List<XFile?> _fotos = List.filled(_kNumFotos, null, growable: false);
  bool _subiendoFotos = false;

  // Reloj en tiempo real
  late Timer _timer;
  String _horaActual = '';

  @override
  void initState() {
    super.initState();
    _actualizarHora();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _actualizarHora());
    _cargarConfigEmpresa();
  }

  Future<void> _cargarConfigEmpresa() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId).get();
      if (mounted) {
        setState(() {
          _fotosRequeridas =
              doc.data()?['fichaje_fotos_entrada'] as bool? ?? false;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _actualizarHora() {
    if (mounted) setState(() => _horaActual = DateFormat('HH:mm:ss').format(DateTime.now()));
  }

  // ── PIN ────────────────────────────────────────────────────────────────────

  void _pulsarDigito(String digito) {
    if (_pin.length >= 4 || _cargando) return;
    setState(() { _pin += digito; _error = null; });
    if (_pin.length == 4) _verificarPIN();
  }

  void _borrarDigito() {
    if (_pin.isEmpty || _cargando) return;
    setState(() { _pin = _pin.substring(0, _pin.length - 1); _error = null; });
  }

  Future<void> _verificarPIN() async {
    setState(() => _cargando = true);
    try {
      final empleado = await _service.verificarPIN(
        empresaId: widget.empresaId, pin: _pin,
      );
      if (empleado == null) {
        setState(() { _error = 'PIN incorrecto'; _pin = ''; });
        return;
      }
      final fichaje = await _service.obtenerFichajeHoy(widget.empresaId, empleado.uid);
      setState(() { _empleado = empleado; _fichaje = fichaje; });
    } catch (_) {
      setState(() { _error = 'Error al verificar PIN'; _pin = ''; });
    } finally {
      setState(() => _cargando = false);
    }
  }

  // ── Fotos ──────────────────────────────────────────────────────────────────

  Future<void> _tomarFoto(int slot) async {
    final fuente = await _mostrarFuenteFoto();
    if (fuente == null) return;
    // 800×600 a 55% ≈ 50-80 KB por foto (vs ~400 KB con 1200/80)
    final img = await _picker.pickImage(
        source: fuente, imageQuality: 55, maxWidth: 800, maxHeight: 600);
    if (img != null && mounted) setState(() => _fotos[slot] = img);
  }

  Future<ImageSource?> _mostrarFuenteFoto() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF3B82F6)),
            title: const Text('Cámara'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF3B82F6)),
            title: const Text('Galería'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
  }

  Future<List<String>> _subirFotos() async {
    final fecha = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // Ruta fija por empleado+fecha: sobreescribe si refichan el mismo día
    final basePath = 'fichajes/${widget.empresaId}/$fecha/${_empleado!.uid}';
    final urls = <String>[];
    for (int i = 0; i < _kNumFotos; i++) {
      final foto = _fotos[i];
      if (foto == null) continue;
      final ref = FirebaseStorage.instance.ref('$basePath/foto_$i.jpg');
      await ref.putFile(
        File(foto.path),
        SettableMetadata(contentType: 'image/jpeg', customMetadata: {
          'empleadoId': _empleado!.uid,
          'empresaId': widget.empresaId,
          'fecha': fecha,
        }),
      );
      urls.add(await ref.getDownloadURL());
    }
    // Purgar carpetas de más de 90 días en segundo plano (sin bloquear)
    _purgarFotosAntiguas();
    return urls;
  }

  // Borra carpetas de empleado con más de 90 días para contener el coste de Storage.
  // Falla silenciosamente — nunca bloquea el fichaje.
  Future<void> _purgarFotosAntiguas() async {
    try {
      final limite = DateTime.now().subtract(const Duration(days: 90));
      final baseRef = FirebaseStorage.instance
          .ref('fichajes/${widget.empresaId}');
      final ListResult dias = await baseRef.listAll();
      for (final prefijo in dias.prefixes) {
        // El nombre del prefijo es la fecha "yyyy-MM-dd"
        final nombre = prefijo.name;
        final fecha = DateTime.tryParse(nombre);
        if (fecha == null || fecha.isAfter(limite)) continue;
        // Borrar todos los archivos dentro de esa carpeta de fecha
        final archivos = await prefijo.listAll();
        for (final empleadoDir in archivos.prefixes) {
          final fotos = await empleadoDir.listAll();
          for (final foto in fotos.items) {
            await foto.delete();
          }
        }
      }
    } catch (_) {
      // Silencioso — no interrumpe el fichaje
    }
  }

  int get _fotosSubidas => _fotos.where((f) => f != null).length;

  // ── Acciones de fichaje ────────────────────────────────────────────────────

  Future<void> _ejecutarAccion(Future<void> Function() accion, String mensajeOk) async {
    setState(() => _cargando = true);
    try {
      await accion();
      if (!mounted) return;
      _mostrarExito(mensajeOk);
      await Future.delayed(const Duration(seconds: 2));
      _cerrarSesion();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      _mostrarError(e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _ficharEntrada() async {
    setState(() { _cargando = true; _subiendoFotos = _fotosRequeridas; });
    try {
      final urls = _fotosRequeridas ? await _subirFotos() : <String>[];
      await _service.ficharEntrada(
        empresaId: widget.empresaId,
        empleadoId: _empleado!.uid,
        empleadoNombre: _empleado!.nombre,
        dispositivoId: widget.dispositivoId,
        fotosUrls: urls,
      );
      if (!mounted) return;
      _mostrarExito('Entrada registrada: $_horaActual');
      await Future.delayed(const Duration(seconds: 2));
      _cerrarSesion();
    } catch (e) {
      if (!mounted) return;
      _mostrarError(e.toString());
    } finally {
      if (mounted) setState(() { _cargando = false; _subiendoFotos = false; });
    }
  }

  Future<void> _iniciarPausa() => _ejecutarAccion(
      () => _service.iniciarPausa(empresaId: widget.empresaId, empleadoId: _empleado!.uid),
      'Pausa iniciada: $_horaActual');

  Future<void> _finalizarPausa() => _ejecutarAccion(
      () => _service.finalizarPausa(empresaId: widget.empresaId, empleadoId: _empleado!.uid),
      'Pausa finalizada: $_horaActual');

  Future<void> _ficharSalida() async {
    final confirmado = await _mostrarConfirmacionJornada();
    if (!confirmado) return;
    return _ejecutarAccion(
      () => _service.ficharSalida(empresaId: widget.empresaId, empleadoId: _empleado!.uid),
      'Salida registrada: $_horaActual',
    );
  }

  Future<bool> _mostrarConfirmacionJornada() async {
    final f = _fichaje;
    if (f == null) return true;
    final entradaStr = f.entrada != null
        ? DateFormat('HH:mm').format(f.entrada!.toDate())
        : '--:--';
    final neto = f.tiempoNeto;
    final netoStr = neto != null
        ? '${neto.inHours}h ${neto.inMinutes.remainder(60).toString().padLeft(2, '0')}m'
        : '—';
    final numPausas = f.pausas.where((p) => p.fin != null).length;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF16A34A), size: 22),
          SizedBox(width: 8),
          Text('Confirmar jornada', style: TextStyle(fontSize: 17)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            '¿Confirmas que tu jornada de hoy ha terminado?',
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _resumenItemDialog('Entrada', entradaStr, Icons.login),
              _resumenItemDialog('Total neto', netoStr, Icons.timer_outlined),
              _resumenItemDialog('Pausas', '$numPausas', Icons.pause_circle_outline),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Confirmar salida'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Widget _resumenItemDialog(String label, String valor, IconData icono) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 18, color: const Color(0xFF16A34A)),
        const SizedBox(height: 2),
        Text(valor,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                color: Color(0xFF15803D))),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A))),
      ]);

  void _abrirHistorial() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HistorialEmpleadoSheet(
        empresaId: widget.empresaId,
        empleadoId: _empleado!.uid,
        empleadoNombre: _empleado!.nombre,
      ),
    );
  }

  void _cerrarSesion() {
    setState(() {
      _empleado = null; _fichaje = null; _pin = ''; _error = null;
      for (int i = 0; i < _kNumFotos; i++) _fotos[i] = null;
    });
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 18)),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const FluixAppBar(titulo: 'Sistema de Fichaje', showLeading: true),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: _empleado == null ? _buildPantallaPIN() : _buildPantallaAcciones(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pantalla PIN ───────────────────────────────────────────────────────────

  Widget _buildPantallaPIN() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
        DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'es_ES').format(DateTime.now()),
        style: const TextStyle(fontSize: 15, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.access_time, size: 28, color: Colors.blue),
        const SizedBox(width: 8),
        Text(_horaActual, style: const TextStyle(
          fontSize: 44, fontWeight: FontWeight.bold, color: Colors.blue,
          fontFeatures: [FontFeature.tabularFigures()],
        )),
      ]),
      const SizedBox(height: 36),
      const CircleAvatar(
        radius: 36, backgroundColor: Colors.blue,
        child: Icon(Icons.person, size: 44, color: Colors.white),
      ),
      const SizedBox(height: 16),
      const Text('Introduce tu PIN',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final relleno = i < _pin.length;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: relleno ? Colors.blue : Colors.transparent,
              border: Border.all(color: Colors.blue, width: 2),
            ),
          );
        }),
      ),
      const SizedBox(height: 24),
      _buildTeclado(),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center),
      ],
      if (_cargando)
        const Padding(padding: EdgeInsets.only(top: 20), child: CircularProgressIndicator()),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _mostrarAyudaPIN,
        child: const Text('¿Olvidaste tu PIN?',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      ),
    ]);
  }

  void _mostrarAyudaPIN() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN olvidado'),
        content: const Text(
          'Contacta con tu administrador para restablecer tu PIN.\n\n'
          'El administrador puede cambiarlo desde la pestaña '
          '"Empleados" en la pantalla de gestión de fichajes.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
      ),
    );
  }

  Widget _buildTeclado() {
    final filas = [['1','2','3'],['4','5','6'],['7','8','9'],['','0','⌫']];
    return Column(children: filas.map((fila) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: fila.map((key) {
        if (key.isEmpty) return const SizedBox(width: 72);
        if (key == '⌫') return _teclaIcono(Icons.backspace_outlined, _borrarDigito, Colors.red);
        return _teclaNumero(key);
      }).toList()),
    )).toList());
  }

  Widget _teclaNumero(String n) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox(width: 60, height: 60,
      child: ElevatedButton(
        onPressed: () => _pulsarDigito(n),
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(), padding: EdgeInsets.zero,
          backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 2,
        ),
        child: Text(n, style: const TextStyle(fontSize: 24)),
      ),
    ),
  );

  Widget _teclaIcono(IconData icon, VoidCallback onTap, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox(width: 60, height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(), padding: EdgeInsets.zero,
          backgroundColor: color.withValues(alpha: 0.1), foregroundColor: color, elevation: 2,
        ),
        child: Icon(icon, size: 24),
      ),
    ),
  );

  // ── Pantalla acciones ──────────────────────────────────────────────────────

  Widget _buildPantallaAcciones() {
    final estado = _fichaje?.estado ?? EstadoFichaje.sinFichar;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Hola, ${_empleado!.nombre}!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(_horaActual, style: const TextStyle(
        fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue,
        fontFeatures: [FontFeature.tabularFigures()],
      )),

      if (_fichaje != null) ...[
        const SizedBox(height: 12),
        _buildResumenJornada(_fichaje!),
      ],

      const SizedBox(height: 20),

      // ── Fotos de revisión (solo si la empresa lo requiere) ─────────────
      if (_fotosRequeridas && estado == EstadoFichaje.sinFichar) ...[
        _buildSeccionFotos(),
        const SizedBox(height: 20),
      ],

      // ── Botones según estado ───────────────────────────────────────────
      if (estado == EstadoFichaje.sinFichar)
        _botonAccion(
          icono: _subiendoFotos ? Icons.cloud_upload_rounded : Icons.login,
          texto: _subiendoFotos
              ? 'Subiendo fotos...'
              : (_fotosRequeridas && _fotosSubidas > 0)
                  ? 'FICHAR ENTRADA ($_fotosSubidas/$_kNumFotos fotos)'
                  : 'FICHAR ENTRADA',
          color: Colors.green,
          onTap: _ficharEntrada,
          enabled: !_cargando,
        ),

      if (estado == EstadoFichaje.trabajando) ...[
        _botonAccion(icono: Icons.pause_circle, texto: 'INICIAR PAUSA',
            color: Colors.orange, onTap: _iniciarPausa),
        const SizedBox(height: 12),
        _botonAccion(icono: Icons.logout, texto: 'FICHAR SALIDA',
            color: Colors.red, onTap: _ficharSalida),
      ],

      if (estado == EstadoFichaje.enPausa)
        _botonAccion(icono: Icons.play_circle, texto: 'FIN DE PAUSA',
            color: Colors.blue, onTap: _finalizarPausa),

      if (estado == EstadoFichaje.cerrado)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50], borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Jornada finalizada',
                style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.w600)),
          ]),
        ),

      const SizedBox(height: 24),
      TextButton.icon(
        onPressed: _cargando ? null : _abrirHistorial,
        icon: const Icon(Icons.history, size: 18),
        label: const Text('Ver mi historial'),
        style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
      ),
      TextButton.icon(
        onPressed: _cerrarSesion,
        icon: const Icon(Icons.close),
        label: const Text('Cancelar'),
        style: TextButton.styleFrom(foregroundColor: Colors.grey),
      ),

      if (_cargando)
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(children: [
            const CircularProgressIndicator(),
            if (_subiendoFotos) ...[
              const SizedBox(height: 8),
              const Text('Subiendo fotos...', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ]),
        ),
    ]);
  }

  // ── Sección de 4 fotos de ambulancia ──────────────────────────────────────

  Widget _buildSeccionFotos() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF3B82F6), size: 18),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Revisión visual de ambulancia',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            Text('Sube 4 fotos antes de comenzar la jornada',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _fotosSubidas == _kNumFotos
                ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$_fotosSubidas/$_kNumFotos',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _fotosSubidas == _kNumFotos
                  ? const Color(0xFF059669) : const Color(0xFFD97706),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8,
        childAspectRatio: 1.4,
        children: List.generate(_kNumFotos, (i) => _buildSlotFoto(i)),
      ),
    ]);
  }

  static const List<String> _kEtiquetasFoto = [
    'Exterior delantera',
    'Exterior trasera',
    'Interior cabina',
    'Interior módulo',
  ];

  Widget _buildSlotFoto(int slot) {
    final foto = _fotos[slot];
    return GestureDetector(
      onTap: _cargando ? null : () => _tomarFoto(slot),
      child: Container(
        decoration: BoxDecoration(
          color: foto != null ? Colors.black : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: foto != null ? const Color(0xFF3B82F6) : Colors.grey.shade300,
            width: foto != null ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: foto != null
              ? Stack(fit: StackFit.expand, children: [
                  Image.file(File(foto.path), fit: BoxFit.cover),
                  Positioned(top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _fotos[slot] = null),
                      child: Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                  Positioned(bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                      color: Colors.black54,
                      child: Text(_kEtiquetasFoto[slot],
                          style: const TextStyle(color: Colors.white, fontSize: 9),
                          textAlign: TextAlign.center),
                    ),
                  ),
                ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_a_photo_rounded,
                      size: 26, color: Colors.grey.shade400),
                  const SizedBox(height: 4),
                  Text(_kEtiquetasFoto[slot],
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      textAlign: TextAlign.center),
                ]),
        ),
      ),
    );
  }

  // ── Widgets auxiliares ─────────────────────────────────────────────────────

  Widget _buildResumenJornada(Fichaje f) {
    final entrada = f.entrada != null
        ? DateFormat('HH:mm').format(f.entrada!.toDate()) : '--:--';
    final neto = f.tiempoNeto;
    final totalStr = neto != null
        ? '${neto.inHours}h ${neto.inMinutes.remainder(60)}m' : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _resumenItem('Entrada', entrada, Icons.login),
        _resumenItem('Pausas', '${f.pausas.length}', Icons.pause),
        _resumenItem('Total neto', totalStr, Icons.timer),
      ]),
    );
  }

  Widget _resumenItem(String label, String valor, IconData icono) => Column(children: [
    Icon(icono, size: 18, color: Colors.blue[700]),
    const SizedBox(height: 2),
    Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
  ]);

  Widget _botonAccion({
    required IconData icono,
    required String texto,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity, height: 66,
      child: ElevatedButton.icon(
        onPressed: (_cargando || !enabled) ? null : onTap,
        icon: Icon(icono, size: 28),
        label: Text(texto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
      ),
    );
  }
}
