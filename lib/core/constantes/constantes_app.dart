// Constantes de la aplicación
class ConstantesApp {
  // ── CUENTA PROPIETARIA ─────────────────────────────────────────────────────
  /// ID fijo de la empresa propietaria de la plataforma (FluxTech)
  static const String empresaPropietariaId = '37KyODVYpXYD04VwG3Vf';
  /// Dominio web del propietario
  static const String webPropietaria = 'fluixtech.com';
  /// Nombre comercial del propietario
  static const String nombrePropietario = 'FluxTech';

  // Firebase Collections
  static const String coleccionEmpresas = 'empresas';
  static const String coleccionUsuarios = 'usuarios';
  static const String coleccionClientes = 'clientes';
  static const String coleccionEmpleados = 'empleados';
  static const String coleccionServicios = 'servicios';
  static const String coleccionReservas = 'reservas';
  static const String coleccionValoraciones = 'valoraciones';
  static const String coleccionOfertas = 'ofertas';
  static const String coleccionTransacciones = 'transacciones';
  static const String coleccionDispositivos = 'dispositivos';

  // Subcollections
  static const String subcoleccionPerfil = 'perfil';
  static const String subcoleccionSuscripcion = 'suscripcion';
  static const String subcoleccionConfiguracion = 'configuracion';
  static const String subcoleccionModulos = 'modulos';
  static const String subcoleccionEstadisticas = 'estadisticas';

  // SharedPreferences Keys
  static const String keyUsuarioLogueado = 'usuario_logueado';
  static const String keyEmpresaId = 'empresa_id';
  static const String keyOnboardingCompleto = 'onboarding_completo';
  static const String keyTokenFCM = 'token_fcm';

  // Duración suscripción
  static const int diasSuscripcionAnual = 365;
  static const int diasAvisoVencimiento = 7;

  // Límites
  static const int limitePaginacion = 20;
  static const int maxImagenesOferta = 3;
  static const int maxCaracteresComentario = 500;

  // Colores del tema
  static const String colorPrimario = '#1976D2';
  static const String colorSecundario = '#FFC107';
  static const String colorExito = '#4CAF50';
  static const String colorError = '#F44336';
  static const String colorAdvertencia = '#FF9800';

  // Rutas de navegación
  static const String rutaLogin = '/login';
  static const String rutaRegistro = '/registro';
  static const String rutaOnboarding = '/onboarding';
  static const String rutaDashboard = '/dashboard';
  static const String rutaReservas = '/reservas';
  static const String rutaClientes = '/clientes';
  static const String rutaServicios = '/servicios';
  static const String rutaOfertas = '/ofertas';
  static const String rutaEmpleados = '/empleados';
  static const String rutaConfiguracion = '/configuracion';
  static const String rutaSuscripcion = '/suscripcion';

  // Tipos de archivo permitidos
  static const List<String> extensionesImagenPermitidas = [
    'jpg',
    'jpeg',
    'png',
    'webp'
  ];

  // Tamaño máximo de archivos (en bytes)
  static const int tamanoMaximoImagen = 5 * 1024 * 1024; // 5MB

  // Formatos de fecha
  static const String formatoFecha = 'dd/MM/yyyy';
  static const String formatoFechaHora = 'dd/MM/yyyy HH:mm';
  static const String formatoHora = 'HH:mm';

  // Valores por defecto
  static const double valoracionMinima = 1.0;
  static const double valoracionMaxima = 5.0;
  static const int duracionMinimaServicio = 15; // minutos
  static const int duracionMaximaServicio = 480; // 8 horas

  // Mensajes de error comunes
  static const String errorConexion = 'Error de conexión. Verifica tu internet.';
  static const String errorGenerico = 'Ha ocurrido un error inesperado.';
  static const String errorSesionExpirada = 'Tu sesión ha expirado. Inicia sesión nuevamente.';
  static const String errorPermisosDenegados = 'No tienes permisos para realizar esta acción.';
  static const String errorSuscripcionVencida = 'Tu suscripción ha vencido. Renueva para continuar.';
}
