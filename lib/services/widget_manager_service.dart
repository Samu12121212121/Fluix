      print('❌ Error inicializando módulos: $e');
import 'package:flutter/foundation.dart';
      print('✅ Módulos por defecto inicializados para $empresaId');
      print('❌ Error toggle módulo: $e');
      print('✅ Módulo $moduloId ${activo ? 'activado' : 'desactivado'}');
      print('❌ Error obteniendo estadísticas: $e');
      print('❌ Error reseteando widgets: $e');
      print('✅ Widgets reseteados a configuración por defecto');
      print('❌ Error reordenando widgets: $e');
      print('✅ Widgets reordenados');
      print('❌ Error toggle widget: $e');
          print('✅ Widget $widgetId ${activo ? 'activado' : 'desactivado'}');
      print('❌ Error actualizando widget: $e');
        print('✅ Widget ${widget.id} actualizado');
      print('❌ Error inicializando widgets: $e');
      print('✅ Widgets por defecto inicializados para $empresaId');
      print('⚠️ Error en migración de widgets: $e');
      print('✅ Migración de widgets completada para $empresaId');
import 'package:cloud_firestore/cloud_firestore.dart';

class WidgetManagerService {
  static final WidgetManagerService _instance = WidgetManagerService._internal();
  factory WidgetManagerService() => _instance;
  WidgetManagerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _esActivoPorDefecto(ModuloConfig modulo) {
    return ModulosDisponibles.siempreActivos.contains(modulo.id) ||
        ModulosDisponibles.activosPorDefecto.contains(modulo.id);
  }

