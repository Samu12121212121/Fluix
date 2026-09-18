/**
 * importar_blog_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Importa las 150 primeras entrevistas de Editorial Nazarí a la colección
 * `blog` de Firestore (empresa 0PoomHYDUJf5w8tDFRLhFi9iURF3).
 *
 * - Salta documentos ya existentes (usa slug como ID)
 * - Obtiene resúmenes en español de la API de WordPress
 * - Admite --solo-nuevas para no sobreescribir existentes
 * - Admite --forzar para actualizar incluso las ya existentes
 *
 * Uso:
 *   cd functions
 *   node scripts/importar_blog_nazari.js
 *   node scripts/importar_blog_nazari.js --forzar
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const https = require('https');

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID    = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const FORZAR = process.argv.includes('--forzar');

// ── Utilidad: HTTPS GET → JSON ────────────────────────────────────────────────
function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'NazariImporter/1.0' } }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch (e) { reject(new Error('JSON parse error: ' + e.message)); }
      });
    }).on('error', reject);
  });
}

// ── Limpia HTML del excerpt de WordPress ─────────────────────────────────────
function limpiarExcerpt(html) {
  if (!html) return '';
  return html
    .replace(/<[^>]+>/g, '')
    .replace(/\n/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/\[&hellip;\]/g, '…')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#8217;/g, '’')
    .replace(/&#8220;/g, '«')
    .replace(/&#8221;/g, '»')
    .replace(/&#8230;/g, '…')
    .trim()
    .substring(0, 500);
}

// ── Obtiene resúmenes del WordPress ──────────────────────────────────────────
async function fetchResumenes() {
  console.log('📡 Obteniendo resúmenes del WordPress...');
  const base = 'https://www.editorialnazari.com/wp-json/wp/v2/posts'
             + '?categories=77&per_page=100&_fields=slug,excerpt&orderby=date&order=desc';
  const [p1, p2] = await Promise.all([
    fetchJson(base + '&page=1'),
    fetchJson(base + '&page=2').catch(() => [])
  ]);
  const mapa = {};
  [...(p1 || []), ...(p2 || [])].forEach(p => {
    if (p.slug && p.excerpt?.rendered) {
      mapa[p.slug] = limpiarExcerpt(p.excerpt.rendered);
    }
  });
  console.log(`✅ Resúmenes obtenidos: ${Object.keys(mapa).length} entradas\n`);
  return mapa;
}

// ── Dataset: 150 entrevistas ──────────────────────────────────────────────────
const ENTREVISTAS = [
  // 2026
  {slug:'manuel-bayona-en-letras-mixtas',titulo:'Manuel Bayona en Letras Mixtas',autor:'Manuel Bayona',fecha:'2026-07-20',imagen_url:'https://www.editorialnazari.com/wp-content/uploads/2026/07/gestion-1024x576.jpg',url_externa:'https://www.editorialnazari.com/manuel-bayona-en-letras-mixtas/'},
  {slug:'entrevista-a-alejandro-santiago-en-educa-edtech-group',titulo:'Alejandro Santiago en Educa EdTech Group',autor:'Alejandro Santiago',fecha:'2026-07-08',imagen_url:'https://www.editorialnazari.com/wp-content/uploads/2026/07/alejandro-santiago-en-educa-edtech-1024x576.jpg',url_externa:'https://www.editorialnazari.com/entrevista-a-alejandro-santiago-en-educa-edtech-group/'},
  {slug:'irene-bosch-blanco-en-temps-de-llibres',titulo:'Irene Bosch Blanco en Temps de Llibres',autor:'Irene Bosch Blanco',fecha:'2026-07-08',imagen_url:'https://www.editorialnazari.com/wp-content/uploads/2026/07/temps-de-llibres-irene-bosch-blanco.jpg',url_externa:'https://www.editorialnazari.com/irene-bosch-blanco-en-temps-de-llibres/'},
  {slug:'daniel-morales-en-radio-salobrena',titulo:'Daniel Morales en Radio Salobreña',autor:'Daniel Morales Escobar',fecha:'2026-02-27',imagen_url:'https://www.editorialnazari.com/wp-content/uploads/2026/02/cronica-granada-01-1024x712.jpg',url_externa:'https://www.editorialnazari.com/daniel-morales-en-radio-salobrena/'},
  {slug:'dulce-lopez-en-la-trinchera-de-los-libros',titulo:'Dulce López en «La trinchera de los libros»',autor:'Dulce López Rodríguez',fecha:'2026-02-26',imagen_url:'https://www.editorialnazari.com/wp-content/uploads/2026/02/untitled-design.jpg',url_externa:'https://www.editorialnazari.com/dulce-lopez-en-la-trinchera-de-los-libros/'},
  {slug:'torcuato-romero-el-tablero-de-ajedrez',titulo:'Torcuato Romero y «El tablero de ajedrez» en El abanico de los lunes',autor:'Torcuato Romero',fecha:'2026-02-18',imagen_url:'https://www.editorialnazari.com/wp-content/uploads/2026/02/el-tablero-de-ajedrez-torcuato-romero-lopez-72ppp.jpg',url_externa:'https://www.editorialnazari.com/torcuato-romero-y-el-tablero-de-ajedrez-en-el-abanico-de-los-lunes/'},
  {slug:'dulce-lopez-cafes-literarios',titulo:'Dulce López Rodríguez en Cafés literarios',autor:'Dulce López Rodríguez',fecha:'2026-02-10',imagen_url:'https://www.editorialnazari.com/wp-content/uploads/2026/02/entrevista-dulce-lopez-1024x761.jpeg',url_externa:'https://www.editorialnazari.com/dulce-lopez-rodriguez-y-creo-que-te-quiero-en-cafes-literarios/'},
  {slug:'manuel-bayona-medico-interactivo',titulo:'Manuel Bayona en El Médico Interactivo',autor:'Manuel Bayona',fecha:'2026-02-04',imagen_url:'https://www.editorialnazari.com/wp-content/uploads/2026/02/manuel-bayona-entrevista-1024x683.jpg',url_externa:'https://www.editorialnazari.com/manuel-bayona-y-la-gestion-del-silencio-en-el-medico-interactivo/'},
  {slug:'al-tercer-dia-podcast-mi-experiencia',titulo:'«Al tercer día» en el pódcast «Mi experiencia como escritor»',autor:'David Macías Gómez',fecha:'2026-01-26',imagen_url:'https://www.editorialnazari.com/wp-content/uploads/2026/01/imagen_cabecera_al_tercer_dia.jpg',url_externa:'https://www.editorialnazari.com/al-tercer-dia-en-el-podcast-mi-experiencia-como-escritor/'},
  // 2025
  {slug:'jesus-avila-granados-libros-y-libretos',titulo:'Jesús Ávila Granados en «Libros y libretos»',autor:'Jesús Ávila Granados',fecha:'2025-09-29',imagen_url:'',url_externa:'https://www.editorialnazari.com/jesus-avila-granados-en-libros-y-libretos/'},
  {slug:'juan-de-dios-villanueva-roa-poeta-armada',titulo:'Juan de Dios Villanueva Roa en Poeta Armada',autor:'Juan de Dios Villanueva Roa',fecha:'2025-07-31',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-juan-de-dios-villanueva-roa-en-poeta-armada/'},
  {slug:'comodamente-adormecido-mijas-tv',titulo:'«Cómodamente adormecido» en Mijas TV',autor:'Juan Quero',fecha:'2025-04-22',imagen_url:'',url_externa:'https://www.editorialnazari.com/comodamente-adormecido-en-mijas-tv/'},
  {slug:'comodamente-adormecido-fuengirola-tv',titulo:'«Cómodamente adormecido» en Fuengirola TV',autor:'Juan Quero',fecha:'2025-04-22',imagen_url:'',url_externa:'https://www.editorialnazari.com/comodamente-adormecido-en-fuengirola-tv/'},
  {slug:'cuando-termina-la-ciencia-la-voz-a-ti-debida',titulo:'«Cuando termina la ciencia» en La voz a ti debida',autor:'Susana Collado',fecha:'2025-02-06',imagen_url:'',url_externa:'https://www.editorialnazari.com/cuando-termina-la-ciencia-y-empieza-la-ficcion-en-la-voz-a-ti-debida/'},
  {slug:'susana-collado-onda-cero-madrid-sur',titulo:'Susana Collado en Onda Cero Madrid Sur',autor:'Susana Collado',fecha:'2025-01-23',imagen_url:'',url_externa:'https://www.editorialnazari.com/susana-collado-en-onda-cero-madrid-sur/'},
  {slug:'jonas-y-la-esperanza-buenos-dias-albolote',titulo:'«Jonás y la esperanza» en Buenos Días Albolote',autor:'Juan Carlos Rodríguez Torres',fecha:'2025-01-13',imagen_url:'',url_externa:'https://www.editorialnazari.com/jonas-y-la-esperanza-en-buenos-dias-albolote/'},
  // 2024
  {slug:'juan-carlos-rodriguez-buenos-dias-albolote',titulo:'Juan Carlos Rodríguez Torres en Buenos Días Albolote',autor:'Juan Carlos Rodríguez Torres',fecha:'2024-10-14',imagen_url:'',url_externa:'https://www.editorialnazari.com/juan-carlos-rodriguez-torres-en-buenos-dias-albolote-a/'},
  {slug:'ana-navarro-relatos-fulgurantes-fe-de-vida',titulo:'Ana Navarro y «Relatos fulgurantes» en Fe de Vida',autor:'Ana Navarro',fecha:'2024-10-08',imagen_url:'',url_externa:'https://www.editorialnazari.com/ana-navarro-y-relatos-fulgurantes-en-fe-de-vida/'},
  {slug:'daniel-fuentes-casado-vitak-ora-club',titulo:'Daniel Fuentes Casado en V.Iták-Ora Club',autor:'Daniel Fuentes Casado',fecha:'2024-06-25',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-daniel-fuentes-casado-para-v-itak-ora-club/'},
  {slug:'estibaliz-madrazo-el-viaje-onda-vasca',titulo:'Estíbaliz Madrazo y «El Viaje» en Onda Vasca',autor:'Estíbaliz Madrazo',fecha:'2024-05-27',imagen_url:'',url_externa:'https://www.editorialnazari.com/estibaliz-madrazo-y-el-viaje-en-onda-vasca/'},
  {slug:'rosario-galvez-pedestal-cobardes-onda-cero',titulo:'Rosario R. Gálvez y «El pedestal de los cobardes» en Onda Cero',autor:'Rosario R. Gálvez',fecha:'2024-04-11',imagen_url:'',url_externa:'https://www.editorialnazari.com/rosario-r-galvez-y-el-pedestal-de-los-cobardes-en-onda-cero/'},
  {slug:'rosario-galvez-pedestal-cobardes-radio-alcala',titulo:'Rosario R. Gálvez y «El pedestal de los cobardes» en Radio Alcalá',autor:'Rosario R. Gálvez',fecha:'2024-04-10',imagen_url:'',url_externa:'https://www.editorialnazari.com/rosario-r-galvez-y-el-pedestal-de-los-cobardes-en-radio-alcala/'},
  {slug:'arturo-palenzuela-preludio-dias-de-radio',titulo:'Arturo Palenzuela y «Preludio, muerte y fuga» en Días de Radio',autor:'Arturo Palenzuela',fecha:'2024-04-01',imagen_url:'',url_externa:'https://www.editorialnazari.com/arturo-palenzuela-y-preludio-muerte-y-fuga-en-dias-de-radio/'},
  {slug:'entrevista-antigona-marquez-pascual',titulo:'Entrevista a Antígona Márquez Pascual',autor:'Antígona Márquez Pascual',fecha:'2024-03-27',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-antigona-marquez-pascual/'},
  {slug:'enrique-moron-en-el-perfil-del-sueno-ideal',titulo:'Enrique Morón y «En el perfil del sueño» en Ideal',autor:'Enrique Morón',fecha:'2024-03-27',imagen_url:'',url_externa:'https://www.editorialnazari.com/enrique-moron-y-en-el-perfil-del-sueno-en-ideal-en-clase/'},
  {slug:'lectura-consciente-pedestal-cobardes-churriana',titulo:'Lectura consciente de «El pedestal de los cobardes» en Churriana de la Vega',autor:'Rosario R. Gálvez',fecha:'2024-03-12',imagen_url:'',url_externa:'https://www.editorialnazari.com/lectura-consciente-de-el-pedestal-de-los-cobardes-en-churriana-de-la-vega/'},
  {slug:'f-javier-cano-cadena-ser-soria',titulo:'F. Javier Cano Santa Bárbara en Cadena SER Soria',autor:'F. Javier Cano Santa Bárbara',fecha:'2024-03-08',imagen_url:'',url_externa:'https://www.editorialnazari.com/f-javier-cano-santa-barbara-en-cadena-ser-soria/'},
  {slug:'lorena-avelar-yo-es-otro-2',titulo:'Lorena Avelar en «Yo es otro» (2ª parte)',autor:'Lorena Avelar',fecha:'2024-02-26',imagen_url:'',url_externa:'https://www.editorialnazari.com/lorena-avelar-en-yo-es-otro-2a-parte/'},
  {slug:'fernando-soriano-luis-peinador',titulo:'Fernando Soriano con Luis Peinador',autor:'Fernando Soriano',fecha:'2024-02-20',imagen_url:'',url_externa:'https://www.editorialnazari.com/fernando-soriano-con-luis-peinador/'},
  {slug:'lorena-avelar-yo-es-otro-1',titulo:'Lorena Avelar en «Yo es otro» (1ª parte)',autor:'Lorena Avelar',fecha:'2024-02-20',imagen_url:'',url_externa:'https://www.editorialnazari.com/lorena-avelar-en-yo-es-otro/'},
  {slug:'mi-vida-en-el-bunker-8-magazine-bierzo',titulo:'«Mi vida en el búnker» en 8 Magazine Bierzo',autor:'Manuel Ángel Morales Escudero',fecha:'2024-02-08',imagen_url:'',url_externa:'https://www.editorialnazari.com/mi-vida-en-el-bunker-en-8-magazine-bierzo/'},
  {slug:'mi-vida-en-el-bunker-la-nueva-cronica',titulo:'«Mi vida en el búnker» en La Nueva Crónica',autor:'Manuel Ángel Morales Escudero',fecha:'2024-01-17',imagen_url:'',url_externa:'https://www.editorialnazari.com/mi-vida-en-el-bunker-en-la-nueva-cronica/'},
  {slug:'cuentame-vitaliano-de-la-cruz',titulo:'Cuéntame con Vitaliano de la Cruz',autor:'Vitaliano de la Cruz',fecha:'2024-01-03',imagen_url:'',url_externa:'https://www.editorialnazari.com/cuentame-con-vitaliano-de-la-cruz/'},
  // 2023
  {slug:'ramon-lopez-pazos-hoy-por-hoy-madrid',titulo:'Ramón López Pazos en Hoy por hoy Madrid',autor:'Ramón López Pazos',fecha:'2023-12-04',imagen_url:'',url_externa:'https://www.editorialnazari.com/ramon-lopez-pazos-en-hoy-por-hoy-madrid/'},
  {slug:'alberto-cordero-radio-isla-cristina',titulo:'Alberto Cordero Contreras en Radio Isla Cristina',autor:'Alberto Cordero Contreras',fecha:'2023-12-01',imagen_url:'',url_externa:'https://www.editorialnazari.com/alberto-cordero-contreras-en-radio-isla-cristina/'},
  {slug:'el-sofa-de-carmen-bajo-el-limonero',titulo:'«El sofá de Carmen» en Bajo el Limonero',autor:'Iduna RuSol',fecha:'2023-11-30',imagen_url:'',url_externa:'https://www.editorialnazari.com/el-sofa-de-carmen-en-bajo-el-limonero/'},
  {slug:'el-sofa-de-carmen-lasexta-noticias',titulo:'«El sofá de Carmen» en LaSexta Noticias',autor:'Iduna RuSol',fecha:'2023-11-30',imagen_url:'',url_externa:'https://www.editorialnazari.com/el-sofa-de-carmen-en-lasexta-noticias/'},
  {slug:'el-lugar-de-la-caracola-ideal-en-clase',titulo:'«El lugar de la caracola» en Ideal en Clase',autor:'Susi Campos',fecha:'2023-11-23',imagen_url:'',url_externa:'https://www.editorialnazari.com/el-lugar-de-la-caracola-en-ideal-en-clase/'},
  {slug:'la-corona-del-cuervo-ideal-en-clase',titulo:'«La Corona del Cuervo» en Ideal en Clase',autor:'J. S. Castañeda',fecha:'2023-10-31',imagen_url:'',url_externa:'https://www.editorialnazari.com/la-corona-del-cuervo-en-ideal/'},
  {slug:'la-isla-invertida-ideal-en-clase',titulo:'«La Isla Invertida» en Ideal en Clase',autor:'Antonio Molina Cuevas',fecha:'2023-10-17',imagen_url:'',url_externa:'https://www.editorialnazari.com/la-isla-invertida-en-ideal-en-clase/'},
  {slug:'enrique-jaramillo-levi-la-estrella-de-panama',titulo:'Enrique Jaramillo Levi en La Estrella de Panamá',autor:'Enrique Jaramillo Levi',fecha:'2023-07-02',imagen_url:'',url_externa:'https://www.editorialnazari.com/enrique-jaramillo-levi-en-la-estrella-de-panama/'},
  {slug:'antonio-cesar-moron-viento-de-levante',titulo:'Antonio César Morón en Viento de Levante',autor:'Antonio César Morón',fecha:'2023-06-26',imagen_url:'',url_externa:'https://www.editorialnazari.com/antonio-cesar-moron-en-viento-de-levante/'},
  {slug:'el-jardin-de-estocolmo-melilla',titulo:'«El jardín de Estocolmo» en Melilla',autor:'Antonio César Morón',fecha:'2023-06-20',imagen_url:'',url_externa:'https://www.editorialnazari.com/asi-fue-la-presentacion-de-el-jardin-de-estocolmo-en-melilla/'},
  // 2022
  {slug:'ladrar-a-la-luna-ideal',titulo:'«Ladrar a la luna» en Ideal',autor:'Pedro López Ávila',fecha:'2022-11-24',imagen_url:'',url_externa:'https://www.editorialnazari.com/ladrar-a-la-luna-en-ideal/'},
  {slug:'miguel-huguet-gaceta-radio-tv-onda-cartagena',titulo:'Miguel Huguet en Gaceta Radio TV · Onda Cartagena',autor:'Miguel Huguet',fecha:'2022-11-13',imagen_url:'',url_externa:'https://www.editorialnazari.com/miguel-huguet-en-gaceta-radio-tv-onda-cartagena/'},
  {slug:'jesus-avila-granados-granada-hoy',titulo:'Jesús Ávila Granados en Granada Hoy',autor:'Jesús Ávila Granados',fecha:'2022-07-31',imagen_url:'',url_externa:'https://www.editorialnazari.com/jesus-avila-granados-en-granada-hoy/'},
  {slug:'la-bruma-que-apacigua-la-memoria-ideal',titulo:'«La bruma que apacigua la memoria» en Ideal en Clase',autor:'Juan Naveros Sánchez',fecha:'2022-05-27',imagen_url:'',url_externa:'https://www.editorialnazari.com/la-bruma-que-apacigua-la-memoria-en-ideal-en-clase/'},
  {slug:'miguel-angel-ulecia-martinez-en-granada-digital',titulo:'Miguel Ángel Ulecia Martínez en Granada Digital',autor:'Miguel Ángel Ulecia Martínez',fecha:'2022-04-21',imagen_url:'',url_externa:'https://www.editorialnazari.com/miguel-angel-ulecia-martinez-en-granada-digital/'},
  {slug:'juan-antonio-nunez-en-radio-5',titulo:'Juan Antonio Núñez en RNE Radio 5',autor:'Juan Antonio Núñez',fecha:'2022-04-03',imagen_url:'',url_externa:'https://www.editorialnazari.com/juan-antonio-nunez-en-radio-5/'},
  {slug:'alberto-cordero-contreras-en-al-dia-de-wihu-tv',titulo:'Alberto Cordero Contreras en Al día, de WiHu TV',autor:'Alberto Cordero Contreras',fecha:'2022-02-11',imagen_url:'',url_externa:'https://www.editorialnazari.com/alberto-cordero-contreras-en-al-dia-de-wihu-tv/'},
  {slug:'eres-lo-que-escuchas-lp1-en-al-dia-de-wihu-tv',titulo:'«Eres lo que escuchas LP1» en Al día, de WiHu TV',autor:'Alberto Cordero Contreras',fecha:'2022-01-14',imagen_url:'',url_externa:'https://www.editorialnazari.com/eres-lo-que-escuchas-lp1-en-al-dia-de-wihu-tv/'},
  {slug:'eres-lo-que-escuchas-lp1-en-cadena-ser-huelva',titulo:'«Eres lo que escuchas LP1» en Cadena SER Huelva',autor:'Alberto Cordero Contreras',fecha:'2022-01-10',imagen_url:'',url_externa:'https://www.editorialnazari.com/eres-lo-que-escuchas-lp1-en-cadena-ser-huelva/'},
  // 2021
  {slug:'el-maristan-nazari-y-sus-hukama-en-ideal-en-clase',titulo:'«El Maristán Nazarí y sus hukamá» en Ideal en Clase',autor:'Miguel Ángel Ulecia Martínez',fecha:'2021-12-13',imagen_url:'',url_externa:'https://www.editorialnazari.com/el-maristan-nazari-y-sus-hukama-en-ideal-en-clase/'},
  {slug:'entrevista-a-enrique-moron',titulo:'Entrevista a Enrique Morón',autor:'Enrique Morón',fecha:'2021-11-23',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-enrique-moron/'},
  {slug:'sonetario-en-ideal-en-clase',titulo:'«Sonetario» en Ideal en Clase',autor:'Enrique Morón',fecha:'2021-11-23',imagen_url:'',url_externa:'https://www.editorialnazari.com/sonetario-en-ideal-en-clase/'},
  {slug:'acordes-de-tormenta-y-cielo-en-ideal',titulo:'«Acordes de tormenta y cielo» en Ideal',autor:'Juan de Dios Villanueva Roa',fecha:'2021-11-10',imagen_url:'',url_externa:'https://www.editorialnazari.com/acordes-de-tormenta-y-cielo-en-ideal/'},
  {slug:'el-corazon-del-roble-en-hoy-por-hoy-granada',titulo:'«El corazón del roble» en Hoy por hoy Granada',autor:'Enrique Árbol',fecha:'2021-10-02',imagen_url:'',url_externa:'https://www.editorialnazari.com/el-corazon-del-roble-en-hoy-por-hoy-granada/'},
  {slug:'teresa-ariza-perianez-en-ideal',titulo:'Teresa Ariza Periáñez en Ideal',autor:'Teresa Ariza Periáñez',fecha:'2021-06-16',imagen_url:'',url_externa:'https://www.editorialnazari.com/teresa-ariza-perianez-en-ideal/'},
  {slug:'pedro-rojas-pedregosa-en-canal-sur-mediodia-granada',titulo:'Pedro Rojas Pedregosa en Canal Sur Mediodía Granada',autor:'Pedro Rojas Pedregosa',fecha:'2021-06-11',imagen_url:'',url_externa:'https://www.editorialnazari.com/pedro-rojas-pedregosa-en-canal-sur-mediodia-granada/'},
  {slug:'eduardo-cano-mazuecos-en-ideal',titulo:'Eduardo Cano Mazuecos en Ideal',autor:'Eduardo Cano Mazuecos',fecha:'2021-06-10',imagen_url:'',url_externa:'https://www.editorialnazari.com/eduardo-cano-mazuecos-en-ideal/'},
  {slug:'pedro-rojas-pedregosa-en-ideal',titulo:'Pedro Rojas Pedregosa en Ideal',autor:'Pedro Rojas Pedregosa',fecha:'2021-05-29',imagen_url:'',url_externa:'https://www.editorialnazari.com/pedro-rojas-pedregosa-en-ideal/'},
  {slug:'francisco-manuel-miranda-en-ideal',titulo:'Francisco Manuel Miranda en Ideal',autor:'Francisco Manuel Miranda',fecha:'2021-05-22',imagen_url:'',url_externa:'https://www.editorialnazari.com/francisco-manuel-miranda-en-ideal/'},
  {slug:'gaudencio-diaz-munoz-en-ideal-en-clase',titulo:'Gaudencio Díaz Muñoz en Ideal en Clase',autor:'Gaudencio Díaz Muñoz',fecha:'2021-05-20',imagen_url:'',url_externa:'https://www.editorialnazari.com/gaudencio-diaz-munoz-en-ideal-en-clase/'},
  {slug:'cecilia-lopez-ballesteros-en-ideal',titulo:'Cecilia López Ballesteros en Ideal',autor:'Cecilia López Ballesteros',fecha:'2021-05-13',imagen_url:'',url_externa:'https://www.editorialnazari.com/cecilia-lopez-ballesteros-en-ideal/'},
  {slug:'cecilia-lopez-ballesteros-presenta-su-nuevo-libro',titulo:'Cecilia López Ballesteros presenta su nuevo libro',autor:'Cecilia López Ballesteros',fecha:'2021-05-11',imagen_url:'',url_externa:'https://www.editorialnazari.com/cecilia-lopez-ballesteros-presenta-su-nuevo-libro/'},
  {slug:'poker-de-ases-en-ideal',titulo:'«Póker de ases» en Ideal',autor:'Miguel Ángel Hita Padial',fecha:'2021-04-27',imagen_url:'',url_externa:'https://www.editorialnazari.com/poker-de-ases-en-ideal/'},
  {slug:'teatro-de-alarma-en-granada-hoy',titulo:'«Teatro de alarma» en Granada Hoy',autor:'Antonio César Morón',fecha:'2021-04-27',imagen_url:'',url_externa:'https://www.editorialnazari.com/teatro-de-alarma-en-granada-hoy/'},
  {slug:'entrevista-a-daniel-fuentes-casado-en-escritores-org',titulo:'Entrevista a Daniel Fuentes Casado en escritores.org',autor:'Daniel Fuentes Casado',fecha:'2021-04-23',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-daniel-fuentes-casado-en-escritores-org/'},
  {slug:'miguel-angel-hita-padial-en-ideal-en-clase',titulo:'Miguel Ángel Hita Padial en Ideal en Clase',autor:'Miguel Ángel Hita Padial',fecha:'2021-04-23',imagen_url:'',url_externa:'https://www.editorialnazari.com/miguel-angel-hita-padial-en-ideal-en-clase/'},
  {slug:'gaudencio-diaz-munoz-en-canal-sur-mediodia-cordoba',titulo:'Gaudencio Díaz Muñoz en Canal Sur Mediodía Córdoba',autor:'Gaudencio Díaz Muñoz',fecha:'2021-04-10',imagen_url:'',url_externa:'https://www.editorialnazari.com/gaudencio-diaz-munoz-en-canal-sur-mediodia-cordoba-08-04-2021/'},
  {slug:'donde-termina-la-lluvia-en-el-pais',titulo:'«Donde termina la lluvia» en El País',autor:'Juantxu Bohigues',fecha:'2021-04-01',imagen_url:'',url_externa:'https://www.editorialnazari.com/donde-termina-la-lluvia-en-el-pais/'},
  {slug:'jesus-avila-granados-en-ideal',titulo:'Jesús Ávila Granados en Ideal',autor:'Jesús Ávila Granados',fecha:'2021-04-01',imagen_url:'',url_externa:'https://www.editorialnazari.com/jesus-avila-granados-en-ideal/'},
  // 2020
  {slug:'carlos-battaglini-en-el-diario-de-lanzarote',titulo:'Carlos Battaglini en el Diario de Lanzarote',autor:'Carlos Battaglini',fecha:'2020-12-15',imagen_url:'',url_externa:'https://www.editorialnazari.com/carlos-battaglini-en-el-diario-de-lanzarote/'},
  {slug:'encuentro-literario-con-juantxu-bohigues-e-ignacio-castro-rey',titulo:'Encuentro literario con Juantxu Bohigues e Ignacio Castro Rey',autor:'Juantxu Bohigues',fecha:'2020-12-14',imagen_url:'',url_externa:'https://www.editorialnazari.com/encuentro-literario-con-juantxu-bohigues-e-ignacio-castro-rey/'},
  {slug:'carlos-battaglini-en-el-magazine-de-obe',titulo:'Carlos Battaglini en El Magazine de Obe',autor:'Carlos Battaglini',fecha:'2020-11-26',imagen_url:'',url_externa:'https://www.editorialnazari.com/carlos-battaglini-en-el-magazine-de-obe/'},
  {slug:'rodolfo-sanchez-padilla-en-la-hoja-en-blanco',titulo:'Rodolfo Sánchez Padilla en «La Hoja en Blanco»',autor:'Rodolfo Sánchez Padilla',fecha:'2020-11-18',imagen_url:'',url_externa:'https://www.editorialnazari.com/rodolfo-sanchez-padilla-en-la-hoja-en-blanco/'},
  {slug:'miguel-angel-ulecia-en-granada-hoy',titulo:'Miguel Ángel Ulecia en Granada Hoy',autor:'Miguel Ángel Ulecia Martínez',fecha:'2020-10-26',imagen_url:'',url_externa:'https://www.editorialnazari.com/miguel-angel-ulecia-en-granada-hoy/'},
  {slug:'slavko-zupcic-bajo-el-paraguas-del-medritor',titulo:'Slavko Zupcic: «Bajo el paraguas del medritor»',autor:'Slavko Zupcic',fecha:'2020-10-19',imagen_url:'',url_externa:'https://www.editorialnazari.com/slavko-zupcic-bajo-el-paraguas-del-medritor/'},
  {slug:'miguel-angel-ulecia-en-ideal',titulo:'Miguel Ángel Ulecia en Ideal',autor:'Miguel Ángel Ulecia Martínez',fecha:'2020-10-19',imagen_url:'',url_externa:'https://www.editorialnazari.com/miguel-angel-ulecia-en-ideal/'},
  {slug:'antonio-marin-sanchez-en-ideal',titulo:'Antonio Marín Sánchez en Ideal',autor:'Antonio Marín Sánchez',fecha:'2020-08-31',imagen_url:'',url_externa:'https://www.editorialnazari.com/antonio-marin-sanchez-en-ideal/'},
  {slug:'antonio-cesar-moron-en-ideal',titulo:'Antonio César Morón en Ideal',autor:'Antonio César Morón',fecha:'2020-02-22',imagen_url:'',url_externa:'https://www.editorialnazari.com/antonio-cesar-moron-en-ideal/'},
  {slug:'maxim-muller-gomiz-en-onda-cero-granada',titulo:'Maxim Müller Gómiz en Onda Cero Granada',autor:'Maxim Müller Gómiz',fecha:'2020-02-18',imagen_url:'',url_externa:'https://www.editorialnazari.com/maxim-muller-gomiz-en-onda-cero-granada/'},
  {slug:'jesus-saavedra-martin-en-ideal',titulo:'Jesús Saavedra Martín en Ideal',autor:'Jesús Saavedra Martín',fecha:'2020-02-17',imagen_url:'',url_externa:'https://www.editorialnazari.com/jesus-saavedra-martin-en-ideal/'},
  {slug:'rodolfo-padilla-sanchez-en-ideal',titulo:'Rodolfo Padilla Sánchez en Ideal',autor:'Rodolfo Padilla Sánchez',fecha:'2020-02-13',imagen_url:'',url_externa:'https://www.editorialnazari.com/rodolfo-padilla-sanchez-en-ideal/'},
  {slug:'nicolas-melini-en-eldia-es',titulo:'Nicolás Melini en eldia.es',autor:'Nicolás Melini',fecha:'2020-01-27',imagen_url:'',url_externa:'https://www.editorialnazari.com/nicolas-melini-en-eldia-es/'},
  {slug:'nicolas-melini-en-el-comercio-de-asturias',titulo:'Nicolás Melini en El Comercio de Asturias',autor:'Nicolás Melini',fecha:'2020-01-17',imagen_url:'',url_externa:'https://www.editorialnazari.com/nicolas-melini-en-el-comercio-de-asturias/'},
  {slug:'lo-que-opina-isabel-rezmo-por-norberto-garcia-hernanz',titulo:'Lo que opina Isabel Rezmo, por Norberto García Hernanz',autor:'Isabel Rezmo',fecha:'2020-01-03',imagen_url:'',url_externa:'https://www.editorialnazari.com/lo-que-opina-isabel-rezmo-por-norberto-garcia-hernanz/'},
  // 2019
  {slug:'isabel-rezmo-en-poesia-y-mucho-de-radio-puebla',titulo:'Isabel Rezmo en Poesía y mucho + de Radio Puebla',autor:'Isabel Rezmo',fecha:'2019-12-12',imagen_url:'',url_externa:'https://www.editorialnazari.com/isabel-rezmo-en-poesia-y-mucho-de-radio-puebla/'},
  {slug:'isabel-rezmo-en-castillo-de-versos-de-uniradio-jaen',titulo:'Isabel Rezmo en Castillo de versos de UniRadio Jaén',autor:'Isabel Rezmo',fecha:'2019-11-26',imagen_url:'',url_externa:'https://www.editorialnazari.com/isabel-rezmo-en-castillo-de-versos-de-uniradio-jaen/'},
  {slug:'isabel-rezmo-en-entrevistados-de-radio-torredonjimeno',titulo:'Isabel Rezmo en Entrevistados de Radio Torredonjimeno',autor:'Isabel Rezmo',fecha:'2019-11-26',imagen_url:'',url_externa:'https://www.editorialnazari.com/isabel-rezmo-en-entrevistados-de-radio-torredonjimeno/'},
  {slug:'enrique-moron-en-ideal',titulo:'Enrique Morón en Ideal',autor:'Enrique Morón',fecha:'2019-10-29',imagen_url:'',url_externa:'https://www.editorialnazari.com/enrique-moron-en-ideal/'},
  {slug:'mustafa-busfeha-garcia-en-ideal-en-clase',titulo:'Mustafa Busfeha García en Ideal en Clase',autor:'Mustafa Busfeha García',fecha:'2019-07-16',imagen_url:'',url_externa:'https://www.editorialnazari.com/mustafa-busfeha-garcia-en-ideal-en-clase/'},
  {slug:'lorena-avelar-en-ideal-en-clase',titulo:'Lorena Avelar en Ideal en Clase',autor:'Lorena Avelar',fecha:'2019-01-19',imagen_url:'',url_externa:'https://www.editorialnazari.com/lorena-avelar-en-ideal-en-clase/'},
  // 2018-2019
  {slug:'entrevista-a-carmen-m-leon-lopa-en-la-gran-biblioteca-de-david',titulo:'Entrevista a Carmen M. León Lopa en La Gran Biblioteca de David',autor:'Carmen M. León Lopa',fecha:'2019-01-03',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-carmen-m-leon-lopa-en-la-gran-biblioteca-de-david/'},
  {slug:'ana-baldomero-en-ideal-en-clase',titulo:'Ana Baldomero en Ideal en Clase',autor:'Ana Baldomero',fecha:'2018-11-30',imagen_url:'',url_externa:'https://www.editorialnazari.com/ana-baldomero-en-ideal-en-clase/'},
  {slug:'jaime-molina-en-ideal',titulo:'Jaime Molina en Ideal',autor:'Jaime Molina',fecha:'2018-11-29',imagen_url:'',url_externa:'https://www.editorialnazari.com/jaime-molina-en-ideal/'},
  {slug:'enrique-vercher-en-cultura-con-n-de-rne',titulo:'Enrique Vercher en Cultura con ñ, de RNE',autor:'Enrique J. Vercher',fecha:'2018-11-06',imagen_url:'',url_externa:'https://www.editorialnazari.com/enrique-vercher-en-cultura-con-n-de-rne/'},
  {slug:'francisco-montero-en-cadena-ser',titulo:'Francisco Montero en Cadena SER',autor:'Francisco Montero',fecha:'2018-10-19',imagen_url:'',url_externa:'https://www.editorialnazari.com/francisco-montero-en-cadena-ser/'},
  {slug:'bernardo-f-delgado-noguera-en-ideal-en-clase',titulo:'Bernardo F. Delgado Noguera en Ideal en Clase',autor:'Bernardo F. Delgado Noguera',fecha:'2018-10-19',imagen_url:'',url_externa:'https://www.editorialnazari.com/bernardo-f-delgado-noguera-en-ideal-en-clase/'},
  {slug:'entrevista-a-enrique-j-vercher-garcia-en-andalucia-informacion',titulo:'Enrique J. Vercher García en Andalucía Información',autor:'Enrique J. Vercher García',fecha:'2018-06-23',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-enrique-j-vercher-garcia-en-andalucia-informacion/'},
  {slug:'entrevista-a-lucia-marin',titulo:'Entrevista a Lucía Marín',autor:'Lucía Marín',fecha:'2018-06-22',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-lucia-marin/'},
  {slug:'pedro-blanco-naveros-en-gestiona-radio-madrid',titulo:'Pedro Blanco Naveros en Gestiona Radio Madrid',autor:'Pedro Blanco Naveros',fecha:'2018-06-11',imagen_url:'',url_externa:'https://www.editorialnazari.com/pedro-blanco-naveros-en-gestiona-radio-madrid/'},
  {slug:'maria-belen-adarve-en-radio-sin-barreras',titulo:'María Belén Adarve en Radio sin barreras',autor:'María Belén Adarve',fecha:'2018-06-11',imagen_url:'',url_externa:'https://www.editorialnazari.com/maria-belen-adarve-en-radio-sin-barreras/'},
  {slug:'entrevista-a-fernando-soriano-bensusan-en-ideal',titulo:'Fernando Soriano Bensusan en Ideal',autor:'Fernando Soriano Bensusan',fecha:'2018-06-11',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-fernando-soriano-bensusan-en-ideal/'},
  {slug:'cecilia-lopez-ballesteros-en-granada-es-cultura',titulo:'Cecilia López Ballesteros en Granada es cultura',autor:'Cecilia López Ballesteros',fecha:'2018-05-30',imagen_url:'',url_externa:'https://www.editorialnazari.com/cecilia-lopez-ballesteros-en-granada-es-cultura/'},
  {slug:'entrevista-a-enrique-j-vercher-garcia-en-granada-hoy',titulo:'Enrique J. Vercher García en Granada Hoy',autor:'Enrique J. Vercher García',fecha:'2018-05-23',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-enrique-j-vercher-garcia-en-granada-hoy/'},
  {slug:'entrevista-a-cecilia-lopez-ballesteros-en-albolote-informacion',titulo:'Cecilia López Ballesteros en Albolote Información',autor:'Cecilia López Ballesteros',fecha:'2018-05-17',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-cecilia-lopez-ballesteros-en-albolote-informacion/'},
  {slug:'isabel-rezmo-en-guadalquivir-51',titulo:'Isabel Rezmo en Guadalquivir 51',autor:'Isabel Rezmo',fecha:'2018-05-17',imagen_url:'',url_externa:'https://www.editorialnazari.com/isabel-rezmo-en-guadalquivir-51/'},
  {slug:'entrevista-a-enrique-j-vercher-garcia-en-ideal',titulo:'Enrique J. Vercher García en Ideal',autor:'Enrique J. Vercher García',fecha:'2018-05-05',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-enrique-j-vercher-garcia-en-ideal/'},
  {slug:'alejandro-santiago-en-granada-entre-libros',titulo:'Alejandro Santiago en Granada entre libros',autor:'Alejandro Santiago',fecha:'2018-05-03',imagen_url:'',url_externa:'https://www.editorialnazari.com/alejandro-santiago-en-granada-entre-libros/'},
  {slug:'enrique-vercher-y-ultima-en-granada-hoy',titulo:'Enrique Vercher y «Última» en Granada Hoy',autor:'Enrique J. Vercher',fecha:'2018-04-24',imagen_url:'',url_externa:'https://www.editorialnazari.com/enrique-vercher-y-ultima-en-granada-hoy/'},
  {slug:'entrevista-a-francisco-rojas-santos-en-ideal',titulo:'Francisco Rojas Santos en Ideal',autor:'Francisco Rojas Santos',fecha:'2018-04-13',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-francisco-rojas-santos-en-ideal/'},
  {slug:'entrevista-a-ismael-contreras-en-ideal-la-noche-de-walpurgis',titulo:'Ismael Contreras Carmona en Ideal',autor:'Ismael Contreras Carmona',fecha:'2018-03-23',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-ismael-contreras-en-ideal-la-noche-de-walpurgis/'},
  {slug:'entrevista-a-isabel-rezmo-en-ideal',titulo:'Isabel Rezmo en Ideal',autor:'Isabel Rezmo',fecha:'2018-03-14',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-isabel-rezmo-en-ideal/'},
  {slug:'entrevista-a-juan-antonio-nunez-en-ideal',titulo:'Juan Antonio Núñez en Ideal',autor:'Juan Antonio Núñez',fecha:'2017-12-28',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-juan-antonio-nunez-en-ideal/'},
  {slug:'entrevista-a-jordi-navarro-fisas-en-cerdanyola-al-dia',titulo:'Jordi Navarro Fisas en Cerdanyola al día',autor:'Jordi Navarro Fisas',fecha:'2017-12-22',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-jordi-navarro-fisas-en-cerdanyola-al-dia/'},
  {slug:'entrevista-a-jon-sigurdhur-eyjolfsson-en-canal-sur-radio',titulo:'Jón Sigurður Eynjólfsson en Canal Sur Radio',autor:'Jón Sigurður Eynjólfsson',fecha:'2017-12-11',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-jon-sigurdhur-eyjolfsson-en-canal-sur-radio/'},
  {slug:'entrevista-a-diego-castillo-barco-en-viva-la-vega',titulo:'Diego Castillo Barco en Viva La Vega',autor:'Diego Castillo Barco',fecha:'2017-11-23',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-diego-castillo-barco-en-viva-la-vega/'},
  {slug:'entrevista-a-pedro-blanco-naveros-en-canal-sur-television',titulo:'Pedro Blanco Naveros en Canal Sur Televisión',autor:'Pedro Blanco Naveros',fecha:'2017-11-22',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-pedro-blanco-naveros-en-canal-sur-television/'},
  {slug:'entrevista-a-pedro-blanco-naveros-en-interalmeria-tv',titulo:'Pedro Blanco Naveros en InterAlmería TV',autor:'Pedro Blanco Naveros',fecha:'2017-10-28',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-pedro-blanco-naveros-en-interalmeria-tv/'},
  {slug:'entrevista-a-sandra-clavel',titulo:'Entrevista a Sandra Clavel',autor:'Sandra Clavel',fecha:'2017-08-11',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-sandra-clavel/'},
  {slug:'entrevista-a-fermin-lopez-costero',titulo:'Entrevista a Fermín López Costero',autor:'Fermín López Costero',fecha:'2017-07-28',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-fermin-lopez-costero/'},
  {slug:'entrevista-a-fermin-lopez-costero-en-ondabierzo',titulo:'Fermín López Costero en OndaBierzo',autor:'Fermín López Costero',fecha:'2017-07-11',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-fermin-lopez-costero-en-ondabierzo/'},
  {slug:'ismael-contreras-carmona-en-granada-es-cultura',titulo:'Ismael Contreras Carmona en Granada es cultura',autor:'Ismael Contreras Carmona',fecha:'2017-06-23',imagen_url:'',url_externa:'https://www.editorialnazari.com/ismael-contreras-carmona-en-granada-es-cultura/'},
  {slug:'entrevista-a-xanath-caraza-en-ideal',titulo:'Xánath Caraza en Ideal',autor:'Xánath Caraza',fecha:'2017-06-08',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-xanath-caraza-en-ideal/'},
  {slug:'entrevista-a-juan-peregrina-en-radio-tropical-almunecar',titulo:'Juan Peregrina en Radio Tropical Almuñécar',autor:'Juan Peregrina',fecha:'2017-06-07',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-juan-peregrina-en-radio-tropical-almunecar/'},
  {slug:'entrevista-a-xanath-caraza-en-ideal-en-clase',titulo:'Xánath Caraza en Ideal en clase',autor:'Xánath Caraza',fecha:'2017-06-06',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-xanath-caraza-en-ideal-en-clase/'},
  {slug:'ana-carril-en-la-mananica-de-los-caparros',titulo:'Ana Carril en La Mañanica de Los Caparros',autor:'Ana Carril',fecha:'2017-05-30',imagen_url:'',url_externa:'https://www.editorialnazari.com/ana-carril-en-la-mananica-de-los-caparros/'},
  {slug:'entrevista-a-antonio-cobos-ruz-en-ideal',titulo:'Antonio Cobos Ruz en Ideal',autor:'Antonio Cobos Ruz',fecha:'2017-05-04',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-antonio-cobos-ruz-en-ideal/'},
  {slug:'entrevista-a-francisco-castilla-torres-en-ideal',titulo:'Francisco Castilla Torres en Ideal',autor:'Francisco Castilla Torres',fecha:'2017-03-30',imagen_url:'',url_externa:'https://www.editorialnazari.com/entrevista-a-francisco-castilla-torres-en-ideal/'},
];

// ── Importación principal ─────────────────────────────────────────────────────
async function main() {
  console.log(`\n📚 Importar blog — Editorial Nazarí`);
  console.log(`   Empresa : ${EID}`);
  console.log(`   Entradas: ${ENTREVISTAS.length}`);
  console.log(`   Modo    : ${FORZAR ? 'FORZAR (sobreescribe existentes)' : 'SOLO NUEVAS (salta existentes)'}\n`);

  const resumenes = await fetchResumenes();
  const col = db.collection('empresas').doc(EID).collection('blog');

  let creadas = 0, saltadas = 0, errores = 0;

  for (let i = 0; i < ENTREVISTAS.length; i++) {
    const e = ENTREVISTAS[i];
    const ref = col.doc(e.slug);
    try {
      const snap = await ref.get();
      if (snap.exists && !FORZAR) {
        console.log(`  ⏭  [${i+1}/${ENTREVISTAS.length}] ya existe: ${e.slug}`);
        saltadas++;
        continue;
      }
      const resumen = resumenes[e.slug] || '';
      const data = {
        titulo:            e.titulo,
        slug:              e.slug,
        resumen:           resumen,
        autor:             e.autor || 'Editorial Nazarí',
        fecha_publicacion: e.fecha,
        imagen_url:        e.imagen_url || '',
        url_externa:       e.url_externa || '',
        categoria_id:      'Entrevistas',
        tipo:              'entrevista',
        estado:            'publicado',
        publicada:         true,
        eliminado:         false,
        contenido:         '',
        etiquetas:         [],
        visitas:           0,
      };
      await ref.set(data, { merge: !FORZAR });
      console.log(`  ✅ [${i+1}/${ENTREVISTAS.length}] ${snap.exists ? 'actualizada' : 'creada'}: ${e.slug}`);
      creadas++;
    } catch (err) {
      console.error(`  ❌ [${i+1}] ${e.slug}: ${err.message}`);
      errores++;
    }
  }

  console.log(`\n${'─'.repeat(50)}`);
  console.log(`  ✅ Creadas/actualizadas : ${creadas}`);
  console.log(`  ⏭  Saltadas             : ${saltadas}`);
  console.log(`  ❌ Errores              : ${errores}`);
  console.log(`${'─'.repeat(50)}\n`);
  process.exit(errores > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
