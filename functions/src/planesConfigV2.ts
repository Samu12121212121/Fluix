/**
 * planesConfigV2.ts
 * ═════════════════════════════════════════════════════════════════════════════
 * Definición canónica de planes V2 — Fuente única de verdad (Cloud Functions)
 *
 * Debe mantenerse en sincronía con:
 *   lib/core/config/planes_config.dart (Flutter)
 *
 * Estructura:
 *   Plan Base + Packs acumulables + Add-ons independientes
 *   Los módulos activos se calculan dinámicamente.
 * ═════════════════════════════════════════════════════════════════════════════
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

// Guard: el módulo puede cargarse antes de que index.ts llame initializeApp()
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const REGION = "europe-west1";

// ─────────────────────────────────────────────────────────────────────────────
// PLAN BASE
// ─────────────────────────────────────────────────────────────────────────────

export const PLAN_BASE = {
  id: "basico",
  nombre: "Plan Base",
  precioAnual: 300,
  modulosIncluidos: [
    "dashboard",
    "reservas",
    "citas",
    "clientes",
    "servicios",
    "empleados",
    "valoraciones",
    "estadisticas",
    "contenido_web",
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// PACKS
// ─────────────────────────────────────────────────────────────────────────────

export const PACKS: Record<string, {
  id: string; nombre: string; precioAnual: number; modulosAdicionales: string[];
}> = {
  gestion: {
    id: "gestion",
    nombre: "Pack Gestión",
    precioAnual: 350,
    modulosAdicionales: ["facturacion", "vacaciones"],
  },
  tienda: {
    id: "tienda",
    nombre: "Pack Tienda Online",
    precioAnual: 150,
    modulosAdicionales: ["pedidos"],
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// ADD-ONS
// ─────────────────────────────────────────────────────────────────────────────

export const ADDONS: Record<string, {
  id: string; nombre: string; precioAnual: number | null; modulosAdicionales: string[];
}> = {
  whatsapp: {
    id: "whatsapp",
    nombre: "WhatsApp",
    precioAnual: 50,
    modulosAdicionales: ["whatsapp"],
  },
  tareas: {
    id: "tareas",
    nombre: "Tareas",
    precioAnual: null,
    modulosAdicionales: ["tareas"],
  },
  nominas: {
    id: "nominas",
    nombre: "Nóminas",
    precioAnual: null,
    modulosAdicionales: ["nominas"],
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/** Calcula módulos activos a partir de packs y addons */
export function calcularModulosActivos(
  packsActivos: string[],
  addonsActivos: string[]
): string[] {
  const modulos = new Set<string>(PLAN_BASE.modulosIncluidos);

  for (const packId of packsActivos) {
    const pack = PACKS[packId];
    if (pack) {
      pack.modulosAdicionales.forEach((m) => modulos.add(m));
    }
  }

  for (const addonId of addonsActivos) {
    const addon = ADDONS[addonId];
    if (addon) {
      addon.modulosAdicionales.forEach((m) => modulos.add(m));
    }
  }

  return Array.from(modulos);
}

/** Calcula precio total anual */
export function calcularPrecioTotal(
  packsActivos: string[],
  addonsActivos: string[]
): number {
  let total = PLAN_BASE.precioAnual;

  for (const packId of packsActivos) {
    const pack = PACKS[packId];
    if (pack) total += pack.precioAnual;
  }

  for (const addonId of addonsActivos) {
    const addon = ADDONS[addonId];
    if (addon && addon.precioAnual !== null) total += addon.precioAnual;
  }

  return total;
}

/** Verifica que el usuario sea admin de la plataforma */
async function verificarPropietarioPlatforma(uid: string): Promise<void> {
  const doc = await db.collection("usuarios").doc(uid).get();
  if (!doc.exists || doc.data()?.es_plataforma_admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Solo el propietario de la plataforma puede realizar esta acción."
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FUNCIÓN: actualizarModulosSegunPlan
// ═════════════════════════════════════════════════════════════════════════════
/**
 * Callable. Recalcula configuracion/modulos a partir de la suscripción.
 *
 * data: { empresaId: string }
 */
export const actualizarModulosSegunPlan = onCall(
  { region: REGION },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado.");
    }

    await verificarPropietarioPlatforma(callerUid);

    const { empresaId } = request.data as { empresaId: string };
    if (!empresaId) {
      throw new HttpsError("invalid-argument", "empresaId es obligatorio.");
    }

    // 1. Leer suscripción
    const suscripcionSnap = await db
      .collection("empresas")
      .doc(empresaId)
      .collection("suscripcion")
      .doc("actual")
      .get();

    if (!suscripcionSnap.exists) {
      throw new HttpsError("not-found", "No existe suscripción para esta empresa.");
    }

    const suscripcionData = suscripcionSnap.data()!;
    const packsActivos = (suscripcionData.packs_activos as string[]) || [];
    const addonsActivos = (suscripcionData.addons_activos as string[]) || [];

    // 2. Calcular módulos
    const modulosActivos = calcularModulosActivos(packsActivos, addonsActivos);

    // 3. Escribir en configuracion/modulos (formato legacy compatible)
    const modulosMap: Record<string, boolean> = {};
    modulosActivos.forEach((m) => {
      modulosMap[m] = true;
    });

    // También escribir como array para compatibilidad
    await db
      .collection("empresas")
      .doc(empresaId)
      .collection("configuracion")
      .doc("modulos")
      .set(
        {
          ...modulosMap,
          modulos: modulosActivos.map((m) => ({ id: m, activo: true })),
          fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
          generado_por: "actualizarModulosSegunPlan",
        },
        { merge: false }
      );

    console.log(
      `✅ Módulos actualizados para empresa=${empresaId}: ${modulosActivos.join(", ")}`
    );

    return {
      ok: true,
      empresaId,
      modulosActivos,
      totalModulos: modulosActivos.length,
    };
  }
);

