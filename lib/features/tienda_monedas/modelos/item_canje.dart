import 'package:flutter/material.dart';

enum TipoCanje { permanente, duracion, usoUnico }
enum CategoriaItem { identidad, ventajas, gamificacion, social }
enum InputExtra { ninguno, texto, emoji, color }

class ItemCanje {
  final String id;
  final String nombre;
  final String descripcion;
  final String emoji;
  final int costo;
  final TipoCanje tipo;
  final int? duracionDias;
  final int? usos; // para multi-uso (modo_anonimo ×3)
  final CategoriaItem categoria;
  final InputExtra inputExtra;
  final bool esCajaMisteriosa;
  final bool esSiempreComprable; // caja misteriosa, retos: no bloquear si "activo"

  const ItemCanje({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.emoji,
    required this.costo,
    required this.tipo,
    required this.categoria,
    this.duracionDias,
    this.usos,
    this.inputExtra = InputExtra.ninguno,
    this.esCajaMisteriosa = false,
    this.esSiempreComprable = false,
  });

  String get etiquetaDuracion {
    if (esCajaMisteriosa) return '×1 uso';
    return switch (tipo) {
      TipoCanje.permanente => 'Permanente',
      TipoCanje.duracion   => '${duracionDias ?? 30} días',
      TipoCanje.usoUnico   => usos != null ? '×$usos usos' : '×1 uso',
    };
  }
}

extension CategoriaItemX on CategoriaItem {
  String get label => switch (this) {
    CategoriaItem.identidad   => '🎖️ Identidad',
    CategoriaItem.ventajas    => '⚡ Ventajas',
    CategoriaItem.gamificacion=> '🎮 Juego',
    CategoriaItem.social      => '🌐 Social',
  };
  Color get color => switch (this) {
    CategoriaItem.identidad   => const Color(0xFFFFB830),
    CategoriaItem.ventajas    => const Color(0xFF00FFC8),
    CategoriaItem.gamificacion=> const Color(0xFFFF3296),
    CategoriaItem.social      => const Color(0xFF8B5CF6),
  };
}

