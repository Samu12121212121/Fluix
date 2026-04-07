import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/cliente_importado_model.dart';
import '../core/utils/validador_nif_cif.dart';

class ImportacionClientesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── DETECCIÓN DE FORMATO ────────────────────────────────────────────────────

  String detectarSeparador(String contenido) {
    final comas = contenido.split(',').length;
    final puntoYcoma = contenido.split(';').length;
    // Excel español usa ; por defecto
    return puntoYcoma > comas ? ';' : ',';
  }

  String decodificarContenido(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return latin1.decode(bytes);
      } catch (e) {
        return String.fromCharCodes(bytes); // Fallback extremo
      }
    }
  }

  // ── MAPEO DE COLUMNAS ───────────────────────────────────────────────────────

  Map<String, int> mapearColumnas(List<dynamic> cabecera) {
    final mapa = <String, int>{};
    final normalizada = cabecera.map((e) => e.toString().toLowerCase().trim()).toList();

    for (int i = 0; i < normalizada.length; i++) {
      final col = normalizada[i];
      if (_esColumna(col, ['nombre', 'name', 'razon_social', 'empresa', 'cliente'])) {
        mapa['nombre'] = i;
      } else if (_esColumna(col, ['nif', 'cif', 'dni', 'nif_cif', 'documento'])) {
        mapa['nif'] = i;
      } else if (_esColumna(col, ['email', 'correo', 'e-mail', 'mail'])) {
        mapa['email'] = i;
      } else if (_esColumna(col, ['telefono', 'tel', 'phone', 'movil', 'celular'])) {
        mapa['telefono'] = i;
      } else if (_esColumna(col, ['direccion', 'address', 'domicilio', 'calle'])) {
        mapa['direccion'] = i;
      } else if (_esColumna(col, ['poblacion', 'ciudad', 'localidad', 'municipio'])) {
        mapa['poblacion'] = i;
      } else if (_esColumna(col, ['cp', 'codigo_postal', 'postal', 'zip'])) {
        mapa['cp'] = i;
      }
    }
    return mapa;
  }

  bool _esColumna(String actual, List<String> posibles) {
    // Eliminar acentos y carácteres especiales para comparar
    final limpia = actual.replaceAll(RegExp(r'[áéíóúÁÉÍÓÚñÑ]'), ''); // Básico
    return posibles.any((p) => actual.contains(p) || limpia.contains(p));
  }

  // ── PARSEO Y VALIDACIÓN ─────────────────────────────────────────────────────

  Future<ResultadoPreview> procesarCSV(
    Uint8List bytes,
    String empresaId,
  ) async {
    final contenido = decodificarContenido(bytes);
    final separador = detectarSeparador(contenido);
    
    // Convertir CSV a lista
    final filas = const CsvToListConverter().convert(
      contenido,
      fieldDelimiter: separador,
      eol: '\n',
      shouldParseNumbers: false,
    );

    if (filas.isEmpty) throw Exception('El archivo está vacío');
    if (filas.length < 2) throw Exception('El archivo no contiene datos (solo cabecera)');

    final cabecera = filas.first;
    final mapaCols = mapearColumnas(cabecera);

    // Verificar columnas obligatorias
    if (!mapaCols.containsKey('nombre')) {
      throw Exception('No se encontró la columna obligatoria: Nombre');
    }
    if (!mapaCols.containsKey('nif')) {
      throw Exception('No se encontró la columna obligatoria: NIF/CIF');
    }

    final columnasDetectadas = mapaCols.keys.toList();
    final colIndices = mapaCols.values.toSet();
    final columnasIgnoradas = <String>[];
    
    for (int i = 0; i < cabecera.length; i++) {
      if (!colIndices.contains(i)) {
        columnasIgnoradas.add(cabecera[i].toString());
      }
    }

    final candidatos = <ClienteImportado>[];
    final errores = <ClienteImportado>[];

    // Procesar filas (saltando cabecera)
    for (int i = 1; i < filas.length; i++) {
      final fila = filas[i];
      // Saltar filas vacías
      if (fila.every((c) => c.toString().trim().isEmpty)) continue;

      final validacion = _validarYConstruirCliente(fila, mapaCols);
      if (validacion.esValidoParaImportar) {
        candidatos.add(validacion);
      } else {
        errores.add(validacion);
      }
    }

    // Verificar duplicados en Firestore
    if (candidatos.isNotEmpty) {
      await _verificarExistenciaEnDb(candidatos, empresaId);
    }

    return ResultadoPreview(
      validos: candidatos,
      conErrores: errores,
      columnasDetectadas: columnasDetectadas,
      columnasIgnoradas: columnasIgnoradas,
    );
  }

  ClienteImportado _validarYConstruirCliente(
    List<dynamic> fila,
    Map<String, int> mapa,
  ) {
    final validaciones = <ResultadoValidacion>[];
    
    // Obtener valores seguros
    String getVal(String key) {
      final idx = mapa[key];
      if (idx == null || idx >= fila.length) return '';
      return fila[idx].toString().trim();
    }

    final nombre = getVal('nombre');
    final nifRaw = getVal('nif');
    final email = getVal('email');
    final telefono = getVal('telefono');
    final direccion = getVal('direccion');
    final poblacion = getVal('poblacion');
    final cp = getVal('cp');

    // 1. Validar Nombre (Obligatorio)
    if (nombre.isEmpty || nombre.length < 2) {
      validaciones.add(const ResultadoValidacion(
        estado: EstadoValidacion.error,
        mensaje: 'Nombre vacío o muy corto',
      ));
    }

    // 2. Validar NIF (Obligatorio)
    final valNif = ValidadorNifCif.validar(nifRaw);
    if (!valNif.valido) {
      validaciones.add(ResultadoValidacion(
        estado: EstadoValidacion.error,
        mensaje: 'NIF inválido: $nifRaw',
      ));
    }

    // 3. Validar Email (Warning)
    if (email.isNotEmpty) {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (!emailRegex.hasMatch(email)) {
        validaciones.add(ResultadoValidacion(
          estado: EstadoValidacion.warning,
          mensaje: 'Email con formato incorrecto: $email',
        ));
      }
    }

    // 4. Validar CP (Warning)
    if (cp.isNotEmpty) {
      if (!RegExp(r'^\d{5}$').hasMatch(cp)) {
        validaciones.add(ResultadoValidacion(
          estado: EstadoValidacion.warning,
          mensaje: 'CP debe tener 5 dígitos: $cp',
        ));
      }
    }

    return ClienteImportado(
      nombre: nombre,
      nif: valNif.nifNormalizado ?? nifRaw.toUpperCase(),
      email: email.isNotEmpty ? email.toLowerCase() : null,
      telefono: telefono.isNotEmpty ? telefono : null,
      direccion: direccion.isNotEmpty ? direccion : null,
      poblacion: poblacion.isNotEmpty ? poblacion : null,
      cp: cp.isNotEmpty ? cp : null,
      validaciones: validaciones,
    );
  }

  // ── CONSULTA DE DUPLICADOS ──────────────────────────────────────────────────

  Future<void> _verificarExistenciaEnDb(
    List<ClienteImportado> clientes,
    String empresaId,
  ) async {
    // Obtenemos los NIFs de los clientes a importar
    final nifs = clientes.map((c) => c.nif).toSet().toList();
    
    // Firestore whereIn soporta máximo 10 valores. Hacemos batches.
    final existentes = <String>{}; // Set de NIFs que ya existen

    for (var i = 0; i < nifs.length; i += 10) {
      final batch = nifs.sublist(i, (i + 10) < nifs.length ? i + 10 : nifs.length);
      
      // Consultamos buscando por campo 'datos_fiscales.nif' si existe en Factura, 
      // PERO esto es Cliente. El modelo Cliente no tiene el NIF como campo root obligatorio 
      // en la definición anterior, pero en el IMPORTADOR estamos asumiendo que lo usaremos 
      // para identificar duplicados. 
      // IMPORTANTE: En el modelo Cliente.toFirestore no vi el campo 'nif'.
      // Revisando el prompt "MODELO DE DATOS": "nif": "string" // obligatorio
      // Asumiremos que el campo 'nif' existe o debemos crearlo.
      
      // NOTA: Si el modelo Cliente actual no tiene 'nif' en la raiz, deberemos confiar 
      // en buscar por coincidencia exacta de nombre o añadir nif al modelo.
      // El prompt dice: "MODELO DE DATOS — CAMPOS QUE RELLENA EL IMPORTADOR ... "nif": "string""
      // Asumimos que se guarda en el campo 'nif' del documento.
      
      final query = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('clientes')
          .where('nif', whereIn: batch)
          .get();

      for (var doc in query.docs) {
        final data = doc.data();
        existentes.add(data['nif'] ?? '');
      }
    }

    // Marcar los que existen
    for (var c in clientes) {
      if (existentes.contains(c.nif)) {
        c.existeEnDb = true;
      }
    }
  }

  // ── EJECUCIÓN ───────────────────────────────────────────────────────────────

  Stream<double> importarEnLotes(
    List<ClienteImportado> clientes,
    String empresaId,
  ) async* {
    if (clientes.isEmpty) return;

    final total = clientes.length;
    int procesados = 0;
    
    // Lotes de 400 para no saturar el batch (limite 500)
    for (var i = 0; i < total; i += 400) {
      final batch = _firestore.batch();
      final fin = (i + 400 < total) ? i + 400 : total;
      final lote = clientes.sublist(i, fin);

      for (var cliente in lote) {
        // Buscar documento por NIF si es posible para asegurar que el ID sea consistente
        // o usar Query para obtener el ID real si ya existe.
        // Dado que hemos detectado existencia pero no guardamos el ID del doc en _verificarExistenciaEnDb,
        // necesitamos una estrategia eficiente.
        
        // ESTRATEGIA OPTIMIZADA:
        // Si existe, necesitamos su ID. Si no, generamos uno nuevo.
        // Como _verificarExistenciaEnDb solo trajo NIFs, aquí podemos tener un problema para Updates.
        
        // SOLUCIÓN: Usar el NIF como ID del documento, o hacer la importación más lenta buscando ID.
        // El prompt sugiere: "docRef = clientes/{empresaId}/docs/{nif_normalizado}"
        // Esto simplifica todo: el ID ES EL NIF.
        
        // Pero NIF puede contener caracteres inválidos para IDs (/, etc, aunque normalizado es alphanumeric).
        // ValidadorNifCif limpia todo, así que es seguro.
        
        final docRef = _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('clientes')
            .doc(cliente.nif); // Usamos NIF como ID para evitar duplicados reales

        final datos = cliente.toMapFirestore(empresaId);
        
        if (cliente.existeEnDb) {
          // Update: merge true para no borrar campos extra que no vengan en CSV
          batch.set(docRef, datos, SetOptions(merge: true));
        } else {
          // Create: set normal (aunque merge true también vale y es más seguro)
          batch.set(docRef, datos, SetOptions(merge: true));
        }
      }

      await batch.commit();
      procesados += lote.length;
      yield procesados / total;
    }
  }
}

