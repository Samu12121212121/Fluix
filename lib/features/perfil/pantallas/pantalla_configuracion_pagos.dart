import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/configuracion_pagos_service.dart';

class PantallaConfiguracionPagos extends StatefulWidget {
  final String empresaId;
  const PantallaConfiguracionPagos({super.key, required this.empresaId});

  @override
  State<PantallaConfiguracionPagos> createState() => _State();
}

class _State extends State<PantallaConfiguracionPagos> {
  final _svc = ConfiguracionPagosService();
  ConfiguracionPagos? _config;
  bool _cargando = true;

  final _redsysMerchantCtrl = TextEditingController();
  final _redsysTerminalCtrl = TextEditingController(text: '001');
  String? _bancoSel;

  static const _bancos = [
    {'id': 'caixabank', 'nombre': 'CaixaBank', 'icono': '🏦'},
    {'id': 'santander', 'nombre': 'Banco Santander', 'icono': '🔴'},
    {'id': 'bbva', 'nombre': 'BBVA', 'icono': '🔵'},
    {'id': 'sabadell', 'nombre': 'Banco Sabadell', 'icono': '🟢'},
    {'id': 'bankinter', 'nombre': 'Bankinter', 'icono': '🟠'},
  ];

  static const _kP = Color(0xFF0D47A1);
  static const _kOk = Color(0xFF2E7D32);
  static const _kWarn = Color(0xFFF57F17);
  static const _kErr = Color(0xFFC62828);

  @override
  void initState() { super.initState(); _cargar(); }

  @override
  void dispose() { _redsysMerchantCtrl.dispose(); _redsysTerminalCtrl.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    try {
      final c = await _svc.obtener(widget.empresaId);
      if (!mounted) return;
      _redsysMerchantCtrl.text = c.redsysMerchantCode ?? '';
      _redsysTerminalCtrl.text = c.redsysTerminal ?? '001';
      _bancoSel = c.bancoId;
      setState(() { _config = c; _cargando = false; });
    } catch (e) {
      if (mounted) { setState(() => _cargando = false); _snack('Error: $e', err: true); }
    }
  }

