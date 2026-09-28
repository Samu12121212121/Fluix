/**
 * asignar_prioridades_nazari.js
 * ──────────────────────────────────────────────────────────────────────────
 * Asigna el campo `prioridad` en Firestore (colección `autores`) según el
 * orden oficial de la web de Editorial Nazarí (250 posiciones).
 *
 * Uso:
 *   cd functions
 *   node asignar_prioridades_nazari.js            (escribe en Firestore)
 *   node asignar_prioridades_nazari.js --dry-run  (solo muestra, no escribe)
 * ──────────────────────────────────────────────────────────────────────────
 */

const admin  = require('firebase-admin');
const fs     = require('fs');
const path   = require('path');
const os     = require('os');

const DRY_RUN      = process.argv.includes('--dry-run');
const DEL_EXTRAS   = process.argv.includes('--delete-extras');
const EID          = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

// ── Credenciales ─────────────────────────────────────────────────────────────
if (!DRY_RUN) {
  const saPath = path.join(__dirname, 'serviceAccountKey.json');
  if (fs.existsSync(saPath)) {
    admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
  } else {
    const candidates = [
      path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
      path.join(process.env.APPDATA || '', 'Roaming', 'configstore', 'firebase-tools.json'),
      path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
    ];
    let rt = null;
    for (const p of candidates) {
      try { const d = JSON.parse(fs.readFileSync(p, 'utf8')); rt = d?.tokens?.refresh_token; if (rt) break; } catch (_) {}
    }
    if (!rt) { console.error('❌ No se encontró serviceAccountKey.json ni token de Firebase CLI.'); process.exit(1); }
    admin.initializeApp({
      credential: admin.credential.refreshToken({
        type: 'authorized_user',
        client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
        client_secret: 'j9iVZfS8ywKVtZdp0to4vn1p',
        refresh_token: rt,
      }),
      projectId: 'planeaapp-4bea4',
    });
  }
}

