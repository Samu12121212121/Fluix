            const SizedBox(height: 8),
            Text('Las 5 más recientes se descargan al sincronizar\ny se acumulan aquí hasta llegar a 50.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12), textAlign: TextAlign.center),
          ] else ...[
            Icon(Icons.star_border_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Sin valoraciones todavía', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            Text('Las reseñas de Google aparecerán aquí al sincronizar',
              style: TextStyle(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: onAnadir, icon: const Icon(Icons.add),
            label: const Text('Añadir valoración manual'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
                try {
                try {
                  final gs = GoogleSignIn(scopes: ['https://www.googleapis.com/auth/business.manage']);
                  var acc = await gs.signInSilently() ?? await gs.signIn();
                  if (acc != null) {
                    final auth = await acc.authentication;
                    if (auth.accessToken != null) {
                final res = await RespuestaGmbService().publicar(
                  empresaId: empresaId, valoracionId: docId, texto: texto);
                publicadoEnGoogle = res.publicadoEnGoogle;
                if (res.enCola) msgExtra = ' (en cola, reintentando...)';
                else if (!publicadoEnGoogle && res.error != null) msgExtra = ' (${res.error})';
                      await svc.responderResena('accounts/me/locations/me/reviews/$docId', texto, auth.accessToken!);
                      publicadoEnGoogle = true;
                    }
                  }
                } on PlatformException catch (_) {
              }  // closes else
            }  // closes if (data['origen'] == 'google')
                  '3. Cuando se sincronice con Google, se publicará.',
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.2))),
                  '3. Conéctate a Google Business para publicar en Google Maps.',
                  '3. Conéctate a Google Business para publicar en Google Maps.',
    // 4. Sincronizar con Google en background (actualiza rating + añade nuevas)
    // 3. Cargar primera página de reseñas guardadas
    // 2. Borrar pruebas
    // 1. Leer rating del cache de Firestore primero (instantáneo)
import '../../../services/respuesta_gmb_service.dart';
import 'estado_conexion_google_widget.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'estado_conexion_google_widget.dart';

import 'package:flutter/services.dart';
import 'estado_conexion_google_widget.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'estado_conexion_google_widget.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'estado_conexion_google_widget.dart';

import 'package:flutter/services.dart';
import 'estado_conexion_google_widget.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'estado_conexion_google_widget.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../../services/google_reviews_service.dart';
import '../../../services/respuesta_gmb_service.dart';
import 'estado_conexion_google_widget.dart';
import 'estado_respuesta_widget.dart';
import 'grafico_evolucion_rating_widget.dart';
import 'kpis_rating_widget.dart';
import '../pantallas/configurar_google_reviews_screen.dart';

class ModuloValoraciones extends StatefulWidget {
  final String empresaId;
  const ModuloValoraciones({super.key, required this.empresaId});

  @override
  State<ModuloValoraciones> createState() => _ModuloValoracionesState();
        limite: _porPagina, cursor: reset ? null : _ultimoDoc);

    if (!mounted) return;
    setState(() {
      if (reset) {
  }

  bool _cargando = true;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('es', timeago.EsMessages());
    _init();
  }

  Future<void> _init() async {
    // 1. Leer rating del cache de Firestore primero (instantáneo)
    await _leerRatingCache();
    // 2. Borrar pruebas
    await _svc.borrarResenasDePrueba(widget.empresaId);
    // 3. Cargar primera página de reseñas guardadas
    await _cargarPagina(reset: true);
    // 4. Sincronizar con Google en background (actualiza rating + añade nuevas)
    _sincronizarEnBackground();
  Future<void> _cargarMas() async {
    if (_cargandoMas || _ultimoDoc == null) return;
    setState(() => _cargandoMas = true);
    await _cargarPagina();
    if (mounted) setState(() => _cargandoMas = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [

  Future<void> _leerRatingCache() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('estadisticas').doc('resumen').get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _ratingGoogle = (data['rating_google'] as num?)?.toDouble() ?? 0;
        // Solo admin/propietario ven el botón de configuración

    final resultado = await _svc.cargarResenas(widget.empresaId,
        _ultimoDoc = resultado.last['_snap'] as DocumentSnapshot?;
      }
      _hayMas = resultado.length == _porPagina;
      _cargando = false;
    });
  }

  Future<void> _sincronizarEnBackground() async {
    if (!mounted) return;
    setState(() => _sincronizando = true);

    final resultado = await _svc.sincronizarDesdeGoogle(widget.empresaId);

    if (!mounted) return;
    setState(() {
      if (resultado.rating > 0) _ratingGoogle = resultado.rating;
      if (resultado.total > 0) _totalGoogle = resultado.total;
      _errorSync = resultado.error;
      _sincronizando = false;
    });

    // Recargar reseñas tras sincronizar
    await _cargarPagina(reset: true);
  }

        // Solo admin/propietario ven el botón de configuración
      _CabeceraCompleta(
        empresaId: widget.empresaId,
        resenas: _resenas,
        ratingGoogle: _ratingGoogle,
        onGmbConectado: () => _sincronizarEnBackground(),
        totalGoogle: _totalGoogle,
        sincronizando: _sincronizando,
        errorSync: _errorSync,
        mostrarAnaliticas: _mostrarAnaliticas,
        onSincronizar: _sincronizarEnBackground,
        onAnadir: () => _mostrarFormAnadir(context),
        onToggleAnaliticas: () => setState(() => _mostrarAnaliticas = !_mostrarAnaliticas),
        onConfigurar: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConfigurarGoogleReviewsScreen(
              empresaId: widget.empresaId,
            ),
          ),
        ).then((_) => _sincronizarEnBackground()),
      ),
      if (_cargando)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (_resenas.isEmpty)
        Expanded(child: _EstadoVacio(ratingGoogle: _ratingGoogle,
            totalGoogle: _totalGoogle, onAnadir: () => _mostrarFormAnadir(context)))
      else
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _resenas.length + (_hayMas ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _resenas.length) {
              return Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: _cargandoMas
                  ? const CircularProgressIndicator()
                  : OutlinedButton.icon(
                      onPressed: _cargarMas,
                      icon: const Icon(Icons.expand_more),
                      label: Text('Ver más (${_resenas.length} de máx 50)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1976D2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ))));
            }
            final data = Map<String, dynamic>.from(_resenas[i])..remove('_snap');
            return _TarjetaResena(docId: _resenas[i]['id'] as String,
                empresaId: widget.empresaId, data: data, svc: _svc);
          },
        )),
    ]);
  }

  void _mostrarFormAnadir(BuildContext context) {
    final clienteCtrl = TextEditingController();
    final comentarioCtrl = TextEditingController();
    int calificacion = 5;
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
              const SizedBox(height: 16),
              const Text('Nueva valoración manual',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              Text('Para clientes que valoran en persona',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 16),
              TextField(controller: clienteCtrl,
                decoration: InputDecoration(labelText: 'Nombre del cliente',
                  prefixIcon: const Icon(Icons.person_outline),
  final String empresaId;
  final List<Map<String, dynamic>> resenas;
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Calificación: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ...List.generate(5, (i) => GestureDetector(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  child: Icon(i < calificacion ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF57C00), size: 32))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: comentarioCtrl, maxLines: 3,
                decoration: InputDecoration(labelText: 'Comentario',
                  prefixIcon: const Icon(Icons.comment_outlined), alignLabelWithHint: true,
    required this.totalGoogle, required this.sincronizando, required this.errorSync,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final cli = clienteCtrl.text.trim();
                    final com = comentarioCtrl.text.trim();
                    if (cli.isEmpty || com.isEmpty) return;
                    await _svc.anadirValoracionManual(empresaId: widget.empresaId,
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabecera completa con GMB, KPIs y analíticas colapsables
// ─────────────────────────────────────────────────────────────────────────────
class _CabeceraCompleta extends StatelessWidget {
    required this.onToggleAnaliticas, required this.onGmbConectado,
  final int totalGoogle;
  final bool sincronizando;
  final String? errorSync;
  final bool mostrarAnaliticas;
  final VoidCallback onSincronizar;
  final VoidCallback onAnadir;
  final VoidCallback onToggleAnaliticas;
  final VoidCallback onGmbConectado;
  final VoidCallback? onConfigurar;

  const _CabeceraCompleta({
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 6),
                  Text('Sincronizando...', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ])
              : IconButton(
                  onPressed: onSincronizar,
                  icon: const Icon(Icons.sync, size: 18),
                  color: Colors.grey[500],
                  tooltip: 'Sincronizar con Google',
    required this.empresaId, required this.resenas, required this.ratingGoogle,
    required this.onToggleAnaliticas, required this.onGmbConectado,
    required this.mostrarAnaliticas, required this.onSincronizar, required this.onAnadir,
    required this.onToggleAnaliticas, required this.onGmbConectado, this.onConfigurar,
  });

  @override
  Widget build(BuildContext context) {
    final rating = ratingGoogle > 0 ? ratingGoogle : _promedioLocal();
        // Fila estado GMB + acciones
        Row(children: [
        // Fila estado GMB + acciones
        Row(children: [
          Expanded(child: EstadoConexionGoogleWidget(
            empresaId: empresaId, onEstadoCambiado: onGmbConectado)),
          if (sincronizando) ...[
            const SizedBox(width: 8),
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 4),
            Text('Sync...', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
          IconButton(onPressed: sincronizando ? null : onSincronizar,
            icon: const Icon(Icons.sync, size: 20), color: const Color(0xFF4285F4),
            tooltip: 'Sincronizar con Google'),
          IconButton(onPressed: onAnadir,
            icon: const Icon(Icons.add_comment_outlined, size: 20), color: const Color(0xFF43A047),
            tooltip: 'Añadir valoración manual'),
        ]),
            const SizedBox(width: 4),
            Text('Sync...', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
            icon: const Icon(Icons.add_comment_outlined, size: 20), color: const Color(0xFF43A047),
            tooltip: 'Añadir valoración manual'),
            tooltip: 'Sincronizar con Google'),
          IconButton(onPressed: onAnadir,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFF57C00)),
                    minHeight: 7))),
        ]),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Column(children: [
            Text(rating > 0 ? rating.toStringAsFixed(1) : '-',
              style: const TextStyle(fontSize: 46, fontWeight: FontWeight.bold, color: Color(0xFFF57C00))),
            Row(children: List.generate(5, (i) {
              if (rating <= 0) return const Icon(Icons.star_border, color: Color(0xFFF57C00), size: 20);
            const SizedBox(height: 4),
            Text(total > 0 ? '$total reseñas en Google' : 'Sin datos de Google',
              style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500)),
            if (resenas.isNotEmpty) Text('${resenas.length} guardadas aquí',
              style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ]),
          const SizedBox(width: 16),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
          Expanded(child: Column(children: List.generate(5, (i) {
            final stars = 5 - i;
            final count = resenas.where((r) =>
              child: Row(children: [
                Text('$stars', style: const TextStyle(fontSize: 11)),
            ])),
        ],
                const Icon(Icons.star, size: 10, color: Color(0xFFF57C00)),
                const SizedBox(width: 4),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: pct,
                    backgroundColor: Colors.grey[300],
          })))],
        ),
                const SizedBox(width: 4),
                SizedBox(width: 22, child: Text('$count', style: const TextStyle(fontSize: 11))),
              ]));
          }))),
        ]),

        // Aviso limitación
        if (totalGoogle > 5) ...[
          const SizedBox(height: 8),
        // Error sync
        // Error sync
        if (errorSync != null && !errorSync!.contains('último')) ...[
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8)),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(children: [
              Icon(Icons.error_outline, size: 13, color: Colors.red[700]),
              const SizedBox(width: 6),
              Expanded(child: Text(
                errorSync!,
              Expanded(child: Text('Sync: $errorSync',
              Expanded(child: Text('Sync: $errorSync',
              const Icon(Icons.warning_amber_outlined, size: 13, color: Colors.orange),
          if (deApp > 0) ...[
              Expanded(child: Text('Sync: $errorSync',
                style: const TextStyle(fontSize: 10, color: Colors.orange))),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: onToggleAnaliticas,
            icon: Icon(mostrarAnaliticas ? Icons.expand_less : Icons.bar_chart, size: 16),
            label: Text(mostrarAnaliticas ? 'Ocultar' : 'Ver análisis',
              style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF1976D2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          ),
        ]),

        // Sección analíticas colapsable
// ─────────────────────────────────────────────────────────────────────────────
          KPIsRatingWidget(empresaId: empresaId, ratingGoogle: ratingGoogle, totalGoogle: totalGoogle),
          const SizedBox(height: 16),
          GraficoEvolucionRatingWidget(empresaId: empresaId),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }

  double _promedioLocal() {
    if (resenas.isEmpty) return 0;
    final suma = resenas.fold<double>(0, (s, r) =>
      s + ((r['calificacion'] ?? r['estrellas'] ?? 0) as num).toDouble());
    return suma / resenas.length;
  }

  Widget _badge(IconData icono, String texto, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 14, color: color), const SizedBox(width: 4),
      Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vacío
// ─────────────────────────────────────────────────────────────────────────────
class _TarjetaResena extends StatelessWidget {
  final String docId;
  final String empresaId;
  final Map<String, dynamic> data;
                      Icon(esGoogle ? Icons.g_mobiledata : Icons.phone_android, size: 12,
                        color: esGoogle ? const Color(0xFF4285F4) : const Color(0xFF43A047)),
                      const SizedBox(width: 2),
                      Text(esGoogle ? 'Google' : 'App', style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: esGoogle ? const Color(0xFF4285F4) : const Color(0xFF43A047))),
                    ])),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  ...List.generate(5, (i) => Icon(i < calificacion ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF57C00), size: 14)),
                  const SizedBox(width: 6),
                  Text(timeago.format(fecha, locale: 'es'),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ]),
              ])),
            ]),
            if (comentario.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(comentario, style: const TextStyle(fontSize: 13.5, height: 1.45)),
            ],
            if (respuesta != null && respuesta.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: Color(0xFF1976D2), width: 3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('Tu respuesta', style: TextStyle(fontWeight: FontWeight.w600,
                      fontSize: 12, color: Color(0xFF1976D2))),
                    const SizedBox(width: 8),
                    EstadoRespuestaWidget(estado: respuestaEstado, esDeGoogle: esGoogle),
                  ]),
                  const SizedBox(height: 4),
                  Text(respuesta, style: const TextStyle(fontSize: 13, height: 1.35)),
                ])),
            ],
            const SizedBox(height: 4),
            Row(children: [
              const Spacer(),
              TextButton.icon(
                onPressed: () => _dialogoResponder(context, respuesta),
                icon: Icon(respuesta != null && respuesta.isNotEmpty ? Icons.edit_outlined : Icons.reply, size: 16),
                label: Text(respuesta != null && respuesta.isNotEmpty ? 'Editar respuesta' : 'Responder',
                  style: const TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
              ),
            ]),
          ])),
      ),
      // Badge rojo parpadeante para reseñas negativas sin responder
      if (esNegativa && sinResponder && !eliminadaPorGoogle)
        const Positioned(top: 8, left: 8, child: _BadgeNegativa()),
    ]);
  }

  void _dialogoResponder(BuildContext context, String? actual) {
    final ctrl = TextEditingController(text: actual ?? '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.reply, color: Color(0xFF1976D2)), const SizedBox(width: 8),
        Expanded(child: Text(actual != null && actual.isNotEmpty ? 'Editar respuesta' : 'Responder reseña',
          style: const TextStyle(fontSize: 17))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (data['origen'] == 'google') ...[
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF4285F4).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
            child: Text(
              data['google_review_name'] != null
                ? 'Tu respuesta se publicará directamente en Google Maps.'
                : '1. Escribe tu respuesta y pulsa Guardar.\n2. Se guarda en la app.\n'
                  '3. Conéctate a Google Business para publicar en Google Maps.',
              style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.5))),
          const SizedBox(height: 12),
        ],
        TextField(controller: ctrl, maxLines: 5, autofocus: true,
          decoration: InputDecoration(hintText: 'Escribe tu respuesta...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true, fillColor: Colors.grey[50])),
      ]),
      actions: [
        if (data['origen'] == 'google')
          TextButton.icon(onPressed: () => _abrirEnGoogle(ctx),
            icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF4285F4)),
            label: const Text('Abrir Google', style: TextStyle(color: Color(0xFF4285F4), fontSize: 13))),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
          onPressed: () async {
            final texto = ctrl.text.trim();
            if (texto.isEmpty) return;
            // 1. Guardar en Firestore
            await svc.guardarRespuesta(empresaId: empresaId, valoracionId: docId, respuesta: texto);
            bool publicadoEnGoogle = false;
            String msgExtra = '';
            // 2. Publicar en GMB si tiene review name
            if (data['origen'] == 'google') {
              if (data['google_review_name'] != null) {
                try {
                  final res = await RespuestaGmbService().publicar(
                    empresaId: empresaId, valoracionId: docId, texto: texto);
                  publicadoEnGoogle = res.publicadoEnGoogle;
                  if (res.enCola) msgExtra = ' (en cola, reintentando...)';
                  else if (!publicadoEnGoogle && res.error != null) msgExtra = ' (${res.error})';
                } catch (_) {
                  msgExtra = ' (Conecta Google Business para publicar en Maps)';
                }
              } else {
                msgExtra = ' (Se publicará en Maps más tarde)';
              }
            }
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Row(children: [
                Icon(publicadoEnGoogle ? Icons.check_circle : Icons.save, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(data['origen'] == 'google'
                  ? (publicadoEnGoogle ? 'Respuesta publicada en Google Maps ✅' : 'Guardada localmente$msgExtra')
                  '3. Conéctate a Google Business para publicar en Google Maps.',
                  '3. Conéctate a Google Business para publicar en Google Maps.',
              ]),
              backgroundColor: publicadoEnGoogle ? const Color(0xFF4CAF50) : const Color(0xFF1976D2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.2))),
          },
          child: const Text('Guardar')),
      ]));
  }

  Future<void> _abrirEnGoogle(BuildContext context) async {
                  '3. Cuando se sincronice con Google, se publicará.',
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Accede a business.google.com/reviews'),
        backgroundColor: Colors.orange));
    }
  }

  DateTime _parseFecha(dynamic f) {
                  : 'Respuesta guardada correctamente')),
    return DateTime.now();
  }
              duration: const Duration(seconds: 4)));
    final c = [
      const Color(0xFF1976D2), const Color(0xFF388E3C), const Color(0xFF7B1FA2),
      const Color(0xFFF57C00), const Color(0xFFD32F2F), const Color(0xFF00BCD4),
      const Color(0xFF5D4037), const Color(0xFF689F38), const Color(0xFFE91E63),
    ];
    return c[name.codeUnits.fold(0, (a, b) => a + b) % c.length];
  }
    final uri = Uri.parse('https://business.google.com/reviews');
}

