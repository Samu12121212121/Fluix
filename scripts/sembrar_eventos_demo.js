/**
 * sembrar_eventos_demo.js
 * ─────────────────────────────────────────────────────────────────
 * Crea reservas y tareas de prueba para los próximos 7 días
 * en la empresa del propietario (FluixTech).
 *
 * USO:
 *   node scripts/sembrar_eventos_demo.js
 *
 * Requisitos:
 *   - credentials.json en la raíz del proyecto
 *   - firebase-admin disponible (en functions/node_modules)
 * ─────────────────────────────────────────────────────────────────
 */

const admin = require("../functions/node_modules/firebase-admin");
const path  = require("path");

const SERVICE_ACCOUNT_PATH = path.join(__dirname, "..", "credentials.json");
const EMPRESA_ID = "37KyODVYpXYD04VwG3Vf";

let serviceAccount;
try {
  serviceAccount = require(SERVICE_ACCOUNT_PATH);
} catch (e) {
  console.error("❌ No se encontró credentials.json en la raíz del proyecto.");
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ── Datos de demo ──────────────────────────────────────────────────────────

const nombreReservas = [
  "Reunión con cliente",
  "Cita de asesoría",
  "Consulta inicial",
  "Revisión de proyecto",
  "Presentación de propuesta",
  "Reunión de equipo",
  "Cita con proveedor",
  "Entrega de presupuesto",
  "Seguimiento cliente",
  "Formación interna",
  "Demo del producto",
  "Llamada de seguimiento",
  "Reunión de cierre",
  "Auditoría interna",
];

const horasDisponibles = [
  "09:00", "09:30", "10:00", "10:30", "11:00", "11:30",
  "12:00", "12:30", "15:00", "15:30", "16:00", "16:30",
  "17:00", "17:30", "18:00",
];

const clientesDummy = [
  "Carlos Martínez", "Ana López", "Pedro Sánchez", "María García",
  "Luis Rodríguez", "Elena Fernández", "Javier Gómez", "Isabel Díaz",
  "Roberto Torres", "Carmen Ruiz",
];

const titulosTareas = [
  "Revisar contrato mensual",
  "Actualizar catálogo de productos",
  "Llamar a clientes pendientes",
  "Preparar informe semanal",
  "Enviar facturas del mes",
  "Revisar stock disponible",
  "Actualizar redes sociales",
  "Organizar archivos del servidor",
  "Responder emails atrasados",
  "Configurar nueva integración",
  "Formar al nuevo empleado",
  "Revisar métricas del negocio",
  "Actualizar precios del catálogo",
  "Gestionar devolución cliente",
];

const prioridades = ["alta", "media", "baja"];

// ── Utilidades ─────────────────────────────────────────────────────────────

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function randomBetween(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function shuffleArray(arr) {
  return arr.sort(() => Math.random() - 0.5);
}

// ── Semilla principal ──────────────────────────────────────────────────────

async function sembrar() {
  console.log(`\n🌱 Sembrando eventos demo en empresa: ${EMPRESA_ID}`);
  console.log("─".repeat(55));

  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);

  let totalReservas = 0;
  let totalTareas   = 0;
  const batch = db.batch();

  for (let dia = 0; dia < 7; dia++) {
    const fecha = new Date(hoy);
    fecha.setDate(hoy.getDate() + dia);
    const label = fecha.toLocaleDateString("es-ES", { weekday: "long", day: "numeric", month: "short" });

    // Número de eventos: 3..10 por día (mezcla reservas + tareas)
    const numEventos     = randomBetween(3, 10);
    const numReservas    = randomBetween(1, Math.min(numEventos - 1, 6));
    const numTareas      = numEventos - numReservas;

    console.log(`\n📅 ${label.charAt(0).toUpperCase() + label.slice(1)}: ${numReservas} reservas + ${numTareas} tareas`);

    // ── Reservas ───────────────────────────────────────────────────────────
    const horasRandom = shuffleArray([...horasDisponibles]).slice(0, numReservas);
    for (let r = 0; r < numReservas; r++) {
      const nombre = pick(nombreReservas);
      const hora   = horasRandom[r];
      const [h, m] = hora.split(":").map(Number);
      const fechaEvento = new Date(fecha);
      fechaEvento.setHours(h, m, 0, 0);

      const ref = db
        .collection("empresas").doc(EMPRESA_ID)
        .collection("reservas").doc();

      batch.set(ref, {
        nombre,
        cliente:   pick(clientesDummy),
        hora,
        fecha:     admin.firestore.Timestamp.fromDate(fechaEvento),
        estado:    pick(["pendiente", "confirmada"]),
        notas:     "Evento de prueba generado por script de demo",
        duracion:  pick([30, 45, 60, 90]),
        creado_en: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`   ✅ Reserva ${hora}: ${nombre}`);
      totalReservas++;
    }

    // ── Tareas ─────────────────────────────────────────────────────────────
    for (let t = 0; t < numTareas; t++) {
      const titulo    = pick(titulosTareas);
      const prioridad = pick(prioridades);
      const fechaLimite = new Date(fecha);
      fechaLimite.setHours(17, 0, 0, 0); // vencen a las 17:00

      const ref = db
        .collection("empresas").doc(EMPRESA_ID)
        .collection("tareas").doc();

      batch.set(ref, {
        titulo,
        descripcion:  "Tarea de prueba generada por script de demo",
        estado:       pick(["pendiente", "enProgreso"]),
        prioridad,
        fecha_limite: admin.firestore.Timestamp.fromDate(fechaLimite),
        fecha_creacion: admin.firestore.Timestamp.fromDate(new Date()),
        asignado_a:   null,
        modulo:       "general",
        etiquetas:    [],
      });

      const icono = prioridad === "alta" ? "🔴" : prioridad === "media" ? "🟡" : "🟢";
      console.log(`   ${icono} Tarea: ${titulo} [${prioridad}]`);
      totalTareas++;
    }
  }

  try {
    await batch.commit();
    console.log("\n─".repeat(55));
    console.log(`✅ Semilla completada:`);
    console.log(`   📆 ${totalReservas} reservas creadas`);
    console.log(`   📝 ${totalTareas} tareas creadas`);
    console.log(`   📊 Total: ${totalReservas + totalTareas} eventos en 7 días`);
  } catch (err) {
    console.error("❌ Error al hacer commit del batch:", err.message);
    process.exit(1);
  }

  process.exit(0);
}

sembrar().catch((err) => {
  console.error("❌ Error inesperado:", err);
  process.exit(1);
});
