import 'package:flutter/material.dart';
import '../../../services/valoracion_service.dart';
import '../../../models/valoracion_model.dart';

class _V {
  static const fondo      = Color(0xFF0A0F23);
  static const superficie = Color(0xFF151932);
  static const tarjeta    = Color(0xFF1E2139);
  static const borde      = Color(0xFF2A2E45);
  static const amarillo   = Color(0xFFFFBB00);
  static const accent     = Color(0xFF00FFC8);
  static const rosa       = Color(0xFFFF3296);
  static const rojo       = Color(0xFFFF2850);
  static const texto      = Color(0xFFFFFFFF);
  static const textoMuted = Color(0xFFB0B3C1);
  static const textoHint  = Color(0xFF6B6E82);
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA DEJAR VALORACIÓN (vista CLIENTE)
// ─────────────────────────────────────────────────────────────────────────────
class PantallaDejarValoracion extends StatefulWidget {
  final String negocioId;
  final String negocioNombre;
  final String? negocioFoto;
  final String reservaId;
  final DateTime? fechaCita;

  const PantallaDejarValoracion({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    this.negocioFoto,
    required this.reservaId,
    this.fechaCita,
  });

  @override
  State<PantallaDejarValoracion> createState() => _PantallaDejarValoracionState();
}

class _PantallaDejarValoracionState extends State<PantallaDejarValoracion> {
  int _estrellas = 0;
  final _ctrl = TextEditingController();
  bool _publicando = false;
  bool? _yaValorado; // null=cargando, true=ya valorado, false=puede valorar

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _verificar() async {
    final yaV = await ValoracionService.yaValoroReserva(
        widget.negocioId, widget.reservaId);
    if (mounted) setState(() => _yaValorado = yaV);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _V.fondo,
      appBar: AppBar(
        backgroundColor: _V.superficie,
        foregroundColor: _V.texto,
        elevation: 0,
        title: const Text('Dejar valoración',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: _yaValorado == null
          ? const Center(child: CircularProgressIndicator(color: _V.amarillo))
          : _yaValorado == true
              ? _pantallaYaValorado()
              : _formulario(),
    );
  }

  // ── YA VALORADO ──────────────────────────────────────────────
  Widget _pantallaYaValorado() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFF1A2A1A), shape: BoxShape.circle,
          ),
          child: const Center(child: Text('✅', style: TextStyle(fontSize: 36))),
        ),
        const SizedBox(height: 20),
        const Text('Ya has valorado esta visita',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: _V.texto), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('Gracias por tu opinión. Ayuda a otros usuarios a '
            'descubrir negocios de calidad.',
            style: TextStyle(fontSize: 13, color: _V.textoMuted, height: 1.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _V.textoMuted,
              side: const BorderSide(color: _V.borde),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Volver'),
          ),
        ),
      ]),
    ));
  }

  // ── FORMULARIO ───────────────────────────────────────────────
  Widget _formulario() {
    final chars = _ctrl.text.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Negocio info
        _NegocioHeader(
          nombre:  widget.negocioNombre,
          foto:    widget.negocioFoto,
          fechaCita: widget.fechaCita,
        ),
        const SizedBox(height: 28),

        // Selector de estrellas
        const Text('¿Cómo fue tu experiencia?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: _V.texto)),
        const SizedBox(height: 16),
        _SelectorEstrellas(
          seleccionado: _estrellas,
          onChanged: (v) => setState(() => _estrellas = v),
        ),
        if (_estrellas > 0) ...[
          const SizedBox(height: 8),
          Text(_textoEstrellas(_estrellas),
              style: const TextStyle(fontSize: 13, color: _V.amarillo,
                  fontWeight: FontWeight.w500)),
        ],
        const SizedBox(height: 24),

        // Campo comentario
        Container(
          decoration: BoxDecoration(
            color: _V.superficie,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _estrellas > 0 ? _V.amarillo.withValues(alpha: 0.3) : _V.borde),
          ),
          child: Column(children: [
            TextField(
              controller: _ctrl,
              maxLines: 5,
              maxLength: 300,
              buildCounter: (_,{required currentLength, required isFocused, maxLength}) =>
                  const SizedBox.shrink(),
              style: const TextStyle(color: _V.texto, fontSize: 14, height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Cuéntanos cómo fue tu visita...',
                hintStyle: TextStyle(color: _V.textoHint, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              onChanged: (_) => setState(() {}),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                Text('Mínimo 10 caracteres',
                    style: TextStyle(
                      fontSize: 10,
                      color: chars >= 10 ? _V.accent : _V.textoHint,
                    )),
                const Spacer(),
                Text('$chars / 300',
                    style: TextStyle(fontSize: 10,
                        color: chars > 270 ? _V.rosa : _V.textoHint)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 32),

        // Botón publicar
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: (_estrellas > 0 && chars >= 10 && !_publicando)
                ? _publicar : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _V.amarillo,
              foregroundColor: _V.fondo,
              disabledBackgroundColor: _V.borde,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _publicando
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: _V.fondo, strokeWidth: 2.5))
                : const Text('Publicar valoración',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Las valoraciones son públicas e inmediatas. No se pueden editar.',
            style: TextStyle(fontSize: 11, color: _V.textoHint),
            textAlign: TextAlign.center),
      ]),
    );
  }

  String _textoEstrellas(int n) => switch (n) {
    1 => 'Muy mala experiencia',
    2 => 'Mala experiencia',
    3 => 'Regular',
    4 => 'Buena experiencia',
    5 => '¡Excelente experiencia!',
    _ => '',
  };

  Future<void> _publicar() async {
    setState(() => _publicando = true);
    try {
      await ValoracionService.publicar(
        negocioId:  widget.negocioId,
        reservaId:  widget.reservaId,
        estrellas:  _estrellas,
        comentario: _ctrl.text.trim(),
      );
      if (!mounted) return;
      _mostrarExito();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: _V.rojo,
      ));
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  void _mostrarExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: _V.tarjeta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('⭐', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text('¡Gracias por tu valoración!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: _V.texto), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Tu opinión sobre ${widget.negocioNombre} ya es pública.',
                style: const TextStyle(fontSize: 13, color: _V.textoMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // cierra dialog
                  Navigator.pop(context, true); // cierra pantalla con resultado
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _V.amarillo, foregroundColor: _V.fondo,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Genial', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SELECTOR DE ESTRELLAS ANIMADO
// ─────────────────────────────────────────────────────────────────────────────
class _SelectorEstrellas extends StatefulWidget {
  final int seleccionado;
  final ValueChanged<int> onChanged;
  const _SelectorEstrellas({required this.seleccionado, required this.onChanged});

  @override
  State<_SelectorEstrellas> createState() => _SelectorEstrellasState();
}

class _SelectorEstrellasState extends State<_SelectorEstrellas> {
  int _hover = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final n = i + 1;
        final activa = n <= ((_hover > 0 ? _hover : widget.seleccionado));
        return GestureDetector(
          onTap: () {
            setState(() => _hover = 0);
            widget.onChanged(n);
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = n),
            onExit: (_) => setState(() => _hover = 0),
            child: _EstrellaBounce(activa: activa, index: i),
          ),
        );
      }),
    );
  }
}

