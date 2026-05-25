// terminos_condiciones_screen.dart
// Pantalla dedicada para editar y previsualizar los T&C del negocio.
// Accesible desde modulo_app_screen y gestion_negocios_publicos_screen.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _kBg     = Color(0xFF0A0F23);
const _kCard   = Color(0xFF1E2139);
const _kAccent = Color(0xFF00FFC8);
const _kRosa   = Color(0xFFFF3296);
const _kTexto  = Colors.white;
const _kMuted  = Color(0xFFB0B3C1);
const _kBorde  = Color(0xFF2A2E45);

class TerminosCondicionesScreen extends StatefulWidget {
  final String negocioId;
  final String nombreNegocio;

  const TerminosCondicionesScreen({
    super.key,
    required this.negocioId,
    required this.nombreNegocio,
  });

  @override
  State<TerminosCondicionesScreen> createState() => _TerminosCondicionesScreenState();
}

class _TerminosCondicionesScreenState extends State<TerminosCondicionesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _ctrl = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;
  bool _modificado = false;

  // Plantillas rápidas
  static const _plantillas = {
    'Cancelación 24h': '''Al realizar una reserva aceptas las siguientes condiciones:

• Las cancelaciones deben realizarse con al menos 24 horas de antelación.
• Las cancelaciones fuera de plazo podrán conllevar un cargo del 50% del servicio.
• En caso de no presentación (no-show), se cobrará el 100% del servicio reservado.
• ${'{NEGOCIO}'} se reserva el derecho a cancelar citas en casos de fuerza mayor, con notificación previa al cliente.

Para cancelar o modificar tu reserva, contacta con nosotros a través de los canales indicados en el perfil.''',

    'Política básica': '''Condiciones de reserva de ${'{NEGOCIO}'}:

• La reserva quedará confirmada tras recibir notificación por nuestra parte.
• Rogamos puntualidad. Los retrasos superiores a 15 minutos podrán suponer la anulación de la cita.
• Los precios indicados son orientativos y pueden variar según el servicio definitivo realizado.
• ${'{NEGOCIO}'} se compromete a respetar tu privacidad conforme al RGPD.''',

    'Restaurante/Bar': '''Condiciones de reserva de mesa en ${'{NEGOCIO}'}:

• La reserva se mantendrá durante 15 minutos desde la hora acordada.
• Grupos de 8 o más personas requieren confirmación con 48h de antelación.
• Para grupos grandes puede solicitarse un depósito o menú cerrado.
• Las modificaciones de número de comensales deben comunicarse con 24h de antelación.
• ${'{NEGOCIO}'} se reserva el derecho de admisión conforme a la normativa vigente.''',
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tab.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(widget.negocioId)
          .get();
      if (mounted) {
        _ctrl.text = doc.data()?['terminosYCondiciones'] ?? '';
        _ctrl.addListener(() => setState(() => _modificado = true));
      }
    } catch (e) {
      _snack('Error cargando: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(widget.negocioId)
          .update({'terminosYCondiciones': _ctrl.text.trim()});
      if (mounted) setState(() => _modificado = false);
      _snack('✅ Términos guardados y publicados');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _aplicarPlantilla(String clave) {
    final texto = _plantillas[clave]!
        .replaceAll('{NEGOCIO}', widget.nombreNegocio);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('¿Aplicar plantilla?',
            style: TextStyle(color: _kTexto)),
        content: Text(
          'Esto reemplazará el texto actual. ¿Continuar?',
          style: const TextStyle(color: _kMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: _kMuted)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _ctrl.text = texto;
              setState(() => _modificado = true);
              _tab.animateTo(0); // Volver al editor
            },
            style: FilledButton.styleFrom(
                backgroundColor: _kAccent, foregroundColor: _kBg),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFFF2850) : _kAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF151932),
        foregroundColor: _kTexto,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Términos y Condiciones',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.nombreNegocio,
                style: const TextStyle(color: _kMuted, fontSize: 12)),
          ],
        ),
        actions: [
          if (_modificado)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kBg))
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(_guardando ? 'Guardando…' : 'Guardar'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: _kBg,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kAccent,
          labelColor: _kAccent,
          unselectedLabelColor: _kMuted,
          tabs: const [
            Tab(icon: Icon(Icons.edit_rounded, size: 18), text: 'Editor'),
            Tab(
                icon: Icon(Icons.visibility_rounded, size: 18),
                text: 'Vista previa'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(
          child: CircularProgressIndicator(color: _kAccent))
          : TabBarView(
        controller: _tab,
        children: [
          _buildEditor(),
          _buildPreview(),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        // Barra de plantillas
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF151932),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: _kAccent, size: 16),
              const SizedBox(width: 8),
              const Text('Plantillas:',
                  style: TextStyle(color: _kMuted, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _plantillas.keys.map((k) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(k,
                            style: const TextStyle(
                                color: _kAccent, fontSize: 11)),
                        backgroundColor: _kCard,
                        side: const BorderSide(color: _kBorde, width: 0.5),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _aplicarPlantilla(k),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Editor principal
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorde, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(children: [
                      const Icon(Icons.gavel_rounded,
                          color: _kAccent, size: 16),
                      const SizedBox(width: 8),
                      const Text('Texto de los términos',
                          style: TextStyle(
                              color: _kTexto,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const Spacer(),
                      Text('${_ctrl.text.length} caracteres',
                          style: const TextStyle(
                              color: _kMuted, fontSize: 11)),
                    ]),
                  ),
                  const Divider(color: _kBorde, height: 18),
                  Expanded(
                    child: Padding(
                      padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: TextField(
                        controller: _ctrl,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                            color: _kTexto,
                            fontSize: 13,
                            height: 1.6),
                        decoration: const InputDecoration(
                          hintText:
                          'Escribe aquí tus términos y condiciones...\n\nEl cliente los aceptará al confirmar una reserva.',
                          hintStyle: TextStyle(
                              color: Color(0xFF5A5D72), fontSize: 13),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Info footer
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: _kMuted, size: 14),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'El cliente verá este texto y deberá aceptarlo antes de confirmar cualquier reserva.',
                  style: TextStyle(color: _kMuted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final texto = _ctrl.text.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header tipo modal de reserva
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorde, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _kAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.visibility_rounded,
                          color: _kAccent, size: 12),
                      const SizedBox(width: 5),
                      const Text('Vista previa del cliente',
                          style: TextStyle(
                              color: _kAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                const Text('Términos y condiciones',
                    style: TextStyle(
                        color: _kTexto,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.nombreNegocio,
                    style: const TextStyle(
                        color: _kAccent, fontSize: 12)),
                const Divider(color: _kBorde, height: 24),
                if (texto.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Sin contenido todavía.\nVuelve al editor y escribe tus términos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF5A5D72), fontSize: 13),
                      ),
                    ),
                  )
                else
                  Text(
                    texto,
                    style: const TextStyle(
                        color: Color(0xFFD0D3E0),
                        fontSize: 13,
                        height: 1.7),
                  ),
                const SizedBox(height: 20),
                // Simulación del botón de aceptar
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: null, // solo preview
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('He leído y acepto los términos'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                      _kAccent.withValues(alpha: 0.3),
                      foregroundColor:
                      _kAccent.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Así verá el cliente el botón al confirmar la reserva',
                    style: TextStyle(color: _kMuted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}