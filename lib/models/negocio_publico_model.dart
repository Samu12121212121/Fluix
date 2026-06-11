// negocio_publico_model.dart

// ─────────────────────────────────────────────────────────────────────────────
// ENUM
// ─────────────────────────────────────────────────────────────────────────────
enum CategoriaNegocio {
  general,
  restaurantes,
  esteticas,
  peluquerias,
  carnicerias,
  fruterias,
  tatuajes,
  clinicas,
  gimnasios,
  hoteles,
  tiendas,
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Resena Fluix
// ─────────────────────────────────────────────────────────────────────────────
class ResenaFluix {
  final String id;
  final String autorNombre;
  final String? autorAvatarUrl;
  final double estrellas;       // 1.0 – 5.0
  final String comentario;
  final DateTime fecha;
  final bool verificado;        // true = cliente real confirmado
  final String? servicioUsado;  // "Corte y color", etc.
  final String? respuesta;      // Respuesta del negocio
  final DateTime? fechaRespuesta;

  const ResenaFluix({
    required this.id,
    required this.autorNombre,
    this.autorAvatarUrl,
    required this.estrellas,
    required this.comentario,
    required this.fecha,
    this.verificado = false,
    this.servicioUsado,
    this.respuesta,
    this.fechaRespuesta,
  });

  factory ResenaFluix.fromJson(Map<String, dynamic> json) => ResenaFluix(
    id:             json['id'] as String,
    autorNombre:    json['autorNombre'] as String,
    autorAvatarUrl: json['autorAvatarUrl'] as String?,
    estrellas:      (json['estrellas'] as num).toDouble(),
    comentario:     json['comentario'] as String,
    fecha:          (json['fecha'] as dynamic).toDate(),
    verificado:     json['verificado'] as bool? ?? false,
    servicioUsado:  json['servicioUsado'] as String?,
    respuesta:      json['respuesta'] as String?,
    fechaRespuesta: json['fechaRespuesta'] != null
        ? (json['fechaRespuesta'] as dynamic).toDate()
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id':             id,
    'autorNombre':    autorNombre,
    'autorAvatarUrl': autorAvatarUrl,
    'estrellas':      estrellas,
    'comentario':     comentario,
    'fecha':          fecha,
    'verificado':     verificado,
    'servicioUsado':  servicioUsado,
    if (respuesta != null) 'respuesta': respuesta,
    if (fechaRespuesta != null) 'fechaRespuesta': fechaRespuesta,
  };

