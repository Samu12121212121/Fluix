# Fase 2 — VERIFACTU: Especificaciones de Implementación

> Vigencia normativa actualizada: plazos conforme a RD 1007/2023 consolidado con RD 254/2025 y RDL 15/2025.

## VISIÓN GENERAL

El módulo Verifactu automatiza el envío de registros de facturación a la AEAT, garantizando:

- ✅ Firma electrónica XAdES Enveloped (certificado cualificado)
- ✅ Encadenamiento criptográfico (hash chain)
- ✅ Validación de representación (Anexos I, II, III)
- ✅ Envío automático con reintentos
- ✅ Cumplimiento de plazos (antes del 1.1.2027 para empresas IS, 1.7.2027 para resto)

Historial de modificaciones de plazos:
- RD 1007/2023 original: IS jul-2025 / resto ene-2026
- RD 254/2025 (abr-2025): IS ene-2026 / resto jul-2026
- RDL 15/2025 (dic-2025): IS ene-2027 / resto jul-2027 ← VIGENTE

---

## REGLAS PENDIENTES DE IMPLEMENTAR

### R2 — HASH CHAIN (Encadenamiento Criptográfico)

**Norma:** Art. 29.2.j LGT | RD 1007/2023

**Requisito:** Cada registro N+1 debe contener un hash SHA-256 del registro N anterior.

```dart
// Pseudo-código:

class RegistroFacturacion {
  String huella; // SHA-256 del registro actual
  String huellaAnterior; // SHA-256 del registro anterior
  String numeroSecuencia; // Número correlativo del registro
}

// Validación:
bool validarCadenaHash(List<RegistroFacturacion> registros) {
  for (int i = 1; i < registros.length; i++) {
    if (registros[i].huellaAnterior != registros[i-1].huella) {
      return false; // Cadena rota
    }
  }
  return true;
}
```

**Plan de Implementación:**
1. Almacenar hash SHA-256 de cada registro facturación
2. Validar continuidad de cadena al cargar registros
3. Generar alerta si hay saltos en la cadena
4. Imposibilitar modificación retroactiva (hash no coincidiría)

---

### R3 — INALTERABILIDAD (Firma Digital)

**Norma:** Art. 201 bis LGT | RD 1007/2023

**Requisito:** La firma XAdES Enveloped garantiza que un registro no puede alterarse sin invalidar la firma.

```dart
// Pseudo-código:

class RegistroConFirma {
  String xmlDatos; // Datos de la factura en XML
  String firmaXAdES; // Firma XAdES Enveloped base64
  DateTime fechaFirma;
  String certificadoDigital; // Cert. cualificado EU Trusted List
}

// Validación:
bool validarIntegridad(RegistroConFirma registro) {
  // 1. Extraer firma
  // 2. Calcular hash de datos originales
  // 3. Verificar firma con certificado público
  // 4. Si coinciden: ✅ Íntegro
  // 5. Si no coinciden: ❌ Alterado
  return verificarFirmaXAdES(registro.xmlDatos, registro.firmaXAdES);
}
```

**Plan de Implementación:**
1. Integrar SDK de firma digital (p.ej., `signpdf`, `xmlsec`)
2. Firmar cada registro con certificado cualificado
3. Almacenar firma + certificado en BD
4. Validar integridad al recuperar registros
5. Rechazar registros con firma inválida

---

### R5 — REPRESENTACIÓN (Anexos I, II, III)

**Norma:** Art. 46 LGT | Resolución AEAT 18-dic-2024

**Requisito:** Documento normalizado que autoriza a la app a enviar en nombre del cliente.

