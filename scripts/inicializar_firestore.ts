/**
 * inicializar_firestore.ts
 * ═════════════════════════════════════════════════════════════════════════════
 * Script idempotente para crear la estructura COMPLETA de Firestore
 * para Fluix CRM — Plataforma B2B multiempresa.
 *
 * USO:
 *   npx ts-node scripts/inicializar_firestore.ts
 *   — o —
 *   node scripts/inicializar_firestore.js   (si compilas primero con tsc)
 *
 * Requisitos:
 *   - credentials.json (Service Account) en la raíz del proyecto
 *   - firebase-admin instalado (usa el de functions/node_modules)
 *
 * ═════════════════════════════════════════════════════════════════════════════
 *
 * MAPA COMPLETO DE COLECCIONES FIRESTORE:
 *
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │ COLECCIONES RAÍZ                                                       │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │ usuarios/{userId}                                                       │
 * │ empresas/{empresaId}                                                    │
 * │ invitaciones/{token}                                                    │
 * │ login_intentos/{email}                                                  │
 * │ convenios/{convenioId}                                                  │
 * │ config/{configId}           (verifactu, verifactu_cert)                 │
 * │ plataforma_pagos/{pagoId}                                               │
 * │ notificaciones/{empresaId}/items/{itemId}                               │
 * │ vacaciones/{empresaId}/solicitudes/{solicitudId}                         │
 * │ vacaciones/{empresaId}/saldos/{empleadoId}                              │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │ SUBCOLECCIONES DE usuarios/{userId}                                     │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │ usuarios/{userId}/documentos/{docId}                                    │
 * │ usuarios/{userId}/embargos/{embargoId}                                  │
 * │ usuarios/{userId}/bajas_laborales/{bajaId}                              │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │ SUBCOLECCIONES DE empresas/{empresaId}                                  │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │ empresas/{id}/clientes/{clienteId}                                      │
 * │   └─ empresas/{id}/clientes/{cId}/actividad/{actId}                     │
 * │ empresas/{id}/empleados/{empleadoId}                                    │
 * │ empresas/{id}/servicios/{servicioId}                                    │
 * │ empresas/{id}/reservas/{reservaId}                                      │
 * │ empresas/{id}/facturas/{facturaId}                                      │
 * │ empresas/{id}/facturas_recibidas/{frId}                                 │
 * │ empresas/{id}/nominas/{nominaId}                                        │
 * │ empresas/{id}/pedidos/{pedidoId}                                        │
 * │ empresas/{id}/catalogo/{productoId}                                     │
 * │ empresas/{id}/tareas/{tareaId}                                          │
 * │   └─ empresas/{id}/tareas/{tId}/adjuntos/{adjId}                        │
 * │ empresas/{id}/equipos/{equipoId}                                        │
 * │ empresas/{id}/valoraciones/{valoracionId}                               │
 * │ empresas/{id}/finiquitos/{finiquitoId}                                  │
 * │ empresas/{id}/fichajes/{fichajeId}                                      │
 * │ empresas/{id}/gastos/{gastoId}                                          │
 * │ empresas/{id}/proveedores/{proveedorId}                                 │
 * │ empresas/{id}/remesas_sepa/{remesaId}                                   │
 * │ empresas/{id}/chats/{chatId}                                            │
 * │   └─ empresas/{id}/chats/{chatId}/mensajes/{msgId}                      │
 * │ empresas/{id}/bot_respuestas/{respuestaId}                              │
 * │ empresas/{id}/sugerencias/{sugerenciaId}                                │
 * │ empresas/{id}/contenido_web/{seccionId}                                 │
 * │ empresas/{id}/contacto_web/{contactoId}                                 │
 * │ empresas/{id}/blog/{articuloId}                                         │
 * │ empresas/{id}/rating_historial/{mesKey}                                 │
 * │ empresas/{id}/alertas/{alertaId}                                        │
 * │ empresas/{id}/alertas_certificado/{alertaId}                            │
 * │ empresas/{id}/dispositivos/{dispositivoId}                              │
 * │ empresas/{id}/festivos/{anio}/dias/{diaId}                              │
 * │ empresas/{id}/cache_contable/{docId}                                    │
 * │ empresas/{id}/suscripcion/actual                                        │
 * │ empresas/{id}/configuracion/modulos                                     │
 * │ empresas/{id}/configuracion/widgets                                     │
 * │ empresas/{id}/configuracion/facturacion                                 │
 * │ empresas/{id}/configuracion/fiscal                                      │
 * │ empresas/{id}/configuracion/general                                     │
 * │ empresas/{id}/configuracion/bot                                         │
 * │ empresas/{id}/configuracion/google_reviews                              │
 * │ empresas/{id}/configuracion/alertas_resenas                             │
 * │ empresas/{id}/estadisticas/resumen                                      │
 * │ empresas/{id}/estadisticas/web_resumen                                  │
 * │ empresas/{id}/estadisticas/trafico_web                                  │
 * │ convenios/{id}/categorias/{catId}                                       │
 * │ convenios/{id}/pluses/{plusId}                                           │
 * └─────────────────────────────────────────────────────────────────────────┘
 */

// ── IMPORTS ─────────────────────────────────────────────────────────────────

