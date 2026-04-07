import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — Banner offline sutil ("Mostrando datos del {fecha}")
// ─────────────────────────────────────────────────────────────────────────────

class OfflineBanner extends StatelessWidget {
  final String? ultimaSincronizacion;

  const OfflineBanner({super.key, this.ultimaSincronizacion});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snap) {
        final results = snap.data ?? [ConnectivityResult.wifi];
        final offline = results.contains(ConnectivityResult.none);

        if (!offline) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.orange.shade50,
          child: Row(children: [
            const Icon(Icons.cloud_off, size: 16, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ultimaSincronizacion != null
                    ? 'Sin conexión · Datos del $ultimaSincronizacion'
                    : 'Sin conexión · Mostrando datos guardados',
                style: const TextStyle(
                    fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        );
      },
    );
  }
}

