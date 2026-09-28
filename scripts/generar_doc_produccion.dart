// ignore_for_file: avoid_print
/// Genera un PDF de documentación técnica y estado de producción de Fluix.
/// Ejecutar desde la raíz del proyecto:
///   dart run scripts/generar_doc_produccion.dart
library;

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─── Paleta ──────────────────────────────────────────────────────────────────
const _kAzul    = PdfColor.fromInt(0xFF1976D2);
const _kAzulOsc = PdfColor.fromInt(0xFF0D47A1);
const _kVerde   = PdfColor.fromInt(0xFF22C55E);
const _kNaranja = PdfColor.fromInt(0xFFF59E0B);
const _kRojo    = PdfColor.fromInt(0xFFEF4444);
const _kGris    = PdfColor.fromInt(0xFF6B7280);
const _kGrisCl  = PdfColor.fromInt(0xFFF3F4F6);
const _kBorder  = PdfColor.fromInt(0xFFE5E7EB);
const _kTexto   = PdfColor.fromInt(0xFF111827);

// ─── Modelos de datos ─────────────────────────────────────────────────────────
class _Modulo {
  final String icono;
  final String nombre;
  final String descripcion;
  final List<String> funciones;
  final _Estado estado;
  final List<String> pendiente;

  const _Modulo({
    required this.icono,
    required this.nombre,
    required this.descripcion,
    required this.funciones,
    required this.estado,
    this.pendiente = const [],
  });
}

enum _Estado { completo, beta, parcial }