// ═════════════════════════════════════════════════════════════════════════════
// FUNCIÓN: migracionPlanesV2
// ═════════════════════════════════════════════════════════════════════════════
/**
 * Callable. Migra TODAS las empresas existentes al nuevo formato de planes V2.
 * Infiere packs y addons desde los módulos activos actuales.
 *
 * ⚠️ EJECUTAR UNA SOLA VEZ EN PRODUCCIÓN ⚠️
 * Es idempotente: si ya tiene packs_activos, no la sobrescribe.
 *
 * data: { dryRun?: boolean }  — si dryRun=true, solo loguea sin escribir
 */
export const migracionPlanesV2 = onCall(
  { region: REGION, timeoutSeconds: 300 },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado.");
    }

    await verificarPropietarioPlatforma(callerUid);

    const { dryRun = false } = request.data as { dryRun?: boolean };
    const resultados: Array<{
      empresaId: string;
      nombre: string;
      planAnterior: string;
      packsInferidos: string[];
      addonsInferidos: string[];
      precioTotal: number;
      yaTeníaV2: boolean;
    }> = [];

    // 1. Leer todas las empresas
    const empresasSnap = await db.collection("empresas").get();
    console.log(`📦 Migrando ${empresasSnap.size} empresas (dryRun=${dryRun})...`);

    for (const empresaDoc of empresasSnap.docs) {
      const empresaId = empresaDoc.id;
      const empresaData = empresaDoc.data();
      const nombre = (empresaData.nombre as string) || "—";

      try {
        // 2. Leer suscripción actual
        const suscSnap = await empresaDoc.ref
          .collection("suscripcion")
          .doc("actual")
          .get();

        if (!suscSnap.exists) {
          console.log(`⚠️ ${empresaId} (${nombre}): sin suscripción — omitida`);
          continue;
        }

        const suscData = suscSnap.data()!;

        // 3. Si ya tiene formato V2, saltar
        if (suscData.packs_activos !== undefined) {
          resultados.push({
            empresaId,
            nombre,
            planAnterior: suscData.plan || "—",
            packsInferidos: suscData.packs_activos || [],
            addonsInferidos: suscData.addons_activos || [],
            precioTotal: suscData.precio_total || 0,
            yaTeníaV2: true,
          });
          console.log(`✅ ${empresaId} (${nombre}): ya tiene V2 — omitida`);
          continue;
        }

        // 4. Leer módulos actuales
        const configSnap = await empresaDoc.ref
          .collection("configuracion")
          .doc("modulos")
          .get();
        const configData = configSnap.data() || {};

        // Obtener módulos activos (del campo modulos_activos de suscripción
        // o de las claves true en configuracion/modulos)
        let modulosActuales: string[] = [];
        if (suscData.modulos_activos && Array.isArray(suscData.modulos_activos)) {
          modulosActuales = suscData.modulos_activos;
        } else {
          // Inferir desde configuracion/modulos
          modulosActuales = Object.keys(configData).filter(
            (k) => k !== "fecha_actualizacion" && k !== "generado_por" && k !== "modulos"
          );
        }

        // 5. Inferir packs
        const packs: string[] = [];
        if (
          modulosActuales.includes("facturacion") ||
          modulosActuales.includes("vacaciones")
        ) {
          packs.push("gestion");
        }
        if (modulosActuales.includes("pedidos")) {
          packs.push("tienda");
        }

        // 6. Inferir addons
        const addons: string[] = [];
        if (modulosActuales.includes("whatsapp")) addons.push("whatsapp");
        if (modulosActuales.includes("tareas")) addons.push("tareas");
        if (modulosActuales.includes("nominas")) addons.push("nominas");

        // 7. Calcular precio
        const precioTotal = calcularPrecioTotal(packs, addons);

        const planAnterior = (suscData.plan as string) || "basico";

        resultados.push({
          empresaId,
          nombre,
          planAnterior,
          packsInferidos: packs,
          addonsInferidos: addons,
          precioTotal,
          yaTeníaV2: false,
        });

        // 8. Escribir (si no es dryRun)
        if (!dryRun) {
          await suscSnap.ref.set(
            {
              plan_base: "basico",
              packs_activos: packs,
              addons_activos: addons,
              empleados_nomina: 0,
              precio_total: precioTotal,
              fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
              // Mantener campos legacy
              plan: planAnterior,
            },
            { merge: true }
          );

          console.log(
            `✅ ${empresaId} (${nombre}): migrada — packs=[${packs}] addons=[${addons}] precio=${precioTotal}€`
          );
        } else {
          console.log(
            `🔍 [DRY] ${empresaId} (${nombre}): packs=[${packs}] addons=[${addons}] precio=${precioTotal}€`
          );
        }
      } catch (err) {
        console.error(`❌ Error migrando ${empresaId} (${nombre}):`, err);
      }
    }

    console.log(`\n📊 Migración completada: ${resultados.length} empresas procesadas`);

    return {
      ok: true,
      dryRun,
      totalEmpresas: empresasSnap.size,
      empresasMigradas: resultados.filter((r) => !r.yaTeníaV2).length,
      empresasYaV2: resultados.filter((r) => r.yaTeníaV2).length,
      resultados,
    };
  }
);

