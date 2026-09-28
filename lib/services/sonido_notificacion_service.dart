import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'bandeja_notificaciones_service.dart';

extension TipoNotificacionExt on TipoNotificacion {
  static TipoNotificacion fromId(String id) {
    switch (id) {
      case 'tareaAsignada':
      case 'tarea_asignada':
        return TipoNotificacion.tareaAsignada;
      case 'facturaVencida':
      case 'factura_vencida':
        return TipoNotificacion.facturaVencida;
      case 'reservaNueva':
      case 'reserva_nueva':
      case 'nueva_reserva':
        return TipoNotificacion.reservaNueva;
      case 'alertaFiscal':
      case 'alerta_fiscal':
        return TipoNotificacion.alertaFiscal;
      case 'nominaPendiente':
      case 'nomina_pendiente':
        return TipoNotificacion.nominaPendiente;
      case 'pedidoNuevo':
      case 'pedido_nuevo':
      case 'nuevo_pedido':
        return TipoNotificacion.pedidoNuevo;
      case 'clienteNuevo':
      case 'cliente_nuevo':
        return TipoNotificacion.clienteNuevo;
      case 'contactoWeb':
      case 'contacto_web':
        return TipoNotificacion.contactoWeb;
      case 'sugerencia':
        return TipoNotificacion.sugerencia;
      case 'vacacionesSolicitadas':
      case 'vacaciones_solicitadas':
        return TipoNotificacion.vacacionesSolicitadas;
      default:
        return TipoNotificacion.generica;
    }
  }

  String get _archivoSonido {
    switch (this) {
      case TipoNotificacion.alertaFiscal:
      case TipoNotificacion.facturaVencida:
        return 'sounds/notif_urgente.wav';
      case TipoNotificacion.reservaNueva:
      case TipoNotificacion.contactoWeb:
        return 'sounds/notif_clasico.wav';
      case TipoNotificacion.pedidoNuevo:
        return 'sounds/notif_digital.wav';
      case TipoNotificacion.tareaAsignada:
      case TipoNotificacion.clienteNuevo:
      case TipoNotificacion.sugerencia:
      case TipoNotificacion.vacacionesSolicitadas:
        return 'sounds/notif_suave.wav';
      default:
        return 'sounds/notif_default.wav';
    }
  }
}

class SonidoNotificacionService {
  static final SonidoNotificacionService _instance =
      SonidoNotificacionService._internal();
  factory SonidoNotificacionService() => _instance;
  SonidoNotificacionService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> reproducirParaTipo(TipoNotificacion tipo) async {
    try {
      await _player.play(AssetSource(tipo._archivoSonido));
    } catch (e) {
      if (kDebugMode) print('⚠️ SonidoNotificacionService: $e');
    }
  }
}