// ─── Contenido ───────────────────────────────────────────────────────────────
const _modulos = <_Modulo>[
  _Modulo(
    icono: '📊',
    nombre: 'Dashboard',
    descripcion:
        'Hub principal de la aplicación con widgets configurables. Muestra KPIs '
        'en tiempo real (facturas, clientes, pedidos, empleados, reservas y tareas), '
        'gráfico de facturación mensual, alertas del negocio, obligaciones fiscales '
        'próximas, actividad reciente y módulo de briefing IA. Soporta modo oscuro, '
        'multi-empresa y roles diferenciados. Los widgets son reordenables y el '
        'cliente puede personalizar su panel.',
    funciones: [
      'KPIs en tiempo real con Firestore streams',
      'Gráfico de barras de facturación (6 meses, ventana navegable)',
      'Alertas del negocio: facturas vencidas, reservas por confirmar, tareas',
      'Obligaciones fiscales: Mod. 303, 130, 111, 390',
      'Actividad reciente del día (facturas, tareas, clientes, reservas)',
      'Panel de bienvenida con saludo contextual y empresa activa',
      'Modo edición: arrastrar y reordenar widgets',
      'Soporte dark/light mode reactivo',
      'Layout adaptativo: móvil, tablet, desktop (sidebar progresivo)',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Widget de resumen TPV (ventas del día) aún no activo en el dashboard modular',
    ],
  ),
  _Modulo(
    icono: '🧾',
    nombre: 'Facturación',
    descripcion:
        'Módulo completo de facturación adaptado a la normativa española. Permite '
        'crear facturas ordinarias, rectificativas y proformas, gestionar presupuestos, '
        'registrar facturas recibidas y llevar la contabilidad simplificada. Integra '
        'Verifactu para cumplir el Real Decreto 1007/2023 (sistemas de gestión '
        'certificados). Incluye soporte para IVA, IRPF, operaciones intracomunitarias '
        'y construcción.',
    funciones: [
      'Crear, editar y eliminar facturas emitidas (ordinaria, rectificativa, proforma)',
      'Gestión de presupuestos y albaranes',
      'Facturas recibidas (gastos) con seguimiento de pagos',
      'Contabilidad: Libro de IVA soportado/repercutido, PYG simplificado',
      'Modelos fiscales: 303 (IVA), 130 (IRPF), 347, 349, 111, 180, 390',
      'Integración Verifactu: firma digital y envío AEAT (RD 1007/2023)',
      'Subida de certificado digital para firma XADES-BES',
      'Generación de PDF con plantillas personalizables',
      'Filtros avanzados: estado, fecha, cliente, serie',
      'Series de facturación configurables',
      'Validación IBAN español y VIES para operaciones intracomunitarias',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Integración Verifactu en producción: pendiente certificado real de la empresa',
      'Clave API AEAT para entorno producción (actualmente en sandbox)',
      'Revisión completa del Libro de IVA ante posibles discrepancias de redondeo',
      'Exportación XML para SII (Suministro Inmediato de Información) — no implementado',
    ],
  ),
  _Modulo(
    icono: '👥',
    nombre: 'Clientes',
    descripcion:
        'CRM ligero orientado a PYMES españolas. Permite gestionar la cartera de '
        'clientes con etiquetado, segmentación, detección de duplicados e importación '
        'masiva CSV. Se integra con reservas, tareas y facturación para ofrecer una '
        'visión 360° del cliente.',
    funciones: [
      'Alta, edición y baja de clientes (NIF/CIF, IBAN, dirección fiscal)',
      'Etiquetas: VIP, Frecuente, Moroso, Proveedor, Potencial',
      'Detección de clientes "silenciosos" (sin actividad reciente)',
      'Detección de duplicados por nombre/NIF',
      'Importación/exportación CSV masiva',
      'Vinculación a facturas, reservas y tareas',
      'Historial de actividad por cliente',
      'Filtros y búsqueda avanzada',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Envío de email de bienvenida al añadir un cliente nuevo (función Cloud preparada)',
      'Segmentación automática basada en historial de compras (no implementado)',
    ],
  ),
  _Modulo(
    icono: '🖥️',
    nombre: 'TPV (Terminal Punto de Venta)',
    descripcion:
        'Sistema TPV multi-sector: hostelería (mesas, comandas, cocina), peluquería '
        '(citas, cabinas, profesionales) y tienda (catálogo, caja, cierres). Cada '
        'modo tiene su UI y flujo optimizados. Integra impresora térmica Bluetooth '
        'y cajón portamonedas. Se sincroniza automáticamente con Facturación.',
    funciones: [
      'Modo Hostelería: gestión de mesas, zonas, comandas, pantalla cocina (KDS)',
      'Modo Peluquería: agenda por profesional, cabinas, tipos de turno, citas',
      'Modo Tienda: catálogo de productos, variantes, escáner de código de barras',
      'Cierre de caja diario con desglose de métodos de pago',
      'Impresión de tickets en impresora térmica Bluetooth',
      'Apertura de cajón portamonedas vía protocolo ESC/POS',
      'Pedidos en espera (Hold) y división de cuenta',
      'Devoluciones y reembolsos con trazabilidad',
      'Conexión automática con Facturación (emisión de facturas desde TPV)',
      'Histórico de ventas y estadísticas por turno',
    ],
    estado: _Estado.beta,
    pendiente: [
      'Modo Hostelería: pruebas de carga con múltiples mesas simultáneas',
      'Integración Stripe para pago con tarjeta (implementado pero en sandbox)',
      'Impresora térmica: compatibilidad en iOS pendiente (Bluetooth limitado en App Store)',
      'Modo Tienda: gestión de stock en tiempo real con alertas de mínimo',
      'Sincronización offline mejorada (actualmente requiere conexión continua)',
      'Auditoría: pruebas con hardware real de caja en diferentes sectores',
    ],
  ),
  _Modulo(
    icono: '👔',
    nombre: 'Empleados',
    descripcion:
        'Gestión del personal de la empresa. Incluye ficha completa del empleado, '
        'historial salarial, embargos, suspensiones laborales, vinculación con nóminas '
        'y gestión de documentos y fotos. Soporta baja de empleados con conservación '
        'del historial.',
    funciones: [
      'Ficha empleado: datos personales, contrato, IBAN, Seguridad Social',
      'Historial salarial con evolución de salario base',
      'Registro de embargos (embargo judicial de salario)',
      'Suspensiones laborales (ERTE, IT, maternidad, etc.)',
      'Subida de documentos: contrato, DNI, titulaciones',
      'Foto de perfil del empleado',
      'Baja de empleados con conservación de historial',
      'Formulario de datos de nómina (Datos nómina form)',
      'Integración con Nóminas y Fichajes',
      'Control de roles y permisos por empleado',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Gestión de IT (Incapacidad Temporal): actualmente solo registro manual',
      'Integración con sistema de Seguridad Social (RED System) no implementada',
      'Portal del empleado: acceso web del trabajador a sus datos (no existe)',
    ],
  ),
  _Modulo(
    icono: '⏱️',
    nombre: 'Fichajes',
    descripcion:
        'Control horario conforme al Real Decreto 2026 de registro de jornada laboral. '
        'Permite fichar entrada, pausa y salida mediante PIN en tablet kiosk o desde '
        'la propia app. El admin gestiona empleados, horarios y genera informes '
        'mensuales. Soporta empleados sin cuenta en la app (solo kiosk).',
    funciones: [
      'Fichaje entrada/salida/pausa con PIN numérico de 4 dígitos',
      'Modo kiosk: tablet compartida en la empresa con selector de empleado',
      'Dashboard admin en tiempo real: quién está trabajando, en pausa o ha salido',
      'Parámetros por empleado: jornada diaria, horario habitual, días laborables',
      'Informes mensuales: horas trabajadas vs planificadas, horas extra',
      'Corrección de fichajes incorrectos (inmutabilidad + nuevo documento)',
      'Firma SHA-256 de cada fichaje para integridad',
      'Empleados externos (sin cuenta de app, solo kiosk)',
      'Exportación de informes a PDF',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Integración con GPS para verificar ubicación del fichaje (preparado, no activo)',
      'Exportación de fichajes a formato compatible con software de RRHH (A3, Nominasol)',
      'Notificación automática al admin cuando empleado no ha fichado (Cloud Function pendiente)',
    ],
  ),
  _Modulo(
    icono: '🏖️',
    nombre: 'Vacaciones',
    descripcion:
        'Gestión de vacaciones, ausencias y días libres del personal. Permite '
        'solicitar y aprobar permisos, configurar días festivos, ver la cobertura '
        'del equipo y controlar el saldo por tipo de ausencia.',
    funciones: [
      'Solicitud y aprobación de vacaciones (flujo empleado → admin)',
      'Tipos de ausencia: vacaciones, IT, maternidad/paternidad, personal, sin sueldo',
      'Balance de días por empleado y año',
      'Calendario visual de ausencias del equipo (vista de cobertura)',
      'Configuración de festivos nacionales, autonómicos y locales',
      'Formulario de solicitud de coexistencia',
      'Exportación del calendario a PDF',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Integración automática con Fichajes (actualmente manual)',
      'Notificaciones push al empleado cuando se aprueba/rechaza (Cloud Function pendiente)',
      'Cálculo automático de pagas extra en función de vacaciones disfrutadas',
    ],
  ),
  _Modulo(
    icono: '💰',
    nombre: 'Nóminas',
    descripcion:
        'Módulo de gestión de nóminas mensuales. Permite generar nóminas, aplicar '
        'deducciones, suplementos y ausencias. Exporta remesas SEPA para pagos '
        'bancarios automáticos y permite la firma digital del recibo. El empleado '
        'puede consultar sus propias nóminas.',
    funciones: [
      'Generación de nómina mensual por empleado',
      'Cálculo de deducciones: IRPF, SS, embargos',
      'Suplementos: horas extra, nocturnidad, peligrosidad, guardia',
      'Aplicación automática de ausencias (IT, vacaciones)',
      'Análisis de costes de empresa por empleado',
      'Exportación de remesa SEPA (XML ISO 20022) para banco',
      'Firma digital del recibo de nómina',
      'Vista del empleado: acceso a sus propias nóminas y recibos',
    ],
    estado: _Estado.beta,
    pendiente: [
      'Validación legal por gestoría: el cálculo del IRPF usa tablas 2024, '
          'pendiente actualización a tablas 2025-2026 y tramos autonómicos',
      'Integración con Hacienda (SILTRA/RED) no implementada',
      'Generación del modelo 111 (retenciones) desde nóminas (actualmente manual)',
      'Pruebas con distintos tipos de contrato (tiempo parcial, obra y servicio)',
    ],
  ),
  _Modulo(
    icono: '📦',
    nombre: 'Pedidos',
    descripcion:
        'Gestión de pedidos con catálogo de productos, variantes y precios. '
        'Integra un bot de WhatsApp para recepción automática de pedidos de '
        'clientes. Soporta estados de pedido desde nuevo hasta entregado.',
    funciones: [
      'Catálogo de productos con variantes, precios y descripciones',
      'Creación manual de pedidos desde el panel admin',
      'Bot WhatsApp: recepción automática de pedidos por mensaje',
      'Estados: nuevo → confirmado → preparando → enviado → entregado',
      'Importación de catálogo desde CSV',
      'Vinculación opcional a cliente del CRM',
      'Exportación e impresión de albarán',
      'Módulo de delivery: gestión de reparto (fase beta)',
    ],
    estado: _Estado.beta,
    pendiente: [
      'Bot WhatsApp: requiere número de WhatsApp Business verificado y aprobación Meta',
      'Pasarela de pago online en pedidos B2C (Stripe implementado pero no activo)',
      'Notificaciones al cliente en cada cambio de estado (Cloud Function lista, '
          'falta configuración por empresa)',
      'Módulo delivery: pendiente pruebas de campo',
    ],
  ),
  _Modulo(
    icono: '✅',
    nombre: 'Tareas',
    descripcion:
        'Gestión de tareas con metodología Kanban. Permite asignar tareas a '
        'empleados, definir prioridades, fechas límite y adjuntar archivos. '
        'Incluye cronómetro integrado para registro de tiempo y vista de calendario.',
    funciones: [
      'Tablero Kanban: Pendiente → En Progreso → En Revisión → Completado',
      'Vista de lista y vista de calendario',
      'Prioridades: baja, media, alta, urgente',
      'Asignación a empleados con notificación push',
      'Adjuntos de archivos e imágenes',
      'Vinculación a cliente del CRM',
      'Cronómetro integrado para registro de horas',
      'Tareas recurrentes (diaria, semanal, mensual)',
      'Filtrado por asignado, prioridad, estado y fecha',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Exportación de informe de tiempo trabajado por tarea (no implementado)',
      'Vista gantt no disponible',
    ],
  ),
  _Modulo(
    icono: '📅',
    nombre: 'Reservas / Citas',
    descripcion:
        'Sistema de reservas y citas estilo Booksy. Permite a clientes B2C '
        'reservar online y al admin gestionar el calendario, profesionales y '
        'disponibilidad. Integra notificaciones por email y WhatsApp.',
    funciones: [
      'Calendario de reservas por profesional y servicio',
      'Slots de disponibilidad configurables (horas, días, vacaciones)',
      'Portal B2C: clientes reservan sin login previo',
      'Estados: pendiente → confirmada → completada → cancelada',
      'Recordatorios automáticos por email (1 hora antes)',
      'Integración WhatsApp: confirmación y recordatorio',
      'Reservas recurrentes (semanal, quincenal, mensual)',
      'Configuración de tiempo de servicio por tipo de cita',
      'Flash slots: disponibilidad de último minuto',
      'Valoración post-cita automática (email)',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Pago anticipado de la reserva (Stripe preparado, no activo en producción)',
      'Sincronización con Google Calendar del profesional (no implementado)',
      'App móvil B2C separada para clientes (actualmente acceso via web)',
    ],
  ),
  _Modulo(
    icono: '⭐',
    nombre: 'Valoraciones',
    descripcion:
        'Sistema de valoraciones y reseñas de clientes. Recoge opiniones '
        'post-servicio, las muestra en el panel admin y las publica en la web '
        'pública del negocio. Integra Google Reviews con respuesta desde la app.',
    funciones: [
      'Solicitud automática de valoración tras completar reserva (email)',
      'Valoración en escala 1-5 con comentario libre',
      'Panel admin: listado, filtrado y respuesta a reseñas',
      'Publicación selectiva en la web pública del negocio',
      'Integración Google My Business: ver y responder reseñas de Google',
      'Estadísticas: puntuación media, distribución, tendencia',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Integración Google Reviews: requiere verificación GMB por cada negocio',
      'Moderación automática de contenido inapropiado (no implementado)',
    ],
  ),
  _Modulo(
    icono: '🔧',
    nombre: 'Servicios',
    descripcion:
        'Catálogo de servicios de la empresa. Define los servicios disponibles '
        'con nombre, descripción, precio y duración. Es la fuente de datos para '
        'Reservas, TPV peluquería y la web pública.',
    funciones: [
      'Alta, edición y baja de servicios',
      'Categorización de servicios',
      'Precio y duración por servicio',
      'Importación/exportación CSV',
      'Publicación en web pública del negocio',
      'Integración con Reservas y TPV',
    ],
    estado: _Estado.completo,
    pendiente: [],
  ),
  _Modulo(
    icono: '🌐',
    nombre: 'Web (Contenido Público)',
    descripcion:
        'Gestión del contenido de la web pública del negocio: secciones, blog, '
        'eventos, galería, formulario de contacto y configuración general. '
        'El contenido se publica en tiempo real en la web del cliente.',
    funciones: [
      'Editor de secciones de la web (texto, imágenes, llamadas a la acción)',
      'Blog: crear, editar y publicar artículos',
      'Eventos: crear eventos con fecha, hora y descripción',
      'Galería de imágenes con subida directa',
      'Formulario de contacto: recepción y gestión de mensajes',
      'Configuración: horario, dirección, redes sociales, colores',
      'Bandeja de notificaciones del negocio',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Editor WYSIWYG completo para el blog (actualmente texto plano + markdown básico)',
      'Integración con dominio propio del cliente (actualmente subdominio de Fluix)',
      'SEO básico: meta tags, sitemap automático (parcialmente implementado)',
    ],
  ),
  _Modulo(
    icono: '📄',
    nombre: 'Plantillas PDF',
    descripcion:
        'Sistema de personalización de documentos PDF (facturas, albaranes, '
        'presupuestos). El cliente puede elegir entre plantillas prediseñadas y '
        'configurar colores, logo y datos de la empresa.',
    funciones: [
      '5+ layouts de factura (minimalista, corporativo, detallado, moderno, clásico)',
      'Vista previa en tiempo real del PDF',
      'Configuración de colores de marca',
      'Subida de logo de empresa',
      'Selector de fuente tipográfica',
      'Campos configurables: pie de página, términos y condiciones',
      'Galería de plantillas con preview en tarjeta A4',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Editor WYSIWYG de plantillas (actualmente elección entre opciones fijas)',
      'Plantilla para nómina (no existe, solo facturas)',
    ],
  ),
  _Modulo(
    icono: '🛠️',
    nombre: 'Soporte',
    descripcion:
        'Centro de ayuda y soporte al cliente. Incluye enlaces rápidos a tutoriales, '
        'formulario de solicitud de nuevas funcionalidades y canal de comunicación '
        'directa con el equipo de Fluix.',
    funciones: [
      'Formulario de solicitud de ayuda y soporte',
      'Sugerencias de nuevas funcionalidades',
      'Enlace a documentación y tutoriales',
      'Historial de tickets del cliente',
    ],
    estado: _Estado.parcial,
    pendiente: [
      'Base de conocimiento / FAQ interactiva (no implementada)',
      'Chat en vivo con el equipo de soporte (no implementado)',
      'Sistema de tickets con seguimiento de estado (actualmente sin backend propio)',
    ],
  ),
  _Modulo(
    icono: '👑',
    nombre: 'Panel Propietario (Admin Plataforma)',
    descripcion:
        'Panel exclusivo del propietario de la plataforma Fluix (FluixTech). '
        'Permite gestionar empresas, planes de suscripción, métricas globales, '
        'activar/desactivar módulos y simular vistas de otros roles.',
    funciones: [
      'Listado y gestión de todas las empresas de la plataforma',
      'Activación de módulos por empresa y plan de suscripción',
      'Métricas globales: empresas activas, facturación de la plataforma',
      'Simulación de roles (admin, staff, usuario B2C) para QA',
      'Panel de permisos granulares por empresa',
      'Gestión de cuentas demo',
      'Vista del grafo de la app (arquitectura de módulos)',
    ],
    estado: _Estado.completo,
    pendiente: [
      'Dashboard de salud de la plataforma (uptime, errores, latencia)',
      'Facturación automática a empresas (cobro de suscripción mensual)',
      'Sistema de alertas automáticas para el propietario',
    ],
  ),
];

