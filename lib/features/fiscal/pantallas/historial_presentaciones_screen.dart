import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ═════════════════════════════════════════════════════════════════════════════
// HISTORIAL DE PRESENTACIONES — Estado de modelos AEAT por períodos
// ═════════════════════════════════════════════════════════════════════════════

class HistorialPresentacionesScreen extends StatelessWidget {
  final String empresaId;

  const HistorialPresentacionesScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Presentaciones'),
        subtitle: const Text('Estado de modelos AEAT por períodos'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas')
            .doc(empresaId)
            .collection('modelos_fiscales')
            .orderBy('periodo', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmpty();
          }
          
          final docs = snapshot.data!.docs;
          final agrupados = _agruparPorPeriodo(docs);
          
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: agrupados.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              final periodo = agrupados[i];
              return _buildPeriodoCard(periodo);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Sin presentaciones registradas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Los modelos que calcules y presentes aparecerán aquí con su historial.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  List<PeriodoHistorial> _agruparPorPeriodo(List<DocumentSnapshot> docs) {
    final Map<String, PeriodoHistorial> periodos = {};
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docId = doc.id; // ej: "303_2026_Q1"
      final periodo = _extraerPeriodo(docId);
      
      if (periodo.isEmpty) continue;
      
      if (!periodos.containsKey(periodo)) {
        periodos[periodo] = PeriodoHistorial(
          periodo: periodo,
          modelos: [],
        );
      }
      
      periodos[periodo]!.modelos.add(ModeloEstado(
        codigo: _extraerModelo(docId),
        periodo: periodo,
        estado: data['estado'] as String? ?? 'calculado',
        fechaCalculo: data['fecha_calculo'] as Timestamp?,
        fechaPresentacion: data['fecha_presentacion'] as Timestamp?,
        pdfUrl: data['pdf_url'] as String?,
        justificanteUrl: data['pdf_justificante_url'] as String?,
      ));
    }
    
    // Ordenar modelos dentro de cada período
    for (final p in periodos.values) {
      p.modelos.sort((a, b) => a.codigo.compareTo(b.codigo));
    }
    
    // Convertir a lista y ordenar por período (más reciente primero)
    final lista = periodos.values.toList();
    lista.sort((a, b) => _compararPeriodos(b.periodo, a.periodo));
    
    return lista;
  }

  String _extraerPeriodo(String docId) {
    // "303_2026_Q1" -> "2026-Q1"
    // "390_2026" -> "2026"
    final parts = docId.split('_');
    if (parts.length >= 2) {
      if (parts.length == 3) {
        return '${parts[1]}-${parts[2]}'; // Trimestral
      } else {
        return parts[1]; // Anual
      }
    }
    return '';
  }

  String _extraerModelo(String docId) {
    return docId.split('_')[0];
  }

  int _compararPeriodos(String a, String b) {
    // "2026-Q4" vs "2026-Q1" vs "2025"
    final aEsAnual = !a.contains('Q');
    final bEsAnual = !b.contains('Q');
    
    if (aEsAnual && bEsAnual) {
      return int.parse(a).compareTo(int.parse(b));
    }
    
    if (aEsAnual) return -1; // Anuales van después de trimestrales del mismo año
    if (bEsAnual) return 1;
    
    final aParts = a.split('-');
    final bParts = b.split('-');
    final aAnio = int.parse(aParts[0]);
    final bAnio = int.parse(bParts[0]);
    
    if (aAnio != bAnio) return aAnio.compareTo(bAnio);
    
    final aTrim = int.parse(aParts[1].substring(1));
    final bTrim = int.parse(bParts[1].substring(1));
    return aTrim.compareTo(bTrim);
  }

  Widget _buildPeriodoCard(PeriodoHistorial periodo) {
    final esAnual = !periodo.periodo.contains('Q');
    final label = esAnual 
        ? 'Año ${periodo.periodo}'
        : '${periodo.periodo.split('-')[1]} ${periodo.periodo.split('-')[0]}';
    
    final presentados = periodo.modelos.where((m) => m.estado == 'presentado').length;
    final calculados = periodo.modelos.where((m) => m.estado == 'calculado').length;
    final total = periodo.modelos.length;
    
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: presentados == total 
              ? Colors.green.shade100 
              : calculados > 0 
                  ? Colors.orange.shade100 
                  : Colors.grey.shade100,
          child: Icon(
            esAnual ? Icons.calendar_view_year : Icons.calendar_view_month,
            color: presentados == total 
                ? Colors.green.shade700 
                : calculados > 0 
                    ? Colors.orange.shade700 
                    : Colors.grey.shade600,
          ),
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$presentados presentados · $calculados calculados · $total total',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        children: [
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: periodo.modelos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final modelo = periodo.modelos[i];
              return _buildModeloTile(modelo);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeloTile(ModeloEstado modelo) {
    final presentado = modelo.estado == 'presentado';
    final tieneJustificante = modelo.justificanteUrl?.isNotEmpty == true;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: presentado 
            ? Colors.green.shade50 
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: presentado 
              ? Colors.green.shade200 
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          // Código del modelo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: presentado 
                  ? Colors.green.shade100 
                  : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                modelo.codigo,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: presentado 
                      ? Colors.green.shade700 
                      : Colors.orange.shade700,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Info principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modelo ${modelo.codigo}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      presentado ? Icons.check_circle : Icons.pending_actions,
                      size: 14,
                      color: presentado 
                          ? Colors.green.shade700 
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      presentado ? 'Presentado' : 'Calculado',
                      style: TextStyle(
                        fontSize: 12,
                        color: presentado 
                            ? Colors.green.shade700 
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (modelo.fechaPresentacion != null || modelo.fechaCalculo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatearFecha(
                      presentado ? modelo.fechaPresentacion : modelo.fechaCalculo
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Acciones
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (modelo.pdfUrl?.isNotEmpty == true)
                IconButton(
                  onPressed: () => _abrirUrl(modelo.pdfUrl!),
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  tooltip: 'Ver PDF modelo',
                  color: Colors.red,
                ),
              if (tieneJustificante)
                IconButton(
                  onPressed: () => _abrirUrl(modelo.justificanteUrl!),
                  icon: const Icon(Icons.verified, size: 18),
                  tooltip: 'Ver justificante AEAT',
                  color: Colors.green.shade700,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatearFecha(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final fecha = timestamp.toDate();
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  void _abrirUrl(String url) async {
    // TODO: Implementar apertura de URL o descarga
    // Por ahora solo mostramos el URL
    debugPrint('Abrir URL: $url');
  }
}

class PeriodoHistorial {
  final String periodo;
  final List<ModeloEstado> modelos;

  PeriodoHistorial({
    required this.periodo,
    required this.modelos,
  });
}

class ModeloEstado {
  final String codigo;
  final String periodo;
  final String estado;
  final Timestamp? fechaCalculo;
  final Timestamp? fechaPresentacion;
  final String? pdfUrl;
  final String? justificanteUrl;

  ModeloEstado({
    required this.codigo,
    required this.periodo,
    required this.estado,
    this.fechaCalculo,
    this.fechaPresentacion,
    this.pdfUrl,
    this.justificanteUrl,
  });
}
