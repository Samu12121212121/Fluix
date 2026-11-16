# Firma Electrónica — Fluix / Sysday Emergencias

## Marco legal aplicable

| Norma | Qué regula |
|-------|-----------|
| **Reglamento (UE) 910/2014 (eIDAS)** | Define los tres niveles de firma electrónica válidos en toda la UE |
| **Ley 6/2020** | Adapta eIDAS al ordenamiento español; da validez probatoria a firmas avanzadas |
| **Estatuto de los Trabajadores art. 8** | Los contratos laborales pueden formalizarse por cualquier medio, incluyendo firma electrónica |

---

## Los tres niveles de firma (eIDAS art. 3)

### 1. Firma simple
Cualquier marca digital. No requiere verificación de identidad.
- **Ejemplo**: checkbox "He leído y acepto"
- **Validez**: muy débil. Se puede repudiar fácilmente.
- **Lo que evitamos usar** para contratos.

### 2. Firma avanzada (art. 26) ← lo que implementamos
Debe cumplir cuatro requisitos:
1. **Vinculada al firmante** de manera unívoca
2. **Permite identificar** al firmante
3. **Creada con datos bajo control exclusivo** del firmante
4. **Detecta cualquier cambio** posterior en el documento

Nuestra implementación cumple los cuatro:
- OTP por SMS al teléfono registrado del empleado (vinculación + identificación)
- El empleado dibuja su firma táctil (control exclusivo)
- Hash SHA-256 del documento antes de firmar → cualquier cambio lo invalida

**Válida para contratos laborales, acuerdos de confidencialidad, comunicaciones internas.**

### 3. Firma cualificada
Requiere certificado acreditado (DNIe, FNMT). Máxima validez pero requiere infraestructura adicional. No implementado.

---

## Flujo implementado

```
[Admin sube PDF]
      ↓
[Admin solicita firma → Firestore: estado_firma='pendiente', firma_zona, hash_documento]
      ↓
[Empleado ve doc en portal → pulsa Firmar]
      ↓
[App envía OTP por SMS al teléfono registrado]
  → Si no hay teléfono: código aparece en pantalla (SOLO demo)
      ↓
[Empleado introduce OTP → verificado en Firestore: otps_firma/{docId}.verificado=true]
      ↓
[Empleado dibuja firma táctil → PNG generado en cliente]
      ↓
[firmarDocumento() en documento_firma_service.dart]
  1. Verifica que OTP está marcado como verificado
  2. Sube firma PNG a Storage: empleados/{eid}/{uid}/firmas_docs/{docId}.png
  3. Marca Firestore: estado_firma='firmado', firma_url, audit_firma
  4. Llama _incrustarFirmaEnPdf() — AWAIT (bloquea hasta completar)
      ↓
[_incrustarFirmaEnPdf()]
  1. Descarga PDF original de Storage
  2. Rasteriza páginas a 150 DPI con Printing.raster()
  3. Reconstruye PDF con firma en la zona configurada (firma_zona)
  4. Sube PDF firmado a Storage: empleados/{eid}/{uid}/firmas_docs/{docId}_firmado.pdf
  5. Actualiza url del documento en Firestore → el empleado ve la versión firmada
      ↓
[Cloud Function: onDocumentoFirmado — NUEVO]
  1. Detecta estado_firma='firmado' en Firestore
  2. Descarga PDF firmado de Storage
  3. Calcula SHA-256 del PDF firmado (hash diferente al original)
  4. Envía TimeStampRequest (RFC 3161) a FreeTSA.org
  5. Recibe TimeStampToken firmado por la TSA
  6. Guarda token en Storage: empleados/{eid}/{uid}/firmas_docs/{docId}_tsa.tsr
  7. Actualiza Firestore: tsa_token_url, tsa_hash_sha256, tsa_timestamp, tsa_issuer
```

---

## Qué prueba cada elemento

| Elemento | Dónde se guarda | Qué demuestra |
|----------|----------------|---------------|
| `hash_documento` (SHA-256 del original) | Firestore: `usuarios/{uid}/documentos/{docId}` | El PDF no fue alterado antes de firmar |
| `audit_firma.otp_metodo` | Firestore (mismo doc) | Cómo se verificó la identidad |
| `audit_firma.otp_verificado_en` | Firestore | Cuándo se verificó el OTP |
| `firma_url` (PNG de la firma táctil) | Firebase Storage | Representación visual de la firma |
| PDF firmado (`_firmado.pdf`) | Firebase Storage | Documento con firma incrustada visualmente |
| `tsa_token_url` (token RFC 3161) | Firebase Storage + Firestore | **Prueba criptográfica** de que el doc existía en esa fecha/hora exacta |
| `tsa_hash_sha256` | Firestore | Hash del PDF firmado que el token TSA certifica |

---

## Estado actual de cada capa

| Capa | Estado | Notas |
|------|--------|-------|
| OTP por SMS (Firebase Phone Auth) | ✅ Implementado | €0.006/SMS. Fallback a código en pantalla si no hay teléfono |
| Hash SHA-256 del documento original | ✅ Implementado | Se calcula en `_subirDocumento()` y se guarda en Firestore |
| Audit log inmutable | ✅ Implementado | Reglas Firestore: `allow update/delete: if false` en `otps_firma` |
| Firma táctil incrustada en PDF | ✅ Implementado | `_incrustarFirmaEnPdf()` con `await` desde oct 2026 |
| Sello de tiempo TSA (RFC 3161) | ✅ Implementado | Cloud Function `onDocumentoFirmado` → FreeTSA.org |
| Firma PAdES (nativa PDF) | ❌ No implementado | Requeriría certificado X.509 y librería ASN.1 en Dart |
| Sello de tiempo FNMT (cualificado) | ❌ No implementado | Requiere cuenta en FNMT y certificado de empresa |

---

## Por qué FreeTSA.org y no FNMT

| | FreeTSA.org | FNMT |
|--|-------------|------|
| Coste | Gratuito | De pago (sello cualificado) |
| Certificado | Autofirmado (no cualificado) | Acreditado por ENISA |
| Validez | Firma avanzada ✓ | Firma cualificada ✓ |
| Trámite | Ninguno | Cuenta de empresa + proceso de acreditación |

**Para contratos laborales de PYME** FreeTSA.org es suficiente. Si se necesitara un sellado cualificado (p.ej. documentos notariales), habría que migrar a FNMT `tss.fnmt.es`.

---

## Verificar un documento firmado

Para comprobar un token TSA `.tsr` descargado:
```bash
openssl ts -verify -in documento_tsa.tsr -data documento_firmado.pdf -CAfile freetsa_ca.crt
```

El hash en el token debe coincidir con el SHA-256 del PDF firmado (`tsa_hash_sha256` en Firestore).

---

## Limitación conocida

La incrustación visual de la firma usa rasterización (PDF → imágenes PNG → PDF nuevo). Esto significa que el PDF firmado **no conserva la capa de texto seleccionable** del original. El texto queda como imagen, aunque el contenido es idéntico. El token TSA certifica ese PDF rasterizado.

Si se requiere preservar el texto (accesibilidad, búsqueda), la alternativa es usar `pdf-lib` para superponer solo la imagen de firma sobre el PDF original sin rasterizar — pendiente de implementar como mejora futura.
