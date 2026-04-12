import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ASISTENTE IVA CONSTRUCCIÓN
// Guía al usuario paso a paso para determinar el tipo de IVA correcto según
// la Ley del IVA (LIVA) y los criterios de la AEAT para obras de construcción.
// ─────────────────────────────────────────────────────────────────────────────

class ResultadoIva {
  final double porcentaje;
  final String titulo;
  final String explicacion;
  final String articulo;

  const ResultadoIva({
    required this.porcentaje,
    required this.titulo,
    required this.explicacion,
    required this.articulo,
  });
}

class AsistenteIvaConstruccion extends StatefulWidget {
  /// Callback que recibe el porcentaje de IVA elegido al pulsar "Aplicar".
  final void Function(double iva) onIvaSeleccionado;

  const AsistenteIvaConstruccion({super.key, required this.onIvaSeleccionado});

  /// Abre el asistente en un bottom-sheet a pantalla completa.
  static Future<void> mostrar(
    BuildContext context, {
    required void Function(double iva) onIvaSeleccionado,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => AsistenteIvaConstruccion(onIvaSeleccionado: onIvaSeleccionado),
    );
  }

  @override
  State<AsistenteIvaConstruccion> createState() => _AsistenteIvaConstruccionState();
}

class _AsistenteIvaConstruccionState extends State<AsistenteIvaConstruccion> {
  int _paso = 1;
  ResultadoIva? _resultado;

  // ── Constantes de estilo ─────────────────────────────────────────────────

  static const _azul = Color(0xFF0D47A1);
  static const _azulClaro = Color(0xFF1976D2);
  static const _verde = Color(0xFF2E7D32);
  static const _naranja = Color(0xFFE65100);
  static const _gris = Color(0xFF546E7A);

  // ── Build principal ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildCabecera(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _resultado != null ? _buildResultado() : _buildPaso(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cabecera ─────────────────────────────────────────────────────────────