// firebase-admin se carga desde functions/node_modules (mismo patrón que activar_admin_plataforma.js)
// eslint-disable-next-line @typescript-eslint/no-require-imports
const admin = require("../functions/node_modules/firebase-admin"); // type: any — ok con strict:false
import * as path from "path";

// ── CONFIGURACIÓN ───────────────────────────────────────────────────────────

const SERVICE_ACCOUNT_PATH = path.join(__dirname, "..", "credentials.json");

const ADMIN_EMAIL = "admin@fluixcrm.app";
const ADMIN_UID = "admin-fluixcrm-uid";
const EMPRESA_EJEMPLO_ID = "empresa-ejemplo-test";

// ── CONTADORES ──────────────────────────────────────────────────────────────

let creados = 0;
let yaExistian = 0;

// ── INICIALIZAR FIREBASE ────────────────────────────────────────────────────

let serviceAccount: any;
try {
  serviceAccount = require(SERVICE_ACCOUNT_PATH);
} catch {
  console.error("❌ No se encontró credentials.json en la raíz del proyecto.");
  console.error(
    "   Descárgalo de: Firebase Console → Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada"
  );
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const NOW = admin.firestore.Timestamp.now();
const TS = admin.firestore.FieldValue.serverTimestamp();

// ── HELPER: Crear documento si no existe (idempotente) ──────────────────────

async function crearSiNoExiste(
  refPath: string,
  data: Record<string, any>
): Promise<void> {
  const ref = db.doc(refPath);
  const snap = await ref.get();
  if (snap.exists) {
    console.log(`  ⏭️  Ya existe: ${refPath}`);
    yaExistian++;
  } else {
    await ref.set(data);
    console.log(`  ✅ Creado:    ${refPath}`);
    creados++;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. COLECCIONES RAÍZ — USUARIOS
// ═════════════════════════════════════════════════════════════════════════════

async function crearUsuarioAdmin(): Promise<void> {
  console.log("\n══ 1. USUARIO ADMINISTRADOR ══");

  await crearSiNoExiste(`usuarios/${ADMIN_UID}`, {
    nombre: "Admin Fluix CRM",
    correo: ADMIN_EMAIL,
    telefono: "+34 900 000 000",
    empresa_id: EMPRESA_EJEMPLO_ID,
    rol: "propietario",
    activo: true,
    fecha_creacion: NOW,
    permisos: ["todo"],
    token_dispositivo: null,
    es_plataforma_admin: true,
    // datos_nomina embebido (para empleados)
    datos_nomina: {
      tipo_contrato: "indefinido",
      salario_bruto_anual: 30000,
      num_pagas: 14,
      pagas_prorrateadas: false,
      fecha_inicio_contrato: NOW,
      fecha_fin_contrato: null,
      grupo_profesional: "Grupo 1 — Ingenieros y Licenciados",
      categoria_convenio: null,
      convenio_id: null,
      comunidad_autonoma: "castillaMancha",
      estado_civil: "soltero",
      num_hijos: 0,
      discapacidad_porcentaje: 0,
      familia_numerosa: "no",
    },
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. COLECCIONES RAÍZ — EMPRESA
// ═════════════════════════════════════════════════════════════════════════════

async function crearEmpresaEjemplo(): Promise<void> {
  console.log("\n══ 2. EMPRESA DE EJEMPLO ══");

  const empresaId = EMPRESA_EJEMPLO_ID;

  // Documento raíz de empresa
  await crearSiNoExiste(`empresas/${empresaId}`, {
    nombre: "Empresa Demo SL",
    correo: "demo@fluixcrm.app",
    telefono: "+34 926 123 456",
    direccion: "Calle Mayor 1, Guadalajara",
    descripcion: "Empresa de demostración para testing Fluix CRM",
    sitio_web: "demo.fluixcrm.app",
    dominio: "demo.fluixcrm.app",
    categoria: "Hostelería",
    onboarding_completado: true,
    activa: true,
    fecha_creacion: NOW,
    // Campos fiscales (empresa_config)
    nif: "B19123456",
    razon_social: "Empresa Demo SL",
    domicilio_fiscal: "Calle Mayor 1, 19001 Guadalajara",
    codigo_postal: "19001",
    municipio: "Guadalajara",
    provincia: "Guadalajara",
    epigraf_iae: "6731",
    iban_empresa: "ES12 1234 5678 9012 3456 7890",
    bic_empresa: "CABORABBXXX",
    // Perfil embebido
    perfil: {
      nombre: "Empresa Demo SL",
      correo: "demo@fluixcrm.app",
      telefono: "+34 926 123 456",
      direccion: "Calle Mayor 1, Guadalajara",
      descripcion: "Empresa de demostración para testing",
      logo_url: null,
      fecha_creacion: NOW,
    },
    // Suscripción embebida (legacy — se usa también en subcolección)
    suscripcion: {
      estado: "activa",
      fecha_inicio: NOW,
      fecha_fin: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 365 * 24 * 60 * 60 * 1000)
      ),
      aviso_enviado: false,
      monto: 300,
      transaccion_id: null,
    },
    // Configuración embebida (legacy)
    configuracion: {
      modulos: {
        dashboard: true,
        reservas: true,
        clientes: true,
        servicios: true,
        empleados: true,
        facturacion: true,
        pedidos: true,
        tareas: true,
        nominas: true,
        valoraciones: true,
        estadisticas: true,
        web: true,
        whatsapp: false,
      },
      configuracion_modulos: {},
      criterio_iva: "devengo",
    },
    // Estadísticas embebidas (legacy)
    estadisticas: {
      total_clientes: 0,
      total_reservas: 0,
      total_servicios: 0,
      ingresos_mes: 0,
      ingresos_anio: 0,
      valoracion_promedio: 0,
      total_valoraciones: 0,
      fecha_actualizacion: NOW,
    },
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. SUBCOLECCIONES DE EMPRESA — CONFIGURACIÓN
// ═════════════════════════════════════════════════════════════════════════════

async function crearConfiguracionEmpresa(): Promise<void> {
  console.log("\n══ 3. CONFIGURACIÓN DE EMPRESA ══");

  const e = EMPRESA_EJEMPLO_ID;

  // 3.1 — Suscripción
  await crearSiNoExiste(`empresas/${e}/suscripcion/actual`, {
    estado: "ACTIVA",
    plan: "basico",
    plan_base: "basico",
    packs_activos: [],
    addons_activos: [],
    empleados_nomina: 0,
    precio_total: 300,
    fecha_inicio: NOW,
    fecha_fin: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 365 * 24 * 60 * 60 * 1000)
    ),
    aviso_enviado: false,
    ultimo_aviso: null,
    fecha_actualizacion: NOW,
  });

  // 3.2 — Módulos activos
  await crearSiNoExiste(`empresas/${e}/configuracion/modulos`, {
    modulos: [
      { id: "dashboard", activo: true },
      { id: "reservas", activo: true },
      { id: "citas", activo: false },
      { id: "clientes", activo: true },
      { id: "servicios", activo: true },
      { id: "empleados", activo: true },
      { id: "facturacion", activo: true },
      { id: "pedidos", activo: true },
      { id: "tareas", activo: true },
      { id: "nominas", activo: true },
      { id: "valoraciones", activo: true },
      { id: "estadisticas", activo: true },
      { id: "web", activo: true },
      { id: "whatsapp", activo: false },
    ],
    ultima_actualizacion: TS,
  });

  // 3.3 — Widgets del dashboard
  await crearSiNoExiste(`empresas/${e}/configuracion/widgets`, {
    widgets: [
      {
        id: "resumen_diario",
        activo: true,
        orden: 0,
        tamano: "grande",
      },
      {
        id: "ingresos_mes",
        activo: true,
        orden: 1,
        tamano: "mediano",
      },
      {
        id: "reservas_hoy",
        activo: true,
        orden: 2,
        tamano: "mediano",
      },
    ],
    ultima_actualizacion: TS,
  });

  // 3.4 — Contador de facturas
  await crearSiNoExiste(`empresas/${e}/configuracion/facturacion`, {
    ultimo_numero_factura: 0,
    anio_ultimo_factura: new Date().getFullYear(),
    "ultimo_numero_SerieFactura.normal": 0,
    "anio_ultimo_SerieFactura.normal": new Date().getFullYear(),
  });

  // 3.5 — Configuración fiscal
  await crearSiNoExiste(`empresas/${e}/configuracion/fiscal`, {
    nif: "B19123456",
    razon_social: "Empresa Demo SL",
    domicilio_fiscal: "Calle Mayor 1, 19001 Guadalajara",
    codigo_postal: "19001",
    municipio: "Guadalajara",
    provincia: "Guadalajara",
    regimen_iva: "general",
    epigraf_iae: "6731",
    esta_en_sii: false,
    criterio_iva: "devengo",
    iban_empresa: "ES12 1234 5678 9012 3456 7890",
    bic_empresa: "CABORABBXXX",
  });

  // 3.6 — Configuración general / web
  await crearSiNoExiste(`empresas/${e}/configuracion/general`, {
    fecha_instalacion_script: null,
    script_activo: false,
    dominio: "demo.fluixcrm.app",
    modulos_activos: {
      estadisticas: true,
      eventos: true,
      contenido_dinamico: true,
    },
  });

  // 3.7 — Configuración del chatbot
  await crearSiNoExiste(`empresas/${e}/configuracion/bot`, {
    activo: false,
    nombre_bot: "Fluix Bot",
    mensaje_bienvenida: "¡Hola! Soy el asistente virtual. ¿En qué puedo ayudarte?",
    mensaje_fallback: "No he entendido tu consulta. ¿Puedes reformularla?",
    horario_atencion: { inicio: "09:00", fin: "21:00" },
  });

  // 3.8 — Google Reviews
  await crearSiNoExiste(`empresas/${e}/configuracion/google_reviews`, {
    api_key: "",
    place_id: "",
    activo: false,
  });

  // 3.9 — Alertas de reseñas
  await crearSiNoExiste(`empresas/${e}/configuracion/alertas_resenas`, {
    umbral_estrellas: 3,
    notificar_push: true,
    notificar_email: false,
    email_destino: "",
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. SUBCOLECCIONES DE EMPRESA — ESTADÍSTICAS
// ═════════════════════════════════════════════════════════════════════════════

async function crearEstadisticasEmpresa(): Promise<void> {
  console.log("\n══ 4. ESTADÍSTICAS ══");

  const e = EMPRESA_EJEMPLO_ID;

  await crearSiNoExiste(`empresas/${e}/estadisticas/resumen`, {
    total_clientes: 0,
    total_reservas: 0,
    total_servicios: 0,
    ingresos_mes: 0,
    ingresos_anio: 0,
    valoracion_promedio: 0,
    total_valoraciones: 0,
    reservas_confirmadas: 0,
    total_empleados_activos: 0,
    nuevos_clientes_mes: 0,
    fecha_calculo: new Date().toISOString(),
    ultima_actualizacion: TS,
  });

  await crearSiNoExiste(`empresas/${e}/estadisticas/web_resumen`, {
    visitas_totales: 0,
    visitas_mes: 0,
    ultima_visita: null,
    sitio_web: "demo.fluixcrm.app",
    nombre_empresa: "Empresa Demo SL",
    total_valoraciones: 0,
    valoracion_promedio: 0.0,
    fecha_inicio_estadisticas: TS,
  });

  await crearSiNoExiste(`empresas/${e}/estadisticas/trafico_web`, {
    visitas_hoy: 0,
    visitas_semana: 0,
    visitas_mes: 0,
    paginas_mas_vistas: {},
    tiempo_medio_sesion: 0,
    tasa_rebote: 0,
    ultima_actualizacion: TS,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// 5. SUBCOLECCIONES DE EMPRESA — DATOS OPERATIVOS
// ═════════════════════════════════════════════════════════════════════════════

async function crearDatosOperativos(): Promise<void> {
  console.log("\n══ 5. DATOS OPERATIVOS ══");

  const e = EMPRESA_EJEMPLO_ID;

  // ── 5.1 Clientes ──────────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/clientes/cliente-demo-001`, {
    nombre: "Cliente Demo SL",
    telefono: "+34 600 111 222",
    correo: "contacto@clientedemo.com",
    nif: "B19000001",
    direccion: "Avda. Constitución 10, Guadalajara",
    localidad: "Guadalajara",
    total_gastado: 0,
    ultima_visita: null,
    numero_reservas: 0,
    etiquetas: ["Nuevo"],
    notas: "Cliente de prueba creado por inicialización",
    fecha_registro: NOW,
    activo: true,
    es_intracomunitario: false,
    nif_iva_comunitario: null,
    estado_cliente: "contacto",
    ficha_incompleta: false,
    no_contactar: false,
    estado_fusionado: false,
    fusionado_con_id: null,
    ultima_actividad: null,
  });

  // ── 5.2 Empleados ─────────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/empleados/empleado-demo-001`, {
    nombre: "Empleado Demo",
    rol: "staff",
    activo: true,
    permisos: ["reservas", "clientes"],
    uid: null,
    empresa_id: e,
    fecha_creacion: NOW,
  });

  // ── 5.3 Servicios ─────────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/servicios/servicio-demo-001`, {
    nombre: "Servicio de ejemplo",
    descripcion: "Servicio de demostración para testing",
    precio: 50.0,
    duracion_minutos: 60,
    empleado_asignado: null,
    categoria: "General",
    activo: true,
    imagenes: [],
    configuracion_adicional: {},
    empresa_id: e,
    fecha_creacion: NOW,
    fecha_modificacion: null,
  });

  // ── 5.4 Reservas ──────────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/reservas/reserva-demo-001`, {
    cliente_id: "cliente-demo-001",
    servicio_id: "servicio-demo-001",
    empleado_id: null,
    estado: "pendiente",
    fecha_hora: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 24 * 60 * 60 * 1000) // mañana
    ),
    duracion_minutos: 60,
    precio: 50.0,
    notas: "Reserva de prueba",
    notas_internas: null,
    fecha_creacion: NOW,
    fecha_modificacion: null,
    creado_por: ADMIN_UID,
  });

  // ── 5.5 Facturas emitidas ─────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/facturas/factura-demo-001`, {
    empresa_id: e,
    numero_factura: "F-2026-001",
    serie: "fac",
    tipo: "venta_directa",
    estado: "pendiente",
    cliente_nombre: "Cliente Demo SL",
    cliente_telefono: "+34 600 111 222",
    cliente_correo: "contacto@clientedemo.com",
    datos_fiscales: {
      nif: "B19000001",
      razon_social: "Cliente Demo SL",
      direccion: "Avda. Constitución 10",
      codigo_postal: "19001",
      ciudad: "Guadalajara",
      pais: "España",
      es_intracomunitario: false,
      nif_iva_comunitario: null,
    },
    lineas: [
      {
        descripcion: "Servicio de ejemplo",
        precio_unitario: 50.0,
        cantidad: 1,
        porcentaje_iva: 21.0,
      },
    ],
    subtotal: 50.0,
    total_iva: 10.5,
    total: 60.5,
    descuento_global: 0,
    importe_descuento_global: 0,
    porcentaje_irpf: 0,
    retencion_irpf: 0,
    total_recargo_equivalencia: 0,
    dias_vencimiento: 30,
    metodo_pago: null,
    pedido_id: null,
    factura_original_id: null,
    notas_internas: null,
    notas_cliente: null,
    verifactu: null,
    historial: [],
    fecha_emision: NOW,
    fecha_vencimiento: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
    ),
    fecha_pago: null,
    fecha_actualizacion: NOW,
  });

  // ── 5.6 Facturas recibidas ────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/facturas_recibidas/fr-demo-001`, {
    empresa_id: e,
    numero_factura: "PROV-2026-001",
    serie: null,
    fecha_emision: NOW,
    fecha_recepcion: NOW,
    nif_proveedor: "A28000001",
    nif_iva_comunitario: null,
    es_intracomunitario: false,
    nombre_proveedor: "Proveedor Demo SA",
    direccion_proveedor: "Calle Industrial 5, Madrid",
    telefono_proveedor: "+34 910 000 001",
    base_imponible: 100.0,
    porcentaje_iva: 21.0,
    importe_iva: 21.0,
    iva_deducible: true,
    descuento_global: 0,
    recargo_equivalencia: 0,
    total_con_impuestos: 121.0,
    porcentaje_retencion: null,
    importe_retencion: null,
    estado: "pendiente",
    fecha_pago: null,
    metodo_pago: null,
    referencia_bancaria: null,
    es_arrendamiento: false,
    nif_arrendador: null,
    concepto_arrendamiento: null,
    notas: null,
    fecha_creacion: NOW,
    fecha_actualizacion: null,
  });

  // ── 5.7 Nóminas ───────────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/nominas/nomina-demo-001`, {
    empresa_id: e,
    empleado_id: ADMIN_UID,
    empleado_nombre: "Admin Fluix CRM",
    mes: new Date().getMonth() + 1,
    anio: new Date().getFullYear(),
    estado: "borrador",
    tipo_contrato: "indefinido",
    salario_base_mensual: 2142.86,
    salario_bruto_anual: 30000,
    num_pagas: 14,
    pagas_prorrateadas: false,
    dias_trabajados: 30,
    dias_mes: 30,
    // Devengos
    total_devengado: 2142.86,
    // Deducciones
    base_cotizacion_ss: 2142.86,
    cuota_obrera_ss: 136.11,
    porcentaje_irpf: 12.0,
    retencion_irpf: 257.14,
    total_deducciones: 393.25,
    // Líquido
    liquido_percibir: 1749.61,
    fecha_creacion: NOW,
    fecha_aprobacion: null,
    fecha_pago: null,
  });

  // ── 5.8 Pedidos ───────────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/pedidos/pedido-demo-001`, {
    empresa_id: e,
    numero_pedido: "PED-2026-001",
    estado: "pendiente",
    origen: "app",
    cliente_nombre: "Cliente Demo SL",
    cliente_telefono: "+34 600 111 222",
    cliente_correo: "contacto@clientedemo.com",
    direccion_entrega: null,
    items: [
      {
        producto_id: "producto-demo-001",
        nombre: "Producto ejemplo",
        cantidad: 1,
        precio_unitario: 25.0,
        variante: null,
      },
    ],
    subtotal: 25.0,
    iva: 5.25,
    total: 30.25,
    metodo_pago: "efectivo",
    estado_pago: "pendiente",
    notas: "Pedido de prueba",
    fecha_creacion: NOW,
    fecha_entrega: null,
    fecha_actualizacion: null,
  });

  // ── 5.9 Catálogo (productos) ──────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/catalogo/producto-demo-001`, {
    empresa_id: e,
    nombre: "Producto de ejemplo",
    descripcion: "Producto de demostración para testing",
    categoria: "General",
    precio: 25.0,
    imagen_url: null,
    thumbnail_url: null,
    stock: 100,
    activo: true,
    destacado: false,
    tiene_variantes: false,
    duracion_minutos: null,
    iva_porcentaje: 21,
    sku: "DEMO-001",
    codigo_barras: null,
    variantes: [],
    etiquetas: ["demo"],
    fecha_creacion: NOW,
    fecha_actualizacion: null,
  });

  // ── 5.10 Tareas ───────────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/tareas/tarea-demo-001`, {
    empresa_id: e,
    titulo: "Tarea de ejemplo",
    descripcion: "Tarea creada por el script de inicialización",
    tipo: "normal",
    estado: "pendiente",
    prioridad: "media",
    equipo_id: null,
    usuario_asignado_id: ADMIN_UID,
    creado_por_id: ADMIN_UID,
    fecha_limite: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    ),
    etiquetas: ["demo"],
    ubicacion: null,
    tiempo_estimado_min: 60,
    subtareas: [],
    registro_tiempo: [],
    historial: [],
    es_recurrente: false,
    frecuencia_recurrencia: null,
    solo_propietario: false,
    sugerencia_id: null,
    cliente_id: null,
    fecha_creacion: NOW,
    fecha_actualizacion: null,
  });

  // ── 5.11 Equipos ──────────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/equipos/equipo-demo-001`, {
    empresa_id: e,
    nombre: "Equipo general",
    descripcion: "Equipo por defecto",
    responsable_id: ADMIN_UID,
    miembros_ids: [ADMIN_UID],
    fecha_creacion: NOW,
  });

  // ── 5.12 Valoraciones ─────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/valoraciones/valoracion-demo-001`, {
    cliente: "Cliente Demo SL",
    calificacion: 5,
    estrellas: 5,
    comentario: "Excelente servicio, muy recomendable.",
    origen: "app",
    fecha: NOW,
    respondida: false,
    respuesta: null,
    fecha_respuesta: null,
  });

  // ── 5.13 Finiquitos ───────────────────────────────────────────────────────
  // (Se crea vacío — los finiquitos se generan bajo demanda)
  console.log("  ℹ️  empresas/${e}/finiquitos — se crean bajo demanda");

  // ── 5.14 Fichajes ─────────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/fichajes/fichaje-demo-001`, {
    empleado_id: ADMIN_UID,
    empresa_id: e,
    empleado_nombre: "Admin Fluix CRM",
    tipo: "entrada",
    timestamp: NOW,
    latitud: 40.6328,
    longitud: -3.1669,
    editado_por_admin: false,
    notas: null,
  });

  // ── 5.15 Gastos ───────────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/gastos/gasto-demo-001`, {
    empresa_id: e,
    concepto: "Material de oficina",
    importe: 45.0,
    categoria: "suministros",
    fecha: NOW,
    proveedor_id: "proveedor-demo-001",
    proveedor_nombre: "Proveedor Demo SA",
    factura_id: null,
    deducible: true,
    notas: "Gasto de prueba",
    fecha_creacion: NOW,
  });

  // ── 5.16 Proveedores ──────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/proveedores/proveedor-demo-001`, {
    id: "proveedor-demo-001",
    nombre: "Proveedor Demo SA",
    nif: "A28000001",
    email: "proveedor@demo.com",
    telefono: "+34 910 000 001",
    direccion: "Calle Industrial 5",
    ciudad: "Madrid",
    codigo_postal: "28001",
    categoria: "suministros",
    activo: true,
    es_intracomunitario: false,
    nif_iva_comunitario: null,
    fecha_alta: NOW,
    notas: null,
  });

  // ── 5.17 Remesas SEPA ─────────────────────────────────────────────────────
  console.log("  ℹ️  empresas/${e}/remesas_sepa — se crean bajo demanda");

  // ── 5.18 Chats y Bot ──────────────────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/chats/chat-demo-001`, {
    empresa_id: e,
    canal: "web",
    estado: "activo",
    cliente_nombre: "Visitante web",
    cliente_telefono: null,
    fecha_inicio: NOW,
    fecha_ultimo_mensaje: NOW,
    mensajes_count: 0,
  });

  await crearSiNoExiste(`empresas/${e}/bot_respuestas/resp-demo-001`, {
    id: "resp-demo-001",
    palabras_clave: ["horario", "hora", "abierto"],
    respuesta: "Nuestro horario es de lunes a viernes de 9:00 a 21:00.",
    intent: "consultarHorario",
    activa: true,
  });

  // ── 5.19 Sugerencias ──────────────────────────────────────────────────────
  console.log("  ℹ️  empresas/${e}/sugerencias — se crean bajo demanda");

  // ── 5.20 Contenido web (secciones) ────────────────────────────────────────
  await crearSiNoExiste(`empresas/${e}/contenido_web/seccion-demo-001`, {
    id: "seccion-demo-001",
    nombre: "Bienvenida",
    descripcion: "Sección de bienvenida de la web",
    activa: true,
    tipo: "texto",
    contenido: {
      titulo: "Bienvenido a nuestra empresa",
      texto: "Somos una empresa de demostración para testing.",
      imagen_url: null,
    },
    orden: 0,
    fecha_creacion: NOW,
    fecha_actualizacion: null,
  });

  // ── 5.21 Contacto web ─────────────────────────────────────────────────────
  console.log("  ℹ️  empresas/${e}/contacto_web — se crean bajo demanda");

  // ── 5.22 Blog ─────────────────────────────────────────────────────────────
  console.log("  ℹ️  empresas/${e}/blog — se crean bajo demanda");

  // ── 5.23 Rating historial ─────────────────────────────────────────────────
  const mesKey = `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, "0")}`;
  await crearSiNoExiste(`empresas/${e}/rating_historial/${mesKey}`, {
    mes: mesKey,
    rating_medio: 5.0,
    total_resenas: 1,
    fecha_actualizacion: NOW,
  });

  // ── 5.24 Alertas (catálogo) ───────────────────────────────────────────────
  console.log("  ℹ️  empresas/${e}/alertas — se crean por Cloud Functions");

  // ── 5.25 Alertas certificado ──────────────────────────────────────────────
  console.log("  ℹ️  empresas/${e}/alertas_certificado — se crean por Cloud Functions");

  // ── 5.26 Dispositivos (push tokens) ───────────────────────────────────────
  console.log("  ℹ️  empresas/${e}/dispositivos — se registran al hacer login");

  // ── 5.27 Festivos ─────────────────────────────────────────────────────────
  const anio = new Date().getFullYear();
  await crearSiNoExiste(
    `empresas/${e}/festivos/${anio}/dias/01-01`,
    {
      fecha: admin.firestore.Timestamp.fromDate(new Date(anio, 0, 1)),
      nombre: "Año Nuevo",
      tipo: "nacional",
      codigo_comunidad: null,
      es_local: false,
    }
  );

  // ── 5.28 Caché contable ───────────────────────────────────────────────────
  console.log("  ℹ️  empresas/${e}/cache_contable — se genera automáticamente");
}

