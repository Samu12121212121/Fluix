import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/gmb_auth_service.dart';

/// Pantalla de conexión a Google Business Profile.
/// Muestra flujo simplificado de 1 tap para empresarios no técnicos.
class ConectarGoogleBusinessScreen extends StatefulWidget {
  final String empresaId;
  final VoidCallback? onConectado;

  const ConectarGoogleBusinessScreen({
    super.key,
    required this.empresaId,
    this.onConectado,
  });

  @override
  State<ConectarGoogleBusinessScreen> createState() =>
      _ConectarGoogleBusinessScreenState();
}

class _ConectarGoogleBusinessScreenState
    extends State<ConectarGoogleBusinessScreen> {
  final GmbAuthService _svc = GmbAuthService();

  _Paso _paso = _Paso.bienvenida;
  List<FichaNegocio> _fichas = [];
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _paso == _Paso.bienvenida
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => setState(() {
                  _paso = _Paso.bienvenida;
                  _error = null;
                }),
              ),
              title: Text(
                _paso == _Paso.seleccionarFicha
                    ? 'Elige tu negocio'
                    : 'Conectar Google',
                style: const TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w600),
              ),
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildPasoActual(),
      ),
    );
  }

  Widget _buildPasoActual() {
    return switch (_paso) {
      _Paso.bienvenida => _PantallaBienvenida(
          key: const ValueKey('bienvenida'),
          onConectar: _iniciarConexion,
        ),
      _Paso.conectando => const _PantallaConectando(
          key: ValueKey('conectando'),
        ),
      _Paso.seleccionarFicha => _PantallaSeleccionarFicha(
          key: const ValueKey('fichas'),
          fichas: _fichas,
          onSeleccionar: _guardarFicha,
          error: _error,
        ),
      _Paso.error => _PantallaError(
          key: const ValueKey('error'),
          mensaje: _error ?? 'Error desconocido',
          onReintentar: () => setState(() {
            _paso = _Paso.bienvenida;
            _error = null;
          }),
        ),
    };
  }

  Future<void> _iniciarConexion() async {
    setState(() {
      _paso = _Paso.conectando;
      _error = null;
    });

    try {
      // 1. Iniciar OAuth y guardar tokens en Secret Manager
      final errorAuth = await _svc.conectar(widget.empresaId);
      if (!mounted) return;

      if (errorAuth != null) {
        setState(() {
          _paso = _Paso.error;
          _error = errorAuth;
        });
        return;
      }

      // 2. Obtener fichas del empresario
      final resultado = await _svc.obtenerFichas(widget.empresaId);
      if (!mounted) return;

      if (resultado.error != null) {
        setState(() {
          _paso = _Paso.error;
          _error = resultado.error;
        });
        return;
      }

      if (resultado.fichas.isEmpty) {
        setState(() {
          _paso = _Paso.error;
          _error = 'No encontramos ninguna ficha de Google Business en tu cuenta. '
              'Asegúrate de tener un perfil creado en business.google.com';
        });
        return;
      }

      if (resultado.fichas.length == 1) {
        // Solo una ficha → guardar directamente
        await _guardarFicha(resultado.fichas.first);
      } else {
        // Múltiples fichas → dejar que el empresario elija
        setState(() {
          _fichas = resultado.fichas;
          _paso = _Paso.seleccionarFicha;
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _paso = _Paso.error;
        _error = 'Error de plataforma al conectar con Google: ${e.message ?? e.code}.\n'
            'Verifica que Google Sign-In esté configurado correctamente.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paso = _Paso.error;
        _error = 'Error inesperado al conectar con Google: $e';
      });
    }
  }

  Future<void> _guardarFicha(FichaNegocio ficha) async {
    setState(() {
      _paso = _Paso.conectando;
      _error = null;
    });

    final error = await _svc.guardarFicha(widget.empresaId, ficha);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _paso = _Paso.error;
        _error = error;
      });
    } else {
      widget.onConectado?.call();
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }
}

// ── Pantallas internas ────────────────────────────────────────────────────────

enum _Paso { bienvenida, conectando, seleccionarFicha, error }

class _PantallaBienvenida extends StatelessWidget {
  final VoidCallback onConectar;

