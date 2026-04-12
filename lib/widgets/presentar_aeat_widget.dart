import 'package:flutter/material.dart';
import '../services/fiscal/sede_aeat_urls.dart';

/// Widget reutilizable para modelos que se presentan online en Sede AEAT.
/// Muestra guía paso a paso + botón "Ir a Sede AEAT" + campo justificante.
class PresentarAeatWidget extends StatefulWidget {
  final String modelo;       // "303", "130", "390", "202"
  final String urlAeat;
  final String? justificanteInicial;
  final ValueChanged<String>? onJustificanteGuardado;

  const PresentarAeatWidget({
    super.key,
    required this.modelo,
    required this.urlAeat,
    this.justificanteInicial,
    this.onJustificanteGuardado,
  });

  @override
  State<PresentarAeatWidget> createState() => _PresentarAeatWidgetState();
}

class _PresentarAeatWidgetState extends State<PresentarAeatWidget> {
  late TextEditingController _justificanteCtrl;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _justificanteCtrl = TextEditingController(text: widget.justificanteInicial ?? '');
  }

  @override
  void dispose() {
    _justificanteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                Icon(Icons.open_in_browser, color: Colors.indigo.shade700, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Presentar Modelo ${widget.modelo} en AEAT',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'El Modelo ${widget.modelo} se presenta online en la Sede Electrónica '
                'de la AEAT. Usa el borrador calculado por Fluix para introducir '
                'los datos en el formulario oficial.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
              ),
            ),
            const SizedBox(height: 16),

            // Pasos
            _paso(1, 'Genera el borrador desde Fluix (botón "Ver borrador PDF")',
                Icons.picture_as_pdf),
            _paso(2, 'Abre la Sede AEAT con el botón de abajo',
                Icons.open_in_browser),
            _paso(3, 'Introduce los datos del borrador en el formulario online',
                Icons.edit_note),
            _paso(4, 'Firma y envía con tu certificado digital o Cl@ve PIN',
                Icons.verified_user),
            _paso(5, 'Guarda el nº de justificante aquí abajo',
                Icons.save),
            const SizedBox(height: 16),

            // Botón Sede AEAT
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => SedeAeatUrls.abrir(widget.urlAeat),
                icon: const Icon(Icons.open_in_browser, size: 20),
                label: Text('Ir a Sede AEAT — Modelo ${widget.modelo}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Campo justificante
            const Divider(),
            const SizedBox(height: 8),
            Text('Nº justificante AEAT',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _justificanteCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ej: 12345678901234',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _guardando
                      ? null
                      : () {
                          final valor = _justificanteCtrl.text.trim();
                          if (valor.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Introduce el nº de justificante AEAT antes de marcar como presentado'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setState(() => _guardando = true);
                          widget.onJustificanteGuardado?.call(valor);
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (mounted) setState(() => _guardando = false);
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  child: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Presentado ✓'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paso(int numero, String texto, IconData icono) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$numero',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700)),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icono, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }
}


