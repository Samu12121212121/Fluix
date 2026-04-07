class WordPressStats {
  final int visitasMes;
  final int visitasMesPasado;
  final int totalPosts;
  final int comentariosMes;
  final int paginasVistas;
  final double tiempoPromedio;
  final int usuariosRegistrados;
  final DateTime ultimaActualizacion;

  const WordPressStats({
    required this.visitasMes,
    required this.visitasMesPasado,
    required this.totalPosts,
    required this.comentariosMes,
    required this.paginasVistas,
    required this.tiempoPromedio,
    required this.usuariosRegistrados,
    required this.ultimaActualizacion,
  });

  factory WordPressStats.fromJson(Map<String, dynamic> json) {
    return WordPressStats(
      visitasMes: json['visitas_mes'] ?? 0,
      visitasMesPasado: json['visitas_mes_pasado'] ?? 0,
      totalPosts: json['total_posts'] ?? 0,
      comentariosMes: json['comentarios_mes'] ?? 0,
      paginasVistas: json['paginas_vistas'] ?? 0,
      tiempoPromedio: (json['tiempo_promedio'] ?? 0.0).toDouble(),
      usuariosRegistrados: json['usuarios_registrados'] ?? 0,
      ultimaActualizacion: DateTime.tryParse(json['ultima_actualizacion'] ?? '') ?? DateTime.now(),
    );
  }

  factory WordPressStats.empty() {
    return WordPressStats(
      visitasMes: 0,
      visitasMesPasado: 0,
      totalPosts: 0,
      comentariosMes: 0,
      paginasVistas: 0,
      tiempoPromedio: 0.0,
      usuariosRegistrados: 0,
      ultimaActualizacion: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visitas_mes': visitasMes,
      'visitas_mes_pasado': visitasMesPasado,
      'total_posts': totalPosts,
      'comentarios_mes': comentariosMes,
      'paginas_vistas': paginasVistas,
      'tiempo_promedio': tiempoPromedio,
      'usuarios_registrados': usuariosRegistrados,
      'ultima_actualizacion': ultimaActualizacion.toIso8601String(),
    };
  }

  double get porcentajeCambioVisitas {
    if (visitasMesPasado == 0) return 0.0;
    return ((visitasMes - visitasMesPasado) / visitasMesPasado * 100);
  }
}

class WordPressReview {
  final String id;
  final String autorNombre;
  final String autorEmail;
  final String contenido;
  final int rating;
  final DateTime fecha;
  final String? respuesta;
  final String estado;
  final String postTitulo;

  const WordPressReview({
    required this.id,
    required this.autorNombre,
    required this.autorEmail,
    required this.contenido,
    required this.rating,
    required this.fecha,
    this.respuesta,
    required this.estado,
    required this.postTitulo,
  });

  factory WordPressReview.fromJson(Map<String, dynamic> json) {
    return WordPressReview(
      id: json['id'].toString(),
      autorNombre: json['author_name'] ?? 'Anónimo',
      autorEmail: json['author_email'] ?? '',
      contenido: json['content'] ?? '',
      rating: json['rating'] ?? 5,
      fecha: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      respuesta: json['reply'],
      estado: json['status'] ?? 'approved',
      postTitulo: json['post_title'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_name': autorNombre,
      'author_email': autorEmail,
      'content': contenido,
      'rating': rating,
      'date': fecha.toIso8601String(),
      'reply': respuesta,
      'status': estado,
      'post_title': postTitulo,
    };
  }
}

class WordPressReservation {
  final String id;
  final String clienteNombre;
  final String clienteEmail;
  final String clienteTelefono;
  final String servicio;
  final DateTime fechaHora;
  final String estado;
  final String notas;
  final DateTime fechaCreacion;

  const WordPressReservation({
    required this.id,
    required this.clienteNombre,
    required this.clienteEmail,
    required this.clienteTelefono,
    required this.servicio,
    required this.fechaHora,
    required this.estado,
    required this.notas,
    required this.fechaCreacion,
  });

  factory WordPressReservation.fromJson(Map<String, dynamic> json) {
    return WordPressReservation(
      id: json['id'].toString(),
      clienteNombre: json['client_name'] ?? '',
      clienteEmail: json['client_email'] ?? '',
      clienteTelefono: json['client_phone'] ?? '',
      servicio: json['service'] ?? '',
      fechaHora: DateTime.tryParse(json['appointment_date'] ?? '') ?? DateTime.now(),
      estado: json['status'] ?? 'pendiente',
      notas: json['notes'] ?? '',
      fechaCreacion: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_name': clienteNombre,
      'client_email': clienteEmail,
      'client_phone': clienteTelefono,
      'service': servicio,
      'appointment_date': fechaHora.toIso8601String(),
      'status': estado,
      'notes': notas,
      'created_at': fechaCreacion.toIso8601String(),
    };
  }

  /// Convierte a formato Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'nombre_cliente': clienteNombre,
      'correo_cliente': clienteEmail,
      'telefono_cliente': clienteTelefono,
      'servicio': servicio,
      'fecha_hora': fechaHora.toIso8601String(),
      'estado': estado,
      'notas': notas,
      'origen': 'wordpress',
      'wordpress_id': id,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }
}

class WordPressContact {
  final String nombre;
  final String email;
  final String telefono;
  final String mensaje;
  final String asunto;
  final DateTime fecha;
  final String origen;

  const WordPressContact({
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.mensaje,
    required this.asunto,
    required this.fecha,
    required this.origen,
  });

  factory WordPressContact.fromJson(Map<String, dynamic> json) {
    return WordPressContact(
      nombre: json['name'] ?? '',
      email: json['email'] ?? '',
      telefono: json['phone'] ?? '',
      mensaje: json['message'] ?? '',
      asunto: json['subject'] ?? '',
      fecha: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      origen: json['form_origin'] ?? 'contacto',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'correo': email,
      'telefono': telefono,
      'mensaje': mensaje,
      'asunto': asunto,
      'fecha': fecha.toIso8601String(),
      'origen': 'wordpress_$origen',
      'estado': 'pendiente',
    };
  }
}

/// Configuración de integración con WordPress
class WordPressConfig {
  final String baseUrl;
  final String apiKey;
  final String secretKey;
  final bool sincronizacionAutomatica;
  final int intervalSincronizacion; // minutos
  final List<String> modulosActivos;

  const WordPressConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.secretKey,
    this.sincronizacionAutomatica = true,
    this.intervalSincronizacion = 15,
    this.modulosActivos = const ['reservas', 'reviews', 'stats', 'contacts'],
  });

  factory WordPressConfig.fromJson(Map<String, dynamic> json) {
    return WordPressConfig(
      baseUrl: json['base_url'] ?? '',
      apiKey: json['api_key'] ?? '',
      secretKey: json['secret_key'] ?? '',
      sincronizacionAutomatica: json['auto_sync'] ?? true,
      intervalSincronizacion: json['sync_interval'] ?? 15,
      modulosActivos: List<String>.from(json['active_modules'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'base_url': baseUrl,
      'api_key': apiKey,
      'secret_key': secretKey,
      'auto_sync': sincronizacionAutomatica,
      'sync_interval': intervalSincronizacion,
      'active_modules': modulosActivos,
    };
  }

  bool get esValida => baseUrl.isNotEmpty && apiKey.isNotEmpty;
}
