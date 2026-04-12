import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth/biometria_service.dart';
import '../../../services/notificaciones_service.dart';
import '../../../core/utils/permisos_service.dart';
import '../../dashboard/pantallas/pantalla_dashboard.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA — Login biométrico (FaceID / Huella)
//
// Se muestra al abrir la app si:
//   - El usuario tiene una sesión Firebase activa
//   - La biometría está activada en flutter_secure_storage
//
// Si falla 3 veces → cierra sesión → regresa al login normal.
// ─────────────────────────────────────────────────────────────────────────────

class PantallaLoginBiometrico extends StatefulWidget {
  const PantallaLoginBiometrico({super.key});

  @override
  State<PantallaLoginBiometrico> createState() =>
      _PantallaLoginBiometricoState();
}

class _PantallaLoginBiometricoState extends State<PantallaLoginBiometrico> {
  final BiometriaService _bio = BiometriaService();
  static const int _maxIntentos = 3;

  int _intentos = 0;
  bool _autenticando = false;
  String? _error;
  String _labelBoton = 'Acceso biométrico';

  @override
  void initState() {
    super.initState();
    _cargarLabel();
    // Intentar automáticamente al abrir
    WidgetsBinding.instance.addPostFrameCallback((_) => _autenticar());
  }

  Future<void> _cargarLabel() async {
    final label = await _bio.labelBoton();
    if (mounted) setState(() => _labelBoton = label);
  }

  Future<void> _autenticar() async {
    if (_autenticando || _intentos >= _maxIntentos) return;
    setState(() { _autenticando = true; _error = null; });

    final resultado = await _bio.autenticar();
    if (!mounted) return;

    if (resultado.exito) {
      // Cargar sesión de Firestore y navegar
      await PermisosService().cargarSesion();
      await NotificacionesService().guardarTokenTrasLogin();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PantallaDashboard()),
        );
      }
    } else {
      // Si el usuario canceló voluntariamente, no contar como intento fallido
      if (resultado.razon == BiometriaRazon.cancelada) {
        setState(() { _autenticando = false; _error = null; });
        return;
      }

      _intentos++;
      final restantes = _maxIntentos - _intentos;

      if (_intentos >= _maxIntentos) {
        await _cerrarSesionYFallback();
      } else {
        setState(() {
          _error = resultado.mensajeError != null
              ? '${resultado.mensajeError} Quedan $restantes intento${restantes == 1 ? '' : 's'}.'
              : 'Autenticación fallida. Quedan $restantes intento${restantes == 1 ? '' : 's'}.';
          _autenticando = false;
        });
      }
    }
  }

  Future<void> _cerrarSesionYFallback() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Máximo de intentos alcanzado. Inicia sesión con contraseña.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Logo
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    size: 52, color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Fluix CRM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 60),

                // Icono biométrico animado
                GestureDetector(
                  onTap: _autenticando ? null : _autenticar,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: _autenticando
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2),
                    ),
                    child: _autenticando
                        ? const Padding(
                            padding: EdgeInsets.all(22),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.fingerprint,
                            size: 52, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  _autenticando ? 'Verificando...' : _labelBoton,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const Spacer(),

                // Opción de login con contraseña
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: const Text(
                    'Usar contraseña',
                    style: TextStyle(
                        color: Colors.white60, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

