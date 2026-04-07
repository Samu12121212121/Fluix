import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../domain/modelos/contabilidad.dart';
import '../domain/modelos/nomina.dart';
import 'nominas_service.dart';

final _log = Logger();

/// Genera datos de prueba realistas para la empresa Fluixtech.
/// 10 clientes, 30 empleados (con datos de nómina), facturas,
/// gastos, nóminas, valoraciones, reservas, pedidos y transacciones.
class DatosPruebaFluixtechService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NominasService _nominasSvc = NominasService();
  final _rng = Random(42); // seed fijo para reproducibilidad

  static const _empresaId = 'fluixtech';

  /// Ejecuta toda la generación de datos de prueba
  Future<void> generarTodo() async {
    _log.i('Generando datos de prueba para Fluixtech...');
    await Future.wait([
      _crearClientes(),
      _crearEmpleados(),
      _crearServicios(),
      _crearProveedores(),
    ]);
    // Dependientes de empleados:
    await _crearNominas();
    await _crearFacturas();
    await _crearGastos();
    await _crearPedidos();
    await _crearReservas();
    await _crearTransacciones();
    await _crearValoraciones();
    _log.i('Todos los datos de prueba de Fluixtech generados');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 10 CLIENTES
  // ═══════════════════════════════════════════════════════════════════════════

  static const _clientes = [
    {'nombre': 'Restaurante El Olivo S.L.',  'correo': 'contacto@elolivo.es',       'telefono': '+34 911 234 001', 'ciudad': 'Madrid',      'etiquetas': ['Premium', 'Hostelería']},
    {'nombre': 'Clínica Dental Sonríe',      'correo': 'admin@clinicasonrie.com',    'telefono': '+34 912 345 002', 'ciudad': 'Barcelona',   'etiquetas': ['Salud', 'Recurrente']},
    {'nombre': 'Taller Mecánico Ruiz',       'correo': 'ruiz@tallerruiz.es',         'telefono': '+34 913 456 003', 'ciudad': 'Valencia',    'etiquetas': ['Automoción']},
    {'nombre': 'Peluquería Estilo & Co',     'correo': 'info@estiloyco.com',         'telefono': '+34 914 567 004', 'ciudad': 'Sevilla',     'etiquetas': ['Belleza', 'VIP']},
    {'nombre': 'Academia Idiomas Plus',      'correo': 'hola@idiomasplus.es',        'telefono': '+34 915 678 005', 'ciudad': 'Málaga',      'etiquetas': ['Educación']},
    {'nombre': 'Inmobiliaria Costa Sur',     'correo': 'ventas@costasur.es',         'telefono': '+34 916 789 006', 'ciudad': 'Alicante',    'etiquetas': ['Inmobiliaria', 'Premium']},
    {'nombre': 'Gimnasio FitZone',           'correo': 'gym@fitzone.es',             'telefono': '+34 917 890 007', 'ciudad': 'Bilbao',      'etiquetas': ['Deporte', 'Startup']},
    {'nombre': 'Floristería Jardín Azul',    'correo': 'pedidos@jardinazul.com',     'telefono': '+34 918 901 008', 'ciudad': 'Zaragoza',    'etiquetas': ['Comercio']},
    {'nombre': 'Bufete García & Asociados',  'correo': 'bufete@garciaasoc.es',       'telefono': '+34 919 012 009', 'ciudad': 'Guadalajara', 'etiquetas': ['Legal', 'Recurrente']},
    {'nombre': 'Cafetería La Molienda',      'correo': 'info@lamolienda.es',         'telefono': '+34 920 123 010', 'ciudad': 'Toledo',      'etiquetas': ['Hostelería', 'Nuevo']},
  ];

  Future<void> _crearClientes() async {
    final ref = _db.collection('empresas').doc(_empresaId).collection('clientes');
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (int i = 0; i < _clientes.length; i++) {
      final c = _clientes[i];
      final docRef = ref.doc('cli_${i + 1}');
      final diasRegistro = 180 - (i * 15) + _rng.nextInt(20);
      final diasVisita = _rng.nextInt(14);
      batch.set(docRef, {
        'id': docRef.id,
        'nombre': c['nombre'],
        'correo': c['correo'],
        'telefono': c['telefono'],
        'ciudad': c['ciudad'],
        'etiquetas': c['etiquetas'],
        'fecha_registro': Timestamp.fromDate(DateTime.now().subtract(Duration(days: diasRegistro))),
        'ultima_visita': Timestamp.fromDate(DateTime.now().subtract(Duration(days: diasVisita))),
        'numero_reservas': 3 + _rng.nextInt(15),
        'total_gastado': 250.0 + _rng.nextDouble() * 2000,
        'activo': i != 7, // uno inactivo
        'notas': i == 0 ? 'Cliente fundador, plan Premium desde el día 1' : '',
      });
    }
    await batch.commit();
    _log.i('10 clientes creados');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 30 EMPLEADOS (con datos_nomina)
  // ═══════════════════════════════════════════════════════════════════════════

  static const _nombresEmpleados = [
    // Dirección (admin — el propietario real es el usuario logueado, no datos de prueba)
    {'nombre': 'Samuel Ortega Ruiz',       'rol': 'admin', 'puesto': 'CEO / Fundador',          'salario': 45000},
    {'nombre': 'Elena Vázquez Torres',     'rol': 'admin',       'puesto': 'CTO',                     'salario': 42000},
    {'nombre': 'Marcos Gil Hernández',     'rol': 'admin',       'puesto': 'Director Comercial',      'salario': 38000},
    // Desarrollo
    {'nombre': 'Laura Sánchez Pérez',      'rol': 'staff', 'puesto': 'Desarrolladora Flutter Sr.',    'salario': 36000},
    {'nombre': 'Javier Moreno López',      'rol': 'staff', 'puesto': 'Desarrollador Backend Sr.',     'salario': 35000},
    {'nombre': 'Carmen Díaz Navarro',      'rol': 'staff', 'puesto': 'Desarrolladora Full-Stack',     'salario': 32000},
    {'nombre': 'Adrián Romero Castro',     'rol': 'staff', 'puesto': 'Desarrollador Flutter Jr.',     'salario': 24000},
    {'nombre': 'Natalia Jiménez Ruiz',     'rol': 'staff', 'puesto': 'Desarrolladora Web',            'salario': 28000},
    {'nombre': 'Pablo Herrera Molina',     'rol': 'staff', 'puesto': 'DevOps Engineer',               'salario': 34000},
    {'nombre': 'Sofía Ramos Iglesias',     'rol': 'staff', 'puesto': 'QA / Tester',                   'salario': 26000},
    // Diseño
    {'nombre': 'Lucía Martínez Blanco',    'rol': 'staff', 'puesto': 'UX/UI Designer Lead',           'salario': 33000},
    {'nombre': 'Daniel Alonso Vargas',     'rol': 'staff', 'puesto': 'Diseñador Gráfico',             'salario': 25000},
    // Soporte / Atención
    {'nombre': 'Isabel Torres Muñoz',      'rol': 'staff', 'puesto': 'Soporte Técnico L1',            'salario': 21000},
    {'nombre': 'Raúl Fernández Soto',      'rol': 'staff', 'puesto': 'Soporte Técnico L2',            'salario': 23000},
    {'nombre': 'Andrea López García',      'rol': 'staff', 'puesto': 'Customer Success',              'salario': 25000},
    {'nombre': 'Miguel Ángel Reyes',       'rol': 'staff', 'puesto': 'Help Desk',                     'salario': 20000},
    // Ventas / Marketing
    {'nombre': 'Patricia Delgado Ruiz',    'rol': 'staff', 'puesto': 'Account Executive Sr.',          'salario': 30000},
    {'nombre': 'Sergio Campos Ortiz',      'rol': 'staff', 'puesto': 'Account Executive Jr.',          'salario': 22000},
    {'nombre': 'María Rubio Ibáñez',       'rol': 'staff', 'puesto': 'Marketing Digital',              'salario': 27000},
    {'nombre': 'Roberto Peña Calvo',       'rol': 'staff', 'puesto': 'SEO / SEM Specialist',           'salario': 26000},
    {'nombre': 'Ana Belén Cruz Santos',    'rol': 'staff', 'puesto': 'Community Manager',              'salario': 22000},
    // Administración / Finanzas
    {'nombre': 'Teresa Gallego Prieto',    'rol': 'admin', 'puesto': 'Directora Financiera',           'salario': 40000},
    {'nombre': 'Fernando Lozano Martín',   'rol': 'staff', 'puesto': 'Contable',                       'salario': 26000},
    {'nombre': 'Cristina Moya Giménez',    'rol': 'staff', 'puesto': 'RRHH',                           'salario': 28000},
    {'nombre': 'Álvaro Benítez Serrano',   'rol': 'staff', 'puesto': 'Administrativo',                 'salario': 20000},
    // Producto
    {'nombre': 'Inés Cabrera Pascual',     'rol': 'staff', 'puesto': 'Product Manager',                'salario': 35000},
    {'nombre': 'Hugo Domínguez León',      'rol': 'staff', 'puesto': 'Scrum Master',                   'salario': 32000},
    // IT Infra
    {'nombre': 'David Caballero Nieto',    'rol': 'staff', 'puesto': 'SysAdmin',                       'salario': 30000},
    // Becarios/Prácticas
    {'nombre': 'Marina Soler Aguilar',     'rol': 'staff', 'puesto': 'Becaria Desarrollo',             'salario': 12000},
    {'nombre': 'Tomás Esteban Rojas',      'rol': 'staff', 'puesto': 'Becario Marketing',              'salario': 12000},
  ];

  Future<void> _crearEmpleados() async {
    // Comprobamos si ya existen empleados de prueba
    final existentes = await _db.collection('usuarios')
        .where('empresa_id', isEqualTo: _empresaId)
        .limit(5).get();
    if (existentes.docs.length >= 5) return;

    final contratos = [TipoContrato.indefinido, TipoContrato.temporal, TipoContrato.practicas];

    for (int i = 0; i < _nombresEmpleados.length; i++) {
      final e = _nombresEmpleados[i];
      final nombre = e['nombre'] as String;
      final correo = _emailFromNombre(nombre);
      final salario = (e['salario'] as int).toDouble();
      final rol = e['rol'] as String;

      final contrato = i >= 28 ? TipoContrato.practicas :
                       (i < 6 ? TipoContrato.indefinido :
                       contratos[i % 2 == 0 ? 0 : 1]);

      final diasAntiguedad = 365 + _rng.nextInt(730) - (i * 20);
      final docId = 'emp_fluix_${(i + 1).toString().padLeft(2, '0')}';

      await _db.collection('usuarios').doc(docId).set({
        'nombre': nombre,
        'correo': correo,
        'telefono': '+34 6${(10 + i).toString().padLeft(2, '0')} ${_rng.nextInt(900) + 100} ${_rng.nextInt(900) + 100}',
        'empresa_id': _empresaId,
        'rol': rol,
        'activo': i != 15, // Miguel Ángel Reyes inactivo (baja)
        'fecha_creacion': DateTime.now().subtract(Duration(days: diasAntiguedad.abs())).toIso8601String(),
        'permisos': [],
        'token_dispositivo': null,
        'puesto': e['puesto'],
        // ── Datos de nómina ──
        'datos_nomina': {
          'salario_bruto_anual': salario,
          'tipo_contrato': contrato.name,
          'num_pagas': i < 10 ? 14 : 12,
          'nif': _generarNif(i),
          'nss': '28/${(1000000 + i * 12345) % 9999999}/${_rng.nextInt(90) + 10}',
          'cuenta_bancaria': 'ES${(10 + i).toString().padLeft(2, '0')} 0049 ${_rng.nextInt(9999).toString().padLeft(4, '0')} ${_rng.nextInt(99).toString().padLeft(2, '0')} ${_rng.nextInt(9999999999).toString().padLeft(10, '0')}',
          'grupo_cotizacion': i < 3 ? '1' : (i < 10 ? '2' : (i < 20 ? '3' : '5')),
        },
      });
    }
    _log.i('30 empleados creados con datos de nómina');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NÓMINAS (Enero, Febrero, Marzo 2026)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _crearNominas() async {
    final ref = _db.collection('empresas').doc(_empresaId).collection('nominas');
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    // Generar nóminas para Enero, Febrero y Marzo
    for (int mes = 1; mes <= 3; mes++) {
      for (int i = 0; i < _nombresEmpleados.length; i++) {
        if (i == 15) continue; // empleado inactivo

        final e = _nombresEmpleados[i];
        final salario = (e['salario'] as int).toDouble();
        final contrato = i >= 28 ? TipoContrato.practicas :
                         (i < 6 ? TipoContrato.indefinido : TipoContrato.indefinido);
        final numPagas = i < 10 ? 14 : 12;

        final nomina = _nominasSvc.calcularNomina(
          empresaId: _empresaId,
          empleadoId: 'emp_fluix_${(i + 1).toString().padLeft(2, '0')}',
          empleadoNombre: e['nombre'] as String,
          empleadoNif: _generarNif(i),
          empleadoNss: '28/${(1000000 + i * 12345) % 9999999}/${_rng.nextInt(90) + 10}',
          mes: mes,
          anio: 2026,
          config: DatosNominaEmpleado(
            salarioBrutoAnual: salario,
            tipoContrato: contrato,
            numPagas: numPagas,
          ),
          horasExtra: i < 5 ? _rng.nextInt(8).toDouble() : 0,
          precioHoraExtra: 18.0,
          complementosVariables: i < 3 ? 150.0 : 0,
        );

        // Estado: Enero y Febrero pagadas, Marzo borradores
        final estado = mes <= 2 ? EstadoNomina.pagada : EstadoNomina.borrador;
        final data = nomina.toMap();
        data['estado'] = estado.name;
        if (mes <= 2) {
          data['fecha_pago'] = Timestamp.fromDate(DateTime(2026, mes, 28));
        }

        final docRef = ref.doc();
        data['id'] = docRef.id;
        await docRef.set(data);
      }
    }
    _log.i('Nóminas generadas (Ene-Mar 2026) para 29 empleados');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SERVICIOS (paquetes SaaS de Fluixtech)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _crearServicios() async {
    final ref = _db.collection('empresas').doc(_empresaId).collection('servicios');
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final servicios = [
      {'nombre': 'Plan Base Fluix CRM',           'precio': 300.0, 'descripcion': 'Dashboard, reservas, citas opcionales, clientes, valoraciones y estadísticas', 'categoria': 'SaaS', 'duracion': 365},
      {'nombre': 'Pack Gestión',                   'precio': 350.0, 'descripcion': 'Base + WhatsApp + Facturación',                             'categoria': 'SaaS', 'duracion': 365},
      {'nombre': 'Pack Tienda Online',             'precio': 450.0, 'descripcion': 'Base + Gestión + Pedidos online',                           'categoria': 'SaaS', 'duracion': 365},
      {'nombre': 'Módulo Nóminas (por empleado)',  'precio': 3.0,   'descripcion': 'Gestión de nóminas automática, 3€/empleado/mes',            'categoria': 'Add-on', 'duracion': 30},
      {'nombre': 'Desarrollo Web a medida',        'precio': 1500.0,'descripcion': 'Landing page responsive con integración Fluix',             'categoria': 'Servicio', 'duracion': 30},
      {'nombre': 'Consultoría Digitalización',     'precio': 500.0, 'descripcion': 'Sesión de 4h + informe personalizado',                      'categoria': 'Servicio', 'duracion': 1},
      {'nombre': 'Soporte Premium 24/7',           'precio': 100.0, 'descripcion': 'Soporte prioritario ilimitado',                             'categoria': 'Add-on', 'duracion': 30},
      {'nombre': 'Migración de datos',             'precio': 300.0, 'descripcion': 'Importación de datos desde otro CRM',                       'categoria': 'Servicio', 'duracion': 7},
    ];

    final batch = _db.batch();
    for (int i = 0; i < servicios.length; i++) {
      final docRef = ref.doc('svc_${i + 1}');
      batch.set(docRef, {
        ...servicios[i],
        'id': docRef.id,
        'activo': true,
        'fecha_creacion': Timestamp.now(),
      });
    }
    await batch.commit();
    _log.i('8 servicios/paquetes creados');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROVEEDORES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _crearProveedores() async {
    final ref = _db.collection('empresas').doc(_empresaId).collection('proveedores');
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final proveedores = [
      {'nombre': 'OVHcloud',            'nif': 'ESB-87110722', 'categoria': 'software',     'email': 'billing@ovhcloud.com'},
      {'nombre': 'Google Cloud',        'nif': 'ESB-82743863', 'categoria': 'software',     'email': 'billing@google.com'},
      {'nombre': 'Firebase (Google)',    'nif': 'ESB-82743863', 'categoria': 'software',     'email': 'billing@google.com'},
      {'nombre': 'Stripe',              'nif': 'IE3206488LH',  'categoria': 'servicios',    'email': 'invoices@stripe.com'},
      {'nombre': 'Apple Developer',     'nif': 'IE9700053D',   'categoria': 'software',     'email': 'developer@apple.com'},
      {'nombre': 'Google Play Console', 'nif': 'ESB-82743863', 'categoria': 'software',     'email': 'play-console@google.com'},
      {'nombre': 'Hostinger',           'nif': 'LT100011718519','categoria': 'software',    'email': 'billing@hostinger.com'},
      {'nombre': 'Gestoría Rodríguez',  'nif': 'B-98765432',   'categoria': 'gestor',       'email': 'info@gestoriarod.es'},
      {'nombre': 'Mutua Madrileña',     'nif': 'A-28043015',   'categoria': 'seguros',      'email': 'empresas@mutua.es'},
      {'nombre': 'WeWork Spaces',       'nif': 'B-67890123',   'categoria': 'alquiler',     'email': 'invoicing@wework.com'},
    ];

    final batch = _db.batch();
    for (final p in proveedores) {
      final docRef = ref.doc();
      batch.set(docRef, {
        ...p,
        'id': docRef.id,
        'activo': true,
        'fecha_alta': Timestamp.fromDate(DateTime(2025, 6, 1)),
      });
    }
    await batch.commit();
    _log.i('10 proveedores creados');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTURAS EMITIDAS (ingresos de Fluixtech por vender SaaS)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _crearFacturas() async {
    final ref = _db.collection('empresas').doc(_empresaId).collection('facturas');
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final ahora = DateTime.now();
    final facturas = <Map<String, dynamic>>[];
    int num = 1;

    // Cada cliente tiene una factura mensual (suscripción) de Ene a Mar
    for (int mes = 1; mes <= ahora.month; mes++) {
      for (int c = 0; c < _clientes.length; c++) {
        final cli = _clientes[c];
        // Clientes 0-3: Pack Tienda (450€), 4-6: Pack Gestión (350€), 7-9: Base (300€)
        final double precio = c < 4 ? 450.0 : (c < 7 ? 350.0 : 300.0);
        final plan = c < 4 ? 'Pack Tienda Online' : (c < 7 ? 'Pack Gestión' : 'Plan Base');
        final base = precio;
        final iva = base * 0.21;
        final total = base + iva;

        final dia = 1 + (c % 5);
        final fecha = DateTime(2026, mes, dia);
        final esPagada = mes < ahora.month || (mes == ahora.month && c < 7);

        facturas.add({
          'numero_factura': 'FLX-2026-${num.toString().padLeft(4, '0')}',
          'cliente_nombre': cli['nombre'],
          'cliente_email': cli['correo'],
          'datos_fiscales': {'nif': 'B-${(12345678 + c).toString()}', 'nombre': cli['nombre']},
          'lineas': [{'descripcion': '$plan — ${Nomina.nombreMes(mes)} 2026', 'cantidad': 1, 'precio_unitario': precio, 'tipo_iva': 21.0, 'subtotal': base, 'iva_amount': iva, 'total': total}],
          'subtotal': base,
          'total_iva': iva,
          'total': total,
          'estado': esPagada ? 'pagada' : 'pendiente',
          'metodo_pago': esPagada ? (['tarjeta', 'transferencia', 'bizum', 'paypal'])[c % 4] : null,
          'fecha_emision': Timestamp.fromDate(fecha),
          'fecha_vencimiento': Timestamp.fromDate(fecha.add(const Duration(days: 30))),
          if (esPagada) 'fecha_pago': Timestamp.fromDate(fecha.add(Duration(days: c % 3))),
          'creado_por': 'sistema_pruebas',
          'fecha_creacion': Timestamp.fromDate(fecha),
        });
        num++;
      }

      // Facturas extra: nóminas module, desarrollo web, consultoría
      if (mes == 1) {
        // Desarrollo web para cliente 0
        facturas.add(_facturaExtra(num++, 'FLX', 'Desarrollo Web a medida', _clientes[0], 1500.0, DateTime(2026, 1, 15)));
        // Consultoría para cliente 5
        facturas.add(_facturaExtra(num++, 'FLX', 'Consultoría Digitalización', _clientes[5], 500.0, DateTime(2026, 1, 20)));
      }
      if (mes == 2) {
        // Migración de datos para cliente 2
        facturas.add(_facturaExtra(num++, 'FLX', 'Migración de datos', _clientes[2], 300.0, DateTime(2026, 2, 10)));
      }
    }

    // Escribir en lotes
    for (int i = 0; i < facturas.length; i += 20) {
      final lote = facturas.sublist(i, (i + 20) > facturas.length ? facturas.length : i + 20);
      final batch = _db.batch();
      for (final f in lote) {
        final docRef = ref.doc();
        batch.set(docRef, {...f, 'id': docRef.id});
      }
      await batch.commit();
    }
    _log.i('${facturas.length} facturas emitidas creadas');
  }

  Map<String, dynamic> _facturaExtra(int num, String prefix, String concepto, Map<String, dynamic> cli, double precio, DateTime fecha) {
    final iva = precio * 0.21;
    return {
      'numero_factura': '$prefix-2026-${num.toString().padLeft(4, '0')}',
      'cliente_nombre': cli['nombre'],
      'cliente_email': cli['correo'],
      'datos_fiscales': {'nombre': cli['nombre']},
      'lineas': [{'descripcion': concepto, 'cantidad': 1, 'precio_unitario': precio, 'tipo_iva': 21.0, 'subtotal': precio, 'iva_amount': iva, 'total': precio + iva}],
      'subtotal': precio,
      'total_iva': iva,
      'total': precio + iva,
      'estado': 'pagada',
      'metodo_pago': 'transferencia',
      'fecha_emision': Timestamp.fromDate(fecha),
      'fecha_vencimiento': Timestamp.fromDate(fecha.add(const Duration(days: 30))),
      'fecha_pago': Timestamp.fromDate(fecha.add(const Duration(days: 5))),
      'creado_por': 'sistema_pruebas',
      'fecha_creacion': Timestamp.fromDate(fecha),
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GASTOS (gastos operativos de Fluixtech)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _crearGastos() async {
    final ref = _db.collection('empresas').doc(_empresaId).collection('gastos');
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final ahora = DateTime.now();
    final gastos = <Map<String, dynamic>>[];

    for (int mes = 1; mes <= ahora.month; mes++) {
      // Hosting OVH
      gastos.add(_gasto('Servidor dedicado OVH', CategoriaGasto.software, 'OVHcloud', 89.0, 21.0, DateTime(2026, mes, 1)));
      // Firebase
      gastos.add(_gasto('Firebase Blaze Plan', CategoriaGasto.software, 'Firebase (Google)', 45.0 + _rng.nextInt(30).toDouble(), 21.0, DateTime(2026, mes, 3)));
      // Hostinger
      gastos.add(_gasto('Hosting webs clientes', CategoriaGasto.software, 'Hostinger', 24.99, 21.0, DateTime(2026, mes, 5)));
      // Stripe fees
      gastos.add(_gasto('Comisiones Stripe', CategoriaGasto.servicios, 'Stripe', 35.0 + _rng.nextDouble() * 50, 0.0, DateTime(2026, mes, 8), ivaDeducible: false));
      // Apple Developer
      if (mes == 1) gastos.add(_gasto('Apple Developer Program anual', CategoriaGasto.software, 'Apple Developer', 99.0, 0.0, DateTime(2026, 1, 15), ivaDeducible: false));
      // Google Play
      if (mes == 1) gastos.add(_gasto('Google Play Developer (one-time)', CategoriaGasto.software, 'Google Play Console', 25.0, 0.0, DateTime(2026, 1, 15), ivaDeducible: false));
      // Oficina WeWork
      gastos.add(_gasto('Espacio coworking WeWork', CategoriaGasto.alquiler, 'WeWork Spaces', 1200.0, 21.0, DateTime(2026, mes, 1)));
      // Gestoría trimestral
      if (mes == 3) gastos.add(_gasto('Honorarios gestoría T1 2026', CategoriaGasto.gestor, 'Gestoría Rodríguez', 450.0, 21.0, DateTime(2026, 3, 28)));
      // Seguro
      if (mes == 1) gastos.add(_gasto('Seguro RC profesional anual', CategoriaGasto.seguros, 'Mutua Madrileña', 680.0, 0.0, DateTime(2026, 1, 10), ivaDeducible: false));
      // Marketing
      if (mes % 2 == 1) gastos.add(_gasto('Campaña Google Ads', CategoriaGasto.marketing, null, 200.0 + _rng.nextInt(200).toDouble(), 21.0, DateTime(2026, mes, 15)));
    }

    for (int i = 0; i < gastos.length; i += 20) {
      final lote = gastos.sublist(i, (i + 20) > gastos.length ? gastos.length : i + 20);
      final batch = _db.batch();
      for (final g in lote) {
        final docRef = ref.doc();
        batch.set(docRef, {...g, 'id': docRef.id});
      }
      await batch.commit();
    }
    _log.i('${gastos.length} gastos creados');
  }

  Map<String, dynamic> _gasto(String concepto, CategoriaGasto cat, String? prov, double base, double porcIva, DateTime fecha, {bool ivaDeducible = true}) {
    final iva = ivaDeducible ? base * porcIva / 100 : 0.0;
    return {
      'empresa_id': _empresaId,
      'concepto': concepto,
      'categoria': cat.name,
      if (prov != null) 'proveedor_nombre': prov,
      'base_imponible': base,
      'porcentaje_iva': ivaDeducible ? porcIva : 0.0,
      'importe_iva': iva,
      'total': base + iva,
      'iva_deducible': ivaDeducible,
      'estado': 'pagado',
      'fecha_gasto': Timestamp.fromDate(fecha),
      'fecha_pago': Timestamp.fromDate(fecha),
      'metodo_pago': 'transferencia',
      'fecha_creacion': Timestamp.fromDate(fecha),
      'creado_por': 'sistema_pruebas',
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PEDIDOS (compras de paquetes SaaS por web)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _crearPedidos() async {
    final ref = _db.collection('empresas').doc(_empresaId).collection('pedidos');
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final ahora = DateTime.now();
    final pedidos = <Map<String, dynamic>>[];

    for (int mes = 1; mes <= ahora.month; mes++) {
      for (int i = 0; i < 5 + _rng.nextInt(5); i++) {
        final c = _clientes[i % _clientes.length];
        final pack = i % 3;
        final nombre = ['Plan Base', 'Pack Gestión', 'Pack Tienda'][pack];
        final precio = [300.0, 350.0, 450.0][pack];
        final dia = 1 + _rng.nextInt(27);
        final fecha = DateTime(2026, mes, dia.clamp(1, 28));
        final completado = _rng.nextDouble() > 0.15;

        pedidos.add({
          'cliente': c['nombre'],
          'telefono': c['telefono'],
          'productos': [{'nombre': nombre, 'precio': precio, 'cantidad': 1, 'subtotal': precio}],
          'precio_total': precio,
          'estado': completado ? 'completado' : 'pendiente',
          'origen': ['web', 'app', 'whatsapp'][i % 3],
          'pagado': completado,
          'metodo_pago': completado ? ['tarjeta', 'transferencia', 'bizum'][i % 3] : null,
          'fecha_creacion': Timestamp.fromDate(fecha),
          'creado_por': 'sistema_pruebas',
        });
      }
    }

    final batch = _db.batch();
    for (final p in pedidos) {
      final docRef = ref.doc();
      batch.set(docRef, {...p, 'id': docRef.id});
    }
    await batch.commit();
    _log.i('${pedidos.length} pedidos creados');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESERVAS (demos/reuniones con clientes potenciales)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _crearReservas() async {
    final ref = _db.collection('empresas').doc(_empresaId).collection('reservas');
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final reservas = <Map<String, dynamic>>[];
    final horas = ['09:00', '10:00', '11:30', '12:00', '16:00', '17:00', '18:00'];

    for (int dia = -30; dia <= 15; dia++) {
      final fecha = DateTime.now().add(Duration(days: dia));
      if (fecha.weekday >= 6) continue; // L-V

      final n = 1 + _rng.nextInt(3);
      for (int i = 0; i < n; i++) {
        final c = _clientes[(dia.abs() + i) % _clientes.length];
        final estado = dia < -1 ? 'COMPLETADA' : (dia < 0 ? 'CONFIRMADA' : (dia == 0 ? 'CONFIRMADA' : 'PENDIENTE'));

        reservas.add({
          'cliente_id': 'cli_${((dia.abs() + i) % _clientes.length) + 1}',
          'cliente_nombre': c['nombre'],
          'servicio_id': 'svc_${1 + i % 3}',
          'empleado_asignado': 'emp_fluix_${(3 + i).toString().padLeft(2, '0')}',
          'fecha': Timestamp.fromDate(fecha),
          'hora_inicio': horas[(dia.abs() + i) % horas.length],
          'estado': estado,
          'precio': [250.0, 350.0, 500.0][i % 3],
          'notas': i == 0 ? 'Demo personalizada del CRM' : '',
          'fecha_creacion': Timestamp.fromDate(fecha.subtract(const Duration(days: 3))),
        });
      }
    }

    for (int i = 0; i < reservas.length; i += 20) {
      final lote = reservas.sublist(i, (i + 20) > reservas.length ? reservas.length : i + 20);
      final batch = _db.batch();
      for (final r in lote) {
        final docRef = ref.doc();
        batch.set(docRef, {...r, 'id': docRef.id});
      }
      await batch.commit();
    }
    _log.i('${reservas.length} reservas creadas');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSACCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _crearTransacciones() async {
    final ref = _db.collection('empresas').doc(_empresaId).collection('transacciones');
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final transacciones = <Map<String, dynamic>>[];
    for (int dia = 0; dia < 90; dia++) {
      final fecha = DateTime.now().subtract(Duration(days: dia));
      if (fecha.weekday >= 6) continue;

      final n = 1 + _rng.nextInt(3);
      for (int i = 0; i < n; i++) {
        final monto = 250.0 + _rng.nextDouble() * 300;
        transacciones.add({
          'cliente_id': 'cli_${1 + (dia + i) % _clientes.length}',
          'monto': monto,
          'metodo_pago': ['Tarjeta', 'Transferencia', 'Bizum'][i % 3],
          'fecha': Timestamp.fromDate(fecha),
          'concepto': 'Suscripción Fluix CRM',
          'estado': 'completada',
        });
      }
    }

    for (int i = 0; i < transacciones.length; i += 20) {
      final lote = transacciones.sublist(i, (i + 20) > transacciones.length ? transacciones.length : i + 20);
      final batch = _db.batch();
      for (final t in lote) {
        final docRef = ref.doc();
        batch.set(docRef, {...t, 'id': docRef.id});
      }
      await batch.commit();
    }
    _log.i('${transacciones.length} transacciones creadas');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALORACIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _crearValoraciones() async {
    final ref = _db.collection('empresas').doc(_empresaId).collection('valoraciones');
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final resenas = [
      {'cliente': _clientes[0]['nombre'], 'cal': 5, 'txt': 'Fluix CRM nos ha cambiado la gestión del restaurante. Todo automatizado y fácil.'},
      {'cliente': _clientes[1]['nombre'], 'cal': 5, 'txt': 'Increíble para gestionar citas de la clínica. El módulo de reservas es perfecto.'},
      {'cliente': _clientes[2]['nombre'], 'cal': 4, 'txt': 'Buen CRM, la facturación automática nos ahorra mucho tiempo.'},
      {'cliente': _clientes[3]['nombre'], 'cal': 5, 'txt': 'Lo mejor del mercado para peluquerías. Valoraciones de Google integradas, genial.'},
      {'cliente': _clientes[4]['nombre'], 'cal': 4, 'txt': 'Funcional y económico. Nos viene perfecto para la academia.'},
      {'cliente': _clientes[5]['nombre'], 'cal': 5, 'txt': 'El dashboard de estadísticas nos da visibilidad total del negocio.'},
      {'cliente': _clientes[6]['nombre'], 'cal': 3, 'txt': 'Está bien pero echo en falta integración con máquinas de gym.'},
      {'cliente': _clientes[7]['nombre'], 'cal': 5, 'txt': 'Sencillo, bonito y funcional. El soporte técnico es excelente.'},
      {'cliente': _clientes[8]['nombre'], 'cal': 4, 'txt': 'Muy útil para el bufete. Gestión de tareas y clientes impecable.'},
      {'cliente': _clientes[9]['nombre'], 'cal': 5, 'txt': 'Recién contratado y ya no puedo vivir sin él. La app va como la seda.'},
    ];

    final batch = _db.batch();
    for (int i = 0; i < resenas.length; i++) {
      final r = resenas[i];
      final docRef = ref.doc('val_${i + 1}');
      batch.set(docRef, {
        'id': docRef.id,
        'cliente': r['cliente'],
        'cliente_id': 'cli_${i + 1}',
        'calificacion': r['cal'],
        'comentario': r['txt'],
        'fecha': Timestamp.fromDate(DateTime.now().subtract(Duration(days: i * 3 + _rng.nextInt(5)))),
        'origen': 'google',
        'respondida': i % 2 == 0,
        'respuesta': i % 2 == 0 ? '¡Muchas gracias por tu valoración! Nos alegra que Fluix CRM te sea útil. 🚀' : null,
      });
    }
    await batch.commit();
    _log.i('10 valoraciones creadas');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _emailFromNombre(String nombre) {
    final partes = nombre.toLowerCase()
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ñ', 'n')
        .split(' ');
    if (partes.length >= 2) return '${partes[0]}.${partes[1]}@fluixtech.com';
    return '${partes[0]}@fluixtech.com';
  }

  String _generarNif(int i) {
    final num = (10000000 + i * 1234567) % 99999999;
    final letras = 'TRWAGMYFPDXBNJZSQVHLCKE';
    return '$num${letras[num % 23]}';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIMPIAR TODO
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> limpiarTodo() async {
    _log.i('Limpiando datos de prueba de Fluixtech...');
    final colecciones = ['clientes', 'servicios', 'proveedores', 'facturas', 'gastos',
      'pedidos', 'reservas', 'transacciones', 'valoraciones', 'nominas', 'cache_contable', 'cache'];

    for (final col in colecciones) {
      final snap = await _db.collection('empresas').doc(_empresaId).collection(col).get();
      for (int i = 0; i < snap.docs.length; i += 20) {
        final lote = snap.docs.sublist(i, (i + 20) > snap.docs.length ? snap.docs.length : i + 20);
        final batch = _db.batch();
        for (final doc in lote) batch.delete(doc.reference);
        await batch.commit();
      }
    }

    // Limpiar empleados de prueba
    final emps = await _db.collection('usuarios')
        .where('empresa_id', isEqualTo: _empresaId).get();
    for (int i = 0; i < emps.docs.length; i += 20) {
      final lote = emps.docs.sublist(i, (i + 20) > emps.docs.length ? emps.docs.length : i + 20);
      final batch = _db.batch();
      for (final doc in lote) {
        if (doc.id.startsWith('emp_fluix_')) batch.delete(doc.reference);
      }
      await batch.commit();
    }

    _log.i('Todo limpiado');
  }
}




