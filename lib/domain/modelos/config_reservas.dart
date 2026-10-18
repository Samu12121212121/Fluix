import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuración de reservas de una empresa — guardada en
/// empresas/{empresaId}/config_reservas (doc único con id 'config')
class ConfigReservas {
  // ── Tipo ──────────────────────────────────────────────────────────
  final TipoReserva tipo;

  // ── Disponibilidad ────────────────────────────────────────────────
  /// Días de la semana disponibles: 1=Lun … 7=Dom
  final List<int> diasDisponibles;
  final List<FranjaHoraria> franjasHorarias;

  // ── Capacidad ────────────────────────────────────────────────────
  final int? capacidadMaxima;       // personas/reservas por franja
  final int antelacionMinHoras;     // mínimo horas antes de reservar
  final int antelacionMaxDias;      // máximo días vista

  // ── Profesionales ────────────────────────────────────────────────
  final bool permitirElegirProfesional;
  final bool mostrarProfesionales;

  // ── Comportamiento ───────────────────────────────────────────────
  final bool requiereConfirmacion;
  final bool reservarSinRegistro;
  final bool pagosAnticipados;
  final bool listaEspera;
  final String? textoBienvenida;
  final String? instrucciones;
  final String? textoBtnReservar;

  // ── Campos extra del formulario ──────────────────────────────────
  final List<CampoReservaExtra> camposExtra;

  const ConfigReservas({
    this.tipo = TipoReserva.servicio,
    this.diasDisponibles = const [1, 2, 3, 4, 5],
    this.franjasHorarias = const [],
    this.capacidadMaxima,
    this.antelacionMinHoras = 2,
    this.antelacionMaxDias = 30,
    this.permitirElegirProfesional = true,
    this.mostrarProfesionales = true,
    this.requiereConfirmacion = false,
    this.reservarSinRegistro = false,
    this.pagosAnticipados = false,
    this.listaEspera = false,
    this.textoBienvenida,
    this.instrucciones,
    this.textoBtnReservar,
    this.camposExtra = const [],
  });

  factory ConfigReservas.fromMap(Map<String, dynamic> d) => ConfigReservas(
    tipo: TipoReserva.values.firstWhere(
        (t) => t.name == (d['tipo_reserva'] as String? ?? 'servicio'),
        orElse: () => TipoReserva.servicio),
    diasDisponibles: (d['dias_disponibles'] as List?)?.cast<int>() ?? [1,2,3,4,5],
    franjasHorarias: (d['franjas_horarias'] as List?)
        ?.map((f) => FranjaHoraria.fromMap(f as Map<String, dynamic>))
        .toList() ?? [],
    capacidadMaxima: d['capacidad_maxima'] as int?,
    antelacionMinHoras: d['antelacion_min_horas'] as int? ?? 2,
    antelacionMaxDias: d['antelacion_max_dias'] as int? ?? 30,
    permitirElegirProfesional: d['permitir_elegir_profesional'] as bool? ?? true,
    mostrarProfesionales: d['mostrar_profesionales'] as bool? ?? true,
    requiereConfirmacion: d['requiere_confirmacion'] as bool? ?? false,
    reservarSinRegistro: d['reservar_sin_registro'] as bool? ?? false,
    pagosAnticipados: d['pagos_anticipados'] as bool? ?? false,
    listaEspera: d['lista_espera'] as bool? ?? false,
    textoBienvenida: d['texto_bienvenida'] as String?,
    instrucciones: d['instrucciones'] as String?,
    textoBtnReservar: d['texto_btn_reservar'] as String?,
    camposExtra: (d['campos_extra'] as List?)
        ?.map((c) => CampoReservaExtra.fromMap(c as Map<String, dynamic>))
        .toList() ?? [],
  );

