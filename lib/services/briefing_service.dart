import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Briefing matutino del dashboard
//
// Aparece solo entre las 6:00 y las 12:00 del primer acceso del día.
// Agrega datos de múltiples colecciones en paralelo (Future.wait).
// ─────────────────────────────────────────────────────────────────────────────

class BriefingItem {
  final String icono;
  final String texto;
  final int prioridad; // menor = más urgente

  const BriefingItem({
    required this.icono,
    required this.texto,
    required this.prioridad,
  });
}

class BriefingService {
  static final BriefingService _i = BriefingService._();
  factory BriefingService() => _i;
  BriefingService._();

  final _db = FirebaseFirestore.instance;
  static const _prefKey = 'briefing_ultimo_dia';

  /// True si debemos mostrar el briefing ahora.
  Future<bool> debeMostrar() async {
    final ahora = DateTime.now();
    if (ahora.hour < 6 || ahora.hour >= 12) return false;
    final prefs = await SharedPreferences.getInstance();
    final ultimoDia = prefs.getString(_prefKey) ?? '';
    final hoy = DateFormat('yyyy-MM-dd').format(ahora);
    return ultimoDia != hoy;
  }

  /// Marca que el briefing ya fue mostrado hoy (o descartado).
  Future<void> marcarVisto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, DateFormat('yyyy-MM-dd').format(DateTime.now()));
  }

  /// Obtiene los items del briefing en paralelo.
  Future<List<BriefingItem>> obtenerItems({
    required String empresaId,
    required String userId,
  }) async {
    final ahora = DateTime.now();
    final hoyInicio = DateTime(ahora.year, ahora.month, ahora.day);
    final hoyFin = hoyInicio.add(const Duration(days: 1));

    final results = await Future.wait<List<BriefingItem>>([
      _citasHoy(empresaId, hoyInicio, hoyFin),
      _facturasPendientes(empresaId),
      _modelosFiscalesProximos(ahora),
      _tareasUrgentes(empresaId, userId),
      _nominasPendientes(empresaId, ahora),
      _contratosProximosVencer(empresaId, ahora),
    ]);

    final items = <BriefingItem>[];
    for (final list in results) {
      items.addAll(list);
    }

    items.sort((a, b) => a.prioridad.compareTo(b.prioridad));
    return items;
  }

  Future<List<BriefingItem>> _citasHoy(
      String empresaId, DateTime inicio, DateTime fin) async {
    final items = <BriefingItem>[];
    for (final col in ['citas', 'reservas']) {
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection(col)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha', isLessThan: Timestamp.fromDate(fin))
          .get();
      if (snap.docs.isNotEmpty) {
        final nombre = col == 'citas' ? 'citas' : 'reservas';
        items.add(BriefingItem(
          icono: '📅',
          texto: 'Hoy tienes ${snap.docs.length} $nombre.',
          prioridad: 1,
        ));
      }
    }
    return items;
  }

  Future<List<BriefingItem>> _facturasPendientes(String empresaId) async {
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas')
        .where('estado', isEqualTo: 'pendiente')
        .get();
    if (snap.docs.isEmpty) return [];

    final vencidas = snap.docs.where((d) {
      final fechaVenc = (d.data()['fecha_vencimiento'] as Timestamp?)?.toDate();
      return fechaVenc != null && fechaVenc.isBefore(DateTime.now());
    }).length;

    final items = <BriefingItem>[];
    if (vencidas > 0) {
      items.add(BriefingItem(
        icono: '🔴',
        texto: '$vencidas factura${vencidas == 1 ? '' : 's'} vencida${vencidas == 1 ? '' : 's'} sin cobrar.',
        prioridad: 0,
      ));
    } else if (snap.docs.isNotEmpty) {
      items.add(BriefingItem(
        icono: '💰',
        texto: '${snap.docs.length} factura${snap.docs.length == 1 ? '' : 's'} pendiente${snap.docs.length == 1 ? '' : 's'} de cobro.',
        prioridad: 3,
      ));
    }
    return items;
  }

  Future<List<BriefingItem>> _modelosFiscalesProximos(DateTime ahora) async {
    final items = <BriefingItem>[];
    final vencimientos = CalendarioFiscalService.proximosVencimientos(ahora, diasLimite: 7);
    for (final v in vencimientos) {
      items.add(BriefingItem(
        icono: '📋',
        texto: 'El ${v.nombre} vence en ${v.diasRestantes} día${v.diasRestantes == 1 ? '' : 's'}.',
        prioridad: v.diasRestantes <= 3 ? 0 : 2,
      ));
    }
    return items;
  }

  Future<List<BriefingItem>> _tareasUrgentes(
      String empresaId, String userId) async {
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .where('usuario_asignado_id', isEqualTo: userId)
        .where('estado', whereIn: ['pendiente', 'enProgreso'])
        .get();

    final vencidas = snap.docs.where((d) {
      final fl = (d.data()['fecha_limite'] as Timestamp?)?.toDate();
      return fl != null && fl.isBefore(DateTime.now());
    }).length;

    final urgentes = snap.docs.where((d) =>
        d.data()['prioridad'] == 'urgente').length;

    final items = <BriefingItem>[];
    if (vencidas > 0) {
      items.add(BriefingItem(
        icono: '⚠️', texto: '$vencidas tarea${vencidas == 1 ? '' : 's'} vencida${vencidas == 1 ? '' : 's'}.', prioridad: 0));
    }
    if (urgentes > 0) {
      items.add(BriefingItem(
        icono: '🔥', texto: '$urgentes tarea${urgentes == 1 ? '' : 's'} urgente${urgentes == 1 ? '' : 's'}.', prioridad: 1));
    }
    return items;
  }

  Future<List<BriefingItem>> _nominasPendientes(
      String empresaId, DateTime ahora) async {
    if (ahora.day < (DateTime(ahora.year, ahora.month + 1, 0).day - 4)) return [];
    // Últimos 5 días del mes: comprobar si hay nóminas del mes actual
    final mesActual = '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('nominas')
        .where('periodo', isEqualTo: mesActual)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      return [
        const BriefingItem(
            icono: '💼',
            texto: 'Faltan las nóminas de este mes por generar.',
            prioridad: 2),
      ];
    }
    return [];
  }

  Future<List<BriefingItem>> _contratosProximosVencer(
      String empresaId, DateTime ahora) async {
    final limite = ahora.add(const Duration(days: 30));
    final snap = await _db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .where('fecha_fin_contrato', isLessThan: Timestamp.fromDate(limite))
        .where('fecha_fin_contrato', isGreaterThan: Timestamp.fromDate(ahora))
        .get();
    if (snap.docs.isEmpty) return [];
    return [
      BriefingItem(
        icono: '📄',
        texto: '${snap.docs.length} contrato${snap.docs.length == 1 ? '' : 's'} vence${snap.docs.length == 1 ? '' : 'n'} en los próximos 30 días.',
        prioridad: 2,
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CALENDARIO FISCAL — vencimientos AEAT
// ─────────────────────────────────────────────────────────────────────────────

class VencimientoFiscal {
  final String id;
  final String nombre;
  final String descripcion;
  final DateTime fechaLimite;
  final int diasRestantes;

  const VencimientoFiscal({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.fechaLimite,
    required this.diasRestantes,
  });
}

class CalendarioFiscalService {
  /// MOD 303/111/115/130: 1-20 de enero, abril, julio, octubre
  /// MOD 347: febrero (último día hábil)
  /// MOD 190: 1-31 enero
  /// MOD 390: 1-30 enero
  static List<VencimientoFiscal> proximosVencimientos(DateTime ahora,
      {int diasLimite = 30}) {
    final items = <VencimientoFiscal>[];
    final anio = ahora.year;

    // Trimestral: 303, 111, 115, 130
    for (final mes in [1, 4, 7, 10]) {
      var fecha = DateTime(anio, mes, 20);
      fecha = _ajustarDiaHabil(fecha);
      for (final m in [
        ('MOD 303', 'Autoliquidación IVA trimestral'),
        ('MOD 111', 'Retenciones IRPF trabajo/profesional'),
        ('MOD 115', 'Retenciones arrendamientos'),
        ('MOD 130', 'Pago fraccionado autónomos'),
      ]) {
        _addSiProximo(items, m.$1, m.$2, fecha, ahora, diasLimite);
      }
    }

    // MOD 347: último día hábil de febrero
    var feb = DateTime(anio, 2, DateTime(anio, 3, 0).day);
    feb = _ajustarDiaHabilRetro(feb);
    _addSiProximo(items, 'MOD 347', 'Operaciones con terceros >3.005,06€', feb, ahora, diasLimite);

    // MOD 190: 31 enero
    var ene31 = _ajustarDiaHabil(DateTime(anio, 1, 31));
    _addSiProximo(items, 'MOD 190', 'Resumen anual retenciones IRPF', ene31, ahora, diasLimite);

    // MOD 390: 30 enero
    var ene30 = _ajustarDiaHabil(DateTime(anio, 1, 30));
    _addSiProximo(items, 'MOD 390', 'Resumen anual IVA', ene30, ahora, diasLimite);

    items.sort((a, b) => a.diasRestantes.compareTo(b.diasRestantes));
    return items;
  }

  static void _addSiProximo(List<VencimientoFiscal> items, String nombre,
      String desc, DateTime fecha, DateTime ahora, int limite) {
    final diff = fecha.difference(ahora).inDays;
    if (diff >= 0 && diff <= limite) {
      items.add(VencimientoFiscal(
        id: nombre.replaceAll(' ', '_').toLowerCase(),
        nombre: nombre,
        descripcion: desc,
        fechaLimite: fecha,
        diasRestantes: diff,
      ));
    }
  }

  /// Mueve a lunes si cae en sábado/domingo
  static DateTime _ajustarDiaHabil(DateTime d) {
    if (d.weekday == 6) return d.add(const Duration(days: 2));
    if (d.weekday == 7) return d.add(const Duration(days: 1));
    return d;
  }

  /// Mueve al viernes si cae en sábado/domingo
  static DateTime _ajustarDiaHabilRetro(DateTime d) {
    if (d.weekday == 6) return d.subtract(const Duration(days: 1));
    if (d.weekday == 7) return d.subtract(const Duration(days: 2));
    return d;
  }
}



