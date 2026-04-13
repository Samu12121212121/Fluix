import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth/dos_factores_service.dart';
import '../../dashboard/pantallas/pantalla_dashboard.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA — Verificación 2FA por SMS
//
// Se muestra después del login principal cuando el usuario tiene
// dos_factores_activo == true.
// ─────────────────────────────────────────────────────────────────────────────

class PantallaVerificacion2FA extends StatefulWidget {
  final String telefono;     // Número enmascarado para mostrar: "+34 *** *** 78"
  final String verificationId;

  const PantallaVerificacion2FA({
    super.key,
    required this.telefono,
    required this.verificationId,
  });

  @override
  State<PantallaVerificacion2FA> createState() =>
      _PantallaVerificacion2FAState();
}

class _PantallaVerificacion2FAState extends State<PantallaVerificacion2FA> {
  static const int _longitud = 6;
  static const int _segundosReenvio = 60;
  static const Color _azul = Color(0xFF0D47A1);

  final _svc = DosFactoresService();
  late final String _verificationId;
  final List<TextEditingController> _ctrls =
      List.generate(_longitud, (_) => TextEditingController());
  final List<FocusNode> _foci =
      List.generate(_longitud, (_) => FocusNode());

  bool _verificando = false;
  bool _puedeReenviar = false;
  int _segundosRestantes = _segundosReenvio;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _iniciarContador();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) c.dispose();
    for (final f in _foci) f.dispose();
    super.dispose();
  }

  void _iniciarContador() {
    _puedeReenviar = false;
    _segundosRestantes = _segundosReenvio;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _segundosRestantes--;
        if (_segundosRestantes <= 0) {
          _puedeReenviar = true;
          t.cancel();
        }
      });
    });
  }

  String get _codigoCompleto => _ctrls.map((c) => c.text).join();

  Future<void> _verificar() async {
    final codigo = _codigoCompleto;
    if (codigo.length < _longitud) return;

    setState(() { _verificando = true; _error = null; });

    // ── LOGS DE DIAGNÓSTICO 2FA ──────────────────────────────────────────────
    debugPrint('🔐 2FA: código introducido = $codigo');
    debugPrint('🔐 2FA: verificationId = ${_verificationId.substring(0, 8)}...');
    debugPrint('🔐 2FA: timestamp = ${DateTime.now().toIso8601String()}');

    try {
      final ok = await _svc.verificarCodigo(
        verificationId: _verificationId,
        codigo: codigo,
      );

      debugPrint('🔐 2FA: resultado validación = $ok | intentos=${_svc.intentosFallidos}');

      if (!mounted) return;

      if (ok) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PantallaDashboard()),
          (_) => false,
        );
      } else {
        setState(() {
          _error = 'Código incorrecto. '
              '${_svc.intentosFallidos < 3 ? 'Quedan ${3 - _svc.intentosFallidos} intentos.' : ''}';
          _limpiarCampos();
        });
      }
    } on TooManyAttemptsException {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Demasiados intentos incorrectos. Sesión cerrada.'),
          backgroundColor: Colors.red,
        ));
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'session-expired' => 'El código ha expirado. Solicita uno nuevo.',
          _ => 'Error: ${e.message}',
        };
        _limpiarCampos();
      });
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _reenviar() async {
    if (!_puedeReenviar) return;
    setState(() { _error = null; _verificando = true; });
    try {
      // FIX: capturar el NUEVO verificationId (el anterior ya expiró).
      // Sin esto, el código del SMS nuevo siempre falla porque se valida
      // contra un verificationId caducado.
      final nuevoVerificationId = await _svc.enviarCodigo(
        telefono: widget.telefono,
        onError: (msg) {
          if (mounted) setState(() => _error = msg);
        },
      );
      // Actualizar verificationId en el estado local
      setState(() { _verificationId = nuevoVerificationId; });
      _iniciarContador();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('📱 Nuevo código enviado.'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      debugPrint('❌ 2FA reenvío falló: $e');
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  void _limpiarCampos() {
    for (final c in _ctrls) c.clear();
    _foci.first.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Evita volver sin verificar
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Icono
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: _azul.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sms_outlined, size: 40, color: _azul),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Verificación en dos pasos',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Text(
                  'Introduce el código de 6 dígitos que hemos enviado al número ${_telefonoEnmascarado()}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // ── 6 cajas de dígito ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_longitud, (i) => _CajaDigito(
                    controller: _ctrls[i],
                    focusNode: _foci[i],
                    nextFocus: i < _longitud - 1 ? _foci[i + 1] : null,
                    prevFocus: i > 0 ? _foci[i - 1] : null,
                    onComplete: () => _verificar(),
                    enabled: !_verificando,
                  )),
                ),
                const SizedBox(height: 16),

                // Mensaje de error
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13)),
                      ),
                    ]),
                  ),

                const SizedBox(height: 28),

                // ── Botón Verificar ───────────────────────────────────────
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: (_verificando || _codigoCompleto.length < _longitud)
                        ? null
                        : _verificar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _azul,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _verificando
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Verificar',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Reenviar ──────────────────────────────────────────────
                _puedeReenviar
                    ? TextButton(
                        onPressed: _reenviar,
                        child: const Text('Reenviar código',
                            style: TextStyle(
                                color: _azul, fontWeight: FontWeight.w600)),
                      )
                    : Text(
                        'Reenviar en $_segundosRestantes s',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),

                const Spacer(),

                // Cancelar = cerrar sesión
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: Text('Cancelar y cerrar sesión',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _telefonoEnmascarado() {
    final t = widget.telefono;
    if (t.length < 4) return t;
    return '${t.substring(0, t.length - 4).replaceAll(RegExp(r'\d'), '*')}'
        '${t.substring(t.length - 4)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Caja de un solo dígito
// ─────────────────────────────────────────────────────────────────────────────

class _CajaDigito extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final FocusNode? prevFocus;
  final VoidCallback onComplete;
  final bool enabled;

  const _CajaDigito({
    required this.controller,
    required this.focusNode,
    required this.onComplete,
    this.nextFocus,
    this.prevFocus,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46, height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
          ),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (val) {
          if (val.isNotEmpty) {
            if (nextFocus != null) {
              nextFocus!.requestFocus();
            } else {
              onComplete();
            }
          } else {
            prevFocus?.requestFocus();
          }
        },
      ),
    );
  }
}