// ── Orden canónico de la web (250 posiciones) ─────────────────────────────────
const ORDEN_NAZARI = [
  'Esteban Ruiz Ballesteros',       //   1
  'David Cidoncha',                 //   2
  'Enrique Morón',                  //   3
  'Mercedes Maroto Márquez',        //   4
  'Federico Zurita Martínez',       //   5
  'Susana Collado Vázquez',         //   6
  'María Alcázar Rodríguez',        //   7
  'Elisa de Armas',                 //   8
  'Enrique Palomo Atance',          //   9
  'Javier Ruiz Barquín',            //  10
  'Óscar Vázquez Mínguez',          //  11
  'Volantones',                     //  12
  'José Piñero Mira',               //  13
  'Mari Carmen Aguilera',           //  14
  'Belén Esturla',                  //  15
  'Edgar Allan Poe',                //  16
  'Gustavo Adolfo Bécquer',         //  17
  'Pedro López Ávila',              //  18
  'Manuel Ángel Morales Escudero',  //  19
  'Jordi Isern',                    //  20
  'María Eugenia Oliver',           //  21
  'Ángel Elgue',                    //  22
  'Ana Moya',                       //  23
  'Marimén Ayuso',                  //  24
  'José Prados Osuna',              //  25
  'Jesús Paredes Ortiz',            //  26
  'Paula R. Bouzas',                //  27
  'Maite Cuesta',                   //  28
  'José Luis Monroy Antón',         //  29
  'Manuel Bayona',                  //  30
  'Daniel Morales Escobar',         //  31
  'Dulce López Rodríguez',          //  32
  'David Macías Gómez',             //  33
  'Ana Barea Arco',                 //  34
  'Antonio Enrique',                //  35
  'Alejandro A. Bolívar',           //  36
  'José Luis Enríquez Sánchez',     //  37
  'Mar Navarro G.',                 //  38
  'Ana Grandal',                    //  39
  'Walter H. Océano',               //  40
  'Francisco Javier Sánchez Manzano', // 41
  'José Antonio Ramos Muñoz',       //  42
  'Teresa Ariza Periáñez',          //  43
  'Ana Aguilera',                   //  44
  'Hassane Maqnine',                //  45
  'Torcuato Romero López',          //  46
  'Antonio César Morón',            //  47
  'Diego Castillo Barco',           //  48
  'Piedad Santiago',                //  49
  'Irene Bosch Blanco',             //  50
  'José Vicente Pascual',           //  51
  'Juan de Dios Villanueva Roa',    //  52
  'Jesús Ávila Granados',           //  53
  'Lola Callejón',                  //  54
  'Juan J. Quero Perabá',           //  55
  'Ingrid Bürger',                  //  56
  'Sofía Pérez Martínez',           //  57
  'Julio Mardelo',                  //  58
  'Carlos Bodellanos',              //  59
  'Francisco J. Cabrera García',    //  60
  'Antonio Molina Cuevas',          //  61
  'Josep Soler Lladó',              //  62
  'Javier Viraje',                  //  63
  'José Antonio Ruiz Reina',        //  64
  'Miguel Huguet',                  //  65
  'Jorge Fernando Rueda Cerro',     //  66
  'Marta Badenes Sastre',           //  67
  'Estíbaliz Madrazo San Emeterio', //  68
  'Juan Tomás Morales',             //  69
  'Miguel Arnas Coronado',          //  70
  'Daniel Fuentes Casado',          //  71
  'Enrique Mochón Romera',          //  72
  'Antígona Márquez Pascual',       //  73
  'Guillermo Alonso Menchero',      //  74
  'Juan Carlos Rodríguez Torres',   //  75
  'Arturo Palenzuela Reyes',        //  76
  'María Luisa Huertas',            //  77
  'Francisco Manuel Miranda',       //  78
  'Rosario R. Gálvez',              //  79
  'F. Javier Cano Santa Bárbara',   //  80
  'Pablo Acevedo',                  //  81
  'Consuelo Vallejo Delgado',       //  82
  'Fernando Soriano Bensusan',      //  83
  'Susi Campos',                    //  84
  'Xavier Rull',                    //  85
  'J. S. Castañeda',                //  86
  'Ana Navarro',                    //  87
  'Constanza González Ferrer',      //  88
  'Antonio Mejías',                 //  89
  'Iduna RuSol',                    //  90
  'Fernando Díaz Cid',              //  91
  'Lorena Avelar',                  //  92
  'Eva G. Bullido',                 //  93
  'Teresa Muñoz Valera',            //  94
  'Santiago Molina Martín',         //  95
  'Miguel Ávila Cabezas',           //  96
  'José María García Linares',      //  97
  'Enrique Jaramillo Levi',         //  98
  'Sandra Lozano Pedregosa',        //  99
  'Teodoro Martín de Molina',       // 100
  'Ramón López Pazos',              // 101
  'Miha Mazzini',                   // 102
  'Louis Jolicoeur',                // 103
  'José Luis Pedreira',             // 104
  'Miguel Ángel Ulecia Martínez',   // 105
  'Ana Carril',                     // 106
  'Luis Felipe Aladueña',           // 107
  'Santiago Martín Guerrero',       // 108
  'Víctor Ayllón',                  // 109
  'Lorena Escudero',                // 110
  'Pablo Carballal',                // 111
  'Jorge León Gustà',               // 112
  'Rafalé Guadalmedina',            // 113
  'Juan Naveros Sánchez',           // 114
  'Paula Gijón',                    // 115
  'Antonio J. Serrano Fontana',     // 116
  'Javier Ignacio Alarcón',         // 117
  'Jaime Molina',                   // 118
  'Juan Antonio Núñez',             // 119
  'Emilia Súnico',                  // 120
  'David Rodríguez Quintana',       // 121
  'Victoria Eugenia Muñoz Jiménez', // 122
  'Alberto Cordero Contreras',      // 123
  'Jesús Greus',                    // 124
  'Mª Cristina Hernández González', // 125
  'Antonio Morillas',               // 126
  'Rodolfo Padilla Sánchez',        // 127
  'Eduardo Cano Mazuecos',          // 128
  'Pedro Rojas Pedregosa',          // 129
  'Rubén Ortega Jiménez',           // 130
  'Miguel Ángel Hita Padial',       // 131
  'Cecilia López Ballesteros',      // 132
  'Javier Molina Palomino',         // 133
  'Pepe Varos',                     // 134
  'Jonathan Becedas',               // 135
  'Nina Melero',                    // 136
  'Gaudencio Díaz Muñoz',           // 137
  'Juantxu Bohigues',               // 138
  'Antonio Marín Sánchez',          // 139
  'Joan Márquez Franch',            // 140
  'Onofre Rojano',                  // 141
  'Jesús Saavedra Martín',          // 142
  'Juan Zívico',                    // 143
  'Maxim Müller Gómiz',             // 144
  'Lorenzo Algar Molinos',          // 145
  'Isabel Rezmo',                   // 146
  'Lola Cervant',                   // 147
  'June',                           // 148
  'Mariana Feride Moisoiu',         // 149
  'José Ángel Moreno «Kazo»',       // 150
  'Juan Ramón Jiménez Simón',       // 151
  'Nicolás Melini',                 // 152
  'Enric Parellada Rius',           // 153
  'EC13 ~ Cosmic Vibes',            // 154
  'José Herrero',                   // 155
  'Aureliano Cañadas Fernández',    // 156
  'Mustapha Busfeha García',        // 157
  'Ana Baldomero Mascaró',          // 158
  'Àlex Marín Canals',              // 159
  'María Dolors Renau Manén',       // 160
  'Alfonso Montoro',                // 161
  'Francisco Montero',              // 162
  'Bernardo F. Delgado Noguera',    // 163
  'Rubén Perblac',                  // 164
  'Ruth Gómez',                     // 165
  'David Vegue',                    // 166
  'Óscar Borona',                   // 167
  'Francisco Javier Fernández Espinosa', // 168
  'Juan Antonio Trillo López',      // 169
  'Carmen M. León Lopa',            // 170
  'Enrique J. Vercher García',      // 171
  'Francisco Rojas Santos',         // 172
  'Xánath Caraza',                  // 173
  'Eduardo Calvo',                  // 174
  'Héctor Pose',                    // 175
  'Carmen Gijón Herrera',           // 176
  'Ismael Contreras Carmona',       // 177
  'Guillermo Rubio Martín',         // 178
  'Víctor Espuny',                  // 179
  'Saúl Roas Deus',                 // 180
  'Pedro Blanco Naveros',           // 181
  'Slavko Zupcic',                  // 182
  'Juan José Cuenca López',         // 183
  'Jón Sigurður Eyjólfsson',        // 184
  'Jordi Navarro Fisas',            // 185
  'Lucía Marín',                    // 186
  'Antonio Cobos Ruz',              // 187
  'María Belén Adarve Ramírez',     // 188
  'Francisco Castilla Torres',      // 189
  'Dori Hernández Montalbán',       // 190
  'Consuelo de la Torre',           // 191
  'Juan José Castro Martín',        // 192
  'Francisco Beltrán Sánchez',      // 193
  'Alicia María Expósito',          // 194
  'Julia Martínez Sánchez',         // 195
  'Teresa Martín Estévez',          // 196
  'Francisco Urbano',               // 197
  'Guillermo Gómez Muñoz',          // 198
  'Fermín López Costero',           // 199
  'Pilar Quirosa-Cheyrouze',        // 200
  'Cristina Gálvez',                // 201
  'Jone Miren Asteinza',            // 202
  'Francisco Gil Craviotto',        // 203
  'Sandra Clavel',                  // 204
  'Santi Pérez Isasi',              // 205
  'Ángel Olgoso',                   // 206
  'Salvador Pérez Dueñas',          // 207
  'Emilio Ballesteros',             // 208
  'Fernando de Villena',            // 209
  'Antonio Espinosa Úbeda',         // 210
  'José Luis López Enamorado',      // 211
  'Mar de los Ríos',                // 212
  'Miguel Ángel Malo',              // 213
  'Antonio Fernández Ferrer',       // 214
  'José Loma',                      // 215
  'Félix Delgado Ropero',           // 216
  'Carmen Hernández Montalbán',     // 217
  'Cristina León Lopa',             // 218
  'Sergi G. Oset',                  // 219
  'Paz Monserrat Revillo',          // 220
  'Juan Carlos Garvayo',            // 221
  'Reza Emilio Juma',               // 222
  'Carmina Moreno Arenas',          // 223
  'Juan Carlos Friebe',             // 224
  'Emilio Rodríguez Linares, Linarett', // 225
  'Francisco J. Martínez-López',    // 226
  'Luis López-Quiñones Ruiz',       // 227
  'Ángel Fábregas García',          // 228
  'Encarni Barragán Sánchez',       // 229
  'Pedro Ruiz-Cabello Fernández',   // 230
  'José R. Reyes',                  // 231
  'Borja Angosto Rubio',            // 232
  'José Luis Gärtner',              // 233
  'Beatriz Alonso Aranzábal',       // 234
  'José Antonio Santano',           // 235
  'Juan Torres Colomera',           // 236
  'Jorge Pastor',                   // 237
  'Giancarlo Remorini',             // 238
  'Félix Terrones',                 // 239
  'Josefina Martos Peregrín',       // 240
  'Francisco Morales Lomas',        // 241
  'Carlos Almira Picazo',           // 242
  'José Zamora Linares',            // 243
  'Vitaliano de la Cruz',           // 244
  'Gabriel T. Rojo',                // 245
  'Carolina Molina',                // 246
  'Marina Tapia',                   // 247
  'Fernando Morales Núñez',         // 248
  'Doceat',                         // 249
  'Carlos de la Fé',                // 250
];

