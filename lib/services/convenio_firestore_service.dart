import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../domain/modelos/convenio_colectivo.dart';

final _log = Logger();

class ConvenioFirestoreService {
  static final ConvenioFirestoreService _instance = ConvenioFirestoreService._();
  factory ConvenioFirestoreService() => _instance;
  ConvenioFirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conveniosRef =>
      _db.collection('convenios');

  Future<Convenio?> obtenerConvenio(String id) async {
    final doc = await _conveniosRef.doc(id).get();
    if (!doc.exists) return null;
    var data = doc.data()!;
    data['id'] = doc.id;
    return Convenio.fromMap(data);
  }

  Future<List<CategoriaConvenio>> obtenerCategorias(String convenioId) async {
    final snap =
        await _conveniosRef.doc(convenioId).collection('categorias').get();
    return snap.docs.map((d) {
      var data = d.data();
      data['id'] = d.id;
      return CategoriaConvenio.fromMap(data);
    }).toList();
  }

  Future<CategoriaConvenio?> obtenerCategoriaPorNombre(String convenioId, String nombreCategoria) async {
    final snap = await _conveniosRef
        .doc(convenioId)
        .collection('categorias')
        .where('nombre', isEqualTo: nombreCategoria)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    var data = doc.data();
    data['id'] = doc.id;
    return CategoriaConvenio.fromMap(data);
  }

  Future<List<PlusConvenio>> obtenerPluses(String convenioId) async {
    final snap = await _conveniosRef.doc(convenioId).collection('pluses').get();
    return snap.docs.map((d) {
      var data = d.data();
      data['id'] = d.id;
      return PlusConvenio.fromMap(data);
    }).toList();
  }

  Future<void> seedConvenioHosteleriaGuadalajara({bool force = false}) async {
    const convenioId = 'hosteleria-guadalajara';
    final doc = await _conveniosRef.doc(convenioId).get();
    if (doc.exists && !force) {
      _log.i('El convenio de Hostelería de Guadalajara ya existe en Firestore. No se hará nada.');
      return; 
    }

    _log.i('Creando datos para el convenio de Hostelería de Guadalajara...');

    final data = {
      "convenio": {
        "nombre": "Convenio Colectivo de Hostelería de la provincia de Guadalajara",
        "ambito": "provincial",
        "sector": "hosteleria",
        "tipo_convenio": "sectorial_provincial",
        "vigencia": {
          "inicio": "2025-01-01",
          "fin": "2026-12-31",
          "estado_dato": "tablas_provisionales_2026"
        },
        "fuente": {
          "documento": "Tablas provisionales 2026 facilitadas (pendiente publicación definitiva BOP)",
          "fecha_extraccion": "2026-03-16",
          "version": "v2"
        }
      },
      "categorias": [
        {
          "id": "nivel-1",
          "nombre": "Nivel 1",
          "grupo_profesional": "Grupo establecimiento 1",
          "salario_base_mensual": 1569.03,
          "gratificacion_extra": 532.70,
          "salario_anual": 22499.10,
          "num_pagas": 15
        },
        {
          "id": "nivel-2",
          "nombre": "Nivel 2",
          "grupo_profesional": "Grupo establecimiento 2",
          "salario_base_mensual": 1512.91,
          "gratificacion_extra": 528.83,
          "salario_anual": 21709.50,
          "num_pagas": 15
        },
        {
          "id": "nivel-3",
          "nombre": "Nivel 3",
          "grupo_profesional": "Grupo establecimiento 3",
          "salario_base_mensual": 1438.86,
          "gratificacion_extra": 523.72,
          "salario_anual": 20667.73,
          "num_pagas": 15
        },
        {
          "id": "nivel-4",
          "nombre": "Nivel 4",
          "grupo_profesional": "Grupo establecimiento 4",
          "salario_base_mensual": 1342.08,
          "gratificacion_extra": 517.05,
          "salario_anual": 19306.11,
          "num_pagas": 15
        },
        {
          "id": "nivel-5",
          "nombre": "Nivel 5",
          "grupo_profesional": "Grupo establecimiento 5",
          "salario_base_mensual": 1290.80,
          "gratificacion_extra": 513.51,
          "salario_anual": 18584.71,
          "num_pagas": 15
        }
      ],
      "pluses": [
        {"id": "nocturnidad", "nombre": "Plus de Nocturnidad", "tipo": "porcentaje", "importe": 25.0, "base_calculo": "salario_base_hora", "fuente_legal": {"articulo": "26"}},
        {"id": "transporte", "nombre": "Plus de Transporte", "tipo": "fijo", "importe": 80.0, "base_calculo": "mes", "fuente_legal": {"articulo": "27"}},
        {"id": "festivos", "nombre": "Plus de Festivos", "tipo": "fijo", "importe": 50.0, "base_calculo": "dia_festivo_trabajado", "fuente_legal": {"articulo": "30"}}
      ],
      "jornada_laboral": {
        "horas_anuales": 1800,
        "descansos": "2 días ininterrumpidos a la semana",
        "vacaciones_dias_naturales": 30
      },
      "pagas_extra": [
        {"nombre": "Paga de Verano", "mes_pago": 6, "devengo": "semestral"},
        {"nombre": "Paga de Navidad", "mes_pago": 12, "devengo": "semestral"},
        {"nombre": "Gratificación septiembre", "mes_pago": 9, "devengo": "anual"}
      ]
    };

    final WriteBatch batch = _db.batch();

    final convenioDocRef = _conveniosRef.doc(convenioId);
    batch.set(convenioDocRef, data['convenio'] as Map<String,dynamic>);

    for (final catData in data['categorias'] as List<Map<String,dynamic>>) {
      final catId = catData['id'] as String;
      final catDocRef = convenioDocRef.collection('categorias').doc(catId);
      // Calcula el salario mensual si no está presente
      if (catData['salario_base_mensual'] == null) {
        final salarioAnual = (catData['salario_anual'] as num).toDouble();
        final numPagas = (catData['num_pagas'] as num).toInt();
        catData['salario_base_mensual'] = salarioAnual / numPagas;
      }
      batch.set(catDocRef, catData);
    }

    for (final plusData in data['pluses'] as List<Map<String,dynamic>>) {
      final plusId = plusData['id'] as String;
      final plusDocRef = convenioDocRef.collection('pluses').doc(plusId);
      batch.set(plusDocRef, plusData);
    }
    
    await batch.commit();
    _log.i('✅ Datos del convenio de Hostelería de Guadalajara creados en Firestore.');
  }

