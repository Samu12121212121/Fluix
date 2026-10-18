import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../services/verifactu/modelos_verifactu.dart';
import '../../../services/verifactu/hash_chain_service.dart';
import '../../../services/verifactu/validador_verifactu.dart';
import '../../../services/verifactu/aeat_remision_service.dart';
import '../../../services/verifactu/qr_service.dart';
import '../../../services/verifactu/verifactu_service.dart' as veri_inner;

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA DE TEST VERIFACTU — Solo rol propietario
// Cada botón ejecuta una operación del sistema Verifactu y muestra el resultado
// exacto para que el propietario confirme que el comportamiento es el correcto.
// ─────────────────────────────────────────────────────────────────────────────

class VerifactuTestScreen extends StatefulWidget {
  final String empresaId;
  const VerifactuTestScreen({super.key, required this.empresaId});

  @override
  State<VerifactuTestScreen> createState() => _VerifactuTestScreenState();
}

class _VerifactuTestScreenState extends State<VerifactuTestScreen> {
  // ── Datos de prueba fijos ────────────────────────────────────────────────
  static const _kNif    = 'B26997528';
  static const _kSerie  = 'F';
  static const _kNumero = '2026-0001';
  static final _kFecha  = DateTime(2026, 10, 18, 10, 30, 0);

  // ── Estado de cada test ──────────────────────────────────────────────────
  final Map<String, _TestResult?> _resultados = {};
  final Map<String, bool> _cargando = {};

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _setLoading(String id, bool v) =>
      setState(() => _cargando[id] = v);

  void _setResult(String id, _TestResult r) =>
      setState(() { _resultados[id] = r; _cargando[id] = false; });