// ─── Secciones de producción ──────────────────────────────────────────────────
class _AreaProduccion {
  final String titulo;
  final String descripcion;
  final List<_ItemProd> items;
  const _AreaProduccion(this.titulo, this.descripcion, this.items);
}

class _ItemProd {
  final String texto;
  final _PrioProd prioridad;
  const _ItemProd(this.texto, this.prioridad);
}

enum _PrioProd { critico, importante, mejora }

const _areasProduccion = <_AreaProduccion>[
  _AreaProduccion(
    '🔒 Seguridad y Autenticación',
    'Aspectos de seguridad que deben revisarse antes de salir a producción.',
    [
      _ItemProd('Auditoría completa de reglas Firestore con penetration testing básico', _PrioProd.critico),
      _ItemProd('Revisar exposición de datos sensibles (nóminas, NIF, IBAN) en reglas', _PrioProd.critico),
      _ItemProd('Activar App Check (reCAPTCHA v3) para bloquear accesos no autorizados a Firebase', _PrioProd.critico),
      _ItemProd('Rotar todas las claves API y credenciales de Firebase antes del despliegue final', _PrioProd.critico),
      _ItemProd('2FA para cuentas de propietario y admin (ya implementado, verificar flujo)', _PrioProd.importante),
      _ItemProd('Validar que los tokens JWT expiran correctamente y se renuevan', _PrioProd.importante),
      _ItemProd('Cifrado de datos biométricos y PINs de fichaje (actualmente en texto plano en Firestore)', _PrioProd.importante),
      _ItemProd('Rate limiting en Cloud Functions para prevenir abuso', _PrioProd.importante),
    ],
  ),
  _AreaProduccion(
    '📋 Cumplimiento Legal y Fiscal (España)',
    'Requisitos legales específicos para operar en España.',
    [
      _ItemProd('Verifactu: obtener certificado digital real AEAT para cada empresa cliente', _PrioProd.critico),
      _ItemProd('Verifactu: activar endpoint de producción AEAT (actualmente sandbox)', _PrioProd.critico),
      _ItemProd('LOPD/RGPD: política de privacidad específica por empresa (actualmente genérica)', _PrioProd.critico),
      _ItemProd('RGPD: implementar derecho al olvido y portabilidad de datos', _PrioProd.critico),
      _ItemProd('Aviso legal y política de cookies en la web pública de cada negocio', _PrioProd.critico),
      _ItemProd('Registro de actividad de tratamiento (RAT) por empresa', _PrioProd.importante),
      _ItemProd('Normativa fichajes (RD 2026): verificar que los registros son inmutables y firmados', _PrioProd.importante),
      _ItemProd('Nóminas: actualizar tablas IRPF 2025-2026 y tramos autonómicos', _PrioProd.importante),
      _ItemProd('Numeración de facturas: verificar secuencia sin huecos conforme a norma', _PrioProd.importante),
      _ItemProd('Conservación de documentos fiscales: asegurar backup a 7 años mínimo', _PrioProd.importante),
    ],
  ),
  _AreaProduccion(
    '☁️ Backend e Infraestructura',
    'Configuración de servidores, bases de datos y servicios en la nube.',
    [
      _ItemProd('Migrar proyecto Firebase de plan Spark a Blaze (requerido para Cloud Functions en producción)', _PrioProd.critico),
      _ItemProd('Configurar alertas de presupuesto Firebase para evitar costes no esperados', _PrioProd.critico),
      _ItemProd('Índices Firestore: revisar firestore.indexes.json y desplegar todos en producción', _PrioProd.critico),
      _ItemProd('Reglas Firestore: desplegar versión de producción (actualmente en desarrollo)', _PrioProd.critico),
      _ItemProd('Storage rules: revisar que solo usuarios autenticados acceden a archivos privados', _PrioProd.importante),
      _ItemProd('Cloud Functions: revisar timeouts y memoria asignada por función', _PrioProd.importante),
      _ItemProd('Configurar Cloud Logging y alertas de errores críticos (Crashlytics activo)', _PrioProd.importante),
      _ItemProd('Backup automático de Firestore (exportación diaria a Cloud Storage)', _PrioProd.importante),
      _ItemProd('CDN para assets estáticos de la web pública (imágenes, logo)', _PrioProd.mejora),
      _ItemProd('Revisión de Cold Starts en Cloud Functions para mejorar latencia', _PrioProd.mejora),
    ],
  ),
  _AreaProduccion(
    '📱 Apps (iOS y Android)',
    'Preparación para publicación en App Store y Google Play.',
    [
      _ItemProd('Generar certificado de distribución iOS y perfil de aprovisionamiento', _PrioProd.critico),
      _ItemProd('Configurar Google Play keystore de producción (fluix_release.jks existente, verificar contraseña)', _PrioProd.critico),
      _ItemProd('Capturas de pantalla para App Store y Google Play (5.5" y 6.5" iOS, varios Android)', _PrioProd.critico),
      _ItemProd('Descripción en App Store y Google Play en español e inglés', _PrioProd.critico),
      _ItemProd('Política de privacidad pública accesible via URL (requerido por ambas stores)', _PrioProd.critico),
      _ItemProd('Configurar notificaciones push en producción (APNs certificado producción para iOS)', _PrioProd.critico),
      _ItemProd('Pruebas en TestFlight (iOS) y Google Play Internal Testing antes del lanzamiento', _PrioProd.critico),
      _ItemProd('Revisar permisos de la app: cámara, galería, Bluetooth, localización — justificar uso', _PrioProd.importante),
      _ItemProd('Compatibilidad iOS 15+ verificada (hay fixes aplicados, confirmar en device real)', _PrioProd.importante),
      _ItemProd('Target SDK Android 34+ (requerido por Google Play desde 2024)', _PrioProd.importante),
      _ItemProd('Pruebas de accesibilidad (VoiceOver iOS, TalkBack Android)', _PrioProd.mejora),
    ],
  ),
  _AreaProduccion(
    '💳 Pagos (Stripe)',
    'Activación del sistema de cobros online.',
    [
      _ItemProd('Cuenta Stripe verificada y activa en modo producción (actualmente sandbox)', _PrioProd.critico),
      _ItemProd('Webhook Stripe configurado con URL de producción de Cloud Functions', _PrioProd.critico),
      _ItemProd('Revisar variables de entorno: STRIPE_TIENDA_WEBHOOK_SECRET en producción', _PrioProd.critico),
      _ItemProd('Configurar impuestos automáticos de Stripe (Stripe Tax) o revisión manual', _PrioProd.importante),
      _ItemProd('Pruebas de pago con tarjetas reales en staging antes de activar en producción', _PrioProd.importante),
      _ItemProd('Proceso de reembolso: verificar que el flujo funciona end-to-end', _PrioProd.importante),
    ],
  ),
  _AreaProduccion(
    '📧 Comunicaciones (Email y WhatsApp)',
    'Servicios de mensajería para notificaciones a clientes.',
    [
      _ItemProd('Resend: configurar dominio propio (actualmente usa dominio sandbox de Resend)', _PrioProd.critico),
      _ItemProd('Verificar registros SPF, DKIM y DMARC para el dominio de envío', _PrioProd.critico),
      _ItemProd('Twilio/WhatsApp Business: cuenta aprobada y número de producción verificado', _PrioProd.critico),
      _ItemProd('Plantillas de WhatsApp aprobadas por Meta (requieren aprobación previa)', _PrioProd.critico),
      _ItemProd('Probar flujo completo de email: reserva → confirmación → recordatorio → valoración', _PrioProd.importante),
      _ItemProd('Límites de envío: revisar plan de Resend (número de emails/mes)', _PrioProd.importante),
      _ItemProd('Gestión de bajas (unsubscribe) en emails de marketing — obligatorio RGPD', _PrioProd.importante),
    ],
  ),
  _AreaProduccion(
    '🧪 Testing y Calidad',
    'Pruebas necesarias antes del lanzamiento.',
    [
      _ItemProd('Suite de tests de integración para flujos críticos: facturación, fichajes, TPV', _PrioProd.critico),
      _ItemProd('Pruebas de carga: 50+ empresas concurrentes con actividad simultánea', _PrioProd.importante),
      _ItemProd('Pruebas de offline: comportamiento de la app sin conexión a internet', _PrioProd.importante),
      _ItemProd('Pruebas de recuperación ante caída de Firebase (modo degradado)', _PrioProd.importante),
      _ItemProd('QA completo en dispositivos físicos: iPhone 13/15, Samsung Galaxy S23, tablet Android', _PrioProd.importante),
      _ItemProd('Pruebas de accesibilidad en módulos principales', _PrioProd.mejora),
      _ItemProd('Análisis de performance con Flutter DevTools (jank frames, memoria)', _PrioProd.mejora),
    ],
  ),
  _AreaProduccion(
    '📈 Monitorización y Soporte',
    'Herramientas para operar la plataforma en producción.',
    [
      _ItemProd('Firebase Crashlytics activo en modo producción (ya configurado)', _PrioProd.importante),
      _ItemProd('Dashboard de métricas de plataforma: DAU, errores, latencia por módulo', _PrioProd.importante),
      _ItemProd('Proceso de on-boarding: guía de primer acceso para nuevas empresas', _PrioProd.importante),
      _ItemProd('SLA de soporte definido (tiempo de respuesta a incidencias)', _PrioProd.importante),
      _ItemProd('Plan de DR (Disaster Recovery): qué hacer si Firebase cae', _PrioProd.importante),
      _ItemProd('Documentación de usuario final actualizada (actualmente en progreso)', _PrioProd.mejora),
    ],
  ),
];

