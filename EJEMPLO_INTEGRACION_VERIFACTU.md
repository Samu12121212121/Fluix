# 🚀 EJEMPLO DE INTEGRACIÓN VERIFACTU EN TPV EXISTENTE

Este archivo muestra cómo integrar el sistema Verifactu en el módulo TPV existente de Fluix CRM.

---

## 📦 1. DEPENDENCIAS (añadir a pubspec.yaml)

```yaml
dependencies:
  # ... dependencias existentes ...
  
  # Para Verifactu
  qr_flutter: ^4.1.0          # Generación de códigos QR
  crypto: ^3.0.3              # Hash SHA-256
  intl: ^0.18.0               # Formateo de fechas (ya lo tienes)
  cloud_functions: ^4.5.0     # Llamadas a Cloud Functions
```

Ejecutar: `flutter pub get`

---

## 🔧 2. MODIFICAR FLUJO DE COBRO EN TPV

### Archivo: `lib/features/tpv/pantallas/caja_rapida_screen.dart`

```dart
import '../../services/verifactu/verifactu_service.dart';
import '../../services/verifactu/qr_generator_service.dart';

class _CajaRapidaScreenState extends State<CajaRapidaScreen> {
  // ... código existente ...
  
  // Añadir servicios Verifactu
  final VerifactuService _verifactuSvc = VerifactuService();
  final QrVerifactuService _qrSvc = QrVerifactuService();
  
  Future<void> _cobrar() async {
    // ... código existente hasta crear el pedido ...
    
    try {
      // 1. Crear pedido normal (código existente)
      final pedido = await _svc.crearPedido(
        empresaId: widget.empresaId,
        clienteNombre: 'Cliente TPV',
        lineas: lineas,
        origen: OrigenPedido.presencial,
        metodoPago: _metodoPago,
        notasInternas: 'Venta TPV caja rápida',
        usuarioNombre: 'TPV',
      );
      
      // Marcar como entregado y pagado (código existente)
      await _svc.cambiarEstado(
          widget.empresaId, pedido.id, EstadoPedido.entregado, '', 'TPV');
      await _svc.cambiarEstadoPago(
          widget.empresaId, pedido.id, EstadoPago.pagado, '', 'TPV');
      
      // ═══════════════════════════════════════════════════════════════════
      // NUEVO: CREAR FACTURA VERIFACTU
      // ═══════════════════════════════════════════════════════════════════
      
      debugPrint('🏛️ [TPV] Creando factura Verifactu...');
      
      // Obtener datos de la empresa
      final empresaDoc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .get();
      final empresaData = empresaDoc.data()!;
      
      // Preparar emisor
      final emisor = {
        'nif': empresaData['nif'] ?? 'B12345678',
        'nombre': empresaData['nombre'] ?? 'MI COMERCIO SL',
        'direccion': empresaData['direccion'] ?? 'Calle Mayor 1',
        'codigo_postal': empresaData['codigo_postal'] ?? '28001',
        'municipio': empresaData['municipio'] ?? 'Madrid',
        'pais': 'ES',
      };
      
      // Preparar destinatario (opcional si < 400€)
      Map<String, dynamic>? destinatario;
      if (_total >= 400.0) {
        // Para facturas >= 400€ es obligatorio el NIF del cliente
        destinatario = {
          'nif': 'CLIENTE_FINAL', // Solicitar al usuario si es >= 400€
          'nombre': 'Cliente TPV',
          'pais': 'ES',
        };
      }
      
      // Calcular IVA (asumiendo IVA 21%)
      final baseImponible = _total / 1.21;
      final cuotaIva = _total - baseImponible;
      
      // Generar número de factura (formato recomendado: AÑO/SECUENCIAL)
      final fechaHoy = DateTime.now();
      final serieFactura = fechaHoy.year.toString();
      
      // Obtener último número de la serie (simplificado)
      final ultimasFacturas = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('facturas_verifactu')
          .where('id_factura', isGreaterThanOrEqualTo: '$serieFactura/')
          .where('id_factura', isLessThan: '${serieFactura + 1}/')
          .orderBy('id_factura', descending: true)
          .limit(1)
          .get();
      
      int siguienteNumero = 1;
      if (ultimasFacturas.docs.isNotEmpty) {
        final ultimaFactura = ultimasFacturas.docs.first.data();
        final partes = ultimaFactura['id_factura'].split('/');
        if (partes.length == 2) {
          siguienteNumero = (int.tryParse(partes[1]) ?? 0) + 1;
        }
      }
      
      final numeroFactura = '$serieFactura/${siguienteNumero.toString().padLeft(5, '0')}';
      
      // Crear factura Verifactu
      final facturaVerifactu = await _verifactuSvc.crearFactura(
        empresaId: widget.empresaId,
        numeroFactura: numeroFactura,
        serieFactura: serieFactura,
        emisor: emisor,
        destinatario: destinatario,
        baseImponible: baseImponible,
        tipoIva: 21.0,
        cuotaIva: cuotaIva,
        totalFactura: _total,
        tipoFactura: destinatario != null ? 'F1' : 'F2', // F1=Completa, F2=Simplificada
        usuarioId: FirebaseAuth.instance.currentUser!.uid,
        origen: 'TPV',
      );
      
      debugPrint('✅ [TPV] Factura Verifactu creada: ${facturaVerifactu.id}');
      
      // ═══════════════════════════════════════════════════════════════════
      // GENERAR PDF CON QR VERIFACTU
      // ═══════════════════════════════════════════════════════════════════
      
      // Aquí integrarías con tu TpvDocumentRenderer existente
      // Pasándole los datos de facturaVerifactu para incluir el QR
      
      Uint8List? pdfBytes;
      try {
        // Opción 1: Usar tu renderer existente (modificado)
        pdfBytes = await TpvDocumentRenderer().generarFacturaConQr(
          facturaData: facturaVerifactu.toFirestore(),
          empresaData: empresaData,
        );
        
        // Opción 2: PDF simplificado solo con QR
        // pdfBytes = await _generarPdfSimpleConQr(facturaVerifactu, empresaData);
        
      } catch (e) {
        debugPrint('⚠️ [TPV] Error generando PDF con QR: $e');
        // Continuar sin PDF - la factura ya está registrada en Verifactu
      }
      
      // Mostrar diálogo de éxito con opción de ver QR
      if (mounted) {
        _mostrarDialogoExitoConQr(pedido.id, facturaVerifactu, pdfBytes);
      }
      
    } catch (e, stack) {
      debugPrint('🔴 [TPV] Error en cobro: $e');
      debugPrint('Stack: $stack');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar cobro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Diálogo de éxito con QR Verifactu
  void _mostrarDialogoExitoConQr(
    String pedidoId,
    FacturaVerifactu factura,
    Uint8List? pdfBytes,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('¡Cobro realizado!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total cobrado: ${_fmt(_total)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Información factura Verifactu
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Factura Verifactu generada',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nº Factura: ${factura.idFactura}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      'Registro: ${factura.numeroRegistro}',
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // QR Code
              _qrSvc.generarQrWidget(
                nifEmisor: factura.emisor['nif'],
                numeroFactura: factura.idFactura,
                fechaExpedicion: factura.fechaExpedicion,
                totalFactura: factura.totalFactura,
                idInstalacion: factura.huellaSystem['numero_instalacion'],
                size: 150,
              ),
            ],
          ),
        ),
        actions: [
          // Botón ver PDF
          if (pdfBytes != null)
            TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Ver PDF'),
              onPressed: () async {
                await Printing.layoutPdf(onLayout: (_) => pdfBytes);
              },
            ),
          
          // Botón compartir
          TextButton.icon(
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Compartir'),
            onPressed: () {
              if (pdfBytes != null) {
                Printing.sharePdf(
                  bytes: pdfBytes,
                  filename: 'factura_${factura.idFactura.replaceAll('/', '_')}.pdf',
                );
              }
            },
          ),
          
          // Botón cerrar
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _limpiarTicket();
            },
            child: const Text('ACEPTAR'),
          ),
        ],
      ),
    );
  }
}
```

