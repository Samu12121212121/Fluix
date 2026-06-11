import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/modelos/pdf_template.dart';

/// Servicio de gestión de plantillas PDF en Firestore
class PdfTemplateService {
  final FirebaseFirestore _firestore;
  
  PdfTemplateService([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;
  
  // ── OBTENER PLANTILLAS ────────────────────────────────────────────────────────
  
  /// Obtiene la plantilla asignada para un tipo de documento
  Future<PdfTemplate?> getTemplateForDocument({
    required String empresaId,
    required PdfDocumentType type,
  }) async {
    try {
      final config = await getConfig(empresaId);
      final templateId = config?.assignedTemplates[type];
      
      if (templateId == null) {
        debugPrint('⚠️ No hay plantilla asignada para tipo: ${type.name}');
        return null;
      }
      
      return await getTemplate(empresaId, templateId);
    } catch (e) {
      debugPrint('❌ Error obteniendo plantilla para documento: $e');
      return null;
    }
  }
  
  /// Obtiene una plantilla específica
  Future<PdfTemplate?> getTemplate(String empresaId, String templateId) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('pdf_templates')
          .doc(templateId)
          .get();
      
      if (!doc.exists) {
        return await getSystemTemplate(templateId);
      }
      
      return PdfTemplate.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error obteniendo plantilla $templateId: $e');
      return null;
    }
  }
  
  /// Obtiene una plantilla del sistema (global)
  Future<PdfTemplate?> getSystemTemplate(String templateId) async {
    try {
      final doc = await _firestore
          .collection('pdf_template_system')
          .doc(templateId)
          .get();
      
      if (!doc.exists) return null;
      
      return PdfTemplate.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error obteniendo plantilla sistema $templateId: $e');
      return null;
    }
  }
  
  /// Lista todas las plantillas de una empresa
  Future<List<PdfTemplate>> listTemplates(String empresaId, {
    PdfDocumentType? type,
    bool activeOnly = false,
  }) async {
    try {
      var query = _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('pdf_templates')
          .orderBy('updated_at', descending: true);
      
      if (type != null) {
        query = query.where('type', isEqualTo: type.name) as Query<Map<String, dynamic>>;
      }
      
      if (activeOnly) {
        query = query.where('is_active', isEqualTo: true) as Query<Map<String, dynamic>>;
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => PdfTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error listando plantillas: $e');
      return [];
    }
  }
  
  // ── CREAR Y ACTUALIZAR ────────────────────────────────────────────────────────
  
  /// Crea una nueva plantilla
  Future<String?> createTemplate({
    required String empresaId,
    required PdfTemplate template,
  }) async {
    try {
      final ref = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('pdf_templates')
          .add(template.toMap());
      
      debugPrint('✅ Plantilla creada: ${ref.id}');
      return ref.id;
    } catch (e) {
      debugPrint('❌ Error creando plantilla: $e');
      return null;
    }
  }
  
  /// Actualiza una plantilla existente
  Future<bool> updateTemplate({
    required String empresaId,
    required String templateId,
    required PdfTemplate template,
  }) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('pdf_templates')
          .doc(templateId)
          .update(template.toMap());
      
      debugPrint('✅ Plantilla actualizada: $templateId');
      return true;
    } catch (e) {
      debugPrint('❌ Error actualizando plantilla: $e');
      return false;
    }
  }
  
  /// Elimina una plantilla
  Future<bool> deleteTemplate({
    required String empresaId,
    required String templateId,
  }) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('pdf_templates')
          .doc(templateId)
          .delete();
      
      debugPrint('✅ Plantilla eliminada: $templateId');
      return true;
    } catch (e) {
      debugPrint('❌ Error eliminando plantilla: $e');
      return false;
    }
  }
  
  // ── CONFIGURACIÓN ────────────────────────────────────────────────────────────
  
  /// Obtiene la configuración PDF de una empresa
  Future<PdfConfig?> getConfig(String empresaId) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('pdf_config')
          .doc('config')
          .get();
      
      if (!doc.exists) return null;
      
      return PdfConfig.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error obteniendo config PDF: $e');
      return null;
    }
  }
  
  /// Actualiza la configuración PDF de una empresa
  Future<bool> updateConfig({
    required String empresaId,
    required PdfConfig config,
  }) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('pdf_config')
          .doc('config')
          .set(config.toMap(), SetOptions(merge: true));
      
      debugPrint('✅ Configuración PDF actualizada');
      return true;
    } catch (e) {
      debugPrint('❌ Error actualizando config PDF: $e');
      return false;
    }
  }
  
  /// Asigna una plantilla a un tipo de documento
  Future<bool> assignTemplate({
    required String empresaId,
    required PdfDocumentType type,
    required String templateId,
  }) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('pdf_config')
          .doc('config')
          .set({
        'assigned_templates': {
          type.name: templateId,
        },
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ Plantilla $templateId asignada a ${type.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error asignando plantilla: $e');
      return false;
    }
  }
}

