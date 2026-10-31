import 'dart:io';
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:xml/xml.dart' as xml;
import 'package:flutter/material.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/widgets/flux_toast.dart';
import '../../../models/negocio_publico_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IMPORTADOR DE NEGOCIOS DESDE EXCEL (.xlsx con el formato de ficha Fluix)
// Pantalla accesible desde GestionNegociosScreen (rol propietario).
//
// Hojas que lee: Info | Contacto | Horario | Servicios | Extras | Formulario
// Estructura: cada hoja tiene CAMPO | VALOR | NOTAS (fila 1 = cabecera)
// Los servicios se importan a negocios_publicos/{id}/servicios
// ─────────────────────────────────────────────────────────────────────────────

class ImportarNegocioExcelScreen extends StatefulWidget {
  /// Si se proporciona [negocioId], el importador actualiza ese documento
  /// en lugar de crear uno nuevo. Útil desde el panel de edición de un negocio.
  final String? negocioId;
  final String? nombreNegocio;

  const ImportarNegocioExcelScreen({
    super.key,
    this.negocioId,
    this.nombreNegocio,
  });

  @override
  State<ImportarNegocioExcelScreen> createState() =>
      _ImportarNegocioExcelScreenState();
}

class _ImportarNegocioExcelScreenState
    extends State<ImportarNegocioExcelScreen> {
  // ── Estado ─────────────────────────────────────────────────────────────────
  bool _cargando = false;
  bool _importando = false;
  _NegocioParseado? _parseado;
  String? _error;

  static const _kPurple = Color(0xFF7C3AED);

  // ── Seleccionar y parsear fichero ────────────────────────────────────────
  Future<void> _seleccionarFichero() async {
    setState(() { _cargando = true; _error = null; _parseado = null; });
    try {
      // withData:true en Windows/iOS causa deadlock en el isolate de FilePicker.
      // Solo activarlo en web (donde no hay acceso a path).
      // withData:true en Windows/macOS/Linux puede causar problemas; en Android y web es la única vía fiable
      final esDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: kIsWeb || !esDesktop, // web + móvil usan bytes; desktop usa path
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _cargando = false);
        return;
      }

      final file = result.files.first;
      List<int>? bytes;

      // Prioridad: bytes en memoria; fallback: leer desde path
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        setState(() { _error = 'No se pudo leer el fichero. Inténtalo de nuevo.'; _cargando = false; });
        return;
      }

      _NegocioParseado? parsed;
      // Envolver en try separado para distinguir errores de parsing del paquete excel
      try {
        parsed = _parsearExcel(bytes);
      } catch (parseErr, st) {
        debugPrint('[Excel import] Parse error: $parseErr\n$st');
        setState(() {
          _error = 'Error al interpretar el fichero Excel: $parseErr\n\n'
              'Asegúrate de que es un .xlsx en formato "ficha Fluix".';
          _cargando = false;
        });
        return;
      }
      setState(() { _parseado = parsed; _cargando = false; });
    } catch (e) {
      setState(() { _error = 'Error leyendo el fichero: $e'; _cargando = false; });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PARSER XLSX PROPIO — usa archive (descomprimir ZIP) + xml (leer XML)
  // No depende del paquete 'excel' que tiene bugs de null-check en v3/v4.
  // Un .xlsx es un ZIP que contiene:
  //   xl/sharedStrings.xml   → tabla de strings compartidos
  //   xl/workbook.xml        → lista de hojas con sus nombres y rId
  //   xl/_rels/workbook.xml.rels → mapea rId → ruta de archivo
  //   xl/worksheets/sheet*.xml → datos de celdas
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convierte columna Excel letra(s) a índice 0-based: A→0, B→1, Z→25, AA→26
  static int _colToIdx(String col) {
    int idx = 0;
    for (final c in col.toUpperCase().runes) {
      idx = idx * 26 + (c - 65 + 1);
    }
    return idx - 1;
  }

  /// Extrae el texto de una fila dado índice de columna, usando sharedStrings
  static String? _getText(
    List<xml.XmlElement> cellsInRow,
    int colIdx,
    List<String> ss,
  ) {
    try {
      for (final cell in cellsInRow) {
        final ref = cell.getAttribute('r') ?? '';
        // ref = "A2", "B2", etc. — extraer la parte de letras
        final colStr = ref.replaceAll(RegExp(r'[0-9]'), '');
        if (_colToIdx(colStr) != colIdx) continue;

        final t = cell.getAttribute('t') ?? '';
        if (t == 's') {
          // Shared string
          final vEl = cell.findElements('v').firstOrNull;
          final idxStr = vEl?.innerText.trim() ?? '';
          final i = int.tryParse(idxStr);
          if (i != null && i < ss.length) return ss[i].trim().nullIfEmpty;
        } else if (t == 'inlineStr') {
          final tEl = cell.findAllElements('t').firstOrNull;
          return tEl?.innerText.trim().nullIfEmpty;
        } else {
          // Número u otro tipo — devolver como texto
          final vEl = cell.findElements('v').firstOrNull;
          final s = vEl?.innerText.trim() ?? '';
          return s.nullIfEmpty;
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Parser del Excel ─────────────────────────────────────────────────────
  _NegocioParseado _parsearExcel(List<int> bytes) {
    // 1. Descomprimir el ZIP
    final archive = ZipDecoder().decodeBytes(bytes);

    // Mapa rápido de nombre de archivo → contenido XML
    Map<String, String> getFile(String path) {
      final f = archive.findFile(path);
      return f != null ? {path: String.fromCharCodes(f.content as List<int>)} : {};
    }

    String? rawFile(String path) {
      final f = archive.findFile(path);
      if (f == null) return null;
      return String.fromCharCodes(f.content as List<int>);
    }

    // 2. Shared strings
    final List<String> sharedStrings = [];
    final ssRaw = rawFile('xl/sharedStrings.xml');
    if (ssRaw != null) {
      try {
        final ssDoc = xml.XmlDocument.parse(ssRaw);
        for (final si in ssDoc.findAllElements('si')) {
          // Concatenar todos los <t> dentro de <si> (para rich text)
          final text = si.findAllElements('t').map((t) => t.innerText).join('');
          sharedStrings.add(text);
        }
      } catch (_) {}
    }

    // 3. Mapear nombre de hoja → archivo worksheet
    final Map<String, String> sheetNameToFile = {};
    final wbRaw = rawFile('xl/workbook.xml');
    final relsRaw = rawFile('xl/_rels/workbook.xml.rels');
    if (wbRaw != null && relsRaw != null) {
      try {
        final wbDoc = xml.XmlDocument.parse(wbRaw);
        final relsDoc = xml.XmlDocument.parse(relsRaw);
        // rId → target (ruta relativa al archivo xl/)
        final ridToTarget = <String, String>{};
        for (final rel in relsDoc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id') ?? '';
          final target = rel.getAttribute('Target') ?? '';
          if (id.isNotEmpty) ridToTarget[id] = target;
        }
        // nombre de hoja → archivo
        for (final sheet in wbDoc.findAllElements('sheet')) {
          final name = sheet.getAttribute('name') ?? '';
          final rId = sheet.getAttribute('r:id') ??
              sheet.getAttribute('relationships:id') ?? '';
          final target = ridToTarget[rId] ?? '';
          if (name.isNotEmpty && target.isNotEmpty) {
            // Normalizar target a ruta dentro del ZIP:
            // "/xl/worksheets/sheet1.xml" → "xl/worksheets/sheet1.xml"
            // "../worksheets/sheet1.xml"  → "xl/worksheets/sheet1.xml"
            // "worksheets/sheet1.xml"     → "xl/worksheets/sheet1.xml"
            String path = target;
            if (path.startsWith('/')) {
              path = path.substring(1); // quitar slash inicial
            } else if (path.startsWith('../')) {
              path = 'xl/${path.replaceAll('../', '')}';
            } else if (!path.startsWith('xl/')) {
              path = 'xl/$path';
            }
            sheetNameToFile[name] = path;
          }
        }
      } catch (_) {}
    }

    // 4. Leer una hoja como lista de filas (cada fila = lista de strings por columna)
    List<List<String?>> _leerHoja(String nombre) {
      final path = sheetNameToFile[nombre];
      if (path == null) return [];
      final raw = rawFile(path);
      if (raw == null) return [];
      try {
        final doc = xml.XmlDocument.parse(raw);
        final rows = <List<String?>>[];
        for (final rowEl in doc.findAllElements('row')) {
          final cells = rowEl.findElements('c').toList();
          if (cells.isEmpty) continue;
          // Encontrar el máximo índice de columna en esta fila
          int maxCol = 0;
          for (final c in cells) {
            final ref = c.getAttribute('r') ?? '';
            final colStr = ref.replaceAll(RegExp(r'[0-9]'), '');
            if (colStr.isNotEmpty) {
              final idx = _colToIdx(colStr);
              if (idx > maxCol) maxCol = idx;
            }
          }
          final row = List<String?>.filled(maxCol + 1, null);
          for (final c in cells) {
            final ref = c.getAttribute('r') ?? '';
            final colStr = ref.replaceAll(RegExp(r'[0-9]'), '');
            if (colStr.isEmpty) continue;
            final colIdx = _colToIdx(colStr);
            row[colIdx] = _getText([c], colIdx, sharedStrings);
          }
          rows.add(row);
        }
        return rows;
      } catch (_) {
        return [];
      }
    }

    // Helper: extrae valor de columna de una fila
    String? _val(List<String?> row, int col) {
      if (col >= row.length) return null;
      final v = row[col]?.trim();
      return (v == null || v.isEmpty || v == 'null') ? null : v;
    }

    // 5. Lee hojas CAMPO|VALOR (columna 0 = campo, columna 1 = valor)
    Map<String, String?> _leerHojaCampoValor(String nombre) {
      final rows = _leerHoja(nombre);
      final mapa = <String, String?>{};
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        final campo = _val(row, 0) ?? '';
        final valor = _val(row, 1);
        if (campo.isEmpty || campo == 'CAMPO' ||
            campo.startsWith('NOTA') || campo.startsWith('IMPORTANTE') ||
            campo.startsWith('PENDIENTE')) continue;
        mapa[campo] = valor;
      }
      return mapa;
    }

    final info    = _leerHojaCampoValor('Info');
    final contact = _leerHojaCampoValor('Contacto');
    final extras  = _leerHojaCampoValor('Extras');
    final form    = _leerHojaCampoValor('Formulario');

    // ── Horario ──────────────────────────────────────────────────────────────
    final horariosRaw = <Map<String, String?>>[];
    final rowsHor = _leerHoja('Horario');
    for (int i = 1; i < rowsHor.length; i++) {
      final row = rowsHor[i];
      if (row.isEmpty) continue;
      final dia = _val(row, 0) ?? '';
      if (dia.isEmpty || dia == 'DÍA' || dia == 'DIA' ||
          dia.startsWith('IMPORTANTE') || dia.startsWith('D')) continue;
      horariosRaw.add({
        'dia':       dia,
        'abierto':   _val(row, 1),
        'apertura1': _val(row, 2),
        'cierre1':   _val(row, 3),
        'apertura2': _val(row, 4),
        'cierre2':   _val(row, 5),
      });
    }

    // ── Servicios ────────────────────────────────────────────────────────────
    final servicios = <Map<String, String?>>[];
    final rowsSvc = _leerHoja('Servicios');
    for (int i = 1; i < rowsSvc.length; i++) {
      final row = rowsSvc[i];
      if (row.isEmpty) continue;
      final nombre = _val(row, 0) ?? '';
      if (nombre.isEmpty || nombre == 'NOMBRE DEL SERVICIO' || nombre == 'NOTA') continue;
      servicios.add({
        'nombre':      nombre,
        'descripcion': _val(row, 1),
        'categoria':   _val(row, 2),
        'precio':      _val(row, 3),
        'duracion':    _val(row, 5),
        'activo':      _val(row, 7) ?? 'Sí',
      });
    }

    // ── Mapeo → NegocioParseado ────────────────────────────────────────────
    final nombre = info['Nombre del negocio'];
    final catText = info['Categoría'] ?? '';
    final categoria = _parsearCategoria(catText);

    // Rating: "4,9/5 (359 reseñas...)" → 4.9
    final ratingRaw = info['Rating de Google'] ?? '';
    final ratingMatch = RegExp(r'(\d+)[,.](\d+)').firstMatch(ratingRaw);
    final rating = ratingMatch != null
        ? double.tryParse('${ratingMatch.group(1)}.${ratingMatch.group(2)}')
        : null;
    final resenasMatch = RegExp(r'(\d+)').firstMatch(info['Número de reseñas'] ?? '');
    final numResenas = resenasMatch != null ? int.tryParse(resenasMatch.group(1)!) : null;

    // Especialidades → list
    final espRaw = info['Especialidades'] ?? '';
    final especialidades = espRaw.isNotEmpty
        ? espRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    // Horarios → mapa
    final Map<String, Map<String, dynamic>> horario = {};
    const dias = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
    for (final h in horariosRaw) {
      final diaKey = h['dia'] ?? '';
      final prefix = diaKey.length >= 2 ? diaKey.toLowerCase().substring(0, 2) : diaKey.toLowerCase();
      final normalizado = prefix.isEmpty ? diaKey : dias.firstWhere(
        (d) => d.toLowerCase().startsWith(prefix),
        orElse: () => diaKey,
      );
      final abierto = h['abierto']?.toLowerCase() == 'sí' ||
          h['abierto']?.toLowerCase() == 'si';
      horario[normalizado] = {
        'abierto': abierto,
        'apertura': h['apertura1'] ?? '',
        'cierre': h['cierre1'] ?? '',
        'apertura2': h['apertura2'],
        'cierre2': h['cierre2'],
      };
    }

    return _NegocioParseado(
      nombre: nombre ?? '',
      tagline: info['Slogan / Tagline'],
      descripcion: info['Descripción'],
      categoria: categoria,
      categoriaTexto: catText,
      especialidades: especialidades,
      ratingGoogle: rating,
      numResenas: numResenas,
      // Contacto
      direccion: contact['Dirección'],
      telefono: contact['Teléfono'],
      whatsapp: contact['WhatsApp'],
      emailPublico: contact['Email público'],
      emailNotif: contact['Email de notificaciones'],
      web: contact['Página web'],
      instagram: contact['Instagram'],
      facebook: contact['Facebook'],
      googleMapsUrl: contact['URL de Google Maps'],
      // Horario
      horario: horario,
      // Extras
      aceptaTarjeta: _parseBool(extras['Acepta tarjeta']),
      tieneParking: _parseBool(extras['Parking']),
      accesible: _parseBool(extras['Accesible en silla de ruedas']),
      tieneWifi: _parseBool(extras['WiFi']),
      admiteMascotas: _parseBool(extras['Admite mascotas']),
      tieneTerraza: _parseBool(extras['Terraza']),
      // Formulario
      formularioTitulo: form['Título del formulario'],
      formularioBoton: form['Texto del botón'],
      // Servicios
      servicios: servicios,
    );
  }

  static CategoriaNegocio _parsearCategoria(String texto) {
    final t = texto.toLowerCase().replaceAll('é', 'e').replaceAll('á', 'a')
        .replaceAll('ó', 'o').replaceAll('í', 'i').replaceAll('ú', 'u');
    if (t.contains('estetica') || t.contains('belleza')) return CategoriaNegocio.esteticas;
    if (t.contains('peluqueria')) return CategoriaNegocio.peluquerias;
    if (t.contains('barberia')) return CategoriaNegocio.barberias;
    if (t.contains('restaurante')) return CategoriaNegocio.restaurantes;
    if (t.contains('cafeteria') || t.contains('cafe')) return CategoriaNegocio.cafeterias;
    if (t.contains('carniceria')) return CategoriaNegocio.carnicerias;
    if (t.contains('fruteria')) return CategoriaNegocio.fruterias;
    if (t.contains('tatuaje')) return CategoriaNegocio.tatuajes;
    if (t.contains('clinica') || t.contains('medic') || t.contains('salud')) return CategoriaNegocio.clinicas;
    if (t.contains('gimnasio') || t.contains('gym')) return CategoriaNegocio.gimnasios;
    if (t.contains('hotel') || t.contains('alojamiento')) return CategoriaNegocio.hoteles;
    if (t.contains('tienda') || t.contains('comercio')) return CategoriaNegocio.tiendas;
    return CategoriaNegocio.general;
  }

  static bool? _parseBool(String? v) {
    if (v == null) return null;
    final l = v.toLowerCase();
    if (l == 'sí' || l == 'si' || l == 'true' || l == '1') return true;
    if (l == 'no' || l == 'false' || l == '0') return false;
    return null;
  }

  // ── Importar a Firestore ─────────────────────────────────────────────────
  Future<void> _importar() async {
    final p = _parseado;
    if (p == null) return;
    setState(() => _importando = true);
    try {
      final db = FirebaseFirestore.instance;
      final modoActualizar = widget.negocioId != null && widget.negocioId!.isNotEmpty;
      final docRef = modoActualizar
          ? db.collection('negocios_publicos').doc(widget.negocioId)
          : db.collection('negocios_publicos').doc();

      // Construir el mapa para Firestore
      final data = <String, dynamic>{
        'nombre': p.nombre,
        'categoria': p.categoria.name,
        'activo': true,
        'empresaIdVinculada': '',
        if (p.tagline?.isNotEmpty == true) 'tagline': p.tagline,
        if (p.descripcion?.isNotEmpty == true) 'descripcion': p.descripcion,
        if (p.especialidades.isNotEmpty) 'especialidades': p.especialidades,
        if (p.ratingGoogle != null) 'ratingGoogle': p.ratingGoogle,
        if (p.numResenas != null) 'numResenas': p.numResenas,
        // Contacto
        if (p.direccion?.isNotEmpty == true) 'direccion': p.direccion,
        if (p.telefono?.isNotEmpty == true) 'telefono': p.telefono,
        if (p.whatsapp?.isNotEmpty == true) 'whatsapp': p.whatsapp,
        if (p.emailPublico?.isNotEmpty == true) 'emailPublico': p.emailPublico,
        if (p.emailNotif?.isNotEmpty == true) 'emailNotificaciones': p.emailNotif,
        if (p.web?.isNotEmpty == true) 'web': p.web,
        if (p.instagram?.isNotEmpty == true) 'instagram': p.instagram,
        if (p.facebook?.isNotEmpty == true) 'facebook': p.facebook,
        if (p.googleMapsUrl?.isNotEmpty == true) 'googleMapsUrl': p.googleMapsUrl,
        // Horario
        if (p.horario.isNotEmpty) 'horario': p.horario,
        // Extras
        if (p.aceptaTarjeta != null) 'aceptaTarjeta': p.aceptaTarjeta,
        if (p.tieneParking != null) 'tieneParking': p.tieneParking,
        if (p.accesible != null) 'accesibleSillaRuedas': p.accesible,
        if (p.tieneWifi != null) 'tieneWifi': p.tieneWifi,
        if (p.admiteMascotas != null) 'admiteMascotas': p.admiteMascotas,
        if (p.tieneTerraza != null) 'tieneTerraza': p.tieneTerraza,
        // Formulario
        if (p.formularioTitulo?.isNotEmpty == true) 'formularioTitulo': p.formularioTitulo,
        if (p.formularioBoton?.isNotEmpty == true) 'formularioBoton': p.formularioBoton,
        'importadoDesdeExcel': true,
        if (!modoActualizar) 'creadoEn': FieldValue.serverTimestamp(),
        'actualizadoEnExcel': FieldValue.serverTimestamp(),
      };

      if (modoActualizar) {
        // Actualizar: merge para no sobreescribir campos que no trae el Excel
        await docRef.set(data, SetOptions(merge: true));
      } else {
        await docRef.set(data);
      }

      // Importar servicios como subcolección
      if (p.servicios.isNotEmpty) {
        final batch = db.batch();
        for (final svc in p.servicios) {
          final svcRef = docRef.collection('servicios').doc();
          batch.set(svcRef, {
            'nombre': svc['nombre'] ?? '',
            if (svc['descripcion']?.isNotEmpty == true) 'descripcion': svc['descripcion'],
            if (svc['categoria']?.isNotEmpty == true) 'categoria': svc['categoria'],
            if (svc['precio']?.isNotEmpty == true && svc['precio'] != 'null') 'precio': svc['precio'],
            if (svc['duracion']?.isNotEmpty == true && svc['duracion'] != 'null') 'duracion': svc['duracion'],
            'activo': svc['activo']?.toLowerCase() == 'sí' || svc['activo']?.toLowerCase() == 'si',
            'orden': p.servicios.indexOf(svc),
          });
        }
        await batch.commit();
      }

      if (mounted) {
        final accion = modoActualizar ? 'actualizado' : 'importado';
        FluxToast.exito(context,
            '${p.nombre} $accion — ${p.servicios.length} servicios');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al importar: $e');
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: const FluixAppBar(titulo: 'Importar negocio desde Excel', showLeading: true),
      body: _cargando
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: _kPurple),
              SizedBox(height: 16),
              Text('Leyendo fichero…', style: TextStyle(color: Color(0xFF6B7280))),
            ]))
          : _parseado == null
              ? _buildSeleccionar()
              : _buildPreview(),
    );
  }

  Widget _buildSeleccionar() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _kPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.table_chart_rounded, size: 40, color: _kPurple),
          ),
          const SizedBox(height: 24),
          const Text('Importar ficha de negocio',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          const Text(
            'Selecciona el fichero .xlsx generado con el formato de ficha Fluix.\n'
            'Se importarán los datos de Info, Contacto, Horario, Servicios y Extras.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 32),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _seleccionarFichero,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Seleccionar fichero .xlsx',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: _kPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Solo ficheros .xlsx en formato ficha Fluix',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ]),
      ),
    );
  }

  Widget _buildPreview() {
    final p = _parseado!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ── Banner éxito parse ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Fichero leído: ${p.servicios.length} servicios, '
              '${p.horario.length} días de horario',
              style: const TextStyle(fontSize: 13, color: Color(0xFF065F46),
                  fontWeight: FontWeight.w500),
            )),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Info ────────────────────────────────────────────────────────────
        _card('Información general', Icons.store_rounded, [
          _kv('Nombre', p.nombre),
          _kv('Categoría', '${p.categoria.icono} ${p.categoria.label} (leído: "${p.categoriaTexto}")'),
          _kv('Tagline', p.tagline),
          _kv('Descripción', p.descripcion, maxLines: 3),
          _kv('Especialidades', p.especialidades.isEmpty ? null : p.especialidades.join(', ')),
          _kv('Rating Google', p.ratingGoogle?.toString()),
          _kv('Nº reseñas', p.numResenas?.toString()),
        ]),
        const SizedBox(height: 8),

        // ── Contacto ────────────────────────────────────────────────────────
        _card('Contacto', Icons.contact_phone_rounded, [
          _kv('Dirección', p.direccion),
          _kv('Teléfono', p.telefono),
          _kv('WhatsApp', p.whatsapp),
          _kv('Email público', p.emailPublico),
          _kv('Web', p.web),
          _kv('Instagram', p.instagram),
          _kv('Facebook', p.facebook),
          _kv('Google Maps URL', p.googleMapsUrl),
        ]),
        const SizedBox(height: 8),

        // ── Horario ─────────────────────────────────────────────────────────
        if (p.horario.isNotEmpty)
          _card('Horario', Icons.schedule_rounded,
            p.horario.entries.map((e) {
              final h = e.value;
              final abierto = h['abierto'] as bool? ?? false;
              if (!abierto) return _kv(e.key, 'Cerrado');
              final ap2 = h['apertura2'] as String?;
              final ci2 = h['cierre2'] as String?;
              final hora = ap2 != null && ap2.isNotEmpty
                  ? '${h['apertura']} – ${h['cierre']}  /  $ap2 – $ci2'
                  : '${h['apertura']} – ${h['cierre']}';
              return _kv(e.key, hora);
            }).toList(),
          ),
        const SizedBox(height: 8),

        // ── Servicios ───────────────────────────────────────────────────────
        if (p.servicios.isNotEmpty) ...[
          _card('Servicios (${p.servicios.length})', Icons.design_services_rounded, [
            ...p.servicios.take(5).map((s) => _kv(s['nombre'] ?? '', s['categoria'])),
            if (p.servicios.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('… y ${p.servicios.length - 5} más',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280),
                        fontStyle: FontStyle.italic)),
              ),
          ]),
          const SizedBox(height: 8),
        ],

        // ── Extras ──────────────────────────────────────────────────────────
        _card('Características', Icons.checklist_rounded, [
          _kv('Acepta tarjeta', _boolLabel(p.aceptaTarjeta)),
          _kv('Parking', _boolLabel(p.tieneParking)),
          _kv('Accesible silla de ruedas', _boolLabel(p.accesible)),
          _kv('WiFi', _boolLabel(p.tieneWifi)),
          _kv('Admite mascotas', _boolLabel(p.admiteMascotas)),
        ]),
        const SizedBox(height: 16),

        // ── Botones ─────────────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _parseado = null),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Cambiar fichero'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPurple,
                side: const BorderSide(color: _kPurple),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _importando ? null : _importar,
              icon: _importando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(
                _importando
                    ? 'Importando…'
                    : widget.negocioId != null ? 'Actualizar negocio' : 'Importar negocio',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: _kPurple,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          widget.negocioId != null
              ? 'Los datos del Excel se fusionarán (merge) con el negocio. Los servicios se añaden sin borrar los existentes.'
              : 'Se creará en negocios_publicos sin vincular a ninguna empresa. Después podrás asignarla desde Gestión de Negocios.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  // ── Widgets auxiliares ───────────────────────────────────────────────────

  Widget _card(String titulo, IconData icono, List<Widget> children) =>
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icono, size: 16, color: _kPurple),
            const SizedBox(width: 8),
            Text(titulo, style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          ]),
          const Divider(height: 14),
          ...children,
        ]),
      );

  Widget _kv(String campo, String? valor, {int maxLines = 2}) {
    if (valor == null || valor.isEmpty || valor == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120,
            child: Text(campo,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500))),
        const SizedBox(width: 8),
        Expanded(child: Text(valor,
            maxLines: maxLines, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF111827)))),
      ]),
    );
  }

  String _boolLabel(bool? v) {
    if (v == null) return 'No especificado';
    return v ? '✓ Sí' : '✗ No';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO INTERNO — datos parseados del Excel
// ─────────────────────────────────────────────────────────────────────────────
class _NegocioParseado {
  final String nombre;
  final String? tagline;
  final String? descripcion;
  final CategoriaNegocio categoria;
  final String categoriaTexto;
  final List<String> especialidades;
  final double? ratingGoogle;
  final int? numResenas;
  // Contacto
  final String? direccion;
  final String? telefono;
  final String? whatsapp;
  final String? emailPublico;
  final String? emailNotif;
  final String? web;
  final String? instagram;
  final String? facebook;
  final String? googleMapsUrl;
  // Horario
  final Map<String, Map<String, dynamic>> horario;
  // Extras
  final bool? aceptaTarjeta;
  final bool? tieneParking;
  final bool? accesible;
  final bool? tieneWifi;
  final bool? admiteMascotas;
  final bool? tieneTerraza;
  // Formulario
  final String? formularioTitulo;
  final String? formularioBoton;
  // Servicios
  final List<Map<String, String?>> servicios;

  const _NegocioParseado({
    required this.nombre, this.tagline, this.descripcion,
    required this.categoria, required this.categoriaTexto,
    required this.especialidades, this.ratingGoogle, this.numResenas,
    this.direccion, this.telefono, this.whatsapp, this.emailPublico,
    this.emailNotif, this.web, this.instagram, this.facebook, this.googleMapsUrl,
    required this.horario,
    this.aceptaTarjeta, this.tieneParking, this.accesible,
    this.tieneWifi, this.admiteMascotas, this.tieneTerraza,
    this.formularioTitulo, this.formularioBoton,
    required this.servicios,
  });
}

extension _NullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