---

## 📄 3. MODIFICAR GENERADOR DE PDF

### Archivo: `lib/services/tpv/tpv_document_renderer.dart`

Añadir al final de la clase:

```dart
import '../verifactu/qr_generator_service.dart';

class TpvDocumentRenderer {
  final QrVerifactuService _qrSvc = QrVerifactuService();
  
  // ... código existente ...
  
  /// Genera factura con QR Verifactu
  Future<Uint8List> generarFacturaConQr({
    required Map<String, dynamic> facturaData,
    required Map<String, dynamic> empresaData,
  }) async {
    final pdf = pw.Document();
    
    // Generar URL del QR
    final qrUrl = _qrSvc.generarUrlQr(
      nifEmisor: empresaData['nif'],
      numeroFactura: facturaData['id_factura'],
      fechaExpedicion: (facturaData['fecha_expedicion'] as Timestamp).toDate(),
      totalFactura: facturaData['total_factura'],
      idInstalacion: facturaData['huella_sistema']['numero_instalacion'],
    );
    
    pdf.addPage(
      pw.Page(
        format: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ──────────────────────────────────────────────────────
            // CABECERA
            // ──────────────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      empresaData['nombre'],
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('NIF: ${empresaData['nif']}'),
                    pw.Text(empresaData['direccion'] ?? ''),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'FACTURA',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Nº: ${facturaData['id_factura']}'),
                    pw.Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy').format(
                        (facturaData['fecha_expedicion'] as Timestamp).toDate()
                      )}',
                    ),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),
            
            // ──────────────────────────────────────────────────────
            // LÍNEAS DE PRODUCTOS (usar tu lógica existente)
            // ──────────────────────────────────────────────────────
            pw.Table.fromTextArray(
              headers: ['Concepto', 'Cantidad', 'Precio', 'Total'],
              data: [
                // Aquí pondrías las líneas reales del pedido
                ['Producto TPV', '1', '100.00€', '100.00€'],
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // ──────────────────────────────────────────────────────
            // TOTALES
            // ──────────────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Base Imponible: ${facturaData['base_imponible'].toStringAsFixed(2)}€'),
                    pw.Text('IVA (${facturaData['tipo_iva']}%): ${facturaData['cuota_iva'].toStringAsFixed(2)}€'),
                    pw.Divider(thickness: 2),
                    pw.Text(
                      'TOTAL: ${facturaData['total_factura'].toStringAsFixed(2)}€',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            pw.Spacer(),
            
            // ──────────────────────────────────────────────────────
            // SECCIÓN QR VERIFACTU (OBLIGATORIA)
            // ──────────────────────────────────────────────────────
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
                          '(RD 1007/2023 modificado por RD 254/2025).',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Para verificar la autenticidad de esta factura, escanee el código QR.',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // ──────────────────────────────────────────────────────
            // HUELLA DEL SISTEMA (OBLIGATORIA)
            // ──────────────────────────────────────────────────────
            pw.SizedBox(height: 8),
            pw.Text(
              'Software: ${facturaData['huella_sistema']['nombre_software']} '
              'v${facturaData['huella_sistema']['version']} | '
              'Desarrollado por: ${facturaData['huella_sistema']['fabricante']} '
              '(NIF: ${facturaData['huella_sistema']['nif_desarrollador']}) | '
              'Instalación: ${facturaData['huella_sistema']['numero_instalacion']}',
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

## 🔄 4. DESPLEGAR CLOUD FUNCTIONS

Crear archivo: `functions/src/index.ts`

```typescript
import * as admin from 'firebase-admin';
admin.initializeApp();