```dart
enum TipoRepresentacion {
  anexoI,  // Cliente → App (directo)
  anexoII, // Cliente → Gestor (profesional tributario)
  anexoIII, // Gestor → App (sub-autorización)
}

class DocumentoRepresentacion {
  String id;
  TipoRepresentacion tipo;
  String nifCliente;
  String nifGestor; // Solo si ANEXO II o III
  String nifApp; // Si ANEXO III
  DateTime fechaFirma;
  DateTime? fechaVencimiento; // null = indefinido
  bool esActivo; // true si está vigente
  String? razonRevocacion; // Si fue revocado
}

// Validación:
bool validarRepresentacion({
  required DocumentoRepresentacion doc,
  required String nifCliente,
}) {
  // 1. ¿Está vigente?
  if (!doc.esActivo) return false;
  
  // 2. ¿Ha vencido?
  if (doc.fechaVencimiento != null && 
      DateTime.now().isAfter(doc.fechaVencimiento!)) {
    return false;
  }
  
  // 3. ¿Pertenece a este cliente?
  if (doc.nifCliente != nifCliente) return false;
  
  // 4. ¿Es el tipo correcto para envío a AEAT?
  if (doc.tipo == TipoRepresentacion.anexoI) {
    return true; // Directo
  } else if (doc.tipo == TipoRepresentacion.anexoIII) {
    return true; // Gestor → App (tiene autorización)
  }
  
  return false;
}
```

**Plan de Implementación:**
1. Pantalla de carga de Anexo I / II / III (PDF firmado)
2. OCR / parsing para extraer datos (nombre, NIF, fecha)
3. Almacenar documento en Firestore + Cloud Storage
4. Validar antes de cada envío a AEAT
5. Advertencia si falta representación

---

### R10 — FIRMA CUALIFICADA (Certificado Digital)

**Norma:** Art. 30.5 RD 1619/2012 | Orden HAC/1177/2024

**Requisito:** Certificado digital cualificado de la EU Trusted List.

```dart
class CertificadoDigital {
  String subjectDN; // CN=Empresa SL, O=Empresa, C=ES
  String thumbprint; // SHA-256 del cert
  DateTime validDesde;
  DateTime validHasta;
  String euTrustedListId; // ID en EU Trusted List
  bool esCualificado; // true si está en lista oficial
}

// Validación:
bool validarCertificado(CertificadoDigital cert) {
  // 1. ¿Está en EU Trusted List?
  if (!cert.esCualificado) return false;
  
  // 2. ¿Ha vencido?
  final ahora = DateTime.now();
  if (ahora.isBefore(cert.validDesde) || ahora.isAfter(cert.validHasta)) {
    return false;
  }
  
  // 3. Descarga lista oficial de AEAT / AC raíz
  // (operación en background cada 24 horas)
  
  return true;
}
```

**Plan de Implementación:**
1. Solicitarle al usuario que proporcione certificado (archivo .pfx o smart card)
2. Validar contra EU Trusted List
3. Almacenar certificado en Keychain / Secure Storage
4. Verificar validez antes de firmar registros
5. Avisar cuando esté próximo a vencer

---

## DIAGRAMA: FLUJO VERIFACTU (Fase 2)

