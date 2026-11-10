import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/documento_firma_service.dart';
import '../../nominas/widgets/firma_digital_canvas.dart';
import '../../../core/widgets/flux_toast.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FIRMA ELECTRÓNICA AVANZADA — eIDAS art. 26
//
// 3 pasos:
//   1. Verificar identidad → enviar OTP SMS
//   2. Introducir código OTP
//   3. Dibujar firma táctil → Confirmar
// ═══════════════════════════════════════════════════════════════════════════════

enum _Paso { verificandoIdentidad, ingresandoCodigo, firmando }

class FirmaDocumentoSheet extends StatefulWidget {
  final String empleadoId;
  final String empresaId;
  final String docId;
  final String docNombre;
  final String docUrl;
  final String docCategoria;
  final String empresaNombre;

  const FirmaDocumentoSheet({
    super.key,
    required this.empleadoId,
    required this.empresaId,
    required this.docId,
    required this.docNombre,
    required this.docUrl,
    required this.docCategoria,
    required this.empresaNombre,
  });

  static Future<bool> show(
    BuildContext context, {
    required String empleadoId,
    required String empresaId,
    required String docId,
    required String docNombre,
    required String docUrl,
    required String docCategoria,
    String empresaNombre = 'la empresa',
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FirmaDocumentoSheet(
        empleadoId:   empleadoId,
        empresaId:    empresaId,
        docId:        docId,
        docNombre:    docNombre,
        docUrl:       docUrl,
        docCategoria: docCategoria,
        empresaNombre: empresaNombre,
      ),
    );
    return result == true;
  }

  @override
  State<FirmaDocumentoSheet> createState() => _FirmaDocumentoSheetState();
}

class _FirmaDocumentoSheetState extends State<FirmaDocumentoSheet> {
  final _svc        = DocumentoFirmaService();
  final _codigoCtrl = TextEditingController();

  _Paso       _paso            = _Paso.verificandoIdentidad;
  bool        _cargando        = false;
  String      _telParcial      = '';
  String?     _codigoDebug;
  String?     _verificationId; // Firebase Phone Auth — null si se usa fallback hash
  Uint8List?  _firma;
  String?     _errorMsg;

  static const _kBlue   = Color(0xFF3B82F6);
  static const _kGreen  = Color(0xFF22C55E);
  static const _kOrange = Color(0xFFF59E0B);
  static const _kBorder = Color(0xFFE5E7EB);
  static const _kText   = Color(0xFF111827);
  static const _kSub    = Color(0xFF6B7280);
  static const _kBg     = Color(0xFFF8F9FA);

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  // ── Paso 1: enviar OTP ────────────────────────────────────────────────────

  Future<void> _enviarOtp() async {
    setState(() { _cargando = true; _errorMsg = null; });
    try {
      final result = await _svc.enviarOtpFirma(
        empleadoId:     widget.empleadoId,
        docId:          widget.docId,
        nombreDocumento: widget.docNombre,
        empresaNombre:  widget.empresaNombre,
        empresaId:      widget.empresaId,
      );
      setState(() {
        _telParcial      = result.telefonoParcial;
        _codigoDebug     = result.codigoDebug;
        _verificationId  = result.verificationId;
        _paso            = _Paso.ingresandoCodigo;
        _cargando        = false;
      });
    } catch (e) {
      setState(() { _errorMsg = e.toString(); _cargando = false; });
    }
  }

  // ── Paso 2: verificar OTP ────────────────────────────────────────────────