  ResenaFluix copyWith({
    String? autorNombre,
    String? autorAvatarUrl,
    double? estrellas,
    String? comentario,
    bool? verificado,
    String? servicioUsado,
    String? respuesta,
    DateTime? fechaRespuesta,
  }) =>
      ResenaFluix(
        id:             id,
        autorNombre:    autorNombre ?? this.autorNombre,
        autorAvatarUrl: autorAvatarUrl ?? this.autorAvatarUrl,
        estrellas:      estrellas ?? this.estrellas,
        comentario:     comentario ?? this.comentario,
        fecha:          fecha,
        verificado:     verificado ?? this.verificado,
        servicioUsado:  servicioUsado ?? this.servicioUsado,
        respuesta:      respuesta ?? this.respuesta,
        fechaRespuesta: fechaRespuesta ?? this.fechaRespuesta,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Campo personalizado para formulario de reservas
// ─────────────────────────────────────────────────────────────────────────────
class CampoPersonalizado {
  final String id;
  final String label;
  final String tipo; // 'texto', 'numero', 'email', 'telefono', 'selector', 'checkbox'
  final bool obligatorio;
  final List<String>? opciones;
  final String? placeholder;

  CampoPersonalizado({
    required this.id,
    required this.label,
    required this.tipo,
    this.obligatorio = false,
    this.opciones,
    this.placeholder,
  });

  Map<String, dynamic> toJson() => {
    'id':          id,
    'label':       label,
    'tipo':        tipo,
    'obligatorio': obligatorio,
    if (opciones != null) 'opciones': opciones,
    if (placeholder != null) 'placeholder': placeholder,
  };

  factory CampoPersonalizado.fromJson(Map<String, dynamic> json) =>
      CampoPersonalizado(
        id:          json['id'] as String? ?? '',
        label:       json['label'] as String? ?? '',
        tipo:        json['tipo'] as String? ?? 'texto',
        obligatorio: json['obligatorio'] as bool? ?? false,
        opciones:    (json['opciones'] as List?)?.cast<String>(),
        placeholder: json['placeholder'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Horario de un día
// ─────────────────────────────────────────────────────────────────────────────
class HorarioDia {
  final bool abierto;
  final String? horaApertura;
  final String? horaCierre;
  final String? horaAperturaTarde;
  final String? horaCierreTarde;

  HorarioDia({
    this.abierto = false,
    this.horaApertura,
    this.horaCierre,
    this.horaAperturaTarde,
    this.horaCierreTarde,
  });

  Map<String, dynamic> toJson() => {
    'abierto': abierto,
    if (horaApertura != null) 'horaApertura': horaApertura,
    if (horaCierre != null) 'horaCierre': horaCierre,
    if (horaAperturaTarde != null) 'horaAperturaTarde': horaAperturaTarde,
    if (horaCierreTarde != null) 'horaCierreTarde': horaCierreTarde,
  };

  factory HorarioDia.fromJson(Map<String, dynamic> json) => HorarioDia(
    abierto:           json['abierto'] as bool? ?? false,
    horaApertura:      json['horaApertura'] as String?,
    horaCierre:        json['horaCierre'] as String?,
    horaAperturaTarde: json['horaAperturaTarde'] as String?,
    horaCierreTarde:   json['horaCierreTarde'] as String?,
  );

  String get textoHorario {
    if (!abierto) return 'Cerrado';
    if (horaApertura == null || horaCierre == null) return 'Abierto';
    if (horaAperturaTarde != null && horaCierreTarde != null) {
      return '$horaApertura–$horaCierre / $horaAperturaTarde–$horaCierreTarde';
    }
    return '$horaApertura–$horaCierre';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class NegocioPublico {
  final String id;
  final String nombre;
  final CategoriaNegocio categoria;
  final String? fotoUrl;
  final String? fotoSecundariaUrl;
  final double? ratingGoogle;
  final String? placeId;
  final String empresaIdVinculada;
  final bool activo;
  final String? descripcion;
  final String? direccion;
  final String? telefono;

  // ── Contacto ──────────────────────────────────────────────────────────────
  final String? email;
  final String? emailPublico;
  final String? emailNotificaciones;
  final String? web;
  final String? website;
  final String? googleMapsUrl;
  final String? instagram;
  final String? facebook;
  final String? whatsapp;

  // ── Ratings y textos ──────────────────────────────────────────────────────
  final double? ratingFluix;
  final int?    numResenas;
  final String? tagline;
  final String? precioMedio;

  // ── Amenidades ────────────────────────────────────────────────────────────
  final bool? destacado;
  final bool? reservasOnline;
  final bool? aceptaTarjeta;
  final bool? tieneParking;
  final bool? accesibleSillaRuedas;
  final bool? tieneWifi;
  final bool? admiteMascotas;
  final bool? tieneTerraza;

  // ── Horarios ──────────────────────────────────────────────────────────────
  final Map<int, HorarioDia>? horarios;
  final Map<String, Map<String, dynamic>>? horario;

  // ── Personalización App ────────────────────────────────────────────────────
  final List<String>? fotosGaleria;
  final String? descripcionDetallada;
  final List<String>? serviciosDestacados;
  final List<String>? especialidades;
  final List<String>? caracteristicas;
  final List<CampoPersonalizado>? camposPersonalizados;
  final List<ResenaFluix>? resenasFluix;
  final String? nivelPrecio;
  final String? formularioTitulo;
  final String? formularioBoton;
  final int? duracionPromedio;
  final String? terminosYCondiciones;

  // ── Geolocalización ───────────────────────────────────────────────────────
  final double? latitud;
  final double? longitud;

  // ── Pedidos online ────────────────────────────────────────────────────────
  final bool? aceptaPedidos;
  final List<String>? modalidadesPedido;
  final List<String>? metodosPagoPedido;
  final int?    tiempoPreparacionMin;
  final double? costeEnvio;
  final double? pedidoMinimo;
  final double? radioEntregaKm;
  final String? notasPedido;

  NegocioPublico({
    required this.id,
    required this.nombre,
    required this.categoria,
    this.fotoUrl,
    this.fotoSecundariaUrl,
    this.ratingGoogle,
    this.placeId,
    this.empresaIdVinculada = '',
    this.activo = true,
    this.descripcion,
    this.direccion,
    this.telefono,
    this.email,
    this.emailPublico,
    this.emailNotificaciones,
    this.web,
    this.website,
    this.googleMapsUrl,
    this.instagram,
    this.facebook,
    this.whatsapp,
    this.ratingFluix,
    this.numResenas,
    this.tagline,
    this.precioMedio,
    this.destacado,
    this.reservasOnline,
    this.aceptaTarjeta,
    this.tieneParking,
    this.accesibleSillaRuedas,
    this.tieneWifi,
    this.admiteMascotas,
    this.tieneTerraza,
    this.horarios,
    this.horario,
    this.fotosGaleria,
    this.descripcionDetallada,
    this.serviciosDestacados,
    this.especialidades,
    this.caracteristicas,
    this.camposPersonalizados,
    this.resenasFluix,
    this.nivelPrecio,
    this.formularioTitulo,
    this.formularioBoton,
    this.duracionPromedio,
    this.terminosYCondiciones,
    this.latitud,
    this.longitud,
    this.aceptaPedidos,
    this.modalidadesPedido,
    this.metodosPagoPedido,
    this.tiempoPreparacionMin,
    this.costeEnvio,
    this.pedidoMinimo,
    this.radioEntregaKm,
    this.notasPedido,
  });

  // ── toJson ─────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':                  id,
    'nombre':              nombre,
    'categoria':           categoria.name,
    'fotoUrl':             fotoUrl,
    'fotoSecundariaUrl':   fotoSecundariaUrl,
    'ratingGoogle':        ratingGoogle,
    'placeId':             placeId,
    'empresaIdVinculada':  empresaIdVinculada,
    'activo':              activo,
    'descripcion':         descripcion,
    'direccion':           direccion,
    'telefono':            telefono,
    'email':               email ?? emailPublico,
    'emailPublico':        emailPublico ?? email,
    'emailNotificaciones': emailNotificaciones,
    'web':                 web ?? website,
    'website':             website ?? web,
    'googleMapsUrl':       googleMapsUrl,
    'instagram':           instagram,
    'facebook':            facebook,
    'whatsapp':            whatsapp,
    'ratingFluix':         ratingFluix,
    'numResenas':          numResenas,
    'tagline':             tagline,
    'precioMedio':         precioMedio,
    'destacado':           destacado,
    'reservasOnline':      reservasOnline,
    'aceptaTarjeta':       aceptaTarjeta,
    'tieneParking':        tieneParking,
    'accesibleSillaRuedas': accesibleSillaRuedas,
    'tieneWifi':           tieneWifi,
    'admiteMascotas':      admiteMascotas,
    'tieneTerraza':        tieneTerraza,
    if (horarios != null)
      'horarios': horarios!.map((k, v) => MapEntry(k.toString(), v.toJson())),
    if (horario != null) 'horario': horario,
    if (fotosGaleria != null) 'fotosGaleria': fotosGaleria,
    if (descripcionDetallada != null) 'descripcionDetallada': descripcionDetallada,
    if (serviciosDestacados != null) 'serviciosDestacados': serviciosDestacados,
    if (especialidades != null) 'especialidades': especialidades,
    if (caracteristicas != null) 'caracteristicas': caracteristicas,
    if (camposPersonalizados != null)
      'camposPersonalizados': camposPersonalizados!.map((c) => c.toJson()).toList(),
    if (resenasFluix != null)
      'resenasFluix': resenasFluix!.map((r) => r.toJson()).toList(),
    if (nivelPrecio != null) 'nivelPrecio': nivelPrecio,
    if (formularioTitulo != null) 'formularioTitulo': formularioTitulo,
    if (formularioBoton != null) 'formularioBoton': formularioBoton,
    if (duracionPromedio != null) 'duracionPromedio': duracionPromedio,
    if (terminosYCondiciones != null) 'terminosYCondiciones': terminosYCondiciones,
    if (latitud != null) 'latitud': latitud,
    if (longitud != null) 'longitud': longitud,
    if (aceptaPedidos != null) 'acepta_pedidos': aceptaPedidos,
    if (modalidadesPedido != null) 'modalidades_pedido': modalidadesPedido,
    if (metodosPagoPedido != null) 'metodos_pago_pedido': metodosPagoPedido,
    if (tiempoPreparacionMin != null) 'tiempo_preparacion_min': tiempoPreparacionMin,
    if (costeEnvio != null) 'coste_envio': costeEnvio,
    if (pedidoMinimo != null) 'pedido_minimo': pedidoMinimo,
    if (radioEntregaKm != null) 'radio_entrega_km': radioEntregaKm,
    if (notasPedido != null) 'notas_pedido': notasPedido,
  };

  // ── fromJson ───────────────────────────────────────────────────────────────
  factory NegocioPublico.fromJson(String id, Map<String, dynamic> json) {
    // Horarios (índice int)
    Map<int, HorarioDia>? horariosMap;
    if (json['horarios'] != null) {
      horariosMap = {};
      (json['horarios'] as Map<String, dynamic>).forEach((k, v) {
        horariosMap![int.tryParse(k) ?? 0] =
            HorarioDia.fromJson(v as Map<String, dynamic>);
      });
    }

    // Horario (clave string)
    Map<String, Map<String, dynamic>>? horarioMap;
    if (json['horario'] != null) {
      horarioMap = {};
      (json['horario'] as Map<String, dynamic>).forEach((k, v) {
        horarioMap![k] = Map<String, dynamic>.from(v as Map);
      });
    }

    // Campos personalizados
    List<CampoPersonalizado>? campos;
    if (json['camposPersonalizados'] != null) {
      campos = (json['camposPersonalizados'] as List)
          .map((c) => CampoPersonalizado.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    // Resenas Fluix
    List<ResenaFluix>? resenas;
    if (json['resenasFluix'] != null) {
      resenas = (json['resenasFluix'] as List)
          .map((e) => ResenaFluix.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return NegocioPublico(
      id:                   id,
      nombre:               json['nombre'] as String? ?? '',
      categoria: CategoriaNegocio.values.firstWhere(
            (e) => e.name == json['categoria'],
        orElse: () => CategoriaNegocio.general,
      ),
      fotoUrl:               json['fotoUrl'] as String?,
      fotoSecundariaUrl:     json['fotoSecundariaUrl'] as String?,
      ratingGoogle:          (json['ratingGoogle'] as num?)?.toDouble(),
      placeId:               json['placeId'] as String?,
      empresaIdVinculada:    json['empresaIdVinculada'] as String? ?? '',
      activo:                json['activo'] as bool? ?? true,
      descripcion:           json['descripcion'] as String?,
      direccion:             json['direccion'] as String?,
      telefono:              json['telefono'] as String?,
      email:                 json['email'] as String?,
      emailPublico:          json['emailPublico'] as String? ?? json['email'] as String?,
      emailNotificaciones:   json['emailNotificaciones'] as String?,
      web:                   json['web'] as String?,
      website:               json['website'] as String? ?? json['web'] as String?,
      googleMapsUrl:         json['googleMapsUrl'] as String?,
      instagram:             json['instagram'] as String?,
      facebook:              json['facebook'] as String?,
      whatsapp:              json['whatsapp'] as String?,
      ratingFluix:           (json['ratingFluix'] as num?)?.toDouble(),
      numResenas:            (json['numResenas'] as num?)?.toInt(),
      tagline:               json['tagline'] as String?,
      precioMedio:           json['precioMedio'] as String?,
      destacado:             json['destacado'] as bool?,
      reservasOnline:        json['reservasOnline'] as bool?,
      aceptaTarjeta:         json['aceptaTarjeta'] as bool?,
      tieneParking:          json['tieneParking'] as bool?,
      accesibleSillaRuedas:  json['accesibleSillaRuedas'] as bool?,
      tieneWifi:             json['tieneWifi'] as bool?,
      admiteMascotas:        json['admiteMascotas'] as bool?,
      tieneTerraza:          json['tieneTerraza'] as bool?,
      horarios:              horariosMap,
      horario:               horarioMap,
      fotosGaleria:          (json['fotosGaleria'] as List?)?.cast<String>(),
      descripcionDetallada:  json['descripcionDetallada'] as String?,
      serviciosDestacados:   (json['serviciosDestacados'] as List?)?.cast<String>(),
      especialidades:        (json['especialidades'] as List?)?.cast<String>(),
      caracteristicas:       (json['caracteristicas'] as List?)?.cast<String>(),
      camposPersonalizados:  campos,
      resenasFluix:          resenas,
      nivelPrecio:           json['nivelPrecio'] as String?,
      formularioTitulo:      json['formularioTitulo'] as String?,
      formularioBoton:       json['formularioBoton'] as String?,
      duracionPromedio:      json['duracionPromedio'] as int?,
      terminosYCondiciones:  json['terminosYCondiciones'] as String?,
      latitud:               (json['latitud'] as num?)?.toDouble(),
      longitud:              (json['longitud'] as num?)?.toDouble(),
      aceptaPedidos:         json['acepta_pedidos'] as bool?,
      modalidadesPedido:     (json['modalidades_pedido'] as List?)?.cast<String>(),
      metodosPagoPedido:     (json['metodos_pago_pedido'] as List?)?.cast<String>(),
      tiempoPreparacionMin:  (json['tiempo_preparacion_min'] as num?)?.toInt(),
      costeEnvio:            (json['coste_envio'] as num?)?.toDouble(),
      pedidoMinimo:          (json['pedido_minimo'] as num?)?.toDouble(),
      radioEntregaKm:        (json['radio_entrega_km'] as num?)?.toDouble(),
      notasPedido:           json['notas_pedido'] as String?,
    );
  }

  // ── copyWith ───────────────────────────────────────────────────────────────
  NegocioPublico copyWith({
    String? nombre,
    CategoriaNegocio? categoria,
    String? fotoUrl,
    String? fotoSecundariaUrl,
    double? ratingGoogle,
    String? placeId,
    String? empresaIdVinculada,
    bool? activo,
    String? descripcion,
    String? direccion,
    String? telefono,
    String? email,
    String? emailPublico,
    String? emailNotificaciones,
    String? web,
    String? website,
    String? googleMapsUrl,
    String? instagram,
    String? facebook,
    String? whatsapp,
    double? ratingFluix,
    int? numResenas,
    String? tagline,
    String? precioMedio,
    bool? destacado,
    bool? reservasOnline,
    bool? aceptaTarjeta,
    bool? tieneParking,
    bool? accesibleSillaRuedas,
    bool? tieneWifi,
    bool? admiteMascotas,
    bool? tieneTerraza,
    Map<int, HorarioDia>? horarios,
    Map<String, Map<String, dynamic>>? horario,
    List<String>? fotosGaleria,
    String? descripcionDetallada,
    List<String>? serviciosDestacados,
    List<String>? especialidades,
    List<String>? caracteristicas,
    List<CampoPersonalizado>? camposPersonalizados,
    List<ResenaFluix>? resenasFluix,
    String? nivelPrecio,
    String? formularioTitulo,
    String? formularioBoton,
    int? duracionPromedio,
    String? terminosYCondiciones,
    double? latitud,
    double? longitud,
    bool? aceptaPedidos,
    List<String>? modalidadesPedido,
    List<String>? metodosPagoPedido,
    int? tiempoPreparacionMin,
    double? costeEnvio,
    double? pedidoMinimo,
    double? radioEntregaKm,
    String? notasPedido,
  }) =>
      NegocioPublico(
        id:                   id,
        nombre:               nombre ?? this.nombre,
        categoria:            categoria ?? this.categoria,
        fotoUrl:              fotoUrl ?? this.fotoUrl,
        fotoSecundariaUrl:    fotoSecundariaUrl ?? this.fotoSecundariaUrl,
        ratingGoogle:         ratingGoogle ?? this.ratingGoogle,
        placeId:              placeId ?? this.placeId,
        empresaIdVinculada:   empresaIdVinculada ?? this.empresaIdVinculada,
        activo:               activo ?? this.activo,
        descripcion:          descripcion ?? this.descripcion,
        direccion:            direccion ?? this.direccion,
        telefono:             telefono ?? this.telefono,
        email:                email ?? this.email,
        emailPublico:         emailPublico ?? this.emailPublico,
        emailNotificaciones:  emailNotificaciones ?? this.emailNotificaciones,
        web:                  web ?? this.web,
        website:              website ?? this.website,
        googleMapsUrl:        googleMapsUrl ?? this.googleMapsUrl,
        instagram:            instagram ?? this.instagram,
        facebook:             facebook ?? this.facebook,
        whatsapp:             whatsapp ?? this.whatsapp,
        ratingFluix:          ratingFluix ?? this.ratingFluix,
        numResenas:           numResenas ?? this.numResenas,
        tagline:              tagline ?? this.tagline,
        precioMedio:          precioMedio ?? this.precioMedio,
        destacado:            destacado ?? this.destacado,
        reservasOnline:       reservasOnline ?? this.reservasOnline,
        aceptaTarjeta:        aceptaTarjeta ?? this.aceptaTarjeta,
        tieneParking:         tieneParking ?? this.tieneParking,
        accesibleSillaRuedas: accesibleSillaRuedas ?? this.accesibleSillaRuedas,
        tieneWifi:            tieneWifi ?? this.tieneWifi,
        admiteMascotas:       admiteMascotas ?? this.admiteMascotas,
        tieneTerraza:         tieneTerraza ?? this.tieneTerraza,
        horarios:             horarios ?? this.horarios,
        horario:              horario ?? this.horario,
        fotosGaleria:         fotosGaleria ?? this.fotosGaleria,
        descripcionDetallada: descripcionDetallada ?? this.descripcionDetallada,
        serviciosDestacados:  serviciosDestacados ?? this.serviciosDestacados,
        especialidades:       especialidades ?? this.especialidades,
        caracteristicas:      caracteristicas ?? this.caracteristicas,
        camposPersonalizados: camposPersonalizados ?? this.camposPersonalizados,
        resenasFluix:         resenasFluix ?? this.resenasFluix,
        nivelPrecio:          nivelPrecio ?? this.nivelPrecio,
        formularioTitulo:     formularioTitulo ?? this.formularioTitulo,
        formularioBoton:      formularioBoton ?? this.formularioBoton,
        duracionPromedio:     duracionPromedio ?? this.duracionPromedio,
        terminosYCondiciones: terminosYCondiciones ?? this.terminosYCondiciones,
        latitud:              latitud ?? this.latitud,
        longitud:             longitud ?? this.longitud,
        aceptaPedidos:        aceptaPedidos ?? this.aceptaPedidos,
        modalidadesPedido:    modalidadesPedido ?? this.modalidadesPedido,
        metodosPagoPedido:    metodosPagoPedido ?? this.metodosPagoPedido,
        tiempoPreparacionMin: tiempoPreparacionMin ?? this.tiempoPreparacionMin,
        costeEnvio:           costeEnvio ?? this.costeEnvio,
        pedidoMinimo:         pedidoMinimo ?? this.pedidoMinimo,
        radioEntregaKm:       radioEntregaKm ?? this.radioEntregaKm,
        notasPedido:          notasPedido ?? this.notasPedido,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTENSIONS
// ─────────────────────────────────────────────────────────────────────────────
extension CategoriaNegocioExtension on CategoriaNegocio {
  String get label {
    switch (this) {
      case CategoriaNegocio.general:      return 'General';
      case CategoriaNegocio.restaurantes: return 'Restaurantes';
      case CategoriaNegocio.esteticas:    return 'Estéticas';
      case CategoriaNegocio.peluquerias:  return 'Peluquerías';
      case CategoriaNegocio.carnicerias:  return 'Carnicerías';
      case CategoriaNegocio.fruterias:    return 'Fruterías';
      case CategoriaNegocio.tatuajes:     return 'Tatuajes';
      case CategoriaNegocio.clinicas:     return 'Clínicas';
      case CategoriaNegocio.gimnasios:    return 'Gimnasios';
      case CategoriaNegocio.hoteles:      return 'Hoteles';
      case CategoriaNegocio.tiendas:      return 'Tiendas';
    }
  }

  String get icono {
    switch (this) {
      case CategoriaNegocio.general:      return '🏢';
      case CategoriaNegocio.restaurantes: return '🍽️';
      case CategoriaNegocio.esteticas:    return '💅';
      case CategoriaNegocio.peluquerias:  return '✂️';
      case CategoriaNegocio.carnicerias:  return '🥩';
      case CategoriaNegocio.fruterias:    return '🍎';
      case CategoriaNegocio.tatuajes:     return '🎨';
      case CategoriaNegocio.clinicas:     return '🏥';
      case CategoriaNegocio.gimnasios:    return '🏋️';
      case CategoriaNegocio.hoteles:      return '🏨';
      case CategoriaNegocio.tiendas:      return '🛍️';
    }
  }
}