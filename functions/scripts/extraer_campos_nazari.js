'use strict';

/**
 * extraer_campos_nazari.js
 * Lee extraer_url_resultado.json y extrae los campos estructurados de cada libro:
 * ISBN, Categorías, Etiquetas, ID Producto, Autor, ISBN13, Colección, Tamaño,
 * Páginas, Idioma, Edición, Fecha de impresión, Encuadernación.
 * Ordena alfabéticamente por autor y guarda libros_nazari.json.
 *
 * Uso: node scripts/extraer_campos_nazari.js [--input otro.json] [--json]
 */

const fs   = require('fs');
const path = require('path');

const argVal   = f => { const i = process.argv.indexOf(f); return i >= 0 ? process.argv[i+1] : null; };
const INPUT    = argVal('--input') || path.join(__dirname, 'extraer_url_resultado.json');
const GUARDAR  = process.argv.includes('--json');

if (!fs.existsSync(INPUT)) {
  console.error('No se encuentra:', INPUT);
  console.error('Ejecuta primero: node scripts/extraer_url.js <url-catalogo> --completo --json');
  process.exit(1);
}

const data     = JSON.parse(fs.readFileSync(INPUT, 'utf8'));
const registros = Array.isArray(data) ? data : (data.registros || []);

// ── Extractor ──────────────────────────────────────────────────────────────
function campo(txt, patron, flags) {
  const m = txt.match(new RegExp(patron, flags || 'i'));
  return m ? m[1].replace(/\s+/g, ' ').trim() : '';
}