// ─── Generación del PDF ───────────────────────────────────────────────────────

Future<void> main() async {
  final pdf = pw.Document(
    author: 'FluixTech',
    title: 'Fluix — Documentación Técnica y Estado de Producción',
    subject: 'Análisis completo de módulos y checklist de producción',
    creator: 'Generado automáticamente por Fluix',
  );

  // Portada
  pdf.addPage(_portada());

  // Índice de módulos
  pdf.addPage(_indice());

  // Módulos (varios por página)
  for (var i = 0; i < _modulos.length; i++) {
    pdf.addPage(_paginaModulo(_modulos[i], i + 1));
  }

  // Checklist de producción
  for (final area in _areasProduccion) {
    pdf.addPage(_paginaProduccion(area));
  }

  // Resumen ejecutivo final
  pdf.addPage(_resumenFinal());

  final file = File('Fluix_Documentacion_Produccion.pdf');
  await file.writeAsBytes(await pdf.save());
  print('✅ PDF generado: ${file.absolute.path}');
  print('   Módulos documentados: ${_modulos.length}');
  print('   Áreas de producción: ${_areasProduccion.length}');
}

// ─── Widgets de ayuda ─────────────────────────────────────────────────────────

pw.Page _portada() => pw.Page(
  pageFormat: PdfPageFormat.a4,
  margin: pw.EdgeInsets.zero,
  build: (_) => pw.Stack(children: [
    // Fondo degradado simulado con dos rectángulos
    pw.Container(
      width: double.infinity,
      height: double.infinity,
      color: _kAzulOsc,
    ),
    pw.Positioned(
      bottom: 0, right: 0,
      child: pw.Container(
        width: 400, height: 400,
        decoration: const pw.BoxDecoration(
          color: _kAzul,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(400)),
        ),
      ),
    ),
    // Contenido
    pw.Padding(
      padding: const pw.EdgeInsets.all(60),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 60),
          pw.Text('FLUIX', style: pw.TextStyle(
            fontSize: 14, color: PdfColors.white,
            fontWeight: pw.FontWeight.bold, letterSpacing: 6,
          )),
          pw.SizedBox(height: 16),
          pw.Text('Documentación Técnica\ny Estado de Producción',
            style: pw.TextStyle(
              fontSize: 38, color: PdfColors.white,
              fontWeight: pw.FontWeight.bold, lineSpacing: 4,
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Container(width: 60, height: 4, color: _kVerde),
          pw.SizedBox(height: 24),
          pw.Text(
            'Análisis completo de los ${_modulos.length} módulos de la plataforma\n'
            'y checklist de requisitos para el despliegue en producción.',
            style: pw.TextStyle(fontSize: 16, color: PdfColors.white, lineSpacing: 4),
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 16),
          pw.Row(children: [
            _pillPortada('v1.0.15', _kVerde),
            pw.SizedBox(width: 10),
            _pillPortada('Agosto 2026', _kAzul),
            pw.SizedBox(width: 10),
            _pillPortada('Confidencial', _kNaranja),
          ]),
          pw.SizedBox(height: 12),
          pw.Text('FluixTech · PlaneaG · Samuel Corcho',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey)),
        ],
      ),
    ),
  ]),
);

