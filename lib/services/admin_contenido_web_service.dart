import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/seccion_web.dart';

/// Servicio para que el administrador (gestor web) cree y gestione secciones
/// El empresario NO tiene acceso a este servicio
class AdminContenidoWebService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Crear una nueva sección para una empresa específica
  /// SOLO el administrador puede usar este método
  Future<void> crearSeccionParaEmpresa(String empresaId, String seccionId, String nombre, String descripcion) async {
    try {
      final seccion = SeccionWeb(
        id: seccionId,
        nombre: nombre,
        descripcion: descripcion,
        activa: false, // Por defecto desactivada hasta que el empresario la configure
        contenido: ContenidoSeccion(
          titulo: 'Título pendiente de configurar',
          texto: 'Este contenido debe ser editado por el empresario.',
        ),
        fechaCreacion: DateTime.now(),
      );

      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('contenido_web')
          .doc(seccionId)
          .set(seccion.toMap());

      print('✅ Sección "${nombre}" creada para empresa $empresaId');
    } catch (e) {
      print('❌ Error creando sección: $e');
      rethrow;
    }
  }

  /// Eliminar una sección de una empresa
  /// SOLO el administrador puede usar este método
  Future<void> eliminarSeccionDeEmpresa(String empresaId, String seccionId) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('contenido_web')
          .doc(seccionId)
          .delete();

      print('✅ Sección eliminada de empresa $empresaId');
    } catch (e) {
      print('❌ Error eliminando sección: $e');
      rethrow;
    }
  }

  /// Obtener todas las empresas con sus secciones
  /// Para panel de administración
  Stream<List<Map<String, dynamic>>> obtenerResumenEmpresas() {
    return _firestore
        .collection('empresas')
        .snapshots()
        .asyncMap((empresasSnapshot) async {
      final empresas = <Map<String, dynamic>>[];

      for (final empresaDoc in empresasSnapshot.docs) {
        final empresaData = empresaDoc.data();

        // Obtener secciones de esta empresa
        final seccionesSnapshot = await _firestore
            .collection('empresas')
            .doc(empresaDoc.id)
            .collection('contenido_web')
            .get();

        empresas.add({
          'id': empresaDoc.id,
          'nombre': empresaData['nombre'] ?? 'Sin nombre',
          'sitio_web': empresaData['sitio_web'] ?? '',
          'total_secciones': seccionesSnapshot.docs.length,
          'secciones_activas': seccionesSnapshot.docs.where((doc) => doc.data()['activa'] == true).length,
          'ultima_actualizacion': empresaData['ultima_actualizacion'],
        });
      }

      return empresas;
    });
  }

  /// Plantillas predefinidas para diferentes tipos de negocio
  /// El administrador puede usar estas para crear secciones rápidamente
  List<Map<String, String>> obtenerPlantillasPorTipo(String tipoNegocio) {
    switch (tipoNegocio.toLowerCase()) {
      case 'restaurante':
        return [
          {
            'id': 'ofertas_del_dia',
            'nombre': 'Ofertas del Día',
            'descripcion': 'Platos especiales y promociones diarias'
          },
          {
            'id': 'carta_platos',
            'nombre': 'Nuestra Carta',
            'descripcion': 'Menú completo de platos disponibles'
          },
          {
            'id': 'menu_degustacion',
            'nombre': 'Menú Degustación',
            'descripcion': 'Experiencia gastronómica especial'
          },
          {
            'id': 'vinos_bodega',
            'nombre': 'Carta de Vinos',
            'descripcion': 'Selección de vinos de nuestra bodega'
          },
          {
            'id': 'eventos_privados',
            'nombre': 'Eventos Privados',
            'descripcion': 'Celebraciones y eventos especiales'
          },
        ];

      case 'peluqueria':
      case 'estetica':
        return [
          {
            'id': 'ofertas_mes',
            'nombre': 'Ofertas del Mes',
            'descripcion': 'Promociones y descuentos especiales'
          },
          {
            'id': 'servicios_cabello',
            'nombre': 'Servicios de Cabello',
            'descripcion': 'Cortes, coloración y peinados'
          },
          {
            'id': 'tratamientos_faciales',
            'nombre': 'Tratamientos Faciales',
            'descripcion': 'Cuidado y belleza facial'
          },
          {
            'id': 'manicura_pedicura',
            'nombre': 'Manicura y Pedicura',
            'descripcion': 'Cuidado de uñas y pies'
          },
          {
            'id': 'pack_novia',
            'nombre': 'Pack Novia',
            'descripcion': 'Servicios especiales para bodas'
          },
        ];

      case 'tienda':
      case 'comercio':
        return [
          {
            'id': 'productos_destacados',
            'nombre': 'Productos Destacados',
            'descripcion': 'Nuestros productos más populares'
          },
          {
            'id': 'ofertas_temporada',
            'nombre': 'Ofertas de Temporada',
            'descripcion': 'Descuentos y promociones actuales'
          },
          {
            'id': 'nuevos_productos',
            'nombre': 'Nuevos Productos',
            'descripcion': 'Últimas incorporaciones a nuestro catálogo'
          },
          {
            'id': 'marcas_exclusivas',
            'nombre': 'Marcas Exclusivas',
            'descripcion': 'Productos únicos que solo encontrarás aquí'
          },
        ];

      case 'clinica':
      case 'consulta':
        return [
          {
            'id': 'servicios_medicos',
            'nombre': 'Servicios Médicos',
            'descripcion': 'Especialidades y tratamientos disponibles'
          },
          {
            'id': 'horarios_atencion',
            'nombre': 'Horarios de Atención',
            'descripcion': 'Cuándo puedes visitarnos'
          },
          {
            'id': 'seguros_aceptados',
            'nombre': 'Seguros Aceptados',
            'descripcion': 'Compañías aseguradoras con las que trabajamos'
          },
          {
            'id': 'equipo_medico',
            'nombre': 'Nuestro Equipo',
            'descripcion': 'Profesionales que te atenderán'
          },
        ];

      default:
        return [
          {
            'id': 'informacion_general',
            'nombre': 'Información General',
            'descripcion': 'Información básica sobre el negocio'
          },
          {
            'id': 'servicios_productos',
            'nombre': 'Servicios/Productos',
            'descripcion': 'Lo que ofrecemos a nuestros clientes'
          },
          {
            'id': 'contacto_ubicacion',
            'nombre': 'Contacto y Ubicación',
            'descripcion': 'Cómo encontrarnos y contactarnos'
          },
          {
            'id': 'horarios_atencion',
            'nombre': 'Horarios de Atención',
            'descripcion': 'Cuándo estamos disponibles'
          },
        ];
    }
  }

  /// Crear todas las secciones de una plantilla para una empresa
  Future<void> aplicarPlantilla(String empresaId, String tipoNegocio) async {
    try {
      final plantilla = obtenerPlantillasPorTipo(tipoNegocio);

      for (final seccion in plantilla) {
        await crearSeccionParaEmpresa(
          empresaId,
          seccion['id']!,
          seccion['nombre']!,
          seccion['descripcion']!,
        );
      }

      print('✅ Plantilla "$tipoNegocio" aplicada a empresa $empresaId');
    } catch (e) {
      print('❌ Error aplicando plantilla: $e');
      rethrow;
    }
  }
}