  Map<String, dynamic> toMap() => {
    'tipo_reserva': tipo.name,
    'dias_disponibles': diasDisponibles,
    'franjas_horarias': franjasHorarias.map((f) => f.toMap()).toList(),
    if (capacidadMaxima != null) 'capacidad_maxima': capacidadMaxima,
    'antelacion_min_horas': antelacionMinHoras,
    'antelacion_max_dias': antelacionMaxDias,
    'permitir_elegir_profesional': permitirElegirProfesional,
    'mostrar_profesionales': mostrarProfesionales,
    'requiere_confirmacion': requiereConfirmacion,
    'reservar_sin_registro': reservarSinRegistro,
    'pagos_anticipados': pagosAnticipados,
    'lista_espera': listaEspera,
    if (textoBienvenida != null) 'texto_bienvenida': textoBienvenida,
    if (instrucciones != null) 'instrucciones': instrucciones,
    if (textoBtnReservar != null) 'texto_btn_reservar': textoBtnReservar,
    'campos_extra': camposExtra.map((c) => c.toMap()).toList(),
  };

  /// Carga desde Firestore
  static Future<ConfigReservas> cargar(String empresaId) async {
    final doc = await FirebaseFirestore.instance
        .collection('empresas').doc(empresaId)
        .collection('config_reservas').doc('config').get();
    if (!doc.exists || doc.data() == null) return const ConfigReservas();
    return ConfigReservas.fromMap(doc.data()!);
  }

  /// Guarda en Firestore
  Future<void> guardar(String empresaId) =>
      FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('config_reservas').doc('config')
          .set(toMap(), SetOptions(merge: true));

  /// Genera las horas disponibles para una fecha dada
  List<String> horasDisponibles(DateTime fecha) {
    final diaSemana = fecha.weekday; // 1=Lun
    if (!diasDisponibles.contains(diaSemana)) return [];

    if (franjasHorarias.isEmpty) {
      // Default: 10:00–20:00 cada 30min
      return _generarHoras('10:00', '20:00', 30);
    }

    final horas = <String>[];
    for (final f in franjasHorarias) {
      horas.addAll(_generarHoras(f.inicio, f.fin, f.intervaloMinutos));
    }
    return horas;
  }

  static List<String> _generarHoras(String inicio, String fin, int intervalo) {
    final horas = <String>[];
    final partsI = inicio.split(':');
    final partsF = fin.split(':');
    var cur = DateTime(2000, 1, 1, int.parse(partsI[0]), int.parse(partsI[1]));
    final end = DateTime(2000, 1, 1, int.parse(partsF[0]), int.parse(partsF[1]));
    while (cur.isBefore(end)) {
      horas.add('${cur.hour.toString().padLeft(2,'0')}:${cur.minute.toString().padLeft(2,'0')}');
      cur = cur.add(Duration(minutes: intervalo));
    }
    return horas;
  }
}

enum TipoReserva {
  servicio,  // peluquería, estética, clínica → servicio + profesional
  mesa,      // restaurante, bar → nº personas + zona + hora
  espacio,   // gimnasio, hotel, sala → recurso + duración
  generico,  // cualquier negocio → fecha + hora + notas
}

extension TipoReservaExt on TipoReserva {
  String get label => switch (this) {
    TipoReserva.servicio  => 'Cita con servicio',
    TipoReserva.mesa      => 'Reserva de mesa',
    TipoReserva.espacio   => 'Reserva de espacio',
    TipoReserva.generico  => 'Reserva genérica',
  };

  String get icono => switch (this) {
    TipoReserva.servicio  => '✂️',
    TipoReserva.mesa      => '🍽️',
    TipoReserva.espacio   => '🏋️',
    TipoReserva.generico  => '📅',
  };
}

class FranjaHoraria {
  final String inicio;   // "HH:mm"
  final String fin;      // "HH:mm"
  final int intervaloMinutos;

  const FranjaHoraria({
    required this.inicio,
    required this.fin,
    this.intervaloMinutos = 30,
  });

  factory FranjaHoraria.fromMap(Map<String, dynamic> d) => FranjaHoraria(
    inicio: d['inicio'] as String? ?? '10:00',
    fin: d['fin'] as String? ?? '20:00',
    intervaloMinutos: d['intervalo'] as int? ?? 30,
  );

  Map<String, dynamic> toMap() => {
    'inicio': inicio, 'fin': fin, 'intervalo': intervaloMinutos,
  };
}

class CampoReservaExtra {
  final String id;
  final String label;
  final String tipo; // 'texto' | 'numero' | 'selector' | 'checkbox'
  final bool obligatorio;
  final List<String>? opciones;
  final String? placeholder;

  const CampoReservaExtra({
    required this.id,
    required this.label,
    required this.tipo,
    this.obligatorio = false,
    this.opciones,
    this.placeholder,
  });

