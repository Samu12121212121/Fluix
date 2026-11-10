import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA ALERTA DE DESPACHO — Sysday Emergencias
//
// Se abre cuando llega una alerta de despacho vía FCM (notificación push).
// Muestra: paciente, dirección, tipo urgencia, equipos asignados.
// El operario puede Aceptar (confirma disponibilidad) o Pasar (rechaza).
//
// Colección: empresas/{empresaId}/alertas_despacho/{alertaId}
// ═══════════════════════════════════════════════════════════════════════════════

enum PrioridadAlerta { critica, alta, media, baja }

extension PrioridadExt on PrioridadAlerta {
  Color get color => switch (this) {
    PrioridadAlerta.critica => const Color(0xFFDC2626),
    PrioridadAlerta.alta    => const Color(0xFFEA580C),
    PrioridadAlerta.media   => const Color(0xFFD97706),
    PrioridadAlerta.baja    => const Color(0xFF16A34A),
  };
  Color get colorSuave => switch (this) {
    PrioridadAlerta.critica => const Color(0xFFFEF2F2),
    PrioridadAlerta.alta    => const Color(0xFFFFF7ED),
    PrioridadAlerta.media   => const Color(0xFFFFFBEB),
    PrioridadAlerta.baja    => const Color(0xFFF0FDF4),
  };
  String get label => switch (this) {
    PrioridadAlerta.critica => 'CRÍTICA',
    PrioridadAlerta.alta    => 'ALTA',
    PrioridadAlerta.media   => 'MEDIA',
    PrioridadAlerta.baja    => 'BAJA',
  };
  IconData get icon => switch (this) {
    PrioridadAlerta.critica => Icons.emergency_rounded,
    PrioridadAlerta.alta    => Icons.warning_rounded,
    PrioridadAlerta.media   => Icons.info_rounded,
    PrioridadAlerta.baja    => Icons.check_circle_rounded,
  };
}

class AlertaDespacho {
  final String id;
  final String empresaId;
  final String tipoCodigo;
  final String descripcion;
  final String direccion;
  final String localidad;
  final String? referenciaMapa;
  final String? nombrePaciente;
  final int?   edadPaciente;
  final PrioridadAlerta prioridad;
  final String ambulanciaAsignada;
  final String? medicoAsignado;
  final DateTime fechaHora;
  final String estado;
  final String? operadorUid;

  const AlertaDespacho({
    required this.id,
    required this.empresaId,
    required this.tipoCodigo,
    required this.descripcion,
    required this.direccion,
    required this.localidad,
    this.referenciaMapa,
    this.nombrePaciente,
    this.edadPaciente,
    required this.prioridad,
    required this.ambulanciaAsignada,
    this.medicoAsignado,
    required this.fechaHora,
    required this.estado,
    this.operadorUid,
  });

  factory AlertaDespacho.fromMap(String id, Map<String, dynamic> d) =>
      AlertaDespacho(
        id:                  id,
        empresaId:           d['empresa_id'] as String? ?? '',
        tipoCodigo:          d['tipo_codigo'] as String? ?? 'SVB',
        descripcion:         d['descripcion'] as String? ?? '',
        direccion:           d['direccion'] as String? ?? '',
        localidad:           d['localidad'] as String? ?? '',
        referenciaMapa:      d['referencia_mapa'] as String?,
        nombrePaciente:      d['nombre_paciente'] as String?,
        edadPaciente:        (d['edad_paciente'] as num?)?.toInt(),
        prioridad:           PrioridadAlerta.values.firstWhere(
          (p) => p.name == (d['prioridad'] as String? ?? 'alta'),
          orElse: () => PrioridadAlerta.alta,
        ),
        ambulanciaAsignada:  d['ambulancia_asignada'] as String? ?? '',
        medicoAsignado:      d['medico_asignado'] as String?,
        fechaHora:           (d['fecha_hora'] as Timestamp?)?.toDate() ?? DateTime.now(),
        estado:              d['estado'] as String? ?? 'pendiente',
        operadorUid:         d['operador_uid'] as String?,
      );
}

// ── Pantalla ──────────────────────────────────────────────────────────────────

class PantallaAlertaDespacho extends StatefulWidget {
  final String empresaId;
  final String alertaId;

  const PantallaAlertaDespacho({
    super.key,
    required this.empresaId,
    required this.alertaId,
  });

  @override
  State<PantallaAlertaDespacho> createState() => _State();
}