const kCatalogoCanje = <ItemCanje>[

  // ══════════════════════════════════════════════════════════════════════
  // IDENTIDAD (6 items)
  // ══════════════════════════════════════════════════════════════════════
  ItemCanje(
    id: 'marco_bronce',
    nombre: 'Marco Bronce',
    descripcion: 'Borde bronce alrededor de tu avatar. Visible en tu perfil y en todas las reseñas que publiques.',
    emoji: '🟤',
    costo: 200,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.identidad,
  ),
  ItemCanje(
    id: 'marco_oro',
    nombre: 'Marco Oro',
    descripcion: 'Marco dorado animado con efecto shimmer. Destaca en cada reseña que publiques.',
    emoji: '🥇',
    costo: 500,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.identidad,
  ),
  ItemCanje(
    id: 'marco_platino',
    nombre: 'Marco Platino',
    descripcion: 'El marco más exclusivo. Borde platino brillante con halo de luz. Solo para los más dedicados.',
    emoji: '💎',
    costo: 1000,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.identidad,
  ),
  ItemCanje(
    id: 'titulo_custom',
    nombre: 'Título Personalizado',
    descripcion: 'Un texto libre bajo tu nombre en el perfil y reseñas. Ej: "Amante del café ☕".',
    emoji: '📛',
    costo: 600,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.identidad,
    inputExtra: InputExtra.texto,
  ),
  ItemCanje(
    id: 'color_nombre',
    nombre: 'Color de Nombre',
    descripcion: 'Elige un color exclusivo para tu nombre en todas las reseñas. Cian, rosa, dorado, morado…',
    emoji: '🎨',
    costo: 300,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.identidad,
    inputExtra: InputExtra.color,
  ),
  ItemCanje(
    id: 'avatar_pulsante',
    nombre: 'Avatar Pulsante',
    descripcion: 'Tu avatar emite un halo de luz animado en el perfil y en cada reseña que publiques.',
    emoji: '🎭',
    costo: 350,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.identidad,
  ),

  // ══════════════════════════════════════════════════════════════════════
  // VENTAJAS (4 items)
  // ══════════════════════════════════════════════════════════════════════
  ItemCanje(
    id: 'flash_vip',
    nombre: 'Acceso VIP Flash',
    descripcion: 'Ve y reserva los flash slots 15 minutos antes de que sean visibles para el resto.',
    emoji: '⚡',
    costo: 400,
    tipo: TipoCanje.duracion,
    duracionDias: 30,
    categoria: CategoriaItem.ventajas,
  ),
  ItemCanje(
    id: 'resena_destacada',
    nombre: 'Reseña Destacada',
    descripcion: 'Tu próxima reseña aparece fijada en la posición superior durante 7 días.',
    emoji: '📌',
    costo: 150,
    tipo: TipoCanje.usoUnico,
    categoria: CategoriaItem.ventajas,
  ),
  ItemCanje(
    id: 'prioridad_reserva',
    nombre: 'Prioridad en Reservas',
    descripcion: 'Durante 30 días tus solicitudes en lista de espera suben automáticamente al primer puesto.',
    emoji: '🔝',
    costo: 350,
    tipo: TipoCanje.duracion,
    duracionDias: 30,
    categoria: CategoriaItem.ventajas,
  ),
  ItemCanje(
    id: 'modo_anonimo',
    nombre: 'Modo Anónimo',
    descripcion: 'Publica tus próximas 3 reseñas de forma anónima. Tu nombre aparece como "Anónimo".',
    emoji: '🕵️',
    costo: 200,
    tipo: TipoCanje.usoUnico,
    usos: 3,
    categoria: CategoriaItem.ventajas,
    esSiempreComprable: true,
  ),

  // ══════════════════════════════════════════════════════════════════════
  // GAMIFICACIÓN (5 items)
  // ══════════════════════════════════════════════════════════════════════
  ItemCanje(
    id: 'caja_misteriosa',
    nombre: 'Caja Misteriosa',
    descripcion: 'Gasta 100🪙 y recibe un item aleatorio del catálogo. Puede salir algo que vale 1000🪙… o 150🪙. ¡Suerte!',
    emoji: '🎲',
    costo: 100,
    tipo: TipoCanje.usoUnico,
    categoria: CategoriaItem.gamificacion,
    esCajaMisteriosa: true,
    esSiempreComprable: true,
  ),
  ItemCanje(
    id: 'multiplicador_x2',
    nombre: 'Multiplicador ×2',
    descripcion: 'Durante 7 días ganas el doble de monedas en todos los trofeos que completes.',
    emoji: '✖️',
    costo: 500,
    tipo: TipoCanje.duracion,
    duracionDias: 7,
    categoria: CategoriaItem.gamificacion,
  ),
  ItemCanje(
    id: 'trofeo_coleccionista',
    nombre: 'Trofeo Coleccionista',
    descripcion: 'Un trofeo secreto imposible de ganar de ninguna otra forma. Para los más comprometidos.',
    emoji: '🎴',
    costo: 800,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.gamificacion,
  ),
  ItemCanje(
    id: 'categoria_leyendas',
    nombre: 'Categoría Leyendas',
    descripcion: 'Desbloquea 5 trofeos ocultos de dificultad extrema. Solo visibles para quienes lo canjean.',
    emoji: '🔓',
    costo: 700,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.gamificacion,
  ),
  ItemCanje(
    id: 'retos_exclusivos',
    nombre: 'Retos Exclusivos',
    descripcion: 'Cada semana recibes un reto secreto con recompensa de monedas extra. Solo visible para ti.',
    emoji: '🎯',
    costo: 450,
    tipo: TipoCanje.duracion,
    duracionDias: 30,
    categoria: CategoriaItem.gamificacion,
    esSiempreComprable: true,
  ),

  // ══════════════════════════════════════════════════════════════════════
  // SOCIAL (5 items)
  // ══════════════════════════════════════════════════════════════════════
  ItemCanje(
    id: 'tema_midnight',
    nombre: 'Tema Midnight Blue',
    descripcion: 'Activa una paleta azul noche exclusiva en tu perfil y reseñas. Solo para quienes lo canjean.',
    emoji: '🌙',
    costo: 400,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.social,
  ),
  ItemCanje(
    id: 'firma_personal',
    nombre: 'Firma Personal',
    descripcion: 'Un emoji de tu elección que aparece al final de todas tus reseñas, como una firma única.',
    emoji: '✍️',
    costo: 200,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.social,
    inputExtra: InputExtra.emoji,
  ),
  ItemCanje(
    id: 'perfil_publico',
    nombre: 'Perfil Público',
    descripcion: 'Activa tu perfil público: tus trofeos, nivel y estadísticas son visibles para otros usuarios.',
    emoji: '👤',
    costo: 400,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.social,
  ),
  ItemCanje(
    id: 'animacion_logro',
    nombre: 'Animación de Logro',
    descripcion: 'Confetti y celebración animada cada vez que completas una reserva. Porque los logros merecen festejarse.',
    emoji: '🎊',
    costo: 150,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.social,
  ),
  ItemCanje(
    id: 'vitrina_trofeos',
    nombre: 'Vitrina de Trofeos',
    descripcion: 'Elige 3 trofeos que se muestran destacados y animados en tu perfil. Para lucir tus mejores logros.',
    emoji: '🏆',
    costo: 300,
    tipo: TipoCanje.permanente,
    categoria: CategoriaItem.social,
    inputExtra: InputExtra.texto, // se reutiliza para guardar los 3 IDs separados por coma
  ),
];

/// Items que pueden salir en la Caja Misteriosa (excluye la propia caja y coleccionista/leyendas)
List<ItemCanje> get kItemsCajaMisteriosa => kCatalogoCanje
    .where((i) => !i.esCajaMisteriosa &&
        i.id != 'trofeo_coleccionista' &&
        i.id != 'categoria_leyendas')
    .toList();