  factory CampoReservaExtra.fromMap(Map<String, dynamic> d) => CampoReservaExtra(
    id: d['id'] as String? ?? '',
    label: d['label'] as String? ?? '',
    tipo: d['tipo'] as String? ?? 'texto',
    obligatorio: d['obligatorio'] as bool? ?? false,
    opciones: (d['opciones'] as List?)?.cast<String>(),
    placeholder: d['placeholder'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'label': label, 'tipo': tipo,
    'obligatorio': obligatorio,
    if (opciones != null) 'opciones': opciones,
    if (placeholder != null) 'placeholder': placeholder,
  };
}

/// Reserva unificada — compatible con el modelo Reserva existente
/// y con los nuevos tipos de reserva
class ReservaUnificada {
  final String id;
  final TipoReserva tipo;
  final String estado; // pendiente | confirmada | cancelada | completada | no_presentado
  final String origen; // fluix_b2c | web | manual | telefono

  // ── Temporal ──────────────────────────────────────────────────────
  final DateTime fechaHora;
  final String fecha;      // "YYYY-MM-DD"
  final String hora;       // "HH:mm"
  final DateTime fechaCreacion;

  // ── Negocio ───────────────────────────────────────────────────────
  final String negocioId;
  final String negocioNombre;
  final String empresaId;

  // ── Cliente ───────────────────────────────────────────────────────
  final String? clienteUid;
  final String clienteNombre;
  final String clienteEmail;
  final String clienteTelefono;

  // ── Tipo SERVICIO ─────────────────────────────────────────────────
  final String? servicioId;
  final String? servicioNombre;
  final String? empleadoId;
  final String? empleadoNombre;
  final int? duracionMinutos;
  final double? precio;

  // ── Tipo MESA ─────────────────────────────────────────────────────
  final int? numPersonas;
  final String? mesa;
  final String? zona;           // salon | terraza | barra
  final String? alergenos;
  final String? alergenosDetalle;
  final String? peticionEspecial;

  // ── Tipo ESPACIO ──────────────────────────────────────────────────
  final String? recursoId;
  final String? recursoNombre;

  // ── Campos extra configurables ────────────────────────────────────
  final Map<String, dynamic> camposExtra;

  // ── Cancelación ───────────────────────────────────────────────────
  final String? motivoCancelacion;
  final DateTime? fechaCancelacion;

  // ── Notas ─────────────────────────────────────────────────────────
  final String? notas;

  const ReservaUnificada({
    required this.id,
    this.tipo = TipoReserva.generico,
    this.estado = 'pendiente',
    this.origen = 'fluix_b2c',
    required this.fechaHora,
    required this.fecha,
    required this.hora,
    required this.fechaCreacion,
    this.negocioId = '',
    this.negocioNombre = '',
    this.empresaId = '',
    this.clienteUid,
    this.clienteNombre = '',
    this.clienteEmail = '',
    this.clienteTelefono = '',
    this.servicioId,
    this.servicioNombre,
    this.empleadoId,
    this.empleadoNombre,
    this.duracionMinutos,
    this.precio,
    this.numPersonas,
    this.mesa,
    this.zona,
    this.alergenos,
    this.alergenosDetalle,
    this.peticionEspecial,
    this.recursoId,
    this.recursoNombre,
    this.camposExtra = const {},
    this.motivoCancelacion,
    this.fechaCancelacion,
    this.notas,
  });

