# 📋 VALORACIÓN — Módulo de Finiquitos y Liquidaciones

## Archivos creados

| Archivo | Descripción |
|---|---|
| `lib/domain/modelos/finiquito.dart` | Modelo de datos: `Finiquito`, `CausaBaja`, `EstadoFiniquito`, `ProrataPagaExtra` |
| `lib/services/finiquito_calculator.dart` | Motor de cálculo: salario pendiente, vacaciones, pagas, indemnización, IRPF, SS |
| `lib/services/finiquito_service.dart` | CRUD Firestore + contabilización automática de pagos |
| `lib/services/finiquito_pdf_service.dart` | Generador PDF con formato laboral español |
| `lib/features/finiquitos/pantallas/finiquitos_screen.dart` | Listado de finiquitos |
| `lib/features/finiquitos/pantallas/nuevo_finiquito_form.dart` | Formulario de cálculo con desglose en tiempo real |
| `lib/features/finiquitos/pantallas/finiquito_detalle.dart` | Vista detalle con acciones (firmar, pagar, PDF) |
| `test/finiquito_calculator_test.dart` | 30+ tests cubriendo todos los casos legales |

## Archivo modificado

| Archivo | Cambio |
|---|---|
| `lib/features/empleados/pantallas/modulo_empleados_screen.dart` | Botones "Generar finiquito" y "Ver finiquitos" en menú empleado |

## Base legal implementada

| Concepto | Artículo | Implementado |
|---|---|---|
| Salario pendiente | ET art. 49 | ✅ |
| Vacaciones no disfrutadas | ET art. 38 | ✅ (30d defecto, convenios: 31d cárnicas) |
| Prorrata pagas extra | ET art. 31 | ✅ (12/14/15 pagas, por convenio) |
| Despido improcedente 33d/año | ET art. 56 | ✅ (max 24 mensualidades) |
| Despido procedente 20d/año | ET art. 52-53 | ✅ (max 12 mensualidades) |
| Fin contrato temporal 12d/año | ET art. 49.1.c | ✅ |
| ERE/fuerza mayor 20d/año | ET art. 51 | ✅ (max 12 mensualidades) |
| Cálculo dual pre/post 12/02/2012 | Disposición transitoria 5ª Ley 3/2012 | ✅ (45d + 33d) |
| Exención IRPF indemnización | LIRPF art. 7.e | ✅ (solo improcedente) |
| SS no cotiza sobre indemnización | LGSS art. 109 | ✅ |
| Retención mínima 2% | RIRPF art. 86 | ✅ (vía NominasService) |

## Tests implementados

- Caso 1: Dimisión voluntaria, hostelería 15 pagas, 2 años
- Caso 2: Despido improcedente, comercio 14 pagas, 5 años (exención IRPF)
- Caso 3: Fin contrato temporal, cárnicas 31d vacaciones, 1 año
- Caso 4: Cálculo dual pre/post Reforma Laboral 2012 (18+ años)
- Caso 5: Mutuo acuerdo (sin indemnización, 12 pagas prorrateadas)
- Caso 6: ERE (20d/año, tope 12 mensualidades)
- Edge cases: salario 0, jubilación, contrato empezado este año, veterinarios
- Integridad: totalBruto, líquido, retenciones, valores no negativos