  Widget _buildCabecera() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_azul, _azulClaro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_outlined, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Qué IVA aplica?',
                    style: TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.bold)),
                Text('Asistente para obras de construcción',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          if (_resultado != null || _paso > 1)
            TextButton.icon(
              onPressed: _reiniciar,
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 16),
              label: const Text('Reiniciar', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // ── Selector de paso ─────────────────────────────────────────────────────

  Widget _buildPaso() {
    switch (_paso) {
      case 1: return _buildPaso1();
      case 2: return _buildPaso2();
      case 3: return _buildPaso3();
      case 4: return _buildPaso4();
      case 5: return _buildPaso5();
      default: return const SizedBox.shrink();
    }
  }

  // ── Paso 1: Tipo de inmueble ─────────────────────────────────────────────

  Widget _buildPaso1() {
    return _buildPregunta(
      numero: 1,
      pregunta: '¿En qué tipo de inmueble se realiza la obra?',
      opciones: [
        _Opcion(
          icono: Icons.home,
          color: _verde,
          titulo: 'Vivienda particular',
          subtitulo: 'Piso, casa, chalet de uso residencial',
          onTap: () => setState(() => _paso = 2),
        ),
        _Opcion(
          icono: Icons.store,
          color: _naranja,
          titulo: 'Local comercial / Oficina',
          subtitulo: 'Tienda, despacho, bar, restaurante…',
          onTap: () => _setResultado(const ResultadoIva(
            porcentaje: 21,
            titulo: 'IVA General: 21%',
            explicacion:
                'Las obras en locales comerciales, oficinas y demás inmuebles no destinados a vivienda tributan al tipo general del 21%, independientemente del tipo de obra que se realice.',
            articulo: 'Art. 90 LIVA — Tipo general del Impuesto',
          )),
        ),
        _Opcion(
          icono: Icons.warehouse,
          color: _naranja,
          titulo: 'Nave industrial',
          subtitulo: 'Almacén, fábrica, taller industrial…',
          onTap: () => _setResultado(const ResultadoIva(
            porcentaje: 21,
            titulo: 'IVA General: 21%',
            explicacion:
                'Las obras en naves industriales y almacenes tributan siempre al tipo general del 21%.',
            articulo: 'Art. 90 LIVA — Tipo general del Impuesto',
          )),
        ),
        _Opcion(
          icono: Icons.apartment,
          color: _gris,
          titulo: 'Edificio mixto (vivienda + local)',
          subtitulo: 'Obra que afecta a partes residenciales y comerciales',
          onTap: () => setState(() => _paso = 2),
        ),
        _Opcion(
          icono: Icons.construction,
          color: _naranja,
          titulo: 'Obra civil / Infraestructura',
          subtitulo: 'Carreteras, redes, obras de ingeniería civil…',
          onTap: () => _setResultado(const ResultadoIva(
            porcentaje: 21,
            titulo: 'IVA General: 21%',
            explicacion:
                'Las obras civiles e infraestructuras no son edificaciones destinadas a vivienda, por lo que tributan al 21%.',
            articulo: 'Art. 90 LIVA — Tipo general del Impuesto',
          )),
        ),
      ],
    );
  }

  // ── Paso 2: ¿Es VPO? ────────────────────────────────────────────────────

  Widget _buildPaso2() {
    return _buildPregunta(
      numero: 2,
      pregunta: '¿Es una Vivienda de Protección Oficial (VPO)?',
      opciones: [
        _Opcion(
          icono: Icons.verified,
          color: _verde,
          titulo: 'Sí, es VPO de régimen especial o promoción pública',
          subtitulo: 'Con calificación oficial emitida por la administración',
          onTap: () => _setResultado(const ResultadoIva(
            porcentaje: 4,
            titulo: 'IVA Superreducido: 4%',
            explicacion:
                'Las entregas y obras de construcción de Viviendas de Protección Oficial de régimen especial o de promoción pública tributan al tipo superreducido del 4%.',
            articulo: 'Art. 91.Dos.1.º.3.ª LIVA',
          )),
        ),
        _Opcion(
          icono: Icons.home_outlined,
          color: _azulClaro,
          titulo: 'No, no es VPO',
          subtitulo: 'Vivienda libre o de protección oficial general',
          onTap: () => setState(() => _paso = 3),
        ),
      ],
    );
  }

  // ── Paso 3: Tipo de obra ─────────────────────────────────────────────────

  Widget _buildPaso3() {
    return _buildPregunta(
      numero: 3,
      pregunta: '¿Qué tipo de obra se va a realizar?',
      opciones: [
        _Opcion(
          icono: Icons.foundation,
          color: _azul,
          titulo: 'Obra nueva (construcción desde cero)',
          subtitulo: 'Primera edificación o ampliación importante del edificio',
          onTap: () => _setResultado(const ResultadoIva(
            porcentaje: 10,
            titulo: 'IVA Reducido: 10%',
            explicacion:
                'La construcción de edificaciones destinadas principalmente a viviendas tributa al tipo reducido del 10%.',
            articulo: 'Art. 91.Uno.1.º LIVA — Edificaciones destinadas a vivienda',
          )),
        ),
        _Opcion(
          icono: Icons.home_repair_service,
          color: _verde,
          titulo: 'Rehabilitación o renovación de vivienda existente',
          subtitulo: 'Reforma integral o importante de una vivienda ya construida',
          onTap: () => setState(() => _paso = 4),
        ),
        _Opcion(
          icono: Icons.build,
          color: _gris,
          titulo: 'Reparación o mantenimiento puntual',
          subtitulo: 'Pintura, pequeñas reparaciones, mantenimiento ordinario…',
          onTap: () => setState(() => _paso = 5),
        ),
      ],
    );
  }

  // ── Paso 4: ¿Materiales > 40%? ──────────────────────────────────────────

  Widget _buildPaso4() {
    return _buildPregunta(
      numero: 4,
      pregunta: '¿El coste de los materiales supera el 40% del total de la obra?',
      ayuda: 'Cuando los materiales (no la mano de obra) representan más del 40% del coste total, la AEAT no considera la operación como "obra de rehabilitación" a efectos del IVA reducido.',
      opciones: [
        _Opcion(
          icono: Icons.arrow_upward,
          color: _naranja,
          titulo: 'Sí, los materiales superan el 40%',
          subtitulo: 'El porcentaje de materiales es mayor al 40% del precio total',
          onTap: () => _setResultado(const ResultadoIva(
            porcentaje: 21,
            titulo: 'IVA General: 21%',
            explicacion:
                'Cuando el coste de los materiales supera el 40% del total de la obra, la operación no se considera rehabilitación a efectos del IVA y tributa al tipo general del 21%, según criterio de la AEAT.',
            articulo: 'Criterio AEAT — Art. 91.Uno.2.º LIVA (condición materiales < 40%)',
          )),
        ),
        _Opcion(
          icono: Icons.arrow_downward,
          color: _verde,
          titulo: 'No, los materiales son menos del 40%',
          subtitulo: 'La mano de obra es el componente principal del coste',
          onTap: () => _setResultado(const ResultadoIva(
            porcentaje: 10,
            titulo: 'IVA Reducido: 10%',
            explicacion:
                'La obra cumple el requisito de que los materiales no superen el 40% del coste total, por lo que se aplica el tipo reducido del 10% como obra de rehabilitación de vivienda.',
            articulo: 'Art. 91.Uno.2.º LIVA — Ejecuciones de obra de renovación y reparación de edificaciones destinadas a uso particular',
          )),
        ),
      ],
    );
  }

  // ── Paso 5: ¿Quién encarga la obra? ─────────────────────────────────────

  Widget _buildPaso5() {
    return _buildPregunta(
      numero: 5,
      pregunta: '¿Quién encarga la reparación o mantenimiento?',
      opciones: [
        _Opcion(
          icono: Icons.person,
          color: _verde,
          titulo: 'Un particular para su vivienda habitual',
          subtitulo: 'El encargante es una persona física que reside habitualmente en la vivienda',
          onTap: () => _setResultado(const ResultadoIva(
            porcentaje: 10,
            titulo: 'IVA Reducido: 10%',
            explicacion:
                'Las ejecuciones de obra de reparación o mantenimiento encargadas por particulares para su vivienda habitual tributan al 10%.',
            articulo: 'Art. 91.Uno.2.º LIVA — Ejecuciones de obra de renovación y reparación de edificaciones',
          )),
        ),
        _Opcion(
          icono: Icons.business,
          color: _naranja,
          titulo: 'Una empresa o promotora',
          subtitulo: 'El encargante es una persona jurídica o actúa como empresario',
          onTap: () => _setResultado(const ResultadoIva(
            porcentaje: 21,
            titulo: 'IVA General: 21%',
            explicacion:
                'Cuando el promotor de la obra es una empresa o actúa como empresario/profesional, no aplica el tipo reducido y la operación tributa al 21%.',
            articulo: 'Art. 90 LIVA — Tipo general del Impuesto',
          )),
        ),
      ],
    );
  }

  // ── Resultado final ──────────────────────────────────────────────────────

  Widget _buildResultado() {
    final r = _resultado!;
    final Color color;
    final String badge;
    if (r.porcentaje == 4) {
      color = _verde;
      badge = '4%';
    } else if (r.porcentaje == 10) {
      color = _azulClaro;
      badge = '10%';
    } else if (r.porcentaje == 0) {
      color = _gris;
      badge = '0%';
    } else {
      color = _naranja;
      badge = '21%';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge grande de IVA
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              children: [
                Text('IVA recomendado',
                    style: TextStyle(color: color, fontSize: 13)),
                const SizedBox(height: 4),
                Text(badge,
                    style: TextStyle(
                        color: color, fontSize: 52, fontWeight: FontWeight.bold)),
                Text(r.titulo,
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Explicación legal
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.gavel, size: 16, color: _azul),
                SizedBox(width: 6),
                Text('Base legal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              Text(r.explicacion, style: const TextStyle(fontSize: 13, height: 1.5)),
              const SizedBox(height: 6),
              Text(r.articulo,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600],
                      fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Aviso orientativo
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber, size: 18, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Este asistente es orientativo. Consulta con tu asesor fiscal en casos dudosos o en operaciones de especial complejidad.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Botón aplicar
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              widget.onIvaSeleccionado(r.porcentaje);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check),
            label: Text('Aplicar ${badge} a la factura',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _reiniciar,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Volver a empezar'),
            style: TextButton.styleFrom(foregroundColor: _gris),
          ),
        ),
      ],
    );
  }

  // ── Builder reutilizable de pregunta + opciones ──────────────────────────

  Widget _buildPregunta({
    required int numero,
    required String pregunta,
    required List<_Opcion> opciones,
    String? ayuda,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicador de paso
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _azul,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Paso $numero',
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 12),

        // Pregunta
        Text(pregunta,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.4)),
        if (ayuda != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: _azulClaro),
                const SizedBox(width: 6),
                Expanded(child: Text(ayuda,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF37474F)))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Opciones
        ...opciones.map((op) => _buildBotonOpcion(op)),
      ],
    );
  }

  Widget _buildBotonOpcion(_Opcion opcion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: opcion.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: opcion.color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
            color: opcion.color.withValues(alpha: 0.04),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: opcion.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(opcion.icono, color: opcion.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opcion.titulo,
                        style: TextStyle(fontWeight: FontWeight.w600,
                            color: opcion.color, fontSize: 14)),
                    if (opcion.subtitulo != null)
                      Text(opcion.subtitulo!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: opcion.color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _setResultado(ResultadoIva r) => setState(() => _resultado = r);

  void _reiniciar() => setState(() {
        _paso = 1;
        _resultado = null;
      });
}

// ── Modelo interno de opción ─────────────────────────────────────────────────

class _Opcion {
  final IconData icono;
  final Color color;
  final String titulo;
  final String? subtitulo;
  final VoidCallback onTap;

  const _Opcion({
    required this.icono,
    required this.color,
    required this.titulo,
    this.subtitulo,
    required this.onTap,
  });
}