  Future<void> seedConvenioComercioGuadalajara({bool force = false}) async {
    const convenioId = 'comercio-guadalajara';
    final doc = await _conveniosRef.doc(convenioId).get();
    if (doc.exists && !force) {
      _log.i('El convenio de Comercio de Guadalajara ya existe en Firestore. No se hará nada.');
      return;
    }

    _log.i('Creando datos para el convenio de Comercio de Guadalajara...');

    final data = {
      "convenio": {
        "nombre": "Convenio Colectivo de Comercio de la provincia de Guadalajara",
        "ambito": "provincial",
        "sector": "comercio",
        "tipo_convenio": "sectorial_provincial",
        "vigencia": {
          "inicio": "2024-01-01",
          "fin": "2026-12-31",
          "estado_dato": "dato_usuario"
        },
        "fuente": {
          "documento": "Tabla salarial facilitada por usuario (referencia 2026 IPC)",
          "fecha_extraccion": "2026-03-16",
          "version": "v1"
        }
      },
      "categorias": [
        {
          "id": "grp1-nivel1",
          "nombre": "Alta responsabilidad / Dirección tienda",
          "grupo_profesional": "Grupo 1",
          "nivel": 1,
          "salario_anual": 25900.0,
          "salario_base_mensual": 1700.0,
          "complemento_convenio": 150.0,
          "num_pagas": 14
        },
        {
          "id": "grp2-nivel2",
          "nombre": "Jefes de sección / Vendedores cualificados",
          "grupo_profesional": "Grupo 2",
          "nivel": 2,
          "salario_anual": 21000.0,
          "salario_base_mensual": 1400.0,
          "complemento_convenio": 100.0,
          "num_pagas": 14
        },
        {
          "id": "grp3-nivel3",
          "nombre": "Dependientes / Cajeros",
          "grupo_profesional": "Grupo 3",
          "nivel": 3,
          "salario_anual": 17920.0,
          "salario_base_mensual": 1200.0,
          "complemento_convenio": 80.0,
          "num_pagas": 14
        },
        {
          "id": "grp4-nivel4",
          "nombre": "Auxiliares / Mozos / Reponedores",
          "grupo_profesional": "Grupo 4",
          "nivel": 4,
          "salario_anual": 15400.0,
          "salario_base_mensual": 1050.0,
          "complemento_convenio": 50.0,
          "num_pagas": 14
        }
      ],
      "pluses": [
        {"id": "plus_jornada_6dias", "nombre": "Plus jornada 6 días", "tipo": "fijo", "importe": 120.0, "base_calculo": "mes"},
        {"id": "apertura_domingos", "nombre": "Apertura domingos", "tipo": "fijo", "importe": 85.0, "base_calculo": "dia"},
        {"id": "plus_conductor", "nombre": "Plus conductor", "tipo": "fijo", "importe": 50.0, "base_calculo": "mes"},
        {"id": "dietas", "nombre": "Dietas", "tipo": "fijo", "importe": 25.0, "base_calculo": "dia"},
        {"id": "media_dieta", "nombre": "Media dieta", "tipo": "fijo", "importe": 12.5, "base_calculo": "dia"}
      ],
      "jornada_laboral": {
        "horas_semanales": 40,
        "horas_anuales": 1782,
        "descansos": "1,5 días ininterrumpidos semanales; 12h entre jornadas",
        "salario_hora_limpieza": 10.0
      },
      "pagas_extra": [
        {"nombre": "Paga de Verano", "mes_pago": 6, "devengo": "semestral"},
        {"nombre": "Paga de Navidad", "mes_pago": 12, "devengo": "semestral"}
      ],
      "horas_extra": {
        "precio_referencia": "1.25 x valor hora ordinaria",
        "formula": "precio_hora = salario_anual / horas_anuales"
      }
    };

    final WriteBatch batch = _db.batch();
    final convenioDocRef = _conveniosRef.doc(convenioId);
    batch.set(convenioDocRef, data['convenio'] as Map<String, dynamic>);

    for (final catData in data['categorias'] as List<Map<String, dynamic>>) {
      final catId = catData['id'] as String;
      final catDocRef = convenioDocRef.collection('categorias').doc(catId);
      if (catData['salario_base_mensual'] == null) {
        final salarioAnual = (catData['salario_anual'] as num).toDouble();
        final numPagas = (catData['num_pagas'] as num).toInt();
        catData['salario_base_mensual'] = salarioAnual / numPagas;
      }
      batch.set(catDocRef, catData);
    }

    for (final plusData in data['pluses'] as List<Map<String, dynamic>>) {
      final plusId = plusData['id'] as String;
      final plusDocRef = convenioDocRef.collection('pluses').doc(plusId);
      batch.set(plusDocRef, plusData);
    }

    await batch.commit();
    _log.i('✅ Datos del convenio de Comercio de Guadalajara creados en Firestore.');
  }