// ── Aliases: nombre web → nombre/slug en Firestore ───────────────────────────
// Cubre casos donde el nombre web difiere del usado en el import
const ALIASES = {
  'Volantones':            'naz-asociacion-volantones',
  'Eva G. Bullido':        'naz-eva-g-bullido-teresa-munoz-valera',
  'Teresa Muñoz Valera':   'naz-teresa-munoz-valera',
  'Mª Cristina Hernández González': 'naz-m-cristina-hernandez-gonzalez',
  'José Ángel Moreno «Kazo»':       'naz-jose-angel-moreno-kazo',
  'EC13 ~ Cosmic Vibes':            'naz-ec13-cosmic-vibes',
  'Emilio Rodríguez Linares, Linarett': 'naz-emilio-rodriguez-linares-linarett',
};

// ── Helpers ───────────────────────────────────────────────────────────────────
function toSlug(nombre) {
  return nombre.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function docId(nombre) {
  if (ALIASES[nombre] !== undefined) return ALIASES[nombre]; // null = saltar
  return 'naz-' + toSlug(nombre);
}

function normNombre(n) {
  return (n || '').toLowerCase().trim().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ');
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`🚀 ${DRY_RUN ? '[DRY-RUN] ' : ''}Asignando prioridades a ${ORDEN_NAZARI.length} autores…\n`);

  const db     = admin.firestore();
  const colRef = db.collection('empresas').doc(EID).collection('autores');

  // Cargar TODOS los docs con su contenido para búsqueda por nombre
  const snap = await colRef.get();
  console.log(`  ℹ️  Autores en Firestore: ${snap.size}\n`);

  // Mapa id → doc + mapa nombreNorm → [ids]
  const idSet      = new Set(snap.docs.map(d => d.id));
  const nombreMap  = new Map(); // nombreNorm → docId (el mejor candidato)
  for (const doc of snap.docs) {
    const n = normNombre(doc.data().nombre);
    if (n) {
      if (!nombreMap.has(n)) nombreMap.set(n, doc.id);
      // Si existe un id naz-* preferirlo sobre un autogenerado
      else if (doc.id.startsWith('naz-') && !nombreMap.get(n).startsWith('naz-')) {
        nombreMap.set(n, doc.id);
      }
    }
  }

  // Conjunto de IDs canónicos (los que deben tener prioridad)
  const canonicos = new Set();

  if (DRY_RUN) {
    ORDEN_NAZARI.forEach((nombre, i) => {
      const id = docId(nombre);
      const skip = id === null ? ' [OMITIDO]' : '';
      const byName = id ? null : nombreMap.get(normNombre(nombre));
      console.log(`  ${String(i + 1).padStart(3)}. ${nombre}${skip}`);
      if (byName) console.log(`       → encontrado por nombre: ${byName}`);
    });
    console.log('\n[DRY-RUN] No se escribió nada.');
    return;
  }

  let batch   = db.batch();
  let cnt     = 0;
  let ok      = 0;
  let porNombre = 0;
  let noEncontrados = [];

  for (let i = 0; i < ORDEN_NAZARI.length; i++) {
    const nombre    = ORDEN_NAZARI[i];
    const prioridad = i + 1;
    let   id        = docId(nombre);

    if (id === null) continue; // entrada combinada — omitir

    // Si el slug no existe, buscar por nombre normalizado (docs creados en Fluix)
    if (!idSet.has(id)) {
      const byName = nombreMap.get(normNombre(nombre));
      if (byName) {
        console.log(`  🔎 ${nombre}: slug no encontrado → usando ${byName}`);
        id = byName;
        porNombre++;
      } else {
        noEncontrados.push({ prioridad, nombre, id });
        continue;
      }
    }

    canonicos.add(id);
    batch.update(colRef.doc(id), { prioridad, orden: prioridad });
    ok++;
    cnt++;

    if (cnt === 400) {
      await batch.commit();
      batch = db.batch();
      cnt   = 0;
      console.log('  ⏳ Lote enviado…');
    }
  }

  if (cnt > 0) await batch.commit();

  console.log(`\n✅ Prioridades actualizadas: ${ok}${porNombre ? ` (${porNombre} encontrados por nombre)` : ''}`);

  // Docs extra: existen en Firestore pero NO están en el orden canónico
  const extras = snap.docs.filter(d => !canonicos.has(d.id));
  if (extras.length && !DEL_EXTRAS) {
    console.log(`\n📋 Docs EXTRA en Firestore (${extras.length}) — no están en la lista de 250:`);
    extras.forEach(d => {
      const data = d.data();
      const info = [data.nombre || '(sin nombre)', data.bio ? 'con bio' : 'sin bio', data.foto || data.foto_url ? 'con foto' : 'sin foto'].join(' · ');
      console.log(`   ${d.id.padEnd(50)} ${info}`);
    });
    console.log('\n  💡 Para borrarlos ejecuta:');
    console.log('     node asignar_prioridades_nazari.js --delete-extras');
  }

  // ── Modo borrado de extras ────────────────────────────────────────────────
  if (DEL_EXTRAS && extras.length) {
    console.log(`\n🗑  Borrando ${extras.length} docs extra…`);
    // Solo borramos los que tienen un equivalente naz-* canónico con el mismo nombre
    let borrados = 0;
    let batch2   = db.batch();
    let cnt2     = 0;

    for (const d of extras) {
      const nombreDoc  = normNombre(d.data().nombre);
      // Buscar si existe un doc canónico con ese nombre
      const canonicId  = nombreMap.get(nombreDoc);
      const esDuplicado = canonicId && canonicos.has(canonicId);
      // Borrar siempre si ID es puramente numérico (1er import con id numérico)
      const esNumerico  = /^\d+$/.test(d.id);

      if (esDuplicado || esNumerico) {
        batch2.delete(colRef.doc(d.id));
        console.log(`   🗑  ${d.id.padEnd(50)} ${d.data().nombre}`);
        borrados++;
        cnt2++;
        if (cnt2 === 400) {
          await batch2.commit();
          batch2 = db.batch();
          cnt2   = 0;
        }
      } else {
        console.log(`   ⚠️  Conservado (sin equivalente canónico): ${d.id} — ${d.data().nombre}`);
      }
    }
    if (cnt2 > 0) await batch2.commit();
    console.log(`\n✅ Borrados: ${borrados} docs extra`);
  }

  if (noEncontrados.length) {
    console.log(`\n⚠️  Todavía no encontrados (${noEncontrados.length}):`);
    noEncontrados.forEach(({ prioridad, nombre, id }) => {
      console.log(`   ${String(prioridad).padStart(3)}. ${nombre} → ${id}`);
    });
  }

  console.log(`\nDestino: empresas/${EID}/autores`);
  process.exit(0);
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
