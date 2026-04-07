import 'package:cloud_firestore/cloud_firestore.dart';

class DatosPruebaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Crear datos de prueba completos para una empresa
  Future<void> crearDatosPrueba(String empresaId) async {
    try {
      print('🎯 Creando datos de prueba para empresa: $empresaId');

      // Crear servicios de ejemplo
      await _crearServicios(empresaId);

      // Crear clientes de ejemplo
      await _crearClientes(empresaId);

      // Crear empleados de ejemplo
      await _crearEmpleados(empresaId);

      // Crear reservas de ejemplo
      await _crearReservas(empresaId);

      // Crear transacciones de ejemplo
      await _crearTransacciones(empresaId);

      // Crear valoraciones de ejemplo
      await _crearValoraciones(empresaId);

      print('✅ Datos de prueba creados correctamente');
    } catch (e) {
      print('❌ Error creando datos de prueba: $e');
      rethrow;
    }
  }

  /// Crear servicios de ejemplo específicos para Dama Juana Guadalajara
  Future<void> _crearServicios(String empresaId) async {
    final servicios = [
      {
        'id': 'servicio_1',
        'nombre': 'Corte de Pelo',
        'descripcion': 'Corte profesional con estilizado',
        'precio': 28.0,
        'duracion': 45,
        'categoria': 'Peluquería',
        'activo': true,
        'empleado_asignado': 'empleado_1',
        'negocio': 'Dama Juana Guadalajara',
        'fecha_creacion': Timestamp.now(),
      },
      {
        'id': 'servicio_2',
        'nombre': 'Coloración Completa',
        'descripcion': 'Tinte y mechas con productos de alta calidad',
        'precio': 65.0,
        'duracion': 120,
        'categoria': 'Coloración',
        'activo': true,
        'empleado_asignado': 'empleado_2',
        'negocio': 'Dama Juana Guadalajara',
        'fecha_creacion': Timestamp.now(),
      },
      {
        'id': 'servicio_3',
        'nombre': 'Tratamiento Capilar',
        'descripcion': 'Mascarilla nutritiva y reparadora',
        'precio': 45.0,
        'duracion': 60,
        'categoria': 'Tratamientos',
        'activo': true,
        'empleado_asignado': 'empleado_2',
        'negocio': 'Dama Juana Guadalajara',
        'fecha_creacion': Timestamp.now(),
      },
      {
        'id': 'servicio_4',
        'nombre': 'Peinado para Evento',
        'descripcion': 'Peinado profesional para ocasiones especiales',
        'precio': 55.0,
        'duracion': 75,
        'categoria': 'Peinados',
        'activo': true,
        'empleado_asignado': 'empleado_3',
        'negocio': 'Dama Juana Guadalajara',
        'fecha_creacion': Timestamp.now(),
      },
      {
        'id': 'servicio_5',
        'nombre': 'Tratamiento Facial',
        'descripcion': 'Limpieza facial profunda con hidratación',
        'precio': 50.0,
        'duracion': 60,
        'categoria': 'Estética',
        'activo': true,
        'empleado_asignado': 'empleado_3',
        'negocio': 'Dama Juana Guadalajara',
        'fecha_creacion': Timestamp.now(),
      },
    ];

    final batch = _firestore.batch();
    for (final servicio in servicios) {
      final docRef = _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('servicios')
          .doc(servicio['id'] as String);
      batch.set(docRef, servicio);
    }
    await batch.commit();
    print('✅ Servicios de prueba creados');
  }

  /// Crear clientes de ejemplo específicos para Dama Juana Guadalajara
  Future<void> _crearClientes(String empresaId) async {
    final clientes = [
      {
        'id': 'cliente_1',
        'nombre': 'María José García López',
        'telefono': '+34 949 123 456',
        'correo': 'mariajose.garcia@email.com',
        'fecha_registro': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 90))),
        'ultima_visita': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))),
        'numero_reservas': 12,
        'total_gastado': 680.0,
        'etiquetas': ['VIP', 'Cliente frecuente', 'Guadalajara'],
        'notas': 'Cliente fiel de Dama Juana, siempre puntual y muy satisfecha',
        'ciudad': 'Guadalajara',
        'negocio': 'Dama Juana Guadalajara',
      },
      {
        'id': 'cliente_2',
        'nombre': 'Carmen López Martínez',
        'telefono': '+34 949 234 567',
        'correo': 'carmen.lopez@email.com',
        'fecha_registro': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 60))),
        'ultima_visita': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7))),
        'numero_reservas': 8,
        'total_gastado': 520.0,
        'etiquetas': ['Cliente regular', 'Coloración'],
        'notas': 'Viene regularmente para coloración y tratamientos',
        'ciudad': 'Guadalajara',
        'negocio': 'Dama Juana Guadalajara',
      },
      {
        'id': 'cliente_3',
        'nombre': 'Ana Martínez Ruiz',
        'telefono': '+34 949 345 678',
        'correo': 'ana.martinez@email.com',
        'fecha_registro': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 45))),
        'ultima_visita': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2))),
        'numero_reservas': 15,
        'total_gastado': 875.0,
        'etiquetas': ['VIP', 'Cliente premium', 'Eventos'],
        'notas': 'Cliente que viene para eventos especiales y bodas',
        'ciudad': 'Guadalajara',
        'negocio': 'Dama Juana Guadalajara',
      },
      {
        'id': 'cliente_4',
        'nombre': 'Lucía Fernández Sánchez',
        'telefono': '+34 949 456 789',
        'correo': 'lucia.fernandez@email.com',
        'fecha_registro': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))),
        'ultima_visita': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 5))),
        'numero_reservas': 6,
        'total_gastado': 340.0,
        'etiquetas': ['Cliente nueva', 'Tratamientos faciales'],
        'notas': 'Interesada principalmente en tratamientos faciales',
        'ciudad': 'Guadalajara',
        'negocio': 'Dama Juana Guadalajara',
      },
      {
        'id': 'cliente_5',
        'nombre': 'Isabel González Jiménez',
        'telefono': '+34 949 567 890',
        'correo': 'isabel.gonzalez@email.com',
        'fecha_registro': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 75))),
        'ultima_visita': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 10))),
        'numero_reservas': 9,
        'total_gastado': 485.0,
        'etiquetas': ['Cliente frecuente', 'Cortes especiales'],
        'notas': 'Siempre busca estilos innovadores y modernos',
        'ciudad': 'Guadalajara',
        'negocio': 'Dama Juana Guadalajara',
      },
      {
        'id': 'cliente_6',
        'nombre': 'Pilar Rodríguez Castro',
        'telefono': '+34 949 678 901',
        'correo': 'pilar.rodriguez@email.com',
        'fecha_registro': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 20))),
        'ultima_visita': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
        'numero_reservas': 4,
        'total_gastado': 220.0,
        'etiquetas': ['Cliente nueva', 'Referida'],
        'notas': 'Vino recomendada por Carmen López',
        'ciudad': 'Guadalajara',
        'negocio': 'Dama Juana Guadalajara',
      },
    ];

    final batch = _firestore.batch();
    for (final cliente in clientes) {
      final docRef = _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('clientes')
          .doc(cliente['id'] as String);
      batch.set(docRef, cliente);
    }
    await batch.commit();
    print('✅ Clientes de prueba creados');
  }

  /// Crear empleados de ejemplo
  Future<void> _crearEmpleados(String empresaId) async {
    final empleados = [
      {
        'id': 'empleado_1',
        'nombre': 'Juan Pérez',
        'rol': 'ADMIN',
        'activo': true,
        'especialidad': 'Peluquería',
        'fecha_contratacion': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 365))),
        'permisos': ['gestionar_reservas', 'gestionar_clientes'],
      },
      {
        'id': 'empleado_2',
        'nombre': 'Laura Sánchez',
        'rol': 'STAFF',
        'activo': true,
        'especialidad': 'Estética',
        'fecha_contratacion': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 180))),
        'permisos': ['gestionar_reservas'],
      },
      {
        'id': 'empleado_3',
        'nombre': 'Carlos Mendoza',
        'rol': 'STAFF',
        'activo': true,
        'especialidad': 'Masajes',
        'fecha_contratacion': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 90))),
        'permisos': ['gestionar_reservas'],
      },
    ];

    final batch = _firestore.batch();
    for (final empleado in empleados) {
      final docRef = _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('empleados')
          .doc(empleado['id'] as String);
      batch.set(docRef, empleado);
    }
    await batch.commit();
    print('✅ Empleados de prueba creados');
  }

  /// Crear reservas de ejemplo con datos recientes y realistas
  Future<void> _crearReservas(String empresaId) async {
    final reservas = <Map<String, dynamic>>[];
    final serviciosIds = ['servicio_1', 'servicio_2', 'servicio_3', 'servicio_4', 'servicio_5'];
    final clientesIds = ['cliente_1', 'cliente_2', 'cliente_3', 'cliente_4', 'cliente_5', 'cliente_6'];
    final empleadosIds = ['empleado_1', 'empleado_2', 'empleado_3'];
    final estados = ['COMPLETADA', 'CONFIRMADA', 'PENDIENTE', 'CANCELADA'];
    final horas = ['09:00', '09:30', '10:00', '10:30', '11:00', '11:30', '12:00', '16:00', '16:30', '17:00', '17:30', '18:00', '18:30'];

    // Crear reservas para los últimos 45 días + próximos 15 días
    for (int dia = -15; dia < 30; dia++) {
      final fecha = DateTime.now().add(Duration(days: dia));

      // Solo días laborales (lunes a sábado) - Dama Juana cierra domingos
      if (fecha.weekday == DateTime.sunday) continue;

      // Más reservas en días recientes y futuros
      int numReservas;
      if (dia >= 0) {
        numReservas = 2 + (fecha.weekday == DateTime.friday || fecha.weekday == DateTime.saturday ? 3 : 1);
      } else if (dia > -7) {
        numReservas = 3 + (fecha.weekday == DateTime.friday ? 2 : 1);
      } else {
        numReservas = 2 + (dia.abs() % 3);
      }

      for (int i = 0; i < numReservas; i++) {
        final reservaId = 'reserva_demo_${dia}_$i';
        final servicioId = serviciosIds[i % serviciosIds.length];
        final clienteId = clientesIds[i % clientesIds.length];
        final empleadoId = empleadosIds[i % empleadosIds.length];
        final hora = horas[i % horas.length];

        // Estados más realistas según el día
        String estado;
        if (dia < -2) {
          estado = estados[i % 2 == 0 ? 0 : 1]; // COMPLETADA o CONFIRMADA (pasado)
        } else if (dia < 0) {
          estado = i % 4 == 3 ? 'CANCELADA' : 'COMPLETADA'; // Algunas canceladas recientes
        } else if (dia == 0) {
          estado = 'CONFIRMADA'; // Hoy confirmadas
        } else {
          estado = i % 6 == 5 ? 'PENDIENTE' : 'CONFIRMADA'; // Futuro: la mayoría confirmadas
        }

        // Precios según servicio
        final precios = {'servicio_1': 28.0, 'servicio_2': 65.0, 'servicio_3': 45.0, 'servicio_4': 55.0, 'servicio_5': 50.0};
        final precio = precios[servicioId] ?? 30.0;

        reservas.add({
          'id': reservaId,
          'cliente_id': clienteId,
          'servicio_id': servicioId,
          'empleado_asignado': empleadoId,
          'fecha': Timestamp.fromDate(fecha),
          'hora_inicio': hora,
          'estado': estado,
          'notas': i % 4 == 0 ? 'Cliente habitual de Dama Juana' : (i % 3 == 0 ? 'Primera visita' : ''),
          'fecha_creacion': Timestamp.fromDate(fecha.subtract(Duration(hours: (i + 1) * 2))),
          'precio': precio,
          'negocio': 'Dama Juana Guadalajara',
          'confirmada_por': estado == 'CONFIRMADA' ? 'Sistema' : null,
        });
      }
    }

    print('📅 Creando ${reservas.length} reservas para Dama Juana Guadalajara...');

    // Guardar en lotes
    final batchSize = 500;
    for (int i = 0; i < reservas.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize < reservas.length) ? i + batchSize : reservas.length;

      for (int j = i; j < end; j++) {
        final reserva = reservas[j];
        final docRef = _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('reservas')
            .doc(reserva['id'] as String);
        batch.set(docRef, reserva);
      }

      await batch.commit();
      print('✅ Lote ${(i / batchSize).floor() + 1} de reservas de Dama Juana creado');
    }

    print('✅ ${reservas.length} reservas de Dama Juana Guadalajara creadas');
  }

  /// Crear transacciones de ejemplo
  Future<void> _crearTransacciones(String empresaId) async {
    final transacciones = <Map<String, dynamic>>[];
    final clientesIds = ['cliente_1', 'cliente_2', 'cliente_3', 'cliente_4', 'cliente_5'];
    final metodosPago = ['Efectivo', 'Tarjeta', 'Bizum', 'Transferencia'];

    // Crear transacciones para los últimos 90 días
    for (int dia = 0; dia < 90; dia++) {
      final fecha = DateTime.now().subtract(Duration(days: dia));

      // Solo días laborales
      if (fecha.weekday == DateTime.sunday) continue;

      // 1-4 transacciones por día
      final numTransacciones = 1 + (dia % 4);

      for (int i = 0; i < numTransacciones; i++) {
        final transaccionId = 'transaccion_${dia}_$i';
        final clienteId = clientesIds[i % clientesIds.length];
        final metodoPago = metodosPago[i % metodosPago.length];
        final monto = 20.0 + (i * 25.0) + (dia * 2.0); // Monto variable

        transacciones.add({
          'id': transaccionId,
          'cliente_id': clienteId,
          'monto': monto,
          'metodo_pago': metodoPago,
          'fecha': Timestamp.fromDate(fecha),
          'concepto': 'Pago por servicios',
          'estado': 'completada',
        });
      }
    }

    // Guardar en lotes
    final batchSize = 500;
    for (int i = 0; i < transacciones.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize < transacciones.length) ? i + batchSize : transacciones.length;

      for (int j = i; j < end; j++) {
        final transaccion = transacciones[j];
        final docRef = _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('transacciones')
            .doc(transaccion['id'] as String);
        batch.set(docRef, transaccion);
      }

      await batch.commit();
    }

    print('✅ ${transacciones.length} transacciones de prueba creadas');
  }

  /// Crear valoraciones de ejemplo
  Future<void> _crearValoraciones(String empresaId) async {
    final valoraciones = [
      {
        'id': 'valoracion_1',
        'cliente': 'María García',
        'cliente_id': 'cliente_1',
        'calificacion': 5,
        'comentario': 'Excelente servicio, muy profesionales. Repetiré sin duda.',
        'fecha': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2))),
        'origen': 'google',
        'respondida': false,
      },
      {
        'id': 'valoracion_2',
        'cliente': 'Ana López',
        'cliente_id': 'cliente_2',
        'calificacion': 4,
        'comentario': 'Muy buena atención y resultado. Ambiente relajante.',
        'fecha': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 5))),
        'origen': 'google',
        'respondida': true,
      },
      {
        'id': 'valoracion_3',
        'cliente': 'Carmen Ruiz',
        'cliente_id': 'cliente_3',
        'calificacion': 5,
        'comentario': 'Increíble experiencia. Personal muy cualificado y atento.',
        'fecha': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 8))),
        'origen': 'google',
        'respondida': false,
      },
      {
        'id': 'valoracion_4',
        'cliente': 'Lucia Martín',
        'cliente_id': 'cliente_4',
        'calificacion': 4,
        'comentario': 'Buen servicio, aunque tuve que esperar un poco.',
        'fecha': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 12))),
        'origen': 'google',
        'respondida': true,
      },
      {
        'id': 'valoracion_5',
        'cliente': 'Sofia Hernández',
        'cliente_id': 'cliente_5',
        'calificacion': 5,
        'comentario': 'Fantástico como siempre. Mi centro de confianza.',
        'fecha': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 15))),
        'origen': 'google',
        'respondida': false,
      },
      {
        'id': 'valoracion_6',
        'cliente': 'Isabel Torres',
        'calificacion': 3,
        'comentario': 'Correcto, pero esperaba algo más por el precio.',
        'fecha': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 20))),
        'origen': 'google',
        'respondida': true,
      },
      {
        'id': 'valoracion_7',
        'cliente': 'Patricia Vega',
        'calificacion': 5,
        'comentario': 'Perfecto en todo. Instalaciones muy limpias.',
        'fecha': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 25))),
        'origen': 'google',
        'respondida': false,
      },
      {
        'id': 'valoracion_8',
        'cliente': 'Rosa Jiménez',
        'calificacion': 4,
        'comentario': 'Muy profesionales, buen trato al cliente.',
        'fecha': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))),
        'origen': 'google',
        'respondida': true,
      },
    ];

    final batch = _firestore.batch();
    for (final valoracion in valoraciones) {
      final docRef = _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones')
          .doc(valoracion['id'] as String);
      batch.set(docRef, valoracion);
    }
    await batch.commit();
    print('✅ Valoraciones de prueba creadas');
  }

  /// Verificar si ya existen datos de prueba
  Future<bool> tienenDatosPrueba(String empresaId) async {
    try {
      final reservasQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .limit(1)
          .get();

      return reservasQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Limpiar todos los datos de prueba
  Future<void> limpiarDatosPrueba(String empresaId) async {
    try {
      final colecciones = ['reservas', 'clientes', 'servicios', 'empleados', 'transacciones', 'valoraciones'];

      for (final coleccion in colecciones) {
        final query = await _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection(coleccion)
            .get();

        final batch = _firestore.batch();
        for (final doc in query.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      print('✅ Datos de prueba limpiados');
    } catch (e) {
      print('❌ Error limpiando datos de prueba: $e');
      rethrow;
    }
  }
}
