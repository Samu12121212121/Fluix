import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/permisos_service.dart';

class PantallaSuscripcionVencida extends StatelessWidget {
  final String empresaId;
  final String estado; // VENCIDA, PENDIENTE, SUSPENDIDA
  final DateTime? fechaFin;

  const PantallaSuscripcionVencida({
    super.key,
    required this.empresaId,
    required this.estado,
    this.fechaFin,
  });

  @override
  Widget build(BuildContext context) {
    final esPropietario = PermisosService().sesion?.esPropietario ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono principal
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _colorEstado.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconoEstado, size: 72, color: _colorEstado),
              ),
              const SizedBox(height: 28),

              Text(
                _tituloEstado,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _colorEstado,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                _mensajeEstado,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              if (fechaFin != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _colorEstado.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _colorEstado.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: _colorEstado),
                      const SizedBox(width: 8),
                      Text(
                        estado == 'VENCIDA'
                            ? 'Venció el ${_formatFecha(fechaFin!)}'
                            : 'Vence el ${_formatFecha(fechaFin!)}',
                        style: TextStyle(
                          color: _colorEstado,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              if (esPropietario) ...[
                // Botón principal — abrir web de pago
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('https://fluixtech.com/renovar');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) _contactarRenovacion(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text(
                      'Renovar en la web',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Botón secundario — contactar
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _contactarRenovacion(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D47A1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.support_agent, size: 18),
                    label: const Text('Contactar con soporte'),
                  ),
                ),
                const SizedBox(height: 16),

                // Info de planes
                _buildInfoPlanes(),
                const SizedBox(height: 24),
              ] else ...[
                // Mensaje para no propietarios
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Contacta con el propietario de la cuenta para renovar la suscripción.',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Cerrar sesión
              OutlinedButton.icon(
                onPressed: () async {
                  PermisosService().limpiarSesion();
                  await FirebaseAuth.instance.signOut();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Cerrar Sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPlanes() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Planes disponibles',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _PlanItem(nombre: 'Plan Básico', precio: '300€/año', descripcion: 'Dashboard, reservas, citas, clientes y valoraciones'),
          const Divider(height: 16),
          _PlanItem(nombre: 'Plan Profesional', precio: '500€/año', descripcion: 'Todo lo anterior + pedidos, tareas, facturación y servicios'),
          const Divider(height: 16),
          _PlanItem(nombre: 'Plan Premium', precio: '800€/año', descripcion: 'Todo incluido + nóminas, empleados, web y fiscal completo'),
        ],
      ),
    );
  }

  Color get _colorEstado {
    switch (estado) {
      case 'VENCIDA': return const Color(0xFFD32F2F);
      case 'PENDIENTE': return const Color(0xFFF57C00);
      default: return const Color(0xFF455A64);
    }
  }

  IconData get _iconoEstado {
    switch (estado) {
      case 'VENCIDA': return Icons.lock_outline;
      case 'PENDIENTE': return Icons.hourglass_empty;
      default: return Icons.block;
    }
  }

  String get _tituloEstado {
    switch (estado) {
      case 'VENCIDA': return 'Suscripción Vencida';
      case 'PENDIENTE': return 'Pago Pendiente';
      default: return 'Acceso Suspendido';
    }
  }

  String get _mensajeEstado {
    switch (estado) {
      case 'VENCIDA':
        return 'Tu suscripción ha caducado. Renueva para volver a acceder a todas las funcionalidades de Fluix CRM.';
      case 'PENDIENTE':
        return 'Tienes un pago pendiente. Completa el pago para continuar usando la app sin interrupciones.';
      default:
        return 'Tu acceso ha sido suspendido temporalmente. Contacta con soporte para más información.';
    }
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  void _contactarRenovacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: Color(0xFF0D47A1)),
            SizedBox(width: 8),
            Text('Renovar Suscripción'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para renovar tu suscripción contacta con nosotros:'),
            SizedBox(height: 16),
            _ContactoItem(icono: Icons.email, texto: 'soporte@fluixtech.com'),
            SizedBox(height: 8),
            _ContactoItem(icono: Icons.phone, texto: '+34 900 123 456'),
            SizedBox(height: 8),
            _ContactoItem(icono: Icons.web, texto: 'www.fluixtech.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _PlanItem extends StatelessWidget {
  final String nombre;
  final String precio;
  final String descripcion;

  const _PlanItem({
    required this.nombre,
    required this.precio,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF0D47A1), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  Text(precio, style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
              Text(descripcion, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactoItem extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _ContactoItem({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 16, color: const Color(0xFF0D47A1)),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