pw.Widget _pillPortada(String txt, PdfColor color) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
  decoration: pw.BoxDecoration(
    color: color.withAlpha(0.2),
    borderRadius: pw.BorderRadius.circular(20),
    border: pw.Border.all(color: color.withAlpha(0.5)),
  ),
  child: pw.Text(txt, style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
);

pw.Page _indice() => pw.Page(
  pageFormat: PdfPageFormat.a4,
  margin: const pw.EdgeInsets.all(48),
  build: (_) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _cabecera('Índice de Módulos'),
      pw.SizedBox(height: 24),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Columna 1
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: _modulos.take(9).toList().asMap().entries.map((e) =>
              _filaIndice(e.key + 1, e.value)
            ).toList(),
          ),
        ),
        pw.SizedBox(width: 20),
        // Columna 2
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: _modulos.skip(9).toList().asMap().entries.map((e) =>
              _filaIndice(e.key + 10, e.value)
            ).toList(),
          ),
        ),
      ]),
      pw.SizedBox(height: 32),
      _cabecera('Checklist de Producción'),
      pw.SizedBox(height: 16),
      ..._areasProduccion.asMap().entries.map((e) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(children: [
            pw.Text('${e.key + 1}. ', style: pw.TextStyle(fontSize: 11, color: _kGris)),
            pw.Text(e.value.titulo, style: pw.TextStyle(fontSize: 11)),
          ]),
        ),
      ),
      pw.Spacer(),
      _leyendaEstados(),
    ],
  ),
);