class _State extends State<PantallaAlertaDespacho>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  AlertaDespacho? _alerta;
  bool _cargando = true;
  bool _respondiendo = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  Timer? _timer;
  Duration _transcurrido = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _cargar();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    final doc = await _db
        .collection('empresas').doc(widget.empresaId)
        .collection('alertas_despacho').doc(widget.alertaId)
        .get();
    if (!doc.exists || !mounted) return;
    final alerta = AlertaDespacho.fromMap(doc.id, doc.data()!);
    setState(() { _alerta = alerta; _cargando = false; });
    HapticFeedback.heavyImpact();
    _iniciarCronometro(alerta.fechaHora);
  }

  void _iniciarCronometro(DateTime desde) {
    _transcurrido = DateTime.now().difference(desde);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _transcurrido = DateTime.now().difference(desde));
    });
  }

  Future<void> _responder(String estado) async {
    setState(() => _respondiendo = true);
    HapticFeedback.mediumImpact();
    await _db.collection('empresas').doc(widget.empresaId)
        .collection('alertas_despacho').doc(widget.alertaId)
        .update({
      'estado': estado,
      'operador_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
      'fecha_respuesta': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _abrirMapa() async {
    if (_alerta == null) return;
    final dir      = Uri.encodeComponent('${_alerta!.direccion}, ${_alerta!.localidad}, España');
    final gmaps    = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dir&travelmode=driving');
    final gmapsApp = Uri.parse('google.navigation:q=$dir&mode=d');
    if (await canLaunchUrl(gmapsApp)) {
      await launchUrl(gmapsApp);
    } else {
      await launchUrl(gmaps, mode: LaunchMode.externalApplication);
    }
  }

  String _fmtDuracion(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_alerta == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Alerta de despacho')),
        body: const Center(child: Text('Alerta no encontrada')),
      );
    }

    final a   = _alerta!;
    final col = a.prioridad.color;
    final yaRespondida = a.estado != 'pendiente';
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    final contenido = Column(children: [
      _buildBanner(a, col),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _buildTarjetaPaciente(a, col),
            const SizedBox(height: 12),
            _buildTarjetaDireccion(a),
            const SizedBox(height: 12),
            _buildTarjetaAsignacion(a),
            const SizedBox(height: 20),
            if (!yaRespondida) _buildBotones(col),
            if (yaRespondida)  _buildEstadoRespuesta(a),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    ]);

    if (!isWide) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(child: contenido),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Container(
          width: 480,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: col.withValues(alpha: 0.4), width: 2),
            boxShadow: [
              BoxShadow(color: col.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 2),
              const BoxShadow(color: Colors.black26, blurRadius: 20),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: contenido,
        ),
      ),
    );
  }

  // ── Banner superior ────────────────────────────────────────────────────────

  Widget _buildBanner(AlertaDespacho a, Color col) => Container(
    color: col,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    child: Row(children: [
      ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(a.prioridad.icon, color: Colors.white, size: 26),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('DESPACHO ${a.prioridad.label}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 0.8,
              )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(a.tipoCodigo,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 2),
        Text(DateFormat('HH:mm:ss  ·  dd/MM/yyyy').format(a.fechaHora),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
      ])),
      // Cronómetro
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(_fmtDuracion(_transcurrido),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontFeatures: [FontFeature.tabularFigures()],
              )),
          Text('transcurrido', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9)),
        ]),
      ),
    ]),
  );

  // ── Tarjeta paciente ────────────────────────────────────────────────────────

  Widget _buildTarjetaPaciente(AlertaDespacho a, Color col) => _card(
    accentColor: col,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _seccionTitulo('Paciente', Icons.person_rounded, col),
      const SizedBox(height: 10),
      if (a.nombrePaciente != null)
        _fila(Icons.badge_outlined, 'Nombre', a.nombrePaciente!),
      if (a.edadPaciente != null)
        _fila(Icons.cake_outlined, 'Edad', '${a.edadPaciente} años'),
      _fila(Icons.medical_services_outlined, 'Motivo', a.descripcion),
    ]),
  );

  // ── Tarjeta dirección ───────────────────────────────────────────────────────

  Widget _buildTarjetaDireccion(AlertaDespacho a) => _card(
    accentColor: const Color(0xFF2563EB),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _seccionTitulo('Destino', Icons.location_on_rounded, const Color(0xFF2563EB)),
        GestureDetector(
          onTap: _abrirMapa,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.navigation_rounded, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Text('Navegar', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      _fila(Icons.location_on_outlined, 'Dirección', a.direccion),
      _fila(Icons.location_city_outlined, 'Localidad', a.localidad),
      if (a.referenciaMapa != null)
        _fila(Icons.info_outline_rounded, 'Referencia', a.referenciaMapa!),
    ]),
  );

  // ── Tarjeta asignación ──────────────────────────────────────────────────────

  Widget _buildTarjetaAsignacion(AlertaDespacho a) => _card(
    accentColor: const Color(0xFF059669),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _seccionTitulo('Asignación', Icons.local_hospital_rounded, const Color(0xFF059669)),
      const SizedBox(height: 10),
      _fila(Icons.emergency_rounded, 'Unidad', a.ambulanciaAsignada),
      if (a.medicoAsignado != null)
        _fila(Icons.medical_information_outlined, 'Médico', a.medicoAsignado!),
    ]),
  );

  // ── Botones de respuesta ────────────────────────────────────────────────────

  Widget _buildBotones(Color col) => _respondiendo
      ? Center(child: CircularProgressIndicator(color: col))
      : Column(children: [
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: () => _responder('aceptada'),
              icon: const Icon(Icons.check_circle_rounded, size: 24),
              label: const Text('ACEPTAR DESPACHO',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _responder('rechazada'),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('No puedo atender', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]);

  Widget _buildEstadoRespuesta(AlertaDespacho a) {
    final esAceptada = a.estado == 'aceptada';
    final col  = esAceptada ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final bg   = esAceptada ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: col.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(esAceptada ? Icons.check_circle_rounded : Icons.cancel_rounded, color: col, size: 22),
          const SizedBox(width: 10),
          Text(
            esAceptada ? 'Despacho aceptado — En camino' : 'Despacho rechazado',
            style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ]),
      ),
      if (esAceptada) ...[
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _abrirMapa,
            icon: const Icon(Icons.navigation_rounded, size: 20),
            label: const Text('Abrir navegación', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    ]);
  }

  // ── Widgets auxiliares ────────────────────────────────────────────────────

  Widget _card({required Widget child, required Color accentColor}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: child,
  );

  Widget _seccionTitulo(String texto, IconData icon, Color col) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 15, color: col),
    ),
    const SizedBox(width: 8),
    Text(texto, style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 13)),
  ]);

  Widget _fila(IconData icon, String label, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 8),
      SizedBox(width: 72, child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))),
      Expanded(child: Text(valor, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}