// ── Badge rojo parpadeante ────────────────────────────────────────────────────
class _BadgeNegativa extends StatefulWidget {
  const _BadgeNegativa();
  @override
  State<_BadgeNegativa> createState() => _BadgeNegativaState();
}

                try {
                try {
                  final gs = GoogleSignIn(scopes: ['https://www.googleapis.com/auth/business.manage']);
                  var acc = await gs.signInSilently() ?? await gs.signIn();
                  if (acc != null) {
                    final auth = await acc.authentication;
                    if (auth.accessToken != null) {
                final res = await RespuestaGmbService().publicar(
                  empresaId: empresaId, valoracionId: docId, texto: texto);
                publicadoEnGoogle = res.publicadoEnGoogle;
                if (res.enCola) msgExtra = ' (en cola, reintentando...)';
                else if (!publicadoEnGoogle && res.error != null) msgExtra = ' (${res.error})';
                      await svc.responderResena('accounts/me/locations/me/reviews/$docId', texto, auth.accessToken!);
                      publicadoEnGoogle = true;
                    }
                  }
                } on PlatformException catch (_) {
              }  // closes else
            }  // closes if (data['origen'] == 'google')
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Opacity(opacity: _anim.value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(8)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
class _BadgeNegativaState extends State<_BadgeNegativa> with SingleTickerProviderStateMixin {
            const SizedBox(height: 8),
            Text('Las 5 más recientes se descargan al sincronizar\ny se acumulan aquí hasta llegar a 50.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12), textAlign: TextAlign.center),
          ] else ...[
            Icon(Icons.star_border_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Sin valoraciones todavía', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            Text('Las reseñas de Google aparecerán aquí al sincronizar',
              style: TextStyle(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: onAnadir, icon: const Icon(Icons.add),
            label: const Text('Añadir valoración manual'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    if (f is Timestamp) return f.toDate();
    if (f is String) return DateTime.tryParse(f) ?? DateTime.now();
          SizedBox(width: 3),

  Color _colorDesdeNombre(String name) {
        ]),
      ),
    );
  }
      ),
    );
  }
      )),
  );
}


