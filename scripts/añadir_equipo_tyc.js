/**
 * añadir_equipo_tyc.js
 * Añade datos de equipo (subcolección negocios_publicos/{id}/equipo)
 * y términos y condiciones (campo terminosYCondiciones) a los negocios.
 *
 * USO: node scripts/añadir_equipo_tyc.js
 */

const admin = require("../functions/node_modules/firebase-admin");
const path  = require("path");

admin.initializeApp({
  credential: admin.credential.cert(require(path.join(__dirname, "..", "credentials.json"))),
});
const db = admin.firestore();

// ─── Datos ───────────────────────────────────────────────────────────────────

const DATOS = [
  // ── Con equipo identificado ────────────────────────────────────────────────
  {
    id: "belen_nogueras_estetica",
    equipo: [
      {
        nombre: "Belen Nogueras",
        cargo: "Fundadora y Esteticista",
        bio_publica: "Fundadora del centro con mas de 20 anos de experiencia en estetica facial y corporal. Especialista en tratamientos con productos ecologicos y naturales.",
        especialidades: ["Tratamientos faciales", "Limpiezas faciales", "Depilacion cera", "Manicura", "Pedicura"],
      },
    ],
    tyc: "Belen Nogueras Estetica — Centro de estetica ubicado en Av. de Belena 10, 19005 Guadalajara.\n\nReservas y citas: Las citas se confirman por telefono o WhatsApp (722 26 27 08). Para cancelar, avisar con al menos 24 horas de antelacion.\n\nContacto: info@belennoguerasestetica.es",
  },
  {
    id: "clinica_medico_estetica_cristina_aguilera",
    equipo: [
      {
        nombre: "Cristina Aguilera",
        cargo: "Directora Medica",
        bio_publica: "Directora de la clinica especializada en medicina estetica facial. Equipo multidisciplinar formado por expertos en Medicina Estetica.",
        especialidades: ["Medicina estetica facial", "Tratamientos antiinflamatorios"],
      },
      {
        nombre: "Marta",
        cargo: "Especialista en Tratamientos",
        bio_publica: "Especialista destacada en tratamientos esteticos. Reconocida por su profesionalidad, su capacidad de explicar cada tratamiento y transmitir tranquilidad.",
        especialidades: ["Limpiezas faciales", "Masajes esteticos"],
      },
    ],
    tyc: "Clinica Medico Estetica Cristina Aguilera — Pl. de Pablo Iglesias 4, 19001 Guadalajara.\n\nContacto: clinica@cristinaguileraesthetic.es | Tel: 659 780 980\n\nReservas: Se realizan por telefono o WhatsApp. Cancelaciones con 24h de antelacion minimo.\n\nLos tratamientos medicos se realizan bajo prescripcion y valoracion previa del medico estetico.",
  },
  {
    id: "clinica_dra_ana_sanchez_dominguez",
    equipo: [
      {
        nombre: "Dra. Ana Sanchez Dominguez",
        cargo: "Medica Especialista en Medicina Estetica",
        bio_publica: "Medica con dos decadas de experiencia en medicina estetica. Su prioridad es ofrecer los ultimos tratamientos medico-esteticos con formacion continua y las ultimas tecnologias.",
        especialidades: ["Medicina estetica facial", "Rejuvenecimiento", "Tecnicas novedosas"],
      },
      {
        nombre: "Laura",
        cargo: "Esteticista",
        bio_publica: "Esteticista especializada en tratamientos de belleza facial y corporal.",
        especialidades: ["Tratamientos faciales", "Estetica corporal"],
      },
    ],
    tyc: "Clinica Medicina Estetica Dra. Ana Sanchez Dominguez — C/ Angel Martin Puebla 5, Local A, 19001 Guadalajara.\n\nContacto: info@doctoraanasanchez.es | Tel: 638 052 811\n\nLos tratamientos de medicina estetica requieren valoracion medica previa. Los resultados pueden variar segun el paciente.\n\nPolitica de privacidad disponible en doctoraanasanchez.es",
  },
  {
    id: "centro_estetica_alba_guadalajara",
    equipo: [
      {
        nombre: "Cristina Jaraba Heras",
        cargo: "Co-directora",
        bio_publica: "Co-directora del centro desde 2022. Aporta una vision fresca e innovadora manteniendo la mision de calidad original del centro fundado en 1975.",
        especialidades: ["Tratamientos faciales", "Cosmetica avanzada"],
      },
      {
        nombre: "Veronica Lopez-Estrada",
        cargo: "Co-directora",
        bio_publica: "Co-directora del centro desde 2022. Atencion profesional y cercana a cada cliente.",
        especialidades: ["Tratamientos corporales", "Presoterapia"],
      },
    ],
    tyc: "Centro de Estetica Alba Guadalajara — C. de Rufino Blanco 9, 19002 Guadalajara.\n\nFundado en 1975 por las hermanas Marga y Ma Jesus Alba. Centro con mas de 50 anos de experiencia.\n\nContacto: Tel 949 21 02 37\n\nTerminos y condiciones, politica de devoluciones y aviso legal disponibles en albaesteticaguadalajara.es\n\nDe conformidad con la LOPD, sus datos seran tratados con total confidencialidad.",
  },
  {
    id: "mizu_guadalajara",
    equipo: [
      {
        nombre: "Dra. Marivi Lopez",
        cargo: "Especialista en Dietetica y Nutricion",
        bio_publica: "Toda una vida dedicada a mejorar la salud a traves de la alimentacion. Especialista en obesidad, sobrepeso y menopausia. Registro sanitario: 1906999.",
        especialidades: ["Dietetica", "Nutricion", "Menopausia", "Sobrepeso"],
      },
    ],
    tyc: "Balneario Mizu Guadalajara — C. Marques de Santillana 2, 19002 Guadalajara.\n\nRegistro Sanitario: 1906999\n\nCondiciones generales de venta, aviso legal y politica de privacidad disponibles en mizuspa.com\n\nReservas: Tel 685 53 21 67 | Se requiere cancelacion con 24h de antelacion para evitar cargo.",
  },
  {
    id: "laserya_el_casar",
    equipo: [
      {
        nombre: "Inma",
        cargo: "Especialista en Depilacion Laser",
        bio_publica: "Especialista en depilacion laser y estetica en El Casar. Destacada en resenas por su profesionalidad, amabilidad y minuciosidad.",
        especialidades: ["Depilacion laser", "Manicura", "Lifting de pestanas"],
      },
    ],
    tyc: "Laserya — C/ El Salto 13, 19170 El Casar, Guadalajara.\n\nContacto: contacto@laserya.es | Tel: 642 14 17 01 / 949 41 03 27\n\nReservas con cita previa. Cancelaciones con minimo 24h de antelacion.\n\nPolitica de privacidad y politica de cookies disponibles en laserya.es",
  },
  // ── Solo T&C (sin equipo identificado) ──────────────────────────────────────
  {
    id: "laser_azuqueca",
    equipo: [
      {
        nombre: "Jesica Esquinas Anguita",
        cargo: "Propietaria y Especialista",
        bio_publica: "Propietaria de Laser Azuqueca. Especialista en depilacion laser diodo con horario ampliado de lunes a sabado.",
        especialidades: ["Depilacion laser diodo"],
      },
    ],
    tyc: "LASER AZUQUECA — Propietaria: JESICA ESQUINAS ANGUITA (CIF: 09049603T)\nDireccion: Calle la Victoria 4, 19200 Azuqueca de Henares, Guadalajara\nEmail: depilacion@laserazuqueca.es | Tel: +34 641 136 050\n\nCondiciones de uso: Los usuarios que accedan aceptan la totalidad de los terminos. Queda prohibida la reproduccion no autorizada de materiales.\n\nProteccion de datos: Politica de privacidad disponible en laserazuqueca.es/politica-de-privacidad/\n\nJurisdiccion: Tribunales de Madrid y legislacion espanola.",
  },
  {
    id: "laserum_guadalajara",
    tyc: "CENTRAL GRUPO LASERUM SL (NIF: B67863944) — laserum.com\nSede social: Sevilla, Espana\n\nPropiedad intelectual: El sitio web, su programacion, disenos, logotipos, textos y graficos son propiedad de CENTRAL GRUPO LASERUM SL.\n\nCookies: Se utilizan cookies tecnicas para el funcionamiento del sitio. Las cookies adicionales requieren consentimiento previo.\n\nContacto legal: privacidad@laserum.es\n\nJurisdiccion: Legislacion espanola.",
  },
  {
    id: "glow_medicina_estetica",
    tyc: "MEDIMOVIL TRAUMATOLOGICO S.L. (NIF: B82236027)\nDireccion: Calle Virgen de la Soledad 3A 1o, 19003 Guadalajara\nCodigo sanitario: 1904184\nEmail: asanchez@medicinaesteticaglow.es | Tel: 949 211 172\n\nAceptacion: El uso del sitio implica aceptacion de todos los terminos.\n\nResponsabilidad: La empresa no garantiza la exactitud total del contenido y declina responsabilidad por interrupciones del servicio fuera de su control.\n\nPropiedad intelectual: Todos los derechos reservados. Prohibida la reproduccion o uso comercial sin permiso escrito.\n\nJurisdiccion: Legislacion espanola.",
  },
  {
    id: "anatura_bioestetica",
    tyc: "Anatura Bioestetica — C. del Arrabal del Agua 1, local 2, 19005 Guadalajara.\n\nContacto: Tel/WhatsApp 653 15 57 74\n\nEspecialidad unica: Centro especializado en asesoria oncologica y venta de pelucas y turbantes para pacientes de cancer.\n\nReservas con cita previa. Para informacion sobre pelucas oncologicas, contactar directamente por telefono.",
  },
  {
    id: "beauty_by_patricia_guadalajara",
    tyc: "Beauty by Patricia — Blvr. de Entrepeñas 1, B, 19005 Guadalajara.\n\nContacto: Tel/WhatsApp 673 81 17 68 | beautyguadalajara.es\n\nReservas: Con cita previa. Cancelaciones con al menos 24 horas de antelacion.",
  },
  {
    id: "centro_estetica_avanzada_cleo",
    tyc: "Centro Estetica Avanzada Cleo — C. Federica Montseny 4, 19005 Guadalajara.\n\nContacto: Tel 949 03 38 94\n\nReservas con cita previa. Para cancelaciones avisar con minimo 24h de antelacion.",
  },
  {
    id: "clinica_carlos_gomez_guadalajara",
    tyc: "Clinica Carlos Gomez — C. Virgen del Amparo 44, 19002 Guadalajara.\n\nContacto: Tel 949 25 73 28 | clinicacarlosgomez.com\n\nLos tratamientos medico-esteticos requieren valoracion previa. Los resultados pueden variar segun el paciente y el tratamiento aplicado.\n\nReservas con cita previa.",
  },
  {
    id: "gn_estetica_avanzada",
    tyc: "GN Estetica Avanzada — Av. Bulevar del Alto Tajo 9, local 4, 19005 Guadalajara.\n\nContacto: Tel/WhatsApp 624 40 49 09 | gnesteticaavanzada.com\n\nReservas con cita previa. Cancelaciones con al menos 24h de antelacion.",
  },
  {
    id: "samira_salud_y_belleza",
    tyc: "Samira Salud y Belleza — Av. del Ejercito 9A, 19004 Guadalajara.\n\nContacto: Tel 949 25 53 79 | samirasaludybelleza.es\n\nCentro integral de salud y belleza. Servicios de estetica, depilacion laser, peluqueria y pilates.\n\nReservas con cita previa.",
  },
  {
    id: "laude_servibelleza",
    tyc: "Laude Servibelleza — Blvr. de Entrepeñas 8, 19005 Guadalajara.\n\nContacto: Tel/WhatsApp 640 08 40 04 | servibelleza.es\n\nReservas con cita previa. Cancelaciones avisando con al menos 24h de antelacion.",
  },
  {
    id: "sensorial_estetica_avanzada",
    tyc: "Sensorial Estetica Avanzada — Av. de Castilla 18, G, 19002 Guadalajara.\n\nContacto: Tel/WhatsApp 613 17 79 18 | sensorialesteticaavanzada.com\n\nEspecialistas: Beatriz — Esteticista especializada en tratamientos antiedad.\n\nReservas con cita previa.",
  },
  {
    id: "lc_depilacion_laser",
    tyc: "LC Depilacion Laser — C. Wenceslao Argumosa 5, 19003 Guadalajara.\n\nContacto: Tel/WhatsApp 949 25 57 14 | laserbolinia.com\n\nReservas con cita previa. Horario ampliado: L-J 9:15-21:00, V 9:00-21:00.",
  },
  {
    id: "alan_depilacion_laser",
    tyc: "ALAN Depilacion Laser — C. Miguel Fluiters 45, 19001 Guadalajara.\n\nContacto: Tel/WhatsApp 642 29 47 20\n\nReservas con cita previa. Abierto de lunes a sabado de 10:00 a 19:00.",
  },
  {
    id: "centro_rubi_guadalajara",
    tyc: "Centro Rubi — Pl. Virgen de la Antigua 5, 19001 Guadalajara.\n\nContacto: Tel/WhatsApp 622 84 84 60 | centrosrubi@gmail.com | centrosrubi.com\n\nAbierto desde 2023. Reservas con cita previa.",
  },
  {
    id: "sinvello_guadalajara",
    tyc: "SinVello! Guadalajara — C. Felipe Solano Antelo 19, 19002 Guadalajara.\n\nContacto: Tel/WhatsApp 604 90 14 76 | sinvelloporlaser.es\n\nReservas con cita previa. Horario: L-V 9:30-14:30 y 15:00-21:00, S 10:00-14:00.",
  },
];

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  let okEquipo = 0, okTyc = 0;

  for (const item of DATOS) {
    const negRef = db.collection("negocios_publicos").doc(item.id);

    // T&C
    if (item.tyc) {
      await negRef.update({ terminosYCondiciones: item.tyc });
      okTyc++;
    }

    // Equipo
    if (item.equipo && item.equipo.length > 0) {
      const batch = db.batch();
      item.equipo.forEach((miembro, idx) => {
        const ref = negRef.collection("equipo").doc();
        batch.set(ref, { ...miembro, orden: idx });
      });
      await batch.commit();
      okEquipo += item.equipo.length;
    }

    process.stdout.write("\rProcesados: " + DATOS.indexOf(item) + 1 + "/" + DATOS.length + "  ");
  }

  console.log("\n\n===================================================");
  console.log("  LISTO");
  console.log("  T&C actualizados: " + okTyc + " negocios");
  console.log("  Miembros de equipo añadidos: " + okEquipo);
  console.log("===================================================\n");
  process.exit(0);
}

main().catch(e => { console.error("Error:", e.message); process.exit(1); });
