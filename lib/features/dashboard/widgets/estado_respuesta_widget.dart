import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

/// Widget que muestra el estado de publicación de una respuesta en Google.
/// Estados: redactada / publicando / publicada / error / sin_gmb
class EstadoRespuestaWidget extends StatelessWidget {
  final String? estado; // Firestore: respuesta_estado
  final bool esDeGoogle;

  const EstadoRespuestaWidget({
    super.key,
    required this.estado,
    required this.esDeGoogle,
  });

  @override
  Widget build(BuildContext context) {
    if (!esDeGoogle) return const SizedBox.shrink();

    final config = _configParaEstado(estado);
    if (config == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          config.icono,
          const SizedBox(width: 4),
          Text(
            config.texto,
            style: TextStyle(
                color: config.color,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  _EstadoConfig? _configParaEstado(String? estado) {
    return switch (estado) {
      'publicada' => _EstadoConfig(
          icono: const Icon(Icons.check_circle, size: 11,
              color: Color(0xFF43A047)),
          color: const Color(0xFF43A047),
          texto: 'Publicada en Google',
        ),
      'publicando' => _EstadoConfig(
          icono: const SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Color(0xFF1976D2))),
          color: const Color(0xFF1976D2),
          texto: 'Publicando...',
        ),
      'error_pendiente' => _EstadoConfig(
          icono: const Icon(Icons.schedule, size: 11, color: Color(0xFFF57C00)),
          color: const Color(0xFFF57C00),
          texto: 'Reintentando...',
        ),
      'error_definitivo' => _EstadoConfig(
          icono: const Icon(Icons.error_outline, size: 11,
              color: Color(0xFFD32F2F)),
          color: const Color(0xFFD32F2F),
          texto: 'Error al publicar',
        ),
      'resena_eliminada' => _EstadoConfig(
          icono: const Icon(Icons.delete_outline, size: 11, color: Colors.grey),
          color: Colors.grey,
          texto: 'Reseña eliminada por Google',
        ),
      'sin_conexion_gmb' || 'sin_gmb' => _EstadoConfig(
          icono: const Icon(Icons.save_outlined, size: 11,
              color: Color(0xFF1976D2)),
          color: const Color(0xFF1976D2),
          texto: 'Guardada localmente',
        ),
      _ => null,
    };
  }
}

class _EstadoConfig {
  final Widget icono;
  final Color color;
  final String texto;

  const _EstadoConfig(
      {required this.icono, required this.color, required this.texto});
}

// ── Servicio Flutter para publicar respuesta via Cloud Function ───────────────

class RespuestaGmbService {
  static final RespuestaGmbService _i = RespuestaGmbService._();
  factory RespuestaGmbService() => _i;
  RespuestaGmbService._();

  final _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Publica la respuesta en Google Business Profile.
  /// Devuelve el resultado de la operación.
  Future<PublicarRespuestaResultado> publicar({
    required String empresaId,
    required String valoracionId,
    required String texto,
  }) async {
    try {
      final callable = _functions.httpsCallable('publicarRespuestaGoogle');
      final result = await callable.call({
        'empresaId': empresaId,
        'valoracionId': valoracionId,
        'texto': texto,
      });

      final data = result.data as Map<String, dynamic>;
      return PublicarRespuestaResultado(
        success: data['success'] as bool? ?? false,
        publicadoEnGoogle: data['publicado_google'] as bool? ?? false,
        enCola: data['en_cola'] as bool? ?? false,
        error: data['error'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      return PublicarRespuestaResultado(
        success: false,
        publicadoEnGoogle: false,
        enCola: false,
        error: e.message ?? e.code,
      );
    } catch (e) {
      return PublicarRespuestaResultado(
        success: false,
        publicadoEnGoogle: false,
        enCola: false,
        error: e.toString(),
      );
    }
  }
}

class PublicarRespuestaResultado {
  final bool success;
  final bool publicadoEnGoogle;
  final bool enCola;
  final String? error;

  const PublicarRespuestaResultado({
    required this.success,
    required this.publicadoEnGoogle,
    required this.enCola,
    this.error,
  });
}