/// Comandos que el administrador puede usar desde la consola de Firebase o desde un panel admin
class ComandosAdministrador {
  static final AdminContenidoWebService _adminService = AdminContenidoWebService();

  /// Configurar empresa completa con plantilla
  static Future<void> configurarEmpresa(String empresaId, String tipoNegocio) async {
    print('🏗️ Configurando empresa $empresaId como $tipoNegocio...');
    await _adminService.aplicarPlantilla(empresaId, tipoNegocio);
    print('✅ Empresa configurada correctamente');
  }

  /// Configurar Dama Juana Guadalajara específicamente
  static Future<void> configurarDamaJuana() async {
    const empresaId = "ztZblwm1w71wNQtzHV7S"; // ID de Dama Juana

    print('🏪 Configurando Dama Juana Guadalajara...');

    // Crear secciones específicas para Dama Juana
    await _adminService.crearSeccionParaEmpresa(
      empresaId,
      'ofertas_mes',
      'Ofertas del Mes',
      'Promociones especiales y descuentos de temporada',
    );

    await _adminService.crearSeccionParaEmpresa(
      empresaId,
      'servicios_destacados',
      'Servicios Destacados',
      'Nuestros tratamientos de belleza más populares',
    );

    await _adminService.crearSeccionParaEmpresa(
      empresaId,
      'pack_especiales',
      'Packs Especiales',
      'Combinaciones de servicios con precio especial',
    );

    await _adminService.crearSeccionParaEmpresa(
      empresaId,
      'horarios_especiales',
      'Horarios Especiales',
      'Información sobre horarios festivos o cambios temporales',
    );

    print('✅ Dama Juana Guadalajara configurada correctamente');
  }
}
