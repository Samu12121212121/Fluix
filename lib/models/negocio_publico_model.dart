// negocio_publico_model.dart

// ─────────────────────────────────────────────────────────────────────────────
// ENUM
// ─────────────────────────────────────────────────────────────────────────────
enum CategoriaNegocio {
  general, restaurantes, esteticas, peluquerias, barberias,
  cafeterias, carnicerias, fruterias, tatuajes, clinicas, gimnasios, hoteles, tiendas,
}

extension CategoriaNegocioExtension on CategoriaNegocio {
  String get label => const {
    'general': 'General', 'restaurantes': 'Restaurantes', 'esteticas': 'Estéticas',
    'peluquerias': 'Peluquerías', 'barberias': 'Barberías', 'cafeterias': 'Cafeterías',
    'carnicerias': 'Carnicerías', 'fruterias': 'Fruterías', 'tatuajes': 'Tatuajes',
    'clinicas': 'Clínicas', 'gimnasios': 'Gimnasios', 'hoteles': 'Hoteles', 'tiendas': 'Tiendas',
  }[name] ?? 'General';

  String get icono => const {
    'general': '🏢', 'restaurantes': '🍽️', 'esteticas': '💅', 'peluquerias': '✂️',
    'barberias': '🪒', 'cafeterias': '☕', 'carnicerias': '🥩', 'fruterias': '🍎',
    'tatuajes': '🎨', 'clinicas': '🏥', 'gimnasios': '🏋️', 'hoteles': '🏨', 'tiendas': '🛍️',
  }[name] ?? '🏢';
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Resena Fluix
// ─────────────────────────────────────────────────────────────────────────────
class ResenaFluix {
  final String id;
  final String autorNombre;
  final String? autorAvatarUrl;
  final double estrellas;
  final String comentario;
  final DateTime fecha;
  final bool verificado;
  final String? servicioUsado;
  final String? respuesta;
  final DateTime? fechaRespuesta;

  const ResenaFluix({
    required this.id, required this.autorNombre, this.autorAvatarUrl,
    required this.estrellas, required this.comentario, required this.fecha,
    this.verificado = false, this.servicioUsado, this.respuesta, this.fechaRespuesta,
  });

  factory ResenaFluix.fromJson(Map<String, dynamic> json) => ResenaFluix(
    id: json['id'] as String,
    autorNombre: json['autorNombre'] as String,
    autorAvatarUrl: json['autorAvatarUrl'] as String?,
    estrellas: (json['estrellas'] as num?)?.toDouble() ?? 5.0,
    comentario: json['comentario'] as String? ?? '',
    fecha: (json['fecha'] as dynamic).toDate(),
    verificado: json['verificado'] as bool? ?? false,
    servicioUsado: json['servicioUsado'] as String?,
    respuesta: json['respuesta'] as String?,
    fechaRespuesta: json['fechaRespuesta'] != null ? (json['fechaRespuesta'] as dynamic).toDate() : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'autorNombre': autorNombre, 'autorAvatarUrl': autorAvatarUrl,
    'estrellas': estrellas, 'comentario': comentario, 'fecha': fecha,
    'verificado': verificado, 'servicioUsado': servicioUsado,
    if (respuesta != null) 'respuesta': respuesta,
    if (fechaRespuesta != null) 'fechaRespuesta': fechaRespuesta,
  };

