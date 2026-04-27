import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/modelos/contabilidad.dart';

/// Genera datos de prueba realistas para el módulo de contabilidad.
/// Crea proveedores, gastos y facturas emitidas del año actual.
class DatosPruebaContabilidadService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> generarDatosDePrueba(String empresaId) async {
    if (!kDebugMode) {
      debugPrint('⚠️ generarDatosDePrueba solo disponible en modo debug');
      return;
    }

    await Future.wait([
      _crearProveedores(empresaId),
      _crearGastos(empresaId),
      _crearFacturas(empresaId),
      _crearPedidos(empresaId),
    ]);
    // El cache se actualiza después de tener facturas
    await _actualizarCacheFacturas(empresaId);
  }

  // ── PROVEEDORES ───────────────────────────────────────────────────────────

  Future<void> _crearProveedores(String empresaId) async {
    if (!kDebugMode) return;

    final ref = _db
        .collection('empresas')
        .doc(empresaId)
        .collection('proveedores');

    // Comprobar si ya existen
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final proveedores = [
      {
        'nombre': 'Endesa S.A.',
        'nif': 'A-81948077',
        'email': 'clientes@endesa.es',
        'telefono': '900 760 760',
        'categoria': 'suministros',
        'activo': true,
        'fecha_alta': Timestamp.fromDate(DateTime(2025, 1, 1)),
      },
      {
        'nombre': 'Vodafone España',
        'nif': 'A-80907397',
        'email': 'empresas@vodafone.es',
        'telefono': '1444',
        'categoria': 'servicios',
        'activo': true,
        'fecha_alta': Timestamp.fromDate(DateTime(2025, 1, 1)),
      },
      {
        'nombre': 'Google Workspace',
        'nif': 'ESB82743863',
        'email': 'billing@google.com',
        'categoria': 'software',
        'activo': true,
        'fecha_alta': Timestamp.fromDate(DateTime(2025, 3, 1)),
      },
      {
        'nombre': 'Inmobiliaria Centro S.L.',
        'nif': 'B-12345678',
        'email': 'alquileres@inmobcentro.es',
        'telefono': '949 123 456',
        'categoria': 'alquiler',
        'activo': true,
        'fecha_alta': Timestamp.fromDate(DateTime(2024, 6, 1)),
      },
      {
        'nombre': 'Meta Ads',
        'nif': 'ESB-82387770',
        'email': 'billing@meta.com',
        'categoria': 'marketing',
        'activo': true,
        'fecha_alta': Timestamp.fromDate(DateTime(2025, 1, 1)),
      },
      {
        'nombre': 'Asesoría García & Asociados',
        'nif': 'B-98765432',
        'email': 'garcia@asesoria.es',
        'telefono': '949 654 321',
        'categoria': 'gestor',
        'activo': true,
        'fecha_alta': Timestamp.fromDate(DateTime(2024, 1, 1)),
      },
    ];

    final batch = _db.batch();
    for (final p in proveedores) {
      final docRef = ref.doc();
      batch.set(docRef, {...p, 'id': docRef.id});
    }
    await batch.commit();
  }

  // ── GASTOS ────────────────────────────────────────────────────────────────

  Future<void> _crearGastos(String empresaId) async {
    if (!kDebugMode) return;

    final ref = _db
        .collection('empresas')
        .doc(empresaId)
        .collection('gastos');

    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final ahora = DateTime.now();
    final anio = ahora.year;

    // Gastos fijos mensuales + algunos variables
    final gastosMensuales = <Map<String, dynamic>>[];

    for (int mes = 1; mes <= ahora.month; mes++) {
      // Alquiler — siempre el día 1
      gastosMensuales.add(_gasto(
        empresaId: empresaId,
        concepto: 'Alquiler local comercial',
        categoria: CategoriaGasto.alquiler,
        proveedorNombre: 'Inmobiliaria Centro S.L.',
        base: 800.0,
        porcIva: 21.0,
        fecha: DateTime(anio, mes, 1),
        factNum: 'ALQ-$anio-${mes.toString().padLeft(2, '0')}',
        metodoPago: 'transferencia',
        pagado: true,
      ));

      // Luz — día 5 de cada mes
      gastosMensuales.add(_gasto(
        empresaId: empresaId,
        concepto: 'Factura de electricidad',
        categoria: CategoriaGasto.suministros,
        proveedorNombre: 'Endesa S.A.',
        base: mes % 3 == 0 ? 185.0 : 142.0, // varía por temporada
        porcIva: 21.0,
        fecha: DateTime(anio, mes, 5),
        factNum: 'END-$anio-${mes.toString().padLeft(2, '0')}',
        metodoPago: 'domiciliación',
        pagado: true,
      ));

      // Telefonía — día 10
      gastosMensuales.add(_gasto(
        empresaId: empresaId,
        concepto: 'Línea de telefonía y fibra',
        categoria: CategoriaGasto.servicios,
        proveedorNombre: 'Vodafone España',
        base: 49.99,
        porcIva: 21.0,
        fecha: DateTime(anio, mes, 10),
        factNum: 'VOD-$anio-${mes.toString().padLeft(2, '0')}',
        metodoPago: 'domiciliación',
        pagado: true,
      ));

      // Google Workspace — día 15
      gastosMensuales.add(_gasto(
        empresaId: empresaId,
        concepto: 'Google Workspace Business',
        categoria: CategoriaGasto.software,
        proveedorNombre: 'Google Workspace',
        base: 14.40,
        porcIva: 21.0,
        fecha: DateTime(anio, mes, 15),
        factNum: 'GWS-$anio-${mes.toString().padLeft(2, '0')}',
        metodoPago: 'tarjeta',
        pagado: true,
      ));

      // Marketing Meta Ads — varía
      if (mes % 2 == 0 || mes == 1) {
        gastosMensuales.add(_gasto(
          empresaId: empresaId,
          concepto: 'Campaña publicidad Meta/Instagram',
          categoria: CategoriaGasto.marketing,
          proveedorNombre: 'Meta Ads',
          base: mes == 12 ? 400.0 : 150.0,
          porcIva: 0.0, // servicio intracomunitario sin IVA
          fecha: DateTime(anio, mes, 20),
          factNum: 'META-$anio-${mes.toString().padLeft(2, '0')}',
          metodoPago: 'tarjeta',
          pagado: true,
          ivaDeducible: false,
        ));
      }

      // Gestoría — trimestral
      if (mes == 3 || mes == 6 || mes == 9 || mes == 12) {
        gastosMensuales.add(_gasto(
          empresaId: empresaId,
          concepto: 'Honorarios gestoría trimestral',
          categoria: CategoriaGasto.gestor,
          proveedorNombre: 'Asesoría García & Asociados',
          base: 350.0,
          porcIva: 21.0,
          fecha: DateTime(anio, mes, 28),
          factNum: 'GES-$anio-T${(mes / 3).round()}',
          metodoPago: 'transferencia',
          pagado: mes < ahora.month || (mes == ahora.month && ahora.day >= 28),
        ));
      }
    }

    // Gastos no recurrentes de prueba
    gastosMensuales.addAll([
      _gasto(
        empresaId: empresaId,
        concepto: 'Equipo portátil Dell XPS',
        categoria: CategoriaGasto.equipamiento,
        base: 1200.0,
        porcIva: 21.0,
        fecha: DateTime(anio, 1, 20),
        factNum: 'DELL-2026-001',
        metodoPago: 'tarjeta',
        pagado: true,
      ),
      _gasto(
        empresaId: empresaId,
        concepto: 'Seguro de responsabilidad civil',
        categoria: CategoriaGasto.seguros,
        base: 480.0,
        porcIva: 0.0, // los seguros están exentos de IVA
        fecha: DateTime(anio, 2, 1),
        factNum: 'SEG-2026-001',
        metodoPago: 'transferencia',
        pagado: true,
        ivaDeducible: false,
      ),
      _gasto(
        empresaId: empresaId,
        concepto: 'Materiales de papelería y consumibles',
        categoria: CategoriaGasto.suministros,
        base: 87.50,
        porcIva: 21.0,
        fecha: DateTime(anio, ahora.month, 8),
        factNum: null,
        metodoPago: 'efectivo',
        pagado: true,
      ),
      _gasto(
        empresaId: empresaId,
        concepto: 'Formación online — Curso gestión empresas',
        categoria: CategoriaGasto.formacion,
        base: 299.0,
        porcIva: 21.0,
        fecha: DateTime(anio, ahora.month > 1 ? ahora.month - 1 : 1, 15),
        factNum: 'FORM-001',
        metodoPago: 'tarjeta',
        pagado: true,
      ),
      // Gasto pendiente de pago (para demostrar el estado)
      _gasto(
        empresaId: empresaId,
        concepto: 'Reparación climatización local',
        categoria: CategoriaGasto.servicios,
        base: 340.0,
        porcIva: 21.0,
        fecha: DateTime(anio, ahora.month, ahora.day > 5 ? ahora.day - 3 : 1),
        factNum: 'REP-001',
        metodoPago: null,
        pagado: false,
      ),
    ]);

    // Escribir en lotes de 20
    for (int i = 0; i < gastosMensuales.length; i += 20) {
      final lote = gastosMensuales.sublist(
          i, i + 20 > gastosMensuales.length ? gastosMensuales.length : i + 20);
      final batch = _db.batch();
      for (final g in lote) {
        final docRef = ref.doc();
        batch.set(docRef, {...g, 'id': docRef.id});
      }
      await batch.commit();
    }
  }

  Map<String, dynamic> _gasto({
    required String empresaId,
    required String concepto,
    required CategoriaGasto categoria,
    String? proveedorNombre,
    required double base,
    required double porcIva,
    required DateTime fecha,
    String? factNum,
    String? metodoPago,
    required bool pagado,
    bool ivaDeducible = true,
  }) {
    final importe = ivaDeducible ? base * (porcIva / 100) : 0.0;
    final total = base + importe;
    return {
      'empresa_id': empresaId,
      'concepto': concepto,
      'categoria': categoria.name,
      if (proveedorNombre != null) 'proveedor_nombre': proveedorNombre,
      if (factNum != null) 'numero_factura_proveedor': factNum,
      'base_imponible': base,
      'porcentaje_iva': ivaDeducible ? porcIva : 0.0,
      'importe_iva': importe,
      'total': total,
      'iva_deducible': ivaDeducible,
      'estado': pagado ? EstadoGasto.pagado.name : EstadoGasto.pendiente.name,
      'fecha_gasto': Timestamp.fromDate(fecha),
      if (pagado && metodoPago != null) 'fecha_pago': Timestamp.fromDate(fecha),
      if (metodoPago != null) 'metodo_pago': metodoPago,
      'fecha_creacion': Timestamp.fromDate(fecha),
      'creado_por': 'sistema_pruebas',
    };
  }

  // ── FACTURAS EMITIDAS ─────────────────────────────────────────────────────

  Future<void> _crearFacturas(String empresaId) async {
    if (!kDebugMode) return;

    final ref = _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas');

    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final ahora = DateTime.now();
    final anio  = ahora.year;

    // Clientes ficticios
    const clientes = [
      {'nombre': 'María García López',    'email': 'maria@gmail.com',    'nif': '12345678A'},
      {'nombre': 'Carlos Ruiz Martín',   'email': 'carlos@empresa.es',  'nif': '87654321B'},
      {'nombre': 'Ana Sánchez Pérez',    'email': 'ana@hotmail.com',    'nif': '11223344C'},
      {'nombre': 'Luis Fernández Mora',  'email': 'luis@outlook.com',   'nif': '55667788D'},
      {'nombre': 'Empresa Obras S.L.',   'email': 'admin@obras.es',     'nif': 'B-12398765'},
      {'nombre': 'Pedro Jiménez Alba',   'email': 'pedro@gmail.com',    'nif': '99887766E'},
      {'nombre': 'Sofía Torres Vega',    'email': 'sofia@yahoo.es',     'nif': '44556677F'},
    ];

    // Servicios ficticios con sus precios
    const servicios = [
      {'nombre': 'Corte de pelo',          'precio': 28.0,  'iva': 21.0},
      {'nombre': 'Coloración completa',    'precio': 65.0,  'iva': 21.0},
      {'nombre': 'Tratamiento capilar',    'precio': 45.0,  'iva': 21.0},
      {'nombre': 'Peinado para evento',    'precio': 55.0,  'iva': 21.0},
      {'nombre': 'Manicura + pedicura',    'precio': 40.0,  'iva': 21.0},
      {'nombre': 'Mechas balayage',        'precio': 90.0,  'iva': 21.0},
      {'nombre': 'Alisado brasileño',      'precio': 120.0, 'iva': 21.0},
    ];

    final facturas = <Map<String, dynamic>>[];
    int numFactura = 1;

    // Generar facturas para cada mes del año hasta hoy
    for (int mes = 1; mes <= ahora.month; mes++) {
      // Entre 6 y 12 facturas por mes
      final cantMes = (mes == ahora.month) ? 4 : 8 + (mes % 5);

      for (int i = 0; i < cantMes; i++) {
        final cliente   = clientes[(numFactura + i) % clientes.length];
        final servicio  = servicios[(numFactura + i) % servicios.length];
        final cantidad  = 1 + (i % 3);
        final base      = (servicio['precio'] as double) * cantidad;
        final porcIva   = servicio['iva'] as double;
        final ivaImporte = base * (porcIva / 100);
        final total     = base + ivaImporte;

        // Día aleatorio dentro del mes (sin pasar de hoy)
        final maxDia = (mes == ahora.month) ? ahora.day : 28;
        final dia    = 1 + ((numFactura * 3 + i * 7) % maxDia);

        final fecha = DateTime(anio, mes, dia);

        // Estado: mayoría pagadas, algunas pendientes, alguna vencida
        final String estado;
        if (mes == ahora.month && i >= cantMes - 1) {
          estado = 'pendiente';
        } else if (mes < ahora.month - 1 && i == 0) {
          estado = 'vencida';
        } else {
          estado = 'pagada';
        }

        final numStr = numFactura.toString().padLeft(4, '0');
        facturas.add({
          'numero_factura':  'FAC-$anio-$numStr',
          'cliente_nombre':  cliente['nombre'],
          'cliente_email':   cliente['email'],
          'datos_fiscales': {
            'nif':       cliente['nif'],
            'nombre':    cliente['nombre'],
            'direccion': 'Calle Mayor ${numFactura % 30 + 1}, Guadalajara',
          },
          'lineas': [
            {
              'descripcion':      servicio['nombre'],
              'cantidad':         cantidad,
              'precio_unitario':  servicio['precio'],
              'tipo_iva':         porcIva,
              'subtotal':         base,
              'iva_amount':       ivaImporte,
              'total':            total,
            }
          ],
          'subtotal':       base,
          'total_iva':      ivaImporte,
          'total':          total,
          'estado':         estado,
          'metodo_pago':    estado == 'pagada'
              ? (['tarjeta', 'efectivo', 'transferencia', 'bizum'])[i % 4]
              : null,
          'fecha_emision':  Timestamp.fromDate(fecha),
          'fecha_vencimiento': Timestamp.fromDate(
              fecha.add(const Duration(days: 30))),
          if (estado == 'pagada')
            'fecha_pago': Timestamp.fromDate(
                fecha.add(Duration(days: i % 5))),
          'pedido_id':      null,
          'creado_por':     'sistema_pruebas',
          'fecha_creacion': Timestamp.fromDate(fecha),
        });

        numFactura++;
      }
    }

    // Añadir 2 facturas de HOY para que el widget "Hoy" tenga datos
    for (int i = 0; i < 2; i++) {
      final cliente  = clientes[i % clientes.length];
      final servicio = servicios[(i + 2) % servicios.length];
      final base     = (servicio['precio'] as double);
      final iva      = base * 0.21;
      final total    = base + iva;
      final numStr   = numFactura.toString().padLeft(4, '0');

      facturas.add({
        'numero_factura':  'FAC-$anio-$numStr',
        'cliente_nombre':  cliente['nombre'],
        'cliente_email':   cliente['email'],
        'datos_fiscales':  {'nif': cliente['nif'], 'nombre': cliente['nombre']},
        'lineas': [{
          'descripcion':     servicio['nombre'],
          'cantidad':        1,
          'precio_unitario': servicio['precio'],
          'tipo_iva':        21.0,
          'subtotal':        base,
          'iva_amount':      iva,
          'total':           total,
        }],
        'subtotal':        base,
        'total_iva':       iva,
        'total':           total,
        'estado':          'pagada',
        'metodo_pago':     i == 0 ? 'tarjeta' : 'bizum',
        'fecha_emision':   Timestamp.fromDate(ahora),
        'fecha_vencimiento': Timestamp.fromDate(
            ahora.add(const Duration(days: 30))),
        'fecha_pago':      Timestamp.fromDate(ahora),
        'creado_por':      'sistema_pruebas',
        'fecha_creacion':  Timestamp.fromDate(ahora),
      });
      numFactura++;
    }

    // Escribir en lotes de 20
    for (int i = 0; i < facturas.length; i += 20) {
      final lote = facturas.sublist(
          i, (i + 20) > facturas.length ? facturas.length : i + 20);
      final batch = _db.batch();
      for (final f in lote) {
        final docRef = ref.doc();
        batch.set(docRef, {...f, 'id': docRef.id});
      }
      await batch.commit();
    }

    debugPrint('✅ ${facturas.length} facturas de prueba creadas');
  }

  // ── PEDIDOS ───────────────────────────────────────────────────────────────

  Future<void> _crearPedidos(String empresaId) async {
    if (!kDebugMode) return;

    final ref = _db
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos');

    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final ahora = DateTime.now();
    final anio  = ahora.year;

    const productosBase = [
      {'nombre': 'Menú del día',            'precio': 12.50},
      {'nombre': 'Tabla de embutidos',      'precio': 18.00},
      {'nombre': 'Ración de croquetas',     'precio': 9.00},
      {'nombre': 'Botella de vino tinto',   'precio': 14.00},
      {'nombre': 'Postre del día',          'precio': 5.50},
      {'nombre': 'Café + copa',             'precio': 4.50},
      {'nombre': 'Ración de jamón ibérico', 'precio': 22.00},
    ];

    const clientesPedidos = [
      'Mesa 1', 'Mesa 2', 'Mesa 3', 'Barra',
      'Pedro García', 'Ana Martínez', 'Delivery #1',
    ];

    final pedidos = <Map<String, dynamic>>[];

    for (int mes = 1; mes <= ahora.month; mes++) {
      final cantMes = (mes == ahora.month) ? 5 : 15 + (mes % 8);
      for (int i = 0; i < cantMes; i++) {
        final prod    = productosBase[i % productosBase.length];
        final cant    = 1 + (i % 4);
        final precio  = (prod['precio'] as double) * cant;
        final maxDia  = (mes == ahora.month) ? ahora.day : 28;
        final dia     = 1 + ((i * 3 + mes) % maxDia);
        final fecha   = DateTime(anio, mes, dia,
            10 + (i % 12), (i * 7) % 60);

        final estados = ['completado', 'completado', 'completado',
          'pendiente', 'confirmado'];
        final origen  = ['app', 'web', 'whatsapp', 'app'][i % 4];

        pedidos.add({
          'cliente':       clientesPedidos[i % clientesPedidos.length],
          'telefono':      '60${(i * 7654321) % 90000000 + 10000000}',
          'productos':     [
            {
              'nombre':   prod['nombre'],
              'precio':   prod['precio'],
              'cantidad': cant,
              'subtotal': precio,
            }
          ],
          'precio_total':  precio,
          'estado':        estados[i % estados.length],
          'origen':        origen,
          'pagado':        (i % 5) != 3,
          'metodo_pago':   (i % 5) != 3
              ? (['efectivo', 'tarjeta', 'bizum'])[i % 3]
              : null,
          'notas':         i % 7 == 0 ? 'Sin gluten por favor' : null,
          'fecha_creacion': Timestamp.fromDate(fecha),
          'creado_por':    'sistema_pruebas',
        });
      }
    }

    // 3 pedidos de HOY para el widget
    for (int i = 0; i < 3; i++) {
      final prod   = productosBase[(i + 1) % productosBase.length];
      final precio = (prod['precio'] as double) * (i + 1);
      pedidos.add({
        'cliente':       clientesPedidos[i],
        'telefono':      '600${(i + 1) * 111111}',
        'productos':     [
          {
            'nombre':   prod['nombre'],
            'precio':   prod['precio'],
            'cantidad': i + 1,
            'subtotal': precio,
          }
        ],
        'precio_total':  precio,
        'estado':        i == 2 ? 'pendiente' : 'completado',
        'origen':        ['app', 'web', 'whatsapp'][i],
        'pagado':        i != 2,
        'metodo_pago':   i != 2 ? 'tarjeta' : null,
        'fecha_creacion': Timestamp.fromDate(ahora),
        'creado_por':    'sistema_pruebas',
      });
    }

    // Escribir en lotes
    for (int i = 0; i < pedidos.length; i += 20) {
      final lote = pedidos.sublist(
          i, (i + 20) > pedidos.length ? pedidos.length : i + 20);
      final batch = _db.batch();
      for (final p in lote) {
        final docRef = ref.doc();
        batch.set(docRef, {...p, 'id': docRef.id});
      }
      await batch.commit();
    }

    debugPrint('✅ ${pedidos.length} pedidos de prueba creados');
  }

  // ── ACTUALIZAR CACHÉ DE FACTURAS EMITIDAS ─────────────────────────────────
  // Las facturas ya existen en Firestore desde el módulo de facturación.
  // Aquí solo actualizamos el cache_contable para acelerar las consultas.

  Future<void> _actualizarCacheFacturas(String empresaId) async {
    if (!kDebugMode) return;

    final ahora = DateTime.now();
    final anio = ahora.year;

    // Leer facturas del año actual
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas')
        .where('fecha_emision',
        isGreaterThanOrEqualTo:
        Timestamp.fromDate(DateTime(anio, 1, 1)))
        .where('fecha_emision',
        isLessThan: Timestamp.fromDate(DateTime(anio + 1, 1, 1)))
        .where('estado', isEqualTo: 'pagada')
        .get();

    if (snap.docs.isEmpty) return;

    // Agrupar por mes
    final porMes = <String, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final fecha = (data['fecha_emision'] as Timestamp).toDate();
      final key =
          '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';

      porMes.putIfAbsent(key, () => {
        'ingresos_base': 0.0,
        'iva_repercutido': 0.0,
        'ingresos_total': 0.0,
        'num_facturas': 0,
      });

      porMes[key]!['ingresos_base'] =
          (porMes[key]!['ingresos_base'] as double) +
              ((data['subtotal'] as num?)?.toDouble() ?? 0.0);
      porMes[key]!['iva_repercutido'] =
          (porMes[key]!['iva_repercutido'] as double) +
              ((data['total_iva'] as num?)?.toDouble() ?? 0.0);
      porMes[key]!['ingresos_total'] =
          (porMes[key]!['ingresos_total'] as double) +
              ((data['total'] as num?)?.toDouble() ?? 0.0);
      porMes[key]!['num_facturas'] =
          (porMes[key]!['num_facturas'] as int) + 1;
    }

    // Escribir en cache_contable
    final batch = _db.batch();
    for (final entry in porMes.entries) {
      final ref = _db
          .collection('empresas')
          .doc(empresaId)
          .collection('cache_contable')
          .doc(entry.key);
      batch.set(ref, {
        ...entry.value,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Elimina TODOS los datos de prueba (gastos, proveedores, facturas y pedidos)
  Future<void> limpiarDatosDePrueba(String empresaId) async {
    if (!kDebugMode) {
      debugPrint('⚠️ limpiarDatosDePrueba solo disponible en modo debug');
      return;
    }

    final colecciones = ['gastos', 'proveedores', 'facturas', 'pedidos'];

    for (final col in colecciones) {
      // Intentar filtrar por creado_por si la colección lo soporta
      QuerySnapshot snap;
      try {
        snap = await _db
            .collection('empresas')
            .doc(empresaId)
            .collection(col)
            .where('creado_por', isEqualTo: 'sistema_pruebas')
            .get();
      } catch (_) {
        snap = await _db
            .collection('empresas')
            .doc(empresaId)
            .collection(col)
            .get();
      }

      // Borrar en lotes de 20
      for (int i = 0; i < snap.docs.length; i += 20) {
        final lote = snap.docs.sublist(
            i, (i + 20) > snap.docs.length ? snap.docs.length : i + 20);
        final batch = _db.batch();
        for (final doc in lote) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    // Limpiar también la caché contable
    final cacheSnap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('cache_contable')
        .get();
    final batch = _db.batch();
    for (final doc in cacheSnap.docs) {
      batch.delete(doc.reference);
    }
    if (cacheSnap.docs.isNotEmpty) await batch.commit();

    debugPrint('✅ Datos de prueba eliminados');
  }
}