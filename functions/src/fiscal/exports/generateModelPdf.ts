/**
 * Generador de PDF oficial relleno con pdf-lib
 *
 * REQUISITO: tener el PDF oficial de la AEAT almacenado en Firebase Storage
 * en la ruta: templates/fiscal/modelo{code}_{year}.pdf
 *
 * Los PDFs oficiales son formularios editables publicados por la AEAT.
 * Se descargan de: https://sede.agenciatributaria.gob.es/Sede/modelos-formularios
 *
 * ⚠ Los nombres de campo del formulario se obtienen con pdf-lib o Adobe Acrobat
 * inspeccionando el PDF. Cada modelo tiene sus propios nombres de campo.
 */

import { PDFDocument } from 'pdf-lib';
import * as admin from 'firebase-admin';

interface EmpresaFiscal {
  tax_id: string;
  legal_name: string;
  provincia?: string;
  municipio?: string;
}

/**
 * Genera el PDF relleno del modelo AEAT indicado.
 * @param modelCode  - '303', '111', etc.
 * @param modelData  - resultado del calculate{Model}()
 * @param empresa    - datos fiscales empresa
 * @param year       - año fiscal (para cargar el template correcto)
 * @returns Buffer con el PDF relleno
 */
export async function generarModeloPdf(
  modelCode: string,
  modelData: any,
  empresa: EmpresaFiscal,
  year: number = new Date().getFullYear(),
): Promise<Uint8Array> {
  // 1. Cargar template PDF desde Storage
  const bucket = admin.storage().bucket();
  const templatePath = `templates/fiscal/modelo${modelCode}_${year}.pdf`;

  let pdfBytes: Buffer;
  try {
    const [file] = await bucket.file(templatePath).download();
    pdfBytes = file;
  } catch {
    throw new Error(
      `Template PDF no encontrado en Storage: ${templatePath}. ` +
      `Sube el PDF oficial de la AEAT para el año ${year}.`,
    );
  }

  // 2. Cargar y rellenar
  const pdfDoc = await PDFDocument.load(pdfBytes);
  const form = pdfDoc.getForm();

  // 3. Rellenar campos comunes
  safeSetField(form, 'NIF', empresa.tax_id.replace(/[-\s]/g, ''));
  safeSetField(form, 'Apellidos_Nombre', empresa.legal_name.toUpperCase());
  safeSetField(form, 'Ejercicio', modelData.period?.split('-')[0] || String(year));

  // Período (si es trimestral)
  if (modelData.period?.includes('-Q')) {
    const q = modelData.period.split('-Q')[1];
    safeSetField(form, 'Periodo', `${q}T`);
  }

  // 4. Rellenar casillas del modelo
  const casillas: Record<string, number> = modelData.casillas || {};
  for (const [num, valor] of Object.entries(casillas)) {
    // Intentar varios formatos de nombre de campo
    const intentos = [
      `Casilla_${num}`,
      `C${num}`,
      `casilla${num}`,
      num,
    ];
    let rellenado = false;
    for (const nombre of intentos) {
      if (safeSetField(form, nombre, formatoImporteEs(valor as number))) {
        rellenado = true;
        break;
      }
    }
    if (!rellenado) {
      console.warn(`Campo para casilla ${num} no encontrado en el PDF`);
    }
  }

  // 5. Aplanar (no editable) y retornar
  form.flatten();
  return pdfDoc.save();
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function safeSetField(form: any, fieldName: string, value: string): boolean {
  try {
    form.getTextField(fieldName).setText(value);
    return true;
  } catch {
    return false;
  }
}

function formatoImporteEs(valor: number): string {
  // Formato español: 1.234,56
  return valor.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

