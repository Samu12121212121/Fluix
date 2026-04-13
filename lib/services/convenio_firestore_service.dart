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
    // Si ya existe y no forzamos, solo actualizamos los datos 2026 que puedan
    // haber cambiado (merge: true en cada batch.set)
    if (doc.exists && !force) {
      _log.i('El convenio de Peluquerías/Estética/Gimnasios ya existe — actualizando tablas 2026.');
    } else {
      _log.i('Creando datos para el convenio de Peluquerías/Estética/Gimnasios...');
    }

    final data = {
      "convenio": {
        "nombre": "Convenio Colectivo de Peluquerías, Institutos de Belleza y Gimnasios",
        "codigo": "99010955011997",
        "ambito": "estatal",
        "sector": "peluqueria",
        "tipo_convenio": "sectorial_estatal",
        "fuente_legal": "BOE-A-2024-21671 (publicado 22/10/2024)",
        "vigencia": {
          "inicio": "2024-01-01",
          "fin": "2026-12-31",
          "estado_dato": "tablas_boe_2026_definitivas"
        },
        "fuente": {
          "documento": "Tablas salariales 2026 — BOE-A-2024-21671 (Ámbito estatal)",
          "fecha_extraccion": "2026-04-13",
          "version": "v2"
        },
        // Año de la última tabla disponible (permite filtrar selector de año)
        "anio_tabla_vigente": 2026,
        "anios_disponibles": [2024, 2025, 2026],
        "jornada_horas_anuales": 1750,
        "horas_extra_prohibidas": true,
        "horas_extra_nota": "Art. 28 — horas extraordinarias PROHIBIDAS por convenio",
        "pagas": 14,
        "plus_transporte_suprimido_desde": "2025-01-01",
      },
      "categorias": [
        {
          "id": "grupo-i",
          "nombre": "Grupo I",
          "grupo_profesional": "I",
          "descripcion": "Auxiliares — tareas básicas bajo supervisión: lavado, limpieza, recepción, higiene útiles",
          "salario_base_mensual": 1250.00,
          "salario_anual": 17500.00,
          "num_pagas": 14,
          "año_tabla": 2026,
          "jornada_horas_anuales": 1750,
        },
        {
          "id": "grupo-ii",
          "nombre": "Grupo II",
          "grupo_profesional": "II",
          "descripcion": "Oficiales — moldeados, cambios de color, recepción clientes, operaciones auxiliares",
          "salario_base_mensual": 1325.00,
          "salario_anual": 18550.00,
          "num_pagas": 14,
          "año_tabla": 2026,
          "jornada_horas_anuales": 1750,
        },
        {
          "id": "grupo-iii",
          "nombre": "Grupo III",
          "grupo_profesional": "III",
          "descripcion": "Técnicos grado medio — corte, color avanzado, estética, manicura, depilación, maquillaje social",
          "salario_base_mensual": 1350.00,
          "salario_anual": 18900.00,
          "num_pagas": 14,
          "año_tabla": 2026,
          "jornada_horas_anuales": 1750,
        },
        {
          "id": "grupo-iv",
          "nombre": "Grupo IV",
          "grupo_profesional": "IV",
          "descripcion": "Técnicos grado superior — diagnóstico capilar, micropigmentación, láser, fotodepilación, tratamientos faciales/corporales avanzados, gestión y mando",
          "salario_base_mensual": 1375.00,
          "salario_anual": 19250.00,
          "num_pagas": 14,
          "año_tabla": 2026,
          "jornada_horas_anuales": 1750,
        },
      ],
      "pluses": [
        // Plus transporte SUPRIMIDO desde 01/01/2025 — se mantiene con vigente:false
        // para que el cálculo no lo aplique en 2025/2026
        {
          "id": "plus_transporte",
          "nombre": "Plus transporte (suprimido desde 2025)",
          "tipo": "fijo",
          "importe": 0.0,
          "base_calculo": "mes",
          "vigente": false,
          "vigente_hasta": "2024-12-31",
          "nota": "Suprimido por acuerdo de mesa negociadora desde 01/01/2025"
        },
      ],
      "pagas_extra": [
        {
          "nombre": "Paga de Verano",
          "mes_pago": 6,
          "devengo": "semestral",
          "calculo": "30 días de salario base, abono máximo el 30 de junio"
        },
        {
          "nombre": "Paga de Navidad",
          "mes_pago": 12,
          "devengo": "semestral",
          "calculo": "30 días de salario base, abono máximo el 22 de diciembre"
        },
      ],
    };

    final WriteBatch batch = _db.batch();
    final convenioDocRef = _conveniosRef.doc(convenioId);
    // Usar merge:true para no borrar campos existentes que no estén en este seed
    batch.set(convenioDocRef, data['convenio'] as Map<String, dynamic>,
        SetOptions(merge: true));

    for (final catData in data['categorias'] as List<Map<String, dynamic>>) {
      final catId = catData['id'] as String;
      final catDocRef = convenioDocRef.collection('categorias').doc(catId);
      if (catData['salario_base_mensual'] == null) {
        final salarioAnual = (catData['salario_anual'] as num).toDouble();
        final numPagas = (catData['num_pagas'] as num).toInt();
        catData['salario_base_mensual'] = salarioAnual / numPagas;
      }
      // merge:true para preservar campos personalizados existentes
      batch.set(catDocRef, catData, SetOptions(merge: true));
    }

    for (final plusData in data['pluses'] as List<Map<String, dynamic>>) {
      final plusId = plusData['id'] as String;
      final plusDocRef = convenioDocRef.collection('pluses').doc(plusId);
      batch.set(plusDocRef, plusData, SetOptions(merge: true));
    }

    await batch.commit();
    _log.i('✅ Convenio Peluquerías/Estética/Gimnasios — tablas 2026 actualizadas en Firestore.');
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

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVENIO CONSTRUCCIÓN Y OBRAS PÚBLICAS — GUADALAJARA
  // Código: 19000105011981  |  Tablas 2025 y 2026 (provincial)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> seedConvenioConstruccionObrasPublicasGuadalajara({bool force = false}) async {
    const convenioId = 'construccion-obras-publicas-guadalajara';
    final doc = await _conveniosRef.doc(convenioId).get();
    if (doc.exists && !force) {
      _log.i('El convenio de Construcción y O.P. de Guadalajara ya existe en Firestore. No se hará nada.');
      return;
    }

    _log.i('Creando datos para el convenio de Construcción y Obras Públicas (Guadalajara 2025-2026)...');

    // Jornada anual de referencia del convenio estatal de construcción
    const int horasAnuales = 1736;

    // ── Tablas 2025 ───────────────────────────────────────────────────────
    final List<Map<String, dynamic>> categorias2025 = [
      {
        "id": "nivel-i-2025",
        "nombre": "Nivel I — Titulado Superior / Director (salario libre)",
        "grupo_profesional": "Nivel I",
        "nivel": 1, "anio": 2025, "salario_libre": true,
        "salario_base": 0.0, "plus_actividad_asistencia": 0.0, "plus_extrasalarial": 0.0,
        "salario_base_mensual": 0.0, "importe_vacaciones": 0.0,
        "paga_extra_importe": 0.0, "salario_anual": 0.0, "num_pagas": 14,
        "dieta_completa": 45.60, "media_dieta": 15.46,
        "nota": "Salario del Nivel I se pacta individualmente. El usuario debe introducir el salario acordado.",
      },
      {
        "id": "nivel-ii-2025",
        "nombre": "Nivel II — Titulado Superior / Jefe de Obra",
        "grupo_profesional": "Nivel II",
        "nivel": 2, "anio": 2025, "salario_libre": false,
        "salario_base": 1521.24, "plus_actividad_asistencia": 734.95, "plus_extrasalarial": 133.13,
        "salario_base_mensual": 2389.32, "importe_vacaciones": 2708.90,
        "paga_extra_importe": 2708.90, "salario_anual": 34409.22, "num_pagas": 14,
        "dieta_completa": 45.60, "media_dieta": 15.46,
      },
      {
        "id": "nivel-iii-2025",
        "nombre": "Nivel III — Titulado Medio / Jefe de Sección",
        "grupo_profesional": "Nivel III",
        "nivel": 3, "anio": 2025, "salario_libre": false,
        "salario_base": 1289.88, "plus_actividad_asistencia": 632.21, "plus_extrasalarial": 133.13,
        "salario_base_mensual": 2055.22, "importe_vacaciones": 2285.84,
        "paga_extra_importe": 2285.84, "salario_anual": 29464.94, "num_pagas": 14,
        "dieta_completa": 45.60, "media_dieta": 15.46,
      },
      {
        "id": "nivel-iv-2025",
        "nombre": "Nivel IV — Jefe Administrativo / Encargado General",
        "grupo_profesional": "Nivel IV",
        "nivel": 4, "anio": 2025, "salario_libre": false,
        "salario_base": 1256.75, "plus_actividad_asistencia": 628.09, "plus_extrasalarial": 133.13,
        "salario_base_mensual": 2017.97, "importe_vacaciones": 2241.48,
        "paga_extra_importe": 2241.48, "salario_anual": 28922.11, "num_pagas": 14,
        "dieta_completa": 38.02, "media_dieta": 15.05,
      },
      {
        "id": "nivel-v-2025",
        "nombre": "Nivel V — Encargado / Delineante",
        "grupo_profesional": "Nivel V",
        "nivel": 5, "anio": 2025, "salario_libre": false,
        "salario_base": 1201.41, "plus_actividad_asistencia": 554.97, "plus_extrasalarial": 133.13,
        "salario_base_mensual": 1889.51, "importe_vacaciones": 2086.18,
        "paga_extra_importe": 2086.18, "salario_anual": 27043.15, "num_pagas": 14,
        "dieta_completa": 38.02, "media_dieta": 15.05,
      },
      {
        "id": "nivel-vi-2025",
        "nombre": "Nivel VI — Capataz / Oficial Administrativo 1ª",
        "grupo_profesional": "Nivel VI",
        "nivel": 6, "anio": 2025, "salario_libre": false,
        "salario_base": 1086.96, "plus_actividad_asistencia": 500.59, "plus_extrasalarial": 133.13,
        "salario_base_mensual": 1720.68, "importe_vacaciones": 1888.46,
        "paga_extra_importe": 1888.46, "salario_anual": 24592.86, "num_pagas": 14,
        "dieta_completa": 37.62, "media_dieta": 12.91,
      },
      {
        "id": "nivel-vii-2025",
        "nombre": "Nivel VII — Oficial 1ª",
        "grupo_profesional": "Nivel VII",
        "nivel": 7, "anio": 2025, "salario_libre": false,
        "salario_base": 1070.98, "plus_actividad_asistencia": 491.14, "plus_extrasalarial": 133.13,
        "salario_base_mensual": 1695.25, "importe_vacaciones": 1840.49,
        "paga_extra_importe": 1840.49, "salario_anual": 24169.22, "num_pagas": 14,
        "dieta_completa": 37.62, "media_dieta": 12.91,
      },
      {
        "id": "nivel-viii-2025",
        "nombre": "Nivel VIII — Oficial 2ª",
        "grupo_profesional": "Nivel VIII",
        "nivel": 8, "anio": 2025, "salario_libre": false,
        "salario_base": 1065.52, "plus_actividad_asistencia": 451.01, "plus_extrasalarial": 133.13,
        "salario_base_mensual": 1649.66, "importe_vacaciones": 1749.22,
        "paga_extra_importe": 1749.22, "salario_anual": 23393.92, "num_pagas": 14,
        "dieta_completa": 34.01, "media_dieta": 12.91,
      },
      {
        "id": "nivel-ix-2025",
        "nombre": "Nivel IX — Oficial 3ª / Ayudante",
        "grupo_profesional": "Nivel IX",
        "nivel": 9, "anio": 2025, "salario_libre": false,
        "salario_base": 1039.78, "plus_actividad_asistencia": 387.67, "plus_extrasalarial": 133.13,
        "salario_base_mensual": 1560.58, "importe_vacaciones": 1689.25,
        "paga_extra_importe": 1689.25, "salario_anual": 22234.13, "num_pagas": 14,
        "dieta_completa": 34.01, "media_dieta": 12.91,
      },
      {
        "id": "nivel-x-2025",
        "nombre": "Nivel X — Especialista",
        "grupo_profesional": "Nivel X",
        "nivel": 10, "anio": 2025, "salario_libre": false,
        "salario_base": 1012.71, "plus_actividad_asistencia": 346.55, "plus_extrasalarial": 133.13,
        "salario_base_mensual": 1492.39, "importe_vacaciones": 1607.77,
        "paga_extra_importe": 1607.77, "salario_anual": 21239.60, "num_pagas": 14,
        "dieta_completa": 34.01, "media_dieta": 12.91,
      },
      {
        "id": "nivel-xi-2025",
        "nombre": "Nivel XI — Peón Especializado",
        "grupo_profesional": "Nivel XI",
        "nivel": 11, "anio": 2025, "salario_libre": false,
        "salario_base": 994.45, "plus_actividad_asistencia": 346.55, "plus_extrasalarial": 133.13,
        "salario_base_mensual": 1474.13, "importe_vacaciones": 1580.82,
        "paga_extra_importe": 1580.82, "salario_anual": 20957.89, "num_pagas": 14,
        "dieta_completa": 34.01, "media_dieta": 12.91,
      },
      {
        "id": "nivel-xii-2025",
        "nombre": "Nivel XII — Peón Ordinario",
        "grupo_profesional": "Nivel XII",
        "nivel": 12, "anio": 2025, "salario_libre": false,
        "salario_base": 991.61, "plus_actividad_asistencia": 346.55, "plus_extrasalarial": 133.13,
        "salario_base_mensual": 1471.29, "importe_vacaciones": 1579.07,
        "paga_extra_importe": 1579.07, "salario_anual": 20921.40, "num_pagas": 14,
        "dieta_completa": 34.01, "media_dieta": 12.91,
      },
    ];

    // ── Tablas 2026 ───────────────────────────────────────────────────────
    final List<Map<String, dynamic>> categorias2026 = [
      {
        "id": "nivel-i-2026",
        "nombre": "Nivel I — Titulado Superior / Director (salario libre)",
        "grupo_profesional": "Nivel I",
        "nivel": 1, "anio": 2026, "salario_libre": true,
        "salario_base": 0.0, "plus_actividad_asistencia": 0.0, "plus_extrasalarial": 0.0,
        "salario_base_mensual": 0.0, "importe_vacaciones": 0.0,
        "paga_extra_importe": 0.0, "salario_anual": 0.0, "num_pagas": 14,
        "hora_extra_diaria": 0.0,
        "plan_pensiones_mensual": 0.0, "plan_pensiones_vacaciones": 0.0,
        "plan_pensiones_paga_extra": 0.0, "plan_pensiones_anual": 0.0,
        "dieta_completa": 46.97, "media_dieta": 15.92,
        "nota": "Salario del Nivel I se pacta individualmente. El usuario debe introducir el salario acordado.",
      },
      {
        "id": "nivel-ii-2026",
        "nombre": "Nivel II — Titulado Superior / Jefe de Obra",
        "grupo_profesional": "Nivel II",
        "nivel": 2, "anio": 2026, "salario_libre": false,
        "salario_base": 1566.88, "plus_actividad_asistencia": 757.00, "plus_extrasalarial": 137.12,
        "salario_base_mensual": 2461.00, "importe_vacaciones": 2790.17,
        "paga_extra_importe": 2790.17, "salario_anual": 35441.51, "num_pagas": 14,
        "hora_extra_diaria": 0.0,
        "plan_pensiones_mensual": 50.43, "plan_pensiones_vacaciones": 60.54,
        "plan_pensiones_paga_extra": 60.54, "plan_pensiones_anual": 736.35,
        "dieta_completa": 46.97, "media_dieta": 15.92,
      },
      {
        "id": "nivel-iii-2026",
        "nombre": "Nivel III — Titulado Medio / Jefe de Sección",
        "grupo_profesional": "Nivel III",
        "nivel": 3, "anio": 2026, "salario_libre": false,
        "salario_base": 1328.58, "plus_actividad_asistencia": 651.18, "plus_extrasalarial": 137.12,
        "salario_base_mensual": 2116.88, "importe_vacaciones": 2354.42,
        "paga_extra_importe": 2354.42, "salario_anual": 30348.94, "num_pagas": 14,
        "hora_extra_diaria": 0.0,
        "plan_pensiones_mensual": 42.95, "plan_pensiones_vacaciones": 51.08,
        "plan_pensiones_paga_extra": 51.08, "plan_pensiones_anual": 625.69,
        "dieta_completa": 46.97, "media_dieta": 15.92,
      },
      {
        "id": "nivel-iv-2026",
        "nombre": "Nivel IV — Jefe Administrativo / Encargado General",
        "grupo_profesional": "Nivel IV",
        "nivel": 4, "anio": 2026, "salario_libre": false,
        "salario_base": 1294.45, "plus_actividad_asistencia": 646.93, "plus_extrasalarial": 137.12,
        "salario_base_mensual": 2078.50, "importe_vacaciones": 2308.72,
        "paga_extra_importe": 2308.72, "salario_anual": 29789.66, "num_pagas": 14,
        "hora_extra_diaria": 0.0,
        "plan_pensiones_mensual": 42.11, "plan_pensiones_vacaciones": 50.10,
        "plan_pensiones_paga_extra": 50.10, "plan_pensiones_anual": 613.51,
        "dieta_completa": 39.16, "media_dieta": 15.50,
      },
      {
        "id": "nivel-v-2026",
        "nombre": "Nivel V — Encargado / Delineante",
        "grupo_profesional": "Nivel V",
        "nivel": 5, "anio": 2026, "salario_libre": false,
        "salario_base": 1237.45, "plus_actividad_asistencia": 571.62, "plus_extrasalarial": 137.12,
        "salario_base_mensual": 1946.19, "importe_vacaciones": 2148.77,
        "paga_extra_importe": 2148.77, "salario_anual": 27854.40, "num_pagas": 14,
        "hora_extra_diaria": 0.0,
        "plan_pensiones_mensual": 39.25, "plan_pensiones_vacaciones": 46.63,
        "plan_pensiones_paga_extra": 46.63, "plan_pensiones_anual": 571.64,
        "dieta_completa": 39.16, "media_dieta": 15.50,
      },
      {
        "id": "nivel-vi-2026",
        "nombre": "Nivel VI — Capataz / Oficial Administrativo 1ª",
        "grupo_profesional": "Nivel VI",
        "nivel": 6, "anio": 2026, "salario_libre": false,
        "salario_base": 1119.57, "plus_actividad_asistencia": 515.61, "plus_extrasalarial": 137.12,
        "salario_base_mensual": 1772.30, "importe_vacaciones": 1945.11,
        "paga_extra_importe": 1945.11, "salario_anual": 25330.63, "num_pagas": 14,
        "hora_extra_diaria": 14.07,
        "plan_pensiones_mensual": 35.49, "plan_pensiones_vacaciones": 42.20,
        "plan_pensiones_paga_extra": 42.20, "plan_pensiones_anual": 516.99,
        "dieta_completa": 38.75, "media_dieta": 13.30,
      },
      {
        "id": "nivel-vii-2026",
        "nombre": "Nivel VII — Oficial 1ª",
        "grupo_profesional": "Nivel VII",
        "nivel": 7, "anio": 2026, "salario_libre": false,
        "salario_base": 1103.11, "plus_actividad_asistencia": 505.87, "plus_extrasalarial": 137.12,
        "salario_base_mensual": 1746.10, "importe_vacaciones": 1895.70,
        "paga_extra_importe": 1895.70, "salario_anual": 24894.20, "num_pagas": 14,
        "hora_extra_diaria": 14.18,
        "plan_pensiones_mensual": 34.91, "plan_pensiones_vacaciones": 41.13,
        "plan_pensiones_paga_extra": 41.13, "plan_pensiones_anual": 507.40,
        "dieta_completa": 38.75, "media_dieta": 13.30,
      },
      {
        "id": "nivel-viii-2026",
        "nombre": "Nivel VIII — Oficial 2ª",
        "grupo_profesional": "Nivel VIII",
        "nivel": 8, "anio": 2026, "salario_libre": false,
        "salario_base": 1097.49, "plus_actividad_asistencia": 464.54, "plus_extrasalarial": 137.12,
        "salario_base_mensual": 1699.15, "importe_vacaciones": 1801.70,
        "paga_extra_importe": 1801.70, "salario_anual": 24095.75, "num_pagas": 14,
        "hora_extra_diaria": 13.66,
        "plan_pensiones_mensual": 33.90, "plan_pensiones_vacaciones": 39.09,
        "plan_pensiones_paga_extra": 39.09, "plan_pensiones_anual": 490.17,
        "dieta_completa": 35.03, "media_dieta": 13.30,
      },
      {
        "id": "nivel-ix-2026",
        "nombre": "Nivel IX — Oficial 3ª / Ayudante",
        "grupo_profesional": "Nivel IX",
        "nivel": 9, "anio": 2026, "salario_libre": false,
        "salario_base": 1070.97, "plus_actividad_asistencia": 399.30, "plus_extrasalarial": 137.12,
        "salario_base_mensual": 1607.39, "importe_vacaciones": 1739.93,
        "paga_extra_importe": 1739.93, "salario_anual": 22901.08, "num_pagas": 14,
        "hora_extra_diaria": 13.01,
        "plan_pensiones_mensual": 31.89, "plan_pensiones_vacaciones": 37.75,
        "plan_pensiones_paga_extra": 37.75, "plan_pensiones_anual": 464.04,
        "dieta_completa": 35.03, "media_dieta": 13.30,
      },
      {
        "id": "nivel-x-2026",
        "nombre": "Nivel X — Especialista",
        "grupo_profesional": "Nivel X",
        "nivel": 10, "anio": 2026, "salario_libre": false,
        "salario_base": 1043.09, "plus_actividad_asistencia": 356.95, "plus_extrasalarial": 137.12,
        "salario_base_mensual": 1537.16, "importe_vacaciones": 1656.00,
        "paga_extra_importe": 1656.00, "salario_anual": 21876.76, "num_pagas": 14,
        "hora_extra_diaria": 12.42,
        "plan_pensiones_mensual": 30.37, "plan_pensiones_vacaciones": 35.93,
        "plan_pensiones_paga_extra": 35.93, "plan_pensiones_anual": 441.86,
        "dieta_completa": 35.03, "media_dieta": 13.30,
      },
      {
        "id": "nivel-xi-2026",
        "nombre": "Nivel XI — Peón Especializado",
        "grupo_profesional": "Nivel XI",
        "nivel": 11, "anio": 2026, "salario_libre": false,
        "salario_base": 1024.28, "plus_actividad_asistencia": 356.95, "plus_extrasalarial": 137.12,
        "salario_base_mensual": 1518.35, "importe_vacaciones": 1628.24,
        "paga_extra_importe": 1628.24, "salario_anual": 21586.57, "num_pagas": 14,
        "hora_extra_diaria": 12.30,
        "plan_pensiones_mensual": 29.97, "plan_pensiones_vacaciones": 35.34,
        "plan_pensiones_paga_extra": 35.34, "plan_pensiones_anual": 435.69,
        "dieta_completa": 35.03, "media_dieta": 13.30,
      },
      {
        "id": "nivel-xii-2026",
        "nombre": "Nivel XII — Peón Ordinario",
        "grupo_profesional": "Nivel XII",
        "nivel": 12, "anio": 2026, "salario_libre": false,
        "salario_base": 1021.36, "plus_actividad_asistencia": 356.95, "plus_extrasalarial": 137.12,
        "salario_base_mensual": 1515.43, "importe_vacaciones": 1626.44,
        "paga_extra_importe": 1626.44, "salario_anual": 21549.05, "num_pagas": 14,
        "hora_extra_diaria": 12.24,
        "plan_pensiones_mensual": 29.90, "plan_pensiones_vacaciones": 35.30,
        "plan_pensiones_paga_extra": 35.30, "plan_pensiones_anual": 434.80,
        "dieta_completa": 35.03, "media_dieta": 13.30,
      },
    ];

    // ── Datos del convenio ─────────────────────────────────────────────────
    final Map<String, dynamic> convenioData = {
      "nombre": "Convenio Colectivo de Construcción y Obras Públicas — Guadalajara",
      "codigo": "19000105011981",
      "ambito": "provincial",
      "sector": "construccion",
      "tipo_convenio": "sectorial_provincial",
      "provincia": "Guadalajara",
      "anio_vigente_defecto": 2026,
      "vigencia": {
        "inicio": "2025-01-01",
        "fin": "2026-12-31",
        "estado_dato": "tablas_2025_2026_provinciales"
      },
      "fuente": {
        "documento": "Tablas salariales Convenio Provincial Construcción Guadalajara 2025-2026",
        "fecha_extraccion": "2026-04-11",
        "version": "v1"
      },
      "nivel_i_salario_libre": true,
      "nota_nivel_i": "El salario del Nivel I se pacta individualmente. Introduce el salario acordado.",
      "horas_anuales": horasAnuales,
      "formula_anual": "Total×11 + Vac + PExt×2",
    };

    final List<Map<String, dynamic>> pluses = [
      {
        "id": "plus_actividad_asistencia",
        "nombre": "Plus de Actividad y Asistencia (PAA)",
        "tipo": "fijo", "importe": 0.0, "base_calculo": "segun_nivel",
        "descripcion": "Incluido en la tabla salarial por nivel."
      },
      {
        "id": "plus_extrasalarial",
        "nombre": "Plus Extrasalarial (PE)",
        "tipo": "fijo", "importe": 137.12, "base_calculo": "mes",
        "descripcion": "Plus extrasalarial mensual 2026 (133.13€ en 2025). No cotiza a SS."
      },
      // ── Dietas por grupo de niveles ──────────────────────────────────────
      {
        "id": "dieta_completa_niv_i_ii_iii",
        "nombre": "Dieta completa — Niveles I, II y III",
        "tipo": "fijo", "importe": 46.97, "base_calculo": "dia_desplazamiento",
        "aplica_niveles": [1, 2, 3], "importe_2025": 45.60
      },
      {
        "id": "media_dieta_niv_i_ii_iii",
        "nombre": "Media dieta — Niveles I, II y III",
        "tipo": "fijo", "importe": 15.92, "base_calculo": "dia_desplazamiento",
        "aplica_niveles": [1, 2, 3], "importe_2025": 15.46
      },
      {
        "id": "dieta_completa_niv_iv_v",
        "nombre": "Dieta completa — Niveles IV y V",
        "tipo": "fijo", "importe": 39.16, "base_calculo": "dia_desplazamiento",
        "aplica_niveles": [4, 5], "importe_2025": 38.02
      },
      {
        "id": "media_dieta_niv_iv_v",
        "nombre": "Media dieta — Niveles IV y V",
        "tipo": "fijo", "importe": 15.50, "base_calculo": "dia_desplazamiento",
        "aplica_niveles": [4, 5], "importe_2025": 15.05
      },
      {
        "id": "dieta_completa_niv_vi_vii",
        "nombre": "Dieta completa — Niveles VI y VII",
        "tipo": "fijo", "importe": 38.75, "base_calculo": "dia_desplazamiento",
        "aplica_niveles": [6, 7], "importe_2025": 37.62
      },
      {
        "id": "media_dieta_niv_vi_vii",
        "nombre": "Media dieta — Niveles VI y VII",
        "tipo": "fijo", "importe": 13.30, "base_calculo": "dia_desplazamiento",
        "aplica_niveles": [6, 7], "importe_2025": 12.91
      },
      {
        "id": "dieta_completa_resto",
        "nombre": "Dieta completa — Niveles VIII y ss.",
        "tipo": "fijo", "importe": 35.03, "base_calculo": "dia_desplazamiento",
        "aplica_niveles": [8, 9, 10, 11, 12], "importe_2025": 34.01
      },
      {
        "id": "media_dieta_resto",
        "nombre": "Media dieta — Niveles VIII y ss.",
        "tipo": "fijo", "importe": 13.30, "base_calculo": "dia_desplazamiento",
        "aplica_niveles": [8, 9, 10, 11, 12], "importe_2025": 12.91
      },
      // ── Horas extras diarias 2026 (Niveles VI-XII) ───────────────────────
      {"id": "hora_extra_vi",   "nombre": "Hora extra diaria — Nivel VI",   "tipo": "fijo", "importe": 14.07, "base_calculo": "hora_extra", "aplica_niveles": [6]},
      {"id": "hora_extra_vii",  "nombre": "Hora extra diaria — Nivel VII",  "tipo": "fijo", "importe": 14.18, "base_calculo": "hora_extra", "aplica_niveles": [7]},
      {"id": "hora_extra_viii", "nombre": "Hora extra diaria — Nivel VIII", "tipo": "fijo", "importe": 13.66, "base_calculo": "hora_extra", "aplica_niveles": [8]},
      {"id": "hora_extra_ix",   "nombre": "Hora extra diaria — Nivel IX",   "tipo": "fijo", "importe": 13.01, "base_calculo": "hora_extra", "aplica_niveles": [9]},
      {"id": "hora_extra_x",    "nombre": "Hora extra diaria — Nivel X",    "tipo": "fijo", "importe": 12.42, "base_calculo": "hora_extra", "aplica_niveles": [10]},
      {"id": "hora_extra_xi",   "nombre": "Hora extra diaria — Nivel XI",   "tipo": "fijo", "importe": 12.30, "base_calculo": "hora_extra", "aplica_niveles": [11]},
      {"id": "hora_extra_xii",  "nombre": "Hora extra diaria — Nivel XII",  "tipo": "fijo", "importe": 12.24, "base_calculo": "hora_extra", "aplica_niveles": [12]},
    ];

    final WriteBatch batch = _db.batch();
    final convenioDocRef = _conveniosRef.doc(convenioId);
    batch.set(convenioDocRef, convenioData);

    for (final catData in [...categorias2025, ...categorias2026]) {
      final catId = catData['id'] as String;
      batch.set(convenioDocRef.collection('categorias').doc(catId), catData);
    }

    for (final plusData in pluses) {
      final plusId = plusData['id'] as String;
      batch.set(convenioDocRef.collection('pluses').doc(plusId), plusData);
    }

    await batch.commit();
    _log.i('✅ Datos del convenio de Construcción y O.P. (Guadalajara 2025-2026) creados en Firestore.');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVENIO CONSTRUCCIÓN Y OBRAS PÚBLICAS — CUENCA
  // Código: 16000075011981  |  Vigencia 2022–2026
  // Jornada anual: 1.736 horas  |  2 pagas extras (junio y diciembre)
  // Fórmula: RA = SB×335 + (PS+PE)×díasEfectivos + ExtraJun + ExtraDic + Vac
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> seedConvenioConstruccionCuenca({bool force = false}) async {
    const convenioId = 'construccion-obras-publicas-cuenca';
    final doc = await _conveniosRef.doc(convenioId).get();
    if (doc.exists && !force) {
      _log.i('El convenio de Construcción y O.P. de Cuenca ya existe en Firestore.');
      return;
    }

    _log.i('Creando datos para el convenio de Construcción y Obras Públicas (Cuenca 2024-2026)...');

    const int horasAnuales = 1736;

    // ── Tablas 2024 ─────────────────────────────────────────────────────────
    final List<Map<String, dynamic>> categorias2024 = [
      {"id": "nivel-i-2024", "nombre": "Nivel I — Personal Directivo (salario libre)", "grupo_profesional": "Nivel I", "nivel": 1, "anio": 2024, "salario_libre": true, "sb_dia": 0.0, "plus_salarial_dia": 0.0, "plus_extrasalarial_dia": 0.0, "extra_junio": 0.0, "extra_dic": 0.0, "vacaciones": 0.0, "salario_base_mensual": 0.0, "salario_anual": 0.0, "num_pagas": 14, "nota": "Salario libre — introduce el salario acordado."},
      {"id": "nivel-ii-2024", "nombre": "Nivel II — Titulado Superior", "grupo_profesional": "Nivel II", "nivel": 2, "anio": 2024, "sb_dia": 48.44, "plus_salarial_dia": 1.14, "plus_extrasalarial_dia": 5.69, "extra_junio": 2130.99, "extra_dic": 2130.99, "vacaciones": 2130.99, "salario_base_mensual": 0.0, "salario_anual": 24100.64, "num_pagas": 14},
      {"id": "nivel-iii-2024", "nombre": "Nivel III — Titulado Medio, Jefe de Sección", "grupo_profesional": "Nivel III", "nivel": 3, "anio": 2024, "sb_dia": 47.69, "plus_salarial_dia": 1.14, "plus_extrasalarial_dia": 5.69, "extra_junio": 2098.04, "extra_dic": 2098.04, "vacaciones": 2098.04, "salario_base_mensual": 0.0, "salario_anual": 23756.98, "num_pagas": 14},
      {"id": "nivel-iv-2024", "nombre": "Nivel IV — Jefe de Personal, Encargado General", "grupo_profesional": "Nivel IV", "nivel": 4, "anio": 2024, "sb_dia": 46.41, "plus_salarial_dia": 1.14, "plus_extrasalarial_dia": 5.69, "extra_junio": 2040.55, "extra_dic": 2040.55, "vacaciones": 2040.55, "salario_base_mensual": 0.0, "salario_anual": 23149.83, "num_pagas": 14},
      {"id": "nivel-v-2024", "nombre": "Nivel V — Jefe Adm. 2ª, Delineante Superior", "grupo_profesional": "Nivel V", "nivel": 5, "anio": 2024, "sb_dia": 45.17, "plus_salarial_dia": 1.14, "plus_extrasalarial_dia": 5.69, "extra_junio": 1986.53, "extra_dic": 1986.53, "vacaciones": 1986.53, "salario_base_mensual": 0.0, "salario_anual": 22572.87, "num_pagas": 14},
      {"id": "nivel-vi-2024", "nombre": "Nivel VI — Oficial Adm. 1ª, Jefe de Taller", "grupo_profesional": "Nivel VI", "nivel": 6, "anio": 2024, "sb_dia": 43.91, "plus_salarial_dia": 1.14, "plus_extrasalarial_dia": 5.69, "extra_junio": 1931.70, "extra_dic": 1931.70, "vacaciones": 1931.70, "salario_base_mensual": 0.0, "salario_anual": 21983.52, "num_pagas": 14},
      {"id": "nivel-vii-2024", "nombre": "Nivel VII — Delineante 2ª, Capataz", "grupo_profesional": "Nivel VII", "nivel": 7, "anio": 2024, "sb_dia": 42.26, "plus_salarial_dia": 1.14, "plus_extrasalarial_dia": 5.69, "extra_junio": 1858.45, "extra_dic": 1858.45, "vacaciones": 1858.45, "salario_base_mensual": 0.0, "salario_anual": 21191.41, "num_pagas": 14},
      {"id": "nivel-viii-2024", "nombre": "Nivel VIII — Oficial Adm. 2ª, Oficial 1ª de Oficio", "grupo_profesional": "Nivel VIII", "nivel": 8, "anio": 2024, "sb_dia": 42.04, "plus_salarial_dia": 1.14, "plus_extrasalarial_dia": 5.69, "extra_junio": 1849.41, "extra_dic": 1849.41, "vacaciones": 1849.41, "salario_base_mensual": 0.0, "salario_anual": 21088.49, "num_pagas": 14},
      {"id": "nivel-ix-2024", "nombre": "Nivel IX — Auxiliar Adm., Oficial 2ª de Oficio", "grupo_profesional": "Nivel IX", "nivel": 9, "anio": 2024, "sb_dia": 40.42, "plus_salarial_dia": 1.14, "plus_extrasalarial_dia": 5.69, "extra_junio": 1776.81, "extra_dic": 1776.81, "vacaciones": 1776.81, "salario_base_mensual": 0.0, "salario_anual": 20340.24, "num_pagas": 14},
      {"id": "nivel-x-2024", "nombre": "Nivel X — Auxiliar Laboratorio, Ayudante de Oficio", "grupo_profesional": "Nivel X", "nivel": 10, "anio": 2024, "sb_dia": 38.92, "plus_salarial_dia": 1.14, "plus_extrasalarial_dia": 5.69, "extra_junio": 1710.49, "extra_dic": 1710.49, "vacaciones": 1710.49, "salario_base_mensual": 0.0, "salario_anual": 19635.22, "num_pagas": 14},
      {"id": "nivel-xi-2024", "nombre": "Nivel XI — Especialista 2ª, Peón Especialista", "grupo_profesional": "Nivel XI", "nivel": 11, "anio": 2024, "sb_dia": 38.21, "plus_salarial_dia": 1.14, "plus_extrasalarial_dia": 5.69, "extra_junio": 1681.96, "extra_dic": 1681.96, "vacaciones": 1681.96, "salario_base_mensual": 0.0, "salario_anual": 19327.14, "num_pagas": 14},
      {"id": "nivel-xii-2024", "nombre": "Nivel XII — Peón Ordinario, Limpiadora", "grupo_profesional": "Nivel XII", "nivel": 12, "anio": 2024, "sb_dia": 37.64, "plus_salarial_dia": 1.14, "plus_extrasalarial_dia": 5.69, "extra_junio": 1654.81, "extra_dic": 1654.81, "vacaciones": 1654.81, "salario_base_mensual": 0.0, "salario_anual": 19035.53, "num_pagas": 14},
    ];

    // ── Tablas 2025 ─────────────────────────────────────────────────────────
    final List<Map<String, dynamic>> categorias2025 = [
      {"id": "nivel-i-2025", "nombre": "Nivel I — Personal Directivo (salario libre)", "grupo_profesional": "Nivel I", "nivel": 1, "anio": 2025, "salario_libre": true, "sb_dia": 0.0, "plus_salarial_dia": 0.0, "plus_extrasalarial_dia": 0.0, "extra_junio": 0.0, "extra_dic": 0.0, "vacaciones": 0.0, "salario_base_mensual": 0.0, "salario_anual": 0.0, "num_pagas": 14, "nota": "Salario libre — introduce el salario acordado."},
      {"id": "nivel-ii-2025", "nombre": "Nivel II — Titulado Superior", "grupo_profesional": "Nivel II", "nivel": 2, "anio": 2025, "sb_dia": 50.33, "plus_salarial_dia": 1.18, "plus_extrasalarial_dia": 5.91, "extra_junio": 2214.10, "extra_dic": 2214.10, "vacaciones": 2214.10, "salario_base_mensual": 0.0, "salario_anual": 25040.57, "num_pagas": 14},
      {"id": "nivel-iii-2025", "nombre": "Nivel III — Titulado Medio, Jefe de Sección", "grupo_profesional": "Nivel III", "nivel": 3, "anio": 2025, "sb_dia": 49.55, "plus_salarial_dia": 1.18, "plus_extrasalarial_dia": 5.91, "extra_junio": 2179.86, "extra_dic": 2179.86, "vacaciones": 2179.86, "salario_base_mensual": 0.0, "salario_anual": 24690.50, "num_pagas": 14},
      {"id": "nivel-iv-2025", "nombre": "Nivel IV — Jefe de Personal, Encargado General", "grupo_profesional": "Nivel IV", "nivel": 4, "anio": 2025, "sb_dia": 48.22, "plus_salarial_dia": 1.18, "plus_extrasalarial_dia": 5.91, "extra_junio": 2120.13, "extra_dic": 2120.13, "vacaciones": 2120.13, "salario_base_mensual": 0.0, "salario_anual": 24032.47, "num_pagas": 14},
      {"id": "nivel-v-2025", "nombre": "Nivel V — Jefe Adm. 2ª, Delineante Superior", "grupo_profesional": "Nivel V", "nivel": 5, "anio": 2025, "sb_dia": 46.93, "plus_salarial_dia": 1.18, "plus_extrasalarial_dia": 5.91, "extra_junio": 2063.81, "extra_dic": 2063.81, "vacaciones": 2063.81, "salario_base_mensual": 0.0, "salario_anual": 23453.12, "num_pagas": 14},
      {"id": "nivel-vi-2025", "nombre": "Nivel VI — Oficial Adm. 1ª, Jefe de Taller", "grupo_profesional": "Nivel VI", "nivel": 6, "anio": 2025, "sb_dia": 45.62, "plus_salarial_dia": 1.18, "plus_extrasalarial_dia": 5.91, "extra_junio": 2006.94, "extra_dic": 2006.94, "vacaciones": 2006.94, "salario_base_mensual": 0.0, "salario_anual": 22820.88, "num_pagas": 14},
      {"id": "nivel-vii-2025", "nombre": "Nivel VII — Delineante 2ª, Capataz", "grupo_profesional": "Nivel VII", "nivel": 7, "anio": 2025, "sb_dia": 43.91, "plus_salarial_dia": 1.18, "plus_extrasalarial_dia": 5.91, "extra_junio": 1930.92, "extra_dic": 1930.92, "vacaciones": 1930.92, "salario_base_mensual": 0.0, "salario_anual": 22017.87, "num_pagas": 14},
      {"id": "nivel-viii-2025", "nombre": "Nivel VIII — Oficial Adm. 2ª, Oficial 1ª de Oficio", "grupo_profesional": "Nivel VIII", "nivel": 8, "anio": 2025, "sb_dia": 43.68, "plus_salarial_dia": 1.18, "plus_extrasalarial_dia": 5.91, "extra_junio": 1921.53, "extra_dic": 1921.53, "vacaciones": 1921.53, "salario_base_mensual": 0.0, "salario_anual": 21910.84, "num_pagas": 14},
      {"id": "nivel-ix-2025", "nombre": "Nivel IX — Auxiliar Adm., Oficial 2ª de Oficio", "grupo_profesional": "Nivel IX", "nivel": 9, "anio": 2025, "sb_dia": 42.00, "plus_salarial_dia": 1.18, "plus_extrasalarial_dia": 5.91, "extra_junio": 1845.80, "extra_dic": 1845.80, "vacaciones": 1845.80, "salario_base_mensual": 0.0, "salario_anual": 21133.51, "num_pagas": 14},
      {"id": "nivel-x-2025", "nombre": "Nivel X — Auxiliar Laboratorio, Ayudante de Oficio", "grupo_profesional": "Nivel X", "nivel": 10, "anio": 2025, "sb_dia": 40.44, "plus_salarial_dia": 1.18, "plus_extrasalarial_dia": 5.91, "extra_junio": 1776.28, "extra_dic": 1776.28, "vacaciones": 1776.28, "salario_base_mensual": 0.0, "salario_anual": 20401.99, "num_pagas": 14},
      {"id": "nivel-xi-2025", "nombre": "Nivel XI — Especialista 2ª, Peón Especialista", "grupo_profesional": "Nivel XI", "nivel": 11, "anio": 2025, "sb_dia": 39.70, "plus_salarial_dia": 1.18, "plus_extrasalarial_dia": 5.91, "extra_junio": 1747.40, "extra_dic": 1747.40, "vacaciones": 1747.40, "salario_base_mensual": 0.0, "salario_anual": 20066.90, "num_pagas": 14},
      {"id": "nivel-xii-2025", "nombre": "Nivel XII — Peón Ordinario, Limpiadora", "grupo_profesional": "Nivel XII", "nivel": 12, "anio": 2025, "sb_dia": 39.11, "plus_salarial_dia": 1.18, "plus_extrasalarial_dia": 5.91, "extra_junio": 1719.44, "extra_dic": 1719.44, "vacaciones": 1719.44, "salario_base_mensual": 0.0, "salario_anual": 19773.91, "num_pagas": 14},
    ];

    // ── Tablas 2026 ─────────────────────────────────────────────────────────
    final List<Map<String, dynamic>> categorias2026 = [
      {"id": "nivel-i-2026", "nombre": "Nivel I — Personal Directivo (salario libre)", "grupo_profesional": "Nivel I", "nivel": 1, "anio": 2026, "salario_libre": true, "sb_dia": 0.0, "plus_salarial_dia": 0.0, "plus_extrasalarial_dia": 0.0, "extra_junio": 0.0, "extra_dic": 0.0, "vacaciones": 0.0, "salario_base_mensual": 0.0, "salario_anual": 0.0, "num_pagas": 14, "nota": "Salario libre — introduce el salario acordado."},
      {"id": "nivel-ii-2026", "nombre": "Nivel II — Titulado Superior", "grupo_profesional": "Nivel II", "nivel": 2, "anio": 2026, "sb_dia": 51.84, "plus_salarial_dia": 1.22, "plus_extrasalarial_dia": 6.09, "extra_junio": 2280.52, "extra_dic": 2280.52, "vacaciones": 2280.52, "salario_base_mensual": 0.0, "salario_anual": 25791.79, "num_pagas": 14},
      {"id": "nivel-iii-2026", "nombre": "Nivel III — Titulado Medio, Jefe de Sección", "grupo_profesional": "Nivel III", "nivel": 3, "anio": 2026, "sb_dia": 51.04, "plus_salarial_dia": 1.22, "plus_extrasalarial_dia": 6.09, "extra_junio": 2245.25, "extra_dic": 2245.25, "vacaciones": 2245.25, "salario_base_mensual": 0.0, "salario_anual": 25430.22, "num_pagas": 14},
      {"id": "nivel-iv-2026", "nombre": "Nivel IV — Jefe de Personal, Encargado General", "grupo_profesional": "Nivel IV", "nivel": 4, "anio": 2026, "sb_dia": 49.67, "plus_salarial_dia": 1.22, "plus_extrasalarial_dia": 6.09, "extra_junio": 2183.73, "extra_dic": 2183.73, "vacaciones": 2183.73, "salario_base_mensual": 0.0, "salario_anual": 24753.44, "num_pagas": 14},
      {"id": "nivel-v-2026", "nombre": "Nivel V — Jefe Adm. 2ª, Delineante Superior", "grupo_profesional": "Nivel V", "nivel": 5, "anio": 2026, "sb_dia": 48.34, "plus_salarial_dia": 1.22, "plus_extrasalarial_dia": 6.09, "extra_junio": 2125.72, "extra_dic": 2125.72, "vacaciones": 2125.72, "salario_base_mensual": 0.0, "salario_anual": 24156.71, "num_pagas": 14},
      {"id": "nivel-vi-2026", "nombre": "Nivel VI — Oficial Adm. 1ª, Jefe de Taller", "grupo_profesional": "Nivel VI", "nivel": 6, "anio": 2026, "sb_dia": 46.99, "plus_salarial_dia": 1.22, "plus_extrasalarial_dia": 6.09, "extra_junio": 2067.15, "extra_dic": 2067.15, "vacaciones": 2067.15, "salario_base_mensual": 0.0, "salario_anual": 23505.51, "num_pagas": 14},
      {"id": "nivel-vii-2026", "nombre": "Nivel VII — Delineante 2ª, Capataz", "grupo_profesional": "Nivel VII", "nivel": 7, "anio": 2026, "sb_dia": 45.23, "plus_salarial_dia": 1.22, "plus_extrasalarial_dia": 6.09, "extra_junio": 1988.85, "extra_dic": 1988.85, "vacaciones": 1988.85, "salario_base_mensual": 0.0, "salario_anual": 22678.41, "num_pagas": 14},
      {"id": "nivel-viii-2026", "nombre": "Nivel VIII — Oficial Adm. 2ª, Oficial 1ª de Oficio", "grupo_profesional": "Nivel VIII", "nivel": 8, "anio": 2026, "sb_dia": 44.99, "plus_salarial_dia": 1.22, "plus_extrasalarial_dia": 6.09, "extra_junio": 1979.17, "extra_dic": 1979.17, "vacaciones": 1979.17, "salario_base_mensual": 0.0, "salario_anual": 22568.17, "num_pagas": 14},
      {"id": "nivel-ix-2026", "nombre": "Nivel IX — Auxiliar Adm., Oficial 2ª de Oficio", "grupo_profesional": "Nivel IX", "nivel": 9, "anio": 2026, "sb_dia": 43.26, "plus_salarial_dia": 1.22, "plus_extrasalarial_dia": 6.09, "extra_junio": 1901.17, "extra_dic": 1901.17, "vacaciones": 1901.17, "salario_base_mensual": 0.0, "salario_anual": 21767.51, "num_pagas": 14},
      {"id": "nivel-x-2026", "nombre": "Nivel X — Auxiliar Laboratorio, Ayudante de Oficio", "grupo_profesional": "Nivel X", "nivel": 10, "anio": 2026, "sb_dia": 41.65, "plus_salarial_dia": 1.22, "plus_extrasalarial_dia": 6.09, "extra_junio": 1829.57, "extra_dic": 1829.57, "vacaciones": 1829.57, "salario_base_mensual": 0.0, "salario_anual": 21014.05, "num_pagas": 14},
      {"id": "nivel-xi-2026", "nombre": "Nivel XI — Especialista 2ª, Peón Especialista", "grupo_profesional": "Nivel XI", "nivel": 11, "anio": 2026, "sb_dia": 40.89, "plus_salarial_dia": 1.22, "plus_extrasalarial_dia": 6.09, "extra_junio": 1799.82, "extra_dic": 1799.82, "vacaciones": 1799.82, "salario_base_mensual": 0.0, "salario_anual": 20668.91, "num_pagas": 14},
      {"id": "nivel-xii-2026", "nombre": "Nivel XII — Peón Ordinario, Limpiadora", "grupo_profesional": "Nivel XII", "nivel": 12, "anio": 2026, "sb_dia": 40.28, "plus_salarial_dia": 1.22, "plus_extrasalarial_dia": 6.09, "extra_junio": 1771.02, "extra_dic": 1771.02, "vacaciones": 1771.02, "salario_base_mensual": 0.0, "salario_anual": 20367.13, "num_pagas": 14},
    ];

    final Map<String, dynamic> convenioData = {
      "nombre": "Convenio Colectivo de Construcción y Obras Públicas — Cuenca",
      "codigo": "16000075011981",
      "ambito": "provincial",
      "sector": "construccion",
      "tipo_convenio": "sectorial_provincial",
      "provincia": "Cuenca",
      "anio_vigente_defecto": 2026,
      "vigencia": {"inicio": "2022-01-01", "fin": "2026-12-31", "estado_dato": "tablas_2024_2025_2026"},
      "fuente": {"documento": "Tablas salariales Convenio Provincial Construcción Cuenca 2022-2026", "fecha_extraccion": "2026-04-12", "version": "v1"},
      "nivel_i_salario_libre": true,
      "nota_nivel_i": "El salario del Nivel I se pacta individualmente. Introduce el salario acordado.",
      "horas_anuales": horasAnuales,
      "formula_anual": "SB×335 + (PlusSalarial+PlusExtrasalarial)×díasEfectivos + ExtraJunio + ExtraDic + Vacaciones",
    };

    final List<Map<String, dynamic>> pluses = [
      {"id": "plus_salarial", "nombre": "Plus Salarial (por día trabajado)", "tipo": "fijo", "importe": 1.22, "base_calculo": "dia_trabajado", "importe_2025": 1.18, "importe_2024": 1.14},
      {"id": "plus_extrasalarial", "nombre": "Plus Extrasalarial (por día trabajado)", "tipo": "fijo", "importe": 6.09, "base_calculo": "dia_trabajado", "importe_2025": 5.91, "importe_2024": 5.69, "descripcion": "No cotiza a SS."},
      {"id": "nocturnidad", "nombre": "Plus Nocturno (22h-6h)", "tipo": "porcentaje", "importe": 25.0, "base_calculo": "salario_base"},
      {"id": "penosidad_completa", "nombre": "Plus Penosidad/Toxicidad (jornada completa)", "tipo": "porcentaje", "importe": 20.0, "base_calculo": "salario_base"},
      {"id": "penosidad_media", "nombre": "Plus Penosidad/Toxicidad (media jornada)", "tipo": "porcentaje", "importe": 10.0, "base_calculo": "salario_base"},
      {"id": "conservacion_carreteras", "nombre": "Plus Conservación Carreteras", "tipo": "fijo", "importe": 4.00, "base_calculo": "dia_trabajado", "descripcion": "Fijo, no se revisa anualmente."},
      {"id": "horas_extra", "nombre": "Horas extraordinarias (+25%)", "tipo": "porcentaje", "importe": 125.0, "base_calculo": "hora_ordinaria", "descripcion": "Valor hora tabla × 1,25"},
      {"id": "dieta_completa_2026", "nombre": "Dieta completa 2026", "tipo": "fijo", "importe": 32.63, "base_calculo": "dia_desplazamiento"},
      {"id": "media_dieta_2026", "nombre": "Media dieta 2026", "tipo": "fijo", "importe": 13.81, "base_calculo": "dia_desplazamiento"},
      {"id": "desgaste_herramienta_2026", "nombre": "Desgaste herramienta 2026", "tipo": "fijo", "importe": 0.86, "base_calculo": "dia_trabajado"},
      {"id": "dieta_completa_2025", "nombre": "Dieta completa 2025", "tipo": "fijo", "importe": 31.68, "base_calculo": "dia_desplazamiento"},
      {"id": "media_dieta_2025", "nombre": "Media dieta 2025", "tipo": "fijo", "importe": 13.41, "base_calculo": "dia_desplazamiento"},
      {"id": "desgaste_herramienta_2025", "nombre": "Desgaste herramienta 2025", "tipo": "fijo", "importe": 0.83, "base_calculo": "dia_trabajado"},
      {"id": "dieta_completa_2024", "nombre": "Dieta completa 2024", "tipo": "fijo", "importe": 30.49, "base_calculo": "dia_desplazamiento"},
      {"id": "media_dieta_2024", "nombre": "Media dieta 2024", "tipo": "fijo", "importe": 12.92, "base_calculo": "dia_desplazamiento"},
      {"id": "desgaste_herramienta_2024", "nombre": "Desgaste herramienta 2024", "tipo": "fijo", "importe": 0.80, "base_calculo": "dia_trabajado"},
    ];

    final WriteBatch batch = _db.batch();
    final convenioDocRef = _conveniosRef.doc(convenioId);
    batch.set(convenioDocRef, convenioData);

    for (final catData in [...categorias2024, ...categorias2025, ...categorias2026]) {
      final catId = catData['id'] as String;
      batch.set(convenioDocRef.collection('categorias').doc(catId), catData);
    }
    for (final plusData in pluses) {
      final plusId = plusData['id'] as String;
      batch.set(convenioDocRef.collection('pluses').doc(plusId), plusData);
    }

    await batch.commit();
    _log.i('✅ Datos del convenio de Construcción y O.P. (Cuenca 2024-2026) creados en Firestore.');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVENIO HOSTELERÍA — CUENCA
  // Código: 16000125011981  |  Vigencia 2022-2024 (prorrogado)
  // Jornada anual: 1.800 horas  |  15 pagas (12 + 3 extras)
  // Estructura: SB + Plus Compensatorio + CLC (en 15 pagas) + complementos
  // Grupo A (hoteles 4-5★, rest. 4-5 tenedores...) / Grupo B (1-3★, hostales...)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> seedConvenioHosteleriaCuenca({bool force = false}) async {
    const convenioId = 'hosteleria-cuenca';
    final doc = await _conveniosRef.doc(convenioId).get();
    if (doc.exists && !force) {
      _log.i('El convenio de Hostelería de Cuenca ya existe en Firestore.');
      return;
    }

    _log.i('Creando datos para el convenio de Hostelería (Cuenca 2022-2025)...');

    // ── Tablas 2022 (ene-sep, tablas 2021) ──────────────────────────────────
    final List<Map<String, dynamic>> categorias2022a = [
      {"id": "2022a-ga-i",  "nombre": "Nivel I (Grupo A)", "grupo_profesional": "Grupo A — Nivel I",  "nivel": 1, "anio": 2022, "periodo": "ene-sep", "grupo_establecimiento": "A", "sb_anual": 14812.65, "plus_comp_anual": 1296.15, "clc_anual": 887.16, "salario_base_mensual": 987.51, "salario_anual": 16995.96, "num_pagas": 15},
      {"id": "2022a-ga-ii", "nombre": "Nivel II (Grupo A)", "grupo_profesional": "Grupo A — Nivel II", "nivel": 2, "anio": 2022, "periodo": "ene-sep", "grupo_establecimiento": "A", "sb_anual": 14480.25, "plus_comp_anual": 1267.05, "clc_anual": 887.16, "salario_base_mensual": 965.35, "salario_anual": 16634.46, "num_pagas": 15},
      {"id": "2022a-ga-iii","nombre": "Nivel III (Grupo A)","grupo_profesional": "Grupo A — Nivel III","nivel": 3, "anio": 2022, "periodo": "ene-sep", "grupo_establecimiento": "A", "sb_anual": 14149.80, "plus_comp_anual": 1238.10, "clc_anual": 887.16, "salario_base_mensual": 943.32, "salario_anual": 16275.06, "num_pagas": 15},
      {"id": "2022a-ga-iv", "nombre": "Nivel IV (Grupo A)", "grupo_profesional": "Grupo A — Nivel IV", "nivel": 4, "anio": 2022, "periodo": "ene-sep", "grupo_establecimiento": "A", "sb_anual": 13992.15, "plus_comp_anual": 1224.30, "clc_anual": 887.16, "salario_base_mensual": 932.81, "salario_anual": 16103.61, "num_pagas": 15},
      {"id": "2022a-gb-i",  "nombre": "Nivel I (Grupo B)", "grupo_profesional": "Grupo B — Nivel I",  "nivel": 1, "anio": 2022, "periodo": "ene-sep", "grupo_establecimiento": "B", "sb_anual": 14778.30, "plus_comp_anual": 1293.15, "clc_anual": 887.16, "salario_base_mensual": 985.22, "salario_anual": 16958.61, "num_pagas": 15},
      {"id": "2022a-gb-ii", "nombre": "Nivel II (Grupo B)", "grupo_profesional": "Grupo B — Nivel II", "nivel": 2, "anio": 2022, "periodo": "ene-sep", "grupo_establecimiento": "B", "sb_anual": 14409.75, "plus_comp_anual": 1260.90, "clc_anual": 887.16, "salario_base_mensual": 960.65, "salario_anual": 16557.81, "num_pagas": 15},
      {"id": "2022a-gb-iii","nombre": "Nivel III (Grupo B)","grupo_profesional": "Grupo B — Nivel III","nivel": 3, "anio": 2022, "periodo": "ene-sep", "grupo_establecimiento": "B", "sb_anual": 14026.20, "plus_comp_anual": 1227.30, "clc_anual": 887.16, "salario_base_mensual": 935.08, "salario_anual": 16140.66, "num_pagas": 15},
      {"id": "2022a-gb-iv", "nombre": "Nivel IV (Grupo B)", "grupo_profesional": "Grupo B — Nivel IV", "nivel": 4, "anio": 2022, "periodo": "ene-sep", "grupo_establecimiento": "B", "sb_anual": 13880.10, "plus_comp_anual": 1214.55, "clc_anual": 887.16, "salario_base_mensual": 925.34, "salario_anual": 15981.81, "num_pagas": 15},
    ];

    // ── Tablas 2025 (+1,9% sobre 2024, vigentes) ────────────────────────────
    final List<Map<String, dynamic>> categorias2025 = [
      {"id": "2025-ga-i",  "nombre": "Nivel I (Grupo A)", "grupo_profesional": "Grupo A — Nivel I",  "nivel": 1, "anio": 2025, "grupo_establecimiento": "A", "sb_anual": 16175.05, "plus_comp_anual": 1415.39, "clc_anual": 968.70, "salario_base_mensual": 1078.34, "salario_anual": 18559.14, "num_pagas": 15},
      {"id": "2025-ga-ii", "nombre": "Nivel II (Grupo A)", "grupo_profesional": "Grupo A — Nivel II", "nivel": 2, "anio": 2025, "grupo_establecimiento": "A", "sb_anual": 15812.03, "plus_comp_anual": 1383.45, "clc_anual": 968.70, "salario_base_mensual": 1054.14, "salario_anual": 18164.18, "num_pagas": 15},
      {"id": "2025-ga-iii","nombre": "Nivel III (Grupo A)","grupo_profesional": "Grupo A — Nivel III","nivel": 3, "anio": 2025, "grupo_establecimiento": "A", "sb_anual": 15451.15, "plus_comp_anual": 1351.96, "clc_anual": 968.70, "salario_base_mensual": 1030.08, "salario_anual": 17771.81, "num_pagas": 15},
      {"id": "2025-ga-iv", "nombre": "Nivel IV (Grupo A)", "grupo_profesional": "Grupo A — Nivel IV", "nivel": 4, "anio": 2025, "grupo_establecimiento": "A", "sb_anual": 15279.04, "plus_comp_anual": 1336.98, "clc_anual": 968.70, "salario_base_mensual": 1018.60, "salario_anual": 17584.72, "num_pagas": 15},
      {"id": "2025-gb-i",  "nombre": "Nivel I (Grupo B)", "grupo_profesional": "Grupo B — Nivel I",  "nivel": 1, "anio": 2025, "grupo_establecimiento": "B", "sb_anual": 16137.60, "plus_comp_anual": 1412.18, "clc_anual": 968.70, "salario_base_mensual": 1075.84, "salario_anual": 18518.48, "num_pagas": 15},
      {"id": "2025-gb-ii", "nombre": "Nivel II (Grupo B)", "grupo_profesional": "Grupo B — Nivel II", "nivel": 2, "anio": 2025, "grupo_establecimiento": "B", "sb_anual": 15735.14, "plus_comp_anual": 1376.87, "clc_anual": 968.70, "salario_base_mensual": 1049.01, "salario_anual": 18080.71, "num_pagas": 15},
      {"id": "2025-gb-iii","nombre": "Nivel III (Grupo B)","grupo_profesional": "Grupo B — Nivel III","nivel": 3, "anio": 2025, "grupo_establecimiento": "B", "sb_anual": 15316.18, "plus_comp_anual": 1340.19, "clc_anual": 968.70, "salario_base_mensual": 1021.08, "salario_anual": 17625.07, "num_pagas": 15},
      {"id": "2025-gb-iv", "nombre": "Nivel IV (Grupo B)", "grupo_profesional": "Grupo B — Nivel IV", "nivel": 4, "anio": 2025, "grupo_establecimiento": "B", "sb_anual": 15156.61, "plus_comp_anual": 1326.28, "clc_anual": 968.70, "salario_base_mensual": 1010.44, "salario_anual": 17451.59, "num_pagas": 15},
    ];

    final Map<String, dynamic> convenioData = {
      "nombre": "Convenio Colectivo de Hostelería — Cuenca",
      "codigo": "16000125011981",
      "ambito": "provincial",
      "sector": "hosteleria",
      "tipo_convenio": "sectorial_provincial",
      "provincia": "Cuenca",
      "anio_vigente_defecto": 2025,
      "vigencia": {"inicio": "2022-01-01", "fin": "2024-12-31", "prorroga": true, "estado_dato": "tablas_2025_revision_1_9_pct"},
      "fuente": {"documento": "Tablas salariales Hostelería Cuenca 2022-2025 (+1,9% sobre 2024)", "fecha_extraccion": "2026-04-12", "version": "v1"},
      "horas_anuales": 1800,
      "selector_grupo_establecimiento": true,
      "grupos_establecimiento": {
        "A": "Hoteles 4-5★, restaurantes 4-5 tenedores, cafeterías 3 tazas, catering público, bares categoría especial/1ª, casinos",
        "B": "Hoteles 1-3★, hostales, pensiones, restaurantes 1-3 tenedores, cafeterías 1-2 tazas, bares 2ª/3ª/4ª, casas rurales"
      },
      "formula_salario_hora": "(SB + CLC + CPA + PCA) / 1.800",
    };

    final List<Map<String, dynamic>> pluses = [
      {"id": "nocturnidad", "nombre": "Plus Nocturnidad (22h-8h)", "tipo": "compensacion_jornada", "importe": 1.25, "base_calculo": "hora", "descripcion": "1 hora nocturna = 1,25 horas de jornada"},
      {"id": "festivos", "nombre": "Plus Festivos trabajados", "tipo": "compensacion_jornada", "importe": 1.75, "base_calculo": "hora", "descripcion": "1 hora festiva = 1,75 horas de jornada"},
      {"id": "horas_extra", "nombre": "Horas extraordinarias monetizadas", "tipo": "porcentaje", "importe": 175.0, "base_calculo": "hora_ordinaria", "descripcion": "175% de la hora ordinaria"},
      {"id": "complemento_formacion", "nombre": "Complemento de Formación (2025)", "tipo": "fijo", "importe": 274.64, "base_calculo": "anual_12_pagas"},
      {"id": "limpieza_uniformes", "nombre": "Limpieza de Uniformes (2025)", "tipo": "fijo", "importe": 180.61, "base_calculo": "anual_12_pagas"},
      {"id": "complemento_calzado", "nombre": "Complemento de Calzado (2025)", "tipo": "fijo", "importe": 45.61, "base_calculo": "anual_12_pagas"},
      {"id": "manutencion", "nombre": "Manutención (2025)", "tipo": "fijo", "importe": 371.36, "base_calculo": "anual_12_pagas", "descripcion": "En especie o compensación económica"},
      {"id": "alojamiento", "nombre": "Alojamiento (2025)", "tipo": "fijo", "importe": 636.10, "base_calculo": "anual_12_pagas", "descripcion": "En especie o compensación económica"},
    ];

    final WriteBatch batch = _db.batch();
    final convenioDocRef = _conveniosRef.doc(convenioId);
    batch.set(convenioDocRef, convenioData);

    for (final catData in [...categorias2022a, ...categorias2025]) {
      final catId = catData['id'] as String;
      batch.set(convenioDocRef.collection('categorias').doc(catId), catData);
    }
    for (final plusData in pluses) {
      final plusId = plusData['id'] as String;
      batch.set(convenioDocRef.collection('pluses').doc(plusId), plusData);
    }

    await batch.commit();
    _log.i('✅ Datos del convenio de Hostelería (Cuenca 2022-2025) creados en Firestore.');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVENIO COMERCIO EN GENERAL — CUENCA
  // Código: 16000055011981  |  Vigencia 2025-2028
  // Jornada anual: 1.800 horas  |  15,5 pagas (12 + Nav + Jul + Benef + ½ Prom.Cult.)
  // RA = (SB + PlusComp + PlusConv) × 15,5
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> seedConvenioComercioCuenca({bool force = false}) async {
    const convenioId = 'comercio-general-cuenca';
    final doc = await _conveniosRef.doc(convenioId).get();
    if (doc.exists && !force) {
      _log.i('El convenio de Comercio en General de Cuenca ya existe en Firestore.');
      return;
    }

    _log.i('Creando datos para el convenio de Comercio en General (Cuenca 2025-2026)...');

    // ── Tablas 2025 (BOP 14/11/2025 + modificación BOP 24/11/2025) ──────────
    final List<Map<String, dynamic>> categorias2025 = [
      {"id": "nivel-1-2025",  "nombre": "Nivel 1 — Director/a Área Ventas/Almacén",               "grupo_profesional": "Nivel 1",  "nivel": 1,  "anio": 2025, "sb_mensual": 1212.17, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1305.40, "salario_anual": 20233.59, "num_pagas": 15},
      {"id": "nivel-2-2025",  "nombre": "Nivel 2 — Titulado/a Univ. Grado Superior, Subdirector/a","grupo_profesional": "Nivel 2",  "nivel": 2,  "anio": 2025, "sb_mensual": 1181.26, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1274.49, "salario_anual": 19754.59, "num_pagas": 15},
      {"id": "nivel-3-2025",  "nombre": "Nivel 3 — Jefe/a de Área, Supervisor/a",                 "grupo_profesional": "Nivel 3",  "nivel": 3,  "anio": 2025, "sb_mensual": 1162.75, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1255.98, "salario_anual": 19467.59, "num_pagas": 15},
      {"id": "nivel-4-2025",  "nombre": "Nivel 4 — Jefe/a de Departamento",                       "grupo_profesional": "Nivel 4",  "nivel": 4,  "anio": 2025, "sb_mensual": 1150.43, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1243.66, "salario_anual": 19276.59, "num_pagas": 15},
      {"id": "nivel-5-2025",  "nombre": "Nivel 5 — Dependiente/a Mayor, Titulado/a Medio",        "grupo_profesional": "Nivel 5",  "nivel": 5,  "anio": 2025, "sb_mensual": 1132.75, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1225.98, "salario_anual": 19002.59, "num_pagas": 15},
      {"id": "nivel-6-2025",  "nombre": "Nivel 6 — Jefe/a Administrativo/a, Jefe/a Establecimiento","grupo_profesional": "Nivel 6","nivel": 6,  "anio": 2025, "sb_mensual": 1111.39, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1204.62, "salario_anual": 18671.59, "num_pagas": 15},
      {"id": "nivel-7-2025",  "nombre": "Nivel 7 — Encargado/a Logística, Secretario/a",          "grupo_profesional": "Nivel 7",  "nivel": 7,  "anio": 2025, "sb_mensual": 1100.75, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1193.98, "salario_anual": 18506.59, "num_pagas": 15},
      {"id": "nivel-8-2025",  "nombre": "Nivel 8 — Jefe/a Sección Adm./Comercial/Logística",      "grupo_profesional": "Nivel 8",  "nivel": 8,  "anio": 2025, "sb_mensual": 1083.20, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1176.43, "salario_anual": 18234.59, "num_pagas": 15},
      {"id": "nivel-9-2025",  "nombre": "Nivel 9 — Técnico/a Servicio Auxiliar/Adm./Logística",   "grupo_profesional": "Nivel 9",  "nivel": 9,  "anio": 2025, "sb_mensual": 1071.46, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1164.69, "salario_anual": 18052.59, "num_pagas": 15},
      {"id": "nivel-10-2025", "nombre": "Nivel 10 — Cajero/a, Oficial Adm., Dependiente/a Base",  "grupo_profesional": "Nivel 10", "nivel": 10, "anio": 2025, "sb_mensual": 1060.36, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1153.59, "salario_anual": 17880.59, "num_pagas": 15},
      {"id": "nivel-11-2025", "nombre": "Nivel 11 — Viajante, Especialista A",                    "grupo_profesional": "Nivel 11", "nivel": 11, "anio": 2025, "sb_mensual": 1038.94, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1132.17, "salario_anual": 17548.59, "num_pagas": 15},
      {"id": "nivel-12-2025", "nombre": "Nivel 12 — Especialista B (Oficial 2ª)",                 "grupo_profesional": "Nivel 12", "nivel": 12, "anio": 2025, "sb_mensual": 1013.26, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1106.49, "salario_anual": 17150.59, "num_pagas": 15},
      {"id": "nivel-13-2025", "nombre": "Nivel 13 — Especialista C (Oficial 3ª)",                 "grupo_profesional": "Nivel 13", "nivel": 13, "anio": 2025, "sb_mensual": 1009.26, "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1102.49, "salario_anual": 17088.59, "num_pagas": 15},
      {"id": "nivel-14-2025", "nombre": "Nivel 14 — Auxiliar Administrativo/a, Auxiliar A",        "grupo_profesional": "Nivel 14", "nivel": 14, "anio": 2025, "sb_mensual": 993.87,  "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1087.10, "salario_anual": 16850.00, "num_pagas": 15},
      {"id": "nivel-15-2025", "nombre": "Nivel 15 — Auxiliar B, Auxiliar de Caja",                 "grupo_profesional": "Nivel 15", "nivel": 15, "anio": 2025, "sb_mensual": 982.65,  "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1075.88, "salario_anual": 16676.00, "num_pagas": 15},
      {"id": "nivel-16-2025", "nombre": "Nivel 16 — Ayudante Dependiente/a, Auxiliar C",           "grupo_profesional": "Nivel 16", "nivel": 16, "anio": 2025, "sb_mensual": 976.19,  "plus_comp_mensual": 63.23, "plus_conv_mensual": 30.00, "salario_base_mensual": 1069.42, "salario_anual": 16576.00, "num_pagas": 15},
    ];

    // ── Tablas 2026 (BOP 18/02/2026, +2% sobre 2025) ───────────────────────
    final List<Map<String, dynamic>> categorias2026 = [
      {"id": "nivel-1-2026",  "nombre": "Nivel 1 — Director/a Área Ventas/Almacén",               "grupo_profesional": "Nivel 1",  "nivel": 1,  "anio": 2026, "sb_mensual": 1236.41, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1330.90, "salario_anual": 20629.07, "num_pagas": 15},
      {"id": "nivel-2-2026",  "nombre": "Nivel 2 — Titulado/a Univ. Grado Superior, Subdirector/a","grupo_profesional": "Nivel 2",  "nivel": 2,  "anio": 2026, "sb_mensual": 1204.89, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1299.38, "salario_anual": 20140.39, "num_pagas": 15},
      {"id": "nivel-3-2026",  "nombre": "Nivel 3 — Jefe/a de Área, Supervisor/a",                 "grupo_profesional": "Nivel 3",  "nivel": 3,  "anio": 2026, "sb_mensual": 1186.01, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1280.50, "salario_anual": 19847.74, "num_pagas": 15},
      {"id": "nivel-4-2026",  "nombre": "Nivel 4 — Jefe/a de Departamento",                       "grupo_profesional": "Nivel 4",  "nivel": 4,  "anio": 2026, "sb_mensual": 1173.44, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1267.93, "salario_anual": 19652.96, "num_pagas": 15},
      {"id": "nivel-5-2026",  "nombre": "Nivel 5 — Dependiente/a Mayor, Titulado/a Medio",        "grupo_profesional": "Nivel 5",  "nivel": 5,  "anio": 2026, "sb_mensual": 1155.41, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1249.90, "salario_anual": 19373.44, "num_pagas": 15},
      {"id": "nivel-6-2026",  "nombre": "Nivel 6 — Jefe/a Administrativo/a, Jefe/a Establecimiento","grupo_profesional": "Nivel 6","nivel": 6,  "anio": 2026, "sb_mensual": 1133.62, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1228.11, "salario_anual": 19035.74, "num_pagas": 15},
      {"id": "nivel-7-2026",  "nombre": "Nivel 7 — Encargado/a Logística, Secretario/a",          "grupo_profesional": "Nivel 7",  "nivel": 7,  "anio": 2026, "sb_mensual": 1122.77, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1217.26, "salario_anual": 18867.52, "num_pagas": 15},
      {"id": "nivel-8-2026",  "nombre": "Nivel 8 — Jefe/a Sección Adm./Comercial/Logística",      "grupo_profesional": "Nivel 8",  "nivel": 8,  "anio": 2026, "sb_mensual": 1104.86, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1199.35, "salario_anual": 18590.06, "num_pagas": 15},
      {"id": "nivel-9-2026",  "nombre": "Nivel 9 — Técnico/a Servicio Auxiliar/Adm./Logística",   "grupo_profesional": "Nivel 9",  "nivel": 9,  "anio": 2026, "sb_mensual": 1092.89, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1187.38, "salario_anual": 18404.45, "num_pagas": 15},
      {"id": "nivel-10-2026", "nombre": "Nivel 10 — Cajero/a, Oficial Adm., Dependiente/a Base",  "grupo_profesional": "Nivel 10", "nivel": 10, "anio": 2026, "sb_mensual": 1081.57, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1176.06, "salario_anual": 18228.96, "num_pagas": 15},
      {"id": "nivel-11-2026", "nombre": "Nivel 11 — Viajante, Especialista A",                    "grupo_profesional": "Nivel 11", "nivel": 11, "anio": 2026, "sb_mensual": 1059.72, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1154.21, "salario_anual": 17890.31, "num_pagas": 15},
      {"id": "nivel-12-2026", "nombre": "Nivel 12 — Especialista B (Oficial 2ª)",                 "grupo_profesional": "Nivel 12", "nivel": 12, "anio": 2026, "sb_mensual": 1033.53, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1128.02, "salario_anual": 17484.31, "num_pagas": 15},
      {"id": "nivel-13-2026", "nombre": "Nivel 13 — Especialista C (Oficial 3ª)",                 "grupo_profesional": "Nivel 13", "nivel": 13, "anio": 2026, "sb_mensual": 1029.45, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1123.94, "salario_anual": 17421.07, "num_pagas": 15},
      {"id": "nivel-14-2026", "nombre": "Nivel 14 — Auxiliar Administrativo/a, Auxiliar A",        "grupo_profesional": "Nivel 14", "nivel": 14, "anio": 2026, "sb_mensual": 1013.75, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1108.24, "salario_anual": 17177.75, "num_pagas": 15},
      {"id": "nivel-15-2026", "nombre": "Nivel 15 — Auxiliar B, Auxiliar de Caja",                 "grupo_profesional": "Nivel 15", "nivel": 15, "anio": 2026, "sb_mensual": 1002.30, "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1096.79, "salario_anual": 17000.36, "num_pagas": 15},
      {"id": "nivel-16-2026", "nombre": "Nivel 16 — Ayudante Dependiente/a, Auxiliar C",           "grupo_profesional": "Nivel 16", "nivel": 16, "anio": 2026, "sb_mensual": 995.71,  "plus_comp_mensual": 64.49, "plus_conv_mensual": 30.00, "salario_base_mensual": 1090.20, "salario_anual": 16898.23, "num_pagas": 15},
    ];

    final Map<String, dynamic> convenioData = {
      "nombre": "Convenio Colectivo de Comercio en General — Cuenca",
      "codigo": "16000055011981",
      "ambito": "provincial",
      "sector": "comercio",
      "tipo_convenio": "sectorial_provincial",
      "provincia": "Cuenca",
      "anio_vigente_defecto": 2026,
      "vigencia": {"inicio": "2025-01-01", "fin": "2028-12-31", "estado_dato": "tablas_2025_2026_bop"},
      "fuente": {"documento": "BOP Cuenca 14/11/2025 + 24/11/2025 (2025) y BOP 18/02/2026 (2026)", "fecha_extraccion": "2026-04-12", "version": "v1"},
      "horas_anuales": 1800,
      "num_pagas_total": 15.5,
      "formula_anual": "(SB + PlusComp + PlusConv) × 15,5",
      "pagas_descripcion": "12 mensualidades + Navidad + Julio + Beneficios + ½ Promoción Cultural",
    };

    final List<Map<String, dynamic>> pluses = [
      {"id": "plus_compensatorio_2026", "nombre": "Plus Compensatorio (mensual)", "tipo": "fijo", "importe": 64.49, "base_calculo": "mes_15.5_pagas", "importe_2025": 63.23},
      {"id": "plus_convenio", "nombre": "Plus Convenio (mensual, no revalorizable)", "tipo": "fijo", "importe": 30.00, "base_calculo": "mes_15.5_pagas", "descripcion": "No revalorizable"},
      {"id": "horas_extra_laborables", "nombre": "Horas extras días laborables (+75%)", "tipo": "porcentaje", "importe": 175.0, "base_calculo": "hora_ordinaria"},
      {"id": "horas_extra_festivos", "nombre": "Horas extras domingos/festivos (+150%)", "tipo": "porcentaje", "importe": 250.0, "base_calculo": "hora_ordinaria"},
      {"id": "nocturnidad", "nombre": "Plus Nocturnidad (22h-6h)", "tipo": "porcentaje", "importe": 25.0, "base_calculo": "hora_ordinaria"},
      {"id": "plus_domingos_festivos", "nombre": "Plus domingos y festivos (+50%)", "tipo": "porcentaje", "importe": 50.0, "base_calculo": "hora_ordinaria"},
      {"id": "dieta_comida_2026", "nombre": "Dieta comida 2026", "tipo": "fijo", "importe": 12.17, "base_calculo": "dia_desplazamiento"},
      {"id": "dieta_cena_2026", "nombre": "Dieta cena 2026", "tipo": "fijo", "importe": 12.17, "base_calculo": "dia_desplazamiento"},
      {"id": "dieta_comida_2025", "nombre": "Dieta comida 2025", "tipo": "fijo", "importe": 11.93, "base_calculo": "dia_desplazamiento"},
      {"id": "dieta_cena_2025", "nombre": "Dieta cena 2025", "tipo": "fijo", "importe": 11.93, "base_calculo": "dia_desplazamiento"},
      {"id": "cap2_sin_hijos", "nombre": "Complemento ad personam 2 (sin hijos)", "tipo": "fijo", "importe": 49.93, "base_calculo": "mes", "descripcion": "Antiguo CPF, no revalorizable. Solo si aplica."},
      {"id": "cap2_1_hijo", "nombre": "Complemento ad personam 2 (1 hijo menor)", "tipo": "fijo", "importe": 56.15, "base_calculo": "mes"},
      {"id": "cap2_2_hijos", "nombre": "Complemento ad personam 2 (2 hijos menores)", "tipo": "fijo", "importe": 63.03, "base_calculo": "mes"},
      {"id": "cap2_3_hijos", "nombre": "Complemento ad personam 2 (3+ hijos menores)", "tipo": "fijo", "importe": 69.59, "base_calculo": "mes"},
      {"id": "seguro_accidentes", "nombre": "Seguro accidentes", "tipo": "fijo", "importe": 15000.0, "base_calculo": "anual", "descripcion": "Póliza anual obligatoria empresa"},
    ];

    final WriteBatch batch = _db.batch();
    final convenioDocRef = _conveniosRef.doc(convenioId);
    batch.set(convenioDocRef, convenioData);

    for (final catData in [...categorias2025, ...categorias2026]) {
      final catId = catData['id'] as String;
      batch.set(convenioDocRef.collection('categorias').doc(catId), catData);
    }
    for (final plusData in pluses) {
      final plusId = plusData['id'] as String;
      batch.set(convenioDocRef.collection('pluses').doc(plusId), plusData);
    }

    await batch.commit();
    _log.i('✅ Datos del convenio de Comercio en General (Cuenca 2025-2026) creados en Firestore.');
  }

  /// Siembra todos los convenios Fluixtech.
  /// Usa [force] para reescribir valores en caso de tablas nuevas.
  Future<void> seedConveniosFluixtech({bool force = false}) async {
    await seedConvenioHosteleriaGuadalajara(force: force);
    await seedConvenioComercioGuadalajara(force: force);
    await seedConvenioPeluqueriaEsteticaGimnasios(force: force);
    await seedConvenioCarniceriasGuadalajara2025(force: force);
    await seedConvenioVeterinariosGuadalajara2026(force: force);
    await seedConvenioConstruccionObrasPublicasGuadalajara(force: force);
    await seedConvenioConstruccionCuenca(force: force);
    await seedConvenioHosteleriaCuenca(force: force);
    await seedConvenioComercioCuenca(force: force);
  }

  Future<CategoriaConvenio?> obtenerCategoriaPorId(String convenioId, String categoriaId) async {
    final doc = await _conveniosRef.doc(convenioId).collection('categorias').doc(categoriaId).get();
    if (!doc.exists) return null;
    final data = doc.data()!..['id'] = doc.id;
    return CategoriaConvenio.fromMap(data);
  }
}