```
┌─────────────────────────────────────────┐
│  Usuario crea factura                   │
│  ↓ Validaciones R1-R9 (Fase 1)          │
│  Factura válida ✅                       │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  GENERAR REGISTRO DE FACTURACIÓN        │
│  (XML con estructura AEAT)              │
│                                         │
│  • Datos factura (NIF, serie, número)  │
│  • Hash SHA-256 (R2)                   │
│  • Referencia a registro anterior      │
│  • Timestamp + timezone                │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  FIRMAR REGISTRO (R10)                  │
│  Con certificado cualificado XAdES     │
│                                         │
│  • Validar cert (EU Trusted List)      │
│  • Crear firma XAdES Enveloped         │
│  • Incluir timestamp (TSA)              │
│  • Almacenar firma en registro         │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  VALIDAR REPRESENTACIÓN (R5)            │
│  Documento Anexo I / II+III             │
│                                         │
│  • ¿Existe documento?                  │
│  • ¿Está vigente?                      │
│  • ¿Es tipo correcto?                  │
│  SI todo ✅ → Continuar                 │
│  NO → Bloquear envío                   │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  ENVIAR A AEAT                          │
│  (HTTP POST con cert. empresa)          │
│                                         │
│  • Incluir Cabecera + RegistroFactura  │
│  • Codificación UTF-8                  │
│  • Max 1.000 registros/envío           │
│  • Parámetro "t" (timeout 60s, max)    │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  PROCESAR RESPUESTA AEAT                │
│                                         │
│  ✅ ACEPTADO                             │
│  → Guardar CSV aceptación              │
│  → Mostrar "Factura verificable"       │
│  → Generar código QR Verifactu         │
│                                         │
│  ❌ RECHAZADO (error semántico)         │
│  → Registrar error                     │
│  → Mostrar detalle a usuario           │
│  → Reintentar en 1 hora                │
│                                         │
│  ⚠️ INCIDENCIA TÉCNICA                  │
│  → Parámetro "t" nuevo en respuesta    │
│  → Reintentar con "t" aumentado        │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  GENERAR CÓDIGO QR                      │
│  "VERI*FACTU" + URL AEAT                │
│                                         │
│  • Incluir en PDF factura              │
│  • Tamaño 30-40 mm (ISO 18004)         │
│  • Corrección error M                  │
│  • URL: AEAT + NIF + serie/nº + fecha  │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  ARCHIVADO PERMANENTE                   │
│  ✅ Factura verificable (VERI*FACTU)    │
│  ✅ Cumplimiento 100% normativa         │
│  ✅ Auditable y certificable            │
└─────────────────────────────────────────┘
```

---

## TIMELINE RECOMENDADO (Roadmap Fase 2)

| Semana | Tarea | Responsable |
|--------|-------|-------------|
| W1 (Apr 2026) | Especificación técnica XAdES + PKI | Arquitecto |
| W2-W3 | Integración SDK firma digital | DevOps + Backend |
| W4 | Tests unitarios firma + hash chain | QA |
| W5 (May 2026) | Implementación representación (Anexos) | Backend |
| W6 | Tests flujo Verifactu end-to-end | QA |
| W7 (Jun 2026) | Integración API AEAT (sandbox) | Backend |
| W8 | Tests en sandbox AEAT | QA |
| W9 (Jul 2026) | Deployt a producción | DevOps |
| W10 | Certificación + auditoría externa | Auditor |

---

## LIBRERÍAS RECOMENDADAS

### Firma Digital XAdES

- **`xmlsec1`** (CLI para validaciones)
- **`dart_xmlsec`** (Dart wrapper, si existe)
- **`signpdf`** (Signing, legacy pero robusto)
- **`apache_xml_security_c`** (C binding para performance)

### Certificados Digitales

- **`win-acme`** (Windows)
- **`certbot`** (Linux)
- **`keytool`** (Java, integrado)

### HTTP con Certificado

```dart
import 'dart:io';
import 'package:http/http.dart' as http;

// Crear HttpClient con certificado
final client = HttpClient();
client.badCertificateCallback =
    (X509Certificate cert, String host, int port) => false; // Strict

// Cargar certificado .pfx
final cert = await File('cert.pfx').readAsBytes();
// TODO: Cargar certificado en cliente

// Enviar a AEAT con cert
final request = await client.postUrl(Uri.parse('https://aeat.es/verifactu'));
request.headers.add('Content-Type', 'application/xml; charset=UTF-8');
request.add(registroXml.codeUnits);
final response = await request.close();
```

---

## PRÓXIMOS PASOS (Inmediatos)

1. ✅ Validador Fiscal Integral (R1, R4, R6-R9) — **COMPLETADO**
2. 🔄 Panel UI de Validación — **EN PROGRESO**
3. 📋 Especificación técnica XAdES+PKI — **Roadmap W1 Apr 2026**
4. 🔐 Firma digital (R2, R3, R10) — **Roadmap W2-W3 Apr 2026**
5. 📝 Gestión Anexos (R5) — **Roadmap W5 May 2026**
6. 📤 Envío AEAT (Sandbox) — **Roadmap W7 Jun 2026**


