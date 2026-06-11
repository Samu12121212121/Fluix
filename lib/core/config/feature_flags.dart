/// Feature flags para activar/desactivar funcionalidades nuevas.
/// 
/// Permite rollback inmediato sin recompilar (cambiar a `false`).
class FeatureFlags {
  /// ── FASE 1: ESTABILIZACIÓN ──────────────────────────────────────────
  
  /// Usa configuración de Firestore específica por plataforma
  /// (caché limitada en Windows).
  static const bool USE_PLATFORM_AWARE_FIRESTORE = true;
  
  /// Usa SafeStreamMixin para auto-cancelación de streams.
  static const bool USE_SAFE_STREAM_MIXIN = true;
  
  /// ── FASE 2: REPOSITORY PATTERN (próximamente) ──────────────────────
  
  /// Usa Repository Pattern en lugar de acceso directo a Firestore.
  static const bool USE_REPOSITORY_PATTERN = false;
  
  /// Usa polling en Windows en lugar de realtime streams.
  static const bool USE_WINDOWS_POLLING = false;
  
  /// ── FASE 3: OPTIMIZACIONES (próximamente) ──────────────────────────
  
  /// Usa cache local como primera fuente de datos.
  static const bool USE_CACHE_FIRST = false;
  
  /// Usa smart polling con prioridades diferenciadas.
  static const bool USE_SMART_POLLING = false;
  
  /// Usa dependency injection con GetIt.
  static const bool USE_DI = false;
}

