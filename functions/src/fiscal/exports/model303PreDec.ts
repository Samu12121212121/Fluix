/**
 * Generador de fichero pre-declaración Modelo 303 — formato posicional AEAT
 *
 * ⚠ IMPORTANTE: El diseño de registros oficial se descarga de:
 * https://sede.agenciatributaria.gob.es/Sede/modelo303
 * Cambia cada año. Este generador implementa las casillas principales
 * del diseño 2026. Actualizar si la AEAT publica nueva versión.
 *
 * Formato: texto longitud fija, importes en céntimos sin decimales,
 * signo P/N delante del importe.
 */

interface Empresa303 {
  tax_id: string;
  legal_name: string;
}

/**
 * Genera una línea de pre-declaración para el Modelo 303.
 * @param modelData  - resultado de calculate303()
 * @param empresa    - datos fiscales de la empresa
 * @returns string con la línea en formato posicional AEAT
 */
export function generarPreDec303(modelData: any, empresa: Empresa303): string {
  const ejercicio = modelData.period.includes('-Q')
    ? modelData.period.split('-Q')[0]
    : modelData.period;
  const trimNum = modelData.period.includes('-Q')
    ? modelData.period.split('-Q')[1]
    : '0';
  const periodo = `${trimNum}T`;

  let linea = '';

  // Tipo de registro (1 char)
  linea += 'T';
  // Modelo declaración (3 chars)
  linea += '303';
  // Ejercicio (4 chars)
  linea += ejercicio.padEnd(4, ' ').substring(0, 4);
  // Período (2 chars): 1T, 2T, 3T, 4T
  linea += periodo.padEnd(2, ' ').substring(0, 2);
  // NIF (9 chars)
  linea += padRight(empresa.tax_id.replace(/[-\s]/g, ''), 9);
  // Apellidos y nombre/razón social (40 chars, mayúsculas)
  linea += padRight(empresa.legal_name.toUpperCase(), 40);

  // Casillas principales (15 chars cada una en formato importe AEAT)
  const casillas = modelData.casillas || {};
  const camposCasillas = [
    '01', '02', '04', '05', '07', '08',
    '10', '11', '12', '13',
    '27',
    '28', '29', '30', '31', '32', '33', '34', '35',
    '45', '46',
  ];

  for (const c of camposCasillas) {
    linea += importeAEAT(casillas[c] || 0, 15);
  }

  return linea;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function padRight(str: string, len: number): string {
  return (str || '').substring(0, len).padEnd(len, ' ');
}

/**
 * Formatea un importe al estilo AEAT posicional:
 * - 1 char signo: P (positivo) o N (negativo)
 * - (len-1) chars: valor absoluto en céntimos, con ceros a la izquierda
 */
function importeAEAT(importe: number, len: number): string {
  const cents = Math.round(importe * 100);
  const sign = cents < 0 ? 'N' : 'P';
  const absStr = Math.abs(cents).toString();
  return sign + absStr.padStart(len - 1, '0');
}