  void _snack(String m, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: err ? _kErr : _kOk));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Configuración de pagos', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _kP, foregroundColor: Colors.white, elevation: 0,
      ),
      body: _cargando ? const Center(child: CircularProgressIndicator())
          : _config == null ? const Center(child: Text('Error cargando datos'))
          : _body(),
    );
  }

  Widget _body() {
    final c = _config!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _resumen(c), const SizedBox(height: 20),
        _secStripe(c), const SizedBox(height: 16),
        _secRedsys(c), const SizedBox(height: 16),
        _secBanco(c), const SizedBox(height: 16),
        _secMetodos(c), const SizedBox(height: 32),
      ]),
    );
  }

  // ── RESUMEN ─────────────────────────────────────────────────────────────
  Widget _resumen(ConfiguracionPagos c) {
    final cx = [
      if (c.stripeConectado) '💳 Stripe',
      if (c.redsysConectado) '🏪 Redsys',
      if (c.bancoConectado) '🏦 ${c.bancoNombre ?? "Banco"}',
    ];
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1565C0)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pasarelas de pago', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(cx.isEmpty ? 'Sin conexiones activas' : cx.join(' · '),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
          ])),
        ]),
        if (c.bancoConectado && c.bancoProximoAExpirar) ...[
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4))),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Conexión bancaria caduca en ${c.diasHastaExpiracionBanco} días',
                  style: const TextStyle(color: Colors.white, fontSize: 13))),
            ])),
        ],
      ]),
    );
  }

  // ── STRIPE ──────────────────────────────────────────────────────────────
  Widget _secStripe(ConfiguracionPagos c) {
    return _card(Icons.credit_card, 'Stripe', 'Tarjeta, Apple Pay, Google Pay',
      const Color(0xFF635BFF), c.stripeConectado,
      c.stripeConectado ? _stripeOn(c) : _stripeOff());
  }

  Widget _stripeOn(ConfiguracionPagos c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _info(Icons.check_circle, 'Cuenta', c.stripeDisplayName ?? c.stripeAccountId ?? '—', color: _kOk),
    if (c.stripeFechaConexion != null) _info(Icons.calendar_today, 'Desde', DateFormat('dd/MM/yyyy').format(c.stripeFechaConexion!)),
    const SizedBox(height: 16),
    Row(children: [
      Expanded(child: OutlinedButton.icon(onPressed: () async {
        final u = Uri.parse('https://dashboard.stripe.com');
        if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
      }, icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Dashboard'),
        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF635BFF),
          side: const BorderSide(color: Color(0xFF635BFF)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
      const SizedBox(width: 12),
      Expanded(child: _btnDesconectar('Stripe', () => _svc.desconectarStripe(widget.empresaId))),
    ]),
  ]);

  Widget _stripeOff() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _infoBox(const Color(0xFFF3F0FF), const Color(0xFF635BFF),
      'Conecta tu cuenta Stripe para recibir pagos con tarjeta, Apple Pay y Google Pay directamente en tu cuenta.'),
    const SizedBox(height: 16),
    _btnConectar('Conectar con Stripe', const Color(0xFF635BFF), Icons.link, _conectarStripe),
  ]);

  // ── REDSYS ──────────────────────────────────────────────────────────────
  Widget _secRedsys(ConfiguracionPagos c) {
    return _card(Icons.point_of_sale, 'Redsys — TPV Virtual', 'Pasarela bancaria española',
      const Color(0xFFE65100), c.redsysConectado,
      c.redsysConectado ? _redsysOn(c) : _redsysOff());
  }

  Widget _redsysOn(ConfiguracionPagos c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _info(Icons.store, 'Código', c.redsysMerchantCode ?? '—', color: _kOk),
    _info(Icons.dvr, 'Terminal', c.redsysTerminal ?? '001'),
    if (c.redsysFechaConexion != null) _info(Icons.calendar_today, 'Desde', DateFormat('dd/MM/yyyy').format(c.redsysFechaConexion!)),
    const SizedBox(height: 16),
    _btnDesconectar('Redsys', () => _svc.desconectarRedsys(widget.empresaId)),
  ]);

  Widget _redsysOff() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _infoBox(const Color(0xFFFFF3E0), const Color(0xFFE65100),
      'Introduce los datos de tu TPV virtual. Los proporciona tu banco al contratar la pasarela Redsys.'),
    const SizedBox(height: 16),
    TextField(controller: _redsysMerchantCtrl,
      decoration: _deco('Código de comercio *', Icons.store),
      keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
    const SizedBox(height: 12),
    TextField(controller: _redsysTerminalCtrl,
      decoration: _deco('Terminal (por defecto 001)', Icons.dvr),
      keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
    const SizedBox(height: 16),
    _btnConectar('Configurar Redsys', const Color(0xFFE65100), Icons.link, _conectarRedsys),
  ]);

  // ── BANCO PSD2 ──────────────────────────────────────────────────────────
  Widget _secBanco(ConfiguracionPagos c) {
    return _card(Icons.account_balance, 'Cuenta bancaria',
      'Open Banking (PSD2) — Facturación automática',
      const Color(0xFF1B5E20), c.bancoConectado,
      c.bancoConectado ? _bancoOn(c) : _bancoOff());
  }

  Widget _bancoOn(ConfiguracionPagos c) {
    final exp = c.bancoExpirado;
    final prox = c.bancoProximoAExpirar;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _info(Icons.account_balance, 'Banco', c.bancoNombre ?? '—', color: exp ? _kErr : _kOk),
      if (c.bancoIban != null) _info(Icons.credit_card, 'IBAN', _mask(c.bancoIban!)),
      if (c.bancoFechaConexion != null) _info(Icons.calendar_today, 'Conectado', DateFormat('dd/MM/yyyy').format(c.bancoFechaConexion!)),
      if (c.bancoFechaExpiracion != null) _info(
        exp ? Icons.error : Icons.schedule, 'Consentimiento',
        exp ? 'Expirado' : prox ? 'Caduca en ${c.diasHastaExpiracionBanco} días'
            : 'Válido hasta ${DateFormat('dd/MM/yyyy').format(c.bancoFechaExpiracion!)}',
        color: exp ? _kErr : prox ? _kWarn : null),
      if (exp || prox) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: exp ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: exp ? const Color(0xFFEF9A9A) : const Color(0xFFFFE082))),
          child: Row(children: [
            Icon(exp ? Icons.error_outline : Icons.warning_amber_rounded, color: exp ? _kErr : _kWarn, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              exp ? 'La conexión ha caducado. Los ingresos ya no se facturan automáticamente.'
                  : 'La conexión caduca pronto. Renuévala para no interrumpir la facturación.',
              style: TextStyle(fontSize: 13, color: exp ? _kErr : _kWarn))),
          ])),
      ],
      const SizedBox(height: 16),
      Row(children: [
        if (exp || prox) ...[
          Expanded(child: ElevatedButton.icon(onPressed: _renovarBanco,
            icon: const Icon(Icons.refresh, size: 18), label: const Text('Renovar'),
            style: ElevatedButton.styleFrom(backgroundColor: _kOk, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
          const SizedBox(width: 12),
        ],
        Expanded(child: _btnDesconectar(c.bancoNombre ?? 'Banco', () => _svc.desconectarBanco(widget.empresaId))),
      ]),
    ]);
  }

  Widget _bancoOff() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _infoBox(const Color(0xFFE8F5E9), const Color(0xFF1B5E20),
      'Conecta tu cuenta bancaria para que los ingresos recibidos generen facturas automáticamente. '
      'Open Banking (PSD2) — solo lectura, no podemos mover tu dinero.'),
    const SizedBox(height: 16),
    const Text('Selecciona tu banco:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    const SizedBox(height: 10),
    Wrap(spacing: 10, runSpacing: 10, children: _bancos.map((b) {
      final sel = _bancoSel == b['id'];
      return GestureDetector(onTap: () => setState(() => _bancoSel = b['id']),
        child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF1B5E20) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? const Color(0xFF1B5E20) : Colors.grey.shade300, width: sel ? 2 : 1),
            boxShadow: sel ? [BoxShadow(color: const Color(0xFF1B5E20).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))] : null),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(b['icono']!, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(b['nombre']!, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: sel ? Colors.white : Colors.grey[800])),
            if (sel) ...[const SizedBox(width: 6), const Icon(Icons.check_circle, color: Colors.white, size: 18)],
          ])));
    }).toList()),
    const SizedBox(height: 20),
    _btnConectar('Conectar cuenta bancaria', const Color(0xFF1B5E20), Icons.account_balance,
      _bancoSel != null ? _conectarBanco : null),
  ]);

  // ── MÉTODOS COBRO ───────────────────────────────────────────────────────
  Widget _secMetodos(ConfiguracionPagos c) {
    return _card(Icons.payments, 'Métodos de cobro aceptados',
      'Configura qué formas de pago aceptas', _kP, null,
      Column(children: [
        _sw('💳', 'Tarjeta', c.aceptaTarjeta, (v) => _updMetodo(tarjeta: v)),
        _sw('📱', 'Bizum', c.aceptaBizum, (v) => _updMetodo(bizum: v)),
        _sw('🏦', 'Transferencia', c.aceptaTransferencia, (v) => _updMetodo(transferencia: v)),
        _sw('💵', 'Efectivo', c.aceptaEfectivo, (v) => _updMetodo(efectivo: v)),
        _sw('🅿️', 'PayPal', c.aceptaPaypal, (v) => _updMetodo(paypal: v)),
      ]));
  }

  void _updMetodo({bool? tarjeta, bool? bizum, bool? transferencia, bool? efectivo, bool? paypal}) {
    _svc.actualizarMetodosCobro(widget.empresaId,
      tarjeta: tarjeta, bizum: bizum, transferencia: transferencia, efectivo: efectivo, paypal: paypal);
    _cargar();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _conectarStripe() async {
    final ctrl = TextEditingController();
    final acctId = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [Icon(Icons.credit_card, color: Color(0xFF635BFF)), SizedBox(width: 10), Text('Conectar Stripe')]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _infoBox(const Color(0xFFF3F0FF), const Color(0xFF635BFF),
          'Cuando Stripe Connect esté activo, esto abrirá la autorización OAuth directamente. '
          'Por ahora, introduce tu Account ID (acct_xxx).'),
        const SizedBox(height: 16),
        TextField(controller: ctrl, decoration: InputDecoration(labelText: 'Stripe Account ID', hintText: 'acct_xxxxxxxxxxxxx',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.key))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF635BFF), foregroundColor: Colors.white),
          child: const Text('Conectar')),
      ],
    ));
    if (acctId != null && acctId.isNotEmpty) {
      await _svc.conectarStripe(widget.empresaId, accountId: acctId, displayName: 'Stripe Connect');
      _snack('✅ Stripe conectado correctamente'); _cargar();
    }
  }

  Future<void> _conectarRedsys() async {
    final code = _redsysMerchantCtrl.text.trim();
    if (code.isEmpty) { _snack('Introduce el código de comercio', err: true); return; }
    final t = _redsysTerminalCtrl.text.trim();
    await _svc.conectarRedsys(widget.empresaId, merchantCode: code, terminal: t.isEmpty ? '001' : t);
    _snack('✅ Redsys configurado'); _cargar();
  }

  Future<void> _conectarBanco() async {
    if (_bancoSel == null) return;
    final b = _bancos.firstWhere((x) => x['id'] == _bancoSel);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.account_balance, color: Color(0xFF1B5E20)), const SizedBox(width: 10),
        Expanded(child: Text('Conectar ${b['nombre']}')),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Se abrirá la web de tu banco donde deberás:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _paso('1', 'Iniciar sesión con tus credenciales del banco'),
            _paso('2', 'Autorizar el acceso de lectura a tus movimientos'),
            _paso('3', 'Seleccionar la cuenta a conectar'),
          ])),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFE082))),
          child: const Row(children: [
            Icon(Icons.shield, color: Color(0xFFF57F17), size: 20), SizedBox(width: 10),
            Expanded(child: Text('Solo lectura — no podemos mover dinero. El consentimiento caduca cada 90 días (normativa PSD2).',
              style: TextStyle(fontSize: 12, color: Color(0xFF5D4037)))),
          ])),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton.icon(onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Ir al banco'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white)),
      ],
    ));
    if (ok == true) {
      await _svc.conectarBanco(widget.empresaId, bancoId: b['id']!, bancoNombre: b['nombre']!,
        fechaExpiracion: DateTime.now().add(const Duration(days: 90)));
      _snack('✅ ${b['nombre']} conectado'); _cargar();
    }
  }

  Future<void> _renovarBanco() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Renovar conexión bancaria'),
      content: const Text('Se abrirá la web de tu banco para renovar el consentimiento de lectura (90 días, normativa PSD2).'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: _kOk, foregroundColor: Colors.white),
          child: const Text('Renovar')),
      ],
    ));
    if (ok == true && _config?.bancoId != null) {
      await _svc.conectarBanco(widget.empresaId, bancoId: _config!.bancoId!, bancoNombre: _config!.bancoNombre ?? '',
        iban: _config!.bancoIban, fechaExpiracion: DateTime.now().add(const Duration(days: 90)));
      _snack('✅ Consentimiento renovado (90 días)'); _cargar();
    }
  }

  Future<void> _confirmarDesc(String nombre, Future<void> Function() accion) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Desconectar $nombre'),
      content: Text('¿Seguro? Los pagos por esta vía dejarán de facturarse automáticamente.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: _kErr, foregroundColor: Colors.white),
          child: const Text('Desconectar')),
      ],
    ));
    if (ok == true) { await accion(); _snack('Desconectado'); _cargar(); }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WIDGETS BASE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _card(IconData icon, String titulo, String sub, Color color, bool? on, Widget child) {
    return Container(width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
            if (on != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: on ? _kOk.withValues(alpha: 0.1) : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(on ? Icons.check_circle : Icons.circle_outlined, size: 14, color: on ? _kOk : Colors.grey),
                const SizedBox(width: 4),
                Text(on ? 'Activo' : 'Inactivo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? _kOk : Colors.grey)),
              ])),
          ])),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]));
  }

  Widget _info(IconData icon, String label, String value, {Color? color}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
      Icon(icon, size: 18, color: color ?? Colors.grey[600]), const SizedBox(width: 10),
      Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? Colors.grey[800]))),
    ]));
  }

  Widget _infoBox(Color bg, Color iconColor, String text) {
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, color: iconColor, size: 20), const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF424242)))),
      ]));
  }

  Widget _sw(String emoji, String label, bool val, ValueChanged<bool> onChanged) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 22)), const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
      Switch.adaptive(value: val, onChanged: onChanged, activeTrackColor: _kP.withValues(alpha: 0.5), activeThumbColor: _kP),
    ]));
  }

  Widget _btnConectar(String label, Color color, IconData icon, VoidCallback? onPressed) {
    return SizedBox(width: double.infinity, height: 48,
      child: ElevatedButton.icon(onPressed: onPressed,
        icon: Icon(icon, size: 20), label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));
  }

  Widget _btnDesconectar(String nombre, Future<void> Function() accion) {
    return OutlinedButton.icon(onPressed: () => _confirmarDesc(nombre, accion),
      icon: const Icon(Icons.link_off, size: 18), label: const Text('Desconectar'),
      style: OutlinedButton.styleFrom(foregroundColor: _kErr,
        side: const BorderSide(color: Color(0xFFEF9A9A)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    filled: true, fillColor: Colors.grey[50]);

  String _mask(String iban) => iban.length < 8 ? iban : '${iban.substring(0, 4)} •••• •••• ${iban.substring(iban.length - 4)}';

  Widget _paso(String n, String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 22, height: 22, decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(11)),
        child: Center(child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
      const SizedBox(width: 8),
      Expanded(child: Text(t, style: const TextStyle(fontSize: 13, color: Color(0xFF424242)))),
    ]));
}


