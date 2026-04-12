import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/modelos/empresa_config.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CALENDARIO FISCAL — Servicio de plazos y vencimientos
// ═══════════════════════════════════════════════════════════════════════════════

enum EstadoDeadline { pendiente, presentado, vencido }

class DeadlineFiscal {
  final String modelo;
  final String periodo;          // "1T", "2T", "3T", "4T", "1P", "2P", "3P", "anual"
  final String descripcion;
  final DateTime fechaLimite;
  final EstadoDeadline estado;
  final String? justificante;    // Nº justificante AEAT si presentado

  const DeadlineFiscal({
    required this.modelo,
    required this.periodo,
    required this.descripcion,
    required this.fechaLimite,
    this.estado = EstadoDeadline.pendiente,
    this.justificante,
  });

  int get diasRestantes => fechaLimite.difference(DateTime.now()).inDays;
  bool get esUrgente => diasRestantes >= 0 && diasRestantes <= 7;
  bool get estaVencido => diasRestantes < 0 && estado != EstadoDeadline.presentado;

  DeadlineFiscal conEstado(EstadoDeadline nuevoEstado, [String? nuevoJustificante]) =>
      DeadlineFiscal(
        modelo: modelo,
        periodo: periodo,
        descripcion: descripcion,
        fechaLimite: fechaLimite,
        estado: nuevoEstado,
        justificante: nuevoJustificante ?? justificante,
      );
}

class CalendarioFiscalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Genera todos los deadlines para un ejercicio según forma jurídica.
  List<DeadlineFiscal> generarDeadlines(int ejercicio, FormaJuridica forma) {
    final deadlines = <DeadlineFiscal>[];

    // ── TRIMESTRALES — todos ───────────────────────────────────────────────

    // Modelo 303 — IVA (todos)
    for (final t in [1, 2, 3, 4]) {
      deadlines.add(DeadlineFiscal(
        modelo: '303',
        periodo: '${t}T',
        descripcion: 'Autoliquidación IVA ${t}T',
        fechaLimite: _plazoTrimestral(ejercicio, t),
      ));
    }

    // Modelo 111 — Retenciones IRPF (todos los que tengan empleados)
    for (final t in [1, 2, 3, 4]) {
      deadlines.add(DeadlineFiscal(
        modelo: '111',
        periodo: '${t}T',
        descripcion: 'Retenciones IRPF ${t}T',
        fechaLimite: _plazoTrimestral(ejercicio, t),
      ));
    }

    // Modelo 115 — Retenciones arrendamientos (todos los que alquilen)
    for (final t in [1, 2, 3, 4]) {
      deadlines.add(DeadlineFiscal(
        modelo: '115',
        periodo: '${t}T',
        descripcion: 'Retenciones alquileres ${t}T',
        fechaLimite: _plazoTrimestral(ejercicio, t),
      ));
    }

    // ── TRIMESTRALES — según forma jurídica ────────────────────────────────

    if (forma.tributaIRPF) {
      // Modelo 130 — Pago fraccionado IRPF (autónomos)
      for (final t in [1, 2, 3, 4]) {
        deadlines.add(DeadlineFiscal(
          modelo: '130',
          periodo: '${t}T',
          descripcion: 'IRPF autónomos ${t}T',
          fechaLimite: _plazoTrimestral(ejercicio, t),
        ));
      }
    }

    if (forma.esSociedad) {
      // Modelo 202 — Pago fraccionado IS (sociedades)
      deadlines.add(DeadlineFiscal(
        modelo: '202',
        periodo: '1P',
        descripcion: 'Pago fraccionado IS (abril)',
        fechaLimite: DateTime(ejercicio, 4, 20),
      ));
      deadlines.add(DeadlineFiscal(
        modelo: '202',
        periodo: '2P',
        descripcion: 'Pago fraccionado IS (octubre)',
        fechaLimite: DateTime(ejercicio, 10, 20),
      ));
      deadlines.add(DeadlineFiscal(
        modelo: '202',
        periodo: '3P',
        descripcion: 'Pago fraccionado IS (diciembre)',
        fechaLimite: DateTime(ejercicio, 12, 20),
      ));
    }

    // ── ANUALES ────────────────────────────────────────────────────────────

    // Modelo 390 — Resumen anual IVA (enero siguiente)
    deadlines.add(DeadlineFiscal(
      modelo: '390',
      periodo: 'anual',
      descripcion: 'Resumen anual IVA',
      fechaLimite: DateTime(ejercicio + 1, 1, 30),
    ));

    // Modelo 190 — Resumen anual retenciones IRPF (enero siguiente)
    deadlines.add(DeadlineFiscal(
      modelo: '190',
      periodo: 'anual',
      descripcion: 'Resumen anual retenciones IRPF',
      fechaLimite: DateTime(ejercicio + 1, 1, 31),
    ));

    // Modelo 347 — Operaciones con terceros (febrero siguiente)
    deadlines.add(DeadlineFiscal(
      modelo: '347',
      periodo: 'anual',
      descripcion: 'Operaciones con terceros >3.005,06€',
      fechaLimite: DateTime(ejercicio + 1, 2, 28),
    ));

    deadlines.sort((a, b) => a.fechaLimite.compareTo(b.fechaLimite));
    return deadlines;
  }

  /// Obtiene los próximos N deadlines con estado actualizado desde Firestore.
  Future<List<DeadlineFiscal>> obtenerProximos({
    required String empresaId,
    required int ejercicio,
    required FormaJuridica forma,
    int cantidad = 3,
  }) async {
    final todos = generarDeadlines(ejercicio, forma);
    final ahora = DateTime.now();

    // Cargar estados presentados desde Firestore
    final snapshot = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('modelos_fiscales')
        .where('ejercicio', isEqualTo: ejercicio)
        .get();

    final presentados = <String, String?>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['estado'] == 'presentado') {
        final key = '${data['modelo']}_${data['trimestre'] ?? data['periodo'] ?? 'anual'}';
        presentados[key] = data['justificante_aeat'] as String?;
      }
    }

    // Actualizar estados
    final actualizados = todos.map((d) {
      final key = '${d.modelo}_${d.periodo}';
      if (presentados.containsKey(key)) {
        return d.conEstado(EstadoDeadline.presentado, presentados[key]);
      }
      if (d.fechaLimite.isBefore(ahora)) {
        return d.conEstado(EstadoDeadline.vencido);
      }
      return d;
    }).toList();

    // Filtrar: mostrar los próximos no presentados + urgentes
    final pendientes = actualizados
        .where((d) => d.estado != EstadoDeadline.presentado)
        .take(cantidad)
        .toList();

    return pendientes;
  }

  /// Marca un modelo como presentado con justificante AEAT.
  Future<void> marcarPresentado({
    required String empresaId,
    required String modelo,
    required int ejercicio,
    required String periodo,
    String? justificante,
  }) async {
    final docId = '${modelo}_${ejercicio}_$periodo';
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('modelos_fiscales')
        .doc(docId)
        .set({
      'modelo': modelo,
      'ejercicio': ejercicio,
      'periodo': periodo,
      'trimestre': periodo,
      'estado': 'presentado',
      'justificante_aeat': justificante,
      'fecha_presentacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Plazos AEAT ────────────────────────────────────────────────────────────

  static DateTime _plazoTrimestral(int ejercicio, int trimestre) {
    switch (trimestre) {
      case 1: return DateTime(ejercicio, 4, 20);
      case 2: return DateTime(ejercicio, 7, 20);
      case 3: return DateTime(ejercicio, 10, 20);
      case 4: return DateTime(ejercicio + 1, 1, 30);
      default: return DateTime(ejercicio, 4, 20);
    }
  }
}