  Future<void> _verificarOtp() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.length != 6) {
      setState(() => _errorMsg = 'Introduce el código de 6 dígitos');
      return;
    }
    setState(() { _cargando = true; _errorMsg = null; });
    try {
      await _svc.verificarOtp(
        empleadoId:     widget.empleadoId,
        docId:          widget.docId,
        codigoIngresado: codigo,
        verificationId: _verificationId,
      );
      setState(() { _paso = _Paso.firmando; _cargando = false; });
    } on FirmaException catch (e) {
      setState(() { _errorMsg = e.message; _cargando = false; });
    } catch (e) {
      setState(() { _errorMsg = 'Error inesperado: $e'; _cargando = false; });
    }
  }

  // ── Paso 3: confirmar firma táctil ───────────────────────────────────────

  Future<void> _confirmarFirma() async {
    if (_firma == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() { _cargando = true; _errorMsg = null; });
    try {
      await _svc.firmarDocumento(
        empleadoId:   widget.empleadoId,
        empresaId:    widget.empresaId,
        docId:        widget.docId,
        firmanteUid:  user.uid,
        firmanteEmail: user.email ?? '',
        firmaPng:     _firma!,
      );
      if (mounted) {
        FluxToast.exito(context, 'Documento firmado correctamente');
        Navigator.pop(context, true);
      }
    } on FirmaException catch (e) {
      setState(() { _errorMsg = e.message; _cargando = false; });
    } catch (e) {
      setState(() { _errorMsg = 'Error al firmar: $e'; _cargando = false; });
    }
  }

  Future<void> _verDocumento() async {
    if (widget.docUrl.isEmpty) return;
    final uri = Uri.parse(widget.docUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq          = MediaQuery.of(context);
    final keyboardH   = mq.viewInsets.bottom;
    final maxH        = mq.size.height * 0.92;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Parte scrollable ──────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: keyboardH + 24,
                left: 20, right: 20, top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildContent(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    return [
            // Handle
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)),
            )),

            // Cabecera del documento
            _docHeader(),
            const SizedBox(height: 20),

            // Indicador de pasos
            _stepIndicator(),
            const SizedBox(height: 20),

            // Contenido del paso actual
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (_paso) {
                _Paso.verificandoIdentidad => _buildPaso1(),
                _Paso.ingresandoCodigo     => _buildPaso2(),
                _Paso.firmando             => _buildPaso3(),
              },
            ),

            // Mensaje de error
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 15, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMsg!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
                ]),
              ),
            ],
    ];
  }

  Widget _docHeader() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kBorder),
    ),
    child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: _kBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.description_outlined, color: _kBlue, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.docNombre, style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w700, color: _kText),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(widget.docCategoria, style: const TextStyle(fontSize: 11, color: _kSub)),
      ])),
      if (widget.docUrl.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.open_in_new_rounded, size: 18, color: _kBlue),
          tooltip: 'Ver documento',
          onPressed: _verDocumento,
        ),
    ]),
  );

  Widget _stepIndicator() {
    final pasos = ['Verificar identidad', 'Código SMS', 'Firmar'];
    final actual = _paso.index;
    return Row(children: List.generate(pasos.length * 2 - 1, (i) {
      if (i.isOdd) {
        return Expanded(child: Container(height: 1,
            color: i ~/ 2 < actual ? _kGreen : _kBorder));
      }
      final idx  = i ~/ 2;
      final done = idx < actual;
      final cur  = idx == actual;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? _kGreen : cur ? _kBlue : _kBorder,
          ),
          child: Center(child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text('${idx + 1}', style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cur ? Colors.white : _kSub))),
        ),
        const SizedBox(height: 4),
        Text(pasos[idx], style: TextStyle(fontSize: 9,
            color: cur ? _kBlue : done ? _kGreen : _kSub,
            fontWeight: cur ? FontWeight.w700 : FontWeight.w400)),
      ]);
    }));
  }

  // ── Paso 1: Verificar identidad ───────────────────────────────────────────

  Widget _buildPaso1() => Column(
    key: const ValueKey('p1'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Verificar identidad',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
      const SizedBox(height: 8),
      const Text(
        'Para cumplir con la firma electrónica avanzada (eIDAS art. 26), '
        'enviamos un código de verificación al teléfono registrado.',
        style: TextStyle(fontSize: 12, color: _kSub),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
        ),
        child: const Row(children: [
          Icon(Icons.verified_user_outlined, size: 18, color: _kGreen),
          SizedBox(width: 10),
          Expanded(child: Text(
            'Firma electrónica avanzada conforme a Reglamento (UE) 910/2014 '
            'y Ley 6/2020. Legalmente vinculante para contratos laborales.',
            style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
          )),
        ]),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _cargando ? null : _enviarOtp,
          icon: _cargando
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sms_outlined, size: 18),
          label: Text(_cargando ? 'Enviando...' : 'Enviar código SMS'),
          style: FilledButton.styleFrom(
            backgroundColor: _kBlue,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ],
  );

  // ── Paso 2: Introducir OTP ────────────────────────────────────────────────

  Widget _buildPaso2() => Column(
    key: const ValueKey('p2'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Código de verificación',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
      const SizedBox(height: 8),
      Text('Hemos enviado un código de 6 dígitos al ${_telParcial}.',
          style: const TextStyle(fontSize: 12, color: _kSub)),
      const SizedBox(height: 16),

      // Si Twilio no está configurado (testing), mostrar el código directamente
      if (_codigoDebug != null)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kOrange.withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 15, color: _kOrange),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'SMS no configurado — código de prueba: $_codigoDebug',
              style: const TextStyle(fontSize: 11, color: Color(0xFF92400E),
                  fontWeight: FontWeight.w700),
            )),
          ]),
        ),

      TextField(
        controller: _codigoCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
            letterSpacing: 12, color: _kText),
        decoration: InputDecoration(
          counterText: '',
          hintText: '• • • • • •',
          hintStyle: TextStyle(fontSize: 24, color: _kBorder, letterSpacing: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBlue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
        onChanged: (_) => setState(() => _errorMsg = null),
      ),

      const SizedBox(height: 8),
      TextButton(
        onPressed: _cargando ? null : _enviarOtp,
        child: const Text('Reenviar código', style: TextStyle(fontSize: 12, color: _kBlue)),
      ),

      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _cargando ? null : _verificarOtp,
          icon: _cargando
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline, size: 18),
          label: Text(_cargando ? 'Verificando...' : 'Verificar código'),
          style: FilledButton.styleFrom(
            backgroundColor: _kBlue,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ],
  );

  // ── Paso 3: Firma táctil ─────────────────────────────────────────────────

  Widget _buildPaso3() => Column(
    key: const ValueKey('p3'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        const Icon(Icons.verified_user, size: 16, color: _kGreen),
        const SizedBox(width: 6),
        const Text('Identidad verificada — Firma el documento',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kGreen)),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kOrange.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Al firmar confirmas haber leído y aceptado el contenido de este documento. '
          'La firma quedará registrada con tu identidad, fecha y hora exacta.',
          style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
        ),
      ),
      const SizedBox(height: 16),
      Text('Firme con el dedo en el recuadro',
          style: const TextStyle(fontSize: 12, color: _kSub)),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (ctx, cst) => FirmaDigitalCanvas(
        width:  cst.maxWidth,
        height: 150,
        onFirmaConfirmada: (bytes) => setState(() => _firma = bytes),
      )),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: (_firma != null && !_cargando) ? _confirmarFirma : null,
          icon: _cargando
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.draw_rounded, size: 18),
          label: Text(_cargando ? 'Procesando PDF firmado...' : 'Firmar documento'),
          style: FilledButton.styleFrom(
            backgroundColor: _kGreen,
            disabledBackgroundColor: _kBorder,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Center(child: Text(
        'Esta firma tiene validez legal conforme al Reglamento (UE) 910/2014',
        style: TextStyle(fontSize: 10, color: _kSub),
        textAlign: TextAlign.center,
      )),
    ],
  );
}
