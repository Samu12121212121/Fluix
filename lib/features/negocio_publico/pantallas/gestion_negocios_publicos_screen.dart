import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../models/negocio_publico_model.dart';
import 'resenas_fluix_screen.dart';
import 'terminos_condiciones_screen.dart';

const _kAzul = Color(0xFF0D47A1);
const _kOro  = Color(0xFFFFB830);
const _kMuted = Color(0xFFB0B3C1);

class GestionNegociosPublicosScreen extends StatefulWidget {
  const GestionNegociosPublicosScreen({super.key});

  @override
  State<GestionNegociosPublicosScreen> createState() =>
      _GestionNegociosPublicosScreenState();
}

class _GestionNegociosPublicosScreenState
    extends State<GestionNegociosPublicosScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  CategoriaNegocio? _categoriaFiltro;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Gestión de Negocios Públicos'),
        backgroundColor: _kAzul,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(child: _buildListaNegocios()),
        ],
      ),
    );
  }

  // ── Filtros ───────────────────────────────────────────────────────────────
  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Buscar negocios...',
              prefixIcon: const Icon(Icons.search, color: _kAzul),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFiltroChip('Todos', null),
                const SizedBox(width: 8),
                ...CategoriaNegocio.values.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFiltroChip(cat.label, cat),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, CategoriaNegocio? categoria) {
    final sel = _categoriaFiltro == categoria;
    return FilterChip(
      selected: sel,
      label: Text(label),
      onSelected: (_) => setState(() => _categoriaFiltro = categoria),
      backgroundColor: Colors.grey[100],
      selectedColor: _kAzul.withOpacity(0.15),
      labelStyle: TextStyle(
        color: sel ? _kAzul : Colors.grey[700],
        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: _kAzul,
    );
  }

  // ── Lista ─────────────────────────────────────────────────────────────────
  Widget _buildListaNegocios() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('negocios_publicos')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var negocios = snap.data!.docs
            .map((d) => NegocioPublico.fromJson(
            d.id, d.data() as Map<String, dynamic>))
            .toList();

        if (_categoriaFiltro != null) {
          negocios =
              negocios.where((n) => n.categoria == _categoriaFiltro).toList();
        }
        if (_searchQuery.isNotEmpty) {
          negocios = negocios
              .where((n) =>
          n.nombre.toLowerCase().contains(_searchQuery) ||
              (n.descripcion?.toLowerCase().contains(_searchQuery) ??
                  false))
              .toList();
        }
        if (negocios.isEmpty) return _buildEmptySearchState();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: negocios.length,
          itemBuilder: (_, i) => _buildNegocioCard(negocios[i]),
        );
      },
    );
  }

  // ── Tarjeta negocio ───────────────────────────────────────────────────────
  Widget _buildNegocioCard(NegocioPublico negocio) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Imagen
          GestureDetector(
            onTap: () => _cambiarFoto(negocio),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
                image: negocio.fotoUrl != null
                    ? DecorationImage(
                    image: NetworkImage(negocio.fotoUrl!),
                    fit: BoxFit.cover)
                    : null,
              ),
              child: Stack(
                children: [
                  if (negocio.fotoUrl == null)
                    Center(
                        child: Icon(Icons.store,
                            size: 60, color: Colors.grey[400])),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                      child: const Center(
                        child: Icon(Icons.camera_alt,
                            size: 40, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(negocio.nombre,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _kAzul)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _kAzul.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${negocio.categoria.icono} ${negocio.categoria.label}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: _kAzul,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: negocio.activo,
                      onChanged: (v) => _toggleActivo(negocio.id, v),
                      activeColor: const Color(0xFF43A047),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (negocio.ratingGoogle != null) ...[
                  Row(children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFFFFB300)),
                    const SizedBox(width: 4),
                    Text(negocio.ratingGoogle!.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(' (Google)',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600])),
                  ]),
                  const SizedBox(height: 6),
                ],
                if (negocio.descripcion != null) ...[
                  Text(negocio.descripcion!,
                      style:
                      TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                ],
                // ── Botones de acción ──────────────────────────────────────
                _AccionesNegocio(
                  negocio: negocio,
                  onCambiarFoto: _cambiarFoto,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Acciones ──────────────────────────────────────────────────────────────
  Future<void> _cambiarFoto(NegocioPublico negocio) async {
    try {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (img == null) return;
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final ref = FirebaseStorage.instance
          .ref()
          .child('negocios_publicos')
          .child('${negocio.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(img.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(negocio.id)
          .update({'fotoUrl': url});

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto actualizada'),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _toggleActivo(String negocioId, bool activo) async {
    try {
      await FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(negocioId)
          .update({'activo': activo});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(activo ? 'Negocio activado' : 'Negocio desactivado'),
        backgroundColor: activo ? Colors.green : Colors.orange,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ── Empty states ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.store_outlined, size: 80, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('No hay negocios públicos',
            style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text('Ejecuta el script de seed para agregar negocios',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('No se encontraron resultados',
            style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET ACCIONES (Foto + T&C + Resenas)
// ═══════════════════════════════════════════════════════════════════════════
class _AccionesNegocio extends StatelessWidget {
  final NegocioPublico negocio;
  final Future<void> Function(NegocioPublico) onCambiarFoto;

  const _AccionesNegocio({
    required this.negocio,
    required this.onCambiarFoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Fila 1: Foto + T&C
      Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => onCambiarFoto(negocio),
            icon: const Icon(Icons.photo_camera, size: 18),
            label: const Text('Cambiar Foto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAzul,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Términos y Condiciones',
          child: IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TerminosCondicionesScreen(
                  negocioId: negocio.id,
                  nombreNegocio: negocio.nombre,
                ),
              ),
            ),
            icon: const Icon(Icons.gavel_rounded),
            color: _kMuted,
            style: IconButton.styleFrom(
                backgroundColor: _kAzul.withOpacity(0.08)),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      // Fila 2: Resenas Fluix
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResenasFluixScreen(
                negocioId: negocio.id,
                nombreNegocio: negocio.nombre,
              ),
            ),
          ),
          icon: const Icon(Icons.star_rounded, color: _kOro, size: 18),
          label: _buildResenasLabel(negocio),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _kOro.withOpacity(0.4), width: 1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    ]);
  }

  Widget _buildResenasLabel(NegocioPublico negocio) {
    final resenas = negocio.resenasFluix ?? [];
    if (resenas.isEmpty) {
      return const Text('Añadir resenas Fluix',
          style: TextStyle(
              color: _kOro, fontWeight: FontWeight.w600, fontSize: 13));
    }
    final media =
        resenas.map((r) => r.estrellas).reduce((a, b) => a + b) /
            resenas.length;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(media.toStringAsFixed(1),
          style: const TextStyle(
              color: _kOro, fontWeight: FontWeight.bold, fontSize: 14)),
      Text(' · ${resenas.length} resena${resenas.length == 1 ? '' : 's'} Fluix',
          style: const TextStyle(color: _kOro, fontSize: 13)),
    ]);
  }
}