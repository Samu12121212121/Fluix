import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

const String _fluixtechId = 'ztZblwm1w71wNQtzHV7S';

/// Inicializa TODOS los datos de la empresa Fluixtech en Firestore.
/// Es idempotente: usa set con merge y solo crea colecciones vacías si no existen.
Future<void> inicializarEmpresaFluixtech() async {
  final db  = FirebaseFirestore.instance;
  final ref = db.collection('empresas').doc(_fluixtechId);
  final now = DateTime.now();
  const dominio = 'fluixtech.com';

  debugPrint('🚀 Inicializando Fluixtech completo...');

  // ── 1. Documento raíz ────────────────────────────────────────────────────
  await ref.set({
    'nombre':                'Fluix CRM',
    'correo':                'admin@fluixtech.com',
    'telefono':              '+34 900 123 456',
    'direccion':             '',
    'descripcion':           'Plataforma de gestión empresarial',
    'sitio_web':             'fluixtech.com',
    'dominio':               'fluixtech.com',
    'categoria':             'Tecnología',
    'onboarding_completado': true,
    'activa':                true,
    'fecha_creacion':        Timestamp.fromDate(now),
  }, SetOptions(merge: true));

  // ── 2. Módulos activos ───────────────────────────────────────────────────
  await ref.collection('configuracion').doc('modulos').set({
    'modulos': [
      {'id': 'dashboard',    'activo': true},
      {'id': 'valoraciones', 'activo': true},
      {'id': 'estadisticas', 'activo': true},
      {'id': 'reservas',     'activo': true},
      {'id': 'citas',        'activo': false},
      {'id': 'web',          'activo': true},
      {'id': 'whatsapp',     'activo': true},
      {'id': 'facturacion',  'activo': true},
      {'id': 'pedidos',      'activo': true},
      {'id': 'tareas',       'activo': true},
      {'id': 'clientes',     'activo': true},
      {'id': 'empleados',    'activo': true},
      {'id': 'servicios',    'activo': true},
      {'id': 'nominas',      'activo': true},
    ],
    'ultima_actualizacion': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  // ── 3. Suscripción ───────────────────────────────────────────────────────
  await ref.collection('suscripcion').doc('actual').set({
    'estado':        'ACTIVA',
    'plan':          'enterprise',
    'fecha_inicio':  Timestamp.fromDate(now),
    'fecha_fin':     Timestamp.fromDate(now.add(const Duration(days: 3650))),
    'aviso_enviado': false,
    'ultimo_aviso':  null,
  }, SetOptions(merge: true));

  // ── 4. Contador de facturas ──────────────────────────────────────────────
  await ref.collection('configuracion').doc('facturacion').set({
    'ultimo_numero_factura': 0,
    'anio_ultimo_factura': now.year,
    'ultimo_numero_SerieFactura.normal': 0,
    'anio_ultimo_SerieFactura.normal': now.year,
  }, SetOptions(merge: true));

  // ── 4.b Configuración fiscal (criterio IVA) ─────────────────────────────
  await ref.collection('configuracion').doc('fiscal').set(
    {
      'criterio_iva': 'devengo',
    },
    SetOptions(merge: true),
  );

  // ── 5. Configuración general / script web ────────────────────────────────
  await ref.collection('configuracion').doc('general').set({
    'fecha_instalacion_script': null,
    'script_activo':            false,
    'dominio':                  dominio,
    'modulos_activos': {
      'estadisticas':      true,
      'eventos':           true,
      'contenido_dinamico': true,
    },
  }, SetOptions(merge: true));

  // ── 6. Estadísticas base ─────────────────────────────────────────────────
  await ref.collection('estadisticas').doc('resumen').set({
    'fecha_calculo':        now.toIso8601String(),
    'ultima_actualizacion': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  await ref.collection('estadisticas').doc('web_resumen').set({
    'visitas_totales':            0,
    'visitas_mes':                0,
    'ultima_visita':              null,
    'sitio_web':                  dominio,
    'nombre_empresa':             'Fluixtech',
    'total_valoraciones':         0,
    'valoracion_promedio':        0.0,
    'fecha_inicio_estadisticas':  FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  // ── 7. Servicios de ejemplo ──────────────────────────────────────────────
  final serviciosSnap = await ref.collection('servicios').limit(1).get();
  if (serviciosSnap.docs.isEmpty) {
    final servicios = [
      {'nombre': 'Desarrollo Web',        'precio': 1500.0, 'duracion': 480, 'activo': true, 'categoria': 'Desarrollo',  'descripcion': 'Sitio web profesional a medida'},
      {'nombre': 'App Móvil Flutter',     'precio': 3000.0, 'duracion': 960, 'activo': true, 'categoria': 'Desarrollo',  'descripcion': 'App iOS y Android con Flutter'},
      {'nombre': 'Consultoría Digital',   'precio': 150.0,  'duracion': 60,  'activo': true, 'categoria': 'Consultoría', 'descripcion': 'Sesión de consultoría estratégica'},
      {'nombre': 'Mantenimiento Web',     'precio': 200.0,  'duracion': 120, 'activo': true, 'categoria': 'Soporte',     'descripcion': 'Mantenimiento mensual del sitio'},
      {'nombre': 'Integración Firebase',  'precio': 800.0,  'duracion': 240, 'activo': true, 'categoria': 'Desarrollo',  'descripcion': 'Integración con Firebase/Firestore'},
      {'nombre': 'SEO y Marketing',       'precio': 500.0,  'duracion': 120, 'activo': true, 'categoria': 'Marketing',   'descripcion': 'Posicionamiento y estrategia digital'},
    ];
    final batch = db.batch();
    for (final s in servicios) {
      batch.set(ref.collection('servicios').doc(), {
        ...s,
        'empresa_id':        _fluixtechId,
        'empleado_asignado': null,
        'fecha_creacion':    Timestamp.fromDate(now),
      });
    }
    await batch.commit();
    debugPrint('✅ Servicios creados');
  }

  // ── 8. Empleados ─────────────────────────────────────────────────────────
  final empleadosSnap = await ref.collection('empleados').limit(1).get();
  if (empleadosSnap.docs.isEmpty) {
    final empleados = [
      {'nombre': 'Samuel (Propietario)', 'rol': 'propietario', 'activo': true, 'permisos': ['todo']},
      {'nombre': 'Desarrollador Senior', 'rol': 'admin',        'activo': true, 'permisos': ['reservas', 'clientes', 'pedidos']},
      {'nombre': 'Soporte Técnico',      'rol': 'staff',        'activo': true, 'permisos': ['reservas', 'clientes']},
    ];
    final batch = db.batch();
    for (final e in empleados) {
      batch.set(ref.collection('empleados').doc(), {...e, 'uid': null});
    }
    await batch.commit();
    debugPrint('✅ Empleados creados');
  }

  // ── 9. Clientes ──────────────────────────────────────────────────────────
  final clientesSnap = await ref.collection('clientes').limit(1).get();
  if (clientesSnap.docs.isEmpty) {
    final clientes = [
      {
        'nombre': 'Empresa Ejemplo SL',
        'telefono': '+34 600 111 222',
        'correo': 'contacto@ejemplo.com',
        'total_gastado': 4500.0,
        'ultima_visita': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
        'numero_reservas': 5,
        'etiquetas': ['VIP', 'Recurrente'],
        'notas': 'Cliente premium, proyecto web en curso',
        'fecha_registro': Timestamp.fromDate(now.subtract(const Duration(days: 90))),
      },
      {
        'nombre': 'StartUp Digital',
        'telefono': '+34 600 333 444',
        'correo': 'info@startupdigital.com',
        'total_gastado': 3000.0,
        'ultima_visita': Timestamp.fromDate(now.subtract(const Duration(days: 7))),
        'numero_reservas': 3,
        'etiquetas': ['Nuevo'],
        'notas': 'App móvil en desarrollo',
        'fecha_registro': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
      },
      {
        'nombre': 'Comercio Local',
        'telefono': '+34 600 555 666',
        'correo': 'tienda@comerciolocal.es',
        'total_gastado': 700.0,
        'ultima_visita': Timestamp.fromDate(now.subtract(const Duration(days: 15))),
        'numero_reservas': 2,
        'etiquetas': ['Regular'],
        'notas': 'Tienda online + SEO',
        'fecha_registro': Timestamp.fromDate(now.subtract(const Duration(days: 45))),
      },
    ];
    final batch = db.batch();
    for (final c in clientes) {
      batch.set(ref.collection('clientes').doc(), c);
    }
    await batch.commit();
    debugPrint('✅ Clientes creados');
  }

  // ── 10. Reservas ─────────────────────────────────────────────────────────
  final reservasSnap = await ref.collection('reservas').limit(1).get();
  if (reservasSnap.docs.isEmpty) {
    final reservas = [
      {'cliente': 'Empresa Ejemplo SL',  'servicio': 'Consultoría Digital',  'estado': 'PENDIENTE',  'fecha': Timestamp.fromDate(now.add(const Duration(hours: 24))),  'hora_inicio': '10:00', 'notas': 'Revisión de proyecto web'},
      {'cliente': 'StartUp Digital',     'servicio': 'App Móvil Flutter',    'estado': 'CONFIRMADA', 'fecha': Timestamp.fromDate(now.add(const Duration(hours: 48))),  'hora_inicio': '11:00', 'notas': 'Sprint planning'},
      {'cliente': 'Comercio Local',      'servicio': 'SEO y Marketing',      'estado': 'PENDIENTE',  'fecha': Timestamp.fromDate(now.add(const Duration(hours: 72))),  'hora_inicio': '16:00', 'notas': null},
      {'cliente': 'Empresa Ejemplo SL',  'servicio': 'Mantenimiento Web',    'estado': 'COMPLETADA', 'fecha': Timestamp.fromDate(now.subtract(const Duration(days: 3))), 'hora_inicio': '09:00', 'notas': 'Actualización plugins'},
      {'cliente': 'StartUp Digital',     'servicio': 'Desarrollo Web',       'estado': 'COMPLETADA', 'fecha': Timestamp.fromDate(now.subtract(const Duration(days: 7))), 'hora_inicio': '10:00', 'notas': null},
    ];
    final batch = db.batch();
    for (final r in reservas) {
      batch.set(ref.collection('reservas').doc(), r);
    }
    await batch.commit();
    debugPrint('✅ Reservas creadas');
  }

  // ── 11. Valoraciones ─────────────────────────────────────────────────────
  final valoracionesSnap = await ref.collection('valoraciones').limit(1).get();
  if (valoracionesSnap.docs.isEmpty) {
    final valoraciones = [
      {'cliente': 'Empresa Ejemplo SL', 'calificacion': 5, 'comentario': 'Excelente trabajo, entrega puntual y gran calidad.',        'origen': 'google'},
      {'cliente': 'StartUp Digital',    'calificacion': 5, 'comentario': 'El mejor equipo de desarrollo con el que hemos trabajado.', 'origen': 'google'},
      {'cliente': 'Comercio Local',     'calificacion': 4, 'comentario': 'Muy profesionales y atentos.',                              'origen': 'app'},
      {'cliente': 'Cliente Anónimo',    'calificacion': 5, 'comentario': 'Superaron nuestras expectativas.',                          'origen': 'google'},
      {'cliente': 'Tech Solutions',     'calificacion': 5, 'comentario': 'Increíble dominio de Flutter y Firebase.',                  'origen': 'google'},
    ];
    final batch = db.batch();
    for (int i = 0; i < valoraciones.length; i++) {
      batch.set(ref.collection('valoraciones').doc(), {
        ...valoraciones[i],
        'fecha':   Timestamp.fromDate(now.subtract(Duration(days: i * 3))),
        'respuesta': null,
      });
    }
    await batch.commit();
    debugPrint('✅ Valoraciones creadas');
  }

  // ── 12. Secciones web ────────────────────────────────────────────────────
  final seccionesSnap = await ref.collection('secciones_web').limit(1).get();
  if (seccionesSnap.docs.isEmpty) {
    final secciones = [
      {'titulo': 'Nuestros Servicios',  'contenido': 'Desarrollo de apps móviles, webs y soluciones digitales a medida para tu negocio.',            'tipo': 'texto',  'activo': true, 'orden': 0},
      {'titulo': 'Oferta de Lanzamiento','contenido': '20% de descuento en tu primer proyecto digital. ¡Contacta con nosotros!',                     'tipo': 'oferta', 'activo': true, 'orden': 1},
      {'titulo': 'Sobre Fluixtech',     'contenido': 'Somos especialistas en Flutter, Firebase y tecnologías cloud. Creamos productos que escalan.', 'tipo': 'texto',  'activo': true, 'orden': 2},
    ];
    final batch = db.batch();
    for (final s in secciones) {
      batch.set(ref.collection('secciones_web').doc(), {
        ...s,
        'empresa_id':    _fluixtechId,
        'imagen_url':    null,
        'fecha_creacion': Timestamp.fromDate(now),
        'ultima_edicion': Timestamp.fromDate(now),
      });
    }
    await batch.commit();
    debugPrint('✅ Secciones web creadas');
  }

  // ── 13. Catálogo de productos (para el módulo de pedidos) ────────────────
  final catalogoSnap = await ref.collection('catalogo').limit(1).get();
  if (catalogoSnap.docs.isEmpty) {
    final productos = [
      {'nombre': 'Plan Starter Web',      'categoria': 'Planes',     'precio': 499.0,  'descripcion': 'Web corporativa hasta 5 páginas'},
      {'nombre': 'Plan Business Web',     'categoria': 'Planes',     'precio': 999.0,  'descripcion': 'Web avanzada con e-commerce'},
      {'nombre': 'App Básica Flutter',    'categoria': 'Apps',       'precio': 1500.0, 'descripcion': 'App móvil básica iOS + Android'},
      {'nombre': 'Consultoría 1h',        'categoria': 'Consultoría','precio': 120.0,  'descripcion': 'Sesión de 1 hora con experto'},
      {'nombre': 'Mantenimiento Mensual', 'categoria': 'Soporte',    'precio': 199.0,  'descripcion': 'Soporte y mantenimiento mensual'},
    ];
    final batch = db.batch();
    for (final p in productos) {
      batch.set(ref.collection('catalogo').doc(), {
        ...p,
        'empresa_id':          _fluixtechId,
        'activo':              true,
        'destacado':           false,
        'stock':               null,
        'imagen_url':          null,
        'variantes':           [],
        'etiquetas':           [],
        'fecha_creacion':      Timestamp.fromDate(now),
        'fecha_actualizacion': null,
      });
    }
    await batch.commit();
    debugPrint('✅ Catálogo de productos creado');
  }

  debugPrint('🎉 ¡Fluixtech inicializada completamente!');
  debugPrint('📍 ID: $_fluixtechId  |  Dominio: $dominio');
}