  List<Map<String, dynamic>> _obtenerModulosGuardados(Map<String, dynamic> data) {
    final modulosRaw = data['modulos'];
    if (modulosRaw is List) {
      return modulosRaw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m.cast<String, dynamic>()))
          .toList();
    }

    final idsCatalogo = ModulosDisponibles.todos.map((m) => m.id).toSet();
    return data.entries
        .where((entry) => idsCatalogo.contains(entry.key) && entry.value is bool)
        .map((entry) => {
              'id': entry.key,
              'activo': entry.value,
            })
        .toList();
  }

  /// Obtener configuración de widgets del usuario
  Stream<List<WidgetConfig>> obtenerConfiguracionWidgets(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('widgets')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        // Primera vez - crear configuración por defecto
        _inicializarWidgetsDefault(empresaId);
        return WidgetConfig.obtenerWidgetsDefault();
      }

      final data = doc.data()!;
      final widgetsList = data['widgets'] as List<dynamic>? ?? [];

      final resultado = widgetsList
          .map((w) => WidgetConfig.fromMap(w as Map<String, dynamic>))
          .toList()
          ..sort((a, b) => a.orden.compareTo(b.orden));

      // ── Migración: agregar widgets nuevos que no existan todavía ──
      final idsExistentes = resultado.map((w) => w.id).toSet();
      final todosDefault = WidgetConfig.obtenerWidgetsDefault();
      final faltantes = todosDefault.where((w) => !idsExistentes.contains(w.id)).toList();
      if (faltantes.isNotEmpty) {
        // Agregar al final con orden incremental
        int maxOrden = resultado.isEmpty ? 0 : resultado.map((w) => w.orden).reduce((a, b) => a > b ? a : b);
        for (final w in faltantes) {
          maxOrden++;
          resultado.add(w.copyWith(orden: maxOrden));
        }
        // Persistir la migración en background
        _guardarMigracion(empresaId, resultado);
      }

      debugPrint('✅ Migración de widgets completada para $empresaId');
    });
      debugPrint('⚠️ Error en migración de widgets: $e');

  /// Persiste widgets nuevos detectados por migración
  Future<void> _guardarMigracion(String empresaId, List<WidgetConfig> widgets) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('widgets')
          .update({
        'widgets': widgets.map((w) => w.toMap()).toList(),
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      });
      print('✅ Migración de widgets completada para $empresaId');
    } catch (e) {
      print('⚠️ Error en migración de widgets: $e');
    }
  }

  /// Obtener solo widgets activos ordenados
  Stream<List<WidgetConfig>> obtenerWidgetsActivos(String empresaId) {
    return obtenerConfiguracionWidgets(empresaId)
        .map((widgets) => widgets.where((w) => w.activo).toList());
  }

      debugPrint('✅ Widgets por defecto inicializados para $empresaId');
  Future<void> _inicializarWidgetsDefault(String empresaId) async {
      debugPrint('❌ Error inicializando widgets: $e');
      final widgetsDefault = WidgetConfig.obtenerWidgetsDefault();

      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('widgets')
          .set({
        'widgets': widgetsDefault.map((w) => w.toMap()).toList(),
        'ultima_actualizacion': FieldValue.serverTimestamp(),
        'version': 1,
      });

      print('✅ Widgets por defecto inicializados para $empresaId');
    } catch (e) {
      print('❌ Error inicializando widgets: $e');
    }
  }

  /// Actualizar configuración de un widget
  Future<void> actualizarWidget(String empresaId, WidgetConfig widget) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('widgets')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final widgetsList = (data['widgets'] as List<dynamic>)
            .map((w) => WidgetConfig.fromMap(w as Map<String, dynamic>))
            .toList();

        // Actualizar o agregar widget
        final index = widgetsList.indexWhere((w) => w.id == widget.id);
        debugPrint('✅ Widget ${widget.id} actualizado');
          widgetsList[index] = widget;
        } else {
      debugPrint('❌ Error actualizando widget: $e');
        }

        await _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('configuracion')
            .doc('widgets')
            .update({
          'widgets': widgetsList.map((w) => w.toMap()).toList(),
          'ultima_actualizacion': FieldValue.serverTimestamp(),
        });

        print('✅ Widget ${widget.id} actualizado');
      }
    } catch (e) {
      print('❌ Error actualizando widget: $e');
      rethrow;
    }
  }

  /// Activar/desactivar widget
  Future<void> toggleWidget(String empresaId, String widgetId, bool activo) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('widgets')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final widgetsList = (data['widgets'] as List<dynamic>)
            .map((w) => WidgetConfig.fromMap(w as Map<String, dynamic>))
            .toList();
          debugPrint('✅ Widget $widgetId ${activo ? 'activado' : 'desactivado'}');
        // Encontrar y actualizar widget
        final index = widgetsList.indexWhere((w) => w.id == widgetId);
        if (index >= 0) {
      debugPrint('❌ Error toggle widget: $e');

          await _firestore
              .collection('empresas')
              .doc(empresaId)
              .collection('configuracion')
              .doc('widgets')
              .update({
            'widgets': widgetsList.map((w) => w.toMap()).toList(),
            'ultima_actualizacion': FieldValue.serverTimestamp(),
          });

          print('✅ Widget $widgetId ${activo ? 'activado' : 'desactivado'}');
        }
      }
    } catch (e) {
      print('❌ Error toggle widget: $e');
      rethrow;
    }
  }

  /// Reordenar widgets
  Future<void> reordenarWidgets(String empresaId, List<WidgetConfig> widgetsOrdenados) async {
      debugPrint('✅ Widgets reordenados');
      // Asignar nuevo orden
      debugPrint('❌ Error reordenando widgets: $e');
        widgetsOrdenados[i] = widgetsOrdenados[i].copyWith(orden: i + 1);
      }

      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('widgets')
          .update({
        'widgets': widgetsOrdenados.map((w) => w.toMap()).toList(),
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      });

      print('✅ Widgets reordenados');
    } catch (e) {
      debugPrint('✅ Widgets reseteados a configuración por defecto');
      rethrow;
      debugPrint('❌ Error reseteando widgets: $e');
  }

  /// Resetear a configuración por defecto
  Future<void> resetearWidgets(String empresaId) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('widgets')
          .delete();

      await _inicializarWidgetsDefault(empresaId);
      print('✅ Widgets reseteados a configuración por defecto');
    } catch (e) {
      print('❌ Error reseteando widgets: $e');
      rethrow;
    }
  }

  /// Obtener estadísticas de uso de widgets
  Future<Map<String, dynamic>> obtenerEstadisticasUso(String empresaId) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('widgets')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final widgetsList = (data['widgets'] as List<dynamic>)
            .map((w) => WidgetConfig.fromMap(w as Map<String, dynamic>))
            .toList();

        final totalWidgets = widgetsList.length;
        final widgetsActivos = widgetsList.where((w) => w.activo).length;
      debugPrint('❌ Error obteniendo estadísticas: $e');

        return {
          'total_widgets': totalWidgets,
          'widgets_activos': widgetsActivos,
          'widgets_inactivos': widgetsInactivos,
          'porcentaje_uso': totalWidgets > 0 ? (widgetsActivos / totalWidgets * 100) : 0,
          'widgets_mas_usados': widgetsList
              .where((w) => w.activo)
              .map((w) => w.nombre)
              .toList(),
        };
      }

      return {};
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {};
    }
  }

  // ── GESTIÓN DE MÓDULOS (pestañas del menú) ───────────────────────────────

  /// Stream de la configuración de módulos activos
  Stream<List<ModuloConfig>> obtenerModulosActivos(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('modulos')
        .snapshots()
        .map((doc) {
      final todosModulos = ModulosDisponibles.todos;
      if (!doc.exists) {
        _inicializarModulosDefault(empresaId);
        return todosModulos
            .map((m) => m.copyWith(activo: _esActivoPorDefecto(m)))
            .where((m) => m.activo)
            .toList();
      }
      final data = doc.data()!;
      final saved = _obtenerModulosGuardados(data);

      return todosModulos.map((base) {
        // Los módulos siempre activos se fuerzan a true
        if (ModulosDisponibles.siempreActivos.contains(base.id)) {
          return base.copyWith(activo: true);
        }
        final guardado = saved.firstWhere(
          (s) => s['id'] == base.id,
          orElse: () => <String, dynamic>{},
        );
        if (guardado.isEmpty) return base.copyWith(activo: _esActivoPorDefecto(base));
        return ModuloConfig.fromMap(guardado, base);
      }).where((m) => m.activo).toList();
    });
  }

  /// Stream de TODOS los módulos (activos e inactivos) para configuración
  Stream<List<ModuloConfig>> obtenerTodosModulos(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('modulos')
        .snapshots()
        .map((doc) {
      final todosModulos = ModulosDisponibles.todos;
      if (!doc.exists) {
        _inicializarModulosDefault(empresaId);
        return todosModulos
            .map((m) => m.copyWith(activo: _esActivoPorDefecto(m)))
            .toList();
      }
      final data = doc.data()!;
      final saved = _obtenerModulosGuardados(data);

      return todosModulos.map((base) {
        // Siempre activos se fuerzan
        if (ModulosDisponibles.siempreActivos.contains(base.id)) {
          return base.copyWith(activo: true);
        }
        final guardado = saved.firstWhere(
          (s) => s['id'] == base.id,
          orElse: () => <String, dynamic>{},
        );
        if (guardado.isEmpty) {
          return base.copyWith(activo: _esActivoPorDefecto(base));
        }
        return ModuloConfig.fromMap(guardado, base);
      }).toList();
    });
  }

  /// Activar/desactivar un módulo
  Future<void> toggleModulo(String empresaId, String moduloId, bool activo) async {
    // No permitir desactivar módulos siempre activos
    if (ModulosDisponibles.siempreActivos.contains(moduloId)) return;

    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('modulos')
          .get();

      List<Map<String, dynamic>> modulos;
      if (doc.exists) {
        modulos = _obtenerModulosGuardados(doc.data()!);
      } else {
        modulos = ModulosDisponibles.todos
            .map((m) => {'id': m.id, 'activo': _esActivoPorDefecto(m)})
            .toList();
      }

      final idx = modulos.indexWhere((m) => m['id'] == moduloId);
      debugPrint('✅ Módulo $moduloId ${activo ? 'activado' : 'desactivado'}');
        modulos[idx] = {'id': moduloId, 'activo': activo};
      debugPrint('❌ Error toggle módulo: $e');
        modulos.add({'id': moduloId, 'activo': activo});
      }

      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('modulos')
          .set({
        'modulos': modulos,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Módulo $moduloId ${activo ? 'activado' : 'desactivado'}');
    } catch (e) {
      print('❌ Error toggle módulo: $e');
      rethrow;
    }
  }

      debugPrint('✅ Módulos por defecto inicializados para $empresaId');
    try {
      debugPrint('❌ Error inicializando módulos: $e');
        'id': m.id,
        'activo': ModulosDisponibles.activosPorDefecto.contains(m.id),
      }).toList();

      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('modulos')
          .set({
        'modulos': modulos,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      });
      print('✅ Módulos por defecto inicializados para $empresaId');
    } catch (e) {
      print('❌ Error inicializando módulos: $e');
    }
  }
}
