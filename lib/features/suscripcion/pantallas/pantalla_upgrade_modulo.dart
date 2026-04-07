 // ═════════════════════════════════════════════════════════════════════════════
// PANTALLA DE UPGRADE — Se muestra cuando el usuario intenta acceder a un
// módulo que no tiene contratado en su plan actual.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:planeag_flutter/core/config/planes_config.dart';

class PantallaUpgradeModulo extends StatelessWidget {
  /// ID del módulo al que se intentó acceder (ej: 'facturacion')
  final String moduloId;

  /// Nombre legible del módulo (ej: 'Facturación')
  final String? moduloNombre;

  const PantallaUpgradeModulo({
    super.key,
    required this.moduloId,
    this.moduloNombre,
  });

  @override
  Widget build(BuildContext context) {
    // Buscar qué pack/addon incluye este módulo
    final pack = PlanesConfig.packQueIncluyeModulo(moduloId);
    final addon = PlanesConfig.addonQueIncluyeModulo(moduloId);

    final String productoNombre;
    final String productoPrecio;
    final String productoDescripcion;
    final Color productoColor;
    final IconData productoIcono;

    if (pack != null) {
      productoNombre = pack.nombre;
      productoPrecio = '+${pack.precioAnual.toStringAsFixed(0)}€/año';
      productoDescripcion = pack.descripcion;
      productoColor = pack.color;
      productoIcono = pack.icono;
    } else if (addon != null) {
      productoNombre = addon.nombre;
      productoPrecio = addon.precioLabel;
      productoDescripcion = addon.descripcion;
      productoColor = addon.color;
      productoIcono = addon.icono;
    } else {
      // Módulo desconocido — no debería ocurrir
      productoNombre = 'Módulo no disponible';
      productoPrecio = '';
      productoDescripcion = 'Este módulo no está incluido en tu plan actual.';
      productoColor = Colors.grey;
      productoIcono = Icons.lock_outline;
    }

    final nombre = moduloNombre ?? moduloId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Módulo no disponible'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono del módulo
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: productoColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(productoIcono, size: 64, color: productoColor),
              ),
              const SizedBox(height: 24),

              // Título
              Text(
                '🔒 $nombre',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1a1a2e),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Descripción
              Text(
                'Este módulo está disponible con el $productoNombre.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                productoDescripcion,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Badge de precio
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: productoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: productoColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  productoPrecio,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: productoColor,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Botón ver planes
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('https://fluixcrm.com/planes');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ver planes y contratar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: productoColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botón volver
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Info contacto
              Text(
                '¿Dudas? Escríbenos a soporte@fluixcrm.app',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

