import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/domain/modelos/widget_config.dart';

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

  // ── GESTIÓN DE WIDGETS ─────────────────────────────────────────────────────

  Stream<List<WidgetConfig>> obtenerConfiguracionWidgets(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('widgets')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        _inicializarWidgetsDefault(empresaId);
        return WidgetConfig.obtenerWidgetsDefault();
      }

      final data = doc.data();
      if (data == null) return WidgetConfig.obtenerWidgetsDefault();

      final widgetsList = data['widgets'] as List<dynamic>?;

      if (widgetsList == null || widgetsList.isEmpty) {
        return WidgetConfig.obtenerWidgetsDefault();
      }

      final resultado = widgetsList
          .whereType<Map>()
          .map((w) => WidgetConfig.fromMap(Map<String, dynamic>.from(w)))
          .toList();

      final idsExistentes = resultado.map((w) => w.id).toSet();
      final todosDefault = WidgetConfig.obtenerWidgetsDefault();

      final faltantes =
      todosDefault.where((w) => !idsExistentes.contains(w.id)).toList();

      if (faltantes.isNotEmpty) {
        int maxOrden = resultado.isEmpty
            ? 0
            : resultado.map((w) => w.orden).reduce((a, b) => a > b ? a : b);

        for (final w in faltantes) {
          maxOrden++;
          resultado.add(w.copyWith(orden: maxOrden));
        }

        _guardarMigracion(empresaId, resultado);
      }

      debugPrint('✅ Migración de widgets completada para $empresaId');
      return resultado;
    }).handleError((e) {
      debugPrint('⚠️ Error en migración de widgets: $e');
      return <WidgetConfig>[];
    });
  }

  Future<void> _guardarMigracion(
      String empresaId, List<WidgetConfig> widgets) async {
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
    } catch (e) {
      debugPrint('⚠️ Error en migración de widgets: $e');
    }
  }

  Stream<List<WidgetConfig>> obtenerWidgetsActivos(String empresaId) {
    return obtenerConfiguracionWidgets(empresaId)
        .map((widgets) => widgets.where((w) => w.activo).toList());
  }

  Future<void> _inicializarWidgetsDefault(String empresaId) async {
    try {
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

      debugPrint('✅ Widgets por defecto inicializados para $empresaId');
    } catch (e) {
      debugPrint('❌ Error inicializando widgets: $e');
    }
  }

  Future<void> actualizarWidget(
      String empresaId, WidgetConfig widget) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('widgets')
          .get();

      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      final widgetsList = (data['widgets'] as List<dynamic>?)
          ?.whereType<Map>()
          .map((w) =>
          WidgetConfig.fromMap(Map<String, dynamic>.from(w)))
          .toList() ??
          [];

      final index = widgetsList.indexWhere((w) => w.id == widget.id);

      if (index >= 0) {
        widgetsList[index] = widget;

        await _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('configuracion')
            .doc('widgets')
            .update({
          'widgets': widgetsList.map((w) => w.toMap()).toList(),
          'ultima_actualizacion': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('❌ Error actualizando widget: $e');
      rethrow;
    }
  }

  Future<void> toggleWidget(
      String empresaId, String widgetId, bool activo) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('widgets')
          .get();

      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      final widgetsList = (data['widgets'] as List<dynamic>?)
          ?.whereType<Map>()
          .map((w) =>
          WidgetConfig.fromMap(Map<String, dynamic>.from(w)))
          .toList() ??
          [];

      final index = widgetsList.indexWhere((w) => w.id == widgetId);

      if (index >= 0) {
        widgetsList[index] =
            widgetsList[index].copyWith(activo: activo);

        await _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('configuracion')
            .doc('widgets')
            .update({
          'widgets': widgetsList.map((w) => w.toMap()).toList(),
          'ultima_actualizacion': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('❌ Error toggle widget: $e');
      rethrow;
    }
  }

  Future<void> reordenarWidgets(
      String empresaId, List<WidgetConfig> widgetsOrdenados) async {
    try {
      for (var i = 0; i < widgetsOrdenados.length; i++) {
        widgetsOrdenados[i] =
            widgetsOrdenados[i].copyWith(orden: i + 1);
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
    } catch (e) {
      debugPrint('❌ Error reordenando widgets: $e');
      rethrow;
    }
  }

  Future<void> resetearWidgets(String empresaId) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('widgets')
          .delete();

      await _inicializarWidgetsDefault(empresaId);
    } catch (e) {
      debugPrint('❌ Error reseteando widgets: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> obtenerEstadisticasUso(
      String empresaId) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('widgets')
          .get();

      if (!doc.exists) return {};

      final data = doc.data();
      if (data == null) return {};

      final widgetsList = (data['widgets'] as List<dynamic>?)
          ?.whereType<Map>()
          .map((w) =>
          WidgetConfig.fromMap(Map<String, dynamic>.from(w)))
          .toList() ??
          [];

      final totalWidgets = widgetsList.length;
      final widgetsActivos =
          widgetsList.where((w) => w.activo).length;

      return {
        'total_widgets': totalWidgets,
        'widgets_activos': widgetsActivos,
        'widgets_inactivos': totalWidgets - widgetsActivos,
        'porcentaje_uso': totalWidgets > 0
            ? (widgetsActivos / totalWidgets * 100)
            : 0,
        'widgets_mas_usados': widgetsList
            .where((w) => w.activo)
            .map((w) => w.nombre)
            .toList(),
      };
    } catch (e) {
      debugPrint('❌ Error obteniendo estadísticas: $e');
      return {};
    }
  }

  // ── MÓDULOS ───────────────────────────────────────────────────────────────

  Stream<List<ModuloConfig>> obtenerModulosActivos(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('modulos')
        .snapshots()
        .map((doc) {
      try {
        final todosModulos = ModulosDisponibles.todos;

        if (!doc.exists) {
          _inicializarModulosDefault(empresaId);
          return todosModulos
              .map((m) => m.copyWith(activo: _esActivoPorDefecto(m)))
              .where((m) => m.activo)
              .toList();
        }

        final data = doc.data();
        if (data == null) return [];

        final saved = _obtenerModulosGuardados(data);

        return todosModulos.map((base) {
          final guardado = saved.firstWhere(
                  (s) => s['id'] == base.id,
              orElse: () => <String, dynamic>{});

          final activo = guardado['activo'] as bool? ??
              _esActivoPorDefecto(base);

          return base.copyWith(activo: activo);
        }).where((m) => m.activo).toList();
      } catch (e) {
        debugPrint('❌ ERROR modulos activos: $e');
        return <ModuloConfig>[];
      }
    });
  }

  Stream<List<ModuloConfig>> obtenerTodosModulos(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('modulos')
        .snapshots()
        .map((doc) {
      try {
        final todosModulos = ModulosDisponibles.todos;

        if (!doc.exists) {
          _inicializarModulosDefault(empresaId);
          return todosModulos;
        }

        final data = doc.data();
        if (data == null) return todosModulos;

        final saved = _obtenerModulosGuardados(data);

        return todosModulos.map((base) {
          final guardado = saved.firstWhere(
                  (s) => s['id'] == base.id,
              orElse: () => <String, dynamic>{});

          final activo = guardado['activo'] as bool? ??
              _esActivoPorDefecto(base);

          return base.copyWith(activo: activo);
        }).toList();
      } catch (e) {
        debugPrint('❌ ERROR todos modulos: $e');
        return ModulosDisponibles.todos;
      }
    });
  }

  Future<void> toggleModulo(
      String empresaId, String moduloId, bool activo) async {
    try {
      final doc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('modulos')
          .get();

      List<Map<String, dynamic>> modulos;

      if (doc.exists && doc.data() != null) {
        modulos = _obtenerModulosGuardados(doc.data()!);
      } else {
        modulos = ModulosDisponibles.todos
            .map((m) => {'id': m.id, 'activo': false})
            .toList();
      }

      final idx = modulos.indexWhere((m) => m['id'] == moduloId);

      if (idx >= 0) {
        modulos[idx]['activo'] = activo;
      } else {
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
    } catch (e) {
      debugPrint('❌ Error toggle modulo: $e');
      rethrow;
    }
  }

  Future<void> _inicializarModulosDefault(String empresaId) async {
    try {
      final modulos = ModulosDisponibles.todos
          .map((m) => {
        'id': m.id,
        'activo':
        ModulosDisponibles.activosPorDefecto.contains(m.id),
      })
          .toList();

      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('modulos')
          .set({
        'modulos': modulos,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error init modulos: $e');
    }
  }
}