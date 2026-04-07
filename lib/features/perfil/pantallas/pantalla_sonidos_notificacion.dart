import 'package:flutter/material.dart';
import '../../../services/sonido_notificacion_service.dart';

/// Pantalla para configurar el sonido de cada tipo de notificación.
/// Accesible desde Perfil → Sonidos de notificación.
class PantallaSonidosNotificacion extends StatefulWidget {
  const PantallaSonidosNotificacion({super.key});

  @override
  State<PantallaSonidosNotificacion> createState() =>
      _PantallaSonidosNotificacionState();
}

class _PantallaSonidosNotificacionState
    extends State<PantallaSonidosNotificacion> {
  final SonidoNotificacionService _service = SonidoNotificacionService();

  bool _cargando = true;
  Map<TipoNotificacion, SonidoNotif> _preferencias = {};

  // Sonido que se está reproduciendo en preescucha
  SonidoNotif? _reproduciendo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await _service.obtenerTodas();
    if (mounted) {
      setState(() {
        _preferencias = prefs;
        _cargando = false;
      });
    }
  }

  Future<void> _cambiarSonido(TipoNotificacion tipo, SonidoNotif sonido) async {
    setState(() => _preferencias[tipo] = sonido);
    await _service.guardarSonido(tipo, sonido);
  }

  Future<void> _preescuchar(SonidoNotif sonido) async {
    setState(() => _reproduciendo = sonido);
    await _service.reproducir(sonido);
    if (mounted) setState(() => _reproduciendo = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Sonidos de Notificación',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoBanner(),
                const SizedBox(height: 16),
                ...TipoNotificacion.values.map(
                  (tipo) => _buildTipoCard(tipo),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0D47A1).withValues(alpha: 0.2),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Elige un sonido distinto para cada tipo de notificación. '
              'Pulsa ▶ para escucharlo antes de guardarlo.',
              style: TextStyle(fontSize: 13, color: Color(0xFF0D47A1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoCard(TipoNotificacion tipo) {
    final sonidoActual = _preferencias[tipo] ?? SonidoNotif.predeterminado;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título del tipo
            Row(
              children: [
                Icon(
                  _iconParaTipo(tipo),
                  size: 20,
                  color: const Color(0xFF0D47A1),
                ),
                const SizedBox(width: 8),
                Text(
                  tipo.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Selector de sonido
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SonidoNotif.values.map((sonido) {
                final seleccionado = sonido == sonidoActual;
                final reproduciendo = _reproduciendo == sonido;

                return GestureDetector(
                  onTap: () => _cambiarSonido(tipo, sonido),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: seleccionado
                          ? const Color(0xFF0D47A1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: seleccionado
                            ? const Color(0xFF0D47A1)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sonido.nombre,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: seleccionado
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: seleccionado ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (sonido != SonidoNotif.sinSonido) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _preescuchar(sonido),
                            child: Icon(
                              reproduciendo
                                  ? Icons.volume_up
                                  : Icons.play_circle_outline,
                              size: 16,
                              color: seleccionado
                                  ? Colors.white70
                                  : const Color(0xFF0D47A1),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconParaTipo(TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.nuevaReserva:         return Icons.calendar_today;
      case TipoNotificacion.nuevaValoracion:      return Icons.star;
      case TipoNotificacion.nuevoPedido:          return Icons.shopping_bag_outlined;
      case TipoNotificacion.tareaAsignada:        return Icons.task_alt;
      case TipoNotificacion.suscripcionPorVencer: return Icons.warning_amber_outlined;
      case TipoNotificacion.general:              return Icons.notifications_outlined;
    }
  }
}


