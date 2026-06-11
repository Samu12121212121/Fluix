import 'package:flutter/material.dart';

enum TrofeoCategoria { reservas, resenas, exploracion, fidelidad, especial }

extension TrofeoCategoriaX on TrofeoCategoria {
  String get label {
    switch (this) {
      case TrofeoCategoria.reservas:    return '📅 Reservas';
      case TrofeoCategoria.resenas:     return '⭐ Reseñas';
      case TrofeoCategoria.exploracion: return '🗺️ Exploración';
      case TrofeoCategoria.fidelidad:   return '💎 Fidelidad';
      case TrofeoCategoria.especial:    return '✨ Especial';
    }
  }
  Color get color {
    switch (this) {
      case TrofeoCategoria.reservas:    return const Color(0xFF00FFC8);
      case TrofeoCategoria.resenas:     return const Color(0xFFFFB830);
      case TrofeoCategoria.exploracion: return const Color(0xFF8B5CF6);
      case TrofeoCategoria.fidelidad:   return const Color(0xFFFF3296);
      case TrofeoCategoria.especial:    return const Color(0xFFFF9A3C);
    }
  }
}

class TrofeoDef {
  final String id;
  final String titulo;
  final String descripcion;
  final String emoji;
  final int monedas;
  final TrofeoCategoria categoria;
  final int? meta;
  final bool oculto; // true = solo visible con 'categoria_leyendas' o desde tienda

  const TrofeoDef({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.emoji,
    required this.monedas,
    required this.categoria,
    this.meta,
    this.oculto = false,
  });
}

