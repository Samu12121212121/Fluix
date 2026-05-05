import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../domain/modelos/nomina.dart';

/// Servicio para la cuenta demo de Fluix CRM.
/// Crea la cuenta demoFluix2026@gmail.com / FlFluix26 si no existe
/// y genera datos de prueba realistas en Firestore.
class DemoCuentaService {
  static final DemoCuentaService _i = DemoCuentaService._();
  factory DemoCuentaService() => _i;
  DemoCuentaService._();

  static const String demoEmail     = 'demoFluix2026@gmail.com';
  static const String demoPassword  = 'FlFluix26';
  static const String demoEmpresaId = 'demo_empresa_fluix2026';

  final _db = FirebaseFirestore.instance;
  final _random = Random();

  /// Verifica si el usuario actual es la cuenta demo.
  bool esDemo(String? email) =>
      email?.toLowerCase() == demoEmail.toLowerCase();

  /// Inicia sesión como demo:
  ///  - Crea la cuenta en Firebase Auth si no existe.
  ///  - Configura empresa + usuario en Firestore si es la primera vez.
  ///  - Devuelve el UID del usuario demo.
  Future<String> loginComoDemo() async {
    User? user;

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: demoEmail,
        password: demoPassword,
      );
      user = cred.user!;
      debugPrint('✅ Demo: cuenta creada — ${user.uid}');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: demoEmail,
          password: demoPassword,
        );
        user = cred.user!;
        debugPrint('✅ Demo: login correcto — ${user.uid}');
      } else {
        rethrow;
      }
    }

    await _configurarFirestoreDemo(user.uid);
    return user.uid;
  }

  /// Crea la cuenta demo en Firebase Auth si no existe.
  /// No afecta la sesión actual (solo garantiza que Auth existe).
  Future<void> crearCuentaDemoSiNoExiste() async {
    try {
      await loginComoDemo();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('⚠️ Demo crearCuentaDemoSiNoExiste: $e');
    }
  }

  /// Configura los documentos de Firestore para la empresa demo.
  Future<void> _configurarFirestoreDemo(String uid) async {
    final now        = DateTime.now();
    final empresaRef = _db.collection('empresas').doc(demoEmpresaId);

    // ── 1. USUARIO PRIMERO — las reglas de suscripción/configuración necesitan
    //    que usuarios/{uid} exista con empresa_id y rol correcto. ───────────
    await _db.collection('usuarios').doc(uid).set({
      'nombre':         'Usuario Demo',
      'correo':         demoEmail,
      'telefono':       '',
      'rol':            'admin',
      'empresa_id':     demoEmpresaId,
      'activo':         true,
      'permisos':       [],
      'fecha_creacion': now.toIso8601String(),
      'es_demo':        true,
      'datos_nomina': {
        'salario_bruto_anual':  24000.0,
        'tipo_contrato':        'indefinido',
        'num_pagas':            14,
        'horas_semanales':      40.0,
        'complemento_fijo':     0.0,
        'nif':                  '00000000T',
        'nss':                  '280000000000',
        'situacion_familiar':   'soltero',
        'num_hijos':            0,
        'num_hijos_menores_3':  0,
        'discapacidad':         false,
        'sector_empresa':       'hosteleria',
        'pagas_prorrateadas':   false,
      },
    }, SetOptions(merge: true));

    // ── 2. Empresa ──────────────────────────────────────────────────
    await empresaRef.set({
      'nombre':                'Empresa Demo Fluix',
      'correo':                demoEmail,
      'telefono':              '+34 900 000 000',
      'direccion':             'Calle Demo 1, Madrid',
      'descripcion':           'Cuenta de demostración de Fluix CRM',
      'categoria':             'Demostración',
      'onboarding_completado': true,
      'activa':                true,
      'fecha_creacion':        Timestamp.fromDate(now),
      'es_demo':               true,
    }, SetOptions(merge: true));

    // ── 3. Módulos ───────────────────────────────────────────────────
    await empresaRef.collection('configuracion').doc('modulos').set({
      'modulos': [
        {'id': 'dashboard',    'activo': true},
        {'id': 'valoraciones', 'activo': true},
        {'id': 'estadisticas', 'activo': true},
        {'id': 'reservas',     'activo': true},
        {'id': 'facturacion',  'activo': true},
        {'id': 'pedidos',      'activo': true},
        {'id': 'tareas',       'activo': true},
        {'id': 'clientes',     'activo': true},
        {'id': 'empleados',    'activo': true},
        {'id': 'nominas',      'activo': true},
        {'id': 'whatsapp',     'activo': true},
        {'id': 'web',          'activo': true},
      ],
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ── 4. Suscripción — es_demo:true + packs_activos para bypass de reglas ──
    await empresaRef.collection('suscripcion').doc('actual').set({
      'estado':         'ACTIVA',
      'plan':           'enterprise',
      'plan_base':      'basico',
      'packs_activos':  ['gestion', 'tienda', 'fiscal'],
      'addons_activos': ['whatsapp', 'tareas', 'nominas'],
      'es_demo':        true,   // ← permite acceder a todos los módulos premium
      'precio_total':   0,
      'fecha_inicio':   Timestamp.fromDate(now),
      'fecha_fin':      Timestamp.fromDate(now.add(const Duration(days: 365))),
      'aviso_enviado':  false,
      'ultimo_aviso':   null,
    }, SetOptions(merge: true));

    // ── 5. Config facturación ────────────────────────────────────────
    await empresaRef.collection('configuracion').doc('facturacion').set(
      {'ultimo_numero_factura': 0}, SetOptions(merge: true));


    // ── Empleados demo en la coleccion usuarios (para generarNominasMasivas) ──
    // generarNominasMasivas lee de usuarios/{uid} donde empresa_id == demoEmpresaId
    // Solo los creamos si no existen para no duplicar
    const empleado1Id = 'demo_empleado_001';
    const empleado2Id = 'demo_empleado_002';
    final emp1Doc = await _db.collection('usuarios').doc(empleado1Id).get();
    if (!emp1Doc.exists) {
      await _db.collection('usuarios').doc(empleado1Id).set({
        'nombre': 'Elena Martin Sanz',
        'correo': 'elena.demo@fluixcrm.test',
        'telefono': '+34 611 111 111',
        'rol': 'staff',
        'empresa_id': demoEmpresaId,
        'activo': true,
        'permisos': [],
        'fecha_creacion': now.toIso8601String(),
        'es_demo': true,
        'datos_nomina': {
          'salario_bruto_anual': 19950.0,
          'tipo_contrato': 'indefinido',
          'num_pagas': 14,
          'horas_semanales': 40.0,
          'complemento_fijo': 0.0,
          'nif': '11111111H',
          'nss': '280000000001',
          'situacion_familiar': 'casado',
          'num_hijos': 2,
          'num_hijos_menores_3': 0,
          'discapacidad': false,
          'sector_empresa': 'peluqueria',
          'pagas_prorrateadas': false,
        },
      });
      debugPrint('Demo: empleado1 creado');
    }
    final emp2Doc = await _db.collection('usuarios').doc(empleado2Id).get();
    if (!emp2Doc.exists) {
      await _db.collection('usuarios').doc(empleado2Id).set({
        'nombre': 'Roberto Lopez Vega',
        'correo': 'roberto.demo@fluixcrm.test',
        'telefono': '+34 622 222 222',
        'rol': 'staff',
        'empresa_id': demoEmpresaId,
        'activo': true,
        'permisos': [],
        'fecha_creacion': now.toIso8601String(),
        'es_demo': true,
        'datos_nomina': {
          'salario_bruto_anual': 17500.0,
          'tipo_contrato': 'indefinido',
          'num_pagas': 14,
          'horas_semanales': 40.0,
          'complemento_fijo': 0.0,
          'nif': '22222222J',
          'nss': '280000000002',
          'situacion_familiar': 'soltero',
          'num_hijos': 0,
          'num_hijos_menores_3': 0,
          'discapacidad': false,
          'sector_empresa': 'peluqueria',
          'pagas_prorrateadas': false,
        },
      });
      debugPrint('Demo: empleado2 creado');
    }

    debugPrint('Demo Firestore configurado para $uid / $demoEmpresaId');
  } // _configurarFirestoreDemo

  /// Genera datos de prueba completos para la empresa del usuario demo.
  Future<void> generarDatosPrueba(String empresaId) async {
    final ref = _db.collection('empresas').doc(empresaId);
    final now = DateTime.now();

    // ── 10 Clientes españoles ──────────────────────────────────────────
    final clientes = [
      {'nombre': 'María García López', 'telefono': '+34 612 345 678', 'email': 'maria.garcia@email.com', 'nif': '12345678Z'},
      {'nombre': 'Carlos Rodríguez Martín', 'telefono': '+34 623 456 789', 'email': 'carlos.rodriguez@email.com', 'nif': '23456789A'},
      {'nombre': 'Ana Fernández Ruiz', 'telefono': '+34 634 567 890', 'email': 'ana.fernandez@email.com', 'nif': '34567890B'},
      {'nombre': 'Pedro Sánchez Díaz', 'telefono': '+34 645 678 901', 'email': 'pedro.sanchez@email.com', 'nif': '45678901C'},
      {'nombre': 'Laura Martínez Gómez', 'telefono': '+34 656 789 012', 'email': 'laura.martinez@email.com', 'nif': '56789012D'},
      {'nombre': 'Javier López Hernández', 'telefono': '+34 667 890 123', 'email': 'javier.lopez@email.com', 'nif': '67890123E'},
      {'nombre': 'Carmen Díaz Torres', 'telefono': '+34 678 901 234', 'email': 'carmen.diaz@email.com', 'nif': '78901234F'},
      {'nombre': 'David Moreno Jiménez', 'telefono': '+34 689 012 345', 'email': 'david.moreno@email.com', 'nif': '89012345G'},
      {'nombre': 'Isabel Ruiz Navarro', 'telefono': '+34 690 123 456', 'email': 'isabel.ruiz@email.com', 'nif': '90123456H'},
      {'nombre': 'Miguel Alonso Serrano', 'telefono': '+34 601 234 567', 'email': 'miguel.alonso@email.com', 'nif': '01234567J'},
      {'nombre': 'Carmen Díaz Torres', 'telefono': '+34 678 901 234', 'email': 'carmen.diaz@email.com', 'nif': '78901234F'},
      {'nombre': 'David Moreno Jiménez', 'telefono': '+34 689 012 345', 'email': 'david.moreno@email.com', 'nif': '89012345G'},
      {'nombre': 'Isabel Ruiz Navarro', 'telefono': '+34 690 123 456', 'email': 'isabel.ruiz@email.com', 'nif': '90123456H'},
      {'nombre': 'Miguel Alonso Serrano', 'telefono': '+34 601 234 567', 'email': 'miguel.alonso@email.com', 'nif': '01234567J'},
    ];

    for (final c in clientes) {
      await ref.collection('clientes').add({
        ...c,
        'activo': true,
        'fecha_creacion': Timestamp.fromDate(now),
        'total_facturado': (_random.nextDouble() * 2000).roundToDouble(),
        'ultima_visita': Timestamp.fromDate(now.subtract(Duration(days: _random.nextInt(30)))),
        'etiquetas': [
          ['VIP', 'Regular', 'Nuevo', 'Frecuente'][_random.nextInt(4)]
        ],
        'es_prueba': true,
      });
    }

    // ── 5 Reservas próximos 7 días ────────────────────────────────────
    final servicios = ['Corte de pelo', 'Manicura', 'Masaje relajante', 'Tinte completo', 'Tratamiento facial'];
    for (int i = 0; i < 5; i++) {
      final fecha = now.add(Duration(days: _random.nextInt(7), hours: 9 + _random.nextInt(8)));
      await ref.collection('reservas').add({
        'cliente_nombre': clientes[i]['nombre'],
        'cliente_telefono': clientes[i]['telefono'],
        'servicio': servicios[i],
        'fecha': Timestamp.fromDate(fecha),
        'duracion': [30, 45, 60, 90][_random.nextInt(4)],
        'estado': 'confirmada',
        'precio': (20.0 + _random.nextInt(80)).toDouble(),
        'notas': '',
        'fecha_creacion': Timestamp.fromDate(now),
        'es_prueba': true,
      });
    }

    // ── 3 Facturas (2 pagadas, 1 pendiente) ──────────────────────────
    final estadosFactura = ['pagada', 'pagada', 'pendiente'];
    for (int i = 0; i < 3; i++) {
      final base = (50.0 + _random.nextInt(200)).toDouble();
      final iva = base * 0.21;
      await ref.collection('facturas').add({
        'numero': 'DEMO-${now.year}-${(i + 1).toString().padLeft(3, '0')}',
        'cliente_nombre': clientes[i]['nombre'],
        'cliente_nif': clientes[i]['nif'],
        'fecha_emision': Timestamp.fromDate(now.subtract(Duration(days: i * 5))),
        'fecha_vencimiento': Timestamp.fromDate(now.add(Duration(days: 30 - i * 5))),
        'base_imponible': base,
        'iva': iva,
        'total': base + iva,
        'tipo_iva': 21,
        'estado': estadosFactura[i],
        'lineas': [
          {
            'concepto': servicios[i],
            'cantidad': 1,
            'precio_unitario': base,
            'total': base,
          }
        ],
        'es_prueba': true,
      });
    }

    // ── 3 Empleados completos ─────────────────────────────────────────
    final empleados = [
      {'nombre': 'Elena Martín Sanz', 'correo': 'elena@demo.com', 'telefono': '+34 611 111 111', 'rol': 'admin'},
      {'nombre': 'Roberto López Vega', 'correo': 'roberto@demo.com', 'telefono': '+34 622 222 222', 'rol': 'staff'},
      {'nombre': 'Sofía García Ruiz', 'correo': 'sofia@demo.com', 'telefono': '+34 633 333 333', 'rol': 'staff'},
    ];

    final empleadoIds = <String>[];
    for (final e in empleados) {
      final docRef = await ref.collection('empleados').add({
        ...e,
        'activo': true,
        'fecha_creacion': Timestamp.fromDate(now),
        'datos_nomina': {
          'salario_bruto_anual': (18000 + _random.nextInt(12000)).toDouble(),
          'categoria': 'Grupo ${_random.nextInt(5) + 1}',
          'tipo_contrato': 'Indefinido',
          'jornada': 'Completa',
        },
        'es_prueba': true,
      });
      empleadoIds.add(docRef.id);
    }

    // ── 2 Nóminas generadas ──────────────────────────────────────────
    for (int i = 0; i < 2; i++) {
      final bruto = (1500 + _random.nextInt(500)).toDouble();
      final ssEmp = bruto * 0.3160;
      final ssTrab = bruto * 0.0647;
      final irpf = bruto * 0.15;
      final neto = bruto - ssTrab - irpf;
      await ref.collection('nominas').add({
        'empleado_id': empleadoIds.isNotEmpty ? empleadoIds[i % empleadoIds.length] : 'demo_$i',
        'empleado_nombre': empleados[i]['nombre'],
        'mes': now.month,
        'anio': now.year,
        'salario_bruto': bruto,
        'ss_empresa': ssEmp,
        'ss_trabajador': ssTrab,
        'irpf': irpf,
        'salario_neto': neto,
        'coste_total_empresa': bruto + ssEmp,
        'estado': i == 0 ? 'borrador' : 'pagada',
        'fecha_generacion': Timestamp.fromDate(now),
        'es_prueba': true,
      });
    }

    // ── 5 Tareas en distintos estados ────────────────────────────────
    final estados = ['pendiente', 'en_progreso', 'en_revision', 'completada', 'cancelada'];
    final prioridades = ['baja', 'media', 'alta', 'urgente', 'media'];
    final titulosTareas = [
      'Preparar pedido especial cliente VIP',
      'Revisar inventario de productos',
      'Actualizar carta de servicios',
      'Enviar facturas del mes anterior',
      'Reparar equipo de climatización',
    ];
    for (int i = 0; i < 5; i++) {
      await ref.collection('tareas').add({
        'titulo': titulosTareas[i],
        'descripcion': 'Tarea de prueba generada automáticamente para la demo.',
        'estado': estados[i],
        'prioridad': prioridades[i],
        'tipo': 'normal',
        'creado_por_id': FirebaseAuth.instance.currentUser?.uid ?? '',
        'fecha_creacion': Timestamp.fromDate(now.subtract(Duration(days: i))),
        'fecha_limite': i < 3 ? Timestamp.fromDate(now.add(Duration(days: 3 + i))) : null,
        'subtareas': [],
        'etiquetas': [
          ['urgente', 'inventario', 'web', 'contabilidad', 'mantenimiento'][i]
        ],
        'historial': [],
        'es_prueba': true,
      });
    }

    // ── 10 Pedidos WhatsApp ──────────────────────────────────────────
    final estadosPedido = ['nuevo', 'en_proceso', 'listo', 'entregado'];
    final productosPedido = [
      'Menú del día', 'Hamburguesa completa', 'Ensalada César',
      'Pizza Margarita', 'Sándwich Club', 'Wrap de pollo',
      'Plato combinado', 'Sopa del día', 'Tortilla española', 'Croquetas caseras',
    ];
    for (int i = 0; i < 10; i++) {
      final precio = (8.0 + _random.nextInt(20)).toDouble();
      await ref.collection('pedidos_whatsapp').add({
        'cliente_nombre': clientes[i]['nombre'],
        'cliente_telefono': clientes[i]['telefono'],
        'productos': [
          {
            'nombre': productosPedido[i],
            'cantidad': 1 + _random.nextInt(3),
            'precio': precio,
          }
        ],
        'total': precio * (1 + _random.nextInt(3)),
        'estado': estadosPedido[i % 4],
        'notas': i % 3 == 0 ? 'Sin gluten por favor' : '',
        'fecha_creacion': Timestamp.fromDate(now.subtract(Duration(hours: i * 2))),
        'es_prueba': true,
      });
    }

    // ── Datos fiscales del trimestre actual ──────────────────────────
    final trimestre = ((now.month - 1) ~/ 3) + 1;
    await ref.collection('fiscal').doc('trimestre_${trimestre}_${now.year}').set({
      'trimestre': trimestre,
      'anio': now.year,
      'total_ingresos': 12500.0 + _random.nextInt(5000),
      'total_gastos': 8000.0 + _random.nextInt(3000),
      'iva_repercutido': 2625.0,
      'iva_soportado': 1680.0,
      'resultado_iva': 945.0,
      'irpf_retenido': 1875.0,
      'fecha_calculo': Timestamp.fromDate(now),
      'es_prueba': true,
    }, SetOptions(merge: true));
  }

  /// Genera nóminas con datos aleatorios para la cuenta demo.
  /// Útil cuando no hay empleados configurados o para mostrar el módulo funcional.
  Future<int> generarNominasDemoAleatorias(
      String empresaId, int mes, int anio) async {
    final ref = _db.collection('empresas').doc(empresaId);
    final now = DateTime.now();

    final empleadosDemo = [
      {
        'id': 'demo_emp_001',
        'nombre': 'Elena Martín Sanz',
        'bruto': 1425.0,
        'categoria': 'Oficial de 1ª',
        'contrato': 'Indefinido',
      },
      {
        'id': 'demo_emp_002',
        'nombre': 'Roberto López Vega',
        'bruto': 1250.0,
        'categoria': 'Oficial de 2ª',
        'contrato': 'Indefinido',
      },
      {
        'id': 'demo_emp_003',
        'nombre': 'Sofía García Ruiz',
        'bruto': 1100.0 + (_random.nextDouble() * 200).roundToDouble(),
        'categoria': 'Auxiliar',
        'contrato': 'Jornada parcial',
      },
    ];

    int generadas = 0;
    for (final emp in empleadosDemo) {
      final bruto = emp['bruto'] as double;
      final irpf = bruto * 0.08;  // 8% más realista

      // Comprobar si ya existe para este mes/año/empleado
      final existing = await ref.collection('nominas')
          .where('empleado_id', isEqualTo: emp['id'])
          .where('mes', isEqualTo: mes)
          .where('anio', isEqualTo: anio)
          .get();
      if (existing.docs.isNotEmpty) continue;

      // Desglose SS trabajador (tipos 2026)
      final ssTraCC     = double.parse((bruto * 4.70 / 100).toStringAsFixed(2));
      final ssTraDesemp = double.parse((bruto * 1.55 / 100).toStringAsFixed(2));
      final ssTraFP     = double.parse((bruto * 0.10 / 100).toStringAsFixed(2));
      final ssMeiTra    = double.parse((bruto * 0.15 / 100).toStringAsFixed(2));
      // Desglose SS empresa (tipos 2026)
      final ssEmpCC     = double.parse((bruto * 23.60 / 100).toStringAsFixed(2));
      final ssEmpDesemp = double.parse((bruto *  5.50 / 100).toStringAsFixed(2));
      final ssEmpFog    = double.parse((bruto *  0.20 / 100).toStringAsFixed(2));
      final ssEmpFP_    = double.parse((bruto *  0.60 / 100).toStringAsFixed(2));
      final ssEmpAT_    = double.parse((bruto *  1.50 / 100).toStringAsFixed(2));
      final ssMeiEmp    = double.parse((bruto *  0.75 / 100).toStringAsFixed(2));
      final irpfRet     = double.parse(irpf.toStringAsFixed(2));

      await ref.collection('nominas').add({
        // ── Identificación ────────────────────────────────────────────────
        'empresa_id':       empresaId,
        'empleado_id':      emp['id'],
        'empleado_nombre':  emp['nombre'],
        'mes':              mes,
        'anio':             anio,
        'periodo':          '${Nomina.nombreMes(mes)} $anio',
        // ── Devengos ──────────────────────────────────────────────────────
        'salario_bruto_mensual': bruto,
        'paga_extra':            0.0,
        'horas_extra':           0.0,
        'precio_hora_extra':     0.0,
        'importe_horas_extra':   0.0,
        'complementos':          0.0,
        'paga_extra_prorrateada':0.0,
        'retribuciones_especie': 0.0,
        // ── SS Trabajador ─────────────────────────────────────────────────
        'base_cotizacion':           bruto,
        'ss_trabajador_cc':          ssTraCC,
        'ss_trabajador_desempleo':   ssTraDesemp,
        'ss_trabajador_fp':          ssTraFP,
        'ss_mei_trabajador':         ssMeiTra,
        'ss_solidaridad_trabajador': 0.0,
        'ss_horas_extra_trabajador': 0.0,
        // ── IRPF ──────────────────────────────────────────────────────────
        'base_irpf':        bruto,
        'porcentaje_irpf':  8.0,
        'retencion_irpf':   irpfRet,
        'irpf_ajustado':    false,
        // ── SS Empresa ────────────────────────────────────────────────────
        'ss_empresa_cc':          ssEmpCC,
        'ss_empresa_desempleo':   ssEmpDesemp,
        'ss_empresa_fogasa':      ssEmpFog,
        'ss_empresa_fp':          ssEmpFP_,
        'ss_empresa_at':          ssEmpAT_,
        'ss_mei_empresa':         ssMeiEmp,
        'ss_solidaridad_empresa': 0.0,
        'ss_horas_extra_empresa': 0.0,
        'tipo_hora_extra':        'noEstructural',
        // ── Otros ─────────────────────────────────────────────────────────
        'descuento_ausencias':    0.0,
        'lineas_ausencias':       [],
        'plus_antiguedad':        0.0,
        'anios_antiguedad':       0,
        'trienios_bienios':       0,
        'embargo_judicial':       0.0,
        'regularizacion_irpf':    0.0,
        'complementos_detallados': [],
        'dias_it':                0,
        'importe_it':             0.0,
        'importe_it_empresa':     0.0,
        'importe_it_inss':        0.0,
        'importe_it_mutua':       0.0,
        'descuento_salario_por_it': 0.0,
        // ── Estado ────────────────────────────────────────────────────────
        'estado':           'borrador',
        'fecha_creacion':   Timestamp.fromDate(now),
        // ── Metadatos demo ────────────────────────────────────────────────
        'es_prueba':        true,
        'es_demo':          true,
        'categoria':        emp['categoria'],
        'tipo_contrato':    emp['contrato'],
      });
      generadas++;
    }
    return generadas;
  }

  /// Elimina todos los datos de prueba generados por la demo.
  Future<void> limpiarDatosPrueba(String empresaId) async {
    final ref = _db.collection('empresas').doc(empresaId);
    final colecciones = [
      'clientes', 'reservas', 'facturas', 'empleados',
      'nominas', 'tareas', 'pedidos_whatsapp',
    ];

    for (final col in colecciones) {
      try {
        final snap = await ref.collection(col)
            .where('es_prueba', isEqualTo: true)
            .get();
        if (snap.docs.isEmpty) continue;
        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (_) {}
    }

    // Limpiar fiscal demo
    try {
      final fiscalSnap = await ref.collection('fiscal')
          .where('es_prueba', isEqualTo: true)
          .get();
      final batch = _db.batch();
      for (final doc in fiscalSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERAR DATOS COMPLETOS DEMO (con limpieza y estructura mejorada)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Genera datos demo completos con:
  /// - Limpieza automática de datos anteriores
  /// - 3 empleados con IBANs válidos y convenios diferentes
  /// - 15 nóminas (5 meses × 3 empleados)
  /// - 3 clientes con historial
  /// - 3 servicios
  /// - 5 reservas futuras
  Future<void> generarDatosCompletosDemo(String empresaId) async {
    debugPrint('🌱 Iniciando generación de datos demo completos...');

    // 1. LIMPIAR DATOS ANTERIORES
    await _limpiarDatosDemo(empresaId);

    // 2. CREAR EMPLEADOS
    final empleadosIds = await _crearEmpleadosDemo(empresaId);

    // 3. CREAR NÓMINAS
    await _crearNominasDemo(empresaId, empleadosIds);

    // 4. CREAR CLIENTES
    await _crearClientesDemo(empresaId);

    // 5. CREAR SERVICIOS
    final serviciosIds = await _crearServiciosDemo(empresaId);

    // 6. CREAR RESERVAS
    await _crearReservasDemo(empresaId, serviciosIds);

    debugPrint('✅ Datos demo completos generados exitosamente');
  }

  /// Limpia datos demo anteriores (incluye es_demo y es_prueba)
  Future<void> _limpiarDatosDemo(String empresaId) async {
    debugPrint('🧹 Limpiando datos demo y de prueba anteriores...');

    final ref = _db.collection('empresas').doc(empresaId);

    // Limpiar empleados (es_demo O es_prueba)
    var snap = await ref.collection('empleados').where('es_demo', isEqualTo: true).get();
    for (final doc in snap.docs) { await doc.reference.delete(); }
    snap = await ref.collection('empleados').where('es_prueba', isEqualTo: true).get();
    for (final doc in snap.docs) { await doc.reference.delete(); }

    // Limpiar nóminas
    snap = await ref.collection('nominas').where('es_demo', isEqualTo: true).get();
    for (final doc in snap.docs) { await doc.reference.delete(); }
    snap = await ref.collection('nominas').where('es_prueba', isEqualTo: true).get();
    for (final doc in snap.docs) { await doc.reference.delete(); }

    // Limpiar clientes
    snap = await ref.collection('clientes').where('es_demo', isEqualTo: true).get();
    for (final doc in snap.docs) { await doc.reference.delete(); }
    snap = await ref.collection('clientes').where('es_prueba', isEqualTo: true).get();
    for (final doc in snap.docs) { await doc.reference.delete(); }

    // Limpiar servicios
    snap = await ref.collection('servicios').where('es_demo', isEqualTo: true).get();
    for (final doc in snap.docs) { await doc.reference.delete(); }
    snap = await ref.collection('servicios').where('es_prueba', isEqualTo: true).get();
    for (final doc in snap.docs) { await doc.reference.delete(); }

    // Limpiar reservas
    snap = await ref.collection('reservas').where('origen', isEqualTo: 'demo').get();
    for (final doc in snap.docs) { await doc.reference.delete(); }
    snap = await ref.collection('reservas').where('es_prueba', isEqualTo: true).get();
    for (final doc in snap.docs) { await doc.reference.delete(); }

    debugPrint('✅ Datos anteriores eliminados (demo + prueba)');
  }

  /// Crea 3 empleados demo con IBANs válidos y convenios diferentes
  Future<List<String>> _crearEmpleadosDemo(String empresaId) async {
    debugPrint('👥 Creando empleados demo...');

    final now = DateTime.now();
    final empleadosIds = <String>[];

    final empleados = [
      {
        'nombre': 'María García López',
        'email': 'maria.garcia@demo.fluix.com',
        'telefono': '+34 612 345 678',
        'cargo': 'Encargada de Salón',
        'salario_bruto_anual': 24000.0,
        'nif': '12345678A',
        'nss': '281234567890',
        'cuenta_bancaria': 'ES9121000418450200051332',
        'convenio': 'hosteleria',
        'categoria_convenio': 'grupo5',
        'grupo_cotizacion': 'grupo5',
        'fecha_alta': now.subtract(const Duration(days: 365)),
      },
      {
        'nombre': 'Carlos López Martínez',
        'email': 'carlos.lopez@demo.fluix.com',
        'telefono': '+34 623 456 789',
        'cargo': 'Camarero',
        'salario_bruto_anual': 18000.0,
        'nif': '23456789B',
        'nss': '282345678901',
        'cuenta_bancaria': 'ES7921000813610123456789',
        'convenio': 'hosteleria',
        'categoria_convenio': 'grupo7',
        'grupo_cotizacion': 'grupo7',
        'fecha_alta': now.subtract(const Duration(days: 180)),
      },
      {
        'nombre': 'Ana Martínez Ruiz',
        'email': 'ana.martinez@demo.fluix.com',
        'telefono': '+34 634 567 890',
        'cargo': 'Ayudante de Cocina',
        'salario_bruto_anual': 16800.0,
        'nif': '34567890C',
        'nss': '283456789012',
        'cuenta_bancaria': 'ES1720852066623456789011',
        'convenio': 'hosteleria',
        'categoria_convenio': 'grupo8',
        'grupo_cotizacion': 'grupo8',
        'fecha_alta': now.subtract(const Duration(days: 90)),
      },
    ];

    for (final emp in empleados) {
      final docRef = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('empleados')
          .add({
        'nombre': emp['nombre'],
        'email': emp['email'],
        'telefono': emp['telefono'],
        'cargo': emp['cargo'],
        'activo': true,
        'es_demo': true,
        'fecha_alta': Timestamp.fromDate(emp['fecha_alta'] as DateTime),
        'fecha_creacion': Timestamp.fromDate(now),
        'nif': emp['nif'],
        'nss': emp['nss'],
        'salario_bruto_anual': emp['salario_bruto_anual'],
        'convenio': emp['convenio'],
        'categoria_convenio_id': emp['categoria_convenio'],
        'grupo_cotizacion': emp['grupo_cotizacion'],
        'horas_semanales': 40.0,
        'datos_nomina': {
          'salario_bruto_anual': emp['salario_bruto_anual'],
          'grupo_cotizacion': emp['grupo_cotizacion'],
          'irpf_porcentaje': 8.0,
          'num_pagas': 14,
          'horas_semanales': 40.0,
          'categoria_convenio_id': emp['categoria_convenio'],
          'sector_empresa': emp['convenio'],
          'pagas_prorrateadas': true,
          'cuenta_bancaria': emp['cuenta_bancaria'],
          'nif': emp['nif'],
          'nss': emp['nss'],
          'estado_civil': 'soltero',
          'num_hijos': 0,
          'num_hijos_menores_3': 0,
          'tipo_contrato': 'indefinido',
        },
      });

      empleadosIds.add(docRef.id);
    }

    debugPrint('✅ ${empleados.length} empleados creados');
    return empleadosIds;
  }

  /// Crea nóminas para los empleados (5 meses)
  Future<void> _crearNominasDemo(String empresaId, List<String> empleadosIds) async {
    debugPrint('💰 Creando nóminas demo...');

    if (empleadosIds.isEmpty) {
      debugPrint('⚠️ No hay empleados para generar nóminas');
      return;
    }

    final now = DateTime.now();
    final meses = [
      {'mes': 1, 'año': 2026, 'nombre': 'Enero'},
      {'mes': 2, 'año': 2026, 'nombre': 'Febrero'},
      {'mes': 3, 'año': 2026, 'nombre': 'Marzo'},
      {'mes': 4, 'año': 2026, 'nombre': 'Abril'},
      {'mes': 5, 'año': 2026, 'nombre': 'Mayo'},
    ];

    final salarios = [24000.0, 18000.0, 16800.0];
    int count = 0;

    for (int i = 0; i < empleadosIds.length; i++) {
      final empleadoId = empleadosIds[i];
      final salarioAnual = salarios[i];

      for (final periodo in meses) {
        final salarioBrutoMensual = salarioAnual / 14;
        final irpf = salarioBrutoMensual * 0.08;  // 8% más realista
        final ssEmpleado = salarioBrutoMensual * 0.0635;
        final ssEmpresa = salarioBrutoMensual * 0.30;
        final salarioNeto = salarioBrutoMensual - irpf - ssEmpleado;

        await _db
            .collection('empresas')
            .doc(empresaId)
            .collection('nominas')
            .add({
          'empleado_id': empleadoId,
          'empleado_nombre': ['María García López', 'Carlos López Martínez', 'Ana Martínez Ruiz'][i],
          'empleado_nif': ['12345678A', '23456789B', '34567890C'][i],
          'mes': periodo['mes'],
          'año': periodo['año'],
          'periodo': '${periodo['nombre']} ${periodo['año']}',
          'salario_bruto': double.parse(salarioBrutoMensual.toStringAsFixed(2)),
          'salario_neto': double.parse(salarioNeto.toStringAsFixed(2)),
          'irpf': double.parse(irpf.toStringAsFixed(2)),
          'ss_empleado': double.parse(ssEmpleado.toStringAsFixed(2)),
          'ss_empresa': double.parse(ssEmpresa.toStringAsFixed(2)),
          'estado': 'generada',
          'fecha_generacion': Timestamp.fromDate(now),
          'es_demo': true,
          'convenio': 'hosteleria',
          'categoria_convenio_id': ['grupo5', 'grupo7', 'grupo8'][i],
          'grupo_cotizacion': ['grupo5', 'grupo7', 'grupo8'][i],
          'horas_trabajadas': 160.0,
          'dias_trabajados': 22,
        });

        count++;
      }
    }

    debugPrint('✅ $count nóminas creadas (${empleadosIds.length} empleados × 5 meses)');
  }

  /// Crea 3 clientes demo
  Future<void> _crearClientesDemo(String empresaId) async {
    debugPrint('👤 Creando clientes demo...');

    final now = DateTime.now();
    final clientes = [
      {
        'nombre': 'Pedro Sánchez',
        'telefono': '+34 645 123 456',
        'email': 'pedro.sanchez@email.com',
        'total_gastado': 250.50,
        'numero_reservas': 5,
        'notas': 'Cliente habitual, prefiere mesa junto a ventana',
      },
      {
        'nombre': 'Laura González',
        'telefono': '+34 656 234 567',
        'email': 'laura.gonzalez@email.com',
        'total_gastado': 180.00,
        'numero_reservas': 3,
        'notas': 'Alérgica al gluten',
      },
      {
        'nombre': 'Roberto Fernández',
        'telefono': '+34 667 345 678',
        'email': 'roberto.fernandez@email.com',
        'total_gastado': 420.75,
        'numero_reservas': 8,
        'notas': 'Cliente VIP, pide siempre vino de la casa',
      },
    ];

    for (final cliente in clientes) {
      await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('clientes')
          .add({
        ...cliente,
        'activo': true,
        'es_demo': true,
        'fecha_creacion': Timestamp.fromDate(now),
        'fecha_registro': Timestamp.fromDate(now.subtract(Duration(days: _random.nextInt(180)))),
        'ultima_visita': Timestamp.fromDate(now.subtract(Duration(days: _random.nextInt(30)))),
      });
    }

    debugPrint('✅ ${clientes.length} clientes creados');
  }

  /// Crea 3 servicios demo
  Future<List<String>> _crearServiciosDemo(String empresaId) async {
    debugPrint('🍽️ Creando servicios demo...');

    final now = DateTime.now();
    final serviciosIds = <String>[];
    final servicios = [
      {
        'nombre': 'Menú del Día',
        'descripcion': 'Primer plato, segundo plato, postre y bebida',
        'precio': 12.50,
        'duracion_minutos': 60,
        'categoria': 'Restaurante',
      },
      {
        'nombre': 'Menú Degustación',
        'descripcion': 'Menú especial de 5 platos con maridaje',
        'precio': 45.00,
        'duracion_minutos': 120,
        'categoria': 'Restaurante',
      },
      {
        'nombre': 'Reserva Sala Privada',
        'descripcion': 'Sala privada para eventos (hasta 20 personas)',
        'precio': 150.00,
        'duracion_minutos': 180,
        'categoria': 'Eventos',
      },
    ];

    for (final servicio in servicios) {
      final docRef = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('servicios')
          .add({
        ...servicio,
        'activo': true,
        'es_demo': true,
        'fecha_creacion': Timestamp.fromDate(now),
      });

      serviciosIds.add(docRef.id);
    }

    debugPrint('✅ ${servicios.length} servicios creados');
    return serviciosIds;
  }

  /// Crea 5 reservas futuras
  Future<void> _crearReservasDemo(String empresaId, List<String> serviciosIds) async {
    debugPrint('📅 Creando reservas demo...');

    if (serviciosIds.isEmpty) {
      debugPrint('⚠️ No hay servicios para crear reservas');
      return;
    }

    final now = DateTime.now();
    final clientes = ['Pedro Sánchez', 'Laura González', 'Roberto Fernández'];
    final telefonos = ['+34 645 123 456', '+34 656 234 567', '+34 667 345 678'];
    final precios = [12.50, 45.00, 150.00];

    final reservas = [
      {'dias': 2,  'estado': 'PENDIENTE', 'servicio_idx': 0, 'cliente_idx': 0},
      {'dias': 5,  'estado': 'PENDIENTE', 'servicio_idx': 1, 'cliente_idx': 1},
      {'dias': 7,  'estado': 'PENDIENTE', 'servicio_idx': 0, 'cliente_idx': 0},
      {'dias': 10, 'estado': 'PENDIENTE', 'servicio_idx': 2, 'cliente_idx': 2},
      {'dias': 15, 'estado': 'PENDIENTE', 'servicio_idx': 1, 'cliente_idx': 1},
    ];

    for (final reserva in reservas) {
      final dias = reserva['dias'] as int;
      final fechaReserva = now.add(Duration(days: dias));
      final fechaConHora = DateTime(
        fechaReserva.year,
        fechaReserva.month,
        fechaReserva.day,
        13 + _random.nextInt(8),
        _random.nextBool() ? 0 : 30,
      );

      final servicioIdx = reserva['servicio_idx'] as int;
      final clienteIdx = reserva['cliente_idx'] as int;

      await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .add({
        'nombre_cliente': clientes[clienteIdx],
        'telefono_cliente': telefonos[clienteIdx],
        'servicio': ['Menú del Día', 'Menú Degustación', 'Reserva Sala Privada'][servicioIdx],
        'servicio_id': serviciosIds[servicioIdx],
        'precio': precios[servicioIdx],
        'fecha': Timestamp.fromDate(fechaConHora),
        'fecha_hora': Timestamp.fromDate(fechaConHora),
        'estado': reserva['estado'],
        'origen': 'demo',
        'notas': 'Reserva de prueba generada automáticamente',
        'fecha_creacion': Timestamp.fromDate(now),
      });
    }

    debugPrint('✅ ${reservas.length} reservas creadas');
  }
}
