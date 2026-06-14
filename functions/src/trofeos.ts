import { onDocumentUpdated, onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';

const db        = admin.firestore();
const messaging = admin.messaging();
const REGION    = 'europe-west1';

// ── Metadatos estáticos de trofeos (id → monedas, nombre, emoji) ───────────
const TROFEOS_META: Record<string, { monedas: number; nombre: string; emoji: string }> = {
  primera_reserva:        { monedas: 50,   nombre: 'Primera Cita',             emoji: '🎉' },
  tres_reservas:          { monedas: 75,   nombre: 'Trío de Reservas',          emoji: '🔁' },
  cinco_reservas:         { monedas: 100,  nombre: 'Habitual',                  emoji: '🌟' },
  diez_reservas:          { monedas: 200,  nombre: 'Fiel',                      emoji: '🏆' },
  veinticinco_reservas:   { monedas: 400,  nombre: 'Devoto',                    emoji: '👑' },
  cincuenta_reservas:     { monedas: 750,  nombre: 'Leyenda de Reservas',       emoji: '🦸' },
  mito_local:             { monedas: 150,  nombre: 'Mito Local',                emoji: '🗿' },
  vip_tres:               { monedas: 150,  nombre: 'Cliente VIP',               emoji: '🥉' },
  vip_cinco:              { monedas: 300,  nombre: 'Habitual de Lujo',          emoji: '🥈' },
  vip_diez:               { monedas: 600,  nombre: 'Incondicional',             emoji: '🥇' },
  dios_del_barrio:        { monedas: 150,  nombre: 'Dios del Barrio',           emoji: '🏛️' },
  madrugador:             { monedas: 80,   nombre: 'Madrugador',                emoji: '🌅' },
  madrugador_extremo:     { monedas: 25,   nombre: 'Madrugador Extremo',        emoji: '🌄' },
  noctambulo:             { monedas: 10,   nombre: 'Noctámbulo',                emoji: '🌙' },
  noctambulo_empedernido: { monedas: 25,   nombre: 'Noctámbulo Empedernido',    emoji: '🦉' },
  siempre_vuelves:        { monedas: 10,   nombre: 'Siempre Vuelves',           emoji: '💫' },
  racha_tres_meses:       { monedas: 25,   nombre: 'Racha de 3 Meses',          emoji: '📈' },
  fan_numero_uno:         { monedas: 150,  nombre: 'Fan Número 1',              emoji: '🌟' },
  ritual_semanal:         { monedas: 60,   nombre: 'Ritual Semanal',            emoji: '🔮' },
  puntual:                { monedas: 10,   nombre: 'Puntual',                   emoji: '⏰' },
  reloj_suizo:            { monedas: 25,   nombre: 'Reloj Suizo',               emoji: '⌚' },
  perfecto_25:            { monedas: 60,   nombre: 'Perfecto 25',               emoji: '🎯' },
  diamante_puntualidad:   { monedas: 150,  nombre: 'Diamante Puntualidad',      emoji: '💠' },
  perfecto_50:            { monedas: 150,  nombre: 'Perfecto 50',               emoji: '🎯' },
  primera_resena:         { monedas: 75,   nombre: 'Primera Opinión',           emoji: '📝' },
  cinco_resenas:          { monedas: 150,  nombre: 'Crítico',                   emoji: '🎯' },
  diez_resenas:           { monedas: 300,  nombre: 'Experto en Opiniones',      emoji: '🧐' },
  veinticinco_resenas:    { monedas: 600,  nombre: 'Influencer',                emoji: '📣' },
  cronista_oficial:       { monedas: 150,  nombre: 'Cronista Oficial',          emoji: '📰' },
  voz_ciudad:             { monedas: 150,  nombre: 'Voz de la Ciudad',          emoji: '🎙️' },
  resena_tres_negocios:   { monedas: 150,  nombre: 'Crítico Diverso',           emoji: '🗣️' },
  perfil_completo:        { monedas: 100,  nombre: 'Perfil Pro',                emoji: '🪪' },
  con_cara:               { monedas: 10,   nombre: 'Con Cara',                  emoji: '🤳' },
  conectado:              { monedas: 10,   nombre: 'Conectado',                 emoji: '🔔' },
  bio_completa:           { monedas: 10,   nombre: 'Bio Completa',              emoji: '✏️' },
  bienvenido:             { monedas: 10,   nombre: 'Bienvenido',                emoji: '🎊' },
  cliente_veterano:       { monedas: 500,  nombre: 'Veterano',                  emoji: '🎖️' },
  cliente_ano:            { monedas: 1000, nombre: 'Aniversario',               emoji: '🎂' },
};

// ═══════════════════════════════════════════════════════════════════
// HELPER CENTRAL: otorgar trofeo de forma atómica e idempotente
// ═══════════════════════════════════════════════════════════════════
async function checkAndGrantTrofeo(uid: string, trofeoId: string): Promise<boolean> {
  const trofeoRef   = db.collection('usuarios').doc(uid).collection('trofeos').doc(trofeoId);
  const monederoRef = db.collection('usuarios').doc(uid).collection('monedero').doc('main');

  const snap = await trofeoRef.get();
  if (snap.exists && snap.data()?.completado === true) return false;

  const meta    = TROFEOS_META[trofeoId];
  const monedas = meta?.monedas ?? 10;
  const nombre  = meta?.nombre  ?? trofeoId;
  const emoji   = meta?.emoji   ?? '🏆';

  const userSnap = await db.collection('usuarios').doc(uid).get();
  const user     = userSnap.data() ?? {};
  const multiExp = (user['canje_multi_expira'] as admin.firestore.Timestamp | undefined)?.toDate();
  const multi    = (multiExp && multiExp > new Date()) ? 2 : 1;
  const total    = monedas * multi;

  const batch = db.batch();
  batch.set(trofeoRef, {
    completado: true,
    fecha: admin.firestore.FieldValue.serverTimestamp(),
    monedas_otorgadas: total,
    ...(multi === 2 && { con_multiplicador: true }),
  });
  batch.update(db.collection('usuarios').doc(uid), {
    monedas: admin.firestore.FieldValue.increment(total),
  });
  batch.set(monederoRef, {
    saldo:               admin.firestore.FieldValue.increment(total),
    total_ganado:        admin.firestore.FieldValue.increment(total),
    ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  batch.set(monederoRef.collection('transacciones').doc(), {
    tipo:      'ganancia',
    cantidad:  total,
    concepto:  `${emoji} ${nombre}`,
    trofeo_id: trofeoId,
    fecha:     admin.firestore.FieldValue.serverTimestamp(),
  });
  await batch.commit();

  const fcmToken = user['fcmToken'] as string | undefined;
  if (fcmToken) {
    try {
      await messaging.send({
        token: fcmToken,
        notification: { title: '🏆 ¡Trofeo desbloqueado!', body: `${emoji} ${nombre} — +${total}🪙` },
        data: { tipo: 'trofeo_desbloqueado', trofeo_id: trofeoId, monedas: String(total) },
      });
    } catch (_) { /* no bloquear si falla FCM */ }
  }

  console.log(`✅ Trofeo otorgado: ${uid} → ${trofeoId} (+${total}🪙)`);
  return true;
}

// Evalúa lista de trofeos por umbral de conteo (secuencial para evitar race conditions)
async function evaluarUmbrales(uid: string, valor: number, checks: Array<{ meta: number; id: string }>): Promise<void> {
  for (const c of checks) {
    if (valor >= c.meta) await checkAndGrantTrofeo(uid, c.id);
  }
}

// ═══════════════════════════════════════════════════════════════════
// TRIGGER 1: Cita completada → trofeos fidelidad + puntualidad + horarios
// ═══════════════════════════════════════════════════════════════════
export const onCitaCompletadaTrofeos = onDocumentUpdated(
  { document: 'empresas/{empresaId}/reservas/{reservaId}', region: REGION, maxInstances: 10 },
  async (event) => {
    const antes   = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;
    if (antes['estado'] === despues['estado'] || despues['estado'] !== 'completada') return;

    const uid       = despues['cliente_uid'] as string | undefined;
    if (!uid) return;
    const empresaId = event.params.empresaId;

    try {
      // Total citas completadas del usuario (collectionGroup query)
      const allSnap = await db.collectionGroup('reservas')
        .where('cliente_uid', '==', uid)
        .where('estado', '==', 'completada')
        .get();
      const totalCitas = allSnap.size;

      await evaluarUmbrales(uid, totalCitas, [
        { meta: 1,   id: 'primera_reserva' },
        { meta: 3,   id: 'tres_reservas' },
        { meta: 5,   id: 'cinco_reservas' },
        { meta: 10,  id: 'diez_reservas' },
        { meta: 25,  id: 'veinticinco_reservas' },
        { meta: 50,  id: 'cincuenta_reservas' },
        { meta: 200, id: 'mito_local' },
      ]);

      // Visitas al mismo negocio
      const mismoNegocioSnap = await db.collection(`empresas/${empresaId}/reservas`)
        .where('cliente_uid', '==', uid)
        .where('estado', '==', 'completada')
        .get();
      await evaluarUmbrales(uid, mismoNegocioSnap.size, [
        { meta: 3,   id: 'vip_tres' },
        { meta: 5,   id: 'vip_cinco' },
        { meta: 10,  id: 'vip_diez' },
        { meta: 150, id: 'dios_del_barrio' },
      ]);

      // Trofeos de horario: madrugador / noctámbulo
      const horaStr = despues['hora_inicio'] as string | undefined;
      if (horaStr) {
        const hora = parseInt(horaStr.split(':')[0], 10);
        const madCount = allSnap.docs.filter(d => {
          const h = d.data()['hora_inicio'] as string | undefined;
          return h && parseInt(h.split(':')[0], 10) < 9;
        }).length;
        const nocCount = allSnap.docs.filter(d => {
          const h = d.data()['hora_inicio'] as string | undefined;
          return h && parseInt(h.split(':')[0], 10) >= 20;
        }).length;
        if (hora < 9) {
          await evaluarUmbrales(uid, madCount, [{ meta: 1, id: 'madrugador' }, { meta: 20, id: 'madrugador_extremo' }]);
        }
        if (hora >= 20) {
          await evaluarUmbrales(uid, nocCount, [{ meta: 5, id: 'noctambulo' }, { meta: 20, id: 'noctambulo_empedernido' }]);
        }
      }

      // Siempre vuelves: completó una cita habiendo cancelado antes
      const canceladasSnap = await db.collectionGroup('reservas')
        .where('cliente_uid', '==', uid).where('estado', '==', 'cancelada').limit(1).get();
      if (!canceladasSnap.empty) await checkAndGrantTrofeo(uid, 'siempre_vuelves');

      console.log(`✅ onCitaCompletadaTrofeos: ${uid} (${totalCitas} citas)`);
    } catch (err) {
      console.error(`❌ onCitaCompletadaTrofeos para ${uid}:`, err);
    }
  }
);

// ═══════════════════════════════════════════════════════════════════
// TRIGGER 2: Reseña creada → trofeos de reseñas
// ═══════════════════════════════════════════════════════════════════
export const onResenaCreadaTrofeos = onDocumentCreated(
  { document: 'negocios_publicos/{negocioId}/valoraciones/{valoracionId}', region: REGION, maxInstances: 10 },
  async (event) => {
    const val = event.data?.data();
    if (!val) return;
    const uid = val['clienteId'] as string | undefined;
    if (!uid) return;

    try {
      const todasSnap = await db.collectionGroup('valoraciones')
        .where('clienteId', '==', uid).get();
      const total = todasSnap.size;

      await evaluarUmbrales(uid, total, [
        { meta: 1,   id: 'primera_resena' },
        { meta: 5,   id: 'cinco_resenas' },
        { meta: 10,  id: 'diez_resenas' },
        { meta: 25,  id: 'veinticinco_resenas' },
        { meta: 50,  id: 'cronista_oficial' },
        { meta: 100, id: 'voz_ciudad' },
      ]);

      const negociosDistintos = new Set(todasSnap.docs.map(d => d.ref.parent.parent?.id ?? '')).size;
      if (negociosDistintos >= 3) await checkAndGrantTrofeo(uid, 'resena_tres_negocios');

      console.log(`✅ onResenaCreadaTrofeos: ${uid} (${total} reseñas)`);
    } catch (err) {
      console.error(`❌ onResenaCreadaTrofeos para ${uid}:`, err);
    }
  }
);

// ═══════════════════════════════════════════════════════════════════
// TRIGGER 3: Perfil actualizado → trofeos de perfil
// ═══════════════════════════════════════════════════════════════════
export const onPerfilActualizadoTrofeos = onDocumentUpdated(
  { document: 'usuarios/{userId}', region: REGION, maxInstances: 10 },
  async (event) => {
    const uid    = event.params.userId;
    const antes  = event.data?.before.data() ?? {};
    const despues = event.data?.after.data()  ?? {};

    try {
      if (!antes['foto_url']   && despues['foto_url'])   await checkAndGrantTrofeo(uid, 'con_cara');
      if (!antes['fcmToken']   && despues['fcmToken'])   await checkAndGrantTrofeo(uid, 'conectado');
      if (!antes['bio']        && despues['bio'])        await checkAndGrantTrofeo(uid, 'bio_completa');

      const completo = !!(despues['nombre'] || despues['name'])
                    && !!despues['foto_url']
                    && !!(despues['telefono'] || despues['phone']);
      if (completo) await checkAndGrantTrofeo(uid, 'perfil_completo');
    } catch (err) {
      console.error(`❌ onPerfilActualizadoTrofeos para ${uid}:`, err);
    }
  }
);

// ═══════════════════════════════════════════════════════════════════
// CALLABLE: Recalcular todos los trofeos de fidelidad (migración)
// ═══════════════════════════════════════════════════════════════════
export const evaluarTrofeosFidelidad = onCall(
  { region: REGION, maxInstances: 5 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'No autenticado');

    const snap = await db.collectionGroup('reservas')
      .where('cliente_uid', '==', uid)
      .where('estado', '==', 'completada')
      .get();
    const total = snap.size;

    await evaluarUmbrales(uid, total, [
      { meta: 1,   id: 'primera_reserva' },
      { meta: 3,   id: 'tres_reservas' },
      { meta: 5,   id: 'cinco_reservas' },
      { meta: 10,  id: 'diez_reservas' },
      { meta: 25,  id: 'veinticinco_reservas' },
      { meta: 50,  id: 'cincuenta_reservas' },
      { meta: 200, id: 'mito_local' },
    ]);
    await checkAndGrantTrofeo(uid, 'bienvenido');

    return { ok: true, total_citas: total };
  }
);

// ═══════════════════════════════════════════════════════════════════
// SCHEDULED: Fan número 1 — día 1 de cada mes a las 00:30
// Cooldown 30 días por negocio y usuario (anti-abuso)
// ═══════════════════════════════════════════════════════════════════
export const fanNumero1Job = onSchedule(
  { schedule: '30 0 1 * *', timeZone: 'Europe/Madrid', region: REGION },
  async () => {
    const ahora             = new Date();
    const inicioMesAnterior = new Date(ahora.getFullYear(), ahora.getMonth() - 1, 1);
    const finMesAnterior    = new Date(ahora.getFullYear(), ahora.getMonth(),     0, 23, 59, 59);

    const negociosSnap = await db.collection('negocios_publicos').where('activo', '==', true).get();

    for (const negocioDoc of negociosSnap.docs) {
      const negocioId = negocioDoc.data()['empresaIdVinculada'] as string | undefined;
      if (!negocioId) continue;

      try {
        const reservasSnap = await db.collection(`empresas/${negocioId}/reservas`)
          .where('estado', '==', 'completada')
          .where('fecha_creacion', '>=', admin.firestore.Timestamp.fromDate(inicioMesAnterior))
          .where('fecha_creacion', '<=', admin.firestore.Timestamp.fromDate(finMesAnterior))
          .get();
        if (reservasSnap.empty) continue;

        // Conteo por cliente_uid
        const conteo: Record<string, number> = {};
        for (const r of reservasSnap.docs) {
          const uid = r.data()['cliente_uid'] as string | undefined;
          if (uid) conteo[uid] = (conteo[uid] ?? 0) + 1;
        }

        const sorted = Object.entries(conteo).sort((a, b) => b[1] - a[1]);
        if (sorted.length === 0) continue;
        const [topUid, topCount] = sorted[0];
        if (topCount < 2) continue; // Mínimo 2 visitas en el mes

        // Anti-abuso: cooldown 30 días
        const trofeoRef  = db.collection('usuarios').doc(topUid).collection('trofeos').doc('fan_numero_uno');
        const prevSnap   = await trofeoRef.get();
        const lastGrant  = (prevSnap.data()?.['fecha'] as admin.firestore.Timestamp | undefined)?.toDate();
        if (lastGrant && (ahora.getTime() - lastGrant.getTime()) < 30 * 24 * 3600 * 1000) continue;

        // Reset para permitir re-concesión mensual
        await trofeoRef.set({ completado: false, fecha: null });
        await checkAndGrantTrofeo(topUid, 'fan_numero_uno');
        console.log(`🌟 fan_numero_uno: ${topUid} (${topCount} visitas en ${negocioId})`);
      } catch (err) {
        console.error(`❌ fanNumero1Job en ${negocioId}:`, err);
      }
    }
  }
);
