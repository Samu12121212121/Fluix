part of '../modulo_app_screen.dart';

extension _SecIdentidadContacto on _ModuloAppScreenState {

  Widget _buildIdentidad() => Column(children: [
    _Seccion(icono: Icons.storefront_outlined, titulo: 'Nombre e imagen',
      child: Column(children: [
        _InputIcon(ctrl: _nombreCtrl,      icon: Icons.store_outlined,     label: 'Nombre comercial *',   hint: 'Ej: Peluquería Lucía'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _nombreLegalCtrl, icon: Icons.business_outlined,  label: 'Nombre legal',          hint: 'Ej: Lucía García S.L.'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _descCortaCtrl,   icon: Icons.short_text_rounded, label: 'Descripción corta',    hint: 'Una línea en Explorar'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _taglineCtrl,     icon: Icons.format_quote_rounded, label: 'Tagline / Slogan',   hint: 'Tu frase diferenciadora'),
        const SizedBox(height: 12),
        _buildMiniaturasFotos(),
      ])),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.category_outlined, titulo: 'Categoría y clasificación',
      child: Column(children: [
        _buildSelectorCategoria(),
        const SizedBox(height: 12),
        _buildChipListField('Subcategorías', _subcategorias,
            (v) => setState(() => _subcategorias.add(v)),
            (v) => setState(() => _subcategorias.remove(v))),
        const SizedBox(height: 12),
        _buildChipListField('Etiquetas', _etiquetas,
            (v) => setState(() => _etiquetas.add(v)),
            (v) => setState(() => _etiquetas.remove(v))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Año de apertura', style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: _anioApertura?.toString(),
              keyboardType: TextInputType.number,
              style: TextStyle(color: _kTexto, fontSize: 13),
              decoration: _dec('Ej: 2018'),
              onChanged: (v) => _anioApertura = int.tryParse(v),
            ),
          ])),
        ]),
      ])),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.people_outlined, titulo: 'Público y detalle',
      child: Column(children: [
        _buildChipListField('Idiomas hablados', _idiomas,
            (v) => setState(() => _idiomas.add(v)),
            (v) => setState(() => _idiomas.remove(v)),
            sugerencias: ['Español','Inglés','Francés','Alemán','Árabe','Catalán']),
        const SizedBox(height: 12),
        _buildChipListField('Público objetivo', _publicoObjetivo,
            (v) => setState(() => _publicoObjetivo.add(v)),
            (v) => setState(() => _publicoObjetivo.remove(v)),
            sugerencias: ['Hombres','Mujeres','Niños','Familias','Senior','Todos']),
        const SizedBox(height: 12),
        _InputIcon(ctrl: _descCtrl, icon: Icons.description_outlined,
            label: 'Descripción completa', hint: 'Cuéntale todo al cliente…'),
        const SizedBox(height: 10),
        TextField(
          initialValue: _videoUrl,
          style: TextStyle(color: _kTexto, fontSize: 13),
          decoration: _dec('URL vídeo de presentación (YouTube…)').copyWith(
              prefixIcon: Icon(Icons.play_circle_outlined, color: _kAccent, size: 18)),
          onChanged: (v) => _videoUrl = v.trim().isEmpty ? null : v.trim(),
        ),
        const SizedBox(height: 12),
        _buildCaracteristicas(),
      ])),
  ]);

  Widget _buildMiniaturasFotos() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Imágenes del perfil', style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        _miniImgBtn('Portada',  _fotos.isNotEmpty ? _fotos.first : null, Icons.image_outlined,         () => _subirFoto()),
        const SizedBox(width: 10),
        _miniImgBtn('Logo',     _logoUrl,   Icons.business_center_outlined, () async { final u = await _subirImgExtra('logo');   if (u != null) setState(() => _logoUrl   = u); }),
        const SizedBox(width: 10),
        _miniImgBtn('Avatar',   _avatarUrl, Icons.person_outline_rounded,   () async { final u = await _subirImgExtra('avatar'); if (u != null) setState(() => _avatarUrl = u); }),
      ]),
    ],
  );

  Widget _miniImgBtn(String label, String? url, IconData icon, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: Column(children: [
        Container(width: 64, height: 64,
          decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAccent.withValues(alpha: 0.4), width: 1.2),
            image: (url != null && url.isNotEmpty)
                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null),
          child: (url == null || url.isEmpty) ? Icon(icon, color: _kAccent, size: 22) : null),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: _kMuted, fontSize: 10)),
      ]));

  Future<String?> _subirImgExtra(String tipo) async {
    if (_negocioId == null) { await _guardar(); if (_negocioId == null) return null; }
    Uint8List? bytes; String ext = 'jpg';
    try {
      final esDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
      if (esDesktop) {
        final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
        if (r == null || r.files.isEmpty) return null;
        bytes = r.files.first.bytes; ext = r.files.first.extension ?? 'jpg';
      } else {
        final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
        if (img == null) return null;
        bytes = await img.readAsBytes(); ext = img.path.split('.').last;
      }
      if (bytes == null) return null;
      final ref = FirebaseStorage.instance.ref('negocios_publicos/$_negocioId/$tipo/${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) { _snack('Error: $e', error: true); return null; }
  }

  Widget _buildSelectorCategoria() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Categoría principal', style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: _categorias.map((c) {
        final sel = _categoria == c.$1;
        return GestureDetector(
          onTap: () => setState(() => _categoria = c.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? _kAccent : _kCard2, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? _kAccent : _kBorde, width: sel ? 0 : 0.8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(c.$2, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(c.$3, style: TextStyle(color: sel ? _kBg : _kTexto, fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        );
      }).toList()),
    ],
  );

  Widget _buildContactoCompleto() => _Seccion(
    icono: Icons.contact_phone_outlined, titulo: 'Contacto y Redes Sociales',
    subtitulo: 'Aparecen en el perfil público',
    child: Column(children: [
      Text('Contacto directo', style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      _InputIcon(ctrl: _waCtrl,           icon: Icons.phone_outlined,        label: 'WhatsApp',              hint: '+34 612 345 678'),
      const SizedBox(height: 10),
      _InputIcon(ctrl: _emailPublicoCtrl, icon: Icons.email_outlined,        label: 'Email público',          hint: 'hola@tunegocio.com'),
      const SizedBox(height: 10),
      _InputIcon(ctrl: _emailCtrl,        icon: Icons.notifications_outlined, label: 'Email notificaciones',  hint: 'reservas@tunegocio.com'),
      const SizedBox(height: 10),
      _InputIcon(ctrl: _webCtrl,          icon: Icons.language_outlined,     label: 'Sitio web',              hint: 'https://tu-negocio.com'),
      const SizedBox(height: 16),
      Text('Redes sociales', style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      _InputIcon(ctrl: _igCtrl,           icon: Icons.camera_alt_outlined,   label: 'Instagram',              hint: '@tu_negocio'),
      const SizedBox(height: 10),
      _InputIcon(ctrl: _fbCtrl,           icon: Icons.facebook,              label: 'Facebook',                hint: 'facebook.com/tu-negocio'),
      const SizedBox(height: 10),
      _InputIcon(ctrl: _tiktokCtrl,       icon: Icons.music_note_outlined,   label: 'TikTok',                 hint: '@tu_negocio'),
      const SizedBox(height: 10),
      _InputIcon(ctrl: _youtubeCtrl,      icon: Icons.play_circle_outlined,  label: 'YouTube',                hint: 'youtube.com/@canal'),
    ]),
  );
}
