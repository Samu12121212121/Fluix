# Módulo: Fiscal y VeriFactu

## Qué hace

Cumplimiento normativo fiscal español completo: cálculo y presentación de modelos AEAT (111, 115, 130, 190, 202, 303, 347, 349, 390), VeriFactu (facturación electrónica obligatoria según RD 1007/2023), OCR de facturas recibidas, y calendario fiscal con alertas de vencimiento.

---

## Archivos principales

### Modelos AEAT (pantallas)
| Archivo | Modelo |
|---------|--------|
| `features/fiscal/pantallas/modelo111_screen.dart` | Retenciones e ingresos a cuenta (trimestral) |
| `features/fiscal/pantallas/modelo115_screen.dart` | Retenciones alquileres (trimestral) |
| `features/fiscal/pantallas/modelo130_screen.dart` | IRPF autónomos estimación directa (trimestral) |
| `features/fiscal/pantallas/modelo180_screen.dart` | Resumen anual Modelo 115 |
| `features/fiscal/pantallas/modelo190_screen.dart` | Resumen anual Modelo 111 |
| `features/fiscal/pantallas/modelo202_screen.dart` | IS pagos fraccionados |
| `features/fiscal/pantallas/modelo303_screen.dart` | IVA trimestral |
| `features/fiscal/pantallas/modelo390_screen.dart` | IVA anual |
| `features/fiscal/pantallas/modelo347_screen.dart` | Operaciones > 3.005,06 € anuales |
| `features/fiscal/pantallas/modelo349_screen.dart` | Operaciones intracomunitarias |

### VeriFactu (servicios)
| Archivo | Rol |
|---------|-----|
| `services/verifactu_service.dart` | Orquestador principal |
| `services/verifactu/verifactu_flow_service.dart` | Flujo completo de emisión |
| `services/verifactu/xml_builder_service.dart` | Construcción del XML según RD 1007/2023 |
| `services/verifactu/xml_payload_verifactu_builder.dart` | Payload específico de cada factura |
| `services/verifactu/hash_chain_service.dart` | Cadena de hash entre facturas |
| `services/verifactu/firma_xades_minima_validator.dart` | Validación firma XAdES |
| `services/verifactu/aeat_remision_service.dart` | Envío a AEAT |
| `services/verifactu/qr_service.dart` | Generación de QR |
| `services/verifactu/generador_qr_verifactu.dart` | QR según especificación AEAT |
| `services/verifactu/certificado_repository.dart` | Gestión del certificado PKCS12 |
| `services/verifactu/representacion_verifactu.dart` | HTML de representación gráfica |
| `services/verifactu/lgt_201bis_riesgos.dart` | Validación de riesgos legales |
| `services/verifactu/politica_verifactu_2027.dart` | Política de obligatoriedad 2027 |
| `features/fiscal/pantallas/subir_certificado_verifactu_screen.dart` | Subir certificado digital |

### OCR y facturas recibidas
| Archivo | Rol |
|---------|-----|
| `features/fiscal/pantallas/upload_invoice_screen.dart` | Subir PDF de factura recibida |
| `features/fiscal/pantallas/invoice_result_screen.dart` | Resultado del OCR |
| `functions/src/fiscal/processInvoice.ts` | Cloud Function: OCR + Claude |
| `functions/src/fiscal/ocrPreprocessor.ts` | Preprocesado de imagen |
| `functions/src/fiscal/prompts/invoiceExtractionV4.ts` | Prompt de extracción para Claude |

### Exportadores y calculadores
| Archivo | Rol |
|---------|-----|
| `services/fiscal/mod115_calculator.dart` | Cálculos Modelo 115 |
| `services/fiscal/mod390_calculator.dart` | Cálculos Modelo 390 |
| `services/fiscal/mod115_exporter.dart` | Export BOE Modelo 115 |
| `services/fiscal/mod130_exporter.dart` | Export BOE Modelo 130 |
| `services/fiscal/mod390_exporter.dart` | Export BOE Modelo 390 |
| `services/exportadores_aeat/libro_registro_iva_exporter.dart` | Libro registro IVA |
| `services/exportadores_aeat/mod_349_exporter.dart` | Export BOE Modelo 349 |
| `services/mod_349_service.dart` | Lógica Modelo 349 |
| `services/modelo111_service.dart` | Lógica Modelo 111 |
| `services/modelo111_pdf_service.dart` | PDF Modelo 111 |

