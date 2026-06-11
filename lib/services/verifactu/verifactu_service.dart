// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO VERIFACTU - Fluix CRM
// ═══════════════════════════════════════════════════════════════════════════════
//
// Servicio principal para gestionar el cumplimiento RRSIF/Verifactu
// 
// Funcionalidades:
// - Crear facturas inmutables
// - Obtener siguiente número de registro y hash anterior
// - Calcular hash SHA-256 de facturas (cliente-side backup)
// - Registrar eventos
// - Anular facturas mediante Cloud Function
//
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Modelo de datos para una factura Verifactu
class FacturaVerifactu {
  final String id;
  final String idFactura;
  final DateTime fechaExpedicion;
  final String horaExpedicion;
  final Map<String, dynamic> emisor;
  final Map<String, dynamic>? destinatario;
  final double baseImponible;
  final double tipoIva;
  final double cuotaIva;
  final double totalFactura;
  final String tipoFactura;
  final String hashAnterior;
  final String hashActual;
  final int numeroRegistro;
  final Map<String, dynamic> huellaSystem;
  final Map<String, dynamic> verifactu;
  final Map<String, dynamic> metadata;
  
  FacturaVerifactu({
    required this.id,
    required this.idFactura,
    required this.fechaExpedicion,
    required this.horaExpedicion,
    required this.emisor,
    this.destinatario,
    required this.baseImponible,
    required this.tipoIva,
    required this.cuotaIva,
    required this.totalFactura,
    required this.tipoFactura,
    required this.hashAnterior,
    required this.hashActual,
    required this.numeroRegistro,
    required this.huellaSystem,
    required this.verifactu,
    required this.metadata,
  });
  
  factory FacturaVerifactu.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FacturaVerifactu(
      id: doc.id,
      idFactura: data['id_factura'],
      fechaExpedicion: (data['fecha_expedicion'] as Timestamp).toDate(),
      horaExpedicion: data['hora_expedicion'],
      emisor: data['emisor'],
      destinatario: data['destinatario'],
      baseImponible: (data['base_imponible'] as num).toDouble(),
      tipoIva: (data['tipo_iva'] as num).toDouble(),
      cuotaIva: (data['cuota_iva'] as num).toDouble(),
      totalFactura: (data['total_factura'] as num).toDouble(),
      tipoFactura: data['tipo_factura'],
      hashAnterior: data['hash_anterior'],
      hashActual: data['hash_actual'],
      numeroRegistro: data['numero_registro'],
      huellaSystem: data['huella_sistema'],
      verifactu: data['verifactu'],
      metadata: data['metadata'],
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'id_factura': idFactura,
      'fecha_expedicion': Timestamp.fromDate(fechaExpedicion),
      'hora_expedicion': horaExpedicion,
      'emisor': emisor,
      'destinatario': destinatario,
      'base_imponible': baseImponible,
      'tipo_iva': tipoIva,
      'cuota_iva': cuotaIva,
      'total_factura': totalFactura,
      'tipo_factura': tipoFactura,
      'hash_anterior': hashAnterior,
      'hash_actual': hashActual,
      'numero_registro': numeroRegistro,
      'huella_sistema': huellaSystem,
      'verifactu': verifactu,
      'metadata': metadata,
    };
  }
}

