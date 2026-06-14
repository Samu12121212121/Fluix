import 'package:flutter/material.dart';

enum TrofeoTier { bronce, plata, oro, platino }

extension TrofeoTierX on TrofeoTier {
  String get label {
    switch (this) {
      case TrofeoTier.bronce:  return 'Bronce';
      case TrofeoTier.plata:   return 'Plata';
      case TrofeoTier.oro:     return 'Oro';
      case TrofeoTier.platino: return 'Platino';
    }
  }
  Color get color {
    switch (this) {
      case TrofeoTier.bronce:  return const Color(0xFFCD7F32);
      case TrofeoTier.plata:   return const Color(0xFFC0C0C0);
      case TrofeoTier.oro:     return const Color(0xFFFFD700);
      case TrofeoTier.platino: return const Color(0xFFE5E4E2);
    }
  }
  String get emoji {
    switch (this) {
      case TrofeoTier.bronce:  return '🥉';
      case TrofeoTier.plata:   return '🥈';
      case TrofeoTier.oro:     return '🥇';
      case TrofeoTier.platino: return '💎';
    }
  }
}

enum TrofeoCategoria { reservas, resenas, exploracion, fidelidad, especial, puntualidad, social }

extension TrofeoCategoriaX on TrofeoCategoria {
  String get label {
    switch (this) {
      case TrofeoCategoria.reservas:    return '📅 Reservas';
      case TrofeoCategoria.resenas:     return '⭐ Reseñas';
      case TrofeoCategoria.exploracion: return '🗺️ Exploración';
      case TrofeoCategoria.fidelidad:   return '💎 Fidelidad';
      case TrofeoCategoria.especial:    return '✨ Especial';
      case TrofeoCategoria.puntualidad: return '⏰ Puntualidad';
      case TrofeoCategoria.social:      return '🤝 Social';
    }
  }
  Color get color {
    switch (this) {
      case TrofeoCategoria.reservas:    return const Color(0xFF00FFC8);
      case TrofeoCategoria.resenas:     return const Color(0xFFFFB830);
      case TrofeoCategoria.exploracion: return const Color(0xFF8B5CF6);
      case TrofeoCategoria.fidelidad:   return const Color(0xFFFF3296);
      case TrofeoCategoria.especial:    return const Color(0xFFFF9A3C);
      case TrofeoCategoria.puntualidad: return const Color(0xFF4FC3F7);
      case TrofeoCategoria.social:      return const Color(0xFF81C784);
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
  final TrofeoTier tier;
  final int? meta;
  final bool oculto;

  const TrofeoDef({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.emoji,
    required this.monedas,
    required this.categoria,
    this.tier = TrofeoTier.bronce,
    this.meta,
    this.oculto = false,
  });
}

const List<TrofeoDef> kTrofeos = [
  // ── RESERVAS (15) ──────────────────────────────────────────────────────────
  TrofeoDef(id: 'primera_reserva',       titulo: 'Primera Cita',            descripcion: 'Haz tu primera reserva en la app',                          emoji: '🎉', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.reservas,    meta: 1),
  TrofeoDef(id: 'tres_reservas',         titulo: 'Trío de Reservas',        descripcion: 'Completa 3 reservas en total',                               emoji: '🔁', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.reservas,    meta: 3),
  TrofeoDef(id: 'cinco_reservas',        titulo: 'Habitual',                descripcion: 'Llega a 5 reservas completadas',                             emoji: '🌟', monedas: 10,  tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.reservas,    meta: 5),
  TrofeoDef(id: 'diez_reservas',         titulo: 'Fiel',                    descripcion: '10 reservas completadas',                                    emoji: '🏆', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.reservas,    meta: 10),
  TrofeoDef(id: 'veinticinco_reservas',  titulo: 'Devoto',                  descripcion: '25 reservas completadas',                                    emoji: '👑', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.reservas,    meta: 25),
  TrofeoDef(id: 'cincuenta_reservas',    titulo: 'Leyenda de Reservas',     descripcion: '50 reservas completadas',                                    emoji: '🦸', monedas: 50,  tier: TrofeoTier.oro,     categoria: TrofeoCategoria.reservas,    meta: 50),
  TrofeoDef(id: 'flash_primera',         titulo: 'Cazador de Ofertas',      descripcion: 'Reserva tu primer flash slot con descuento',                  emoji: '⚡', monedas: 10,  tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.reservas,    meta: 1),
  TrofeoDef(id: 'flash_cinco',           titulo: 'Adicto al Flash',         descripcion: 'Consigue 5 reservas flash',                                  emoji: '🔥', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.reservas,    meta: 5),
  TrofeoDef(id: 'flash_diez',            titulo: 'Rey del Flash',           descripcion: '10 reservas flash completadas',                              emoji: '👸', monedas: 50,  tier: TrofeoTier.oro,     categoria: TrofeoCategoria.reservas,    meta: 10),
  TrofeoDef(id: 'reserva_peluqueria',    titulo: 'En Manos de Expertos',    descripcion: 'Primera reserva en una peluquería',                          emoji: '✂️', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.reservas),
  TrofeoDef(id: 'reserva_estetica',      titulo: 'Belleza Total',           descripcion: 'Primera reserva en una estética',                            emoji: '💅', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.reservas),
  TrofeoDef(id: 'reserva_gimnasio',      titulo: 'Fitness Mode',            descripcion: 'Primera reserva en un gimnasio',                             emoji: '💪', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.reservas),
  TrofeoDef(id: 'reserva_restaurante',   titulo: 'Buen Apetito',            descripcion: 'Primera reserva en un restaurante',                          emoji: '🍽️', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.reservas),
  TrofeoDef(id: 'reserva_clinica',       titulo: 'Cuidando la Salud',       descripcion: 'Primera reserva en una clínica o centro de salud',           emoji: '🏥', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.reservas),
  TrofeoDef(id: 'madrugador',            titulo: 'Madrugador',              descripcion: 'Reserva antes de las 9:00 de la mañana',                     emoji: '🌅', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.reservas),

  // ── RESEÑAS (10) ───────────────────────────────────────────────────────────
  TrofeoDef(id: 'primera_resena',        titulo: 'Primera Opinión',         descripcion: 'Deja tu primera reseña en un negocio',                       emoji: '📝', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.resenas,     meta: 1),
  TrofeoDef(id: 'cinco_resenas',         titulo: 'Crítico',                 descripcion: 'Deja 5 reseñas en total',                                    emoji: '🎯', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.resenas,     meta: 5),
  TrofeoDef(id: 'diez_resenas',          titulo: 'Experto en Opiniones',    descripcion: '10 reseñas publicadas',                                      emoji: '🧐', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.resenas,     meta: 10),
  TrofeoDef(id: 'veinticinco_resenas',   titulo: 'Influencer',              descripcion: '25 reseñas publicadas en la app',                            emoji: '📣', monedas: 50,  tier: TrofeoTier.oro,     categoria: TrofeoCategoria.resenas,     meta: 25),
  TrofeoDef(id: 'resena_cinco_estrellas',titulo: 'Perfeccionista',          descripcion: 'Otorga 5 estrellas en una reseña',                           emoji: '⭐', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.resenas),
  TrofeoDef(id: 'resena_detallada',      titulo: 'Detallista',              descripcion: 'Escribe una reseña de más de 100 caracteres',                emoji: '✍️', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.resenas),
  TrofeoDef(id: 'resena_respondida',     titulo: 'Diálogo Directo',         descripcion: 'El negocio responde a una de tus reseñas',                   emoji: '💬', monedas: 10,  tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.resenas),
  TrofeoDef(id: 'resena_verificada',     titulo: 'Verificado',              descripcion: 'Reserva y reseña el mismo negocio',                          emoji: '✅', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.resenas),
  TrofeoDef(id: 'resena_tres_negocios',  titulo: 'Crítico Diverso',         descripcion: 'Reseña 3 negocios distintos',                                emoji: '🗣️', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.resenas,     meta: 3),
  TrofeoDef(id: 'resena_rapida',         titulo: 'Rapidísimo',              descripcion: 'Deja una reseña antes de 1 hora tras tu reserva',            emoji: '⚡', monedas: 10,  tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.resenas),

  // ── EXPLORACIÓN (10) ───────────────────────────────────────────────────────
  TrofeoDef(id: 'explorador_dos_cat',    titulo: 'Curioso',                 descripcion: 'Reserva en 2 categorías de negocios distintas',              emoji: '🔍', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.exploracion, meta: 2),
  TrofeoDef(id: 'explorador_cinco_cat',  titulo: 'Explorador',              descripcion: 'Reserva en 5 categorías distintas',                          emoji: '🗺️', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.exploracion, meta: 5),
  TrofeoDef(id: 'explorador_todas_cat',  titulo: 'Lo Probé Todo',           descripcion: 'Reserva en todas las categorías disponibles',                emoji: '🌍', monedas: 50,  tier: TrofeoTier.oro,     categoria: TrofeoCategoria.exploracion, meta: 9),
  TrofeoDef(id: 'primer_favorito',       titulo: 'Primera Preferencia',     descripcion: 'Guarda tu primer negocio como favorito',                     emoji: '❤️', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.exploracion),
  TrofeoDef(id: 'cinco_favoritos',       titulo: 'Coleccionista',           descripcion: 'Guarda 5 negocios en favoritos',                             emoji: '💝', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.exploracion, meta: 5),
  TrofeoDef(id: 'diez_favoritos',        titulo: 'Curador',                 descripcion: 'Guarda 10 negocios en favoritos',                            emoji: '💎', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.exploracion, meta: 10),
  TrofeoDef(id: 'veinticinco_favoritos', titulo: 'Archivador',              descripcion: '25 negocios en tu lista de favoritos',                       emoji: '🗂️', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.exploracion, meta: 25),
  TrofeoDef(id: 'reserva_hotel',         titulo: 'Viajero',                 descripcion: 'Primera reserva en un hotel o alojamiento',                  emoji: '🏨', monedas: 10,  tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.exploracion),
  TrofeoDef(id: 'reserva_tatuaje',       titulo: 'Arte en Piel',            descripcion: 'Primera reserva en un estudio de tatuajes',                  emoji: '🎨', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.exploracion),
  TrofeoDef(id: 'cinco_negocios',        titulo: 'Sin Fronteras',           descripcion: 'Reserva en 5 negocios distintos',                            emoji: '🧭', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.exploracion, meta: 5),

  // ── FIDELIDAD (10 base) ────────────────────────────────────────────────────
  TrofeoDef(id: 'vip_tres',              titulo: 'Cliente VIP',             descripcion: 'Vuelve al mismo negocio 3 veces',                            emoji: '🥉', monedas: 10,  tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.fidelidad,   meta: 3),
  TrofeoDef(id: 'vip_cinco',             titulo: 'Habitual de Lujo',        descripcion: '5 visitas al mismo negocio',                                 emoji: '🥈', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.fidelidad,   meta: 5),
  TrofeoDef(id: 'vip_diez',              titulo: 'Incondicional',           descripcion: '10 visitas al mismo negocio',                                emoji: '🥇', monedas: 50,  tier: TrofeoTier.oro,     categoria: TrofeoCategoria.fidelidad,   meta: 10),
  TrofeoDef(id: 'cinco_mes',             titulo: 'Cliente del Mes',         descripcion: '5 reservas en el mismo mes',                                 emoji: '📆', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.fidelidad,   meta: 5),
  TrofeoDef(id: 'cuatro_semanas',        titulo: 'Mes Completo',            descripcion: 'Reserva en 4 semanas consecutivas',                          emoji: '🗓️', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.fidelidad,   meta: 4),
  TrofeoDef(id: 'vuelta_rapida',         titulo: 'Con Ganas de Más',        descripcion: 'Vuelve al mismo negocio en menos de 7 días',                 emoji: '🔄', monedas: 10,  tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.fidelidad),
  TrofeoDef(id: 'diversidad_mensual',    titulo: 'Todo en Uno',             descripcion: 'Reserva en 3 categorías distintas en un mes',                emoji: '🎭', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.fidelidad,   meta: 3),
  TrofeoDef(id: 'cliente_veterano',      titulo: 'Veterano',                descripcion: '6 meses como cliente activo',                                emoji: '🎖️', monedas: 50,  tier: TrofeoTier.oro,     categoria: TrofeoCategoria.fidelidad),
  TrofeoDef(id: 'cliente_ano',           titulo: 'Aniversario',             descripcion: '1 año desde tu primera reserva',                             emoji: '🎂', monedas: 50, tier: TrofeoTier.oro,     categoria: TrofeoCategoria.fidelidad),
  TrofeoDef(id: 'maximo_valorado',       titulo: 'El Más Valorado',         descripcion: 'Reserva en 3 negocios con +4.5 estrellas',                   emoji: '🌠', monedas: 20,  tier: TrofeoTier.plata,   categoria: TrofeoCategoria.fidelidad,   meta: 3),

  // ── FIDELIDAD AMPLIADA ─────────────────────────────────────────────────────
  TrofeoDef(id: 'noctambulo',            titulo: 'Noctámbulo',              descripcion: '5 citas en turno tarde-noche (después de las 20:00)',         emoji: '🌙', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.fidelidad,   meta: 5),
  TrofeoDef(id: 'ritual_semanal',        titulo: 'Ritual Semanal',          descripcion: 'El mismo día de la semana durante 8 semanas seguidas',        emoji: '🔮', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.fidelidad,   meta: 8),
  TrofeoDef(id: 'siempre_vuelves',       titulo: 'Siempre Vuelves',         descripcion: 'Reservas tras haber cancelado una cita anterior',             emoji: '💫', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.fidelidad),
  TrofeoDef(id: 'racha_tres_meses',      titulo: 'Racha de 3 Meses',        descripcion: 'Al menos una cita mensual durante 3 meses seguidos',          emoji: '📈', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.fidelidad,   meta: 3),
  TrofeoDef(id: 'fan_numero_uno',        titulo: 'Fan Número 1',            descripcion: 'El cliente más frecuente del mes en un negocio',              emoji: '🌟', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.fidelidad),

  // ── SOCIAL ─────────────────────────────────────────────────────────────────
  TrofeoDef(id: 'el_que_invita',         titulo: 'El que Invita',           descripcion: 'Tu primer amigo referido se registra en Fluix',               emoji: '🤝', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.social),
  TrofeoDef(id: 'conector',              titulo: 'Conector',                descripcion: '3 amigos referidos que completan una cita',                   emoji: '🔗', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.social,      meta: 3),
  TrofeoDef(id: 'influencer_barrial',    titulo: 'Influencer Barrial',      descripcion: '10 referidos activos en Fluix',                               emoji: '📡', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.social,      meta: 10),
  TrofeoDef(id: 'compartidor',           titulo: 'Compartidor',             descripcion: 'Compartes una experiencia desde la app',                      emoji: '📤', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.social),
  TrofeoDef(id: 'buena_onda',            titulo: 'Buena Onda',              descripcion: 'Envías un mensaje de agradecimiento al profesional',           emoji: '💌', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.social),
  TrofeoDef(id: 'generoso',              titulo: 'Generoso',                descripcion: 'Envías una cita como regalo a otra persona',                  emoji: '🎁', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.social),

  // ── EXPLORADOR AMPLIADO ────────────────────────────────────────────────────
  TrofeoDef(id: 'amante_del_estilo',     titulo: 'Amante del Estilo',       descripcion: '3 servicios distintos en una peluquería',                     emoji: '💈', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.exploracion, meta: 3),
  TrofeoDef(id: 'nuevo_servicio',        titulo: 'Nuevo Servicio',          descripcion: 'Pruebas un servicio que no habías reservado antes',            emoji: '🆕', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.exploracion),

  // ── PUNTUALIDAD ────────────────────────────────────────────────────────────
  TrofeoDef(id: 'puntual',               titulo: 'Puntual',                 descripcion: 'Primera cita sin ningún retraso',                             emoji: '⏰', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.puntualidad),
  TrofeoDef(id: 'reloj_suizo',           titulo: 'Reloj Suizo',             descripcion: '10 citas sin retrasos ni cancelaciones',                      emoji: '⌚', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.puntualidad, meta: 10),
  TrofeoDef(id: 'perfecto_25',           titulo: 'Perfecto 25',             descripcion: '25 citas sin ninguna cancelación',                            emoji: '🎯', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.puntualidad, meta: 25),
  TrofeoDef(id: 'precavido',             titulo: 'Precavido',               descripcion: 'Confirmas 5 citas con más de 24h de antelación',              emoji: '🛡️', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.puntualidad, meta: 5),
  TrofeoDef(id: 'planificador',          titulo: 'Planificador',            descripcion: 'Reservas con más de 1 semana de antelación 5 veces',          emoji: '📋', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.puntualidad, meta: 5),

  // ── ESPECIALES base ────────────────────────────────────────────────────────
  TrofeoDef(id: 'bienvenido',            titulo: 'Bienvenido',              descripcion: '¡Bienvenido a la comunidad Fluix!',                          emoji: '🎊', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'perfil_completo',       titulo: 'Perfil Pro',              descripcion: 'Completa tu perfil con nombre, foto y teléfono',             emoji: '🪪', monedas: 10,  tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'con_cara',              titulo: 'Con Cara',                descripcion: 'Subes una foto de perfil',                                    emoji: '🤳', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'conectado',             titulo: 'Conectado',               descripcion: 'Activas las notificaciones push',                             emoji: '🔔', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'bio_completa',          titulo: 'Bio Completa',            descripcion: 'Escribes una bio en tu perfil',                               emoji: '✏️', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'veterano_plataforma',   titulo: 'Veterano de Plataforma',  descripcion: '2 años usando Fluix',                                         emoji: '🏛️', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'mil_monedas',           titulo: 'Primer Tesoro',           descripcion: 'Acumula 1000 monedas en total',                               emoji: '💰', monedas: 50,  tier: TrofeoTier.oro,     categoria: TrofeoCategoria.especial,    meta: 1000),
  TrofeoDef(id: 'veinticinco_trofeos',   titulo: 'Coleccionista de Logros', descripcion: 'Completa 25 trofeos',                                        emoji: '🏅', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial,    meta: 25),
  TrofeoDef(id: 'todos_trofeos',         titulo: 'Maestro Absoluto',        descripcion: 'Completa 100 trofeos',                                       emoji: '👑', monedas: 150, tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial,    meta: 100),
  TrofeoDef(id: 'cumpleanero',           titulo: 'Cumpleañero',             descripcion: 'Reservas una cita el día de tu cumpleaños',                   emoji: '🎂', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'navidad_salon',         titulo: 'Navidad en el Salón',     descripcion: 'Cita en diciembre 3 años seguidos',                           emoji: '🎄', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.especial,    meta: 3),
  TrofeoDef(id: 'early_adopter',         titulo: 'Early Adopter',           descripcion: 'Reserva en el primer mes de apertura de un nuevo negocio',    emoji: '🚀', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'ultimo_hueco',          titulo: 'Último Hueco',            descripcion: 'Reservas el último slot disponible del día 3 veces',          emoji: '🏁', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.especial,    meta: 3),
  TrofeoDef(id: 'speed_booker',          titulo: 'Speed Booker',            descripcion: 'Reservas en menos de 60 segundos desde que abres la app',     emoji: '⚡', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'embajador_logros',      titulo: 'Embajador',               descripcion: 'Trofeo en fidelidad + social + reseñas simultáneamente',      emoji: '🦁', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'all_star',              titulo: 'All-Star',                descripcion: 'Al menos 1 trofeo completado en cada categoría',              emoji: '🌠', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial),

  // ── RESEÑAS AMPLIADAS ──────────────────────────────────────────────────────
  TrofeoDef(id: 'fotografo_resenas',     titulo: 'Fotógrafo',               descripcion: 'Adjuntas foto en 5 reseñas distintas',                        emoji: '📸', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.resenas,     meta: 5),
  TrofeoDef(id: 'valorado',              titulo: 'Valorado',                descripcion: 'Tu reseña recibe 10 "útil" de otros usuarios',                emoji: '👍', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.resenas,     meta: 10),
  TrofeoDef(id: 'siempre_cinco_estrellas',titulo: 'Siempre 5 Estrellas',    descripcion: '10 reseñas de 5 estrellas consecutivas',                      emoji: '💫', monedas: 10,   tier: TrofeoTier.bronce,  categoria: TrofeoCategoria.resenas,     meta: 10),
  TrofeoDef(id: 'voz_barrio',            titulo: 'Voz del Barrio',          descripcion: '25 reseñas, con foto en al menos 5',                          emoji: '📢', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.resenas,     meta: 25),


  // ── OCULTOS (tienda + leyendas) ────────────────────────────────────────────
  TrofeoDef(id: 'coleccionista_tienda',  titulo: 'El Coleccionista',        descripcion: 'Has canjeado el Trofeo Coleccionista.',                      emoji: '🎴', monedas: 0,    tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial,    oculto: true),
  TrofeoDef(id: 'leyenda_mil',           titulo: 'Mil Visitas',             descripcion: '1000 reservas en total. Una hazaña de pocos.',               emoji: '🌌', monedas: 150, tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial,    meta: 1000, oculto: true),
  TrofeoDef(id: 'leyenda_critico',       titulo: 'Crítico Supremo',         descripcion: 'Publica 100 reseñas verificadas.',                           emoji: '🖊️', monedas: 150, tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial,    meta: 100,  oculto: true),
  TrofeoDef(id: 'leyenda_fidelidad',     titulo: 'Incondicional Absoluto',  descripcion: '50 visitas al mismo negocio.',                               emoji: '💠', monedas: 150, tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial,    meta: 50,   oculto: true),
  TrofeoDef(id: 'leyenda_temporada',     titulo: 'Cuatro Estaciones',       descripcion: 'Reserva en los 4 trimestres de un mismo año.',               emoji: '🍂', monedas: 150, tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial,    meta: 4,    oculto: true),
  TrofeoDef(id: 'leyenda_explorador',    titulo: 'Sin Límites',             descripcion: 'Reserva en 8 categorías de negocios distintas.',             emoji: '🗺️', monedas: 150, tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial,    meta: 8,    oculto: true),

  // ── FIDELIDAD AVANZADA (57-64) ─────────────────────────────────────────────
  TrofeoDef(id: 'mito_local',            titulo: 'Mito Local',              descripcion: '200 citas completadas',                                       emoji: '🗿', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.fidelidad,   meta: 200),
  TrofeoDef(id: 'racha_semestral',       titulo: 'Racha Semestral',         descripcion: 'Al menos una cita mensual durante 6 meses seguidos',          emoji: '📅', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.fidelidad,   meta: 6),
  TrofeoDef(id: 'dos_anos_juntos',       titulo: 'Dos Años Juntos',         descripcion: 'Cliente activo durante 24 meses',                             emoji: '💞', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.fidelidad),
  TrofeoDef(id: 'dios_del_barrio',       titulo: 'Dios del Barrio',         descripcion: '150 citas en el mismo negocio',                               emoji: '🏛️', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.fidelidad,   meta: 150),
  TrofeoDef(id: 'ritual_imparable',      titulo: 'Ritual Imparable',        descripcion: 'El mismo día de la semana durante 20 semanas seguidas',       emoji: '🔥', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.fidelidad,   meta: 20),
  TrofeoDef(id: 'madrugador_extremo',    titulo: 'Madrugador Extremo',      descripcion: '20 citas en el primer turno del día',                         emoji: '🌄', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.fidelidad,   meta: 20),
  TrofeoDef(id: 'noctambulo_empedernido',titulo: 'Noctámbulo Empedernido',  descripcion: '20 citas en turno tarde-noche',                               emoji: '🦉', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.fidelidad,   meta: 20),
  TrofeoDef(id: 'el_inamovible',         titulo: 'El Inamovible',           descripcion: 'Reservas de nuevo tras haber cancelado 3 veces',              emoji: '⚓', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.fidelidad),

  // ── SOCIAL AVANZADA (65-69) ────────────────────────────────────────────────
  TrofeoDef(id: 'embajador_ciudad',      titulo: 'Embajador de Ciudad',     descripcion: '25 referidos activos en Fluix',                               emoji: '🌆', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.social,      meta: 25),
  TrofeoDef(id: 'red_viral',             titulo: 'Red Viral',               descripcion: '50 referidos activos en Fluix',                               emoji: '🕸️', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.social,      meta: 50),
  TrofeoDef(id: 'super_compartidor',     titulo: 'Súper Compartidor',       descripcion: '20 experiencias compartidas desde la app',                    emoji: '📲', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.social,      meta: 20),
  TrofeoDef(id: 'generosidad_extrema',   titulo: 'Generosidad Extrema',     descripcion: '5 citas regaladas a otras personas',                          emoji: '🎀', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.social,      meta: 5),

  // ── EXPLORADOR AVANZADO (70-74) ────────────────────────────────────────────
  TrofeoDef(id: 'cosmopolita',           titulo: 'Cosmopolita',             descripcion: '20 negocios distintos visitados',                             emoji: '🌍', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.exploracion, meta: 20),
  TrofeoDef(id: 'maestro_del_estilo',    titulo: 'Maestro del Estilo',      descripcion: '8 servicios distintos en peluquería',                         emoji: '🪄', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.exploracion, meta: 8),
  TrofeoDef(id: 'guru_bienestar',        titulo: 'Gurú del Bienestar',      descripcion: 'Reservas en 6 categorías distintas de negocios',              emoji: '🧘', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.exploracion, meta: 6),
  TrofeoDef(id: 'pionero_permanente',    titulo: 'Pionero Permanente',      descripcion: 'Pruebas 10 servicios que no habías reservado antes',          emoji: '🏴', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.exploracion, meta: 10),
  TrofeoDef(id: 'gran_turismo',          titulo: 'Gran Turismo Urbano',     descripcion: '30 negocios distintos visitados',                             emoji: '🏙️', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.exploracion, meta: 30),

  // ── PUNTUALIDAD AVANZADA (75-78) ───────────────────────────────────────────
  TrofeoDef(id: 'perfecto_50',           titulo: 'Perfecto 50',             descripcion: '50 citas sin ninguna cancelación',                            emoji: '🎯', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.puntualidad, meta: 50),
  TrofeoDef(id: 'maestro_del_tiempo',    titulo: 'Maestro del Tiempo',      descripcion: 'Confirmas 20 citas con más de 24h de antelación',             emoji: '🕰️', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.puntualidad, meta: 20),
  TrofeoDef(id: 'gran_planificador',     titulo: 'Gran Planificador',       descripcion: 'Reservas con más de 1 semana de antelación 20 veces',         emoji: '🗓️', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.puntualidad, meta: 20),

  // ── ESPECIALES AVANZADOS (79-86) ───────────────────────────────────────────
  TrofeoDef(id: 'leyenda_app',           titulo: 'Leyenda de la App',       descripcion: '3 años usando Fluix',                                         emoji: '🏺', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'cuenta_dorada',         titulo: 'Cuenta Dorada',           descripcion: '1000 monedas acumuladas en total (histórico)',                 emoji: '💛', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.especial,    meta: 1000),
  TrofeoDef(id: 'omnipresente',          titulo: 'Omnipresente',            descripcion: 'Activo en móvil + desktop + web en el mismo mes',              emoji: '🖥️', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'cumpleaneros_x3',       titulo: 'Cumpleaños x3',           descripcion: 'Cita el día de tu cumpleaños durante 3 años distintos',       emoji: '🎊', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.especial,    meta: 3),
  TrofeoDef(id: 'navidad_permanente',    titulo: 'Navidad Permanente',      descripcion: 'Cita en diciembre durante 5 años seguidos',                   emoji: '🎅', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.especial,    meta: 5),
  TrofeoDef(id: 'padrino_fundador',      titulo: 'Padrino Fundador',        descripcion: 'Entre los primeros 10 clientes de un nuevo negocio',          emoji: '🏗️', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'cazador_huecos',        titulo: 'Cazador de Huecos',       descripcion: 'Reservas el último slot del día 10 veces',                    emoji: '🏹', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.especial,    meta: 10),
  TrofeoDef(id: 'speed_demon',           titulo: 'Speed Demon',             descripcion: 'Reservas en menos de 30 segundos 5 veces',                    emoji: '💨', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.especial,    meta: 5),

  // ── RESEÑAS AVANZADAS (87-92) ──────────────────────────────────────────────
  TrofeoDef(id: 'cronista_oficial',      titulo: 'Cronista Oficial',        descripcion: '50 reseñas publicadas',                                       emoji: '📰', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.resenas,     meta: 50),
  TrofeoDef(id: 'voz_ciudad',            titulo: 'Voz de la Ciudad',        descripcion: '100 reseñas con foto en al menos 20',                         emoji: '🎙️', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.resenas,     meta: 100),
  TrofeoDef(id: 'fotografo_premium',     titulo: 'Fotógrafo Premium',       descripcion: 'Foto adjunta en 20 reseñas distintas',                        emoji: '📷', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.resenas,     meta: 20),
  TrofeoDef(id: 'la_referencia',         titulo: 'La Referencia',           descripcion: 'Tus reseñas reciben 50 "útil" de otros usuarios',             emoji: '🌟', monedas: 50,   tier: TrofeoTier.oro,     categoria: TrofeoCategoria.resenas,     meta: 50),
  TrofeoDef(id: 'perfecto_25_estrellas', titulo: 'Perfecto 25 ★',           descripcion: '25 reseñas de 5 estrellas consecutivas',                      emoji: '💫', monedas: 20,   tier: TrofeoTier.plata,   categoria: TrofeoCategoria.resenas,     meta: 25),
  TrofeoDef(id: 'cien_por_cien',         titulo: 'Cien por Cien',           descripcion: 'Reseña en el 100% de tus visitas (mín. 20 citas)',             emoji: '💯', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.resenas,     meta: 20),

  // ── ESPECIALES CIERRE (93-94) ──────────────────────────────────────────────
  TrofeoDef(id: 'triple_corona',         titulo: 'Triple Corona',           descripcion: 'Trofeo en fidelidad + social + explorador simultáneamente',    emoji: '👑', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial),
  TrofeoDef(id: 'maestro_total',         titulo: 'Maestro Total',           descripcion: 'Al menos 3 trofeos completados en cada categoría',            emoji: '🎓', monedas: 150,  tier: TrofeoTier.platino, categoria: TrofeoCategoria.especial),

];