  Future<void> seedConvenioPeluqueriaEsteticaGimnasios({bool force = false}) async {
    const convenioId = 'peluqueria-estetica-gimnasios';
    final doc = await _conveniosRef.doc(convenioId).get();
    if (doc.exists && !force) {
      _log.i('El convenio de Peluquerías/Estética/Gimnasios ya existe en Firestore.');
      return;
    }

    _log.i('Creando datos para el convenio de Peluquerías/Estética/Gimnasios...');

    final data = {
      "convenio": {
        "nombre": "Convenio Colectivo de Peluquerías, Institutos de Belleza y Gimnasios",
        "codigo": "99010955011997",
        "ambito": "estatal",
        "sector": "peluqueria",
        "tipo_convenio": "sectorial_estatal",
        "vigencia": {
          "inicio": "2024-01-01",
          "fin": "2026-12-31",
          "estado_dato": "tablas_boe_2026"
        },
        "fuente": {
          "documento": "Tablas salariales oficiales 2026 (BOE)",
          "fecha_extraccion": "2026-03-16",
          "version": "v1"
        }
      },
      "categorias": [
        {"id": "grupo-i",   "nombre": "Grupo I",   "grupo_profesional": "I",   "salario_base_mensual": 1250.00, "salario_anual": 17500.00, "num_pagas": 14},
        {"id": "grupo-ii",  "nombre": "Grupo II",  "grupo_profesional": "II",  "salario_base_mensual": 1325.00, "salario_anual": 18550.00, "num_pagas": 14},
        {"id": "grupo-iii", "nombre": "Grupo III", "grupo_profesional": "III", "salario_base_mensual": 1350.00, "salario_anual": 18900.00, "num_pagas": 14},
        {"id": "grupo-iv",  "nombre": "Grupo IV",  "grupo_profesional": "IV",  "salario_base_mensual": 1375.00, "salario_anual": 19250.00, "num_pagas": 14}
      ],
      "pluses": [
        {"id": "plus_transporte", "nombre": "Plus transporte suprimido 2026", "tipo": "fijo", "importe": 0.0, "base_calculo": "mes", "vigente": false}
      ],
      "pagas_extra": [
        {"nombre": "Paga de Verano", "mes_pago": 6, "devengo": "semestral"},
        {"nombre": "Paga de Navidad", "mes_pago": 12, "devengo": "semestral"}
      ]
    };

    final WriteBatch batch = _db.batch();
    final convenioDocRef = _conveniosRef.doc(convenioId);
    batch.set(convenioDocRef, data['convenio'] as Map<String, dynamic>);

    for (final catData in data['categorias'] as List<Map<String, dynamic>>) {
      final catId = catData['id'] as String;
      final catDocRef = convenioDocRef.collection('categorias').doc(catId);
      if (catData['salario_base_mensual'] == null) {
        final salarioAnual = (catData['salario_anual'] as num).toDouble();
        final numPagas = (catData['num_pagas'] as num).toInt();
        catData['salario_base_mensual'] = salarioAnual / numPagas;
      }
      batch.set(catDocRef, catData);
    }

    for (final plusData in data['pluses'] as List<Map<String, dynamic>>) {
      final plusId = plusData['id'] as String;
      final plusDocRef = convenioDocRef.collection('pluses').doc(plusId);
      batch.set(plusDocRef, plusData);
    }

    await batch.commit();
    _log.i('✅ Datos del convenio de Peluquerías/Estética/Gimnasios creados en Firestore.');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVENIO INDUSTRIAS CÁRNICAS — BOE 07/07/2025 (BOE-A-2025-13965)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> seedConvenioCarniceriasGuadalajara2025({bool force = false}) async {
    const convenioId = 'industrias-carnicas-guadalajara-2025';
    final doc = await _conveniosRef.doc(convenioId).get();
    if (doc.exists && !force) {
      _log.i('El convenio de Industrias Cárnicas ya existe en Firestore. No se hará nada.');
      return;
    }

    _log.i('Creando datos para el convenio de Industrias Cárnicas (Guadalajara)...');

    // ── Jornada y cálculo hora ordinaria ──────────────────────────────────
    const int horasAnuales = 1748;

    final data = {
      "convenio": {
        "nombre": "Convenio Colectivo Estatal de Industrias Cárnicas 2024-2025",
        "codigo_boe": "BOE-A-2025-13965",
        "ambito": "estatal",
        "sector": "industrias_carnicas",
        "tipo_convenio": "sectorial_estatal",
        "vigencia": {
          "inicio": "2024-01-01",
          "fin": "2025-12-31",
          "estado_dato": "tablas_boe_2025_provisional_2026"
        },
        "fuente": {
          "documento": "BOE 07/07/2025 — Tablas salariales 2025 (+3% s/2024). Base provisional para 2026.",
          "fecha_extraccion": "2026-03-23",
          "version": "v1"
        },
        "provincia_aplicacion": "Guadalajara",
        "incremento_2025": "3% sobre 2024",
      },
      "categorias": [
        // ── Categorías típicas de carnicería/establecimientos cárnicos ────
        {
          "id": "nivel-8-encargado",
          "nombre": "Encargado / Maestro Maquinista",
          "grupo_profesional": "Nivel 8",
          "nivel": 8,
          "salario_anual": 22615.10,
          "salario_base_mensual": 1615.36,   // 22.615,10 / 14
          "num_pagas": 14,
          "hora_ordinaria": 22615.10 / horasAnuales, // ≈ 12,94€
        },
        {
          "id": "nivel-10-oficial-1a",
          "nombre": "Oficial 1ª Obrero / Carretillero",
          "grupo_profesional": "Nivel 10",
          "nivel": 10,
          "salario_anual": 21393.23,
          "salario_base_mensual": 1528.09,   // 21.393,23 / 14
          "num_pagas": 14,
          "hora_ordinaria": 21393.23 / horasAnuales, // ≈ 12,24€
        },
        {
          "id": "nivel-11-oficial-2a",
          "nombre": "Oficial 2ª Obrero",
          "grupo_profesional": "Nivel 11",
          "nivel": 11,
          "salario_anual": 21083.40,
          "salario_base_mensual": 1505.96,   // 21.083,40 / 14
          "num_pagas": 14,
          "hora_ordinaria": 21083.40 / horasAnuales, // ≈ 12,06€
        },
        {
          "id": "nivel-12-ayudante",
          "nombre": "Ayudante",
          "grupo_profesional": "Nivel 12",
          "nivel": 12,
          "salario_anual": 20459.93,
          "salario_base_mensual": 1461.42,   // 20.459,93 / 14
          "num_pagas": 14,
          "hora_ordinaria": 20459.93 / horasAnuales, // ≈ 11,70€
        },
        {
          "id": "nivel-13-peon",
          "nombre": "Peón",
          "grupo_profesional": "Nivel 13",
          "nivel": 13,
          "salario_anual": 19804.15,
          "salario_base_mensual": 1414.58,   // 19.804,15 / 14
          "num_pagas": 14,
          "hora_ordinaria": 19804.15 / horasAnuales, // ≈ 11,33€
        },
        {
          "id": "nivel-6-aux-admin",
          "nombre": "Auxiliar Administrativo",
          "grupo_profesional": "Nivel 6",
          "nivel": 6,
          "salario_anual": 20469.54,
          "salario_base_mensual": 1462.11,   // 20.469,54 / 14
          "num_pagas": 14,
          "hora_ordinaria": 20469.54 / horasAnuales, // ≈ 11,71€
        },
        {
          "id": "nivel-7-subalterno",
          "nombre": "Subalterno",
          "grupo_profesional": "Nivel 7",
          "nivel": 7,
          "salario_anual": 19774.44,
          "salario_base_mensual": 1412.46,   // 19.774,44 / 14
          "num_pagas": 14,
          "hora_ordinaria": 19774.44 / horasAnuales, // ≈ 11,31€
        },
      ],
      "pluses": [
        // ── Plus sustitutorio de productividad (no incentivados) ──────────
        {
          "id": "productividad",
          "nombre": "Plus sustitutorio productividad",
          "tipo": "fijo",
          "importe": 0.886,
          "base_calculo": "hora_trabajada",
          "descripcion": "Para personal no sujeto a incentivo"
        },
        // ── Plus de penosidad (puestos especiales) ────────────────────────
        {
          "id": "penosidad",
          "nombre": "Plus de penosidad",
          "tipo": "fijo",
          "importe": 0.87,    // valor medio orientativo (0,694-1,044€/h)
          "base_calculo": "hora_trabajada",
          "descripcion": "Puestos de especial penosidad. Rango: 0,694-1,044€/h"
        },
        // ── Plus de nocturnidad (22h-6h) ──────────────────────────────────
        {
          "id": "nocturnidad",
          "nombre": "Plus de nocturnidad (22h-6h)",
          "tipo": "fijo",
          "importe": 2.83,    // valor medio orientativo (2,167-3,501€/h)
          "base_calculo": "hora_nocturna",
          "descripcion": "Trabajo entre 22:00 y 06:00. Rango: 2,167-3,501€/h según nivel"
        },
        // ── Quebranto de moneda (cajeros) ─────────────────────────────────
        {
          "id": "quebranto_moneda",
          "nombre": "Quebranto de moneda",
          "tipo": "fijo",
          "importe": 25.811,
          "base_calculo": "mes",
          "descripcion": "Solo personal de caja"
        },
        // ── Dietas ────────────────────────────────────────────────────────
        {
          "id": "dieta_comida",
          "nombre": "Dieta comida",
          "tipo": "fijo",
          "importe": 17.344,
          "base_calculo": "dia_desplazamiento"
        },
        {
          "id": "dieta_cena",
          "nombre": "Dieta cena",
          "tipo": "fijo",
          "importe": 17.344,
          "base_calculo": "dia_desplazamiento"
        },
        {
          "id": "dieta_alojamiento",
          "nombre": "Dieta alojamiento + desayuno",
          "tipo": "fijo",
          "importe": 34.711,
          "base_calculo": "dia_desplazamiento"
        },
      ],
      "jornada_laboral": {
        "horas_anuales": horasAnuales,
        "desde": "2025-01-01",
        "descansos": "Según Art. 34 ET — mínimo 1,5 días semanales",
        "vacaciones_dias_naturales": 30
      },
      "pagas_extra": [
        {"nombre": "Paga de Verano", "mes_pago": 6, "devengo": "semestral", "calculo": "30 días salario base"},
        {"nombre": "Paga de Navidad", "mes_pago": 12, "devengo": "semestral", "calculo": "30 días salario base"}
      ],
      "horas_extra": {
        "recargo": 1.75,
        "formula": "hora_ordinaria × 1,75",
        "hora_ordinaria_formula": "salario_anual / $horasAnuales"
      },
      "periodo_prueba": {
        "personal_comercial": "9 meses",
        "personal_tecnico": "6 meses",
        "resto": "2 meses",
        "peones": "30 días"
      },
      "preaviso_cese": {
        "titulados_o_con_personal_a_cargo": "2 meses",
        "tecnico_administrativo": "15 días",
        "subalterno_obrero": "8 días"
      }
    };

    final WriteBatch batch = _db.batch();
    final convenioDocRef = _conveniosRef.doc(convenioId);
    batch.set(convenioDocRef, data['convenio'] as Map<String, dynamic>);

    for (final catData in data['categorias'] as List<Map<String, dynamic>>) {
      final catId = catData['id'] as String;
      final catDocRef = convenioDocRef.collection('categorias').doc(catId);
      if (catData['salario_base_mensual'] == null) {
        final salarioAnual = (catData['salario_anual'] as num).toDouble();
        final numPagas = (catData['num_pagas'] as num).toInt();
        catData['salario_base_mensual'] = salarioAnual / numPagas;
      }
      batch.set(catDocRef, catData);
    }

    for (final plusData in data['pluses'] as List<Map<String, dynamic>>) {
      final plusId = plusData['id'] as String;
      final plusDocRef = convenioDocRef.collection('pluses').doc(plusId);
      batch.set(plusDocRef, plusData);
    }

    await batch.commit();
    _log.i('✅ Datos del convenio de Industrias Cárnicas (Guadalajara) creados en Firestore.');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // II CONVENIO CENTROS Y SERVICIOS VETERINARIOS — BOE-A-2023-21910
  // PRÓRROGA 2026: tablas 2025 × IPC 2,9% (art. 6.4 convenio)
  // Pendiente nuevo convenio 2026 — actualizar cuando se publique
  // Fuente: BOE-A-2023-21910 + BOE febrero 2026 (denuncia)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> seedConvenioVeterinariosGuadalajara2026({bool force = false}) async {
    const convenioId = 'veterinarios-guadalajara-2026';
    final doc = await _conveniosRef.doc(convenioId).get();
    if (doc.exists && !force) {
      _log.i('El convenio de Veterinarios (Guadalajara) ya existe en Firestore. No se hará nada.');
      return;
    }

    _log.i('Creando datos para el convenio de Veterinarios (Guadalajara, prórroga 2026)...');

    // ── Jornada ───────────────────────────────────────────────────────────
    const int horasAnuales = 1780; // art. 38 del convenio

    // ── IPC interanual dic-2025: 2,9% → factor ×1,029 ──────────────────
    // Tablas base: Anexo III (2025) del BOE-A-2023-21910
    // Todas las cifras monetarias 2026 = valor_2025 × 1,029
    const double ipc = 1.029;

    // ── Salarios base 2025 (Anexo III) ────────────────────────────────────
    const double sb1_2025 = 1506.74; // SB Nivel I (Grupo I y II)
    const double sb2_2025 = 1332.88; // SB Nivel II
    const double sb3_2025 = 1216.98; // SB Nivel III
    const double sb4_2025 = 1159.03; // SB Nivel IV

    // ── CPT 2025 ──────────────────────────────────────────────────────────
    const double cptVetDir_2025      = 482.16;
    const double cptVetGen_2025      = 120.54;
    const double cptTecnico_2025     = 53.06;
    const double cptAcv_2025         = 23.07;
    const double cptTitSup_2025      = 119.96;

    // ── Cálculo 2026 (×1,029) ─────────────────────────────────────────────
    // Se aplica IPC a SB y CPT por separado, redondeando a céntimos.
    double r(double v) => (v * ipc * 100).roundToDouble() / 100;

    final double sb1  = r(sb1_2025);   // 1550.44
    final double sb2  = r(sb2_2025);   // 1371.55
    final double sb3  = r(sb3_2025);   // 1252.27
    final double sb4  = r(sb4_2025);   // 1192.64

    final double cptVetDir  = r(cptVetDir_2025);   // 496.14
    final double cptVetGen  = r(cptVetGen_2025);    // 124.04
    final double cptTecnico = r(cptTecnico_2025);   // 54.60
    final double cptAcv     = r(cptAcv_2025);       // 23.74
    final double cptTitSup  = r(cptTitSup_2025);    // 123.44

    // ── Totales mensuales 2026 ────────────────────────────────────────────
    final double vetDir    = sb1 + cptVetDir;   // ≈2046.58
    final double vetGen    = sb1 + cptVetGen;   // ≈1674.48
    final double vetSup    = sb1;               // ≈1550.44 (CPT=0)
    final double tecnico   = sb2 + cptTecnico;  // ≈1426.15
    final double acv       = sb3 + cptAcv;      // ≈1276.01
    final double titSup    = sb1 + cptTitSup;   // ≈1673.88
    final double admin     = sb2 + cptTecnico;  // ≈1426.15
    final double nivelIII  = sb3;               // ≈1252.27 (CPT=0)
    final double nivelIV   = sb4;               // ≈1192.64 (CPT=0)

    // ── Pluses 2026 (×1,029 sobre 2025) ──────────────────────────────────
    final double festividad2026     = r(24.00);  // ≈24.70
    final double festivoEsp2026    = r(55.00);  // ≈56.60
    final double dispOrd2026       = r(15.00);  // ≈15.44
    final double dispFest2026      = r(18.00);  // ≈18.52
    final double dispFestEsp2026   = r(25.00);  // ≈25.73
    final double dietaMedia2026    = r(22.73);  // ≈23.39
    final double dietaCompleta2026 = r(62.49);  // ≈64.30
    final double km2026            = r(0.22);   // ≈0.23

    final data = {
      "convenio": {
        "nombre": "II Convenio Colectivo de Centros y Servicios Veterinarios",
        "codigo_boe": "BOE-A-2023-21910",
        "ambito": "estatal",
        "sector": "veterinarios",
        "tipo_convenio": "sectorial_estatal",
        "vigencia": {
          "inicio": "2023-01-01",
          "fin": "2025-12-31",
          "prorroga": true,
          "estado_dato": "prorroga_2026_ipc_29"
        },
        "fuente": {
          "documento": "BOE-A-2023-21910. Tablas Anexo III (2025) × IPC dic-2025 2,9% (art. 6.4 convenio).",
          "ipc_aplicado": "2,9% interanual dic-2025",
          "fecha_extraccion": "2026-03-23",
          "version": "v1",
          "nota": "PRÓRROGA 2026 — pendiente nuevo convenio. Actualizar cuando se publique."
        },
        "provincia_aplicacion": "Guadalajara",
      },
      "categorias": [
        // ═══════ GRUPO I — PERSONAL SANITARIO ════════════════════════════
        // ── Nivel I ──────────────────────────────────────────────────────
        {
          "id": "g1-n1-vet-director",
          "nombre": "Veterinario Director",
          "grupo_profesional": "Grupo I — Personal Sanitario",
          "nivel": 1,
          "salario_base_2026": sb1,
          "complemento_puesto_trabajo": cptVetDir,
          "salario_base_mensual": vetDir,
          "salario_anual": vetDir * 14,
          "num_pagas": 14,
          "hora_ordinaria": vetDir * 14 / horasAnuales,
        },
        {
          "id": "g1-n1-vet-generalista",
          "nombre": "Veterinario Generalista",
          "grupo_profesional": "Grupo I — Personal Sanitario",
          "nivel": 1,
          "salario_base_2026": sb1,
          "complemento_puesto_trabajo": cptVetGen,
          "salario_base_mensual": vetGen,
          "salario_anual": vetGen * 14,
          "num_pagas": 14,
          "hora_ordinaria": vetGen * 14 / horasAnuales,
        },
        {
          "id": "g1-n1-vet-supervisado",
          "nombre": "Veterinario Supervisado",
          "grupo_profesional": "Grupo I — Personal Sanitario",
          "nivel": 1,
          "salario_base_2026": sb1,
          "complemento_puesto_trabajo": 0.0,
          "salario_base_mensual": vetSup,
          "salario_anual": vetSup * 14,
          "num_pagas": 14,
          "hora_ordinaria": vetSup * 14 / horasAnuales,
        },
        // ── Nivel II ─────────────────────────────────────────────────────
        {
          "id": "g1-n2-tecnico-especialista",
          "nombre": "Técnico Especialista (Laboratorio / Radiodiagnóstico)",
          "grupo_profesional": "Grupo I — Personal Sanitario",
          "nivel": 2,
          "salario_base_2026": sb2,
          "complemento_puesto_trabajo": cptTecnico,
          "salario_base_mensual": tecnico,
          "salario_anual": tecnico * 14,
          "num_pagas": 14,
          "hora_ordinaria": tecnico * 14 / horasAnuales,
        },
        // ── Nivel III ────────────────────────────────────────────────────
        {
          "id": "g1-n3-acv",
          "nombre": "Auxiliar Clínico Veterinaria (ACV)",
          "grupo_profesional": "Grupo I — Personal Sanitario",
          "nivel": 3,
          "salario_base_2026": sb3,
          "complemento_puesto_trabajo": cptAcv,
          "salario_base_mensual": acv,
          "salario_anual": acv * 14,
          "num_pagas": 14,
          "hora_ordinaria": acv * 14 / horasAnuales,
        },
        // ═══════ GRUPO II — PERSONAL NO SANITARIO ════════════════════════
        // ── Nivel I ──────────────────────────────────────────────────────
        {
          "id": "g2-n1-titulado-superior",
          "nombre": "Personal Titulado Superior",
          "grupo_profesional": "Grupo II — Personal No Sanitario",
          "nivel": 1,
          "salario_base_2026": sb1,
          "complemento_puesto_trabajo": cptTitSup,
          "salario_base_mensual": titSup,
          "salario_anual": titSup * 14,
          "num_pagas": 14,
          "hora_ordinaria": titSup * 14 / horasAnuales,
        },
        // ── Nivel II ─────────────────────────────────────────────────────
        {
          "id": "g2-n2-administrativo",
          "nombre": "Personal Administrativo",
          "grupo_profesional": "Grupo II — Personal No Sanitario",
          "nivel": 2,
          "salario_base_2026": sb2,
          "complemento_puesto_trabajo": cptTecnico,
          "salario_base_mensual": admin,
          "salario_anual": admin * 14,
          "num_pagas": 14,
          "hora_ordinaria": admin * 14 / horasAnuales,
        },
        // ── Nivel III ────────────────────────────────────────────────────
        {
          "id": "g2-n3-adiestrador",
          "nombre": "Adiestrador-Educador Canino",
          "grupo_profesional": "Grupo II — Personal No Sanitario",
          "nivel": 3,
          "salario_base_2026": sb3,
          "complemento_puesto_trabajo": 0.0,
          "salario_base_mensual": nivelIII,
          "salario_anual": nivelIII * 14,
          "num_pagas": 14,
          "hora_ordinaria": nivelIII * 14 / horasAnuales,
        },
        {
          "id": "g2-n3-peluquero-animales",
          "nombre": "Peluquero Animales de Compañía",
          "grupo_profesional": "Grupo II — Personal No Sanitario",
          "nivel": 3,
          "salario_base_2026": sb3,
          "complemento_puesto_trabajo": 0.0,
          "salario_base_mensual": nivelIII,
          "salario_anual": nivelIII * 14,
          "num_pagas": 14,
          "hora_ordinaria": nivelIII * 14 / horasAnuales,
          "nota": "Aplica este convenio, NO el de peluquería humana.",
        },
        {
          "id": "g2-n3-aux-administrativo",
          "nombre": "Auxiliar Administrativo",
          "grupo_profesional": "Grupo II — Personal No Sanitario",
          "nivel": 3,
          "salario_base_2026": sb3,
          "complemento_puesto_trabajo": 0.0,
          "salario_base_mensual": nivelIII,
          "salario_anual": nivelIII * 14,
          "num_pagas": 14,
          "hora_ordinaria": nivelIII * 14 / horasAnuales,
        },
        // ── Nivel IV ─────────────────────────────────────────────────────
        {
          "id": "g2-n4-limpieza-servicios",
          "nombre": "Personal de Limpieza / Servicios Generales",
          "grupo_profesional": "Grupo II — Personal No Sanitario",
          "nivel": 4,
          "salario_base_2026": sb4,
          "complemento_puesto_trabajo": 0.0,
          "salario_base_mensual": nivelIV,
          "salario_anual": nivelIV * 14,
          "num_pagas": 14,
          "hora_ordinaria": nivelIV * 14 / horasAnuales,
        },
      ],
      "pluses": [
        // ── Nocturnidad (22h-6h): 30% del valor hora salario base ─────
        {
          "id": "nocturnidad",
          "nombre": "Plus de nocturnidad (22h-6h)",
          "tipo": "porcentaje",
          "importe": 30.0,
          "base_calculo": "salario_base_hora",
          "descripcion": "30% del valor hora del salario base"
        },
        // ── Festividad (día festivo trabajado) ────────────────────────
        {
          "id": "festividad",
          "nombre": "Plus festividad (día festivo trabajado)",
          "tipo": "fijo",
          "importe": festividad2026,
          "base_calculo": "dia_festivo_trabajado"
        },
        // ── Festivo especial (1ene, 6ene, 25dic y noches previas) ────
        {
          "id": "festivo_especial",
          "nombre": "Plus festivo especial (1ene/6ene/25dic y noches)",
          "tipo": "fijo",
          "importe": festivoEsp2026,
          "base_calculo": "dia_festivo_especial",
          "descripcion": "1 enero, 6 enero, 25 diciembre y noches anteriores"
        },
        // ── Disponibilidad ordinaria (solo Grupo I sanitario) ─────────
        {
          "id": "disponibilidad_ordinaria",
          "nombre": "Disponibilidad ordinaria",
          "tipo": "fijo",
          "importe": dispOrd2026,
          "base_calculo": "jornada_disponibilidad",
          "aplica_a": "grupo_i_sanitario",
          "descripcion": "Solo personal sanitario Grupo I"
        },
        // ── Disponibilidad festivos (solo Grupo I sanitario) ──────────
        {
          "id": "disponibilidad_festivos",
          "nombre": "Disponibilidad festivos",
          "tipo": "fijo",
          "importe": dispFest2026,
          "base_calculo": "jornada_disponibilidad",
          "aplica_a": "grupo_i_sanitario"
        },
        // ── Disponibilidad festivos especiales (solo Grupo I) ─────────
        {
          "id": "disponibilidad_festivos_especiales",
          "nombre": "Disponibilidad festivos especiales",
          "tipo": "fijo",
          "importe": dispFestEsp2026,
          "base_calculo": "jornada_disponibilidad",
          "aplica_a": "grupo_i_sanitario",
          "descripcion": "1ene, 6ene, 25dic y noches anteriores"
        },
        // ── Dietas ───────────────────────────────────────────────────
        {
          "id": "dieta_media",
          "nombre": "Media dieta",
          "tipo": "fijo",
          "importe": dietaMedia2026,
          "base_calculo": "dia_desplazamiento"
        },
        {
          "id": "dieta_completa",
          "nombre": "Dieta completa",
          "tipo": "fijo",
          "importe": dietaCompleta2026,
          "base_calculo": "dia_desplazamiento"
        },
        // ── Kilometraje ──────────────────────────────────────────────
        {
          "id": "kilometraje",
          "nombre": "Kilometraje (vehículo propio)",
          "tipo": "fijo",
          "importe": km2026,
          "base_calculo": "km"
        },
      ],
      "jornada_laboral": {
        "horas_anuales": horasAnuales,
        "descansos": "Según art. 38 convenio — mínimo 1,5 días semanales",
        "vacaciones_dias_naturales": 30
      },
      "pagas_extra": [
        {"nombre": "Paga de Verano", "mes_pago": 6, "devengo": "semestral", "calculo": "SB + CPT + antigüedad"},
        {"nombre": "Paga de Navidad", "mes_pago": 12, "devengo": "semestral", "calculo": "SB + CPT + antigüedad"}
      ],
      "horas_extra": {
        "recargo": 1.50,
        "formula": "hora_ordinaria × 1,50 (150%)",
        "hora_jornada_continuada": "100% hora ordinaria",
        "hora_jornada_continuada_disponibilidad": "150% hora ordinaria",
        "hora_ordinaria_formula": "salario_anual / $horasAnuales"
      },
      "periodo_prueba": {
        "nivel_i": "6 meses",
        "niveles_ii_iii": "3 meses",
        "nivel_iv": "1 mes"
      },
      "preaviso_cese": {
        "nivel_i": "45 días",
        "nivel_ii": "30 días",
        "niveles_iii_iv": "20 días"
      }
    };

    final WriteBatch batch = _db.batch();
    final convenioDocRef = _conveniosRef.doc(convenioId);
    batch.set(convenioDocRef, data['convenio'] as Map<String, dynamic>);

    for (final catData in data['categorias'] as List<Map<String, dynamic>>) {
      final catId = catData['id'] as String;
      final catDocRef = convenioDocRef.collection('categorias').doc(catId);
      batch.set(catDocRef, catData);
    }

    for (final plusData in data['pluses'] as List<Map<String, dynamic>>) {
      final plusId = plusData['id'] as String;
      final plusDocRef = convenioDocRef.collection('pluses').doc(plusId);
      batch.set(plusDocRef, plusData);
    }

    await batch.commit();
    _log.i('✅ Datos del convenio de Veterinarios (Guadalajara, prórroga 2026) creados en Firestore.');
  }

  /// Siembra todos los convenios Fluixtech.
  /// Usa [force] para reescribir valores en caso de tablas nuevas.
  Future<void> seedConveniosFluixtech({bool force = false}) async {
    await seedConvenioHosteleriaGuadalajara(force: force);
    await seedConvenioComercioGuadalajara(force: force);
    await seedConvenioPeluqueriaEsteticaGimnasios(force: force);
    await seedConvenioCarniceriasGuadalajara2025(force: force);
    await seedConvenioVeterinariosGuadalajara2026(force: force);
  }

  Future<CategoriaConvenio?> obtenerCategoriaPorId(String convenioId, String categoriaId) async {
    final doc = await _conveniosRef.doc(convenioId).collection('categorias').doc(categoriaId).get();
    if (!doc.exists) return null;
    final data = doc.data()!..['id'] = doc.id;
    return CategoriaConvenio.fromMap(data);
  }
}