function parsearLibro(r) {
  const txt = r.contenido_principal || (r.parrafos || []).join('\n');
  if (!txt) return null;

  // Título limpio — se define primero porque la extracción de precio lo necesita
  const titulo = (r.titulo || '')
    .replace(/\s*[\-|]\s*Editorial Nazar[ií]\s*$/i, '')
    .replace(/\s*[\-|]\s*Tienda\s*$/i, '')
    .trim();

  // Sección WooCommerce: "ISBN: X Categorías: X Etiqueta(s): X ID Producto: X\nAutor(a): X."
  const isbn      = campo(txt, 'ISBN:\\s*([\\d\\-]+)');
  const categorias = campo(txt, 'Categor[ií]as?:\\s*(.+?)(?=\\s+Etiqueta|\\s+ID Producto|\\s+Autor|$)', 'si')
                       .replace(/\s*\n\s*/g, ', ').trim();
  const etiquetas  = campo(txt, 'Etiquetas?:\\s*(.+?)(?=\\s+ID Producto|\\s+Autor|$)', 'si')
                       .replace(/\s*\n\s*/g, ', ').trim();
  const id_producto = campo(txt, 'ID Producto:\\s*(\\d+)');
  const autor      = campo(txt, 'Autor[a]?:\\s*([^.\\n]+)');

  // Sección "Más información": campos en líneas separadas
  const isbn13         = campo(txt, 'ISBN13[:\\s]+([\\d]+)');
  const coleccion      = campo(txt, 'Colecci[oó]n:\\s*([^\\n]+)');
  const tamano         = campo(txt, 'Tama[nñ]o:\\s*([^\\n]+)');
  const paginas        = campo(txt, 'P[aá]ginas:\\s*(\\d+)');
  const idioma         = campo(txt, 'Idioma:\\s*([^\\n]+)');
  const edicion        = campo(txt, 'Edici[oó]n:\\s*([^\\n]+)');
  const fecha_impresion = campo(txt, 'Fecha de impresi[oó]n:\\s*([^\\n]+)');
  const encuadernacion  = campo(txt, 'Encuadernaci[oó]n:\\s*([^\\n]+)');

  // Precios separados ebook / impreso
  // El precio siempre aparece en la línea inmediatamente después del título
  let precio_ebook = '', precio_impreso = '', precio_unico = '';

  // 1. Rango "X,XX - Y,YY Rango de precios" → ebook (menor) + impreso (mayor)
  const rangoM = txt.match(/([\d,]+)\s*[-–]\s*([\d,]+)\s*Rango/);
  if (rangoM) {
    const p1 = parseFloat(rangoM[1].replace(',','.')), p2 = parseFloat(rangoM[2].replace(',','.'));
    precio_ebook   = (p1 <= p2 ? rangoM[1] : rangoM[2]) + ' €';
    precio_impreso = (p1 <= p2 ? rangoM[2] : rangoM[1]) + ' €';
  } else {
    // 2. Precio en la línea justo después del título (WooCommerce siempre lo pone ahí)
    const lineas = txt.split('\n');
    const iTitulo = lineas.findIndex(l => l.trim() === titulo || l.trim() === titulo + ' cantidad');
    const lineaPrecio = iTitulo >= 0 ? lineas.slice(iTitulo + 1, iTitulo + 4).find(l => /^\d+[,\.]\d{2}/.test(l.trim())) : null;
    const rawPrecio = lineaPrecio ? lineaPrecio.trim() : (
      txt.match(/"price_html":"([\d,]+)\s*"/)?.[1] || ''
    );
    if (rawPrecio) {
      // Dos precios en la misma línea sin "Rango": "X,XX Y,YY" → ebook + impreso
      const dosM = rawPrecio.match(/^([\d,]+)\s+([\d,]+)$/);
      if (dosM) {
        const p1 = parseFloat(dosM[1].replace(',','.')), p2 = parseFloat(dosM[2].replace(',','.'));
        precio_ebook   = (p1 <= p2 ? dosM[1] : dosM[2]) + ' €';
        precio_impreso = (p1 <= p2 ? dosM[2] : dosM[1]) + ' €';
      } else {
        // Un solo precio → determinar tipo por el atributo WooCommerce o por categoría
        const tipo = txt.match(/"attribute_pa_tipo-de-libro":"(ebook|impreso)"/)?.[1]
                  || (categorias.toLowerCase().includes('ebook') ? 'ebook' : 'impreso');
        const val = rawPrecio.replace(/\s.*/, '') + ' €';
        if (tipo === 'ebook') precio_ebook = val;
        else precio_impreso = val;
      }
    }
  }


  // Sinopsis: bloque antes de "ISBN:", filtrando breadcrumb, título, precio, botones
  const idxIsbn = txt.indexOf('ISBN:');
  const sinopsisBloque = idxIsbn > 0 ? txt.substring(0, idxIsbn) : txt.substring(0, 1200);
  const precioRe = /^[\d,.]+\s*(?:€|[-–][\s\d,.]*)?\s*(?:Rango de precios)?/;
  const sinopsis = sinopsisBloque
    .split('\n')
    .map(l => l.trim())
    .filter(l => l &&
      !l.includes('Inicio /') &&
      !l.includes('Añadir al carrito') &&
      !l.includes('Limpiar') &&
      !l.includes('cantidad') &&
      !l.match(/^One moment/) &&
      !l.match(precioRe) &&
      l !== titulo
    )
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

  const portada = r.og_image ? r.og_image.replace(/https?:\/\/web\.archive\.org\/web\/\d+im_\//, '') : '';

  return {
    titulo,
    autor,
    isbn,
    isbn13,
    coleccion,
    categorias,
    etiquetas,
    precio_ebook,
    precio_impreso,
    precio_unico,
    paginas:          paginas ? +paginas : null,
    tamano,
    idioma,
    edicion,
    fecha_impresion,
    encuadernacion,
    id_producto,
    sinopsis,
    portada,
    url:              r.url,
    fuente:           r._fuente || '',
  };
}

// ── Procesar ───────────────────────────────────────────────────────────────
const tituloKey = s => (s || '').trim();

const libros = registros
  .map(parsearLibro)
  .filter(Boolean)
  .filter(l => l.isbn || (l.titulo && !l.titulo.match(/one moment|please wait|wayback/i) && l.titulo !== 'Tienda'))
  // Eliminar duplicados por ISBN (si tienen ISBN) o por título
  .filter((l, idx, arr) => {
    if (l.isbn) return arr.findIndex(x => x.isbn === l.isbn) === idx;
    return arr.findIndex(x => tituloKey(x.titulo) === tituloKey(l.titulo)) === idx;
  })
  .sort((a, b) => {
    // Primero los que tienen ISBN, luego los que no
    if (a.isbn && !b.isbn) return -1;
    if (!a.isbn && b.isbn) return 1;
    // Alfabético por título (números primero, artículos ignorados)
    return tituloKey(a.titulo).localeCompare(tituloKey(b.titulo), 'es', { numeric: true, sensitivity: 'base' });
  });

// ── Mostrar ────────────────────────────────────────────────────────────────
const sep = '─'.repeat(72);
libros.forEach((l, i) => {
  console.log('\n' + sep);
  console.log(String(i + 1).padStart(3) + '. ' + (l.titulo || '(sin título)'));
  if (l.autor)           console.log('    Autor:              ' + l.autor);
  if (l.isbn)            console.log('    ISBN:               ' + l.isbn);
  if (l.isbn13)          console.log('    ISBN13:             ' + l.isbn13);
  if (l.coleccion)       console.log('    Colección:          ' + l.coleccion);
  if (l.categorias)      console.log('    Categorías:         ' + l.categorias);
  if (l.etiquetas)       console.log('    Etiquetas:          ' + l.etiquetas);
  if (l.precio_ebook)    console.log('    Precio ebook:       ' + l.precio_ebook);
  if (l.precio_impreso)  console.log('    Precio impreso:     ' + l.precio_impreso);
  if (l.precio_unico)    console.log('    Precio:             ' + l.precio_unico);
  if (l.paginas)         console.log('    Páginas:            ' + l.paginas);
  if (l.tamano)          console.log('    Tamaño:             ' + l.tamano);
  if (l.idioma)          console.log('    Idioma:             ' + l.idioma);
  if (l.edicion)         console.log('    Edición:            ' + l.edicion);
  if (l.fecha_impresion) console.log('    Fecha impresión:    ' + l.fecha_impresion);
  if (l.encuadernacion)  console.log('    Encuadernación:     ' + l.encuadernacion);
  if (l.id_producto)     console.log('    ID Producto:        ' + l.id_producto);
  if (l.sinopsis) {
    console.log('    Sinopsis:');
    l.sinopsis.split('\n').slice(0, 4).forEach(line => console.log('      ' + line));
    const lines = l.sinopsis.split('\n');
    if (lines.length > 4) console.log('      ... (' + lines.length + ' líneas)');
  }
});

console.log('\n' + '═'.repeat(72));
console.log(' TOTAL: ' + libros.length + ' libros ordenados por autor');

const conIsbn    = libros.filter(l => l.isbn).length;
const conSinopsis = libros.filter(l => l.sinopsis && l.sinopsis.length > 50).length;
const conFecha   = libros.filter(l => l.fecha_impresion).length;
console.log(' Con ISBN: ' + conIsbn + ' | Con sinopsis: ' + conSinopsis + ' | Con fecha impresión: ' + conFecha);

// ── Guardar JSON ────────────────────────────────────────────────────────────
const outFile = path.join(__dirname, 'libros_nazari.json');
fs.writeFileSync(outFile, JSON.stringify({
  fecha:    new Date().toISOString(),
  fuente:   INPUT,
  total:    libros.length,
  libros,
}, null, 2), 'utf8');
console.log('\nGuardado: ' + outFile);