const List<TrofeoDef> kTrofeos = [
  // ── RESERVAS (15) ──────────────────────────────────────────────────────────
  TrofeoDef(id: 'primera_reserva',      titulo: 'Primera Cita',          descripcion: 'Haz tu primera reserva en la app',                          emoji: '🎉', monedas: 50,   categoria: TrofeoCategoria.reservas, meta: 1),
  TrofeoDef(id: 'tres_reservas',        titulo: 'Trío de Reservas',      descripcion: 'Completa 3 reservas en total',                               emoji: '🔁', monedas: 75,   categoria: TrofeoCategoria.reservas, meta: 3),
  TrofeoDef(id: 'cinco_reservas',       titulo: 'Habitual',              descripcion: 'Llega a 5 reservas completadas',                             emoji: '🌟', monedas: 100,  categoria: TrofeoCategoria.reservas, meta: 5),
  TrofeoDef(id: 'diez_reservas',        titulo: 'Fiel',                  descripcion: '10 reservas completadas',                                    emoji: '🏆', monedas: 200,  categoria: TrofeoCategoria.reservas, meta: 10),
  TrofeoDef(id: 'veinticinco_reservas', titulo: 'Devoto',                descripcion: '25 reservas completadas',                                    emoji: '👑', monedas: 400,  categoria: TrofeoCategoria.reservas, meta: 25),
  TrofeoDef(id: 'cincuenta_reservas',   titulo: 'Leyenda de Reservas',   descripcion: '50 reservas completadas',                                    emoji: '🦸', monedas: 750,  categoria: TrofeoCategoria.reservas, meta: 50),
  TrofeoDef(id: 'flash_primera',        titulo: 'Cazador de Ofertas',    descripcion: 'Reserva tu primer flash slot con descuento',                  emoji: '⚡', monedas: 100,  categoria: TrofeoCategoria.reservas, meta: 1),
  TrofeoDef(id: 'flash_cinco',          titulo: 'Adicto al Flash',       descripcion: 'Consigue 5 reservas flash',                                  emoji: '🔥', monedas: 250,  categoria: TrofeoCategoria.reservas, meta: 5),
  TrofeoDef(id: 'flash_diez',           titulo: 'Rey del Flash',         descripcion: '10 reservas flash completadas',                              emoji: '👸', monedas: 500,  categoria: TrofeoCategoria.reservas, meta: 10),
  TrofeoDef(id: 'reserva_peluqueria',   titulo: 'En Manos de Expertos',  descripcion: 'Primera reserva en una peluquería',                          emoji: '✂️', monedas: 60,   categoria: TrofeoCategoria.reservas),
  TrofeoDef(id: 'reserva_estetica',     titulo: 'Belleza Total',         descripcion: 'Primera reserva en una estética',                            emoji: '💅', monedas: 60,   categoria: TrofeoCategoria.reservas),
  TrofeoDef(id: 'reserva_gimnasio',     titulo: 'Fitness Mode',          descripcion: 'Primera reserva en un gimnasio',                             emoji: '💪', monedas: 60,   categoria: TrofeoCategoria.reservas),
  TrofeoDef(id: 'reserva_restaurante',  titulo: 'Buen Apetito',          descripcion: 'Primera reserva en un restaurante',                          emoji: '🍽️', monedas: 60,   categoria: TrofeoCategoria.reservas),
  TrofeoDef(id: 'reserva_clinica',      titulo: 'Cuidando la Salud',     descripcion: 'Primera reserva en una clínica o centro de salud',           emoji: '🏥', monedas: 60,   categoria: TrofeoCategoria.reservas),
  TrofeoDef(id: 'madrugador',           titulo: 'Madrugador',            descripcion: 'Realiza una reserva antes de las 9:00 de la mañana',         emoji: '🌅', monedas: 80,   categoria: TrofeoCategoria.reservas),

  // ── RESEÑAS (10) ───────────────────────────────────────────────────────────
  TrofeoDef(id: 'primera_resena',       titulo: 'Primera Opinión',       descripcion: 'Deja tu primera reseña en un negocio',                       emoji: '📝', monedas: 75,   categoria: TrofeoCategoria.resenas, meta: 1),
  TrofeoDef(id: 'cinco_resenas',        titulo: 'Crítico',               descripcion: 'Deja 5 reseñas en total',                                    emoji: '🎯', monedas: 150,  categoria: TrofeoCategoria.resenas, meta: 5),
  TrofeoDef(id: 'diez_resenas',         titulo: 'Experto en Opiniones',  descripcion: '10 reseñas publicadas',                                      emoji: '🧐', monedas: 300,  categoria: TrofeoCategoria.resenas, meta: 10),
  TrofeoDef(id: 'veinticinco_resenas',  titulo: 'Influencer',            descripcion: '25 reseñas publicadas en la app',                            emoji: '📣', monedas: 600,  categoria: TrofeoCategoria.resenas, meta: 25),
  TrofeoDef(id: 'resena_cinco_estrellas',titulo: 'Perfeccionista',       descripcion: 'Otorga 5 estrellas en una reseña',                           emoji: '⭐', monedas: 50,   categoria: TrofeoCategoria.resenas),
  TrofeoDef(id: 'resena_detallada',     titulo: 'Detallista',            descripcion: 'Escribe una reseña de más de 100 caracteres',                emoji: '✍️', monedas: 75,   categoria: TrofeoCategoria.resenas),
  TrofeoDef(id: 'resena_respondida',    titulo: 'Diálogo Directo',       descripcion: 'El negocio responde a una de tus reseñas',                   emoji: '💬', monedas: 100,  categoria: TrofeoCategoria.resenas),
  TrofeoDef(id: 'resena_verificada',    titulo: 'Verificado',            descripcion: 'Reserva y reseña el mismo negocio',                          emoji: '✅', monedas: 200,  categoria: TrofeoCategoria.resenas),
  TrofeoDef(id: 'resena_tres_negocios', titulo: 'Crítico Diverso',       descripcion: 'Reseña 3 negocios distintos',                                emoji: '🗣️', monedas: 150,  categoria: TrofeoCategoria.resenas, meta: 3),
  TrofeoDef(id: 'resena_rapida',        titulo: 'Rapidísimo',            descripcion: 'Deja una reseña antes de 1 hora tras tu reserva',            emoji: '⚡', monedas: 150,  categoria: TrofeoCategoria.resenas),

  // ── EXPLORACIÓN (10) ───────────────────────────────────────────────────────
  TrofeoDef(id: 'explorador_dos_cat',   titulo: 'Curioso',               descripcion: 'Reserva en 2 categorías de negocios distintas',              emoji: '🔍', monedas: 80,   categoria: TrofeoCategoria.exploracion, meta: 2),
  TrofeoDef(id: 'explorador_cinco_cat', titulo: 'Explorador',            descripcion: 'Reserva en 5 categorías distintas',                          emoji: '🗺️', monedas: 200,  categoria: TrofeoCategoria.exploracion, meta: 5),
  TrofeoDef(id: 'explorador_todas_cat', titulo: 'Lo Probé Todo',         descripcion: 'Reserva en todas las categorías disponibles',                emoji: '🌍', monedas: 500,  categoria: TrofeoCategoria.exploracion, meta: 9),
  TrofeoDef(id: 'primer_favorito',      titulo: 'Primera Preferencia',   descripcion: 'Guarda tu primer negocio como favorito',                     emoji: '❤️', monedas: 25,   categoria: TrofeoCategoria.exploracion),
  TrofeoDef(id: 'cinco_favoritos',      titulo: 'Coleccionista',         descripcion: 'Guarda 5 negocios en favoritos',                             emoji: '💝', monedas: 75,   categoria: TrofeoCategoria.exploracion, meta: 5),
  TrofeoDef(id: 'diez_favoritos',       titulo: 'Curador',               descripcion: 'Guarda 10 negocios en favoritos',                            emoji: '💎', monedas: 150,  categoria: TrofeoCategoria.exploracion, meta: 10),
  TrofeoDef(id: 'veinticinco_favoritos',titulo: 'Archivador',            descripcion: '25 negocios en tu lista de favoritos',                       emoji: '🗂️', monedas: 300,  categoria: TrofeoCategoria.exploracion, meta: 25),
  TrofeoDef(id: 'reserva_hotel',        titulo: 'Viajero',               descripcion: 'Primera reserva en un hotel o alojamiento',                  emoji: '🏨', monedas: 100,  categoria: TrofeoCategoria.exploracion),
  TrofeoDef(id: 'reserva_tatuaje',      titulo: 'Arte en Piel',          descripcion: 'Primera reserva en un estudio de tatuajes',                  emoji: '🎨', monedas: 80,   categoria: TrofeoCategoria.exploracion),
  TrofeoDef(id: 'cinco_negocios',       titulo: 'Sin Fronteras',         descripcion: 'Reserva en 5 negocios distintos',                            emoji: '🧭', monedas: 150,  categoria: TrofeoCategoria.exploracion, meta: 5),

  // ── FIDELIDAD (10) ─────────────────────────────────────────────────────────
  TrofeoDef(id: 'vip_tres',             titulo: 'Cliente VIP',           descripcion: 'Vuelve al mismo negocio 3 veces',                            emoji: '🥉', monedas: 150,  categoria: TrofeoCategoria.fidelidad, meta: 3),
  TrofeoDef(id: 'vip_cinco',            titulo: 'Habitual de Lujo',      descripcion: '5 visitas al mismo negocio',                                 emoji: '🥈', monedas: 300,  categoria: TrofeoCategoria.fidelidad, meta: 5),
  TrofeoDef(id: 'vip_diez',             titulo: 'Incondicional',         descripcion: '10 visitas al mismo negocio',                                emoji: '🥇', monedas: 600,  categoria: TrofeoCategoria.fidelidad, meta: 10),
  TrofeoDef(id: 'cinco_mes',            titulo: 'Cliente del Mes',       descripcion: '5 reservas en el mismo mes',                                 emoji: '📆', monedas: 200,  categoria: TrofeoCategoria.fidelidad, meta: 5),
  TrofeoDef(id: 'cuatro_semanas',       titulo: 'Mes Completo',          descripcion: 'Reserva en 4 semanas consecutivas',                          emoji: '🗓️', monedas: 300,  categoria: TrofeoCategoria.fidelidad, meta: 4),
  TrofeoDef(id: 'vuelta_rapida',        titulo: 'Con Ganas de Más',      descripcion: 'Vuelve al mismo negocio en menos de 7 días',                 emoji: '🔄', monedas: 100,  categoria: TrofeoCategoria.fidelidad),
  TrofeoDef(id: 'diversidad_mensual',   titulo: 'Todo en Uno',           descripcion: 'Reserva en 3 categorías distintas en un mes',                emoji: '🎭', monedas: 250,  categoria: TrofeoCategoria.fidelidad, meta: 3),
  TrofeoDef(id: 'cliente_veterano',     titulo: 'Veterano',              descripcion: '6 meses como cliente activo',                                emoji: '🎖️', monedas: 500,  categoria: TrofeoCategoria.fidelidad),
  TrofeoDef(id: 'cliente_ano',          titulo: 'Aniversario',           descripcion: '1 año desde tu primera reserva',                             emoji: '🎂', monedas: 1000, categoria: TrofeoCategoria.fidelidad),
  TrofeoDef(id: 'maximo_valorado',      titulo: 'El Más Valorado',       descripcion: 'Reserva en 3 negocios con +4.5 estrellas',                   emoji: '🌠', monedas: 200,  categoria: TrofeoCategoria.fidelidad, meta: 3),

  // ── ESPECIALES (5) ─────────────────────────────────────────────────────────
  TrofeoDef(id: 'bienvenido',           titulo: 'Bienvenido',            descripcion: '¡Bienvenido a la comunidad Fluix!',                          emoji: '🎊', monedas: 10,   categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'perfil_completo',      titulo: 'Perfil Pro',            descripcion: 'Completa tu perfil con nombre, foto y teléfono',             emoji: '🪪', monedas: 100,  categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'mil_monedas',          titulo: 'Primer Tesoro',         descripcion: 'Acumula 1000 monedas en total',                              emoji: '💰', monedas: 500,  categoria: TrofeoCategoria.especial, meta: 1000),
  TrofeoDef(id: 'veinticinco_trofeos',  titulo: 'Coleccionista de Logros',descripcion: 'Completa 25 trofeos',                                       emoji: '🏅', monedas: 750,  categoria: TrofeoCategoria.especial, meta: 25),
  TrofeoDef(id: 'todos_trofeos',        titulo: 'Maestro Absoluto',      descripcion: 'Completa todos los trofeos disponibles',                     emoji: '👑', monedas: 2000, categoria: TrofeoCategoria.especial, meta: 50),

  // ── TIENDA (ocultos — solo desde canje) ───────────────────────────────────
  TrofeoDef(id: 'coleccionista_tienda', titulo: 'El Coleccionista',      descripcion: 'Has canjeado el Trofeo Coleccionista. Un logro imposible de ganar de otra forma.', emoji: '🎴', monedas: 0, categoria: TrofeoCategoria.especial, oculto: true),

  // ── LEYENDAS (ocultos — requieren categoria_leyendas) ─────────────────────
  TrofeoDef(id: 'leyenda_mil',          titulo: 'Mil Visitas',           descripcion: 'Completa 1000 reservas en total. Una hazaña de pocos.',        emoji: '🌌', monedas: 2000, categoria: TrofeoCategoria.especial, meta: 1000, oculto: true),
  TrofeoDef(id: 'leyenda_critico',      titulo: 'Crítico Supremo',       descripcion: 'Publica 100 reseñas verificadas.',                             emoji: '🖊️', monedas: 1500, categoria: TrofeoCategoria.especial, meta: 100,  oculto: true),
  TrofeoDef(id: 'leyenda_fidelidad',    titulo: 'Incondicional Absoluto',descripcion: '50 visitas al mismo negocio.',                                 emoji: '💠', monedas: 2000, categoria: TrofeoCategoria.especial, meta: 50,   oculto: true),
  TrofeoDef(id: 'leyenda_temporada',    titulo: 'Cuatro Estaciones',     descripcion: 'Reserva en los 4 trimestres de un mismo año.',                 emoji: '🍂', monedas: 1500, categoria: TrofeoCategoria.especial, meta: 4,    oculto: true),
  TrofeoDef(id: 'leyenda_explorador',   titulo: 'Sin Límites',           descripcion: 'Reserva en 8 categorías de negocios distintas.',               emoji: '🗺️', monedas: 1000, categoria: TrofeoCategoria.especial, meta: 8,    oculto: true),
];
