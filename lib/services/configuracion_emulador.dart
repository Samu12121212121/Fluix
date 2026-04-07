import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuración especial para el emulador Android
/// Maneja problemas de conectividad de forma elegante
class ConfiguracionEmulador {
  static Future<void> configurarFirebaseParaEmulador() async {
    try {
      // Habilitar persistencia offline en Firestore
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Configurar timeout más corto para detectar problemas de red rápidamente
      await FirebaseFirestore.instance
          .enableNetwork()
          .timeout(const Duration(seconds: 5));

      print('✅ Firebase configurado para emulador con persistencia offline');
    } catch (e) {
      print('⚠️ Configurando modo offline para emulador: $e');

      // Deshabilitar red y usar solo cache local
      try {
        await FirebaseFirestore.instance.disableNetwork();
        print('📱 Modo offline activado para emulador');
      } catch (offline_error) {
        print('❌ Error configurando modo offline: $offline_error');
      }
    }
  }

  /// Verificar si estamos en emulador
  static bool esEmulador() {
    // Detectar si estamos en emulador basado en indicadores comunes
    return _isEmulator();
  }

  static bool _isEmulator() {
    // Implementación simple para detectar emulador
    // En un caso real podrías usar device_info_plus
    return true; // Asumimos que estamos en emulador para este caso
  }

  /// Estadísticas de emergencia para cuando no hay conexión
  static Map<String, dynamic> obtenerEstadisticasDeEmergencia() {
    return {
      // KPIs principales
      'ingresos_mes': 2850.0,
      'ingresos_mes_anterior': 2650.0,
      'reservas_mes': 42,
      'reservas_mes_anterior': 38,
      'nuevos_clientes_mes': 8,
      'nuevos_clientes_mes_anterior': 6,

      // Métricas de negocio
      'total_clientes': 156,
      'clientes_activos': 89,
      'reservas_confirmadas': 35,
      'reservas_completadas': 28,
      'reservas_pendientes': 7,
      'reservas_canceladas': 3,

      // Rendimiento
      'tasa_conversion': 83.3,
      'tasa_conversion_anterior': 78.9,
      'tasa_cancelacion': 7.1,
      'valor_medio_reserva': 67.86,
      'valor_medio_reserva_anterior': 69.74,

      // Valoraciones
      'valoracion_promedio': 4.6,
      'total_valoraciones': 47,
      'valoraciones_mes': 12,
      'valoraciones_5_estrellas': 28,
      'valoraciones_4_estrellas': 15,
      'valoraciones_3_estrellas': 3,
      'valoraciones_2_estrellas': 1,
      'valoraciones_1_estrella': 0,

      // Servicios y empleados
      'total_servicios_activos': 4,
      'total_empleados_activos': 3,
      'servicio_mas_popular': 'Corte de Pelo',
      'servicio_mas_rentable': 'Tratamiento Facial',
      'empleado_mas_activo': 'Laura Sánchez',

      // Distribución
      'empleados_propietarios': 1,
      'empleados_admin': 1,
      'empleados_staff': 1,

      // Información adicional
      'horas_pico': ['10:00', '16:00', '17:00'],
      'dia_mas_activo': 'viernes',
      'metodo_pago_preferido': 'Tarjeta',
      'cliente_mas_valioso': 'Carmen Ruiz',
      'valor_promedio_cliente': 18.27,
      'total_transacciones_mes': 42,

      // Distribución por días
      'distribucion_dias': {
        'lunes': 5,
        'martes': 6,
        'miércoles': 8,
        'jueves': 7,
        'viernes': 12,
        'sábado': 4
      },

      // Reservas por servicio
      'reservas_por_servicio': {
        'Corte de Pelo': 18,
        'Manicura': 12,
        'Tratamiento Facial': 8,
        'Masaje Relajante': 4
      },

      // Ingresos por servicio
      'ingresos_por_servicio': {
        'Tratamiento Facial': 480.0,
        'Corte de Pelo': 450.0,
        'Manicura': 420.0,
        'Masaje Relajante': 320.0
      },

      // Rendimiento empleados
      'rendimiento_empleados': {
        'Laura Sánchez': {'reservas': 18, 'rol': 'ADMIN'},
        'Juan Pérez': {'reservas': 15, 'rol': 'STAFF'},
        'Carlos Mendoza': {'reservas': 9, 'rol': 'STAFF'}
      },

      // Valoraciones recientes
      'valoraciones_recientes': [
        {
          'cliente': 'María García',
          'calificacion': 5,
          'comentario': 'Excelente servicio, muy profesionales',
          'fecha': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()
        },
        {
          'cliente': 'Ana López',
          'calificacion': 4,
          'comentario': 'Muy buena atención y resultado',
          'fecha': DateTime.now().subtract(const Duration(days: 5)).toIso8601String()
        },
        {
          'cliente': 'Carmen Ruiz',
          'calificacion': 5,
          'comentario': 'Increíble experiencia, totalmente recomendado',
          'fecha': DateTime.now().subtract(const Duration(days: 8)).toIso8601String()
        }
      ],

      // Metadatos
      'modo_offline': true,
      'datos_emulador': true,
      'ultima_actualizacion': DateTime.now().toIso8601String(),
      'fecha_calculo': DateTime.now().toIso8601String()
    };
  }

  /// Simular datos en tiempo real para el emulador
  static void simularDatosEnTiempoReal() {
    // Actualizar cada 30 segundos con pequeñas variaciones
    Stream.periodic(const Duration(seconds: 30)).listen((_) {
      final estadisticas = obtenerEstadisticasDeEmergencia();

      // Pequeñas variaciones aleatorias para simular actividad
      final random = DateTime.now().millisecondsSinceEpoch % 10;
      estadisticas['visitas_tiempo_real'] = 150 + random;
      estadisticas['reservas_hoy'] = 3 + (random % 3);

      print('📊 Datos actualizados para emulador - Visitas: ${estadisticas['visitas_tiempo_real']}');
    });
  }
}