pw.Widget _filaIndice(int num, _Modulo m) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 10),
  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
    pw.Text('$num.', style: pw.TextStyle(fontSize: 11, color: _kGris, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(width: 6),
    pw.Text(m.icono, style: const pw.TextStyle(fontSize: 14)),
    pw.SizedBox(width: 6),
    pw.Expanded(
      child: pw.Text(m.nombre, style: pw.TextStyle(fontSize: 11)),
    ),
    _badgeEstado(m.estado),
  ]),
);

pw.Widget _leyendaEstados() => pw.Container(
  padding: const pw.EdgeInsets.all(12),
  decoration: pw.BoxDecoration(
    color: _kGrisCl,
    borderRadius: pw.BorderRadius.circular(8),
  ),
  child: pw.Row(children: [
    pw.Text('Leyenda: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(width: 8),
    _badgeEstado(_Estado.completo), pw.SizedBox(width: 4),
    pw.Text('Completo', style: const pw.TextStyle(fontSize: 10)),
    pw.SizedBox(width: 12),
    _badgeEstado(_Estado.beta), pw.SizedBox(width: 4),
    pw.Text('Beta / Pruebas', style: const pw.TextStyle(fontSize: 10)),
    pw.SizedBox(width: 12),
    _badgeEstado(_Estado.parcial), pw.SizedBox(width: 4),
    pw.Text('Parcial', style: const pw.TextStyle(fontSize: 10)),
  ]),
);

pw.Widget _badgeEstado(_Estado e) {
  final (txt, color) = switch (e) {
    _Estado.completo => ('✓ Completo', _kVerde),
    _Estado.beta     => ('⚡ Beta', _kNaranja),
    _Estado.parcial  => ('⚠ Parcial', _kRojo),
  };
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(
      color: color.withAlpha(0.12),
      borderRadius: pw.BorderRadius.circular(20),
      border: pw.Border.all(color: color.withAlpha(0.4)),
    ),
    child: pw.Text(txt, style: pw.TextStyle(fontSize: 9, color: color, fontWeight: pw.FontWeight.bold)),
  );
}