// ═════════════════════════════════════════════════════════════════════════════
// FUNCIÓN: actualizarPlanEmpresaV2
// ═════════════════════════════════════════════════════════════════════════════
/**
 * Callable. Actualiza el plan de una empresa con el nuevo formato V2.
 * Reemplaza a actualizarPlanEmpresa para el nuevo sistema de packs.
 *
 * data: {
 *   empresaId: string
 *   packsActivos: string[]     — ['gestion', 'tienda']
 *   addonsActivos: string[]    — ['whatsapp', 'tareas']
 *   empleadosNomina?: number
 *   extenderDias?: number      — si 0 mantiene fecha, si >0 extiende
 * }
 */
export const actualizarPlanEmpresaV2 = onCall(
  { region: REGION },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado.");
    }

    await verificarPropietarioPlatforma(callerUid);

    const {
      empresaId,
      packsActivos = [],
      addonsActivos = [],
      empleadosNomina = 0,
      extenderDias = 365,
    } = request.data as {
      empresaId: string;
      packsActivos: string[];
      addonsActivos: string[];
      empleadosNomina?: number;
      extenderDias?: number;
    };

    if (!empresaId) {
      throw new HttpsError("invalid-argument", "empresaId es obligatorio.");
    }

    // Validar packs
    for (const p of packsActivos) {
      if (!PACKS[p]) {
        throw new HttpsError("invalid-argument", `Pack desconocido: ${p}`);
      }
    }
    // Validar addons
    for (const a of addonsActivos) {
      if (!ADDONS[a]) {
        throw new HttpsError("invalid-argument", `Add-on desconocido: ${a}`);
      }
    }

    // Calcular
    const modulosActivos = calcularModulosActivos(packsActivos, addonsActivos);
    const precioTotal = calcularPrecioTotal(packsActivos, addonsActivos);

    // Leer suscripción actual para fecha_fin
    const suscripcionRef = db
      .collection("empresas")
      .doc(empresaId)
      .collection("suscripcion")
      .doc("actual");

    const suscripcionSnap = await suscripcionRef.get();
    let fechaFin: Date;

    if (suscripcionSnap.exists && extenderDias === 0) {
      fechaFin = suscripcionSnap.data()?.fecha_fin?.toDate() ?? new Date();
    } else {
      fechaFin = new Date();
      fechaFin.setDate(fechaFin.getDate() + (extenderDias || 365));
    }

    const batch = db.batch();

    // 1. Actualizar suscripción
    batch.set(
      suscripcionRef,
      {
        plan_base: "basico",
        plan: "basico", // Mantener campo legacy
        packs_activos: packsActivos,
        addons_activos: addonsActivos,
        empleados_nomina: empleadosNomina,
        precio_total: precioTotal,
        estado: "ACTIVA",
        fecha_fin: admin.firestore.Timestamp.fromDate(fechaFin),
        actualizado_por: callerUid,
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 2. Actualizar empresa
    batch.update(db.collection("empresas").doc(empresaId), {
      plan_id: "basico",
      fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 3. Recalcular configuracion/modulos
    const modulosMap: Record<string, boolean> = {};
    modulosActivos.forEach((m) => {
      modulosMap[m] = true;
    });

    batch.set(
      db.collection("empresas").doc(empresaId).collection("configuracion").doc("modulos"),
      {
        ...modulosMap,
        modulos: modulosActivos.map((m) => ({ id: m, activo: true })),
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
        generado_por: "actualizarPlanEmpresaV2",
      },
      { merge: false }
    );

    await batch.commit();

    console.log(
      `✅ Plan V2 actualizado: empresa=${empresaId}, packs=[${packsActivos}], ` +
      `addons=[${addonsActivos}], módulos=${modulosActivos.length}, precio=${precioTotal}€`
    );

    return {
      ok: true,
      empresaId,
      packsActivos,
      addonsActivos,
      modulosActivos,
      precioTotal,
      fechaFin: fechaFin.toISOString(),
    };
  }
);