/// Servicio principal de Verifactu
class VerifactuService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  
  // Constantes del fabricante (FLUIX TECH, S.L.)
  static const String FABRICANTE = 'FLUIX TECH, S.L.';
  static const String NIF_FABRICANTE = 'B26997528';
  static const String NOMBRE_SOFTWARE = 'Fluix CRM';
  static const String VERSION_SOFTWARE = '1.0.0';
  
  /// Obtiene el siguiente número de registro y hash anterior para una nueva factura
  Future<Map<String, dynamic>> obtenerDatosNuevaFactura(String empresaId) async {
    debugPrint('🔍 [VERIFACTU] Obteniendo datos para nueva factura empresa: $empresaId');
    
    try {
      // Buscar la última factura de la empresa
      final ultimaFacturaQuery = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('facturas_verifactu')
          .orderBy('numero_registro', descending: true)
          .limit(1)
          .get();
      
      if (ultimaFacturaQuery.docs.isEmpty) {
        // Primera factura de la empresa - iniciar cadena
        debugPrint('✨ [VERIFACTU] Primera factura - inicializando cadena');
        
        return {
          'numero_registro': 1,
          'hash_anterior': '0' * 64, // Hash inicial: 64 ceros
        };
      }
      
      // Obtener datos de la última factura
      final ultimaFactura = ultimaFacturaQuery.docs.first.data();
      final numeroSiguiente = ultimaFactura['numero_registro'] + 1;
      final hashAnterior = ultimaFactura['hash_actual'];
      
      debugPrint('✅ [VERIFACTU] Número siguiente: $numeroSiguiente | Hash anterior disponible');
      
      return {
        'numero_registro': numeroSiguiente,
        'hash_anterior': hashAnterior,
      };
      
    } catch (e, stack) {
      debugPrint('🔴 [VERIFACTU] Error obteniendo datos nueva factura: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }
  
  /// Calcula el hash SHA-256 de una factura según especificación Verifactu
  /// 
  /// Campos que entran en el cálculo (en orden):
  /// 1. NIF Emisor
  /// 2. Número de Factura
  /// 3. Fecha (YYYY-MM-DD)
  /// 4. Hora (HH:MM:SS)
  /// 5. Tipo de Factura
  /// 6. Base Imponible (formato: XX.XX)
  /// 7. Cuota IVA (formato: XX.XX)
  /// 8. Total Factura (formato: XX.XX)
  /// 9. Hash Anterior
  String calcularHashFactura({
    required String nifEmisor,
    required String numeroFactura,
    required DateTime fechaExpedicion,
    required String horaExpedicion,
    required String tipoFactura,
    required double baseImponible,
    required double cuotaIva,
    required double totalFactura,
    required String hashAnterior,
  }) {
    // Formatear fecha como YYYY-MM-DD
    final fechaStr = fechaExpedicion.toIso8601String().split('T')[0];
    
    // Construir cadena canónica
    final cadenaHash = [
      nifEmisor,
      numeroFactura,
      fechaStr,
      horaExpedicion,
      tipoFactura,
      baseImponible.toStringAsFixed(2),
      cuotaIva.toStringAsFixed(2),
      totalFactura.toStringAsFixed(2),
      hashAnterior,
    ].join('|');
    
    debugPrint('🔐 [VERIFACTU] Cadena hash: $cadenaHash');
    
    // Calcular SHA-256
    final bytes = utf8.encode(cadenaHash);
    final digest = sha256.convert(bytes);
    final hash = digest.toString();
    
    debugPrint('✅ [VERIFACTU] Hash calculado: $hash');
    
    return hash;
  }
  
  /// Crea una nueva factura Verifactu
  Future<FacturaVerifactu> crearFactura({
    required String empresaId,
    required String numeroFactura,
    required String serieFactura,
    required Map<String, dynamic> emisor,
    Map<String, dynamic>? destinatario,
    required double baseImponible,
    required double tipoIva,
    required double cuotaIva,
    required double totalFactura,
    required String tipoFactura, // 'F1', 'F2', 'F3'
    String? facturaSustituida,
    String? motivoRectificacion,
    required String usuarioId,
    required String origen, // 'TPV', 'APP', 'WEB'
  }) async {
    debugPrint('💰 [VERIFACTU] ═══ INICIO CREACIÓN FACTURA ═══');
    debugPrint('💰 [VERIFACTU] Empresa: $empresaId | Número: $numeroFactura');
    
    try {
      // 1. Obtener datos para la nueva factura
      final datosNueva = await obtenerDatosNuevaFactura(empresaId);
      final numeroRegistro = datosNueva['numero_registro'] as int;
      final hashAnterior = datosNueva['hash_anterior'] as String;
      
      // 2. Generar ID único para la factura
      final facturaRef = _db
          .collection('empresas')
          .doc(empresaId)
          .collection('facturas_verifactu')
          .doc();
      
      // 3. Obtener datos de la empresa para el número de instalación
      final empresaDoc = await _db.collection('empresas').doc(empresaId).get();
      final empresaData = empresaDoc.data()!;
      
      // Generar número de instalación único (si no existe)
      String numeroInstalacion;
      if (empresaData.containsKey('verifactu_instalacion')) {
        numeroInstalacion = empresaData['verifactu_instalacion'];
      } else {
        numeroInstalacion = 'INST-${empresaId.substring(0, 8)}';
        // Guardar para futuras facturas
        await _db.collection('empresas').doc(empresaId).update({
          'verifactu_instalacion': numeroInstalacion,
        });
      }
      
      // 4. Preparar huella del sistema
      final huellaSystem = {
        'fabricante': FABRICANTE,
        'nombre_software': NOMBRE_SOFTWARE,
        'version': VERSION_SOFTWARE,
        'numero_instalacion': numeroInstalacion,
        'tipo_dispositivo': origen,
        'nif_desarrollador': NIF_FABRICANTE,
      };
      
      // 5. Preparar hora de expedición
      final now = DateTime.now();
      final horaExpedicion = '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';
      
      // 6. Calcular hash de la factura
      final hashActual = calcularHashFactura(
        nifEmisor: emisor['nif'],
        numeroFactura: numeroFactura,
        fechaExpedicion: now,
        horaExpedicion: horaExpedicion,
        tipoFactura: tipoFactura,
        baseImponible: baseImponible,
        cuotaIva: cuotaIva,
        totalFactura: totalFactura,
        hashAnterior: hashAnterior,
      );
      
      // 7. Preparar documento de factura
      final facturaData = FacturaVerifactu(
        id: facturaRef.id,
        idFactura: numeroFactura,
        fechaExpedicion: now,
        horaExpedicion: horaExpedicion,
        emisor: emisor,
        destinatario: destinatario,
        baseImponible: baseImponible,
        tipoIva: tipoIva,
        cuotaIva: cuotaIva,
        totalFactura: totalFactura,
        tipoFactura: tipoFactura,
        hashAnterior: hashAnterior,
        hashActual: hashActual,
        numeroRegistro: numeroRegistro,
        huellaSystem: huellaSystem,
        verifactu: {
          'qr_generado': false, // Se actualiza al generar PDF
          'qr_url': null,
          'enviado_aeat': false,
          'fecha_envio_aeat': null,
          'csv_aeat': null,
          'estado_envio': 'pendiente',
        },
        metadata: {
          'creado_en': FieldValue.serverTimestamp(),
          'creado_por': usuarioId,
          'origen': origen,
          'dispositivo_id': 'flutter-app',
          'anulada': false,
          'fecha_anulacion': null,
          'motivo_anulacion': null,
        },
      );
      
      // 8. Guardar en Firestore
      await facturaRef.set(facturaData.toFirestore());
      
      debugPrint('✅ [VERIFACTU] Factura creada: ${facturaRef.id}');
      debugPrint('✅ [VERIFACTU] Hash: $hashActual');
      debugPrint('✅ [VERIFACTU] Número registro: $numeroRegistro');
      
      // 9. Registrar evento de ALTA
      await registrarEvento(
        empresaId: empresaId,
        tipoEvento: 'ALTA',
        facturaId: facturaRef.id,
        numeroFactura: numeroFactura,
        numeroRegistro: numeroRegistro,
        detalles: {
          'hash_calculado': hashActual,
          'dispositivo': origen,
        },
      );
      
      debugPrint('💰 [VERIFACTU] ═══ FACTURA CREADA EXITOSAMENTE ═══\n');
      
      return facturaData;
      
    } catch (e, stack) {
      debugPrint('🔴 [VERIFACTU] Error creando factura: $e');
      debugPrint('Stack: $stack');
      
      // Registrar evento de error
      try {
        await registrarEvento(
          empresaId: empresaId,
          tipoEvento: 'ERROR',
          facturaId: 'ERROR',
          numeroFactura: numeroFactura,
          detalles: {
            'codigo_error': 'ERR_CREATE_001',
            'mensaje_error': e.toString(),
            'stack_trace': stack.toString(),
          },
        );
      } catch (_) {
        // Ignorar error al registrar evento de error
      }
      
      rethrow;
    }
  }
  
  /// Registra un evento en el sistema Verifactu
  Future<void> registrarEvento({
    required String empresaId,
    required String tipoEvento, // 'ALTA', 'ANULACION', 'ERROR', etc.
    required String facturaId,
    String? numeroFactura,
    int? numeroRegistro,
    required Map<String, dynamic> detalles,
  }) async {
    try {
      await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('eventos_verifactu')
          .add({
        'tipo_evento': tipoEvento,
        'factura_id': facturaId,
        'numero_factura': numeroFactura,
        'numero_registro': numeroRegistro,
        'detalles': detalles,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      debugPrint('📝 [VERIFACTU] Evento $tipoEvento registrado');
    } catch (e) {
      debugPrint('⚠️ [VERIFACTU] Error registrando evento: $e');
      // No lanzar excepción - el evento es secundario
    }
  }
  
  /// Anula una factura creando una rectificativa
  Future<Map<String, dynamic>> anularFactura({
    required String empresaId,
    required String facturaId,
    required String motivo,
  }) async {
    debugPrint('🚫 [VERIFACTU] Anulando factura: $facturaId');
    
    try {
      final callable = _functions.httpsCallable('anularFacturaVerifactu');
      
      final resultado = await callable.call({
        'empresaId': empresaId,
        'facturaId': facturaId,
        'motivo': motivo,
      });
      
      debugPrint('✅ [VERIFACTU] Factura anulada correctamente');
      
      return Map<String, dynamic>.from(resultado.data);
    } catch (e, stack) {
      debugPrint('🔴 [VERIFACTU] Error anulando factura: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }
  
  /// Verifica la integridad de la cadena de hash
  Future<Map<String, dynamic>> verificarIntegridadCadena(String empresaId) async {
    debugPrint('🔍 [VERIFACTU] Verificando integridad cadena empresa: $empresaId');
    
    try {
      final callable = _functions.httpsCallable('verificarIntegridadCadena');
      
      final resultado = await callable.call({
        'empresaId': empresaId,
      });
      
      final data = Map<String, dynamic>.from(resultado.data);
      
      if (data['integridad_ok']) {
        debugPrint('✅ [VERIFACTU] Integridad verificada OK');
      } else {
        debugPrint('⚠️ [VERIFACTU] Errores de integridad encontrados: ${data['errores']}');
      }
      
      return data;
    } catch (e, stack) {
      debugPrint('🔴 [VERIFACTU] Error verificando integridad: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }
  
  /// Obtiene todas las facturas de una empresa
  Stream<List<FacturaVerifactu>> obtenerFacturas(String empresaId) {
    return _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas_verifactu')
        .orderBy('numero_registro', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FacturaVerifactu.fromFirestore(doc))
            .toList());
  }
  
  /// Obtiene una factura específica
  Future<FacturaVerifactu?> obtenerFactura(String empresaId, String facturaId) async {
    final doc = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas_verifactu')
        .doc(facturaId)
        .get();
    
    if (!doc.exists) return null;
    
    return FacturaVerifactu.fromFirestore(doc);
  }
}

