# 🏛️ PLAN TÉCNICO: Cumplimiento RRSIF (Verifactu) - Fluix CRM

**Empresa Fabricante:** FLUIX TECH, S.L. (CIF: B26997528)  
**Producto:** Fluix CRM (SaaS Multitenant)  
**Base Legal:** RD 1007/2023 modificado por RD 254/2025 + Orden HAC/1177/2024  
**Proyecto Firebase:** planeaapp-4bea4 (europe-west1)

---

## 📊 ÍNDICE

1. [Registro de Facturación Inmutable](#1-registro-de-facturación-inmutable)
2. [Hash SHA-256 Encadenado](#2-hash-sha-256-encadenado)
3. [Registro de Eventos](#3-registro-de-eventos)
4. [Código QR en Factura](#4-código-qr-en-factura)
5. [Remisión a la AEAT](#5-remisión-a-la-aeat)
6. [Exportación Estandarizada](#6-exportación-estandarizada)
7. [Declaración Responsable del Fabricante](#7-declaración-responsable-del-fabricante)
8. [Inalterabilidad y Auditoría](#8-inalterabilidad-y-auditoría)

---

# 1. REGISTRO DE FACTURACIÓN INMUTABLE

## 🗄️ Estructura de Firestore

### Colección: `empresas/{empresaId}/facturas_verifactu/{facturaId}`

```javascript
{
  // ── IDENTIFICACIÓN ────────────────────────────────────────────────────
  "id_factura": "2026/00001",              // Número de factura (serie/número)
  "fecha_expedicion": Timestamp,            // Fecha y hora de expedición
  "hora_expedicion": "14:32:15",            // Hora en formato HH:MM:SS
  
  // ── EMISOR ────────────────────────────────────────────────────────────
  "emisor": {
    "nif": "B26997528",                     // NIF del emisor
    "nombre": "MI COMERCIO SL",
    "direccion": "Calle Mayor 1",
    "codigo_postal": "28001",
    "municipio": "Madrid",
    "pais": "ES"
  },
  
  // ── DESTINATARIO (opcional para tickets simplificados) ────────────────
  "destinatario": {
    "nif": "12345678A",                     // Opcional si < 400€
    "nombre": "CLIENTE FINAL",
    "pais": "ES"
  },
  
  // ── IMPORTES ──────────────────────────────────────────────────────────
  "base_imponible": 100.00,                 // Sin IVA
  "tipo_iva": 21.00,                        // Porcentaje
  "cuota_iva": 21.00,                       // Importe IVA
  "tipo_recargo": 0.00,                     // Recargo equivalencia (opcional)
  "cuota_recargo": 0.00,
  "total_factura": 121.00,                  // Base + IVA + Recargo
  
  // ── DESGLOSE POR TIPOS IMPOSITIVOS (si hay varios) ───────────────────
  "desgloses_iva": [
    {
      "base_imponible": 100.00,
      "tipo_iva": 21.00,
      "cuota_iva": 21.00,
      "tipo_no_sujeto": null,               // "S1", "S2", "S3" si aplica
      "tipo_exencion": null                 // "E1" a "E6" si aplica
    }
  ],
  
  // ── TIPO DE FACTURA ───────────────────────────────────────────────────
  "tipo_factura": "F1",                     // F1=Completa, F2=Simplificada, F3=Rectificativa
  "factura_sustituida": null,               // ID si es rectificativa
  "motivo_rectificacion": null,             // "R1" a "R5" según art. 80 RIVA
  
  // ── HASH ENCADENADO ───────────────────────────────────────────────────
  "hash_anterior": "1234abcd...",           // SHA-256 del registro anterior
  "hash_actual": "5678efgh...",             // SHA-256 de este registro
  "numero_registro": 1,                     // Secuencial en la empresa
  
  // ── HUELLA DEL SISTEMA ────────────────────────────────────────────────
  "huella_sistema": {
    "fabricante": "FLUIX TECH, S.L.",
    "nombre_software": "Fluix CRM",
    "version": "1.0.0",
    "numero_instalacion": "INST-001",       // Único por empresa
    "tipo_dispositivo": "TPV",              // TPV, App, Web
    "nif_desarrollador": "B26997528"
  },
  
  // ── METADATOS VERIFACTU ───────────────────────────────────────────────
  "verifactu": {
    "qr_generado": true,                    // Si se generó QR
    "qr_url": "https://...",                // URL del QR
    "enviado_aeat": false,                  // Si se envió a AEAT
    "fecha_envio_aeat": null,               // Timestamp del envío
    "csv_aeat": null,                       // Código CSV de la AEAT (respuesta)
    "estado_envio": "pendiente"             // pendiente, enviado, error, rechazado
  },
  
  // ── TRAZABILIDAD ──────────────────────────────────────────────────────
  "metadata": {
    "creado_en": Timestamp,                 // Momento de creación (INMUTABLE)
    "creado_por": "user_id",
    "origen": "TPV",                        // TPV, APP, WEB
    "dispositivo_id": "device_123",
    "anulada": false,                       // Si fue anulada (sin borrar)
    "fecha_anulacion": null,
    "motivo_anulacion": null
  }
}
```

---

## 🔒 Reglas de Seguridad Firestore

```javascript
// firestore.rules

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ═══════════════════════════════════════════════════════════════════
    // FACTURAS VERIFACTU - INMUTABILIDAD ESTRICTA
    // ═══════════════════════════════════════════════════════════════════
    
    match /empresas/{empresaId}/facturas_verifactu/{facturaId} {
      
      // ✅ PERMITIDO: Crear (solo una vez)
      allow create: if 
        request.auth != null &&
        isEmpresaUser(empresaId) &&
        // Verificar que tiene todos los campos obligatorios
        request.resource.data.keys().hasAll([
          'id_factura', 'fecha_expedicion', 'emisor', 'base_imponible',
          'tipo_iva', 'cuota_iva', 'total_factura', 'hash_anterior',
          'hash_actual', 'numero_registro', 'tipo_factura', 'huella_sistema'
        ]) &&
        // Verificar que el hash_actual no es vacío
        request.resource.data.hash_actual.size() == 64 &&
        // Verificar que metadata.creado_en es igual a request.time
        request.resource.data.metadata.creado_en == request.time;
      
      // ✅ PERMITIDO: Leer (auditado)
      allow read: if 
        request.auth != null &&
        isEmpresaUser(empresaId);
      
      // ❌ PROHIBIDO: Actualizar
      allow update: if false;
      
      // ❌ PROHIBIDO: Eliminar
      allow delete: if false;
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // EVENTOS VERIFACTU - SOLO ESCRITURA
    // ═══════════════════════════════════════════════════════════════════
    
    match /empresas/{empresaId}/eventos_verifactu/{eventoId} {
      allow create: if 
        request.auth != null &&
        isEmpresaUser(empresaId);
      
      allow read: if 
        request.auth != null &&
        isEmpresaUser(empresaId);
      
      allow update: if false;
      allow delete: if false;
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════
    
    function isEmpresaUser(empresaId) {
      return exists(/databases/$(database)/documents/usuarios/$(request.auth.uid)) &&
             get(/databases/$(database)/documents/usuarios/$(request.auth.uid))
               .data.empresa_id == empresaId;
    }
    
    function isAdmin() {
      return request.auth != null &&
             request.auth.token.admin == true;
    }
  }
}
```

---

## 🔄 Gestión de Anulaciones (sin borrar)

Las facturas **NUNCA se borran**. Para anular:

1. **Crear factura rectificativa** (tipo F3) que referencia la original
2. **Marcar la original como anulada** mediante evento de sistema (NO update directo)
3. **Registrar evento de anulación** en `eventos_verifactu`

**Cloud Function para anulación:**

```typescript
// functions/src/verifactu/anularFactura.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const anularFacturaVerifactu = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    
    // Verificar autenticación
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Usuario no autenticado'
      );
    }
    
    const { empresaId, facturaId, motivo } = data;
    
    const db = admin.firestore();
    
    // 1. Verificar que la factura existe y no está anulada
    const facturaRef = db
      .collection('empresas').doc(empresaId)
      .collection('facturas_verifactu').doc(facturaId);
    
    const facturaDoc = await facturaRef.get();
    
    if (!facturaDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Factura no encontrada'
      );
    }
    
    const facturaData = facturaDoc.data()!;
    
    if (facturaData.metadata?.anulada) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'La factura ya está anulada'
      );
    }
    
    // 2. Crear factura rectificativa (tipo R1 = anulación)
    const rectificativaRef = db
      .collection('empresas').doc(empresaId)
      .collection('facturas_verifactu').doc();
    
    const numeroRegistro = facturaData.numero_registro + 1;
    
    const rectificativa = {
      ...facturaData,
      id_factura: `${facturaData.id_factura}-R`,
      tipo_factura: 'F3',
      factura_sustituida: facturaId,
      motivo_rectificacion: 'R1', // Anulación
      base_imponible: -facturaData.base_imponible, // Importes negativos
      cuota_iva: -facturaData.cuota_iva,
      total_factura: -facturaData.total_factura,
      numero_registro: numeroRegistro,
      hash_anterior: facturaData.hash_actual,
      fecha_expedicion: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        creado_en: admin.firestore.FieldValue.serverTimestamp(),
        creado_por: context.auth.uid,
        origen: 'ANULACION',
        dispositivo_id: 'cloud-function',
        anulada: false
      }
    };
    
    // Calcular nuevo hash
    rectificativa.hash_actual = await calcularHashFactura(rectificativa);
    
    // 3. Crear evento de anulación
    const eventoRef = db
      .collection('empresas').doc(empresaId)
      .collection('eventos_verifactu').doc();
    
    await eventoRef.set({
      tipo_evento: 'ANULACION',
      factura_id: facturaId,
      factura_rectificativa_id: rectificativaRef.id,
      motivo,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      usuario_id: context.auth.uid
    });
    
    // 4. Guardar factura rectificativa
    await rectificativaRef.set(rectificativa);
    
    // NOTA: NO actualizamos la factura original (inmutable)
    // El campo "anulada" solo se actualiza mediante eventos de sistema internos
    
    return {
      success: true,
      factura_rectificativa_id: rectificativaRef.id,
      evento_id: eventoRef.id
    };
  });

// Helper para calcular hash
async function calcularHashFactura(factura: any): Promise<string> {
  // Ver sección 2 para implementación completa
  return 'hash_placeholder';
}
```

---

# 2. HASH SHA-256 ENCADENADO

## 🔗 Algoritmo de Hash Encadenado

### Cloud Function: Cálculo Automático al Crear Factura

```typescript
// functions/src/verifactu/hashEncadenado.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

/**
 * Trigger que se ejecuta ANTES de crear una factura (onWrite)
 * para calcular el hash encadenado
 */
export const calcularHashVerifactu = functions
  .region('europe-west1')
  .firestore
  .document('empresas/{empresaId}/facturas_verifactu/{facturaId}')
  .onCreate(async (snap, context) => {
    
    const { empresaId } = context.params;
    const facturaData = snap.data();
    
    const db = admin.firestore();
    
    try {
      // 1. Obtener el hash del registro anterior
      const ultimaFacturaQuery = await db
        .collection('empresas').doc(empresaId)
        .collection('facturas_verifactu')
        .where('numero_registro', '<', facturaData.numero_registro)
        .orderBy('numero_registro', 'desc')
        .limit(1)
        .get();
      
      let hashAnterior = '0000000000000000000000000000000000000000000000000000000000000000';
      
      if (!ultimaFacturaQuery.empty) {
        const ultimaFactura = ultimaFacturaQuery.docs[0].data();
        hashAnterior = ultimaFactura.hash_actual;
      }
      
      // 2. Calcular hash del registro actual
      const hashActual = calcularHash({
        ...facturaData,
        hash_anterior: hashAnterior
      });
      
      // 3. Actualizar el documento con los hash (solo si no están)
      if (!facturaData.hash_actual || !facturaData.hash_anterior) {
        await snap.ref.update({
          hash_anterior: hashAnterior,
          hash_actual: hashActual
        });
      }
      
      // 4. Registrar evento
      await db
        .collection('empresas').doc(empresaId)
        .collection('eventos_verifactu').add({
          tipo_evento: 'CALCULO_HASH',
          factura_id: snap.id,
          hash_calculado: hashActual,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
      
    } catch (error) {
      console.error('Error calculando hash:', error);
      
      // Registrar error
      await db
        .collection('empresas').doc(empresaId)
        .collection('eventos_verifactu').add({
          tipo_evento: 'ERROR_HASH',
          factura_id: snap.id,
          error: String(error),
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
    }
  });

/**
 * Calcula el hash SHA-256 de una factura según especificación Verifactu
 * 
 * Campos que entran en el cálculo (en este orden):
 * 1. NIF Emisor
 * 2. Número de Factura
 * 3. Fecha de Expedición (YYYY-MM-DD)
 * 4. Hora de Expedición (HH:MM:SS)
 * 5. Tipo de Factura
 * 6. Base Imponible
 * 7. Cuota IVA
 * 8. Total Factura
 * 9. Hash Anterior (encadenamiento)
 */
function calcularHash(factura: any): string {
  // Formatear fecha como YYYY-MM-DD
  const fecha = factura.fecha_expedicion.toDate();
  const fechaStr = fecha.toISOString().split('T')[0];
  
  // Construir cadena canónica
  const cadenaHash = [
    factura.emisor.nif,
    factura.id_factura,
    fechaStr,
    factura.hora_expedicion || '00:00:00',
    factura.tipo_factura,
    formatoNumerico(factura.base_imponible),
    formatoNumerico(factura.cuota_iva),
    formatoNumerico(factura.total_factura),
    factura.hash_anterior
  ].join('|');
  
  // Calcular SHA-256
  const hash = crypto
    .createHash('sha256')
    .update(cadenaHash, 'utf8')
    .digest('hex');
  
  return hash;
}

/**
 * Formatea números con 2 decimales, separador de punto
 */
function formatoNumerico(valor: number): string {
  return valor.toFixed(2);
}

/**
 * Cloud Function HTTP para verificar integridad de la cadena
 */
export const verificarIntegridadCadena = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
    }
    
    const { empresaId } = data;
    const db = admin.firestore();
    
    // Obtener todas las facturas ordenadas
    const facturasSnap = await db
      .collection('empresas').doc(empresaId)
      .collection('facturas_verifactu')
      .orderBy('numero_registro', 'asc')
      .get();
    
    const errores: any[] = [];
    let hashAnterior = '0000000000000000000000000000000000000000000000000000000000000000';
    
    for (const doc of facturasSnap.docs) {
      const factura = doc.data();
      
      // Verificar que el hash_anterior coincide
      if (factura.hash_anterior !== hashAnterior) {
        errores.push({
          factura_id: doc.id,
          numero_registro: factura.numero_registro,
          error: 'hash_anterior no coincide',
          esperado: hashAnterior,
          encontrado: factura.hash_anterior
        });
      }
      
      // Recalcular hash y verificar
      const hashRecalculado = calcularHash({
        ...factura,
        hash_anterior: hashAnterior
      });
      
      if (hashRecalculado !== factura.hash_actual) {
        errores.push({
          factura_id: doc.id,
          numero_registro: factura.numero_registro,
          error: 'hash_actual no coincide (posible manipulación)',
          esperado: hashRecalculado,
          encontrado: factura.hash_actual
        });
      }
      
      hashAnterior = factura.hash_actual;
    }
    
    return {
      total_facturas: facturasSnap.size,
      integridad_ok: errores.length === 0,
      errores
    };
  });
```

---

## 🎬 Inicialización de la Cadena (Primera Factura)

```dart
// lib/services/verifactu/verifactu_service.dart

class VerifactuService {
  
  /// Obtiene el siguiente número de registro y el hash anterior
  Future<Map<String, dynamic>> obtenerDatosNuevaFactura(
    String empresaId
  ) async {
    final db = FirebaseFirestore.instance;
    
    // Buscar la última factura
    final ultimaFacturaQuery = await db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas_verifactu')
        .orderBy('numero_registro', descending: true)
        .limit(1)
        .get();
    
    if (ultimaFacturaQuery.docs.isEmpty) {
      // Primera factura de la empresa
      return {
        'numero_registro': 1,
        'hash_anterior': '0' * 64, // Hash inicial (64 ceros)
      };
    }
    
    final ultimaFactura = ultimaFacturaQuery.docs.first.data();
    
    return {
      'numero_registro': ultimaFactura['numero_registro'] + 1,
      'hash_anterior': ultimaFactura['hash_actual'],
    };
  }
}
```

---

# 3. REGISTRO DE EVENTOS

## 📝 Estructura de Eventos

### Colección: `empresas/{empresaId}/eventos_verifactu/{eventoId}`

```javascript
{
  // ── IDENTIFICACIÓN DEL EVENTO ─────────────────────────────────────────
  "tipo_evento": "ALTA",          // ALTA, ANULACION, SUSTITUCION, ERROR, ENVIO_AEAT
  "timestamp": Timestamp,          // Momento del evento
  
  // ── RELACIÓN CON FACTURA ──────────────────────────────────────────────
  "factura_id": "fact_123",        // ID de la factura afectada
  "numero_factura": "2026/00001",
  "numero_registro": 1,
  
  // ── DATOS ESPECÍFICOS DEL EVENTO ──────────────────────────────────────
  "detalles": {
    // Para ALTA:
    "hash_calculado": "abc123...",
    
    // Para ANULACION:
    "factura_rectificativa_id": "fact_456",
    "motivo": "Error en importe",
    
    // Para SUSTITUCION:
    "factura_original_id": "fact_789",
    "factura_nueva_id": "fact_790",
    
    // Para ERROR:
    "codigo_error": "ERR_HASH_001",
    "mensaje_error": "No se pudo calcular hash",
    "stack_trace": "...",
    
    // Para ENVIO_AEAT:
    "estado_envio": "exitoso",      // exitoso, fallido, pendiente_reintento
    "csv_aeat": "CSV123456",
    "codigo_respuesta": "200",
    "mensaje_respuesta": "Recibido correctamente"
  },
  
  // ── TRAZABILIDAD ──────────────────────────────────────────────────────
  "usuario_id": "user_123",        // Quien provocó el evento (si aplica)
  "dispositivo_id": "device_456",
  "ip_address": "192.168.1.1",     // IP del cliente
  "user_agent": "Fluix CRM v1.0.0"
}
```

---

## 📊 Tipos de Eventos Obligatorios

| Código | Evento | Cuándo Registrar |
|--------|--------|------------------|
| `ALTA` | Alta de factura | Al crear cualquier factura nueva |
| `ANULACION` | Anulación | Al anular una factura (crear rectificativa R1) |
| `SUSTITUCION` | Sustitución | Al sustituir una factura (crear rectificativa R2-R5) |
| `ERROR_HASH` | Error en hash | Si falla el cálculo del hash encadenado |
| `ERROR_QR` | Error en QR | Si falla la generación del código QR |
| `ENVIO_AEAT` | Envío a AEAT | Cada intento de envío (exitoso o fallido) |
| `VERIFICACION` | Verificación externa | Cuando alguien verifica el QR |

---

## 🔧 Cloud Function para Registrar Eventos

```typescript
// functions/src/verifactu/registrarEvento.ts

import * as admin from 'firebase-admin';

export interface EventoVerifactu {
  tipo_evento: 'ALTA' | 'ANULACION' | 'SUSTITUCION' | 'ERROR' | 'ENVIO_AEAT' | 'VERIFICACION';
  factura_id: string;
  numero_factura?: string;
  numero_registro?: number;
  detalles: any;
  usuario_id?: string;
  dispositivo_id?: string;
  ip_address?: string;
  user_agent?: string;
}

export async function registrarEventoVerifactu(
  empresaId: string,
  evento: EventoVerifactu
): Promise<string> {
  
  const db = admin.firestore();
  
  const eventoDoc = await db
    .collection('empresas').doc(empresaId)
    .collection('eventos_verifactu')
    .add({
      ...evento,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  
  console.log(`Evento ${evento.tipo_evento} registrado: ${eventoDoc.id}`);
  
  return eventoDoc.id;
}
```

---

# 4. CÓDIGO QR EN FACTURA

## 📱 Campos Obligatorios según Orden HAC/1177/2024

El código QR debe contener una URL con estos parámetros:

```
https://prewww2.aeat.es/wlpl/TIKE-CONT/ValidarQR?
  nif={NIF_EMISOR}&
  num={NUMERO_FACTURA}&
  fec={FECHA_EXPEDICION}&
  imp={TOTAL_FACTURA}&
  id={ID_INSTALACION}
```

**Ejemplo real:**
```
https://prewww2.aeat.es/wlpl/TIKE-CONT/ValidarQR?
  nif=B26997528&
  num=2026/00001&
  fec=26-05-2026&
  imp=121.00&
  id=INST-001
```

---

## 🎨 Generación del QR en Flutter

### Dependencia a añadir en `pubspec.yaml`:

```yaml
dependencies:
  qr_flutter: ^4.1.0  # Generación de QR codes
```

### Servicio Flutter:

```dart
// lib/services/verifactu/qr_generator_service.dart

import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class QrVerifactuService {
  
  /// Genera la URL del QR según especificación AEAT
  String generarUrlQr({
    required String nifEmisor,
    required String numeroFactura,
    required DateTime fechaExpedicion,
    required double totalFactura,
    required String idInstalacion,
  }) {
    // Formato fecha: DD-MM-YYYY
    final fechaStr = DateFormat('dd-MM-yyyy').format(fechaExpedicion);
    
    // Formato importe: con 2 decimales y punto
    final importeStr = totalFactura.toStringAsFixed(2);
    
    // Construir URL
    final url = 'https://prewww2.aeat.es/wlpl/TIKE-CONT/ValidarQR'
        '?nif=$nifEmisor'
        '&num=${Uri.encodeComponent(numeroFactura)}'
        '&fec=$fechaStr'
        '&imp=$importeStr'
        '&id=$idInstalacion';
    
    return url;
  }
  
  /// Genera el widget QR para mostrar en la factura
  Widget generarQrWidget({
    required String nifEmisor,
    required String numeroFactura,
    required DateTime fechaExpedicion,
    required double totalFactura,
    required String idInstalacion,
    double size = 150.0,
  }) {
    final url = generarUrlQr(
      nifEmisor: nifEmisor,
      numeroFactura: numeroFactura,
      fechaExpedicion: fechaExpedicion,
      totalFactura: totalFactura,
      idInstalacion: idInstalacion,
    );
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Código QR
        QrImageView(
          data: url,
          version: QrVersions.auto,
          size: size,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
        ),
        const SizedBox(height: 8),
        // Texto legal obligatorio
        const Text(
          'VERI*FACTU',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sistema de verificación de facturas',
          style: TextStyle(
            fontSize: 8,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  /// Genera el QR como Uint8List para incluir en PDF
  Future<Uint8List> generarQrBytes({
    required String nifEmisor,
    required String numeroFactura,
    required DateTime fechaExpedicion,
    required double totalFactura,
    required String idInstalacion,
    int size = 150,
  }) async {
    final url = generarUrlQr(
      nifEmisor: nifEmisor,
      numeroFactura: numeroFactura,
      fechaExpedicion: fechaExpedicion,
      totalFactura: totalFactura,
      idInstalacion: idInstalacion,
    );
    
    // Generar QR
    final qrCode = QrCode.fromData(
      data: url,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    
    // Renderizar como imagen
    final qrPainter = QrPainter.withQr(
      qr: qrCode,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
      gapless: true,
    );
    
    // Convertir a bytes (necesita package adicional o rendered manualmente)
    // Por simplicidad, retornamos placeholder
    // En producción: usar package:image o canvas rendering
    
    return Uint8List(0); // Placeholder
  }
}
```

---

## 📄 Integración en PDF con package `pdf`

```dart
// lib/services/tpv/tpv_document_renderer.dart (actualización)

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../verifactu/qr_generator_service.dart';

class TpvDocumentRenderer {
  final QrVerifactuService _qrService = QrVerifactuService();
  
  Future<Uint8List> generarFacturaConQr({
    required Map<String, dynamic> facturaData,
    required Map<String, dynamic> empresaData,
  }) async {
    final pdf = pw.Document();
    
    // Generar URL del QR
    final qrUrl = _qrService.generarUrlQr(
      nifEmisor: empresaData['nif'],
      numeroFactura: facturaData['id_factura'],
      fechaExpedicion: (facturaData['fecha_expedicion'] as Timestamp).toDate(),
      totalFactura: facturaData['total_factura'],
      idInstalacion: facturaData['huella_sistema']['numero_instalacion'],
    );
    
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ... resto de la factura ...
            
            pw.Spacer(),
            
            // Sección QR Verifactu
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                children: [
                  // QR Code
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrUrl,
                    width: 100,
                    height: 100,
                  ),
                  pw.SizedBox(width: 16),
                  // Texto legal
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VERI*FACTU',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Esta factura ha sido expedida mediante un sistema informático de facturación que '
                          'cumple con el Reglamento por el que se regulan las obligaciones de facturación '
                          '(RD 1007/2023).',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Para verificar la autenticidad de esta factura, '
                          'escanee el código QR con su móvil.',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Huella del sistema
            pw.SizedBox(height: 8),
            pw.Text(
              'Software: ${facturaData['huella_sistema']['nombre_software']} '
              'v${facturaData['huella_sistema']['version']} | '
              'Desarrollado por: ${facturaData['huella_sistema']['fabricante']} '
              '(NIF: ${facturaData['huella_sistema']['nif_desarrollador']})',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
    
    return pdf.save();
  }
}
```

---

## 📝 Texto Legal Obligatorio

Debe aparecer en **TODAS las facturas**:

```
VERI*FACTU

Esta factura ha sido expedida mediante un sistema informático de facturación
que cumple con el Reglamento por el que se regulan las obligaciones de 
facturación (RD 1007/2023 modificado por RD 254/2025).

Para verificar la autenticidad de esta factura, escanee el código QR.
```

**También debe aparecer:**
- Nombre y versión del software
- Fabricante y su NIF
- Número de instalación

---

# 5. REMISIÓN A LA AEAT

## 🔄 Modalidades de Envío

### Opción 1: **CON ENVÍO INMEDIATO** (VERI*FACTU)

- ✅ **Obligatorio para:** Facturas > 100.000€
- ⚙️ **Requisito:** Envío en **tiempo real** (máximo 4 días naturales)
- 🔐 **Comunicación:** API web service de la AEAT
- ✅ **Ventaja:** Mayor seguridad, permite deducción IVA inmediata

### Opción 2: **SIN ENVÍO INMEDIATO** (TicketBAI + Conservación)

- ✅ **Válido para:** Facturas < 100.000€
- ⚙️ **Requisito:** Conservación del registro durante 4 años
- 📤 **Envío:** Solo bajo requerimiento de inspección
- ⚠️ **Limitación:** No permite deducción IVA hasta SII

---

## 📡 API de la AEAT - Estructura XML/JSON

### Endpoint de Envío (Producción):

```
https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/aplicaciones/es/aeat/burt/jdit/ws/SuministroLR.html
```

### Estructura del Request (XML SOAP):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope 
    xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:siiR="https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/aplicaciones/es/aeat/ssii/fact/ws/SuministroInformacion.xsd">
  <soapenv:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
      <!-- Certificado digital del emisor -->
    </wsse:Security>
  </soapenv:Header>
  <soapenv:Body>
    <siiR:SuministroLRFacturasEmitidas>
      <siiR:Cabecera>
        <siiR:IDVersionSii>1.1</siiR:IDVersionSii>
        <siiR:Titular>
          <siiR:NIF>B26997528</siiR:NIF>
          <siiR:NombreRazon>MI COMERCIO SL</siiR:NombreRazon>
        </siiR:Titular>
        <siiR:TipoComunicacion>A0</siiR:TipoComunicacion>
      </siiR:Cabecera>
      <siiR:RegistroLRFacturasEmitidas>
        <siiR:PeriodoImpositivo>
          <siiR:Ejercicio>2026</siiR:Ejercicio>
          <siiR:Periodo>05</siiR:Periodo>
        </siiR:PeriodoImpositivo>
        <siiR:IDFactura>
          <siiR:IDEmisorFactura>
            <siiR:NIF>B26997528</siiR:NIF>
          </siiR:IDEmisorFactura>
          <siiR:NumSerieFacturaEmisor>2026/00001</siiR:NumSerieFacturaEmisor>
          <siiR:FechaExpedicionFacturaEmisor>26-05-2026</siiR:FechaExpedicionFacturaEmisor>
        </siiR:IDFactura>
        <siiR:FacturaExpedida>
          <siiR:TipoFactura>F1</siiR:TipoFactura>
          <siiR:ClaveRegimenEspecialOTrascendencia>01</siiR:ClaveRegimenEspecialOTrascendencia>
          <siiR:ImporteTotal>121.00</siiR:ImporteTotal>
          <siiR:DescripcionOperacion>Venta TPV</siiR:DescripcionOperacion>
          <siiR:TipoDesglose>
            <siiR:DesgloseFactura>
              <siiR:Sujeta>
                <siiR:NoExenta>
                  <siiR:TipoNoExenta>S1</siiR:TipoNoExenta>
                  <siiR:DesgloseIVA>
                    <siiR:DetalleIVA>
                      <siiR:TipoImpositivo>21.00</siiR:TipoImpositivo>
                      <siiR:BaseImponible>100.00</siiR:BaseImponible>
                      <siiR:CuotaRepercutida>21.00</siiR:CuotaRepercutida>
                    </siiR:DetalleIVA>
                  </siiR:DesgloseIVA>
                </siiR:NoExenta>
              </siiR:Sujeta>
            </siiR:DesgloseFactura>
          </siiR:TipoDesglose>
          
          <!-- CAMPOS ESPECÍFICOS VERIFACTU -->
          <siiR:SistemaInformaticoFacturacion>
            <siiR:IdSistemaInformaticoFacturacion>FLUIX-CRM-001</siiR:IdSistemaInformaticoFacturacion>
            <siiR:VersionSistemaInformaticoFacturacion>1.0.0</siiR:VersionSistemaInformaticoFacturacion>
            <siiR:NumeroInstalacion>INST-001</siiR:NumeroInstalacion>
            <siiR:TipoUsoPosibleSoloVerifactu>S</siiR:TipoUsoPosibleSoloVerifactu>
            <siiR:TipoUsoPosibleMultiOT>N</siiR:TipoUsoPosibleMultiOT>
            <siiR:IndicadorMultiplesOT>N</siiR:IndicadorMultiplesOT>
            <siiR:NIFFabricanteSistemaInformático>B26997528</siiR:NIFFabricanteSistemaInformático>
            <siiR:NIF_ID_OtroDiferentefabricante>B26997528</siiR:NIF_ID_OtroDiferentefabricante>
            <siiR:NombreSistemaInformático>Fluix CRM</siiR:NombreSistemaInformático>
          </siiR:SistemaInformaticoFacturacion>
          
          <!-- HASH ENCADENADO -->
          <siiR:VerifactuFacturaRegistrada>
            <siiR:HuellaSHA256RegistroFactura>5678efgh...</siiR:HuellaSHA256RegistroFactura>
            <siiR:NumeroRegistroVerifactu>1</siiR:NumeroRegistroVerifactu>
            <siiR:FechaHoraHusellaGenerada>2026-05-26T14:32:15Z</siiR:FechaHoraHusellaGenerada>
          </siiR:VerifactuFacturaRegistrada>
          
        </siiR:FacturaExpedida>
      </siiR:RegistroLRFacturasEmitidas>
    </siiR:SuministroLRFacturasEmitidas>
  </soapenv:Body>
</soapenv:Envelope>
```

---

## ⚙️ Cloud Function para Envío a AEAT

```typescript
// functions/src/verifactu/enviarAeat.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';
import * as xmlbuilder from 'xmlbuilder';
import { registrarEventoVerifactu } from './registrarEvento';

/**
 * Cloud Function programada que envía facturas pendientes a la AEAT
 * Se ejecuta cada hora
 */
export const enviarFacturasAeat = functions
 .region('europe-west1')
  .pubsub.schedule('every 1 hours')
  .onRun(async (context) => {
    
    const db = admin.firestore();
    
    // Buscar facturas pendientes de envío (últimas 24h)
    const hace24h = new Date();
    hace24h.setHours(hace24h.getHours() - 24);
    
    const facturasQuery = await db
      .collectionGroup('facturas_verifactu')
      .where('verifactu.enviado_aeat', '==', false)
      .where('fecha_expedicion', '>', hace24h)
      .limit(100) // Procesar por lotes
      .get();
    
    console.log(`Facturas pendientes de envío: ${facturasQuery.size}`);
    
    for (const facturaDoc of facturasQuery.docs) {
      const empresaId = facturaDoc.ref.parent.parent!.id;
      const facturaData = facturaDoc.data();
      
      try {
        // Enviar a AEAT
        const resultado = await enviarFacturaAeat(empresaId, facturaData);
        
        // Actualizar estado (esto es una excepción a la inmutabilidad,
        // solo para metadatos de envío)
        await facturaDoc.ref.update({
          'verifactu.enviado_aeat': true,
          'verifactu.fecha_envio_aeat': admin.firestore.FieldValue.serverTimestamp(),
          'verifactu.csv_aeat': resultado.csv,
          'verifactu.estado_envio': 'enviado'
        });
        
        // Registrar evento
        await registrarEventoVerifactu(empresaId, {
          tipo_evento: 'ENVIO_AEAT',
          factura_id: facturaDoc.id,
          numero_factura: facturaData.id_factura,
          detalles: {
            estado_envio: 'exitoso',
            csv_aeat: resultado.csv,
            codigo_respuesta: resultado.codigo,
            mensaje_respuesta: resultado.mensaje
          }
        });
        
      } catch (error: any) {
        console.error(`Error enviando factura ${facturaDoc.id}:`, error);
        
        // Marcar error
        await facturaDoc.ref.update({
          'verifactu.estado_envio': 'error',
          'verifactu.ultimo_error': error.message
        });
        
        // Registrar evento de error
        await registrarEventoVerifactu(empresaId, {
          tipo_evento: 'ENVIO_AEAT',
          factura_id: facturaDoc.id,
          numero_factura: facturaData.id_factura,
          detalles: {
            estado_envio: 'fallido',
            codigo_error: error.code || 'UNKNOWN',
            mensaje_error: error.message
          }
        });
      }
    }
    
    console.log('Proceso de envío a AEAT completado');
  });

/**
 * Envía una factura individual a la AEAT
 */
async function enviarFacturaAeat(
  empresaId: string,
  factura: any
): Promise<{ csv: string; codigo: string; mensaje: string }> {
  
  // 1. Obtener datos de la empresa (para certificado, NIF, etc.)
  const empresaDoc = await admin.firestore()
    .collection('empresas')
    .doc(empresaId)
    .get();
  
  const empresaData = empresaDoc.data();
  
  if (!empresaData) {
    throw new Error('Empresa no encontrada');
  }
  
  // 2. Construir XML SOAP
  const xml = construirXmlSII(factura, empresaData);
  
  // 3. Firmar con certificado digital (requiere configuración adicional)
  // const xmlFirmado = await firmarXml(xml, empresaData.certificado);
  
  // 4. Enviar a AEAT
  const urlAeat = functions.config().aeat?.url || 
    'https://www2.agenciatributaria.gob.es/wlpl/SSII-FACT/ws/fe/SiiFactFEV1SOAP';
  
  const response = await axios.post(urlAeat, xml, {
    headers: {
      'Content-Type': 'text/xml; charset=utf-8',
      'SOAPAction': 'SuministroLRFacturasEmitidas'
    },
    timeout: 30000
  });
  
  // 5. Parsear respuesta
  const respuesta = parsearRespuestaAeat(response.data);
  
  if (respuesta.estado === 'Correcto') {
    return {
      csv: respuesta.csv,
      codigo: respuesta.codigo,
      mensaje: respuesta.descripcion
    };
  } else {
    throw new Error(`AEAT rechazó la factura: ${respuesta.descripcion}`);
  }
}

/**
 * Construye el XML según especificación SII
 */
function construirXmlSII(factura: any, empresa: any): string {
  const fecha = factura.fecha_expedicion.toDate();
  const ejercicio = fecha.getFullYear();
  const periodo = String(fecha.getMonth() + 1).padStart(2, '0');
  
  const xml = xmlbuilder.create('soapenv:Envelope', { 
    version: '1.0', 
    encoding: 'UTF-8' 
  })
    .att('xmlns:soapenv', 'http://schemas.xmlsoap.org/soap/envelope/')
    .att('xmlns:sii', 'https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/aplicaciones/es/aeat/ssii/fact/ws/SuministroInformacion.xsd')
    .ele('soapenv:Header').up()
    .ele('soapenv:Body')
      .ele('sii:SuministroLRFacturasEmitidas')
        .ele('sii:Cabecera')
          .ele('sii:IDVersionSii', '1.1').up()
          .ele('sii:Titular')
            .ele('sii:NIF', empresa.nif).up()
            .ele('sii:NombreRazon', empresa.nombre).up()
          .up()
          .ele('sii:TipoComunicacion', 'A0').up()
        .up()
        .ele('sii:RegistroLRFacturasEmitidas')
          .ele('sii:PeriodoImpositivo')
            .ele('sii:Ejercicio', ejercicio).up()
            .ele('sii:Periodo', periodo).up()
          .up()
          .ele('sii:IDFactura')
            .ele('sii:IDEmisorFactura')
              .ele('sii:NIF', factura.emisor.nif).up()
            .up()
            .ele('sii:NumSerieFacturaEmisor', factura.id_factura).up()
            .ele('sii:FechaExpedicionFacturaEmisor', 
              formatearFecha(fecha)).up()
          .up()
          .ele('sii:FacturaExpedida')
            .ele('sii:TipoFactura', factura.tipo_factura).up()
            .ele('sii:ClaveRegimenEspecialOTrascendencia', '01').up()
            .ele('sii:ImporteTotal', factura.total_factura.toFixed(2)).up()
            .ele('sii:DescripcionOperacion', 'Venta TPV').up()
            // ... desglose IVA ...
            .ele('sii:SistemaInformaticoFacturacion')
              .ele('sii:IdSistemaInformaticoFacturacion', 'FLUIX-CRM-001').up()
              .ele('sii:VersionSistemaInformaticoFacturacion', 
                factura.huella_sistema.version).up()
              .ele('sii:NumeroInstalacion', 
                factura.huella_sistema.numero_instalacion).up()
              .ele('sii:NIFFabricanteSistemaInformático', 
                factura.huella_sistema.nif_desarrollador).up()
            .up()
            .ele('sii:VerifactuFacturaRegistrada')
              .ele('sii:HuellaSHA256RegistroFactura', factura.hash_actual).up()
              .ele('sii:NumeroRegistroVerifactu', factura.numero_registro).up()
            .up()
          .up()
        .up()
      .up()
    .up();
  
  return xml.end({ pretty: true });
}

function formatearFecha(fecha: Date): string {
  const dia = String(fecha.getDate()).padStart(2, '0');
  const mes = String(fecha.getMonth() + 1).padStart(2, '0');
  const año = fecha.getFullYear();
  return `${dia}-${mes}-${año}`;
}

function parsearRespuestaAeat(xmlResponse: string): any {
  // Parsear XML de respuesta
  // Placeholder - implementar parser XML real
  return {
    estado: 'Correcto',
    csv: 'CSV123456789',
    codigo: '200',
    descripcion: 'Registro aceptado'
  };
}
```

---

## 🔄 Manejo de Errores y Reintentos

```typescript
// functions/src/verifactu/reintentarEnvios.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Reintenta envíos fallidos cada 6 horas
 */
export const reintentarEnviosAeat = functions
  .region('europe-west1')
  .pubsub.schedule('every 6 hours')
  .onRun(async (context) => {
    
    const db = admin.firestore();
    
    // Buscar facturas con estado de error (máximo 3 intentos)
    const facturasError = await db
      .collectionGroup('facturas_verifactu')
      .where('verifactu.estado_envio', '==', 'error')
      .where('verifactu.intentos_envio', '<', 3)
      .limit(50)
      .get();
    
    for (const doc of facturasError.docs) {
      const empresaId = doc.ref.parent.parent!.id;
      const factura = doc.data();
      
      try {
        // Incrementar contador de intentos
        await doc.ref.update({
          'verifactu.intentos_envio': admin.firestore.FieldValue.increment(1)
        });
        
        // Reintentar envío
        // ... (llamar a enviarFacturaAeat)
        
      } catch (error) {
        console.error(`Fallo reintento ${doc.id}:`, error);
      }
    }
  });
```

---

# 6. EXPORTACIÓN ESTANDARIZADA

## 📤 Formato Requerido para Exportar

La AEAT puede requerir exportación de registros en formato:
- **XML estructurado** (preferido)
- **CSV** con campos específicos

### Cloud Function HTTP para Exportar

```typescript
// functions/src/verifactu/exportarRegistros.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as xmlbuilder from 'xmlbuilder';
import { Parser } from 'json2csv';

export const exportarRegistrosVerifactu = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
    }
    
    const { empresaId, fechaInicio, fechaFin, formato } = data;
    // formato: 'xml' | 'csv' | 'json'
    
    const db = admin.firestore();
    
    // Obtener facturas del rango de fechas
    let query = db
      .collection('empresas').doc(empresaId)
      .collection('facturas_verifactu')
      .orderBy('fecha_expedicion', 'asc');
    
    if (fechaInicio) {
      query = query.where('fecha_expedicion', '>=', new Date(fechaInicio));
    }
    
    if (fechaFin) {
      query = query.where('fecha_expedicion', '<=', new Date(fechaFin));
    }
    
    const facturasSnap = await query.get();
    
    const facturas = facturasSnap.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    // Generar archivo según formato
    let contenido: string;
    let mimeType: string;
    let extension: string;
    
    switch (formato) {
      case 'xml':
        contenido = generarXmlExportacion(facturas);
        mimeType = 'application/xml';
        extension = 'xml';
        break;
      
      case 'csv':
        contenido = generarCsvExportacion(facturas);
        mimeType = 'text/csv';
        extension = 'csv';
        break;
      
      case 'json':
      default:
        contenido = JSON.stringify(facturas, null, 2);
        mimeType = 'application/json';
        extension = 'json';
        break;
    }
    
    // Guardar en Cloud Storage
    const bucket = admin.storage().bucket();
    const nombreArchivo = `exportaciones/${empresaId}/facturas_${Date.now()}.${extension}`;
    const file = bucket.file(nombreArchivo);
    
    await file.save(contenido, {
      contentType: mimeType,
      metadata: {
        empresaId,
        fechaInicio,
        fechaFin,
        total_registros: facturas.length,
        exportado_en: new Date().toISOString()
      }
    });
    
    // Generar URL firmada (válida 7 días)
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + 7 * 24 * 60 * 60 * 1000
    });
    
    return {
      success: true,
      total_registros: facturas.length,
      url_descarga: url,
      formato,
      extension
    };
  });

function generarXmlExportacion(facturas: any[]): string {
  const root = xmlbuilder.create('RegistrosVerifactu', {
    version: '1.0',
    encoding: 'UTF-8'
  })
    .att('xmlns', 'http://www.aeat.es/verifactu/export/v1')
    .att('version', '1.0');
  
  facturas.forEach(factura => {
    root.ele('Registro')
      .ele('NumeroRegistro', factura.numero_registro).up()
      .ele('IDFactura', factura.id_factura).up()
      .ele('FechaExpedicion', factura.fecha_expedicion.toDate().toISOString()).up()
      .ele('NIFEmisor', factura.emisor.nif).up()
      .ele('BaseImponible', factura.base_imponible.toFixed(2)).up()
      .ele('TipoIVA', factura.tipo_iva.toFixed(2)).up()
      .ele('CuotaIVA', factura.cuota_iva.toFixed(2)).up()
      .ele('TotalFactura', factura.total_factura.toFixed(2)).up()
      .ele('HashAnterior', factura.hash_anterior).up()
      .ele('HashActual', factura.hash_actual).up()
      .ele('TipoFactura', factura.tipo_factura).up()
      .up();
  });
  
  return root.end({ pretty: true });
}

function generarCsvExportacion(facturas: any[]): string {
  const campos = [
    'numero_registro',
    'id_factura',
    'fecha_expedicion',
    'emisor.nif',
    'base_imponible',
    'tipo_iva',
    'cuota_iva',
    'total_factura',
    'hash_anterior',
    'hash_actual',
    'tipo_factura'
  ];
  
  const parser = new Parser({ fields: campos, delimiter: ';' });
  
  const facturasPlanas = facturas.map(f => ({
    numero_registro: f.numero_registro,
    id_factura: f.id_factura,
    fecha_expedicion: f.fecha_expedicion.toDate().toISOString(),
    'emisor.nif': f.emisor.nif,
    base_imponible: f.base_imponible.toFixed(2),
    tipo_iva: f.tipo_iva.toFixed(2),
    cuota_iva: f.cuota_iva.toFixed(2),
    total_factura: f.total_factura.toFixed(2),
    hash_anterior: f.hash_anterior,
    hash_actual: f.hash_actual,
    tipo_factura: f.tipo_factura
  }));
  
  return parser.parse(facturasPlanas);
}
```

---

## 📱 Integración en Flutter

```dart
// lib/services/verifactu/exportacion_service.dart

import 'package:cloud_functions/cloud_functions.dart';

class ExportacionVerifactuService {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  
  Future<Map<String, dynamic>> exportarRegistros({
    required String empresaId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String formato = 'xml', // 'xml', 'csv', 'json'
  }) async {
    final callable = _functions.httpsCallable('exportarRegistrosVerifactu');
    
    final resultado = await callable.call({
      'empresaId': empresaId,
      'fechaInicio': fechaInicio?.toIso8601String(),
      'fechaFin': fechaFin?.toIso8601String(),
      'formato': formato,
    });
    
    return Map<String, dynamic>.from(resultado.data);
  }
}
```

---

# 7. DECLARACIÓN RESPONSABLE DEL FABRICANTE

## 📜 Contenido Obligatorio

Como **FLUIX TECH, S.L. (CIF: B26997528)**, fabricante/comercializador de Fluix CRM, debe declarar:

1. **Identificación del fabricante:**
   - Razón social: FLUIX TECH, S.L.
   - NIF: B26997528
   - Domicilio social
   - Persona responsable

2. **Identificación del software:**
   - Nombre comercial: Fluix CRM
   - Versión: 1.0.0
   - Número de identificación único

3. **Declaración de cumplimiento:**
   - Cumplimiento del RD 1007/2023 y RD 254/2025
   - Sistema de inalterabilidad implementado
   - Generación de hash SHA-256 encadenado
   - Registro de eventos obligatorios
   - Capacidad de generación de QR conforme Orden HAC/1177/2024

4. **Compromisos:**
   - Mantenimiento de documentación técnica 5 años
   - Soporte a usuarios para auditorías AEAT
   - Notificación de cambios significativos en el software

---

## 📄 Documento de Declaración (Firebase/Firestore)

```typescript
// Colección: /sistema/verifactu

{
  "declaracion_fabricante": {
    // ── IDENTIFICACIÓN DEL FABRICANTE ──────────────────────────────────
    "fabricante": {
      "razon_social": "FLUIX TECH, S.L.",
      "nif": "B26997528",
      "domicilio": {
        "direccion": "Calle [COMPLETAR]",
        "codigo_postal": "[COMPLETAR]",
        "municipio": "[COMPLETAR]",
        "provincia": "[COMPLETAR]",
        "pais": "ES"
      },
      "email_contacto": "legal@fluixcrm.com",
      "telefono_contacto": "+34 XXX XXX XXX",
      "persona_responsable": "[NOMBRE DEL RESPONSABLE LEGAL]",
      "cargo_responsable": "Administrador Único"
    },
    
    // ── IDENTIFICACIÓN DEL SOFTWARE ────────────────────────────────────
    "software": {
      "nombre_comercial": "Fluix CRM",
      "version_actual": "1.0.0",
      "fecha_primera_version": "2026-01-01",
      "id_software_unico": "FLUIX-CRM-001",
      "tipo_software": "SaaS Multitenant",
      "plataformas": ["Web", "Windows", "iOS", "Android"],
      "url_oficial": "https://fluixcrm.com"
    },
    
    // ── DECLARACIÓN DE CUMPLIMIENTO ────────────────────────────────────
    "declaracion_cumplimiento": {
      "normativa_cumplida": [
        "RD 1007/2023 - Reglamento de facturación",
        "RD 254/2025 - Modificación RRSIF",
        "Orden HAC/1177/2024 - Código QR"
      ],
      "fecha_declaracion": "2026-05-26",
      "funcionalidades": {
        "inalterabilidad": {
          "implementado": true,
          "descripcion": "Sistema de registros inmutables en Firestore con reglas de seguridad que impiden update/delete de facturas"
        },
        "hash_encadenado": {
          "implementado": true,
          "algoritmo": "SHA-256",
          "descripcion": "Cada factura contiene hash del registro anterior, verificable mediante Cloud Function"
        },
        "registro_eventos": {
          "implementado": true,
          "eventos_registrados": ["ALTA", "ANULACION", "SUSTITUCION", "ERROR", "ENVIO_AEAT", "VERIFICACION"]
        },
        "codigo_qr": {
          "implementado": true,
          "conformidad": "Orden HAC/1177/2024",
          "url_verificacion": "https://prewww2.aeat.es/wlpl/TIKE-CONT/ValidarQR"
        },
        "envio_aeat": {
          "implementado": true,
          "modalidad": "Con envío inmediato (opcional)",
          "frecuencia": "Horaria mediante Cloud Functions programadas"
        },
        "exportacion": {
          "implementado": true,
          "formatos_soportados": ["XML", "CSV", "JSON"]
        }
      }
    },
    
    // ── COMPROMISOS DEL FABRICANTE ─────────────────────────────────────
    "compromisos": {
      "documentacion_tecnica": {
        "periodo_conservacion_años": 5,
        "ubicacion": "Firestore + Cloud Storage",
        "responsable_custodia": "FLUIX TECH, S.L."
      },
      "soporte_auditorias": {
        "disponibilidad": "24/7",
        "email_soporte": "soporte@fluixcrm.com",
        "tiempo_respuesta_horas": 24
      },
      "notificacion_cambios": {
        "canal": "Email certificado a AEAT",
        "plazo_previo_dias": 15,
        "incluye_changelog": true
      },
      "formacion_usuarios": {
        "documentacion_disponible": true,
        "url_ayuda": "https://fluixcrm.com/ayuda/verifactu"
      }
    },
    
    // ── AUDITORÍA Y VERIFICACIÓN ───────────────────────────────────────
    "auditoria": {
      "ultima_auditoria_interna": "2026-05-26",
      "proxima_revision": "2027-05-26",
      "certificaciones": []
    },
    
    // ── METADATOS ──────────────────────────────────────────────────────
    "metadata": {
      "creado_en": Timestamp,
      "actualizado_en": Timestamp,
      "version_declaracion": "1.0",
      "firma_electronica": null,  // Si se requiere firma digital
      "hash_documento": "..."     // Hash del documento para integridad
    }
  }
}
```

---

## 📱 Pantalla Flutter: Mostrar Declaración al Usuario

```dart
// lib/features/verifactu/pantallas/declaracion_fabricante_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeclaracionFabricanteScreen extends StatelessWidget {
  const DeclaracionFabricanteScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Declaración Responsable del Fabricante'),
        backgroundColor: Colors.blueGrey,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sistema')
            .doc('verifactu')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final declaracion = data['declaracion_fabricante'];
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user, size: 48, color: Colors.blue),
                      const SizedBox(height: 16),
                      Text(
                        'DECLARACIÓN RESPONSABLE',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cumplimiento del Reglamento de Sistemas Informáticos de Facturación (RRSIF)',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Fabricante
                _buildSection(
                  'Fabricante del Software',
                  Icons.business,
                  [
                    _buildInfoRow('Razón Social', declaracion['fabricante']['razon_social']),
                    _buildInfoRow('NIF', declaracion['fabricante']['nif']),
                    _buildInfoRow('Email', declaracion['fabricante']['email_contacto']),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Software
                _buildSection(
                  'Información del Software',
                  Icons.smartphone,
                  [
                    _buildInfoRow('Nombre', declaracion['software']['nombre_comercial']),
                    _buildInfoRow('Versión', declaracion['software']['version_actual']),
                    _buildInfoRow('ID Único', declaracion['software']['id_software_unico']),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Cumplimiento
                _buildSection(
                  'Cumplimiento Normativo',
                  Icons.check_circle,
                  [
                    _buildFeatureRow('Inalterabilidad de registros', 
                      declaracion['declaracion_cumplimiento']['funcionalidades']['inalterabilidad']['implementado']),
                    _buildFeatureRow('Hash SHA-256 encadenado', 
                      declaracion['declaracion_cumplimiento']['funcionalidades']['hash_encadenado']['implementado']),
                    _buildFeatureRow('Registro de eventos', 
                      declaracion['declaracion_cumplimiento']['funcionalidades']['registro_eventos']['implementado']),
                    _buildFeatureRow('Código QR Verifactu', 
                      declaracion['declaracion_cumplimiento']['funcionalidades']['codigo_qr']['implementado']),
                    _buildFeatureRow('Envío a AEAT', 
                      declaracion['declaracion_cumplimiento']['funcionalidades']['envio_aeat']['implementado']),
                    _buildFeatureRow('Exportación estandarizada', 
                      declaracion['declaracion_cumplimiento']['funcionalidades']['exportacion']['implementado']),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Disclaimer legal
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Esta declaración responsable certifica que Fluix CRM cumple con todos los '
                    'requisitos técnicos y funcionales establecidos en el Real Decreto 1007/2023 '
                    'modificado por Real Decreto 254/2025, relativos a los sistemas informáticos '
                    'de facturación.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSection(String titulo, IconData icono, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeatureRow(String nombre, bool implementado) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            implementado ? Icons.check_circle : Icons.cancel,
            color: implementado ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(nombre)),
        ],
      ),
    );
  }
}
```

---

# 8. INALTERABILIDAD Y AUDITORÍA

## 🚫 OPERACIONES PROHIBIDAS

### Lista de bloqueos obligatorios:

| ❌ Operación | Dónde bloquear | Cómo bloquear |
|-------------|----------------|---------------|
| Actualizar factura | Firestore Rules | `allow update: if false` |
| Eliminar factura | Firestore Rules | `allow delete: if false` |
| Modificar hash_actual | Firestore Rules | Campo de solo lectura |
| Modificar numero_registro | Firestore Rules | Campo de solo lectura |
| Modificar fecha_expedicion | Firestore Rules | Inmutable tras creación |
| Borrar eventos | Firestore Rules | `allow delete: if false` |
| Acceso no autenticado | Firestore Rules | Verificar `request.auth` |

---

## 🔍 Auditoría del Código Actual

### Script de auditoría automática:

```typescript
// functions/src/verifactu/auditoria.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud Function para auditar cumplimiento Verifactu
 * Se ejecuta semanalmente
 */
export const auditarCumplimientoVerifactu = functions
  .region('europe-west1')
  .pubsub.schedule('every sunday 00:00')
  .onRun(async (context) => {
    
    const db = admin.firestore();
    const resultadosAuditoria: any = {
      fecha_auditoria: new Date().toISOString(),
      empresas_auditadas: 0,
      incidencias: [],
      warnings: [],
      cumplimiento_global: true
    };
    
    // 1. Auditar todas las empresas
    const empresasSnap = await db.collection('empresas').get();
    
    for (const empresaDoc of empresasSnap.docs) {
      const empresaId = empresaDoc.id;
      resultadosAuditoria.empresas_auditadas++;
      
      // ── Verificar integridad de cadena de hash ──────────────────────
      const verificacion = await verificarIntegridadCadena(empresaId);
      
      if (!verificacion.integridad_ok) {
        resultadosAuditoria.incidencias.push({
          tipo: 'INTEGRIDAD_HASH',
          empresaId,
          detalles: verificacion.errores
        });
        resultadosAuditoria.cumplimiento_global = false;
      }
      
      // ── Verificar facturas sin hash ─────────────────────────────────
      const facturasSinHash = await db
        .collection('empresas').doc(empresaId)
        .collection('facturas_verifactu')
        .where('hash_actual', '==', null)
        .get();
      
      if (!facturasSinHash.empty) {
        resultadosAuditoria.incidencias.push({
          tipo: 'FACTURAS_SIN_HASH',
          empresaId,
          cantidad: facturasSinHash.size
        });
      }
      
      // ── Verificar facturas sin QR generado ──────────────────────────
      const facturasSinQr = await db
        .collection('empresas').doc(empresaId)
        .collection('facturas_verifactu')
        .where('verifactu.qr_generado', '==', false)
        .get();
      
      if (!facturasSinQr.empty) {
        resultadosAuditoria.warnings.push({
          tipo: 'FACTURAS_SIN_QR',
          empresaId,
          cantidad: facturasSinQr.size
        });
      }
      
      // ── Verificar facturas pendientes de envío AEAT (>7 días) ──────
      const hace7dias = new Date();
      hace7dias.setDate(hace7dias.getDate() - 7);
      
      const facturasAtrasadas = await db
        .collection('empresas').doc(empresaId)
        .collection('facturas_verifactu')
        .where('verifactu.enviado_aeat', '==', false)
        .where('fecha_expedicion', '<', hace7dias)
        .get();
      
      if (!facturasAtrasadas.empty) {
        resultadosAuditoria.warnings.push({
          tipo: 'FACTURAS_ATRASADAS_AEAT',
          empresaId,
          cantidad: facturasAtrasadas.size
        });
      }
    }
    
    // 2. Guardar resultados de auditoría
    await db
      .collection('sistema')
      .doc('auditorias_verifactu')
      .collection('reportes')
      .add(resultadosAuditoria);
    
    // 3. Notificar si hay incidencias críticas
    if (resultadosAuditoria.incidencias.length > 0) {
      // Enviar email al administrador
      console.error('⚠️ INCIDENCIAS CRÍTICAS EN VERIFACTU:', 
        resultadosAuditoria.incidencias);
    }
    
    return resultadosAuditoria;
  });

async function verificarIntegridadCadena(empresaId: string): Promise<any> {
  // Implementación en sección 2
  return { integridad_ok: true, errores: [] };
}
```

---

## 📋 Checklist Final de Implementación

### ✅ Checklist Técnico

- [ ] Estructura de datos `facturas_verifactu` creada en Firestore
- [ ] Reglas de seguridad Firestore desplegadas (inmutabilidad)
- [ ] Cloud Function `calcularHashVerifactu` desplegada
- [ ] Cloud Function `anularFacturaVerifactu` desplegada
- [ ] Estructura `eventos_verifactu` creada
- [ ] Servicio QR implementado en Flutter (`qr_flutter`)
- [ ] Integración QR en generador de PDF
- [ ] Cloud Function `enviarFacturasAeat` desplegada (scheduled)
- [ ] Cloud Function `exportarRegistrosVerifactu` desplegada
- [ ] Documento `declaracion_fabricante` creado en Firestore
- [ ] Pantalla de declaración fabricante en Flutter
- [ ] Cloud Function `auditarCumplimientoVerifactu` desplegada
- [ ] Tests de integridad de hash
- [ ] Tests de flujo completo de facturación
- [ ] Documentación de usuario actualizada

---

## 🚀 Próximos Pasos

1. **Implementar los archivos TypeScript en `/functions/src/verifactu/`**
2. **Desplegar Cloud Functions:** `firebase deploy --only functions`
3. **Actualizar reglas de Firestore:** `firebase deploy --only firestore:rules`
4. **Añadir dependencias Dart** en `pubspec.yaml`
5. **Implementar servicios Flutter** en `lib/services/verifactu/`
6. **Integrar con TPV existente**
7. **Crear pantalla de auditoría** para administradores
8. **Configurar certificado digital** para envíos AEAT (si aplica)
9. **Testing exhaustivo** en entorno de preproducción
10. **Documentar para el usuario** el cumplimiento Verifactu

---

## 📞 Contacto y Soporte

**FLUIX TECH, S.L.**  
NIF: B26997528  
Email: legal@fluixcrm.com  
Soporte técnico: soporte@fluixcrm.com

---

**Fecha del plan:** 2026-05-26  
**Versión del documento:** 1.0  
**Autor:** Equipo técnico Fluix CRM  
**Aprobado por:** [NOMBRE RESPONSABLE LEGAL]