  ResenaFluix copyWith({
    String? autorNombre, String? autorAvatarUrl, double? estrellas,
    String? comentario, bool? verificado, String? servicioUsado,
    String? respuesta, DateTime? fechaRespuesta,
  }) => ResenaFluix(
    id: id,
    autorNombre: autorNombre ?? this.autorNombre,
    autorAvatarUrl: autorAvatarUrl ?? this.autorAvatarUrl,
    estrellas: estrellas ?? this.estrellas,
    comentario: comentario ?? this.comentario,
    fecha: fecha,
    verificado: verificado ?? this.verificado,
    servicioUsado: servicioUsado ?? this.servicioUsado,
    respuesta: respuesta ?? this.respuesta,
    fechaRespuesta: fechaRespuesta ?? this.fechaRespuesta,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Campo personalizado
// ─────────────────────────────────────────────────────────────────────────────
class CampoPersonalizado {
  final String id;
  final String label;
  final String tipo; // 'texto', 'numero', 'email', 'telefono', 'selector', 'checkbox'
  final bool obligatorio;
  final List<String>? opciones;
  final String? placeholder;

  CampoPersonalizado({
    required this.id, required this.label, required this.tipo,
    this.obligatorio = false, this.opciones, this.placeholder,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'label': label, 'tipo': tipo, 'obligatorio': obligatorio,
    if (opciones != null) 'opciones': opciones,
    if (placeholder != null) 'placeholder': placeholder,
  };

  factory CampoPersonalizado.fromJson(Map<String, dynamic> json) => CampoPersonalizado(
    id: json['id'] as String? ?? '',
    label: json['label'] as String? ?? '',
    tipo: json['tipo'] as String? ?? 'texto',
    obligatorio: json['obligatorio'] as bool? ?? false,
    opciones: (json['opciones'] as List?)?.cast<String>(),
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
    this.abierto = false, this.horaApertura, this.horaCierre,
    this.horaAperturaTarde, this.horaCierreTarde,
  });

  Map<String, dynamic> toJson() => {
    'abierto': abierto,
    if (horaApertura != null) 'horaApertura': horaApertura,
    if (horaCierre != null) 'horaCierre': horaCierre,
    if (horaAperturaTarde != null) 'horaAperturaTarde': horaAperturaTarde,
    if (horaCierreTarde != null) 'horaCierreTarde': horaCierreTarde,
  };

  factory HorarioDia.fromJson(Map<String, dynamic> json) => HorarioDia(
    abierto: json['abierto'] as bool? ?? false,
    horaApertura: json['horaApertura'] as String?,
    horaCierre: json['horaCierre'] as String?,
    horaAperturaTarde: json['horaAperturaTarde'] as String?,
    horaCierreTarde: json['horaCierreTarde'] as String?,
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
  final bool activo;
  final String empresaIdVinculada;

  // ── Identidad ─────────────────────────────────────────────────────────────
  final String? nombreLegal;
  final String? fotoUrl;           // portada
  final String? fotoSecundariaUrl;
  final String? logoUrl;           // logo pequeño
  final String? avatarUrl;
  final String? descripcion;
  final String? descripcionCorta;
  final String? descripcionDetallada;
  final String? tagline;
  final List<String>? subcategorias;
  final List<String>? etiquetas;
  final int? anioApertura;
  final List<String>? idiomas;
  final List<String>? publicoObjetivo;
  final String? videoUrl;
  final String? nivelPrecio;
  final String? precioMedio;
  final int? duracionPromedio;

  // ── Contacto ──────────────────────────────────────────────────────────────
  final String? telefono;
  final String? whatsapp;
  final String? email;
  final String? emailPublico;
  final String? emailNotificaciones;
  final String? web;
  final String? website;
  final String? instagram;
  final String? facebook;
  final String? tiktok;
  final String? youtube;
  final String? googleMapsUrl;
  final Map<String, bool>? contactoVisible;
  final Map<String, String>? otrasRedes;

  // ── Ubicación ─────────────────────────────────────────────────────────────
  final String? direccion;
  final String? calle;
  final String? numero;
  final String? codigoPostal;
  final String? localidad;
  final String? provincia;
  final double? latitud;
  final double? longitud;
  final bool? mostrarDireccion;
  final String? indicacionesLlegar;
  final String? zonaServicio;
  final double? radioAtencionKm;

  // ── Horarios ──────────────────────────────────────────────────────────────
  final Map<int, HorarioDia>? horarios;
  final Map<String, Map<String, dynamic>>? horario;
  final bool? turnosPartidos;
  final String? cierreTemporalHasta;
  final String? ultimaHoraAdmision;
  final bool? atencionConCita;
  final bool? atencionSinCita;
  final String? zonaHoraria;

  // ── Amenidades / Características ──────────────────────────────────────────
  final bool? destacado;
  final bool? reservasOnline;   // legacy
  final bool? aceptaTarjeta;
  final bool? tieneParking;
  final bool? accesibleSillaRuedas;
  final bool? tieneWifi;
  final bool? admiteMascotas;
  final bool? tieneTerraza;
  final List<String>? caracteristicas;

  // ── Servicios / Personalización ───────────────────────────────────────────
  final List<String>? fotosGaleria;
  final List<String>? serviciosDestacados;
  final List<String>? especialidades;
  final List<CampoPersonalizado>? camposPersonalizados;
  final List<ResenaFluix>? resenasFluix;
  final String? formularioTitulo;
  final String? formularioBoton;
  final String? terminosYCondiciones;

  // ── Reservas config ───────────────────────────────────────────────────────
  final bool? reservasOnlineActivas;
  final String? textoBotonReserva;
  final bool? mostrarAgenda;
  final bool? reservarSinRegistro;
  final int? antelacionMinHoras;
  final int? antelacionMaxDias;
  final bool? pagosAnticipados;
  final bool? listaEspera;
  final String? instruccionesReserva;

  // ── Profesionales ─────────────────────────────────────────────────────────
  final bool? mostrarEquipo;
  final bool? permitirElegirProfesional;

  // ── Reseñas config ────────────────────────────────────────────────────────
  final double? ratingGoogle;
  final double? ratingFluix;
  final int? numResenas;
  final String? placeId;
  final bool? mostrarResenasGoogle;
  final bool? mostrarResenasFluix;
  final bool? permitirResenas;

  // ── Pagos y confianza ─────────────────────────────────────────────────────
  final String? razonSocial;
  final String? nifCif;
  final List<String>? metodosPago;
  final bool? pagosOnline;
  final bool? preciosConImpuestos;
  final bool? facturaDisponible;

  // ── Diseño ────────────────────────────────────────────────────────────────
  final String? colorPrincipal;
  final String? colorSecundario;
  final List<String>? ordenSecciones;
  final Map<String, bool>? seccionesVisibles;
  final String? textoBienvenida;
  final String? mensajePromocional;

  // ── SEO ───────────────────────────────────────────────────────────────────
  final String? urlPublica;
  final String? tituloSeo;
  final String? descripcionSeo;
  final List<String>? palabrasClave;
  final bool? indexarExternamente;
  final bool? aparecerEnResultados;
  final List<String>? idiomasAdicionales;

  // ── Pedidos online (legacy) ────────────────────────────────────────────────
  final bool? aceptaPedidos;
  final List<String>? modalidadesPedido;
  final List<String>? metodosPagoPedido;
  final int? tiempoPreparacionMin;
  final double? costeEnvio;
  final double? pedidoMinimo;
  final double? radioEntregaKm;
  final String? notasPedido;

  NegocioPublico({
    required this.id, required this.nombre, required this.categoria,
    this.activo = true, this.empresaIdVinculada = '',
    this.nombreLegal, this.fotoUrl, this.fotoSecundariaUrl, this.logoUrl, this.avatarUrl,
    this.descripcion, this.descripcionCorta, this.descripcionDetallada, this.tagline,
    this.subcategorias, this.etiquetas, this.anioApertura, this.idiomas,
    this.publicoObjetivo, this.videoUrl, this.nivelPrecio, this.precioMedio, this.duracionPromedio,
    this.telefono, this.whatsapp, this.email, this.emailPublico, this.emailNotificaciones,
    this.web, this.website, this.instagram, this.facebook, this.tiktok, this.youtube,
    this.googleMapsUrl, this.contactoVisible, this.otrasRedes,
    this.direccion, this.calle, this.numero, this.codigoPostal, this.localidad, this.provincia,
    this.latitud, this.longitud, this.mostrarDireccion, this.indicacionesLlegar,
    this.zonaServicio, this.radioAtencionKm,
    this.horarios, this.horario, this.turnosPartidos, this.cierreTemporalHasta,
    this.ultimaHoraAdmision, this.atencionConCita, this.atencionSinCita, this.zonaHoraria,
    this.destacado, this.reservasOnline, this.aceptaTarjeta, this.tieneParking,
    this.accesibleSillaRuedas, this.tieneWifi, this.admiteMascotas, this.tieneTerraza,
    this.caracteristicas,
    this.fotosGaleria, this.serviciosDestacados, this.especialidades,
    this.camposPersonalizados, this.resenasFluix, this.formularioTitulo,
    this.formularioBoton, this.terminosYCondiciones,
    this.reservasOnlineActivas, this.textoBotonReserva, this.mostrarAgenda,
    this.reservarSinRegistro, this.antelacionMinHoras, this.antelacionMaxDias,
    this.pagosAnticipados, this.listaEspera, this.instruccionesReserva,
    this.mostrarEquipo, this.permitirElegirProfesional,
    this.ratingGoogle, this.ratingFluix, this.numResenas, this.placeId,
    this.mostrarResenasGoogle, this.mostrarResenasFluix, this.permitirResenas,
    this.razonSocial, this.nifCif, this.metodosPago, this.pagosOnline,
    this.preciosConImpuestos, this.facturaDisponible,
    this.colorPrincipal, this.colorSecundario, this.ordenSecciones,
    this.seccionesVisibles, this.textoBienvenida, this.mensajePromocional,
    this.urlPublica, this.tituloSeo, this.descripcionSeo, this.palabrasClave,
    this.indexarExternamente, this.aparecerEnResultados, this.idiomasAdicionales,
    this.aceptaPedidos, this.modalidadesPedido, this.metodosPagoPedido,
    this.tiempoPreparacionMin, this.costeEnvio, this.pedidoMinimo,
    this.radioEntregaKm, this.notasPedido,
  });

  bool get tieneDatosMinimos =>
      (fotoUrl != null && fotoUrl!.isNotEmpty) ||
      (descripcion != null && descripcion!.isNotEmpty);

  NegocioPublico copyWith({
    String? id, String? nombre, CategoriaNegocio? categoria,
    bool? activo, String? empresaIdVinculada,
    String? nombreLegal, String? fotoUrl, String? fotoSecundariaUrl,
    String? logoUrl, String? avatarUrl,
    String? descripcion, String? descripcionCorta, String? descripcionDetallada,
    String? tagline,
    List<String>? subcategorias, List<String>? etiquetas,
    int? anioApertura, List<String>? idiomas,
    List<String>? publicoObjetivo, String? videoUrl,
    String? nivelPrecio, String? precioMedio, int? duracionPromedio,
    String? telefono, String? whatsapp, String? email,
    String? emailPublico, String? emailNotificaciones,
    String? web, String? website, String? instagram,
    String? facebook, String? tiktok, String? youtube,
    String? googleMapsUrl, Map<String, bool>? contactoVisible,
    Map<String, String>? otrasRedes,
    String? direccion, String? calle, String? numero,
    String? codigoPostal, String? localidad, String? provincia,
    double? latitud, double? longitud, bool? mostrarDireccion,
    String? indicacionesLlegar, String? zonaServicio, double? radioAtencionKm,
    Map<int, HorarioDia>? horarios,
    Map<String, Map<String, dynamic>>? horario,
    bool? turnosPartidos, String? cierreTemporalHasta,
    String? ultimaHoraAdmision, bool? atencionConCita,
    bool? atencionSinCita, String? zonaHoraria,
    bool? destacado, bool? reservasOnline,
    bool? aceptaTarjeta, bool? tieneParking,
    bool? accesibleSillaRuedas, bool? tieneWifi,
    bool? admiteMascotas, bool? tieneTerraza,
    List<String>? caracteristicas,
    List<String>? fotosGaleria, List<String>? serviciosDestacados,
    List<String>? especialidades,
    List<CampoPersonalizado>? camposPersonalizados,
    List<ResenaFluix>? resenasFluix,
    String? formularioTitulo, String? formularioBoton,
    String? terminosYCondiciones,
    bool? reservasOnlineActivas, String? textoBotonReserva,
    bool? mostrarAgenda, bool? reservarSinRegistro,
    int? antelacionMinHoras, int? antelacionMaxDias,
    bool? pagosAnticipados, bool? listaEspera,
    String? instruccionesReserva,
    bool? mostrarEquipo, bool? permitirElegirProfesional,
    double? ratingGoogle, double? ratingFluix,
    int? numResenas, String? placeId,
    bool? mostrarResenasGoogle, bool? mostrarResenasFluix,
    bool? permitirResenas,
    String? razonSocial, String? nifCif,
    List<String>? metodosPago, bool? pagosOnline,
    bool? preciosConImpuestos, bool? facturaDisponible,
    String? colorPrincipal, String? colorSecundario,
    List<String>? ordenSecciones, Map<String, bool>? seccionesVisibles,
    String? textoBienvenida, String? mensajePromocional,
    String? urlPublica, String? tituloSeo, String? descripcionSeo,
    List<String>? palabrasClave, bool? indexarExternamente,
    bool? aparecerEnResultados, List<String>? idiomasAdicionales,
    bool? aceptaPedidos, List<String>? modalidadesPedido,
    List<String>? metodosPagoPedido, int? tiempoPreparacionMin,
    double? costeEnvio, double? pedidoMinimo,
    double? radioEntregaKm, String? notasPedido,
  }) => NegocioPublico(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    categoria: categoria ?? this.categoria,
    activo: activo ?? this.activo,
    empresaIdVinculada: empresaIdVinculada ?? this.empresaIdVinculada,
    nombreLegal: nombreLegal ?? this.nombreLegal,
    fotoUrl: fotoUrl ?? this.fotoUrl,
    fotoSecundariaUrl: fotoSecundariaUrl ?? this.fotoSecundariaUrl,
    logoUrl: logoUrl ?? this.logoUrl,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    descripcion: descripcion ?? this.descripcion,
    descripcionCorta: descripcionCorta ?? this.descripcionCorta,
    descripcionDetallada: descripcionDetallada ?? this.descripcionDetallada,
    tagline: tagline ?? this.tagline,
    subcategorias: subcategorias ?? this.subcategorias,
    etiquetas: etiquetas ?? this.etiquetas,
    anioApertura: anioApertura ?? this.anioApertura,
    idiomas: idiomas ?? this.idiomas,
    publicoObjetivo: publicoObjetivo ?? this.publicoObjetivo,
    videoUrl: videoUrl ?? this.videoUrl,
    nivelPrecio: nivelPrecio ?? this.nivelPrecio,
    precioMedio: precioMedio ?? this.precioMedio,
    duracionPromedio: duracionPromedio ?? this.duracionPromedio,
    telefono: telefono ?? this.telefono,
    whatsapp: whatsapp ?? this.whatsapp,
    email: email ?? this.email,
    emailPublico: emailPublico ?? this.emailPublico,
    emailNotificaciones: emailNotificaciones ?? this.emailNotificaciones,
    web: web ?? this.web,
    website: website ?? this.website,
    instagram: instagram ?? this.instagram,
    facebook: facebook ?? this.facebook,
    tiktok: tiktok ?? this.tiktok,
    youtube: youtube ?? this.youtube,
    googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
    contactoVisible: contactoVisible ?? this.contactoVisible,
    otrasRedes: otrasRedes ?? this.otrasRedes,
    direccion: direccion ?? this.direccion,
    calle: calle ?? this.calle,
    numero: numero ?? this.numero,
    codigoPostal: codigoPostal ?? this.codigoPostal,
    localidad: localidad ?? this.localidad,
    provincia: provincia ?? this.provincia,
    latitud: latitud ?? this.latitud,
    longitud: longitud ?? this.longitud,
    mostrarDireccion: mostrarDireccion ?? this.mostrarDireccion,
    indicacionesLlegar: indicacionesLlegar ?? this.indicacionesLlegar,
    zonaServicio: zonaServicio ?? this.zonaServicio,
    radioAtencionKm: radioAtencionKm ?? this.radioAtencionKm,
    horarios: horarios ?? this.horarios,
    horario: horario ?? this.horario,
    turnosPartidos: turnosPartidos ?? this.turnosPartidos,
    cierreTemporalHasta: cierreTemporalHasta ?? this.cierreTemporalHasta,
    ultimaHoraAdmision: ultimaHoraAdmision ?? this.ultimaHoraAdmision,
    atencionConCita: atencionConCita ?? this.atencionConCita,
    atencionSinCita: atencionSinCita ?? this.atencionSinCita,
    zonaHoraria: zonaHoraria ?? this.zonaHoraria,
    destacado: destacado ?? this.destacado,
    reservasOnline: reservasOnline ?? this.reservasOnline,
    aceptaTarjeta: aceptaTarjeta ?? this.aceptaTarjeta,
    tieneParking: tieneParking ?? this.tieneParking,
    accesibleSillaRuedas: accesibleSillaRuedas ?? this.accesibleSillaRuedas,
    tieneWifi: tieneWifi ?? this.tieneWifi,
    admiteMascotas: admiteMascotas ?? this.admiteMascotas,
    tieneTerraza: tieneTerraza ?? this.tieneTerraza,
    caracteristicas: caracteristicas ?? this.caracteristicas,
    fotosGaleria: fotosGaleria ?? this.fotosGaleria,
    serviciosDestacados: serviciosDestacados ?? this.serviciosDestacados,
    especialidades: especialidades ?? this.especialidades,
    camposPersonalizados: camposPersonalizados ?? this.camposPersonalizados,
    resenasFluix: resenasFluix ?? this.resenasFluix,
    formularioTitulo: formularioTitulo ?? this.formularioTitulo,
    formularioBoton: formularioBoton ?? this.formularioBoton,
    terminosYCondiciones: terminosYCondiciones ?? this.terminosYCondiciones,
    reservasOnlineActivas: reservasOnlineActivas ?? this.reservasOnlineActivas,
    textoBotonReserva: textoBotonReserva ?? this.textoBotonReserva,
    mostrarAgenda: mostrarAgenda ?? this.mostrarAgenda,
    reservarSinRegistro: reservarSinRegistro ?? this.reservarSinRegistro,
    antelacionMinHoras: antelacionMinHoras ?? this.antelacionMinHoras,
    antelacionMaxDias: antelacionMaxDias ?? this.antelacionMaxDias,
    pagosAnticipados: pagosAnticipados ?? this.pagosAnticipados,
    listaEspera: listaEspera ?? this.listaEspera,
    instruccionesReserva: instruccionesReserva ?? this.instruccionesReserva,
    mostrarEquipo: mostrarEquipo ?? this.mostrarEquipo,
    permitirElegirProfesional: permitirElegirProfesional ?? this.permitirElegirProfesional,
    ratingGoogle: ratingGoogle ?? this.ratingGoogle,
    ratingFluix: ratingFluix ?? this.ratingFluix,
    numResenas: numResenas ?? this.numResenas,
    placeId: placeId ?? this.placeId,
    mostrarResenasGoogle: mostrarResenasGoogle ?? this.mostrarResenasGoogle,
    mostrarResenasFluix: mostrarResenasFluix ?? this.mostrarResenasFluix,
    permitirResenas: permitirResenas ?? this.permitirResenas,
    razonSocial: razonSocial ?? this.razonSocial,
    nifCif: nifCif ?? this.nifCif,
    metodosPago: metodosPago ?? this.metodosPago,
    pagosOnline: pagosOnline ?? this.pagosOnline,
    preciosConImpuestos: preciosConImpuestos ?? this.preciosConImpuestos,
    facturaDisponible: facturaDisponible ?? this.facturaDisponible,
    colorPrincipal: colorPrincipal ?? this.colorPrincipal,
    colorSecundario: colorSecundario ?? this.colorSecundario,
    ordenSecciones: ordenSecciones ?? this.ordenSecciones,
    seccionesVisibles: seccionesVisibles ?? this.seccionesVisibles,
    textoBienvenida: textoBienvenida ?? this.textoBienvenida,
    mensajePromocional: mensajePromocional ?? this.mensajePromocional,
    urlPublica: urlPublica ?? this.urlPublica,
    tituloSeo: tituloSeo ?? this.tituloSeo,
    descripcionSeo: descripcionSeo ?? this.descripcionSeo,
    palabrasClave: palabrasClave ?? this.palabrasClave,
    indexarExternamente: indexarExternamente ?? this.indexarExternamente,
    aparecerEnResultados: aparecerEnResultados ?? this.aparecerEnResultados,
    idiomasAdicionales: idiomasAdicionales ?? this.idiomasAdicionales,
    aceptaPedidos: aceptaPedidos ?? this.aceptaPedidos,
    modalidadesPedido: modalidadesPedido ?? this.modalidadesPedido,
    metodosPagoPedido: metodosPagoPedido ?? this.metodosPagoPedido,
    tiempoPreparacionMin: tiempoPreparacionMin ?? this.tiempoPreparacionMin,
    costeEnvio: costeEnvio ?? this.costeEnvio,
    pedidoMinimo: pedidoMinimo ?? this.pedidoMinimo,
    radioEntregaKm: radioEntregaKm ?? this.radioEntregaKm,
    notasPedido: notasPedido ?? this.notasPedido,
  );

  // ── fromJson ───────────────────────────────────────────────────────────────
  factory NegocioPublico.fromJson(String id, Map<String, dynamic> json) {
    Map<int, HorarioDia>? horariosMap;
    if (json['horarios'] != null) {
      horariosMap = {};
      (json['horarios'] as Map<String, dynamic>).forEach((k, v) {
        horariosMap![int.tryParse(k) ?? 0] = HorarioDia.fromJson(v as Map<String, dynamic>);
      });
    }
    Map<String, Map<String, dynamic>>? horarioMap;
    if (json['horario'] != null) {
      horarioMap = {};
      (json['horario'] as Map<String, dynamic>).forEach((k, v) {
        horarioMap![k] = Map<String, dynamic>.from(v as Map);
      });
    }
    List<CampoPersonalizado>? campos;
    if (json['camposPersonalizados'] != null) {
      campos = (json['camposPersonalizados'] as List)
          .map((c) => CampoPersonalizado.fromJson(c as Map<String, dynamic>)).toList();
    }
    List<ResenaFluix>? resenas;
    if (json['resenasFluix'] != null) {
      resenas = (json['resenasFluix'] as List)
          .map((e) => ResenaFluix.fromJson(e as Map<String, dynamic>)).toList();
    }

    Map<String, bool>? secVis;
    if (json['seccionesVisibles'] != null) {
      secVis = Map<String, bool>.from(json['seccionesVisibles'] as Map);
    }
    Map<String, bool>? ctVis;
    if (json['contactoVisible'] != null) {
      ctVis = Map<String, bool>.from(json['contactoVisible'] as Map);
    }
    Map<String, String>? otrasR;
    if (json['otrasRedes'] != null) {
      otrasR = Map<String, String>.from(json['otrasRedes'] as Map);
    }

    return NegocioPublico(
      id: id,
      nombre: json['nombre'] as String? ?? '',
      categoria: CategoriaNegocio.values.firstWhere(
        (e) => e.name == json['categoria'], orElse: () => CategoriaNegocio.general),
      activo: json['activo'] as bool? ?? true,
      empresaIdVinculada: json['empresaIdVinculada'] as String? ?? '',
      nombreLegal: json['nombreLegal'] as String?,
      fotoUrl: json['fotoUrl'] as String?,
      fotoSecundariaUrl: json['fotoSecundariaUrl'] as String?,
      logoUrl: json['logoUrl'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      descripcion: json['descripcion'] as String?,
      descripcionCorta: json['descripcionCorta'] as String?,
      descripcionDetallada: json['descripcionDetallada'] as String?,
      tagline: json['tagline'] as String?,
      subcategorias: (json['subcategorias'] as List?)?.cast<String>(),
      etiquetas: (json['etiquetas'] as List?)?.cast<String>(),
      anioApertura: (json['anioApertura'] as num?)?.toInt(),
      idiomas: (json['idiomas'] as List?)?.cast<String>(),
      publicoObjetivo: (json['publicoObjetivo'] as List?)?.cast<String>(),
      videoUrl: json['videoUrl'] as String?,
      nivelPrecio: json['nivelPrecio'] as String?,
      precioMedio: json['precioMedio'] as String?,
      duracionPromedio: (json['duracionPromedio'] as num?)?.toInt(),
      telefono: json['telefono'] as String?,
      whatsapp: json['whatsapp'] as String?,
      email: json['email'] as String?,
      emailPublico: json['emailPublico'] as String? ?? json['email'] as String?,
      emailNotificaciones: json['emailNotificaciones'] as String?,
      web: json['web'] as String?,
      website: json['website'] as String? ?? json['web'] as String?,
      instagram: json['instagram'] as String?,
      facebook: json['facebook'] as String?,
      tiktok: json['tiktok'] as String?,
      youtube: json['youtube'] as String?,
      googleMapsUrl: json['googleMapsUrl'] as String?,
      contactoVisible: ctVis,
      otrasRedes: otrasR,
      direccion: json['direccion'] as String?,
      calle: json['calle'] as String?,
      numero: json['numero'] as String?,
      codigoPostal: json['codigoPostal'] as String?,
      localidad: json['localidad'] as String?,
      provincia: json['provincia'] as String?,
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
      mostrarDireccion: json['mostrarDireccion'] as bool?,
      indicacionesLlegar: json['indicacionesLlegar'] as String?,
      zonaServicio: json['zonaServicio'] as String?,
      radioAtencionKm: (json['radioAtencionKm'] as num?)?.toDouble(),
      horarios: horariosMap,
      horario: horarioMap,
      turnosPartidos: json['turnosPartidos'] as bool?,
      cierreTemporalHasta: json['cierreTemporalHasta'] as String?,
      ultimaHoraAdmision: json['ultimaHoraAdmision'] as String?,
      atencionConCita: json['atencionConCita'] as bool?,
      atencionSinCita: json['atencionSinCita'] as bool?,
      zonaHoraria: json['zonaHoraria'] as String?,
      destacado: json['destacado'] as bool?,
      reservasOnline: json['reservasOnline'] as bool?,
      aceptaTarjeta: json['aceptaTarjeta'] as bool?,
      tieneParking: json['tieneParking'] as bool?,
      accesibleSillaRuedas: json['accesibleSillaRuedas'] as bool?,
      tieneWifi: json['tieneWifi'] as bool?,
      admiteMascotas: json['admiteMascotas'] as bool?,
      tieneTerraza: json['tieneTerraza'] as bool?,
      caracteristicas: (json['caracteristicas'] as List?)?.cast<String>(),
      fotosGaleria: (json['fotosGaleria'] as List?)?.cast<String>(),
      serviciosDestacados: (json['serviciosDestacados'] as List?)?.cast<String>(),
      especialidades: (json['especialidades'] as List?)?.cast<String>(),
      camposPersonalizados: campos,
      resenasFluix: resenas,
      formularioTitulo: json['formularioTitulo'] as String?,
      formularioBoton: json['formularioBoton'] as String?,
      terminosYCondiciones: json['terminosYCondiciones'] as String?,
      reservasOnlineActivas: json['reservasOnlineActivas'] as bool?,
      textoBotonReserva: json['textoBotonReserva'] as String?,
      mostrarAgenda: json['mostrarAgenda'] as bool?,
      reservarSinRegistro: json['reservarSinRegistro'] as bool?,
      antelacionMinHoras: (json['antelacionMinHoras'] as num?)?.toInt(),
      antelacionMaxDias: (json['antelacionMaxDias'] as num?)?.toInt(),
      pagosAnticipados: json['pagosAnticipados'] as bool?,
      listaEspera: json['listaEspera'] as bool?,
      instruccionesReserva: json['instruccionesReserva'] as String?,
      mostrarEquipo: json['mostrarEquipo'] as bool?,
      permitirElegirProfesional: json['permitirElegirProfesional'] as bool?,
      ratingGoogle: (json['ratingGoogle'] as num?)?.toDouble(),
      ratingFluix: (json['ratingFluix'] as num?)?.toDouble(),
      numResenas: (json['numResenas'] as num?)?.toInt(),
      placeId: json['placeId'] as String?,
      mostrarResenasGoogle: json['mostrarResenasGoogle'] as bool?,
      mostrarResenasFluix: json['mostrarResenasFluix'] as bool?,
      permitirResenas: json['permitirResenas'] as bool?,
      razonSocial: json['razonSocial'] as String?,
      nifCif: json['nifCif'] as String?,
      metodosPago: (json['metodosPago'] as List?)?.cast<String>(),
      pagosOnline: json['pagosOnline'] as bool?,
      preciosConImpuestos: json['preciosConImpuestos'] as bool?,
      facturaDisponible: json['facturaDisponible'] as bool?,
      colorPrincipal: json['colorPrincipal'] as String?,
      colorSecundario: json['colorSecundario'] as String?,
      ordenSecciones: (json['ordenSecciones'] as List?)?.cast<String>(),
      seccionesVisibles: secVis,
      textoBienvenida: json['textoBienvenida'] as String?,
      mensajePromocional: json['mensajePromocional'] as String?,
      urlPublica: json['urlPublica'] as String?,
      tituloSeo: json['tituloSeo'] as String?,
      descripcionSeo: json['descripcionSeo'] as String?,
      palabrasClave: (json['palabrasClave'] as List?)?.cast<String>(),
      indexarExternamente: json['indexarExternamente'] as bool?,
      aparecerEnResultados: json['aparecerEnResultados'] as bool?,
      idiomasAdicionales: (json['idiomasAdicionales'] as List?)?.cast<String>(),
      aceptaPedidos: json['acepta_pedidos'] as bool?,
      modalidadesPedido: (json['modalidades_pedido'] as List?)?.cast<String>(),
      metodosPagoPedido: (json['metodos_pago_pedido'] as List?)?.cast<String>(),
      tiempoPreparacionMin: (json['tiempo_preparacion_min'] as num?)?.toInt(),
      costeEnvio: (json['coste_envio'] as num?)?.toDouble(),
      pedidoMinimo: (json['pedido_minimo'] as num?)?.toDouble(),
      radioEntregaKm: (json['radio_entrega_km'] as num?)?.toDouble(),
      notasPedido: json['notas_pedido'] as String?,
    );
  }

  // ── toJson ─────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id, 'nombre': nombre, 'categoria': categoria.name, 'activo': activo,
    'empresaIdVinculada': empresaIdVinculada,
    if (nombreLegal != null) 'nombreLegal': nombreLegal,
    if (fotoUrl != null) 'fotoUrl': fotoUrl,
    if (fotoSecundariaUrl != null) 'fotoSecundariaUrl': fotoSecundariaUrl,
    if (logoUrl != null) 'logoUrl': logoUrl,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (descripcion != null) 'descripcion': descripcion,
    if (descripcionCorta != null) 'descripcionCorta': descripcionCorta,
    if (descripcionDetallada != null) 'descripcionDetallada': descripcionDetallada,
    if (tagline != null) 'tagline': tagline,
    if (subcategorias != null) 'subcategorias': subcategorias,
    if (etiquetas != null) 'etiquetas': etiquetas,
    if (anioApertura != null) 'anioApertura': anioApertura,
    if (idiomas != null) 'idiomas': idiomas,
    if (publicoObjetivo != null) 'publicoObjetivo': publicoObjetivo,
    if (videoUrl != null) 'videoUrl': videoUrl,
    if (nivelPrecio != null) 'nivelPrecio': nivelPrecio,
    if (precioMedio != null) 'precioMedio': precioMedio,
    if (duracionPromedio != null) 'duracionPromedio': duracionPromedio,
    if (telefono != null) 'telefono': telefono,
    if (whatsapp != null) 'whatsapp': whatsapp,
    'email': email ?? emailPublico,
    'emailPublico': emailPublico ?? email,
    if (emailNotificaciones != null) 'emailNotificaciones': emailNotificaciones,
    'web': web ?? website, 'website': website ?? web,
    if (instagram != null) 'instagram': instagram,
    if (facebook != null) 'facebook': facebook,
    if (tiktok != null) 'tiktok': tiktok,
    if (youtube != null) 'youtube': youtube,
    if (googleMapsUrl != null) 'googleMapsUrl': googleMapsUrl,
    if (contactoVisible != null) 'contactoVisible': contactoVisible,
    if (otrasRedes != null) 'otrasRedes': otrasRedes,
    if (direccion != null) 'direccion': direccion,
    if (calle != null) 'calle': calle,
    if (numero != null) 'numero': numero,
    if (codigoPostal != null) 'codigoPostal': codigoPostal,
    if (localidad != null) 'localidad': localidad,
    if (provincia != null) 'provincia': provincia,
    if (latitud != null) 'latitud': latitud,
    if (longitud != null) 'longitud': longitud,
    if (mostrarDireccion != null) 'mostrarDireccion': mostrarDireccion,
    if (indicacionesLlegar != null) 'indicacionesLlegar': indicacionesLlegar,
    if (zonaServicio != null) 'zonaServicio': zonaServicio,
    if (radioAtencionKm != null) 'radioAtencionKm': radioAtencionKm,
    if (horarios != null) 'horarios': horarios!.map((k, v) => MapEntry(k.toString(), v.toJson())),
    if (horario != null) 'horario': horario,
    if (turnosPartidos != null) 'turnosPartidos': turnosPartidos,
    if (cierreTemporalHasta != null) 'cierreTemporalHasta': cierreTemporalHasta,
    if (ultimaHoraAdmision != null) 'ultimaHoraAdmision': ultimaHoraAdmision,
    if (atencionConCita != null) 'atencionConCita': atencionConCita,
    if (atencionSinCita != null) 'atencionSinCita': atencionSinCita,
    if (zonaHoraria != null) 'zonaHoraria': zonaHoraria,
    'destacado': destacado, 'reservasOnline': reservasOnline,
    'aceptaTarjeta': aceptaTarjeta, 'tieneParking': tieneParking,
    'accesibleSillaRuedas': accesibleSillaRuedas, 'tieneWifi': tieneWifi,
    'admiteMascotas': admiteMascotas, 'tieneTerraza': tieneTerraza,
    if (caracteristicas != null) 'caracteristicas': caracteristicas,
    if (fotosGaleria != null) 'fotosGaleria': fotosGaleria,
    if (serviciosDestacados != null) 'serviciosDestacados': serviciosDestacados,
    if (especialidades != null) 'especialidades': especialidades,
    if (camposPersonalizados != null) 'camposPersonalizados': camposPersonalizados!.map((c) => c.toJson()).toList(),
    if (resenasFluix != null) 'resenasFluix': resenasFluix!.map((r) => r.toJson()).toList(),
    if (formularioTitulo != null) 'formularioTitulo': formularioTitulo,
    if (formularioBoton != null) 'formularioBoton': formularioBoton,
    if (terminosYCondiciones != null) 'terminosYCondiciones': terminosYCondiciones,
    if (reservasOnlineActivas != null) 'reservasOnlineActivas': reservasOnlineActivas,
    if (textoBotonReserva != null) 'textoBotonReserva': textoBotonReserva,
    if (mostrarAgenda != null) 'mostrarAgenda': mostrarAgenda,
    if (reservarSinRegistro != null) 'reservarSinRegistro': reservarSinRegistro,
    if (antelacionMinHoras != null) 'antelacionMinHoras': antelacionMinHoras,
    if (antelacionMaxDias != null) 'antelacionMaxDias': antelacionMaxDias,
    if (pagosAnticipados != null) 'pagosAnticipados': pagosAnticipados,
    if (listaEspera != null) 'listaEspera': listaEspera,
    if (instruccionesReserva != null) 'instruccionesReserva': instruccionesReserva,
    if (mostrarEquipo != null) 'mostrarEquipo': mostrarEquipo,
    if (permitirElegirProfesional != null) 'permitirElegirProfesional': permitirElegirProfesional,
    if (ratingGoogle != null) 'ratingGoogle': ratingGoogle,
    if (ratingFluix != null) 'ratingFluix': ratingFluix,
    if (numResenas != null) 'numResenas': numResenas,
    if (placeId != null) 'placeId': placeId,
    if (mostrarResenasGoogle != null) 'mostrarResenasGoogle': mostrarResenasGoogle,
    if (mostrarResenasFluix != null) 'mostrarResenasFluix': mostrarResenasFluix,
    if (permitirResenas != null) 'permitirResenas': permitirResenas,
    if (razonSocial != null) 'razonSocial': razonSocial,
    if (nifCif != null) 'nifCif': nifCif,
    if (metodosPago != null) 'metodosPago': metodosPago,
    if (pagosOnline != null) 'pagosOnline': pagosOnline,
    if (preciosConImpuestos != null) 'preciosConImpuestos': preciosConImpuestos,
    if (facturaDisponible != null) 'facturaDisponible': facturaDisponible,
    if (colorPrincipal != null) 'colorPrincipal': colorPrincipal,
    if (colorSecundario != null) 'colorSecundario': colorSecundario,
    if (ordenSecciones != null) 'ordenSecciones': ordenSecciones,
    if (seccionesVisibles != null) 'seccionesVisibles': seccionesVisibles,
    if (textoBienvenida != null) 'textoBienvenida': textoBienvenida,
    if (mensajePromocional != null) 'mensajePromocional': mensajePromocional,
    if (urlPublica != null) 'urlPublica': urlPublica,
    if (tituloSeo != null) 'tituloSeo': tituloSeo,
    if (descripcionSeo != null) 'descripcionSeo': descripcionSeo,
    if (palabrasClave != null) 'palabrasClave': palabrasClave,
    if (indexarExternamente != null) 'indexarExternamente': indexarExternamente,
    if (aparecerEnResultados != null) 'aparecerEnResultados': aparecerEnResultados,
    if (idiomasAdicionales != null) 'idiomasAdicionales': idiomasAdicionales,
    if (aceptaPedidos != null) 'acepta_pedidos': aceptaPedidos,
    if (modalidadesPedido != null) 'modalidades_pedido': modalidadesPedido,
    if (metodosPagoPedido != null) 'metodos_pago_pedido': metodosPagoPedido,
    if (tiempoPreparacionMin != null) 'tiempo_preparacion_min': tiempoPreparacionMin,
    if (costeEnvio != null) 'coste_envio': costeEnvio,
    if (pedidoMinimo != null) 'pedido_minimo': pedidoMinimo,
    if (radioEntregaKm != null) 'radio_entrega_km': radioEntregaKm,
    if (notasPedido != null) 'notas_pedido': notasPedido,
  };
}