// ═════════════════════════════════════════════════════════════════════════════
// 6. SUBCOLECCIONES DE USUARIO — DOCUMENTOS, EMBARGOS, BAJAS
// ═════════════════════════════════════════════════════════════════════════════

async function crearSubcoleccionesUsuario(): Promise<void> {
  console.log("\n══ 6. SUBCOLECCIONES DE USUARIO ══");

  const uid = ADMIN_UID;

  // Documentos de empleado (placeholder vacío — se suben por la app)
  console.log(`  ℹ️  usuarios/${uid}/documentos — se suben por la app`);

  // Embargos (placeholder vacío — se crean por la app)
  console.log(`  ℹ️  usuarios/${uid}/embargos — se crean bajo demanda`);

  // Bajas laborales (placeholder vacío — se crean por la app)
  console.log(`  ℹ️  usuarios/${uid}/bajas_laborales — se crean bajo demanda`);
}

// ═════════════════════════════════════════════════════════════════════════════
// 7. COLECCIONES RAÍZ — INVITACIONES
// ═════════════════════════════════════════════════════════════════════════════

async function crearInvitaciones(): Promise<void> {
  console.log("\n══ 7. INVITACIONES ══");

  await crearSiNoExiste("invitaciones/token-demo-001", {
    token: "token-demo-001",
    email: "empleado@demo.com",
    rol: "staff",
    empresa_id: EMPRESA_EJEMPLO_ID,
    empresa_nombre: "Empresa Demo SL",
    creado_por: ADMIN_UID,
    expira: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 48 * 60 * 60 * 1000)
    ),
    usado: false,
    fecha_creacion: NOW,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// 8. COLECCIONES RAÍZ — LOGIN INTENTOS
// ═════════════════════════════════════════════════════════════════════════════

async function crearLoginIntentos(): Promise<void> {
  console.log("\n══ 8. LOGIN INTENTOS ══");

  // Documento de ejemplo (se crea y borra por la Cloud Function verificarLoginIntento)
  await crearSiNoExiste("login_intentos/demo@example.com", {
    intentos: 0,
    bloqueado: false,
    ultimo_intento: NOW,
    fecha_bloqueo: null,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// 9. COLECCIONES RAÍZ — NOTIFICACIONES
// ═════════════════════════════════════════════════════════════════════════════

async function crearNotificaciones(): Promise<void> {
  console.log("\n══ 9. NOTIFICACIONES ══");

  const e = EMPRESA_EJEMPLO_ID;

  await crearSiNoExiste(`notificaciones/${e}/items/notif-demo-001`, {
    titulo: "Bienvenido a Fluix CRM",
    cuerpo: "Tu empresa ha sido configurada correctamente.",
    tipo: "reserva_nueva",
    timestamp: NOW,
    leida: false,
    modulo_destino: "reservas",
    entidad_id: null,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// 10. COLECCIONES RAÍZ — VACACIONES
// ═════════════════════════════════════════════════════════════════════════════

async function crearVacaciones(): Promise<void> {
  console.log("\n══ 10. VACACIONES ══");

  const e = EMPRESA_EJEMPLO_ID;
  const anio = new Date().getFullYear();

  // Solicitud de ejemplo
  await crearSiNoExiste(`vacaciones/${e}/solicitudes/solicitud-demo-001`, {
    empleado_id: ADMIN_UID,
    empleado_nombre: "Admin Fluix CRM",
    tipo: "vacaciones",
    subtipo_permiso: null,
    estado: "pendiente",
    fecha_inicio: admin.firestore.Timestamp.fromDate(
      new Date(anio, 7, 1) // 1 de agosto
    ),
    fecha_fin: admin.firestore.Timestamp.fromDate(
      new Date(anio, 7, 15) // 15 de agosto
    ),
    dias_naturales: 15,
    dias_laborables: 11,
    notas: "Vacaciones de verano",
    aprobado_por: null,
    fecha_solicitud: NOW,
    fecha_respuesta: null,
    motivo_rechazo: null,
  });

  // Saldo de vacaciones
  await crearSiNoExiste(`vacaciones/${e}/saldos/${ADMIN_UID}`, {
    empleado_id: ADMIN_UID,
    anio: anio,
    dias_devengados: 30,
    dias_disfrutados: 0,
    dias_pendientes: 30,
    dias_pendientes_ano_anterior: 0,
    ultima_actualizacion: NOW,
    dias_arrastre: 0,
    dias_arrastre_consumidos: 0,
    fecha_expiracion_arrastre: null,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// 11. COLECCIONES RAÍZ — CONVENIOS COLECTIVOS
// ═════════════════════════════════════════════════════════════════════════════

async function crearConveniosColectivos(): Promise<void> {
  console.log("\n══ 11. CONVENIOS COLECTIVOS ══");

  const convenioId = "hosteleria-guadalajara";

  await crearSiNoExiste(`convenios/${convenioId}`, {
    id: convenioId,
    nombre: "Convenio Colectivo de Hostelería de Guadalajara",
    ambito: "Provincial",
    sector: "Hostelería",
    vigencia: {
      inicio: "2025-01-01",
      fin: "2027-12-31",
    },
  });

  // Categoría de ejemplo
  await crearSiNoExiste(`convenios/${convenioId}/categorias/cat-001`, {
    id: "cat-001",
    nombre: "Camarero/a de primera",
    grupo_profesional: "Grupo 5 — Personal de Sala",
    salario_base_mensual: 1200.0,
    salario_anual: 16800.0,
    num_pagas: 14,
  });

  // Plus de ejemplo
  await crearSiNoExiste(`convenios/${convenioId}/pluses/plus-001`, {
    id: "plus-001",
    nombre: "Plus de transporte",
    tipo: "fijo",
    importe: 60.0,
    base_calculo: null,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// 12. COLECCIONES RAÍZ — CONFIG GLOBAL (Verifactu, etc.)
// ═════════════════════════════════════════════════════════════════════════════

async function crearConfigGlobal(): Promise<void> {
  console.log("\n══ 12. CONFIGURACIÓN GLOBAL ══");

  await crearSiNoExiste("config/verifactu", {
    endpoint_produccion: "https://www1.agenciatributaria.gob.es/wlpl/TIKE-CONT/ws/SistemaFacturacion/SuministroFactEmitidas",
    endpoint_pruebas: "https://prewww1.aeat.es/wlpl/TIKE-CONT/ws/SistemaFacturacion/SuministroFactEmitidas",
    usar_pruebas: true,
    version: "1.0",
  });

  await crearSiNoExiste("config/verifactu_cert", {
    alias: "certificado_pruebas",
    password_encrypted: "",
    tipo: "software",
    fecha_carga: NOW,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// 13. COLECCIONES RAÍZ — PLATAFORMA PAGOS
// ═════════════════════════════════════════════════════════════════════════════

async function crearPlataformaPagos(): Promise<void> {
  console.log("\n══ 13. PLATAFORMA PAGOS ══");

  // Solo log — los documentos se crean por el webhook de Stripe
  console.log("  ℹ️  plataforma_pagos — se crean por webhook de Stripe");
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN
// ═════════════════════════════════════════════════════════════════════════════

async function main(): Promise<void> {
  console.log("╔═══════════════════════════════════════════════════════════════╗");
  console.log("║         FLUIX CRM — Inicialización de Firestore              ║");
  console.log("║         Script idempotente — seguro de re-ejecutar            ║");
  console.log("╚═══════════════════════════════════════════════════════════════╝");
  console.log(`\n📅 Fecha: ${new Date().toISOString()}`);
  console.log(`🏢 Empresa: ${EMPRESA_EJEMPLO_ID}`);
  console.log(`👤 Admin:   ${ADMIN_EMAIL}\n`);

  try {
    // Orden correcto: primero usuarios, luego empresas, luego relaciones
    await crearUsuarioAdmin();
    await crearEmpresaEjemplo();
    await crearConfiguracionEmpresa();
    await crearEstadisticasEmpresa();
    await crearDatosOperativos();
    await crearSubcoleccionesUsuario();
    await crearInvitaciones();
    await crearLoginIntentos();
    await crearNotificaciones();
    await crearVacaciones();
    await crearConveniosColectivos();
    await crearConfigGlobal();
    await crearPlataformaPagos();

    // ── RESUMEN FINAL ──────────────────────────────────────────────────────
    console.log("\n╔═══════════════════════════════════════════════════════════════╗");
    console.log("║                     RESUMEN FINAL                             ║");
    console.log("╠═══════════════════════════════════════════════════════════════╣");
    console.log(`║  ✅ Documentos creados:      ${String(creados).padStart(4)}                          ║`);
    console.log(`║  ⏭️  Documentos ya existían:  ${String(yaExistian).padStart(4)}                          ║`);
    console.log(`║  📄 Total procesados:        ${String(creados + yaExistian).padStart(4)}                          ║`);
    console.log("╚═══════════════════════════════════════════════════════════════╝");

    if (creados > 0) {
      console.log("\n🎉 ¡Firestore inicializado correctamente!");
    } else {
      console.log("\n✨ Todos los documentos ya existían. Firestore está al día.");
    }

    console.log("\n📋 COLECCIONES CREADAS:");
    console.log("   Raíz: usuarios, empresas, invitaciones, login_intentos,");
    console.log("         convenios, config, notificaciones, vacaciones");
    console.log("   Empresa: clientes, empleados, servicios, reservas, facturas,");
    console.log("            facturas_recibidas, nominas, pedidos, catalogo,");
    console.log("            tareas, equipos, valoraciones, finiquitos, fichajes,");
    console.log("            gastos, proveedores, remesas_sepa, chats,");
    console.log("            bot_respuestas, sugerencias, contenido_web,");
    console.log("            contacto_web, blog, rating_historial, alertas,");
    console.log("            alertas_certificado, dispositivos, festivos,");
    console.log("            cache_contable, suscripcion, configuracion, estadisticas");
    console.log("   Usuario: documentos, embargos, bajas_laborales");
    console.log("   Convenio: categorias, pluses\n");
  } catch (error) {
    console.error("\n❌ Error durante la inicialización:", error);
    process.exit(1);
  }

  process.exit(0);
}

main();