pw.Page _paginaModulo(_Modulo m, int num) => pw.Page(
  pageFormat: PdfPageFormat.a4,
  margin: const pw.EdgeInsets.all(48),
  build: (_) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Header del módulo
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: _kAzulOsc,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Row(children: [
          pw.Text(m.icono, style: const pw.TextStyle(fontSize: 28)),
          pw.SizedBox(width: 14),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Módulo $num', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              pw.Text(m.nombre, style: pw.TextStyle(
                fontSize: 22, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
            ],
          )),
          _badgeEstado(m.estado),
        ]),
      ),
      pw.SizedBox(height: 20),

      // Descripción
      pw.Text('Descripción', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _kTexto)),
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _kGrisCl,
          borderRadius: pw.BorderRadius.circular(8),
          border: const pw.Border(left: pw.BorderSide(color: _kAzul, width: 3)),
        ),
        child: pw.Text(m.descripcion,
          style: pw.TextStyle(fontSize: 11, lineSpacing: 3, color: _kTexto)),
      ),
      pw.SizedBox(height: 20),

      // Funcionalidades
      pw.Text('Funcionalidades implementadas', style: pw.TextStyle(
        fontSize: 13, fontWeight: pw.FontWeight.bold, color: _kTexto)),
      pw.SizedBox(height: 8),
      ...m.funciones.map((f) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 4),
            width: 6, height: 6,
            decoration: pw.BoxDecoration(color: _kVerde, shape: pw.BoxShape.circle),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Text(f, style: pw.TextStyle(fontSize: 11, lineSpacing: 2))),
        ]),
      )),

      // Pendiente (si existe)
      if (m.pendiente.isNotEmpty) ...[
        pw.SizedBox(height: 20),
        pw.Text('Pendiente / Mejoras futuras', style: pw.TextStyle(
          fontSize: 13, fontWeight: pw.FontWeight.bold, color: _kTexto)),
        pw.SizedBox(height: 8),
        ...m.pendiente.map((p) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 4),
              width: 6, height: 6,
              decoration: pw.BoxDecoration(color: _kNaranja, shape: pw.BoxShape.circle),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Text(p, style: pw.TextStyle(fontSize: 11, lineSpacing: 2, color: _kGris))),
          ]),
        )),
      ],

      pw.Spacer(),
      _piePagina('Módulo: ${m.nombre}'),
    ],
  ),
);

pw.Page _paginaProduccion(_AreaProduccion area) {
  final criticos   = area.items.where((i) => i.prioridad == _PrioProd.critico).toList();
  final importantes = area.items.where((i) => i.prioridad == _PrioProd.importante).toList();
  final mejoras    = area.items.where((i) => i.prioridad == _PrioProd.mejora).toList();

  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(48),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(colors: [_kRojo, _kNaranja]),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(children: [
            pw.Text(area.titulo.substring(0, 2), style: const pw.TextStyle(fontSize: 24)),
            pw.SizedBox(width: 12),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Requisitos de Producción', style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                pw.Text(area.titulo.substring(3), style: pw.TextStyle(
                  fontSize: 18, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              ],
            )),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('${criticos.length} críticos', style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.Text('${importantes.length} importantes', style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
              if (mejoras.isNotEmpty)
                pw.Text('${mejoras.length} mejoras', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 10),
        pw.Text(area.descripcion, style: pw.TextStyle(fontSize: 11, color: _kGris, lineSpacing: 2)),
        pw.SizedBox(height: 16),

        if (criticos.isNotEmpty) ...[
          _seccionProd('🔴 CRÍTICO — Bloqueante para producción', _kRojo, criticos),
          pw.SizedBox(height: 12),
        ],
        if (importantes.isNotEmpty) ...[
          _seccionProd('🟡 IMPORTANTE — Recomendado antes del lanzamiento', _kNaranja, importantes),
          pw.SizedBox(height: 12),
        ],
        if (mejoras.isNotEmpty)
          _seccionProd('🟢 MEJORA — Puede implementarse post-lanzamiento', _kVerde, mejoras),

        pw.Spacer(),
        _piePagina(area.titulo.substring(3)),
      ],
    ),
  );
}