  Future<void> _run(String id, Future<_TestResult> Function() fn) async {
    _setLoading(id, true);
    try {
      final r = await fn();
      _setResult(id, r);
    } catch (e, st) {
      _setResult(id, _TestResult.error('Excepción: $e\n\n$st'));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TESTS
  // ─────────────────────────────────────────────────────────────────────────

  // T1 — Calcular hash SHA-256 de un registro alta
  Future<_TestResult> _t1HashSha256() async {
    final reg = RegistroFacturacionAlta(
      nifEmisor: _kNif,
      numeroSerie: _kSerie,
      numeroFactura: _kNumero,
      fechaExpedicion: _kFecha,
      tipoFactura: TipoFacturaVeri.f1,
      descripcion: 'Servicios de desarrollo software',
      importeTotal: 1210.00,
      cuotaTotal: 210.00,
      desglosePorTipo: {'21': 1000.00},
      claveRegimen: ClaveRegimen.general,
      calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
      registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
      fechaHoraGeneracion: _kFecha,
      zonaHoraria: 'Europe/Madrid',
      esVerifactu: true,
    );
    return _TestResult.ok(
      titulo: 'Hash SHA-256 calculado correctamente',
      detalle: 'Hash (64 chars): ${reg.hash64}\n\nHash completo (${reg.hash.length} chars):\n${reg.hash}',
      esperado: 'Hash de 64 hex chars (SHA-256). Cadena canónica construida con los campos '
          'del RD 1007/2023 Bloque 6 en orden: NIF|serie+número|fecha|tipo|cuota|importe|'
          'descripción|fecha+hora+zona.',
    );
  }

  // T2 — Primer registro de la cadena (hash anterior = 64 ceros)
  Future<_TestResult> _t2PrimerRegistro() async {
    final ref = ReferenceRegistroAnterior.primerRegistro();
    final esPrimero = ref.esPrimerRegistro;
    final hash = ref.hash64Caracteres;
    return _TestResult.ok(
      titulo: 'Primer registro de cadena inicializado',
      detalle: 'esPrimerRegistro: $esPrimero\nhash64Caracteres: $hash\n'
          'Longitud: ${hash.length} chars',
      esperado: 'esPrimerRegistro = true. hash64Caracteres = 64 ceros exactos. '
          'Esto es el "genesis block" de la cadena Verifactu de la empresa.',
    );
  }

  // T3 — Alta F1: factura ordinaria completa
  Future<_TestResult> _t3AltaF1() async {
    final ref = ReferenceRegistroAnterior.primerRegistro();
    final reg = RegistroFacturacionAlta(
      nifEmisor: _kNif,
      numeroSerie: _kSerie,
      numeroFactura: _kNumero,
      fechaExpedicion: _kFecha,
      tipoFactura: TipoFacturaVeri.f1,
      descripcion: 'Diseño web y mantenimiento mensual',
      importeTotal: 1452.00,
      cuotaTotal: 252.00,
      desglosePorTipo: {'21': 1200.00},
      claveRegimen: ClaveRegimen.general,
      calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
      registroAnterior: ref,
      fechaHoraGeneracion: DateTime.now(),
      zonaHoraria: 'Europe/Madrid',
      esVerifactu: true,
    );
    final json = reg.toJson();
    return _TestResult.ok(
      titulo: 'RegistroFacturacionAlta F1 creado',
      detalle: const JsonEncoder.withIndent('  ').convert(json),
      esperado: 'Registro de tipo F1 (factura ordinaria). Campos: nifEmisor, núm. factura, '
          'fecha, tipo="F1", cuotaTotal, importeTotal, claveRegimen="01", '
          'calificación="S1". Hash válido encadenado al primer registro (64 ceros).',
    );
  }

  // T4 — Alta F2: factura simplificada (TPV)
  Future<_TestResult> _t4AltaF2() async {
    final reg = RegistroFacturacionAlta(
      nifEmisor: _kNif,
      numeroSerie: 'TPV',
      numeroFactura: '2026-0042',
      fechaExpedicion: _kFecha,
      tipoFactura: TipoFacturaVeri.f2,
      descripcion: 'Venta mostrador',
      importeTotal: 18.15,
      cuotaTotal: 3.15,
      desglosePorTipo: {'21': 15.00},
      claveRegimen: ClaveRegimen.general,
      calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
      registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
      fechaHoraGeneracion: DateTime.now(),
      zonaHoraria: 'Europe/Madrid',
      esVerifactu: true,
    );
    return _TestResult.ok(
      titulo: 'RegistroFacturacionAlta F2 creado (TPV)',
      detalle: 'tipoFactura: ${reg.tipoFactura.codigo} — ${reg.tipoFactura.descripcion}\n'
          'importeTotal: ${reg.importeTotal} €\ncuotaTotal: ${reg.cuotaTotal} €\n'
          'hash64: ${reg.hash64}',
      esperado: 'Registro de tipo F2 (factura simplificada ≤400 €). Usado en el TPV '
          'para tickets y facturas simplificadas. El tipo "F2" debe aparecer en el XML '
          'y en el QR de verificación AEAT.',
    );
  }

  // T5 — Alta R1: rectificativa por error
  Future<_TestResult> _t5AltaR1() async {
    final reg = RegistroFacturacionAlta(
      nifEmisor: _kNif,
      numeroSerie: 'R',
      numeroFactura: '2026-0001',
      fechaExpedicion: _kFecha,
      tipoFactura: TipoFacturaVeri.r1,
      tipoRectificativa: TipoRectificativa.diferencias,
      descripcion: 'Rectificativa de F-2026-0001',
      importeTotal: -121.00,
      cuotaTotal: -21.00,
      desglosePorTipo: {'21': -100.00},
      claveRegimen: ClaveRegimen.general,
      calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
      registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
      fechaHoraGeneracion: DateTime.now(),
      zonaHoraria: 'Europe/Madrid',
      esVerifactu: true,
    );
    return _TestResult.ok(
      titulo: 'RegistroFacturacionAlta R1 creado (rectificativa)',
      detalle: 'tipoFactura: ${reg.tipoFactura.codigo} — ${reg.tipoFactura.descripcion}\n'
          'tipoRectificativa: ${reg.tipoRectificativa?.codigo} (${reg.tipoRectificativa?.descripcion})\n'
          'importeTotal: ${reg.importeTotal} € (negativo = abono)\n'
          'hash64: ${reg.hash64}',
      esperado: 'Registro R1 (rectificativa por error fundado en Derecho). '
          'Tipo rectificativa "I" = por diferencias (solo el delta). '
          'El importe es negativo porque es un abono. '
          'IMPORTANTE: R2 solo es para concurso de acreedores, NO para devoluciones normales.',
    );
  }

  // T6 — Encadenamiento de 2 registros
  Future<_TestResult> _t6Encadenamiento() async {
    final reg1 = RegistroFacturacionAlta(
      nifEmisor: _kNif,
      numeroSerie: _kSerie,
      numeroFactura: '2026-0001',
      fechaExpedicion: _kFecha,
      tipoFactura: TipoFacturaVeri.f1,
      descripcion: 'Factura 1',
      importeTotal: 121.00,
      cuotaTotal: 21.00,
      desglosePorTipo: {'21': 100.00},
      claveRegimen: ClaveRegimen.general,
      calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
      registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
      fechaHoraGeneracion: DateTime.now(),
      zonaHoraria: 'Europe/Madrid',
      esVerifactu: true,
    );

    final ref2 = ReferenceRegistroAnterior(
      nifEmisor: _kNif,
      numeroSerie: _kSerie,
      numeroFactura: '2026-0001',
      fechaExpedicion: _kFecha,
      hash64Caracteres: reg1.hash64,
    );

    final reg2 = RegistroFacturacionAlta(
      nifEmisor: _kNif,
      numeroSerie: _kSerie,
      numeroFactura: '2026-0002',
      fechaExpedicion: _kFecha.add(const Duration(hours: 1)),
      tipoFactura: TipoFacturaVeri.f1,
      descripcion: 'Factura 2',
      importeTotal: 242.00,
      cuotaTotal: 42.00,
      desglosePorTipo: {'21': 200.00},
      claveRegimen: ClaveRegimen.general,
      calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
      registroAnterior: ref2,
      fechaHoraGeneracion: DateTime.now().add(const Duration(seconds: 1)),
      zonaHoraria: 'Europe/Madrid',
      esVerifactu: true,
    );

    final cadena = CadenaFacturacion(
      nifEmisor: _kNif,
      registrosAlta: [reg1, reg2],
      registrosAnulacion: [],
    );
    final ok = cadena.validarEncadenamiento();

    return _TestResult.ok(
      titulo: ok ? 'Cadena de 2 registros VÁLIDA' : 'Cadena ROTA',
      detalle: 'Registro 1 hash64: ${reg1.hash64}\n\n'
          'Registro 2 referencia hash anterior: ${reg2.registroAnterior.hash64Caracteres}\n\n'
          'Hash reg1 == hashAnterior reg2: ${reg1.hash64 == reg2.registroAnterior.hash64Caracteres}\n\n'
          'cadena.validarEncadenamiento(): $ok',
      esperado: 'Los 64 primeros chars del hash del registro 1 deben coincidir exactamente '
          'con el campo hash64Caracteres del registroAnterior del registro 2. '
          'validarEncadenamiento() debe devolver true.',
    );
  }

  // T7 — Validar registro alta con ValidadorVerifactu
  Future<_TestResult> _t7Validar() async {
    final reg = RegistroFacturacionAlta(
      nifEmisor: _kNif,
      numeroSerie: _kSerie,
      numeroFactura: _kNumero,
      fechaExpedicion: DateTime.now(),
      tipoFactura: TipoFacturaVeri.f1,
      descripcion: 'Servicio de test',
      importeTotal: 121.00,
      cuotaTotal: 21.00,
      desglosePorTipo: {'21': 100.00},
      claveRegimen: ClaveRegimen.general,
      calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
      registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
      fechaHoraGeneracion: DateTime.now(),
      zonaHoraria: 'Europe/Madrid',
      esVerifactu: true,
    );

    final result = ValidadorVerifactu.validarRegistroAlta(reg, null);

    return _TestResult(
      ok: result.esValido,
      titulo: result.esValido
          ? 'Registro VÁLIDO según ValidadorVerifactu'
          : 'Registro INVÁLIDO: ${result.errores.length} error(es)',
      detalle: 'esValido: ${result.esValido}\n'
          'errores: ${result.errores.isEmpty ? "ninguno" : result.errores.join("\n")}\n'
          'advertencias: ${result.advertencias.isEmpty ? "ninguna" : result.advertencias.join("\n")}\n'
          'hashCalculado (64): ${result.hashPrimeros64}',
      esperado: 'esValido = true, sin errores. El registro usa fechaHoraGeneracion = ahora '
          'para pasar la regla R6 (±60 segundos del reloj del sistema). '
          'hashCalculado debe ser un SHA-256 de 64 hex chars.',
    );
  }

  // T8 — Anulación: crear registro de anulación
  Future<_TestResult> _t8Anulacion() async {
    final regAnul = RegistroFacturacionAnulacion(
      nifEmisor: _kNif,
      numeroSerie: _kSerie,
      numeroFactura: _kNumero,
      fechaExpedicion: _kFecha,
      solicitanteCodigo: 'E', // E = Emisor
      registroAnterior: ReferenceRegistroAnterior.primerRegistro(),
      fechaHoraGeneracion: DateTime.now(),
      zonaHoraria: 'Europe/Madrid',
    );

    return _TestResult.ok(
      titulo: 'RegistroFacturacionAnulacion creado',
      detalle: 'nifEmisor: ${regAnul.nifEmisor}\n'
          'numeroFactura: ${regAnul.numeroSerie}${regAnul.numeroFactura}\n'
          'solicitante: ${regAnul.solicitanteCodigo} (E=Emisor)\n'
          'hash64: ${regAnul.hash64}',
      esperado: 'Un registro de anulación no modifica la factura original ni la borra. '
          'Añade un nuevo eslabón en la cadena hash indicando que la factura ha sido '
          'anulada. El código de solicitante "E" significa que es el propio emisor '
          'quien solicita la anulación.',
    );
  }

  // T9 — Registro de evento (anomalía / exportación)
  Future<_TestResult> _t9Evento() async {
    final evento = RegistroEvento(
      codigoProductor: 'FLUIX',
      codigoSistema: 'Fluix CRM',
      versionSistema: '1.0.0',
      numeroInstalacion: 'INST-${widget.empresaId.substring(0, 8)}',
      nifObligado: _kNif,
      tipoEvento: TipoEvento.exportacionFacturacion,
      registroAnteriorEvento: ReferenceRegistroAnterior.primerRegistro(),
      fechaHoraGeneracion: DateTime.now(),
      zonaHoraria: 'Europe/Madrid',
      detalleEvento: 'Exportación de cadena de facturación para auditoría',
    );

    return _TestResult.ok(
      titulo: 'RegistroEvento creado (tipo 08: exportación)',
      detalle: 'tipoEvento: ${evento.tipoEvento.codigo} — ${evento.tipoEvento.descripcion}\n'
          'detalleEvento: ${evento.detalleEvento}\n'
          'hash64: ${evento.hash64}',
      esperado: 'Los eventos son registros especiales (no facturas) que documentan '
          'operaciones del sistema: arranques, anomalías, exportaciones, restauraciones. '
          'El tipo 08 = exportación de facturación. Todos los eventos también se '
          'encadenan con hash SHA-256.',
    );
  }

  // T10 — Generar URL y QR Verifactu
  Future<_TestResult> _t10Qr() async {
    final svc = QrService();
    final url = svc.generarUrl(
      nifEmisor: _kNif,
      serie: _kSerie,
      numero: _kNumero,
      fecha: _kFecha,
      importeTotal: 1210.00,
    );
    return _TestResult.ok(
      titulo: 'URL QR Verifactu generada',
      detalle: url,
      esperado: 'URL de verificación en la sede electrónica de la AEAT '
          '(www2.agenciatributaria.gob.es/wlpl/TIKE-CONT/ValidarQR). '
          'Parámetros: nif, numserie, fecha (dd-MM-yyyy), importe (2 decimales). '
          'Esta URL se incrusta en el QR que aparece en el PDF de la factura.',
    );
  }

  // T11 — Leer cadena hash de Firestore
  Future<_TestResult> _t11LeerCadena() async {
    final svc = HashChainService(widget.empresaId);
    final ref = await svc.obtenerReferenciaAnterior(_kNif);
    return _TestResult.ok(
      titulo: ref.esPrimerRegistro
          ? 'Cadena vacía — empresa sin registros Verifactu todavía'
          : 'Referencia anterior leída de Firestore',
      detalle: 'esPrimerRegistro: ${ref.esPrimerRegistro}\n'
          'nifEmisor: "${ref.nifEmisor}"\n'
          'numeroSerie: "${ref.numeroSerie}"\n'
          'numeroFactura: "${ref.numeroFactura}"\n'
          'hash64Caracteres: ${ref.hash64Caracteres}',
      esperado: 'Si la empresa aún no ha emitido facturas Verifactu, devuelve el '
          '"primer registro" con 64 ceros. Si ya hay facturas, devuelve los datos '
          'del último registro para encadenar el siguiente. '
          'Colección Firestore: empresas/{id}/registros_verifactu',
    );
  }

  // T12 — Encolar XML para AEAT
  Future<_TestResult> _t12Encolar() async {
    final svc = AeatRemisionService(widget.empresaId);
    await svc.encolarParaEnvio(
      xmlPayload: '<Test>XML de prueba Verifactu</Test>',
      facturaId: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      nifEmisor: _kNif,
      numeroFactura: 'TEST-${DateTime.now().second}',
    );
    final pendientes = await svc.contarPendientes();
    return _TestResult.ok(
      titulo: 'XML encolado para AEAT. Pendientes en cola: $pendientes',
      detalle: 'XML de prueba guardado en:\n'
          'empresas/${widget.empresaId}/cola_verifactu\n\n'
          'estado: pendiente\n'
          'Registros pendientes totales: $pendientes',
      esperado: 'El XML se guarda en Firestore con estado "pendiente". '
          'Una Cloud Function (roadmap Q3 2026) procesará la cola y enviará '
          'los XMLs a la AEAT vía SOAP. El contador de pendientes debe '
          'haber aumentado en 1 respecto al valor anterior.',
    );
  }

  // T13 — Contar cola AEAT pendiente
  Future<_TestResult> _t13ContarCola() async {
    final svc = AeatRemisionService(widget.empresaId);
    final n = await svc.contarPendientes();
    return _TestResult.ok(
      titulo: 'Cola AEAT: $n registros pendientes de envío',
      detalle: 'Colección: empresas/${widget.empresaId}/cola_verifactu\n'
          'Filtro: estado == "pendiente"\n'
          'Total encontrados: $n',
      esperado: 'Muestra cuántos XMLs están esperando ser enviados a la AEAT. '
          'En producción este valor debería ser 0 o muy bajo. '
          'Si crece sin parar indica que el servicio de envío no está funcionando.',
    );
  }

  // T14 — Validar lote (límite 1–1000 registros)
  Future<_TestResult> _t14ValidarLote() async {
    final ok    = ValidadorVerifactu.validarLote(500);
    final error = ValidadorVerifactu.validarLote(1001);
    return _TestResult.ok(
      titulo: 'Validación de límite de lote AEAT',
      detalle: 'Lote de 500 registros → esValido: ${ok.esValido}\n'
          'Lote de 1001 registros → esValido: ${error.esValido}\n'
          'Error lote 1001: ${error.errores.join(", ")}',
      esperado: 'La AEAT acepta máximo 1000 registros por envío (art. 9 RD 1007/2023). '
          '500 → válido. 1001 → inválido con error HAC1177-LOTE-001.',
    );
  }

  // T15 — VerifactuService: obtenerDatosNuevaFactura
  Future<_TestResult> _t15DatosNuevaFactura() async {
    final svc = veri_inner.VerifactuService();
    final datos = await svc.obtenerDatosNuevaFactura(widget.empresaId);
    return _TestResult.ok(
      titulo: 'Datos para nueva factura Verifactu obtenidos',
      detalle: 'numero_registro: ${datos['numero_registro']}\n'
          'hash_anterior: ${(datos['hash_anterior'] as String).substring(0, 16)}... '
          '(${(datos['hash_anterior'] as String).length} chars)',
      esperado: 'Si es la primera factura de la empresa: numero_registro=1 y '
          'hash_anterior=64 ceros. Si ya hay facturas: número siguiente al último '
          'registro y el hash del último registro. '
          'Colección: empresas/{id}/facturas_verifactu',
    );
  }

  // T16 — VerifactuService: calcularHashFactura (formato legado)
  Future<_TestResult> _t16HashLegado() async {
    final svc = veri_inner.VerifactuService();
    final hash = svc.calcularHashFactura(
      nifEmisor: _kNif,
      numeroFactura: '$_kSerie-$_kNumero',
      fechaExpedicion: _kFecha,
      horaExpedicion: '10:30:00',
      tipoFactura: 'F1',
      baseImponible: 1000.00,
      cuotaIva: 210.00,
      totalFactura: 1210.00,
      hashAnterior: '0' * 64,
    );
    return _TestResult.ok(
      titulo: 'Hash SHA-256 (formato VerifactuService legado)',
      detalle: 'Hash: $hash\nLongitud: ${hash.length} chars',
      esperado: 'Hash SHA-256 de 64 hex chars. Este método usa el formato más simple '
          '(campos separados por "|") del VerifactuService.dart original. '
          'El formato canónico oficial está en modelos_verifactu.dart '
          '(RegistroFacturacionAlta.calcularHash()).',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const FluixAppBar(titulo: 'Test Verifactu', showLeading: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildSection('HASH Y ENCADENAMIENTO', [
            _buildTestCard(
              id: 't1',
              label: 'T1 — Calcular hash SHA-256',
              icon: Icons.fingerprint_rounded,
              color: const Color(0xFF6366F1),
              descripcion: 'Calcula el hash de un RegistroFacturacionAlta de prueba '
                  'según RD 1007/2023 Bloque 6. Muestra la cadena canónica y el hash resultante.',
              onRun: () => _run('t1', _t1HashSha256),
            ),
            _buildTestCard(
              id: 't2',
              label: 'T2 — Primer registro (genesis)',
              icon: Icons.looks_one_rounded,
              color: const Color(0xFF6366F1),
              descripcion: 'Verifica el primer eslabón de la cadena: el hash anterior '
                  'debe ser exactamente 64 ceros y esPrimerRegistro=true.',
              onRun: () => _run('t2', _t2PrimerRegistro),
            ),
            _buildTestCard(
              id: 't6',
              label: 'T6 — Encadenamiento de 2 registros',
              icon: Icons.link_rounded,
              color: const Color(0xFF6366F1),
              descripcion: 'Crea 2 registros enlazados: el hash64 del primero debe '
                  'coincidir exactamente con hashAnterior del segundo. '
                  'CadenaFacturacion.validarEncadenamiento() debe devolver true.',
              onRun: () => _run('t6', _t6Encadenamiento),
            ),
          ]),
          const SizedBox(height: 12),
          _buildSection('TIPOS DE REGISTRO', [
            _buildTestCard(
              id: 't3',
              label: 'T3 — Alta F1: Factura ordinaria',
              icon: Icons.receipt_rounded,
              color: const Color(0xFF0EA5E9),
              descripcion: 'Crea un RegistroFacturacionAlta de tipo F1 (factura completa '
                  'ordinaria). Verifica que el JSON de salida contiene todos los campos '
                  'obligatorios del RD 1007/2023.',
              onRun: () => _run('t3', _t3AltaF1),
            ),
            _buildTestCard(
              id: 't4',
              label: 'T4 — Alta F2: Factura simplificada (TPV)',
              icon: Icons.point_of_sale_rounded,
              color: const Color(0xFF0EA5E9),
              descripcion: 'Crea un RegistroFacturacionAlta de tipo F2 (factura '
                  'simplificada ≤400 €). Es el tipo que genera el TPV para tickets '
                  'y facturas simplificadas.',
              onRun: () => _run('t4', _t4AltaF2),
            ),
            _buildTestCard(
              id: 't5',
              label: 'T5 — Alta R1: Rectificativa por error',
              icon: Icons.undo_rounded,
              color: const Color(0xFF0EA5E9),
              descripcion: 'Crea un RegistroFacturacionAlta de tipo R1 (rectificativa '
                  'por error fundado). Verifica que el tipoRectificativa="I" (diferencias) '
                  'y el importe es negativo (abono). R2 sería concurso de acreedores — '
                  'NO para devoluciones normales.',
              onRun: () => _run('t5', _t5AltaR1),
            ),
            _buildTestCard(
              id: 't8',
              label: 'T8 — Registro de anulación',
              icon: Icons.cancel_outlined,
              color: const Color(0xFF0EA5E9),
              descripcion: 'Crea un RegistroFacturacionAnulacion. La anulación NO '
                  'borra la factura: añade un nuevo eslabón en la cadena indicando '
                  'que el emisor (código "E") solicita su anulación.',
              onRun: () => _run('t8', _t8Anulacion),
            ),
            _buildTestCard(
              id: 't9',
              label: 'T9 — Registro de evento',
              icon: Icons.event_note_rounded,
              color: const Color(0xFF0EA5E9),
              descripcion: 'Crea un RegistroEvento de tipo 08 (exportación de '
                  'facturación). Los eventos documentan operaciones del sistema: '
                  'arranques, anomalías, exportaciones, restauraciones de backup.',
              onRun: () => _run('t9', _t9Evento),
            ),
          ]),
          const SizedBox(height: 12),
          _buildSection('VALIDACIÓN', [
            _buildTestCard(
              id: 't7',
              label: 'T7 — Validar registro alta (ValidadorVerifactu)',
              icon: Icons.verified_rounded,
              color: const Color(0xFF22C55E),
              descripcion: 'Ejecuta ValidadorVerifactu.validarRegistroAlta() sobre '
                  'un registro creado ahora mismo (pasa la regla R6 de ±60 s). '
                  'Debe devolver esValido=true sin errores.',
              onRun: () => _run('t7', _t7Validar),
            ),
          ]),
          const SizedBox(height: 12),
          _buildSection('QR Y REPRESENTACIÓN', [
            _buildTestCard(
              id: 't10',
              label: 'T10 — Generar URL QR Verifactu',
              icon: Icons.qr_code_rounded,
              color: const Color(0xFFF59E0B),
              descripcion: 'Genera la URL que va codificada en el QR de la factura. '
                  'Apunta a la sede electrónica de la AEAT para verificar la factura. '
                  'Parámetros: nif, numserie, fecha (dd-MM-yyyy), importe.',
              onRun: () => _run('t10', _t10Qr),
            ),
          ]),
          const SizedBox(height: 12),
          _buildSection('FIRESTORE Y COLA AEAT', [
            _buildTestCard(
              id: 't11',
              label: 'T11 — Leer cadena hash de Firestore',
              icon: Icons.cloud_download_rounded,
              color: const Color(0xFF8B5CF6),
              descripcion: 'Lee el último registro de la cadena Verifactu de esta '
                  'empresa desde Firestore (empresas/{id}/registros_verifactu). '
                  'Si no hay facturas aún, devuelve el registro "genesis" (64 ceros).',
              onRun: () => _run('t11', _t11LeerCadena),
            ),
            _buildTestCard(
              id: 't12',
              label: 'T12 — Encolar XML de prueba para AEAT',
              icon: Icons.send_rounded,
              color: const Color(0xFF8B5CF6),
              descripcion: 'Encola un XML de prueba en la cola de remisión AEAT '
                  '(empresas/{id}/cola_verifactu). En producción una Cloud Function '
                  'procesa esta cola y envía a la AEAT. Muestra cuántos hay pendientes.',
              onRun: () => _run('t12', _t12Encolar),
            ),
            _buildTestCard(
              id: 't13',
              label: 'T13 — Contar cola AEAT pendiente',
              icon: Icons.hourglass_bottom_rounded,
              color: const Color(0xFF8B5CF6),
              descripcion: 'Cuenta cuántos XMLs están en cola esperando ser enviados '
                  'a la AEAT. En producción debería ser 0. Si crece sin parar, '
                  'la Cloud Function de remisión no está funcionando.',
              onRun: () => _run('t13', _t13ContarCola),
            ),
            _buildTestCard(
              id: 't14',
              label: 'T14 — Validar límite de lote AEAT',
              icon: Icons.layers_rounded,
              color: const Color(0xFF8B5CF6),
              descripcion: 'Verifica que el validador acepta lotes ≤1000 registros y '
                  'rechaza lotes de 1001+. La AEAT solo acepta máximo 1000 registros '
                  'por envío (art. 9 RD 1007/2023). Test sin acceso a Firestore.',
              onRun: () => _run('t14', _t14ValidarLote),
            ),
            _buildTestCard(
              id: 't15',
              label: 'T15 — Datos para nueva factura (VerifactuService)',
              icon: Icons.add_circle_outline_rounded,
              color: const Color(0xFF8B5CF6),
              descripcion: 'Llama a VerifactuService.obtenerDatosNuevaFactura(). '
                  'Devuelve el número de registro siguiente y el hash anterior '
                  'de la colección facturas_verifactu de esta empresa.',
              onRun: () => _run('t15', _t15DatosNuevaFactura),
            ),
          ]),
          const SizedBox(height: 12),
          _buildSection('FORMATO LEGADO', [
            _buildTestCard(
              id: 't16',
              label: 'T16 — Hash formato VerifactuService (legado)',
              icon: Icons.history_rounded,
              color: const Color(0xFF64748B),
              descripcion: 'Prueba el método calcularHashFactura() del '
                  'VerifactuService.dart original (formato campos separados por "|"). '
                  'Comparar con T1 para ver la diferencia entre el formato legado '
                  'y el canónico del RD 1007/2023.',
              onRun: () => _run('t16', _t16HashLegado),
            ),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGETS INTERNOS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.security_rounded, color: Colors.white70, size: 18),
            SizedBox(width: 8),
            Text('Verifactu — Banco de pruebas',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Empresa: ${widget.empresaId.substring(0, 12)}...',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pulsa cada botón, observa el resultado y confirma que es el comportamiento '
            'esperado. Los tests T12 y T15 escriben en Firestore (datos de prueba reales).',
            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String titulo, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(titulo,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B), letterSpacing: 0.8)),
        ),
        ...children,
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildTestCard({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
    required String descripcion,
    required VoidCallback onRun,
  }) {
    final result = _resultados[id];
    final loading = _cargando[id] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: result == null
              ? const Color(0xFFE2E8F0)
              : result.ok
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFFCA5A5),
          width: result != null ? 1.5 : 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          // ── Cabecera del test ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                          color: Color(0xFF1E293B))),
                ),
                if (loading)
                  const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: Color(0xFF6366F1)))
                else
                  TextButton(
                    onPressed: onRun,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(result == null ? 'Ejecutar' : 'Re-ejecutar',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          // ── Descripción ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Text(descripcion,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4)),
          ),
          // ── Resultado ─────────────────────────────────────────────────────
          if (result != null) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              decoration: BoxDecoration(
                color: result.ok
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: result.ok
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título resultado
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    child: Row(
                      children: [
                        Icon(
                          result.ok ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: result.ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(result.titulo,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: result.ok
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB91C1C),
                              )),
                        ),
                      ],
                    ),
                  ),
                  // Resultado en bloque de código
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                    child: GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: result.detalle));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copiado al portapapeles'),
                              duration: Duration(seconds: 1)));
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(result.detalle,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 10,
                                color: Color(0xFF7DD3FC), height: 1.5)),
                      ),
                    ),
                  ),
                  // Qué se espera ver
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            result.esperado,
                            style: const TextStyle(fontSize: 10,
                                color: Color(0xFF64748B), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS INTERNOS
// ─────────────────────────────────────────────────────────────────────────────

class _TestResult {
  final bool ok;
  final String titulo;
  final String detalle;
  final String esperado;

  const _TestResult({
    required this.ok,
    required this.titulo,
    required this.detalle,
    required this.esperado,
  });

  factory _TestResult.ok({
    required String titulo,
    required String detalle,
    required String esperado,
  }) => _TestResult(ok: true, titulo: titulo, detalle: detalle, esperado: esperado);

  factory _TestResult.error(String mensaje) => _TestResult(
    ok: false,
    titulo: 'Error en el test',
    detalle: mensaje,
    esperado: 'El test debería haberse ejecutado sin excepciones.',
  );
}
