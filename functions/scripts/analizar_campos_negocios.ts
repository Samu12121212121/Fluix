// functions/scripts/analizar_campos_negocios.ts
//
// Analiza qué campos faltan en cada documento de negocios_publicos.
//
// Uso:
//   cd functions
//   npx ts-node --project scripts/tsconfig.scripts.json --transpileOnly scripts/analizar_campos_negocios.ts

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

const saPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
const db = admin.firestore();

// Campos evaluados y su "peso" de importancia
const CAMPOS: { campo: string; label: string; critico: boolean }[] = [
  { campo: 'nombre',             label: 'Nombre',              critico: true  },
  { campo: 'categoria',          label: 'Categoría',           critico: true  },
  { campo: 'activo',             label: 'Activo',              critico: true  },
  { campo: 'fotoUrl',            label: 'Foto principal',      critico: true  },
  { campo: 'descripcion',        label: 'Descripción',         critico: true  },
  { campo: 'direccion',          label: 'Dirección',           critico: true  },
  { campo: 'telefono',           label: 'Teléfono',            critico: true  },
  { campo: 'ratingGoogle',       label: 'Rating Google',       critico: false },
  { campo: 'tagline',            label: 'Tagline',             critico: false },
  { campo: 'web',                label: 'Web',                 critico: false },
  { campo: 'instagram',          label: 'Instagram',           critico: false },
  { campo: 'facebook',           label: 'Facebook',            critico: false },
  { campo: 'whatsapp',           label: 'WhatsApp',            critico: false },
  { campo: 'googleMapsUrl',      label: 'Google Maps URL',     critico: false },
  { campo: 'latitud',            label: 'Latitud',             critico: false },
  { campo: 'longitud',           label: 'Longitud',            critico: false },
  { campo: 'horario',            label: 'Horario',             critico: false },
  { campo: 'serviciosDestacados',label: 'Servicios destacados',critico: false },
  { campo: 'fotosGaleria',       label: 'Galería de fotos',    critico: false },
  { campo: 'precioMedio',        label: 'Precio medio',        critico: false },
];

const CRITICOS = CAMPOS.filter(c => c.critico).map(c => c.campo);
const TOTAL    = CAMPOS.length;

interface Resumen {
  id: string;
  nombre: string;
  categoria: string;
  camposFaltantes: string[];
  camposCriticosFaltantes: string[];
  pct: number;
}

async function main() {
  const snap = await db.collection('negocios_publicos').get();
  const docs = snap.docs;

  console.log(`\n📊 ANÁLISIS DE CAMPOS — negocios_publicos`);
  console.log(`   Total documentos: ${docs.length}\n`);

  const resultados: Resumen[] = [];

  for (const doc of docs) {
    const d = doc.data();
    const faltantes     = CAMPOS.filter(c => !d[c.campo]).map(c => c.label);
    const criticosFalt  = CAMPOS.filter(c => c.critico && !d[c.campo]).map(c => c.label);
    const completos     = TOTAL - faltantes.length;
    const pct           = Math.round((completos / TOTAL) * 100);

    resultados.push({
      id:                     doc.id,
      nombre:                 d.nombre ?? doc.id,
      categoria:              d.categoria ?? '?',
      camposFaltantes:        faltantes,
      camposCriticosFaltantes: criticosFalt,
      pct,
    });
  }

  // Ordenar: primero los menos completos
  resultados.sort((a, b) => a.pct - b.pct);

  // ── Tabla por negocio ──────────────────────────────────────────────────────
  console.log(`${'NEGOCIO'.padEnd(48)} ${'CAT'.padEnd(14)} ${'%'}   CRÍTICOS FALTANTES`);
  console.log('─'.repeat(100));

  for (const r of resultados) {
    const bar    = '█'.repeat(Math.round(r.pct / 10)).padEnd(10, '░');
    const criStr = r.camposCriticosFaltantes.length === 0
      ? '✓ completo'
      : r.camposCriticosFaltantes.join(', ');
    console.log(
      `${r.nombre.substring(0, 47).padEnd(48)} ${r.categoria.padEnd(14)} ${String(r.pct).padStart(3)}%  ${bar}  ${criStr}`
    );
  }

  // ── Resumen global ──────────────────────────────────────────────────────────
  const conFoto      = resultados.filter(r => !r.camposFaltantes.includes('Foto principal')).length;
  const conDir       = resultados.filter(r => !r.camposFaltantes.includes('Dirección')).length;
  const conTel       = resultados.filter(r => !r.camposFaltantes.includes('Teléfono')).length;
  const conDesc      = resultados.filter(r => !r.camposFaltantes.includes('Descripción')).length;
  const conRating    = resultados.filter(r => !r.camposFaltantes.includes('Rating Google')).length;
  const conHorario   = resultados.filter(r => !r.camposFaltantes.includes('Horario')).length;
  const conCoords    = resultados.filter(r => !r.camposFaltantes.includes('Latitud')).length;
  const conWeb       = resultados.filter(r => !r.camposFaltantes.includes('Web')).length;
  const completosTot = resultados.filter(r => r.pct === 100).length;
  const criticos0    = resultados.filter(r => r.camposCriticosFaltantes.length === 0).length;
  const avgPct       = Math.round(resultados.reduce((s, r) => s + r.pct, 0) / resultados.length);

  console.log(`\n${'═'.repeat(100)}`);
  console.log(`📈 RESUMEN GLOBAL`);
  console.log(`${'─'.repeat(100)}`);
  console.log(`  Negocios totales          : ${docs.length}`);
  console.log(`  Completitud media         : ${avgPct}%`);
  console.log(`  Completamente llenos      : ${completosTot} / ${docs.length}`);
  console.log(`  Sin campos críticos falt. : ${criticos0} / ${docs.length}`);
  console.log('');
  console.log(`  CAMPO               TIENEN     FALTAN`);
  console.log(`  ${'─'.repeat(45)}`);

  const printRow = (label: string, tienen: number) => {
    const faltan = docs.length - tienen;
    const bar    = '█'.repeat(Math.round((tienen / docs.length) * 20)).padEnd(20, '░');
    console.log(`  ${label.padEnd(20)} ${String(tienen).padStart(4)} / ${docs.length}  ${bar}  (${faltan} faltan)`);
  };

  printRow('Foto principal',   conFoto);
  printRow('Dirección',        conDir);
  printRow('Teléfono',         conTel);
  printRow('Descripción',      conDesc);
  printRow('Rating Google',    conRating);
  printRow('Horario',          conHorario);
  printRow('Coordenadas GPS',  conCoords);
  printRow('Web',              conWeb);

  console.log(`\n${'═'.repeat(100)}`);

  // Guardar CSV resumen
  const csvPath = path.resolve('C:/Users/Samu/Desktop/analisis_campos_negocios.csv');
  const csvLines = ['id,nombre,categoria,pct_completitud,campos_faltantes,criticos_faltantes'];
  for (const r of resultados) {
    csvLines.push([
      r.id,
      `"${r.nombre}"`,
      r.categoria,
      r.pct,
      `"${r.camposFaltantes.join(' | ')}"`,
      `"${r.camposCriticosFaltantes.join(' | ')}"`,
    ].join(','));
  }
  fs.writeFileSync(csvPath, csvLines.join('\n'), 'utf-8');
  console.log(`\n📄 CSV guardado en: ${csvPath}\n`);

  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
