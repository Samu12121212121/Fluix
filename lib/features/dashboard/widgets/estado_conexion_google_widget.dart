import 'package:flutter/material.dart';
import '../../../services/gmb_auth_service.dart';
import '../pantallas/conectar_google_business_screen.dart';

/// Widget reutilizable que muestra el estado de conexión con Google Business Profile.
/// Se coloca en la cabecera del módulo de valoraciones.
class EstadoConexionGoogleWidget extends StatefulWidget {
  final String empresaId;
  final VoidCallback? onEstadoCambiado;

  const EstadoConexionGoogleWidget({
    super.key,
    required this.empresaId,
    this.onEstadoCambiado,
  });

  @override
  State<EstadoConexionGoogleWidget> createState() =>
      _EstadoConexionGoogleWidgetState();
}

class _EstadoConexionGoogleWidgetState
    extends State<EstadoConexionGoogleWidget> {
  final GmbAuthService _svc = GmbAuthService();
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    _init();
    _svc.addListener(_rebuild);
  }

  @override
  void dispose() {
    _svc.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    await _svc.init(widget.empresaId);
    if (mounted) setState(() => _inicializado = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_inicializado) {
      return const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return _svc.conectado ? _BadgeConectado() : _BadgeDesconectado();
  }

  Widget _BadgeConectado() {
    return GestureDetector(
      onTap: () => _mostrarDialogoDesconectar(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF43A047).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF43A047).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF43A047),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _svc.nombreFicha?.isNotEmpty == true
                    ? _svc.nombreFicha!
                    : 'Google Business conectado',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more,
                size: 14, color: Color(0xFF43A047)),
          ],
        ),
      ),
    );
  }

  Widget _BadgeDesconectado() {
    return GestureDetector(
      onTap: () => _abrirConectar(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4285F4).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF4285F4).withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 13, color: Color(0xFF4285F4)),
            const SizedBox(width: 5),
            const Text(
              'Conectar Google',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirConectar(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConectarGoogleBusinessScreen(
          empresaId: widget.empresaId,
          onConectado: () {
            widget.onEstadoCambiado?.call();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _mostrarDialogoDesconectar(BuildContext context) {
    final ultimaSync = _svc.ultimaSync;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),

            // Badge verde
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF43A047).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.verified,
                  color: Color(0xFF43A047), size: 40),
            ),
            const SizedBox(height: 16),

            const Text(
              'Conectado a Google Business',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            if (_svc.nombreFicha?.isNotEmpty == true)
              Text(
                _svc.nombreFicha!,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4285F4)),
              ),

            if (_svc.direccionFicha?.isNotEmpty == true) ...[
              const SizedBox(height: 3),
              Text(
                _svc.direccionFicha!,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],

            if (ultimaSync != null) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icono: Icons.sync,
                texto:
                    'Última sync: ${_formatFecha(ultimaSync)}',
              ),
            ],

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Botón desconectar
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _desconectar(context);
                },
                icon: const Icon(Icons.link_off, size: 18, color: Colors.red),
                label: const Text('Desconectar',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _desconectar(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Desconectar Google Business?'),
        content: const Text(
            'Las reseñas ya guardadas se mantendrán, pero dejarás de '
            'recibir nuevas reseñas y alertas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _svc.desconectar(widget.empresaId);
      widget.onEstadoCambiado?.call();
    }
  }

  String _formatFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diff = ahora.difference(fecha);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _InfoRow({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icono, size: 13, color: Colors.grey[400]),
        const SizedBox(width: 5),
        Text(texto,
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }
}

