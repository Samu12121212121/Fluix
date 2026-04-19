  void _responder(BuildContext context) {
    final ctrl = TextEditingController(text: respuesta ?? '');
    showDialog(
import 'package:url_launcher/url_launcher.dart';
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Responder a $nombre'),
        content: TextField(
          controller: ctrl, maxLines: 4,
          decoration: const InputDecoration(hintText: 'Escribe tu respuesta...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final texto = ctrl.text.trim();
              if (texto.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('empresas').doc(empresaId)
                    .collection('valoraciones').doc(docId)
                    .update({'respuesta': texto});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enviar'),
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
class ModuloValoraciones extends StatelessWidget {
  final String empresaId;
  const ModuloValoraciones({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('es', timeago.EsMessages());
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones')
          .orderBy('fecha', descending: true)
          .limit(15)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Error cargando valoraciones', style: TextStyle(fontSize: 16, color: Colors.red[600])),
            ]),
          );
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // ← Fuerza el scroll siempre
          slivers: [
            SliverToBoxAdapter(
              child: _buildResumen(validas, promedio),
            ),
            SliverPadding(
        final validas = <DocumentSnapshot>[];
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final data = validas[i].data() as Map<String, dynamic>?;
                    if (data == null) return const SizedBox.shrink();
                    return _TarjetaResena(
                      docId: validas[i].id,
                      empresaId: empresaId,
                      nombre: '${data['cliente'] ?? data['nombre_persona'] ?? 'Anónimo'}',
                      estrellas: ((data['calificacion'] ?? data['estrellas'] ?? 0) as num).toInt(),
                      comentario: '${data['comentario'] ?? ''}',
                      fecha: _parseFecha(data['fecha']),
                      respuesta: data['respuesta'] as String?,
                    );
                  },
                  childCount: validas.length,
                ),
              ),
            ),
          ],
        );

        return Column(children: [
        return Column(children: [
          _buildResumen(validas, promedio),
          Expanded(
            child: ListView.builder(
                if (data == null) return const SizedBox.shrink();
                return _TarjetaResena(
                  docId: validas[i].id,
                  empresaId: empresaId,
              itemCount: validas.length,
              itemBuilder: (context, i) {
                final data = validas[i].data() as Map<String, dynamic>?;
                if (data == null) return const SizedBox.shrink();
                return _TarjetaResena(
                  docId: validas[i].id,
                  empresaId: empresaId,
                  nombre: '${data['cliente'] ?? data['nombre_persona'] ?? 'Anónimo'}',
                  estrellas: ((data['calificacion'] ?? data['estrellas'] ?? 0) as num).toInt(),
                  comentario: '${data['comentario'] ?? ''}',
                  fecha: _parseFecha(data['fecha']),
                  respuesta: data['respuesta'] as String?,
                );
              },
            ),
          ),
        ]);
          Row(
            children: List.generate(5, (i) => Icon(
              i < promedio.round() ? Icons.star : Icons.star_border,
              color: const Color(0xFFF57C00), size: 18,
            )),
          ),
        ]),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${validas.length} reseñas', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Google Reviews', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 4),
            ...List.generate(5, (i) {
              final stars = 5 - i;
              final count = validas.where((doc) {
                final d = doc.data() as Map<String, dynamic>?;
                if (d == null) return false;
                return ((d['calificacion'] ?? d['estrellas'] ?? 0) as num).toInt() == stars;
              }).length;
              final pct = validas.isEmpty ? 0.0 : count / validas.length;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(children: [
                  Text('$stars', style: const TextStyle(fontSize: 11)),
                  const Icon(Icons.star, size: 10, color: Color(0xFFF57C00)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF57C00)),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(width: 18, child: Text('$count', style: const TextStyle(fontSize: 11))),
                ]),
              );
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('Aún no hay valoraciones', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Text('Las reseñas aparecerán aquí cuando los clientes las dejen',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ]),
    );
  }

  static DateTime _parseFecha(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}

// ── TARJETA ────────────────────────────────────────────────────────────────────

class _TarjetaResena extends StatelessWidget {
  final String docId;
  final String empresaId;
  final String nombre;
  final int estrellas;
  final String comentario;
  final DateTime fecha;
  final String? respuesta;

  const _TarjetaResena({
    required this.docId,
    required this.empresaId,
    required this.nombre,
    required this.estrellas,
    required this.comentario,
    required this.fecha,
    this.respuesta,
  });

  @override
  Widget build(BuildContext context) {
    final iniciales = nombre.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0]).join().toUpperCase();
    final colorAvatar = _color(nombre);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorAvatar,
              child: Text(iniciales,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Row(children: [
                  ...List.generate(5, (i) => Icon(
                    i < estrellas ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF57C00), size: 14,
                  )),
                  const SizedBox(width: 6),
                  Text(timeago.format(fecha, locale: 'es'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Text(comentario, style: const TextStyle(fontSize: 13.5, height: 1.4)),
          if (respuesta != null && respuesta!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            child: ElevatedButton.icon(
              onPressed: () => _abrirGoogleBusiness(context),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Responder en Google', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4), // Azul de Google
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 2,
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _responder(context),
              icon: Icon(respuesta != null ? Icons.edit : Icons.reply, size: 16),
              label: Text(respuesta != null ? 'Editar respuesta' : 'Responder',
                  style: const TextStyle(fontSize: 13)),
  Future<void> _abrirGoogleBusiness(BuildContext context) async {
    final url = Uri.parse('https://business.google.com/reviews');
    
    try {
      final canLaunch = await canLaunchUrl(url);
      if (canLaunch) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication, // Abre en navegador externo
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No se puede abrir el navegador'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al abrir: $e'),
            backgroundColor: Colors.red,
        ],
        );
      }
    }
                    .update({'respuesta': texto});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Color _color(String name) {
    const cols = [
      Color(0xFF1976D2), Color(0xFF388E3C), Color(0xFF7B1FA2),
      Color(0xFFF57C00), Color(0xFFD32F2F), Color(0xFF00BCD4),
      Color(0xFF5D4037), Color(0xFF689F38), Color(0xFFE91E63),
    ];
    return cols[name.codeUnits.fold(0, (a, b) => a + b) % cols.length];
  }
}