  const _PantallaBienvenida({super.key, required this.onConectar});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Icono principal
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8FF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.2)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.star_rate_rounded,
                      size: 60, color: Color(0xFFF57C00)),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4285F4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.link, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Título
            const Text(
              'Conecta tu Google Business',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Descripción en lenguaje simple
            Text(
              'Conecta tu ficha de Google para ver y responder tus reseñas '
              'directamente desde aquí, sin salir de la app.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Beneficios
            _BeneficioItem(
              icono: Icons.notifications_active,
              color: const Color(0xFFD32F2F),
              texto: 'Alerta inmediata cuando recibes una reseña negativa',
            ),
            const SizedBox(height: 12),
            _BeneficioItem(
              icono: Icons.reply_rounded,
              color: const Color(0xFF1976D2),
              texto: 'Responde directamente en Google Maps desde la app',
            ),
            const SizedBox(height: 12),
            _BeneficioItem(
              icono: Icons.trending_up,
              color: const Color(0xFF43A047),
              texto: 'Gráfico de evolución de tu rating mes a mes',
            ),
            const SizedBox(height: 40),

            // Botón principal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onConectar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 2,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo de Google manual (colores oficiales)
                    _GoogleLogo(),
                    const SizedBox(width: 12),
                    const Text(
                      'Conectar con Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Enlace de permisos
            TextButton(
              onPressed: () => _mostrarDialogoPermisos(context),
              child: const Text(
                '¿Qué permisos necesito?',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoPermisos(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.info_outline, color: Color(0xFF4285F4)),
          SizedBox(width: 8),
          Text('Permisos que necesitas',
              style: TextStyle(fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PermisoItem(
              titulo: '✅ Ver tus reseñas',
              descripcion:
                  'Para mostrarlas en la app y avisarte de las nuevas.',
            ),
            const SizedBox(height: 12),
            _PermisoItem(
              titulo: '✅ Responder reseñas',
              descripcion:
                  'Para publicar tus respuestas directamente en Google Maps.',
            ),
            const SizedBox(height: 12),
            _PermisoItem(
              titulo: '❌ Lo que NO hacemos',
              descripcion:
                  'No modificamos tu ficha, no publicamos nada sin tu permiso, '
                  'no accedemos a otros servicios de Google.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🔒 Los permisos se guardan cifrados en Google Cloud. '
                'Puedes revocarlos en cualquier momento desde myaccount.google.com',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _PantallaConectando extends StatelessWidget {
  const _PantallaConectando({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF4285F4),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Conectando con Google...',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Esto solo tardará unos segundos',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PantallaSeleccionarFicha extends StatelessWidget {
  final List<FichaNegocio> fichas;
  final ValueChanged<FichaNegocio> onSeleccionar;
  final String? error;

  const _PantallaSeleccionarFicha({
    super.key,
    required this.fichas,
    required this.onSeleccionar,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Tenemos ${fichas.length} fichas en tu cuenta:',
              style:
                  TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              '¿Cuál es tu negocio?',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: fichas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final ficha = fichas[i];
                  return _TarjetaFicha(
                    ficha: ficha,
                    onTap: () => onSeleccionar(ficha),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaFicha extends StatelessWidget {
  final FichaNegocio ficha;
  final VoidCallback onTap;

  const _TarjetaFicha({required this.ficha, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.store_rounded,
                    color: Color(0xFF4285F4), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ficha.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (ficha.direccion.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        ficha.direccion,
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _PantallaError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _PantallaError({
    super.key,
    required this.mensaje,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.error_outline,
                  size: 44, color: Color(0xFFD32F2F)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No se pudo conectar',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                mensaje,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFB71C1C), height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Intentar de nuevo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _BeneficioItem extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String texto;

  const _BeneficioItem(
      {required this.icono, required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              texto,
              style: TextStyle(
                  color: Colors.grey[700], fontSize: 13.5, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _PermisoItem extends StatelessWidget {
  final String titulo;
  final String descripcion;

  const _PermisoItem({required this.titulo, required this.descripcion});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 3),
        Text(descripcion,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Logo de Google con 4 colores
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = rect.center;
    final r = size.width / 2;

    // Círculo base gris claro
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r, bgPaint);

    // Cuatro arcos de colores Google
    final arcPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 3;
    const sweep = 1.5708; // PI/2

    arcPaint.color = const Color(0xFF4285F4); // azul
    canvas.drawArc(rect.deflate(2), -1.5708, sweep, false, arcPaint);
    arcPaint.color = const Color(0xFFEA4335); // rojo
    canvas.drawArc(rect.deflate(2), 0, sweep, false, arcPaint);
    arcPaint.color = const Color(0xFFFBBC05); // amarillo
    canvas.drawArc(rect.deflate(2), 1.5708, sweep, false, arcPaint);
    arcPaint.color = const Color(0xFF34A853); // verde
    canvas.drawArc(rect.deflate(2), 3.1416, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