class _EstrellaBounce extends StatefulWidget {
  final bool activa;
  final int index;
  const _EstrellaBounce({required this.activa, required this.index});

  @override
  State<_EstrellaBounce> createState() => _EstrellaBounceState();
}

class _EstrellaBounceState extends State<_EstrellaBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _prevActiva = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 300));
    _scale = Tween<double>(begin: 1, end: 1.35)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(_EstrellaBounce old) {
    super.didUpdateWidget(old);
    if (widget.activa && !_prevActiva) {
      _ctrl.forward(from: 0);
    }
    _prevActiva = widget.activa;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ScaleTransition(
        scale: _scale,
        child: Icon(
          widget.activa ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 42,
          color: widget.activa ? const Color(0xFFFFBB00) : const Color(0xFF2A2E45),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER DEL NEGOCIO
// ─────────────────────────────────────────────────────────────────────────────
class _NegocioHeader extends StatelessWidget {
  final String nombre;
  final String? foto;
  final DateTime? fechaCita;
  const _NegocioHeader({required this.nombre, this.foto, this.fechaCita});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _V.tarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _V.borde),
      ),
      child: Row(children: [
        // Foto
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56, height: 56,
            child: foto != null && foto!.isNotEmpty
                ? Image.network(foto!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: const TextStyle(fontSize: 15,
              fontWeight: FontWeight.w700, color: _V.texto)),
          if (fechaCita != null) ...[
            const SizedBox(height: 4),
            Text('Visita el ${fechaCita!.day}/${fechaCita!.month}/${fechaCita!.year}',
                style: const TextStyle(fontSize: 11, color: _V.textoMuted)),
          ],
        ])),
      ]),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFF1E2139),
    child: const Center(child: Icon(Icons.store_outlined,
        color: Color(0xFF6B6E82), size: 24)),
  );
}

