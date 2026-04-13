import 'package:flutter/material.dart';
import '../../../domain/modelos/configuracion_facturacion_tpv.dart';
import '../../../services/tpv_facturacion_service.dart';
import 'caja_rapida_screen.dart';
import 'importar_ventas_csv_screen.dart';
import 'historial_importaciones_screen.dart';
import 'facturar_pedidos_screen.dart';
import 'configuracion_facturacion_tpv_screen.dart';

class ModuloTpvScreen extends StatelessWidget {
  final String empresaId;

  /// true si el usuario es admin o propietario (puede ver configuración)
  final bool esAdmin;

  const ModuloTpvScreen({
    super.key,
    required this.empresaId,
    this.esAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.point_of_sale, size: 22),
          SizedBox(width: 8),
          Text('TPV', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Acceso rápido: Caja ──────────────────────────────────────────
          _TarjetaAccionTpv(
            icono: Icons.point_of_sale,
            titulo: 'Caja Rápida',
            descripcion: 'Cobra ventas en el mostrador con catálogo visual y ticket imprimible',
            color: const Color(0xFF1565C0),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CajaRapidaScreen(empresaId: empresaId),
            )),
          ),
          const SizedBox(height: 12),

          // ── Importar CSV ─────────────────────────────────────────────────
          _TarjetaAccionTpv(
            icono: Icons.upload_file,
            titulo: 'Importar ventas CSV',
            descripcion: 'Importa el cierre de tu TPV externo (Glop, Agora, ICG, Excel, banco)',
            color: Colors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ImportarVentasCsvScreen(empresaId: empresaId),
            )),
          ),
          const SizedBox(height: 12),

          // ── Historial ────────────────────────────────────────────────────
          _TarjetaAccionTpv(
            icono: Icons.history,
            titulo: 'Historial de importaciones',
            descripcion: 'Consulta y deshaz las importaciones realizadas',
            color: Colors.blueGrey,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => HistorialImportacionesScreen(empresaId: empresaId),
            )),
          ),
          const SizedBox(height: 12),

          // ── Facturar pedidos (modo manual) ───────────────────────────────
          _TarjetaAccionTpvDinamica(
            empresaId: empresaId,
            context: context,
          ),

          // ── Configuración (solo admin) ───────────────────────────────────
          if (esAdmin) ...[
            const SizedBox(height: 12),
            _TarjetaAccionTpv(
              icono: Icons.settings,
              titulo: 'Configuración TPV',
              descripcion: 'Modo de facturación, series, VeriFactu y automatismos',
              color: Colors.grey[700]!,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ConfiguracionFacturacionTpvScreen(empresaId: empresaId),
              )),
            ),
          ],

          const SizedBox(height: 24),

          // ── Resumen de hoy ───────────────────────────────────────────────
          _ResumenHoyWidget(empresaId: empresaId),
        ],
      ),
    );
  }
}

// ── Tarjeta de acción ─────────────────────────────────────────────────────────

class _TarjetaAccionTpv extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final Color color;
  final VoidCallback onTap;

  const _TarjetaAccionTpv({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(descripcion,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de facturar (se carga dinámicamente según config) ─────────────────

class _TarjetaAccionTpvDinamica extends StatelessWidget {
  final String empresaId;
  final BuildContext context;

  const _TarjetaAccionTpvDinamica({required this.empresaId, required this.context});

  @override
  Widget build(BuildContext _) {
    return FutureBuilder<ConfiguracionFacturacionTpv>(
      future: TpvFacturacionService().obtenerConfig(empresaId),
      builder: (ctx, snap) {
        // Solo mostrar si el modo es manual
        if (!snap.hasData || snap.data!.modo != ModoFacturacionTpv.manual) {
          return const SizedBox.shrink();
        }
        return _TarjetaAccionTpv(
          icono: Icons.receipt_long,
          titulo: 'Facturar pedidos',
          descripcion: 'Selecciona los pedidos TPV que quieres facturar manualmente',
          color: Colors.green[700]!,
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => FacturarPedidosScreen(empresaId: empresaId),
          )),
        );
      },
    );
  }
}

// ── Resumen de hoy ────────────────────────────────────────────────────────────

class _ResumenHoyWidget extends StatelessWidget {
  final String empresaId;
  const _ResumenHoyWidget({required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: TpvFacturacionService().contarPendientesStream(empresaId).first,
      builder: (_, snap) {
        final pendientes = snap.data ?? 0;
        if (pendientes == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            border: Border.all(color: Colors.amber[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.pending_actions, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$pendientes pedido${pendientes != 1 ? 's' : ''} pendiente${pendientes != 1 ? 's' : ''} de facturar (últimos 30 días)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