---

## Cómo funciona internamente

### Flujo de un modelo AEAT (ej. Modelo 303)
1. El usuario abre `modelo303_screen.dart`
2. La pantalla consulta las facturas del trimestre en `empresas/{empresaId}/facturas` y `facturas_recibidas`
3. El servicio `calculateFiscalModel` (Cloud Function) agrega los datos:
   - IVA repercutido (facturas emitidas)
   - IVA soportado (facturas recibidas)
   - Resultado = IVA a pagar o a devolver
4. El usuario puede ver el desglose, ajustarlo manualmente y generar el PDF
5. Se puede exportar en formato BOE (fichero `.303` para presentar telemáticamente)
6. El resultado queda guardado en `empresas/{empresaId}/modelo_303`

### Flujo VeriFactu completo
```
Factura emitida
    │
    ▼
hash_chain_service.dart
    │  Calcula hash = SHA-256(factura + hash_anterior)
    ▼
xml_builder_service.dart
    │  Construye XML según RD 1007/2023 Anexo I
    ▼
firmarXMLVerifactu (Cloud Function)
    │  Firma XAdES con certificado PKCS12 de la empresa
    ▼
remitirVerifactu (Cloud Function)
    │  Envía al endpoint AEAT (producción o pruebas)
    ▼
Respuesta AEAT → guarda en factura.verifactuRegistrado=true
```

### OCR de facturas recibidas
```
Usuario sube PDF
    │
    ▼
Firebase Storage → triggers processInvoice (Cloud Function)
    │
    ├─ ocrPreprocessor.ts → mejora imagen para OCR
    ├─ Google Document AI → extrae texto y estructura
    └─ Claude API (invoiceExtractionV4.ts prompt) → interpreta y devuelve JSON
    │
    ▼
invoice_result_screen.dart → muestra resultado para confirmar
    │
    ▼
Se guarda en empresas/{empresaId}/facturas_recibidas
```

---

## Modelos AEAT implementados

| Modelo | Periodicidad | Qué declara |
|--------|-------------|-------------|
| 111 | Trimestral | Retenciones de trabajadores y profesionales |
| 115 | Trimestral | Retenciones sobre alquileres |
| 130 | Trimestral | Pagos fraccionados IRPF autónomos |
| 180 | Anual | Resumen de retenciones sobre alquileres |
| 190 | Anual | Resumen retenciones trabajadores/profesionales |
| 202 | Trimestral | Pagos fraccionados Impuesto de Sociedades |
| 303 | Trimestral | Declaración-liquidación del IVA |
| 347 | Anual | Operaciones con terceros > 3.005,06€ |
| 349 | Trimestral/Anual | Operaciones intracomunitarias |
| 390 | Anual | Resumen anual del IVA |

---

## Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/facturas` | Fuente de IVA repercutido |
| `empresas/{empresaId}/facturas_recibidas` | Fuente de IVA soportado |
| `empresas/{empresaId}/modelo_111` | Registros declarados |
| `empresas/{empresaId}/modelo_115` | Registros declarados |
| `empresas/{empresaId}/modelo_303` | Registros declarados |
| `empresas/{empresaId}/modelo_390` | Registros declarados |
| `empresas/{empresaId}/configuracion/fiscal` | Régimen fiscal, periodicidad, NIF, obligaciones |

---

## Cloud Functions relacionadas

| Función | Cuándo se ejecuta |
|---------|------------------|
| `firmarXMLVerifactu` | Al emitir factura con VeriFactu — firma el XML |
| `remitirVerifactu` | Al emitir factura — envía a AEAT |
| `processInvoice` | Al subir PDF — OCR + Claude |
| `calculateFiscalModel` | Callable — calcula cualquier modelo fiscal |
| `alertasVencimientosFiscales` | Scheduled — alerta de presentaciones próximas |
| `backupDatosFiscalesNocturno` | Scheduled noche — backup de datos fiscales |

---

## Conexión con otros módulos

- **Facturación** — fuente de todos los datos fiscales (facturas emitidas y recibidas)
- **Empleados** — datos necesarios para Modelo 111 (retenciones IRPF nóminas)
- **Nóminas** — retenciones de trabajadores alimentan Modelo 111
- **Clientes** — datos fiscales del cliente en facturas