pw.Widget _seccionProd(String titulo, PdfColor color, List<_ItemProd> items) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: pw.BoxDecoration(
          color: color.withAlpha(0.12),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: color.withAlpha(0.3)),
        ),
        child: pw.Text(titulo, style: pw.TextStyle(fontSize: 10, color: color, fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(height: 8),
      ...items.map((item) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6, left: 4),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('☐', style: pw.TextStyle(fontSize: 12, color: color)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Text(item.texto,
            style: pw.TextStyle(fontSize: 10.5, lineSpacing: 2))),
        ]),
      )),
    ]);

pw.Page _resumenFinal() {
  final completos  = _modulos.where((m) => m.estado == _Estado.completo).length;
  final beta       = _modulos.where((m) => m.estado == _Estado.beta).length;
  final parciales  = _modulos.where((m) => m.estado == _Estado.parcial).length;
  final totalPend  = _modulos.fold(0, (s, m) => s + m.pendiente.length);
  final criticos   = _areasProduccion.fold(0, (s, a) =>
    s + a.items.where((i) => i.prioridad == _PrioProd.critico).length);
  final importantes = _areasProduccion.fold(0, (s, a) =>
    s + a.items.where((i) => i.prioridad == _PrioProd.importante).length);
  final mejoras    = _areasProduccion.fold(0, (s, a) =>
    s + a.items.where((i) => i.prioridad == _PrioProd.mejora).length);

  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(48),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _cabecera('Resumen Ejecutivo'),
        pw.SizedBox(height: 24),

        // KPIs
        pw.Row(children: [
          _kpiCard('$completos', 'Módulos\nCompletados', _kVerde),
          pw.SizedBox(width: 12),
          _kpiCard('$beta', 'En Beta /\nPruebas', _kNaranja),
          pw.SizedBox(width: 12),
          _kpiCard('$parciales', 'Módulos\nParciales', _kRojo),
          pw.SizedBox(width: 12),
          _kpiCard('$totalPend', 'Mejoras\nPendientes', _kGris),
        ]),
        pw.SizedBox(height: 20),

        pw.Row(children: [
          _kpiCard('$criticos', 'Bloqueantes\nProducción', _kRojo),
          pw.SizedBox(width: 12),
          _kpiCard('$importantes', 'Importantes\nRecomendados', _kNaranja),
          pw.SizedBox(width: 12),
          _kpiCard('$mejoras', 'Mejoras\nPost-lanzamiento', _kVerde),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.SizedBox()),
        ]),
        pw.SizedBox(height: 28),

        pw.Text('Evaluación por módulo', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),

        pw.Table(
          border: pw.TableBorder.all(color: _kBorder, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(40),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _kAzulOsc),
              children: [
                _thCell('#'),
                _thCell('Módulo'),
                _thCell('Estado'),
                _thCell('Pendientes'),
              ],
            ),
            ..._modulos.asMap().entries.map((e) {
              final m = e.value;
              final (color, txt) = switch (m.estado) {
                _Estado.completo => (_kVerde, 'Completo'),
                _Estado.beta     => (_kNaranja, 'Beta'),
                _Estado.parcial  => (_kRojo, 'Parcial'),
              };
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: e.key.isEven ? PdfColors.white : _kGrisCl,
                ),
                children: [
                  _tdCell('${e.key + 1}', center: true),
                  _tdCell('${m.icono} ${m.nombre}'),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Text(txt, style: pw.TextStyle(fontSize: 9, color: color, fontWeight: pw.FontWeight.bold)),
                  ),
                  _tdCell(m.pendiente.isEmpty ? '—' : '${m.pendiente.length} pendientes'),
                ],
              );
            }),
          ],
        ),
        pw.Spacer(),

        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _kAzulOsc,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Conclusión', style: pw.TextStyle(fontSize: 12, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(
              'Fluix es una plataforma SaaS madura con ${_modulos.length} módulos implementados. '
              '$completos módulos están completos y listos para producción. Los principales '
              'bloqueantes son: activación de Verifactu en producción, certificado Stripe, '
              'App Check Firebase, y pruebas de distribución en App Store / Google Play. '
              'Con $criticos elementos críticos resueltos, la plataforma puede desplegarse '
              'para los primeros clientes en producción.',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.white, lineSpacing: 3),
            ),
          ]),
        ),
        pw.SizedBox(height: 12),
        _piePagina('Resumen Ejecutivo'),
      ],
    ),
  );
}

pw.Widget _kpiCard(String valor, String label, PdfColor color) => pw.Expanded(
  child: pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: color.withAlpha(0.08),
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: color.withAlpha(0.3)),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(valor, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: color)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: pw.TextStyle(fontSize: 9.5, color: _kGris, lineSpacing: 2)),
    ]),
  ),
);

pw.Widget _thCell(String txt) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  child: pw.Text(txt, style: pw.TextStyle(fontSize: 9.5, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
);

pw.Widget _tdCell(String txt, {bool center = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  child: pw.Text(txt,
    textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
    style: pw.TextStyle(fontSize: 9.5)),
);

pw.Widget _cabecera(String titulo) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(titulo, style: pw.TextStyle(
      fontSize: 24, fontWeight: pw.FontWeight.bold, color: _kTexto)),
    pw.SizedBox(height: 6),
    pw.Container(width: 40, height: 3, color: _kAzul),
  ],
);

pw.Widget _piePagina(String seccion) => pw.Column(children: [
  pw.Divider(color: _kBorder),
  pw.SizedBox(height: 4),
  pw.Row(children: [
    pw.Text('Fluix · Documentación Técnica', style: pw.TextStyle(fontSize: 8.5, color: _kGris)),
    pw.Spacer(),
    pw.Text(seccion, style: pw.TextStyle(fontSize: 8.5, color: _kGris)),
    pw.Spacer(),
    pw.Text('Confidencial · Agosto 2026', style: pw.TextStyle(fontSize: 8.5, color: _kGris)),
  ]),
]);
