import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../domain/modelos/configuracion_facturacion_tpv.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../../../services/tpv/impresora_bluetooth_service.dart';
import '../../../services/tpv/impresora_windows_service.dart';
import '../../../services/demo_cuenta_service.dart';
import '../../../features/pdf_templates/data/pdf_template_service.dart';
import '../../../features/pdf_templates/domain/models/pdf_template.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'importar_catalogo_csv_screen.dart';
import '../../../core/widgets/flux_toast.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/utils/app_settings.dart';
import '../../../services/tpv/terminal_fisica_service.dart';

class ConfiguracionFacturacionTpvScreen extends StatefulWidget {
  final String empresaId;
  final bool esPropietario;
  
  const ConfiguracionFacturacionTpvScreen({
    super.key, 
    required this.empresaId,
    this.esPropietario = false,
  });

  @override
  State<ConfiguracionFacturacionTpvScreen> createState() =>
      _ConfiguracionFacturacionTpvScreenState();
}

class _ConfiguracionFacturacionTpvScreenState
    extends State<ConfiguracionFacturacionTpvScreen> {
  final TpvFacturacionService _svc = TpvFacturacionService();
  final PdfTemplateService _pdfSvc = PdfTemplateService();
  ConfiguracionFacturacionTpv _config = const ConfiguracionFacturacionTpv();
  bool _cargando = true;
  bool _guardando = false;
  List<PdfTemplate> _plantillas = [];

  // Métodos de pago configurables en el TPV
  static const _metodosBase = [
    ('efectivo',      '💵', 'Efectivo'),
    ('tarjeta',       '💳', 'Tarjeta'),
    ('bizum',         '📱', 'Bizum'),
    ('transferencia', '🏦', 'Transferencia'),
    ('cheque_regalo', '🎁', 'Cheque regalo'),
  ];
  Set<String> _metodosHabilitados = {'efectivo', 'tarjeta'};
  List<String> _metodosCustom = [];
  final _nuevoMetodoCtrl = TextEditingController();
  
  int _navIdx = 0;

  // Estado Bluetooth
  bool _btConectada = false;
  String? _nombreImpresora;

  // Estado Windows (COM + TCP)
  String? _winPuerto;
  bool _winConectada = false;
  bool _winDetectando = false;
  bool _winUsaTcp = false;
  final _winPuertoCtrl = TextEditingController();
  final _winIpCtrl = TextEditingController();
  final _winPortCtrl = TextEditingController(text: '9100');
  
  // Estado impresora de barra
  bool _barraUsaTcp = false;
  final _barraPuertoCtrl = TextEditingController();
  final _barraIpCtrl = TextEditingController();
  final _barraPortCtrl = TextEditingController(text: '9100');

  // Estado terminal física
  final _terminalIpCtrl = TextEditingController();
  final _terminalPuertoCtrl = TextEditingController(text: '8080');
  bool _terminalTestando = false;
  String? _terminalTestResultado;

  // Control de visualización
  bool _esDemo = false;
  bool get _puedeEditarTipoNegocio => widget.esPropietario || _esDemo;
  bool _isDark = false;

  // Colores adaptativos
  Color get _bg   => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F2F5);
  Color get _surf => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _bdr  => _isDark ? const Color(0xFF334155) : Colors.grey.shade200;
  Color get _txt  => _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1A1A2E);
  Color get _sub  => _isDark ? const Color(0xFF94A3B8) : _sub;

  @override
  void initState() {
    super.initState();
    _isDark = AppSettings.darkMode.value;
    AppSettings.darkMode.addListener(_onDark);
    _cargar();
    _verificarBluetooth();
    _verificarWindows();
    _verificarDemo();
  }

  void _onDark() { if (mounted) setState(() => _isDark = AppSettings.darkMode.value); }

  @override
  void dispose() {
    AppSettings.darkMode.removeListener(_onDark);
    _nuevoMetodoCtrl.dispose();
    _winPuertoCtrl.dispose();
    _winIpCtrl.dispose();
    _winPortCtrl.dispose();
    _barraPuertoCtrl.dispose();
    _barraIpCtrl.dispose();
    _barraPortCtrl.dispose();
    _terminalIpCtrl.dispose();
    _terminalPuertoCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarDemo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _esDemo = DemoCuentaService().esDemo(user.email));
    }
  }

  Future<void> _verificarWindows() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    final svc = ImpresoraWindowsService();
    await svc.inicializar();
    if (mounted) {
      setState(() {
        _winUsaTcp = svc.usaTcp;
        _winPuerto = svc.puertoActual;
        _winConectada = svc.estaConectada;
        _winPuertoCtrl.text = _winPuerto ?? '';
        _winIpCtrl.text = svc.ipActual ?? '';
        _winPortCtrl.text = svc.puertoTcpActual.toString();
      });
    }
  }

  Future<void> _verificarBluetooth() async {
    final conectada = await ImpressoraBluetooth().estaConectada();
    final ultima = await ImpressoraBluetooth().obtenerUltimaGuardada();
    if (mounted) {
      setState(() {
        _btConectada = conectada;
        _nombreImpresora = ultima?['name'];
      });
    }
  }

  Future<void> _cargar() async {
    final config = await _svc.obtenerConfig(widget.empresaId);
    List<PdfTemplate> plantillas = [];
    try { plantillas = await _pdfSvc.getPlantillas(widget.empresaId); } catch (_) {}

    // Cargar métodos de pago del TPV
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('tpv_cobro').get();
      if (doc.exists) {
        final habilitados = (doc.data()?['metodos_habilitados'] as List?)
            ?.map((e) => e.toString()).toSet() ?? {'efectivo', 'tarjeta'};
        final custom = (doc.data()?['metodos_custom'] as List?)
            ?.map((e) => e.toString()).toList() ?? [];
        setState(() { _metodosHabilitados = habilitados; _metodosCustom = custom; });
      }
    } catch (_) {}

    setState(() { _config = config; _plantillas = plantillas; _cargando = false; });
    // Inicializar controles de impresora de barra
    _barraPuertoCtrl.text = config.impresoraBarraPuerto;
    _barraIpCtrl.text = config.impresoraBarraIp;
    _barraUsaTcp = config.impresoraBarraIp.isNotEmpty;
    // Inicializar controles de terminal física
    _terminalIpCtrl.text = config.terminalFisicaIp;
    _terminalPuertoCtrl.text = config.terminalFisicaPuerto.toString();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    // Sincronizar impresora de barra y terminal física desde controles de texto
    _config = _config.copyWith(
      impresoraBarraPuerto: !_barraUsaTcp ? _barraPuertoCtrl.text.trim().toUpperCase() : '',
      impresoraBarraIp: _barraUsaTcp ? _barraIpCtrl.text.trim() : '',
      terminalFisicaIp: _terminalIpCtrl.text.trim(),
      terminalFisicaPuerto: int.tryParse(_terminalPuertoCtrl.text.trim()) ?? 8080,
    );
    try {
      await _svc.guardarConfig(widget.empresaId, _config);
      // Guardar métodos de pago del TPV
      await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('tpv_cobro')
          .set({
        'metodos_habilitados': _metodosHabilitados.toList(),
        'metodos_custom': _metodosCustom,
        'actualizado': FieldValue.serverTimestamp(),
      });
      if (mounted) FluxToast.exito(context, 'Configuración guardada');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  static const _primario = Color(0xFF1565C0);

  static const _navDestinos = [
    (icon: Icons.hardware_outlined,       sel: Icons.hardware,          label: 'Hardware'),
    (icon: Icons.description_outlined,    sel: Icons.description,       label: 'Documentos'),
    (icon: Icons.point_of_sale_outlined,  sel: Icons.point_of_sale,     label: 'Cobro'),
    (icon: Icons.business_outlined,       sel: Icons.business,          label: 'Negocio'),
    (icon: Icons.tune_rounded,            sel: Icons.tune,              label: 'Avanzado'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: FluixAppBar(
        titulo: 'Configuración TPV',
        showLeading: true,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _primario))
          : LayoutBuilder(builder: (_, c) {
              final wide = c.maxWidth > 640;
              return Column(children: [
                Expanded(
                  child: wide ? _layoutDesktop() : _layoutMobile(),
                ),
                _pieGuardar(),
              ]);
            }),
    );
  }

  // ── Layout desktop: sidebar + contenido ──────────────────────────────────

  Widget _layoutDesktop() => Row(children: [
    Container(
      width: 152,
      color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header del sidebar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Configuración',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: _sub, letterSpacing: 0.5)),
            Text('TPV',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: _txt, letterSpacing: -0.3)),
          ]),
        ),
        Divider(height: 1, color: _bdr),
        const SizedBox(height: 8),
        // Items de navegación
        ..._navDestinos.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          final sel = _navIdx == i;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: InkWell(
              onTap: () => setState(() => _navIdx = i),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: sel
                      ? _primario.withValues(alpha: _isDark ? 0.18 : 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: sel
                      ? Border.all(color: _primario.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(children: [
                  Icon(sel ? d.sel : d.icon, size: 17,
                      color: sel ? _primario : _sub),
                  const SizedBox(width: 9),
                  Expanded(child: Text(d.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? _primario : _sub,
                      ),
                      overflow: TextOverflow.ellipsis)),
                  if (sel)
                    Container(width: 4, height: 4,
                        decoration: BoxDecoration(
                            color: _primario, shape: BoxShape.circle)),
                ]),
              ),
            ),
          );
        }),
      ]),
    ),
    Container(width: 1, color: _bdr),
    Expanded(child: _tabContent(_navIdx)),
  ]);

  // ── Layout mobile: TabBar ─────────────────────────────────────────────────

  Widget _layoutMobile() {
    return DefaultTabController(
      length: 5,
      child: Column(children: [
        Material(
          color: _surf,
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: _primario,
            unselectedLabelColor: _sub,
            indicatorColor: _primario,
            indicatorWeight: 2.5,
            dividerColor: _bdr,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            tabs: _navDestinos.map((d) => Tab(
              icon: Icon(d.icon, size: 18),
              text: d.label,
              iconMargin: const EdgeInsets.only(bottom: 2),
            )).toList(),
          ),
        ),
        Expanded(child: TabBarView(
          children: List.generate(5, _tabContent),
        )),
      ]),
    );
  }

  // ── Contenido por tab ─────────────────────────────────────────────────────

  Widget _tabContent(int idx) {
    return [
      _tabHardware(),
      _tabDocumentos(),
      _tabCobro(),
      _tabNegocio(),
      _tabAvanzado(),
    ][idx];
  }

  Widget _tabHardware() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ch('Formato de impresión', icon: Icons.print_outlined),
        ...FormatoImpresionTpv.values.map((f) {
          final sel = _config.formatoImpresion == f;
          return InkWell(
            onTap: () => setState(() => _config = _config.copyWith(formatoImpresion: f)),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: sel ? _primario.withValues(alpha: 0.06) : _bg,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: sel ? _primario : _bdr,
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Text(f.icono, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text(f.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: sel ? _primario : _txt,
                    ))),
                if (sel)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: _primario, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
              ]),
            ),
          );
        }),
      ])),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
        _seccionImpresoraWindows()
      else
        _seccionBluetooth(),
      _seccionImpresoraBarra(),
      _seccionConfigBarra(),
      _seccionTerminalFisica(),
    ]),
  );

  Widget _tabDocumentos() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _seccionTipoDocumento(),
      _seccionPlantillasVinculadas(),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ch('Personalización del ticket', icon: Icons.receipt_long_outlined),
        TextFormField(
          initialValue: _config.mensajePiTicket,
          decoration: _deco('Mensaje al pie del ticket',
              hint: 'Ej: ¡Gracias por su visita, hasta pronto!'),
          onChanged: (v) => setState(
              () => _config = _config.copyWith(mensajePiTicket: v)),
        ),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(child: Text('Copias al imprimir',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          ...List.generate(3, (i) {
            final n = i + 1;
            final sel = _config.numeroCopias == n;
            return GestureDetector(
              onTap: () => setState(
                  () => _config = _config.copyWith(numeroCopias: n)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(left: 8),
                width: 40, height: 36,
                decoration: BoxDecoration(
                  color: sel ? _primario : _bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: sel ? _primario : _bdr),
                ),
                child: Center(child: Text('$n',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : _txt,
                    ))),
              ),
            );
          }),
        ]),
      ])),
      _seccionSerie(),
    ]),
  );

  Widget _tabCobro() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _seccionMetodosPagoTpv(),
      _seccionMetodosPago(),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ch('Acciones al cobrar', icon: Icons.touch_app_outlined),
        _sw('Pedir datos del cliente al cobrar',
            'Muestra un diálogo para NIF/email antes de generar el documento',
            _config.pedirDatosClienteAlCobrar,
            (v) => setState(() => _config = _config.copyWith(pedirDatosClienteAlCobrar: v))),
        _sw('Imprimir automáticamente al cobrar', null,
            _config.imprimirAuto,
            (v) => setState(() => _config = _config.copyWith(imprimirAuto: v))),
        _sw('Enviar por email automáticamente',
            'Envía el PDF al email del cliente si está disponible',
            _config.enviarPorEmailAuto,
            (v) => setState(() => _config = _config.copyWith(enviarPorEmailAuto: v))),
        _sw('Los precios ya incluyen IVA (PVP)',
            'Actívalo si los precios son el precio final con IVA incluido',
            _config.preciosIncluyenIva,
            (v) => setState(() => _config = _config.copyWith(preciosIncluyenIva: v))),
      ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ch('Propina', icon: Icons.volunteer_activism_outlined),
        _sw('Mostrar campo de propina al cobrar',
            'El cajero puede añadir propina antes de confirmar el cobro',
            _config.mostrarPropina,
            (v) => setState(() => _config = _config.copyWith(mostrarPropina: v))),
        if (_config.mostrarPropina) ...[
          const SizedBox(height: 10),
          TextFormField(
            initialValue: _config.porcentajesPropina,
            decoration: _deco('Porcentajes sugeridos',
                hint: 'Ej: 5,10,15  (separados por coma)'),
            onChanged: (v) => setState(
                () => _config = _config.copyWith(porcentajesPropina: v.trim())),
          ),
          const SizedBox(height: 4),
          Text('Aparecen como botones rápidos en la pantalla de cobro.',
              style: TextStyle(fontSize: 11, color: _sub)),
        ],
      ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ch('Descuentos', icon: Icons.local_offer_outlined),
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Descuento máximo por línea',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            SizedBox(height: 2),
            Text('Limita el % que un cajero puede aplicar. 100 = sin límite.',
                style: TextStyle(fontSize: 11, color: _sub)),
          ])),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: _config.descuentoMaximoPct.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: _deco('').copyWith(
                suffixText: '%',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n >= 0 && n <= 100) {
                  setState(() => _config = _config.copyWith(descuentoMaximoPct: n));
                }
              },
            ),
          ),
        ]),
      ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ch('Stock e inventario', icon: Icons.inventory_2_outlined),
        _sw('Bloquear venta si stock es 0',
            'Impide añadir al ticket un producto sin existencias',
            _config.bloquearVentaSinStock,
            (v) => setState(() => _config = _config.copyWith(bloquearVentaSinStock: v))),
      ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ch('Cancelaciones', icon: Icons.cancel_outlined),
        _sw('Pedir motivo al anular un ticket',
            'Obliga a introducir una justificación antes de anular',
            _config.pedirMotivoCancelacion,
            (v) => setState(() => _config = _config.copyWith(pedirMotivoCancelacion: v))),
      ])),
    ]),
  );

  Widget _tabNegocio() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _seccionDatosEmpresa(),
      _seccionModo(),
      if (_config.modo == ModoFacturacionTpv.resumenDiario) _seccionResumenDiario(),
      if (_config.modo == ModoFacturacionTpv.porVenta) _seccionPorVenta(),
    ]),
  );

  Widget _tabAvanzado() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ch('Seguridad y acceso', icon: Icons.lock_outline_rounded),
        TextFormField(
          initialValue: _config.pinAcceso,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: _deco('PIN de acceso al TPV',
              hint: '4 dígitos — vacío para sin PIN'),
          onChanged: (v) =>
              setState(() => _config = _config.copyWith(pinAcceso: v)),
        ),
        const SizedBox(height: 4),
        Text('El operario deberá introducir el PIN al abrir el TPV.',
            style: TextStyle(fontSize: 11, color: _sub)),
      ])),
      _seccionOpciones(),
      _seccionGenerarFacturaDia(),
      _seccionImportarCatalogo(),
      _seccionImagenesProductos(),
    ]),
  );

  // ── Pie guardar ───────────────────────────────────────────────────────────

  Widget _pieGuardar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    decoration: BoxDecoration(
      color: _surf,
      border: Border(top: BorderSide(color: _bdr)),
      boxShadow: _isDark ? [] : [BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 8,
        offset: const Offset(0, -2),
      )],
    ),
    child: SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _guardando ? null : _guardar,
        icon: _guardando
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_outlined, size: 18),
        label: Text(_guardando ? 'Guardando…' : 'Guardar configuración',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        style: FilledButton.styleFrom(
          backgroundColor: _primario,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
  );

  bool _generandoFacturaDia = false;

  Widget _seccionGenerarFacturaDia() {
    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('🧾 FACTURA DE LO QUE SE LLEVA HOY'),
        Text(
          'Genera una factura resumen con todos los tickets cobrados hoy que aún no tienen factura.',
          style: TextStyle(fontSize: 13, color: _sub),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _generandoFacturaDia ? null : _generarFacturaDia,
            icon: _generandoFacturaDia
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.receipt_long),
            label: Text(_generandoFacturaDia
                ? 'Generando…'
                : 'Generar factura del día'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1565C0)),
              foregroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    ));
  }

  Future<void> _generarFacturaDia() async {
    setState(() => _generandoFacturaDia = true);
    try {
      final factura = await _svc.generarFacturaResumenDiario(
        empresaId: widget.empresaId,
        fecha: DateTime.now(),
        config: _config,
        usuarioNombre: FirebaseAuth.instance.currentUser?.displayName ?? 'TPV',
      );
      if (!mounted) return;
      if (factura == null) {
        FluxToast.aviso(context, 'No hay ventas pendientes de facturar hoy');
      } else {
        FluxToast.exito(context,
            'Factura ${factura.numeroFactura} — ${factura.total.toStringAsFixed(2)} €',
            duration: const Duration(seconds: 5));
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _generandoFacturaDia = false);
    }
  }

  // ── Design system helpers ─────────────────────────────────────────────────

  // Card con sombra sutil — unidad visual principal
  Widget _card(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surf,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _bdr),
      boxShadow: _isDark ? [] : [BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
      )],
    ),
    child: child,
  );

  // Section header: icono en badge + texto bold dark
  Widget _ch(String titulo, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      if (icon != null) ...[
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _primario.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: _primario),
        ),
        const SizedBox(width: 10),
      ],
      Text(titulo, style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _txt,
        letterSpacing: -0.1,
      )),
    ]),
  );

  // Mantener _titulo para compatibilidad con secciones antiguas — ahora usa _ch
  Widget _titulo(String t) {
    final clean = t.replaceAll(RegExp(r'[🧾📄📋🖨️🗄️]'), '').trim();
    return _ch(clean);
  }

  // Switch con título + subtítulo opcional
  Widget _sw(String titulo, String? sub, bool val, ValueChanged<bool> onChange) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _txt)),
        subtitle: sub != null
            ? Text(sub, style: TextStyle(fontSize: 11, color: _sub))
            : null,
        value: val,
        activeColor: _primario,
        onChanged: onChange,
      );

  // InputDecoration uniforme
  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(fontSize: 12, color: _sub),
    labelStyle: TextStyle(fontSize: 13, color: _sub),
    filled: true,
    fillColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: _bdr)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: _bdr)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _primario, width: 1.5),
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  // ── MÉTODOS DE PAGO DEL TPV (cobrar) ────────────────────────────────────────

  Widget _seccionMetodosPagoTpv() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('MÉTODOS DE PAGO EN EL TPV'),
      _card(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Elige qué métodos de pago aparecen en la pantalla de cobro:',
            style: TextStyle(fontSize: 12, color: _sub),
          ),
          const SizedBox(height: 8),
          // Métodos predefinidos
          ..._metodosBase.map((m) {
            final (id, emoji, label) = m;
            final habilitado = _metodosHabilitados.contains(id);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('$emoji  $label'),
              value: habilitado,
              onChanged: (v) => setState(() {
                if (v == true) _metodosHabilitados.add(id);
                else _metodosHabilitados.remove(id);
              }),
            );
          }),
          // Métodos personalizados
          ..._metodosCustom.asMap().entries.map((e) {
            final idx = e.key;
            final nombre = e.value;
            final habilitado = _metodosHabilitados.contains('custom_$idx');
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Row(children: [
                Expanded(child: Text('⚡  $nombre')),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  onPressed: () => setState(() {
                    _metodosCustom.removeAt(idx);
                    _metodosHabilitados.remove('custom_$idx');
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              value: habilitado,
              onChanged: (v) => setState(() {
                if (v == true) _metodosHabilitados.add('custom_$idx');
                else _metodosHabilitados.remove('custom_$idx');
              }),
            );
          }),
          const Divider(height: 20),
          // Añadir método personalizado
          Row(children: [
            Expanded(
              child: TextField(
                controller: _nuevoMetodoCtrl,
                decoration: const InputDecoration(
                  hintText: 'Añadir método (ej: Bizum empresa)',
                  prefixIcon: Icon(Icons.add, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final nombre = _nuevoMetodoCtrl.text.trim();
                if (nombre.isEmpty) return;
                final idx = _metodosCustom.length;
                setState(() {
                  _metodosCustom.add(nombre);
                  _metodosHabilitados.add('custom_$idx');
                });
                _nuevoMetodoCtrl.clear();
              },
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
              child: const Text('Añadir'),
            ),
          ]),
        ],
      )),
    ],
  );


  Widget _seccionModo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('MODO DE FACTURACIÓN'),
      _card(Column(
        children: ModoFacturacionTpv.values.map((modo) => InkWell(
          onTap: () => setState(() => _config = _config.copyWith(modo: modo)),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Radio<ModoFacturacionTpv>(
                  value: modo,
                  groupValue: _config.modo,
                  onChanged: (v) => setState(() => _config = _config.copyWith(modo: v)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Row(children: [
                        Text(modo.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (modo == ModoFacturacionTpv.resumenDiario) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Recomendado',
                                style: TextStyle(fontSize: 10, color: Colors.green[800], fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(modo.descripcion, style: TextStyle(fontSize: 12, color: _sub)),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      )),
    ],
  );

  // ── TIPO DE DOCUMENTO AL COBRAR ───────────────────────────────────────────

  Widget _seccionTipoDocumento() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('TIPO DE DOCUMENTO AL COBRAR'),
      _card(Column(
        children: TipoDocumentoTpv.values.map((tipo) {
          final sel = _config.tipoDocumento == tipo;
          return InkWell(
            onTap: () => setState(() => _config = _config.copyWith(tipoDocumento: tipo)),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF1565C0).withValues(alpha: 0.08) : null,
                borderRadius: BorderRadius.circular(8),
                border: sel ? Border.all(color: const Color(0xFF1565C0), width: 1.5) : null,
              ),
              child: Row(children: [
                Text(tipo.icono, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tipo.nombre, style: TextStyle(fontWeight: FontWeight.w600,
                      color: sel ? const Color(0xFF1565C0) : null)),
                  Text(tipo.descripcion, style: TextStyle(fontSize: 11, color: _sub)),
                ])),
                if (sel) const Icon(Icons.check_circle, color: Color(0xFF1565C0)),
              ]),
            ),
          );
        }).toList(),
      )),
    ],
  );

  // ── PLANTILLAS PDF VINCULADAS ─────────────────────────────────────────────

  Widget _seccionPlantillasVinculadas() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('PLANTILLAS PDF VINCULADAS'),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Selecciona qué plantilla usar para cada tipo de documento. '
          'Si no seleccionas ninguna, se usa la marcada como "Por defecto".',
          style: TextStyle(fontSize: 12, color: _sub),
        ),
        const SizedBox(height: 12),
        _plantillaSelector('📋 Factura completa', _config.plantillaIdFactura,
            (id) => setState(() => _config = _config.copyWith(plantillaIdFactura: id))),
        const SizedBox(height: 8),
        _plantillaSelector('📄 Fact. simplificada', _config.plantillaIdSimplificada,
            (id) => setState(() => _config = _config.copyWith(plantillaIdSimplificada: id))),
        const SizedBox(height: 8),
        _plantillaSelector('🧾 Ticket', _config.plantillaIdTicket,
            (id) => setState(() => _config = _config.copyWith(plantillaIdTicket: id))),
        if (_plantillas.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'No hay plantillas creadas. Ve a Perfil → Plantillas PDF para crear una.',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
              )),
            ]),
          ),
      ])),
    ],
  );

  Widget _plantillaSelector(String label, String? valorActual, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 148, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(child: DropdownButtonFormField<String>(
          value: _plantillas.any((p) => p.id == valorActual) ? valorActual : null,
          decoration: const InputDecoration(
            isDense: true, border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          hint: const Text('⭐ Por defecto', style: TextStyle(fontSize: 12)),
          items: [
            const DropdownMenuItem<String>(value: null,
                child: Text('⭐ Por defecto', style: TextStyle(fontSize: 12))),
            ..._plantillas.map((p) => DropdownMenuItem(
              value: p.id,
              child: Text('${p.tipo.icon} ${p.nombre}',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: onChanged,
        )),
      ]),
    );
  }


  // ── SECCIÓN: RESUMEN DIARIO ───────────────────────────────────────────────────

  Widget _seccionResumenDiario() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('CONFIGURACIÓN RESUMEN DIARIO'),
      _card(Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hora de generación automática'),
            subtitle: Text(
              'Genera la factura diaria automáticamente a las ${_config.horaGeneracion.hour.toString().padLeft(2, '0')}:${_config.horaGeneracion.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: TextButton.icon(
              onPressed: _seleccionarHora,
              icon: const Icon(Icons.schedule, size: 18),
              label: Text('${_config.horaGeneracion.hour.toString().padLeft(2, '0')}:${_config.horaGeneracion.minute.toString().padLeft(2, '0')}'),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Facturación automática diaria'),
            subtitle: const Text('Genera automáticamente la factura de resumen al final del día',
                style: TextStyle(fontSize: 12)),
            value: _config.facturacionAutomatica,
            onChanged: (v) => setState(() => _config = _config.copyWith(facturacionAutomatica: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Solo si el cliente está identificado'),
            subtitle: const Text('Solo incluye pedidos con datos del cliente (nombre, email o teléfono)',
                style: TextStyle(fontSize: 12)),
            value: _config.soloSiClienteIdentificado,
            onChanged: (v) => setState(() => _config = _config.copyWith(soloSiClienteIdentificado: v)),
          ),
        ],
      )),
    ],
  );

  Future<void> _seleccionarHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _config.horaGeneracion,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0)),
        ),
        child: child!,
      ),
    );
    if (hora != null) {
      setState(() => _config = _config.copyWith(horaGeneracion: hora));
    }
  }

  // ── SECCIÓN: POR VENTA ────────────────────────────────────────────────────────

  Widget _seccionPorVenta() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('CONFIGURACIÓN POR VENTA'),
      _card(Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Generar automáticamente al cobrar'),
            subtitle: const Text('Crea la factura automáticamente cada vez que se cobra un pedido',
                style: TextStyle(fontSize: 12)),
            value: _config.generarAutomaticamente,
            onChanged: (v) => setState(() => _config = _config.copyWith(generarAutomaticamente: v)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'En este modo, cada pedido genera su propia factura inmediatamente al cobrar.',
              style: TextStyle(fontSize: 12, color: _sub),
            ),
          ),
        ],
      )),
    ],
  );

  // ── SECCIÓN: MÉTODOS DE PAGO ──────────────────────────────────────────────────

  Widget _seccionMetodosPago() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('MÉTODOS DE PAGO A INCLUIR'),
      _card(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecciona qué métodos de pago incluir en la facturación automática:',
            style: TextStyle(fontSize: 12, color: _sub),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('💵 Efectivo'),
            value: _config.incluirPedidosEfectivo,
            onChanged: (v) => setState(() => _config = _config.copyWith(incluirPedidosEfectivo: v ?? true)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('💳 Tarjeta'),
            value: _config.incluirPedidosTarjeta,
            onChanged: (v) => setState(() => _config = _config.copyWith(incluirPedidosTarjeta: v ?? true)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('🔀 Mixto (efectivo + tarjeta)'),
            value: _config.incluirPedidosMixto,
            onChanged: (v) => setState(() => _config = _config.copyWith(incluirPedidosMixto: v ?? true)),
          ),
        ],
      )),
    ],
  );

  // ── SECCIÓN: DATOS DE EMPRESA (para PDFs/facturas) ───────────────────────────

  Widget _seccionDatosEmpresa() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('DATOS DE EMPRESA EN FACTURAS'),
      _card(Column(
        children: [
          Text(
            'Si el nombre de empresa aparece incorrecto en los PDFs, '
            'escríbelo aquí. Tiene prioridad sobre el documento de Firestore.',
            style: TextStyle(fontSize: 12, color: _sub),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _config.nombreEmpresa,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre de empresa',
              hintText: 'Ej: Mi Negocio S.L.',
              prefixIcon: Icon(Icons.business_outlined),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(
                () => _config = _config.copyWith(nombreEmpresa: v.trim())),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _config.cifEmpresa,
            decoration: const InputDecoration(
              labelText: 'NIF / CIF',
              hintText: 'Ej: B12345678',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(
                () => _config = _config.copyWith(cifEmpresa: v.trim())),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _config.direccionEmpresa,
            decoration: const InputDecoration(
              labelText: 'Dirección fiscal',
              hintText: 'Ej: Calle Mayor 1, 28001 Madrid',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(
                () => _config = _config.copyWith(direccionEmpresa: v.trim())),
          ),
        ],
      )),
    ],
  );

  // ── SECCIÓN: SERIE DE FACTURA ─────────────────────────────────────────────────

  Widget _seccionSerie() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('SERIE DE FACTURACIÓN'),
      _card(Column(
        children: [
          TextFormField(
            initialValue: _config.serieFactura,
            decoration: const InputDecoration(
              labelText: 'Prefijo de serie',
              hintText: 'TPV-',
              helperText: 'Prefijo para la numeración de facturas del TPV',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _config = _config.copyWith(serieFactura: v)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _config.diasVencimiento.toString(),
            decoration: const InputDecoration(
              labelText: 'Días de vencimiento',
              hintText: '0',
              helperText: 'Días hasta el vencimiento (0 = pago inmediato)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final dias = int.tryParse(v) ?? 0;
              setState(() => _config = _config.copyWith(diasVencimiento: dias));
            },
          ),
        ],
      )),
    ],
  );

  // ── SECCIÓN: OPCIONES AVANZADAS ───────────────────────────────────────────────

  Widget _seccionOpciones() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('OPCIONES AVANZADAS'),
      _card(Column(
        children: [
          // ── IVA ────────────────────────────────────────────────────────
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Precios ya incluyen IVA (PVP)'),
            subtitle: const Text(
              'Actívalo si tus precios son el precio final (ej: 12€ = base + IVA). '
              'La base imponible se calculará dividiendo entre (1 + %IVA).',
              style: TextStyle(fontSize: 12)),
            value: _config.preciosIncluyenIva,
            onChanged: (v) => setState(() =>
                _config = _config.copyWith(preciosIncluyenIva: v)),
          ),
          if (_config.preciosIncluyenIva)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'Ejemplo con IVA 21%: Precio 12,10€ → Base 10€ + IVA 2,10€',
                style: TextStyle(fontSize: 11, color: _txt),
              ),
            ),
          const Divider(height: 20),
          // ── Veri*Factu ─────────────────────────────────────────────────
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aplicar Veri*Factu'),
            subtitle: const Text('Genera código QR y huella digital según RD 1007/2023',
                style: TextStyle(fontSize: 12)),
            value: _config.aplicarVeriFactu,
            onChanged: (v) => setState(() => _config = _config.copyWith(aplicarVeriFactu: v)),
          ),
          if (_config.aplicarVeriFactu)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Veri*Factu requiere certificado digital instalado en la empresa',
                      style: TextStyle(fontSize: 11, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      )),
    ],
  );

  // ── IMPRESORA WINDOWS ─────────────────────────────────────────────────────────

  // ── TERMINAL FÍSICA DE COBRO ────────────────────────────────────────────────

  Widget _seccionTerminalFisica() {
    final protocolo = _config.terminalFisicaProtocolo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('💳 TERMINAL FÍSICA (DATÁFONO)'),
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conecta un datáfono WiFi para que el TPV envíe automáticamente el importe al terminal. '
              'Sin configuración funciona en modo manual (el cajero confirma tras cobrar).',
              style: TextStyle(fontSize: 12, color: _sub),
            ),
            const SizedBox(height: 16),
            // Selector de protocolo
            const Text('Tipo de terminal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ('manual',   '🖐 Manual',       'Confirma tú mismo tras cobrar'),
                ('sumup',    '📱 SumUp Solo',   'API local WiFi'),
                ('generico', '🌐 Otro (HTTP)',  'Terminal con API REST genérica'),
              ].map(((String id, String label, String desc) e) {
                final sel = protocolo == e.$1;
                return ChoiceChip(
                  label: Text(e.$2, style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  tooltip: e.$3,
                  onSelected: (_) => setState(() => _config = _config.copyWith(terminalFisicaProtocolo: e.$1)),
                  selectedColor: const Color(0xFF1565C0).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: sel ? const Color(0xFF1565C0) : null,
                    fontWeight: sel ? FontWeight.bold : null,
                  ),
                );
              }).toList(),
            ),
            if (protocolo != 'manual') ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _terminalIpCtrl,
                    onChanged: (_) => setState(() => _terminalTestResultado = null),
                    decoration: const InputDecoration(
                      labelText: 'IP del terminal',
                      hintText: 'Ej: 192.168.1.50',
                      prefixIcon: Icon(Icons.router_outlined),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _terminalPuertoCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _terminalTestResultado = null),
                    decoration: const InputDecoration(
                      labelText: 'Puerto',
                      isDense: true,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                FilledButton.icon(
                  onPressed: _terminalTestando ? null : _testTerminal,
                  icon: _terminalTestando
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.wifi_find, size: 16),
                  label: Text(_terminalTestando ? 'Probando...' : 'Probar conexión'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                if (_terminalTestResultado != null) ...[
                  const SizedBox(width: 12),
                  Icon(
                    _terminalTestResultado!.startsWith('✓') ? Icons.check_circle : Icons.error_outline,
                    color: _terminalTestResultado!.startsWith('✓') ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: Text(_terminalTestResultado!, style: TextStyle(
                    fontSize: 12,
                    color: _terminalTestResultado!.startsWith('✓') ? Colors.green.shade700 : Colors.red,
                  ))),
                ],
              ]),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Modo manual: el TPV mostrará el importe en grande y esperará a que confirmes el cobro en el datáfono.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  )),
                ]),
              ),
            ],
          ],
        )),
      ],
    );
  }

  Future<void> _testTerminal() async {
    final ip = _terminalIpCtrl.text.trim();
    final puerto = int.tryParse(_terminalPuertoCtrl.text.trim()) ?? 8080;
    final protocolo = _config.terminalFisicaProtocolo;
    if (ip.isEmpty) {
      setState(() => _terminalTestResultado = '✗ Introduce la IP del terminal');
      return;
    }
    setState(() { _terminalTestando = true; _terminalTestResultado = null; });
    TerminalFisicaService().configurar(
      ip: ip,
      puerto: puerto,
      protocolo: ProtocoloTerminal.values.firstWhere(
        (p) => p.name == protocolo, orElse: () => ProtocoloTerminal.manual,
      ),
    );
    final ok = await TerminalFisicaService().verificarConexion();
    if (mounted) {
      setState(() {
        _terminalTestando = false;
        _terminalTestResultado = ok
            ? '✓ Terminal accesible en $ip:$puerto'
            : '✗ No se pudo conectar a $ip:$puerto';
      });
    }
  }

  // ── IMPRESORA DE BARRA (segunda impresora para bebidas) ────────────────────

  Widget _seccionImpresoraBarra() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('🍺 IMPRESORA DE BARRA (opcional)'),
      _card(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Impresora exclusiva para comandas de barra. Si no se configura, usa la impresora principal.',
            style: TextStyle(fontSize: 12, color: _sub),
          ),
          const SizedBox(height: 14),
          // Selector modo
          Container(
            decoration: BoxDecoration(
              color: (_isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _barraUsaTcp = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_barraUsaTcp ? const Color(0xFF1565C0) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.usb, size: 16, color: !_barraUsaTcp ? Colors.white : _sub),
                    const SizedBox(width: 6),
                    Text('Puerto COM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: !_barraUsaTcp ? Colors.white : _sub)),
                  ]),
                ),
              )),
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _barraUsaTcp = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _barraUsaTcp ? const Color(0xFF1565C0) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.wifi, size: 16, color: _barraUsaTcp ? Colors.white : _sub),
                    const SizedBox(width: 6),
                    Text('Red (WiFi)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _barraUsaTcp ? Colors.white : _sub)),
                  ]),
                ),
              )),
            ]),
          ),
          const SizedBox(height: 14),
          if (!_barraUsaTcp)
            TextField(
              controller: _barraPuertoCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Puerto COM barra',
                hintText: 'Ej: COM4',
                prefixIcon: Icon(Icons.usb),
              ),
            )
          else
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _barraIpCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IP impresora barra',
                    hintText: 'Ej: 192.168.1.101',
                    prefixIcon: Icon(Icons.wifi),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _barraPortCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Puerto'),
                ),
              ),
            ]),
          const SizedBox(height: 8),
          Text(
            _barraUsaTcp
                ? (_barraIpCtrl.text.isNotEmpty ? 'Impresora barra: ${_barraIpCtrl.text}:${_barraPortCtrl.text}' : 'Sin configurar')
                : (_barraPuertoCtrl.text.isNotEmpty ? 'Impresora barra: ${_barraPuertoCtrl.text}' : 'Sin configurar — usará la impresora principal'),
            style: TextStyle(
              fontSize: 11,
              color: (_barraUsaTcp ? _barraIpCtrl.text : _barraPuertoCtrl.text).isNotEmpty
                  ? Colors.green.shade700
                  : _sub,
            ),
          ),
        ],
      )),
    ],
  );

  // ── CONFIG ESPECÍFICA DE BARRA ──────────────────────────────────────────────

  Widget _seccionConfigBarra() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('⚙️ COMPORTAMIENTO DE BARRA'),
      _card(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notificación visual al llegar comandas'),
            subtitle: const Text('Muestra un aviso en pantalla cuando llega un pedido nuevo a barra/cocina',
                style: TextStyle(fontSize: 12)),
            value: _config.notificacionVisualBarra,
            onChanged: (v) => setState(() => _config = _config.copyWith(notificacionVisualBarra: v)),
          ),
          const Divider(height: 20),
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Alerta de tiempo en barra', style: TextStyle(fontWeight: FontWeight.w500)),
                Text('Minutos antes de marcar la comanda en rojo', style: TextStyle(fontSize: 12, color: _sub)),
              ]),
            ),
            Row(children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _config.tiempoAlertaBarraMinutos > 1
                    ? () => setState(() => _config = _config.copyWith(
                        tiempoAlertaBarraMinutos: _config.tiempoAlertaBarraMinutos - 1))
                    : null,
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${_config.tiempoAlertaBarraMinutos} min',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _config.tiempoAlertaBarraMinutos < 30
                    ? () => setState(() => _config = _config.copyWith(
                        tiempoAlertaBarraMinutos: _config.tiempoAlertaBarraMinutos + 1))
                    : null,
              ),
            ]),
          ]),
        ],
      )),
    ],
  );

  Widget _seccionImpresoraWindows() {
    final conectadaColor = _winConectada ? Colors.green.shade700 : _sub;
    final estadoTexto = _winConectada
        ? (_winUsaTcp
            ? 'Conectada vía red (${_winIpCtrl.text})'
            : 'Conectada en $_winPuerto')
        : 'Sin conexión — configura el puerto o la IP';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('🖨️ IMPRESORA WINDOWS'),
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado
            Row(children: [
              Icon(_winConectada ? Icons.check_circle : Icons.error_outline,
                  color: _winConectada ? Colors.green : Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(estadoTexto,
                  style: TextStyle(color: conectadaColor,
                      fontWeight: FontWeight.w500, fontSize: 13))),
            ]),
            const SizedBox(height: 14),
            // Selector de modo
            Container(
              decoration: BoxDecoration(
                color: (_isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _winUsaTcp = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_winUsaTcp ? const Color(0xFF1565C0) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.usb, size: 16,
                          color: !_winUsaTcp ? Colors.white : _sub),
                      const SizedBox(width: 6),
                      Text('Bluetooth / USB',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: !_winUsaTcp ? Colors.white : _sub)),
                    ]),
                  ),
                )),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _winUsaTcp = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _winUsaTcp ? const Color(0xFF1565C0) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.wifi, size: 16,
                          color: _winUsaTcp ? Colors.white : _sub),
                      const SizedBox(width: 6),
                      Text('Red (WiFi)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: _winUsaTcp ? Colors.white : _sub)),
                    ]),
                  ),
                )),
              ]),
            ),
            const SizedBox(height: 14),
            // Campos según modo
            if (!_winUsaTcp) ...[
              Row(children: [
                Expanded(child: TextField(
                  controller: _winPuertoCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Puerto COM',
                    hintText: 'Ej: COM3',
                    prefixIcon: Icon(Icons.settings_input_component, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                )),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _winDetectando ? null : _guardarPuertoWindows,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                  child: const Text('Guardar'),
                ),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _winDetectando ? null : _autoDetectarPuertoWindows,
                  icon: _winDetectando
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search, size: 18),
                  label: Text(_winDetectando ? 'Buscando COM1–COM20…' : 'Auto-detectar'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1565C0)),
                    foregroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
            ] else ...[
              Row(children: [
                Expanded(flex: 3, child: TextField(
                  controller: _winIpCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'IP impresora',
                    hintText: 'Ej: 192.168.1.50',
                    prefixIcon: Icon(Icons.router, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: TextField(
                  controller: _winPortCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Puerto',
                    hintText: '9100',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                )),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _winDetectando ? null : _guardarIpWindows,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                  child: _winDetectando
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar'),
                ),
              ]),
              const SizedBox(height: 6),
              Text('Puerto RAW estándar: 9100. Asegúrate de que la impresora está en la misma red.',
                  style: TextStyle(fontSize: 11, color: _sub)),
            ],
            const Divider(height: 28),
            _titulo('🗄️ CAJÓN REGISTRADORA'),
            Text('Ajustes guardados en la nube por empresa.',
                style: TextStyle(fontSize: 11, color: _sub)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Abrir cajón al cobrar'),
              subtitle: const Text('Envía el comando ESC/POS de apertura tras cada cobro',
                  style: TextStyle(fontSize: 12)),
              value: _config.abrirCajonAlCobrar,
              onChanged: (v) => setState(() => _config = _config.copyWith(abrirCajonAlCobrar: v)),
            ),
            if (_config.abrirCajonAlCobrar) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Solo en pagos en efectivo'),
                subtitle: const Text('No abrirá con tarjeta, Bizum, etc.',
                    style: TextStyle(fontSize: 12)),
                value: _config.abrirCajonSoloEfectivo,
                onChanged: (v) => setState(() => _config = _config.copyWith(abrirCajonSoloEfectivo: v)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pin del cajón'),
                subtitle: const Text('Pin 2: estándar (99%). Pin 5: cajas antiguas.',
                    style: TextStyle(fontSize: 12)),
                trailing: DropdownButton<int>(
                  value: _config.drawerPin,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Pin 2 (estándar)')),
                    DropdownMenuItem(value: 1, child: Text('Pin 5')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _config = _config.copyWith(drawerPin: v));
                  },
                ),
              ),
            ],
          ],
        )),
      ],
    );
  }

  Future<void> _guardarPuertoWindows() async {
    final puerto = _winPuertoCtrl.text.trim().toUpperCase();
    if (puerto.isEmpty) return;
    setState(() => _winDetectando = true);
    try {
      final svc = ImpresoraWindowsService();
      await svc.setPuerto(puerto);
      setState(() { _winPuerto = puerto; _winConectada = svc.estaConectada; });
      if (mounted) {
        _winConectada
            ? FluxToast.exito(context, 'Impresora detectada en $puerto')
            : FluxToast.aviso(context, '$puerto guardado pero no responde. ¿Encendida?');
      }
    } finally {
      if (mounted) setState(() => _winDetectando = false);
    }
  }

  Future<void> _guardarIpWindows() async {
    final ip = _winIpCtrl.text.trim();
    final port = int.tryParse(_winPortCtrl.text.trim()) ?? 9100;
    if (ip.isEmpty) return;
    setState(() => _winDetectando = true);
    try {
      final svc = ImpresoraWindowsService();
      await svc.setIp(ip, port: port);
      setState(() => _winConectada = svc.estaConectada);
      if (mounted) {
        _winConectada
            ? FluxToast.exito(context, 'Impresora de red detectada en $ip:$port')
            : FluxToast.aviso(context, '$ip:$port guardado pero no responde. ¿En la misma red?');
      }
    } finally {
      if (mounted) setState(() => _winDetectando = false);
    }
  }

  Future<void> _autoDetectarPuertoWindows() async {
    setState(() => _winDetectando = true);
    try {
      final svc = ImpresoraWindowsService();
      await svc.forzarDeteccion();
      setState(() {
        _winPuerto = svc.puertoActual;
        _winConectada = svc.estaConectada;
        if (_winPuerto != null) _winPuertoCtrl.text = _winPuerto!;
      });
      if (mounted) {
        _winConectada
            ? FluxToast.exito(context, 'Impresora detectada en $_winPuerto')
            : FluxToast.aviso(context, 'No detectada. ¿Encendida y emparejada por Bluetooth?');
      }
    } finally {
      if (mounted) setState(() => _winDetectando = false);
    }
  }

  // ── BLUETOOTH ──────────────────────────────────────────────────────────────────

  Widget _seccionBluetooth() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('IMPRESORA BLUETOOTH'),
      _card(Column(
        children: [
          if (_btConectada && _nombreImpresora != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bluetooth_connected, color: Colors.green, size: 28),
              title: Text('Conectada: $_nombreImpresora'),
              subtitle: const Text('Impresora lista para usar', style: TextStyle(fontSize: 12)),
              trailing: TextButton.icon(
                onPressed: _desconectarBluetooth,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Desconectar'),
              ),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bluetooth_disabled, color: _sub, size: 28),
              title: const Text('Sin impresora conectada'),
              subtitle: const Text('Conecta una impresora Bluetooth para imprimir tickets', style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _configurarBluetooth,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Buscar y conectar impresora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      )),
    ],
  );

  Future<void> _configurarBluetooth() async {
    try {
      final impresoras = await ImpressoraBluetooth().escanearImpresoras();
      if (!mounted) return;
      
      if (impresoras.isEmpty) {
        FluxToast.aviso(context,
            'No se encontraron impresoras Bluetooth vinculadas.\n'
            'Vincula la impresora en los ajustes de Bluetooth primero.',
            duration: const Duration(seconds: 4));
        return;
      }

      final seleccionada = await showDialog<BluetoothDevice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Seleccionar impresora'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: ListView.builder(
              itemCount: impresoras.length,
              itemBuilder: (_, i) {
                final imp = impresoras[i];
                return ListTile(
                  leading: const Icon(Icons.print),
                  title: Text(imp.name ?? 'Sin nombre'),
                  subtitle: Text(imp.address ?? ''),
                  onTap: () => Navigator.pop(ctx, imp),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (seleccionada != null) {
        await ImpressoraBluetooth().conectar(seleccionada);
        await _verificarBluetooth();
        if (mounted) FluxToast.exito(context, 'Conectado a ${seleccionada.name}');
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }

  Future<void> _desconectarBluetooth() async {
    await ImpressoraBluetooth().olvidarImpresora();
    await _verificarBluetooth();
    if (mounted) FluxToast.info(context, 'Impresora desconectada');
  }

  // ── IMPORTAR CATÁLOGO ──────────────────────────────────────────────────────────

  Widget _seccionImportarCatalogo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('IMPORTAR CATÁLOGO (CSV)'),
      _card(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Importa productos en masa desde un archivo CSV o Excel.',
            style: TextStyle(fontSize: 13, color: _sub),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _mostrarInfoPlantilla,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Info plantilla'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _mostrarInfoImportacion,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Importar CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      )),
    ],
  );

  void _mostrarInfoPlantilla() {
    const plantilla = 'nombre,categoria,precio,descripcion,iva,sku,codigo_barras,stock\n'
        'Coca-Cola 33cl,Bebidas,1.50,Refresco de cola,10,COCA33,5449000000996,100\n'
        'Cerveza Estrella 33cl,Bebidas,2.00,Cerveza nacional,10,CERV33,8410793504039,200\n'
        'Café solo,Cafetería,1.20,Café espresso,10,CAFE01,,\n'
        'Jamón serrano,Tapas,3.50,Ración de jamón ibérico,10,JAM01,,50';
        
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Plantilla CSV'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Formato esperado del archivo CSV:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  plantilla,
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Copia este contenido y pégalo en Excel o Google Sheets. '
                'Guarda como CSV y súbelo desde "Importar CSV".',
                style: TextStyle(fontSize: 12, color: _sub),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarInfoImportacion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportarCatalogoCsvScreen(empresaId: widget.empresaId),
      ),
    );
  }

  // ── IMÁGENES DE PRODUCTOS ──────────────────────────────────────────────────────

  Widget _seccionImagenesProductos() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('IMÁGENES DE PRODUCTOS'),
      _card(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestiona las imágenes de los productos de tu catálogo.',
            style: TextStyle(fontSize: 13, color: _sub),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _mostrarInfoImagenes,
              icon: const Icon(Icons.image),
              label: const Text('Gestionar imágenes del catálogo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      )),
    ],
  );

  void _mostrarInfoImagenes() async {
    // Cargar productos del catálogo
    final productosSnap = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('catalogo')
        .get();

    if (!mounted) return;

    if (productosSnap.docs.isEmpty) {
      FluxToast.aviso(context, 'No hay productos en el catálogo');
      return;
    }

    // Mostrar diálogo con lista de productos
    showDialog(
      context: context,
      builder: (_) => _DialogoGestionImagenes(
        empresaId: widget.empresaId,
        productos: productosSnap.docs,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO GESTIÓN DE IMÁGENES DE PRODUCTOS
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoGestionImagenes extends StatefulWidget {
  final String empresaId;
  final List<QueryDocumentSnapshot> productos;

  const _DialogoGestionImagenes({
    required this.empresaId,
    required this.productos,
  });

  @override
  State<_DialogoGestionImagenes> createState() => _DialogoGestionImagenesState();
}

class _DialogoGestionImagenesState extends State<_DialogoGestionImagenes> {
  bool _subiendo = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gestionar Imágenes de Productos'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: ListView.builder(
          itemCount: widget.productos.length,
          itemBuilder: (context, index) {
            final producto = widget.productos[index];
            final data = producto.data() as Map<String, dynamic>;
            final nombre = data['nombre'] as String? ?? 'Sin nombre';
            final imagenUrl = data['imagen_url'] as String?;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: imagenUrl != null && imagenUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          imagenUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.image, color: Color(0xFF9CA3AF)),
                      ),
                title: Text(nombre),
                subtitle: imagenUrl != null && imagenUrl.isNotEmpty
                    ? const Text('Imagen asignada', style: TextStyle(color: Colors.green, fontSize: 11))
                    : const Text('Sin imagen', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (imagenUrl != null && imagenUrl.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        tooltip: 'Eliminar imagen',
                        onPressed: () => _eliminarImagen(producto.id, imagenUrl),
                      ),
                    IconButton(
                      icon: const Icon(Icons.upload),
                      tooltip: 'Subir imagen',
                      onPressed: () => _subirImagen(producto.id, nombre),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        if (_subiendo)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        TextButton(
          onPressed: _subiendo ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _subirImagen(String productoId, String nombreProducto) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _subiendo = true);

      final file = result.files.first;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('empresas/${widget.empresaId}/catalogo/$fileName');

      // Detectar content-type por extensión
      final ext = file.extension?.toLowerCase() ?? '';
      final contentType = switch (ext) {
        'webp' => 'image/webp',
        'png'  => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => 'image/jpeg',
      };
      final meta = SettableMetadata(contentType: contentType);

      // Subir archivo — usa bytes siempre que estén disponibles (funciona en Web, Windows, Android, iOS)
      if (kIsWeb || file.bytes != null) {
        await storageRef.putData(file.bytes!, meta);
      } else if (file.path != null) {
        await storageRef.putFile(File(file.path!), meta);
      } else {
        throw Exception('No se pudieron leer los bytes del archivo');
      }

      // Obtener URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Actualizar Firestore
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('catalogo')
          .doc(productoId)
          .update({'imagen_url': downloadUrl});

      if (!mounted) return;

      FluxToast.exito(context, 'Imagen subida para $nombreProducto');
      setState(() => _subiendo = false);
    } catch (e) {
      if (!mounted) return;
      FluxToast.error(context, 'Error al subir imagen: $e');
      setState(() => _subiendo = false);
    }
  }

  Future<void> _eliminarImagen(String productoId, String imagenUrl) async {
    try {
      setState(() => _subiendo = true);

      // Eliminar de Storage
      try {
        final ref = FirebaseStorage.instance.refFromURL(imagenUrl);
        await ref.delete();
      } catch (e) {
        print('No se pudo eliminar de Storage: $e');
      }

      // Actualizar Firestore
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('catalogo')
          .doc(productoId)
          .update({'imagen_url': FieldValue.delete()});

      if (!mounted) return;

      FluxToast.exito(context, 'Imagen eliminada');
      setState(() => _subiendo = false);
    } catch (e) {
      if (!mounted) return;
      FluxToast.error(context, 'Error al eliminar imagen: $e');
      setState(() => _subiendo = false);
    }
  }
}