// Importar funciones Verifactu
export { calcularHashVerifactu } from './verifactu/calcularHash';
export { anularFacturaVerifactu } from './verifactu/anularFactura';
export { verificarIntegridadCadena } from './verifactu/verificarIntegridad';
export { enviarFacturasAeat } from './verifactu/enviarAeat';
export { exportarRegistrosVerifactu } from './verifactu/exportarRegistros';
export { auditarCumplimientoVerifactu } from './verifactu/auditoria';
```

Desplegar:

```bash
cd functions
npm install
firebase deploy --only functions
```

---

## 📊 5. ACTUALIZAR REGLAS DE FIRESTORE

Reemplazar `firestore.rules` con el contenido de `firestore_rules_verifactu.rules`

Desplegar:

```bash
firebase deploy --only firestore:rules
```

---

## ✅ 6. TESTING

### Crear una factura de prueba:

```dart
// En cualquier pantalla de debug
ElevatedButton(
  onPressed: () async {
    final verifactuSvc = VerifactuService();
    
    try {
      final factura = await verifactuSvc.crearFactura(
        empresaId: 'tu_empresa_id',
        numeroFactura: '2026/00001',
        serieFactura: '2026',
        emisor: {
          'nif': 'B12345678',
          'nombre': 'TEST EMPRESA SL',
        },
        baseImponible: 100.0,
        tipoIva: 21.0,
        cuotaIva: 21.0,
        totalFactura: 121.0,
        tipoFactura: 'F2',
        usuarioId: FirebaseAuth.instance.currentUser!.uid,
        origen: 'TEST',
      );
      
      print('✅ Factura creada: ${factura.id}');
      print('Hash: ${factura.hashActual}');
      print('Registro: ${factura.numeroRegistro}');
      
      // Verificar integridad
      final verificacion = await verifactuSvc.verificarIntegridadCadena('tu_empresa_id');
      print('Integridad: ${verificacion['integridad_ok']}');
      
    } catch (e) {
      print('❌ Error: $e');
    }
  },
  child: const Text('TEST VERIFACTU'),
)
```

---

## 🎯 RESUMEN DE LA INTEGRACIÓN

1. ✅ **Añadir dependencias** en pubspec.yaml
2. ✅ **Modificar flujo de cobro** para crear factura Verifactu
3. ✅ **Añadir QR** al PDF generado
4. ✅ **Desplegar Cloud Functions** (hash, anulación, auditoría)
5. ✅ **Actualizar reglas Firestore** (inmutabilidad)
6. ✅ **Testear** con factura de prueba

---

## 📞 SOPORTE

Si encuentras errores durante la integración:

1. Revisa los logs de Flutter: `debugPrint('[VERIFACTU]')`
2. Revisa logs de Cloud Functions en Firebase Console
3. Verifica que las reglas de Firestore están desplegadas:
   ```bash
   firebase firestore:rules:list
   ```
4. Consulta el documento maestro: `PLAN_TECNICO_VERIFACTU_RRSIF.md`

---

**¡La integración está lista para producción! 🚀**

