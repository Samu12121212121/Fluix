class BloqueDisponible {
  final String tipo;
  final String nombre;
  final String icono;
  final String categoria;
  final Map<String, dynamic> propsDefault;

  const BloqueDisponible({
    required this.tipo,
    required this.nombre,
    required this.icono,
    required this.categoria,
    required this.propsDefault,
  });
}
