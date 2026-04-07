import 'package:flutter/material.dart';

import '../../../services/validador_fiscal_integral.dart';

class PanelResultadoValidacionFiscal extends StatelessWidget {
  final ValidacionFiscalResultado resultado;

  const PanelResultadoValidacionFiscal({
    super.key,
    required this.resultado,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: resultado.esValido ? Colors.green.shade50 : Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TÍTULO Y ESTADO
              Row(
                children: [
                  Icon(
                    resultado.esValido ? Icons.check_circle : Icons.error_outline,
                    color:
                        resultado.esValido ? Colors.green : Colors.red,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resultado.esValido
                              ? '✅ Factura VÁLIDA conforme a normativa'
                              : '❌ Factura INVÁLIDA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: resultado.esValido
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                        if (resultado.errores.isNotEmpty ||
                            resultado.advertencias.isNotEmpty)
                          Text(
                            resultado.esValido
                                ? 'Con ${resultado.advertencias.length} advertencia(s)'
                                : 'Con ${resultado.errores.length} error(es) crítico(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: resultado.esValido
                                  ? Colors.orange.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // ERRORES (si hay)
              if (resultado.errores.isNotEmpty) ...[
                Text(
                  'ERRORES CRÍTICOS (${resultado.errores.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                ...resultado.errores.map((error) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.close_outlined,
                          color: Colors.red.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade800,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                if (resultado.advertencias.isNotEmpty) const SizedBox(height: 12),
              ],

              // ADVERTENCIAS (si hay)
              if (resultado.advertencias.isNotEmpty) ...[
                Text(
                  'ADVERTENCIAS (${resultado.advertencias.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                ...resultado.advertencias.map((adv) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outlined,
                          color: Colors.orange.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            adv,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],

              // BOTONES DE ACCIÓN
              if (!resultado.esValido) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Mostrar detalles de normativa
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Ver detalle de normativa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ] else if (resultado.advertencias.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check),
                    label: const Text('Continuar de todas formas'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    'La factura cumple con toda la normativa fiscal española '
                    '(LGT 58/2003, RD 1619/2012, RD 1007/2023).',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo para mostrar resultado de validación fiscal
Future<void> mostrarResultadoValidacionFiscal(
  BuildContext context,
  ValidacionFiscalResultado resultado,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !resultado.esValido,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          resultado.esValido
              ? '✅ Validación Fiscal Completada'
              : '❌ Incumplimiento Detectado',
          style: TextStyle(
            color: resultado.esValido ? Colors.green : Colors.red,
          ),
        ),
        content: SingleChildScrollView(
          child: PanelResultadoValidacionFiscal(resultado: resultado),
        ),
        actions: [
          if (!resultado.esValido)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar operación'),
            ),
          if (resultado.esValido || resultado.advertencias.isNotEmpty)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
        ],
      );
    },
  );
}

/// Banner para mostrar advertencias de validación
class BannerValidacionFiscal extends StatelessWidget {
  final ValidacionFiscalResultado resultado;
  final VoidCallback? onDismiss;

  const BannerValidacionFiscal({
    super.key,
    required this.resultado,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (resultado.esValido && resultado.advertencias.isEmpty) {
      return const SizedBox.shrink();
    }

    final esError = !resultado.esValido;
    final color = esError ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            esError ? Icons.error_outline : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esError
                      ? 'Incumplimiento fiscal detectado'
                      : 'Advertencias de normativa',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  esError
                      ? 'La factura no cumple la normativa (${resultado.errores.length} error(es))'
                      : 'Revisa las advertencias antes de continuar (${resultado.advertencias.length})',
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              splashRadius: 20,
            ),
        ],
      ),
    );
  }
}


