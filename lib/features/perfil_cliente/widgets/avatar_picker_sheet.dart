import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

const _kBg     = Color(0xFF0A0F23);
const _kCard   = Color(0xFF1E2139);
const _kAccent = Color(0xFF00FFC8);
const _kTexto  = Color(0xFFFFFFFF);
const _kMuted  = Color(0xFFB0B3C1);

const kAvatarEmojis = ['🦊','🐺','🦁','🐸','🦋','🐙','🦄','🐼','🎭','🏄','🎸','🚀','⚡','🌈','🍀'];
const kAvatarGradients = [
  [Color(0xFF00FFC8), Color(0xFF00D9FF)],
  [Color(0xFFFF3296), Color(0xFFFF8C42)],
  [Color(0xFF7B2FBE), Color(0xFF3F8EFC)],
  [Color(0xFF56CCF2), Color(0xFF2F80ED)],
  [Color(0xFFF7971E), Color(0xFFFFD200)],
  [Color(0xFF11998E), Color(0xFF38EF7D)],
  [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
  [Color(0xFF4CAF50), Color(0xFF8BC34A)],
];

class AvatarPickerSheet extends StatefulWidget {
  final int gradientIndex;
  final String? emojiActual;
  final String? fotoUrlActual;
  final void Function(int grad, String? emoji, String? fotoUrl) onGuardar;

  const AvatarPickerSheet({
    super.key,
    required this.gradientIndex,
    required this.emojiActual,
    this.fotoUrlActual,
    required this.onGuardar,
  });

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  late int _grad;
  String? _emoji, _fotoUrl;
  bool _subiendo = false;

  @override
  void initState() {
    super.initState();
    _grad = widget.gradientIndex;
    _emoji = widget.emojiActual;
    _fotoUrl = widget.fotoUrlActual;
  }

  Future<void> _subirFoto() async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (imagen == null) return;
    setState(() => _subiendo = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('No autenticado');
      final ref = FirebaseStorage.instance.ref('avatares/$uid.jpg');
      // FIX: establecer contentType explícito para que pase la regla de Storage
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putFile(File(imagen.path), metadata);
      final url = await ref.getDownloadURL();
      setState(() { _fotoUrl = url; _emoji = null; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir foto: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewGrad = _kAvatarGradients(_grad);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Personaliza tu avatar', style: TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        // Preview
        Stack(alignment: Alignment.bottomRight, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(gradient: _fotoUrl == null ? LinearGradient(colors: previewGrad) : null, shape: BoxShape.circle),
            child: _fotoUrl != null
                ? ClipOval(child: Image.network(_fotoUrl!, width: 80, height: 80, fit: BoxFit.cover))
                : Center(child: _emoji != null
                    ? Text(_emoji!, style: const TextStyle(fontSize: 38))
                    : const Text('A', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _kBg))),
          ),
          if (_fotoUrl != null)
            GestureDetector(
              onTap: () => setState(() => _fotoUrl = null),
              child: Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: _kCard, width: 1.5)),
                child: const Icon(Icons.close, size: 12, color: Colors.white)),
            ),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _subiendo ? null : _subirFoto,
          icon: _subiendo
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent))
              : const Icon(Icons.photo_library_outlined, size: 16, color: _kAccent),
          label: Text(_subiendo ? 'Subiendo...' : 'Subir foto de galería', style: const TextStyle(color: _kAccent, fontSize: 13)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: _kAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
        )),
        const SizedBox(height: 14),
        const Align(alignment: Alignment.centerLeft, child: Text('Color de fondo', style: TextStyle(color: _kMuted, fontSize: 12))),
        const SizedBox(height: 8),
        SizedBox(height: 44, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: kAvatarGradients.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => setState(() { _grad = i; _fotoUrl = null; }),
            child: Container(
              width: 38, height: 38, margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: kAvatarGradients[i]), shape: BoxShape.circle,
                border: _grad == i && _fotoUrl == null ? Border.all(color: _kAccent, width: 2.5) : null,
              ),
            ),
          ),
        )),
        const SizedBox(height: 14),
        const Align(alignment: Alignment.centerLeft, child: Text('Emoji (opcional)', style: TextStyle(color: _kMuted, fontSize: 12))),
        const SizedBox(height: 8),
        SizedBox(height: 96, child: GridView.count(
          crossAxisCount: 8, crossAxisSpacing: 6, mainAxisSpacing: 6,
          children: [
            GestureDetector(
              onTap: () => setState(() => _emoji = null),
              child: Container(decoration: BoxDecoration(color: _kCard, shape: BoxShape.circle,
                border: _emoji == null ? Border.all(color: _kAccent, width: 2) : Border.all(color: Colors.white12)),
                child: const Center(child: Text('A', style: TextStyle(color: _kBg, fontWeight: FontWeight.bold, fontSize: 14)))),
            ),
            ...kAvatarEmojis.map((e) => GestureDetector(
              onTap: () => setState(() { _emoji = e; _fotoUrl = null; }),
              child: Container(decoration: BoxDecoration(color: _kCard, shape: BoxShape.circle,
                border: _emoji == e ? Border.all(color: _kAccent, width: 2) : Border.all(color: Colors.white12)),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 20)))),
            )),
          ],
        )),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: () => widget.onGuardar(_grad, _emoji, _fotoUrl),
          style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg),
          child: const Text('Guardar avatar', style: TextStyle(fontWeight: FontWeight.w700)),
        )),
      ]),
    );
  }

  List<Color> _kAvatarGradients(int idx) => kAvatarGradients[idx.clamp(0, kAvatarGradients.length - 1)];
}
