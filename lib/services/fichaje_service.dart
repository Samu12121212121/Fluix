import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../domain/modelos/fichaje.dart';

/// Servicio de control horario / fichaje de empleados
class FichajeService {
  static final FichajeService _i = FichajeService._();
  factory FichajeService() => _i;
  FichajeService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _fichajes(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('fichajes');

  // ── FICHAR ENTRADA ────────────────────────────────────────────────────────

  Future<RegistroFichaje> ficharEntrada({
    required String empresaId,
    required String empleadoId,
    required String empleadoNombre,
    double? latitud,
    double? longitud,
  }) async {
    final registro = RegistroFichaje(
      id: '',
      empleadoId: empleadoId,
      empresaId: empresaId,
      empleadoNombre: empleadoNombre,
      tipo: TipoFichaje.entrada,
      timestamp: DateTime.now(),
      latitud: latitud,
      longitud: longitud,
    );
    final docRef = await _fichajes(empresaId).add(registro.toMap());
    return RegistroFichaje(
      id: docRef.id,
      empleadoId: registro.empleadoId,
      empresaId: registro.empresaId,
      empleadoNombre: registro.empleadoNombre,
      tipo: registro.tipo,
      timestamp: registro.timestamp,
      latitud: registro.latitud,
      longitud: registro.longitud,
    );
  }

  // ── FICHAR SALIDA ─────────────────────────────────────────────────────────

  Future<RegistroFichaje> ficharSalida({
    required String empresaId,
    required String empleadoId,
    required String empleadoNombre,
    double? latitud,
    double? longitud,
  }) async {
    final registro = RegistroFichaje(
      id: '',
      empleadoId: empleadoId,
      empresaId: empresaId,
      empleadoNombre: empleadoNombre,
      tipo: TipoFichaje.salida,
      timestamp: DateTime.now(),
      latitud: latitud,
      longitud: longitud,
    );
    final docRef = await _fichajes(empresaId).add(registro.toMap());
    return RegistroFichaje(
      id: docRef.id,
      empleadoId: registro.empleadoId,
      empresaId: registro.empresaId,
      empleadoNombre: registro.empleadoNombre,
      tipo: registro.tipo,
      timestamp: registro.timestamp,
      latitud: registro.latitud,
      longitud: registro.longitud,
    );
  }

  // ── ESTADO ACTUAL ─────────────────────────────────────────────────────────

  /// Obtiene el último fichaje de un empleado hoy para saber si está trabajando
  Stream<RegistroFichaje?> ultimoFichajeHoy(String empresaId, String empleadoId) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    return _fichajes(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return RegistroFichaje.fromMap(snap.docs.first.data(), snap.docs.first.id);
    });
  }

  // ── FICHAJES DEL DÍA ─────────────────────────────────────────────────────

  Stream<List<RegistroFichaje>> fichajesDelDia(
      String empresaId, String empleadoId, DateTime dia) {
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fin = inicio.add(const Duration(days: 1));
    return _fichajes(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fin))
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
            .toList());
  }

  // ── FICHAJES DE TODOS LOS EMPLEADOS HOY (ADMIN) ──────────────────────────

  Stream<List<RegistroFichaje>> fichajesHoyTodos(String empresaId) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    return _fichajes(empresaId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
            .toList());
  }

  // ── CALCULAR HORAS TRABAJADAS EN UN DÍA ───────────────────────────────────

  double calcularHorasDia(List<RegistroFichaje> fichajesDia) {
    double totalMinutos = 0;
    RegistroFichaje? entradaActual;

    for (final f in fichajesDia) {
      if (f.tipo == TipoFichaje.entrada) {
        entradaActual = f;
      } else if (f.tipo == TipoFichaje.salida && entradaActual != null) {
        totalMinutos +=
            f.timestamp.difference(entradaActual.timestamp).inMinutes;
        entradaActual = null;
      }
    }
    // Si hay entrada sin salida, contar hasta ahora
    if (entradaActual != null) {
      totalMinutos +=
          DateTime.now().difference(entradaActual.timestamp).inMinutes;
    }
    return totalMinutos / 60.0;
  }

  // ── EDITAR FICHAJE (ADMIN) ────────────────────────────────────────────────

  Future<void> editarFichaje(
      String empresaId, String fichajeId, DateTime nuevoTimestamp) async {
    await _fichajes(empresaId).doc(fichajeId).update({
      'timestamp': Timestamp.fromDate(nuevoTimestamp),
      'editado_por_admin': true,
    });
  }

  // ── ELIMINAR FICHAJE (ADMIN) ──────────────────────────────────────────────

  Future<void> eliminarFichaje(String empresaId, String fichajeId) async {
    await _fichajes(empresaId).doc(fichajeId).delete();
  }

  // ── RESUMEN SEMANAL ───────────────────────────────────────────────────────

  Future<List<ResumenDiaFichaje>> resumenSemanal(
      String empresaId, String empleadoId, DateTime semana) async {
    // semana es el lunes de la semana
    final lunes = semana.subtract(Duration(days: semana.weekday - 1));
    final domingo = lunes.add(const Duration(days: 7));

    final snap = await _fichajes(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(lunes))
        .where('timestamp', isLessThan: Timestamp.fromDate(domingo))
        .orderBy('timestamp')
        .get();

    final fichajes = snap.docs
        .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
        .toList();

    // Agrupar por día
    final Map<String, List<RegistroFichaje>> porDia = {};
    for (final f in fichajes) {
      final key = DateFormat('yyyy-MM-dd').format(f.timestamp);
      porDia.putIfAbsent(key, () => []).add(f);
    }

    final List<ResumenDiaFichaje> resumen = [];
    for (int i = 0; i < 7; i++) {
      final dia = lunes.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(dia);
      final fichajesDia = porDia[key] ?? [];
      final horas = calcularHorasDia(fichajesDia);
      final entrada = fichajesDia.isNotEmpty &&
              fichajesDia.first.tipo == TipoFichaje.entrada
          ? fichajesDia.first.timestamp
          : null;
      final salida = fichajesDia.isNotEmpty &&
              fichajesDia.last.tipo == TipoFichaje.salida
          ? fichajesDia.last.timestamp
          : null;

      resumen.add(ResumenDiaFichaje(
        fecha: dia,
        empleadoId: empleadoId,
        entrada: entrada,
        salida: salida,
        horasTrabajadas: horas,
        horasExtra: horas > 8 ? horas - 8 : null,
        fichajePendiente: entrada != null && salida == null,
      ));
    }
    return resumen;
  }

  // ── EXPORTAR CSV ──────────────────────────────────────────────────────────

  Future<String> exportarCsv(
      String empresaId, DateTime desde, DateTime hasta) async {
    final snap = await _fichajes(empresaId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('timestamp', isLessThan: Timestamp.fromDate(hasta))
        .orderBy('timestamp')
        .get();

    final fichajes = snap.docs
        .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
        .toList();

    final buffer = StringBuffer();
    buffer.writeln('Empleado,Tipo,Fecha,Hora,Latitud,Longitud,Editado');
    for (final f in fichajes) {
      buffer.writeln(
        '${f.empleadoNombre},'
        '${f.tipo == TipoFichaje.entrada ? "Entrada" : "Salida"},'
        '${DateFormat('dd/MM/yyyy').format(f.timestamp)},'
        '${DateFormat('HH:mm:ss').format(f.timestamp)},'
        '${f.latitud ?? ""},'
        '${f.longitud ?? ""},'
        '${f.editadoPorAdmin ? "Sí" : "No"}',
      );
    }
    return buffer.toString();
  }

  // ── ALERTAS: FICHAJES PENDIENTES (>9 HORAS) ──────────────────────────────

  Future<List<RegistroFichaje>> fichajesPendientesAlerta(String empresaId) async {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final limite = hoy.subtract(const Duration(hours: 9));

    final snap = await _fichajes(empresaId)
        .where('tipo', isEqualTo: 'entrada')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(limite))
        .get();

    final entradas = snap.docs
        .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
        .toList();

    // Filtrar los que no tienen salida después
    final List<RegistroFichaje> sinSalida = [];
    for (final entrada in entradas) {
      final salidaSnap = await _fichajes(empresaId)
          .where('empleado_id', isEqualTo: entrada.empleadoId)
          .where('tipo', isEqualTo: 'salida')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(entrada.timestamp))
          .limit(1)
          .get();
      if (salidaSnap.docs.isEmpty) {
        sinSalida.add(entrada);
      }
    }
    return sinSalida;
  }
}

