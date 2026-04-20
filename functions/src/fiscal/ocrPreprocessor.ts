// ═══════════════════════════════════════════════════════════════
// PREPROCESADOR OCR — Fluix CRM v4
//
// Añade contexto explícito al texto OCR antes de enviarlo a Claude
// para mejorar la detección de non_subject_amount cuando el OCR
// ha aplanado columnas o perdido estructura de tabla.
// ═══════════════════════════════════════════════════════════════

// Patrones que identifican facturas notariales/registrales
const PATRONES_NOTARIALES = [
  /notario/i,
  /notaría/i,
  /notaria/i,
  /registrador/i,
  /registro de la propiedad/i,
  /registro mercantil/i,
  /procurador/i,
  /arancel/i,
  /timbre/i,
  /timbres/i,
  /suplido/i,
  /suplidos/i,
  /tasas registrales/i,
  /derechos de registro/i,
  /gastos de notaría/i,
  /honorarios notariales/i,
];

// Patrones que sugieren presencia de partes no sujetas
const PATRONES_NO_SUJETO = [
  /no sujeto/i,
  /no sujeta/i,
  /sujeto a iva/i,
  /no sujeto a iva/i,
  /exento de iva/i,
  /sin iva/i,
  /tasas judiciales/i,
  /derechos arancelarios/i,
  /gastos de correo/i,
  /desplazamiento/i,
  /dietas/i,
];

export interface PreprocesadoResult {
  textoEnriquecido: string;
  esNotarial: boolean;
  tieneIndiciosNoSujeto: boolean;
  avisos: string[];
}

export function preprocesarTextoOCR(rawText: string): PreprocesadoResult {
  const avisos: string[] = [];

  // 1. Detectar si es factura notarial/registral
  const esNotarial = PATRONES_NOTARIALES.some((p) => p.test(rawText));

  // 2. Detectar si hay indicios explícitos de parte no sujeta
  const tieneIndiciosNoSujeto = PATRONES_NO_SUJETO.some((p) => p.test(rawText));

  // 3. Detectar si parece que el OCR ha aplanado columnas
  // Señal: hay múltiples importes en la misma línea sin separador claro
  const lineasConMultiplesImportes = rawText
    .split('\n')
    .filter(linea => {
      const importes = linea.match(/\d+[.,]\d{2}/g);
      return importes && importes.length >= 2;
    });

  const ocrAplanado = lineasConMultiplesImportes.length > 0;

  // 4. Construir el texto enriquecido con avisos para Claude
  const bloqueAviso: string[] = [];

  if (esNotarial) {
    avisos.push('proveedor_notarial_detectado');
    bloqueAviso.push(
      '⚠️ AVISO PREPROCESADOR: Este documento es de un NOTARIO, REGISTRADOR o PROCURADOR.',
      'Es muy probable que contenga importes NO SUJETOS a IVA (timbres, suplidos, tasas, aranceles).',
      'BUSCA ACTIVAMENTE non_subject_amount aunque no veas columnas explícitas.',
      'Si el total no cuadra con base+IVA-retención, calcula non_subject_amount por diferencia.'
    );
  }

  if (tieneIndiciosNoSujeto) {
    avisos.push('indicios_no_sujeto_detectados');
    bloqueAviso.push(
      '⚠️ AVISO PREPROCESADOR: Se han detectado términos que indican partes NO SUJETAS a IVA.',
      'Extrae el importe no sujeto en el campo non_subject_amount.'
    );
  }

  if (ocrAplanado && esNotarial) {
    avisos.push('ocr_columnas_aplanadas');
    bloqueAviso.push(
      '⚠️ AVISO PREPROCESADOR: El OCR puede haber aplanado columnas.',
      `Se detectaron ${lineasConMultiplesImportes.length} línea(s) con múltiples importes:`,
      ...lineasConMultiplesImportes.map(l => `  → "${l.trim()}"`),
      'Usa la fórmula de cálculo por diferencia si es necesario:'
    );
  }

  // 5. Construir el texto final
  let textoEnriquecido = rawText;

  if (bloqueAviso.length > 0) {
    textoEnriquecido = [
      '╔══════════════════════════════════════════════════════════╗',
      '║         CONTEXTO ADICIONAL DEL PREPROCESADOR             ║',
      '╚══════════════════════════════════════════════════════════╝',
      ...bloqueAviso,
      '══════════════════════════════════════════════════════════',
      '',
      rawText,
    ].join('\n');
  }

  return {
    textoEnriquecido,
    esNotarial,
    tieneIndiciosNoSujeto,
    avisos,
  };
}