  factory ReservaUnificada.fromMap(String id, Map<String, dynamic> d) {
    final fh = d['fecha_hora'];
    final fechaHora = fh is Timestamp ? fh.toDate()
        : fh is String ? DateTime.tryParse(fh) ?? DateTime.now()
        : DateTime.now();
    return ReservaUnificada(
      id: id,
      tipo: TipoReserva.values.firstWhere(
          (t) => t.name == (d['tipo'] as String? ?? 'generico'),
          orElse: () => TipoReserva.generico),
      estado: d['estado'] as String? ?? 'pendiente',
      origen: d['origen'] as String? ?? 'fluix_b2c',
      fechaHora: fechaHora,
      fecha: d['fecha'] as String? ?? '',
      hora: d['hora'] as String? ?? '',
      fechaCreacion: (d['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      negocioId: d['negocio_id'] as String? ?? '',
      negocioNombre: d['negocio_nombre'] as String? ?? '',
      empresaId: d['empresa_id'] as String? ?? '',
      clienteUid: d['cliente_uid'] as String? ?? d['usuario_uid'] as String?,
      clienteNombre: d['cliente_nombre'] as String? ?? d['nombre_cliente'] as String? ?? '',
      clienteEmail: d['cliente_email'] as String? ?? d['email_cliente'] as String? ?? '',
      clienteTelefono: d['cliente_telefono'] as String? ?? d['telefono_cliente'] as String? ?? '',
      servicioId: d['servicio_id'] as String?,
      servicioNombre: d['servicio_nombre'] as String?,
      empleadoId: d['empleado_id'] as String? ?? d['profesional_id'] as String?,
      empleadoNombre: d['empleado_nombre'] as String?,
      duracionMinutos: d['duracion_minutos'] as int? ?? d['duracion'] as int?,
      precio: (d['precio'] as num?)?.toDouble(),
      numPersonas: d['num_personas'] as int? ?? d['comensales'] as int?,
      mesa: d['mesa'] as String?,
      zona: d['zona'] as String? ?? d['ubicacion'] as String?,
      alergenos: d['alergenos'] as String?,
      alergenosDetalle: d['alergenos_detalle'] as String?,
      peticionEspecial: d['peticion_especial'] as String?,
      recursoId: d['recurso_id'] as String?,
      recursoNombre: d['recurso_nombre'] as String?,
      camposExtra: (d['campos_extra'] as Map<String, dynamic>?) ?? {},
      motivoCancelacion: d['motivo_cancelacion'] as String?,
      fechaCancelacion: (d['fecha_cancelacion'] as Timestamp?)?.toDate(),
      notas: d['notas'] as String? ?? d['comentarios'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'tipo': tipo.name,
    'estado': estado,
    'origen': origen,
    'fecha_hora': Timestamp.fromDate(fechaHora),
    'fecha': fecha,
    'hora': hora,
    'fecha_creacion': FieldValue.serverTimestamp(),
    'negocio_id': negocioId,
    'negocio_nombre': negocioNombre,
    'empresa_id': empresaId,
    if (clienteUid != null) 'cliente_uid': clienteUid,
    if (clienteUid != null) 'usuario_uid': clienteUid,
    'cliente_nombre': clienteNombre,
    'cliente_email': clienteEmail,
    'cliente_telefono': clienteTelefono,
    // Servicio
    if (servicioId != null) 'servicio_id': servicioId,
    if (servicioNombre != null) 'servicio_nombre': servicioNombre,
    if (empleadoId != null) ...{'empleado_id': empleadoId, 'profesional_id': empleadoId},
    if (empleadoNombre != null) 'empleado_nombre': empleadoNombre,
    if (duracionMinutos != null) ...{'duracion_minutos': duracionMinutos, 'duracion': duracionMinutos},
    if (precio != null) 'precio': precio,
    // Mesa
    if (numPersonas != null) ...{'num_personas': numPersonas, 'comensales': numPersonas},
    if (mesa != null) 'mesa': mesa,
    if (zona != null) ...{'zona': zona, 'ubicacion': zona},
    if (alergenos != null) 'alergenos': alergenos,
    if (alergenosDetalle != null) 'alergenos_detalle': alergenosDetalle,
    if (peticionEspecial != null) 'peticion_especial': peticionEspecial,
    // Espacio
    if (recursoId != null) 'recurso_id': recursoId,
    if (recursoNombre != null) 'recurso_nombre': recursoNombre,
    // Extra
    if (camposExtra.isNotEmpty) 'campos_extra': camposExtra,
    if (notas != null) ...{'notas': notas, 'comentarios': notas},
  };

  String get horaFormateada =>
      '${fechaHora.hour.toString().padLeft(2,'0')}:${fechaHora.minute.toString().padLeft(2,'0')}';

  String get fechaFormateada =>
      '${fechaHora.day.toString().padLeft(2,'0')}/${fechaHora.month.toString().padLeft(2,'0')}/${fechaHora.year}';

  bool get esPendiente => estado == 'pendiente';
  bool get esConfirmada => estado == 'confirmada';
  bool get esCancelada => estado == 'cancelada';
}
