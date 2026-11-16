# 07 — Modelos Fiscales AEAT

**Análisis**: Fluix CRM · planeag_flutter v1.0.18 · Firebase planeaapp-4bea4  
**Fecha**: 2026-10-26 · **Modo**: Solo lectura

---

## Estado actual

| Modelo | Formulario | Calculadora | Exportador | Observaciones |
|--------|-----------|-------------|------------|---------------|
| **111** | Completo — 5 secciones (trabajo, actividades, premios, forestales, imagen) | `modelo111_service.dart` + CF `model111.ts` — nutre de nóminas (`tx.type='payroll'`) y facturas recibidas con tag `SERVICIOS_PROFESIONALES` | `modelo111_aeat_exporter.dart` — formato posicional DR111e16v18, 2 registros de 500 chars, ISO-8859-1. Validación de longitud en runtime. | CF solo calcula 2 secciones (trabajo + actividades); el modelo Dart tiene 5. Sin presentaciones sustitutivas. |
| **115** | Completo — 5 casillas + detalle por arrendador | `mod115_calculator.dart` — lee `facturas_recibidas` con flag `es_arrendamiento`. Tasa 19% fija. | `mod115_exporter.dart` — formato DR115e15v13 | Presenta complementaria (c04). No hay flujo para tipo "G" (ingreso CCT). |
| **130** | Completo — 19 casillas YTD, acumulativo | `mod130_calculator.dart` — lee facturas emitidas (c01) y recibidas (c02) YTD; c05 automático de trimestres anteriores; c16 tope 660,14 € validado. | `mod130_exporter.dart` | El Mod130Screen comprueba `EmpresaConfig.formaJuridica.tributaIRPF` para mostrar aviso, **pero no bloquea** la pantalla a sociedades. El calendario fiscal genera vencimiento 202 con fecha 20 de abril/octubre/diciembre, **pero la 2P (oct) del 202 cae el 20 oct — correcto**; la 3P cae el 20 dic — correcto. El Mod130 4T vence el 30 ene — correcto. |
| **180** | Completo — par anual del 115 | `mod180_calculator.dart` — consolida los 4 trimestres de modelos115 + arrendatarios individuales | Fichero `.txt` compartido vía Share | Sin exportador AEAT posicional dedicado. Solo compartir fichero de texto plano. |
| **190** | Completo — tipo 1 (totales) + tipo 2 (perceptores), clave A full, IT, especie, familia, discapacidad | `modelo190_service.dart` — lee `modelos111` del ejercicio y los empleados | No encontrado exportador posicional en `exportadores_aeat/`. La pantalla hace un `Share` de texto. | **Falta exportador posicional AEAT (DR190e25v13)**. El mod190 Dart tiene estructura completa (perceptores) pero no se serializa a formato posicional. |
| **202** | Completo — modalidad A (18% cuota IS ejerc. anterior). Campos c01–c08 | `mod202_calculator.dart` — busca `200_{ejercicio-1}_anual` en `modelos_fiscales`. Si no existe ese doc, **base IS = 0**. | `mod202_exporter.dart` | Sin comprobación de Mod.200 previo. Sin modalidad B (art. 40.3 LIS, grandes empresas). La pantalla muestra la guarda sin explicar que necesita el Mod.200 del año anterior. |
| **303** | Completo — 3 tipos IVA, criterio caja, estado por trimestre, plazo visual | `mod_303_service.dart` — lee `facturas` / `facturas_recibidas`; criterio devengo/caja; filtra intracomunitarias | `dr303e26v101_exporter.dart` — formato posicional DR303e26v101 completo (p0, p1, p3, DID) | **BUG de casillas**: en `_construirCasillas`, casilla `[01]` mapea a `base_reducida` (10%) y casilla `[04]` a `base_general` (21%). En el modelo oficial AEAT v101: casilla 01=4%, 04=10%, 07=21%. La pantalla muestra "[01]" para base 21% y "[04]" para 10%, pero el servicio mapea al revés vs. el oficial. Hay un doble problema: la UI mostraba [01]=21% pero el exportador pone en casilla `[04]` la base general. |
| **347** | Completo — umbral 3.005,06 €, claves A/B/C, desglose trimestral | `mod_347_service.dart` — cruza facturas emitidas (clave B) + recibidas (clave A) | `mod_347_exporter.dart` — posicional 500 chars, ISO-8859-1. Incluye NIF comunitario. | Plazos del calendario apuntan a fecha de febrero del año siguiente (correcto). Sin soporte de ref. catastral para inmuebles. |
| **349** | Básico — lista de facturas marcadas como intracomunitarias | Sin calculadora propia — `modelo349_screen.dart` filtra facturas por año directamente. No agrega por NIF tercero. | `mod_349_exporter.dart` | **Sin agregación por NIF**: el Mod.349 oficial requiere un registro por proveedor/cliente con base total anual. La pantalla lista facturas individuales. Falta conversión a registros resumen. Sin clave de operación (E/A/T/S). |
| **390** | Completo — 6 páginas (sujeto pasivo, devengado, 2B, deducible, bienes inv., liquidación) | `mod390_calculator.dart` — consolida 4 Mod.303 recalculando desde facturas (no leyendo los 303 ya guardados); verifica coherencia cuota devengada | `mod390_posicional_service.dart` + `Mod390Builder` — formato posicional 2025 v1.02, ISO-8859-1 | **Inconsistencia de ruta**: `Mod390PosicionalService` busca los 303 en colección `modelos303` (línea 71), pero `Mod303Service` los guarda en `modelos_fiscales` con doc id `303_{año}_{trimestre}T`. La verificación de trimestres siempre sale en alerta aunque existan los 303. |

---

## Riesgos

| Nivel | Descripción | Fichero:Línea |
|-------|-------------|---------------|
| **CRITICO** | Casillas 303 intercambiadas: `[01]` mapea `base_reducida` (10%) y `[04]` mapea `base_general` (21%), cuando el oficial AEAT tiene 01=4%, 04=10%, 07=21%. Cualquier fichero exportado declara tipos incorrectos. | `lib/services/mod_303_service.dart:323-328` |
| **CRITICO** | `Mod390PosicionalService` verifica trimestres en colección `modelos303` que no existe; los 303 están en `modelos_fiscales`. La alerta "sin Mod.303" aparece siempre. | `lib/services/fiscal/mod390_posicional_service.dart:71` |
| **ALTO** | Mod.190 carece de exportador posicional AEAT. Solo genera texto plano. La AEAT exige formato DR190e25v13 para presentación telemática de más de 10 perceptores. | `lib/features/fiscal/pantallas/modelo190_screen.dart` |
| **ALTO** | Mod.349 no agrega por NIF tercero. El formato oficial requiere un registro resumen por empresa; actualmente se listan facturas individuales. | `lib/features/fiscal/pantallas/modelo349_screen.dart:46-67` |
| **ALTO** | Mod.202 calcula base IS = 0 si no existe doc `200_{ejercicio-1}_anual` en Firestore. No hay Mod.200 (IS anual) implementado, por lo que la base siempre será 0 en el primer uso. | `lib/services/fiscal/mod202_calculator.dart:19-30` |
| **MEDIO** | Calendario fiscal genera vencimientos del 202 como trimestrales (20 abr/jul/oct/ene), pero el 202 tiene 3 períodos (1P abril, 2P octubre, 3P diciembre); aparece en el calendario el 20 jul — incorrecto para el 202. | `lib/features/fiscal/pantallas/calendario_fiscal_screen.dart:95-135` |
| **MEDIO** | Historial de presentaciones lee de `modelos_fiscales` y extrae el período del doc id (patrón `303_2026_Q1`), pero `Mod303Service` guarda con formato `303_2026_1T`. El parser espera `Q1..Q4`, encontrará `1T..4T` y el campo periodo quedará vacío. | `lib/features/fiscal/pantallas/historial_presentaciones_screen.dart:116-127` |
| **MEDIO** | `generarMod303Dr303e26v101` pasa `nombreRazonSocial: nifEmpresa` (usa el NIF como nombre de empresa) en lugar del nombre real. | `lib/services/mod_303_service.dart:233` |
| **MEDIO** | Mod.130 no bloquea a sociedades (S.L., S.A.): `EmpresaConfig.tributaIRPF` existe pero no se usa para deshabilitar el formulario. Una S.L. podría calcular un modelo que no le corresponde. | `lib/features/fiscal/pantallas/modelo130_screen.dart` |
| **BAJO** | `Mod390Calculator` recalcula los 303 desde facturas en el momento del cálculo del 390; no lee los 303 ya presentados y guardados. Cualquier factura añadida después altera retroactivamente el resumen anual. | `lib/services/fiscal/mod390_calculator.dart:40-46` |
| **BAJO** | CF `model111.ts` solo tiene secciones I (trabajo) y II (actividades), pero el Dart `Modelo111` tiene 5 secciones. Premio/forestales/imagen nunca se calculan desde la CF. | `functions/src/fiscal/models/model111.ts` |
| **BAJO** | CF `model303.ts` aplica siempre 21% en inversión sujeta pasiva (`reverse_charge_domestic`), sin leer la tasa real de la transacción. | `functions/src/fiscal/models/model303.ts:103` |
| **BAJO** | Libros registro solo generan emitidas/recibidas. No generan libro de bienes de inversión ni operaciones intracomunitarias (art. 62-64 RIVA). | `lib/features/fiscal/pantallas/pantalla_libros_registro.dart` |

---

## Diferencias por plataforma

| Funcionalidad | iOS | Android | Windows |
|---------------|-----|---------|---------|
| Exportar fichero .txt (303, 390, 111, 115, 130) | `Share.shareXFiles` — abre panel compartir; requiere app compatible (Ficheros, AirDrop) | `Share.shareXFiles` — funciona con explorador de archivos, correo, Drive | `Share.shareXFiles` en Windows desktop puede no abrir panel nativo; el fichero se guarda en `getTemporaryDirectory()` que en Windows apunta a `%TEMP%`, y el usuario puede perderlo si no actúa rápido. Necesita botón "Guardar en disco" o `FilePicker.saveFile`. |
| `getTemporaryDirectory()` | `/tmp` app sandbox | `/data/data/…/cache` | `C:\Users\…\AppData\Local\Temp` — archivos efímeros, riesgo de pérdida |
| Presentación AEAT (web) | `url_launcher` abre Safari | `url_launcher` abre Chrome | `url_launcher` abre navegador de escritorio — funciona correctamente |
| Libros registro (filtro fechas Firestore) | OK | OK | OK — no hay diferencia de comportamiento |
| Exportación PDF (Cloud Function) | OK si conectado a internet | OK | OK |

---

## Cumplimiento legal (normativa AEAT vigente 2025)

| Modelo | Norma de referencia | Estado de cumplimiento |
|--------|--------------------|-----------------------|
| 111 | Orden HAC/1422/2002 + actualizaciones | Parcial — secciones III–V no calculadas desde CF |
| 115 | Art. 101.6 LIRPF | Cumple en la parte material; falta exportador posicional DR115 validado |
| 130 | Art. 110 LIRPF | Cumple fórmula YTD; tope c16=660,14 € validado |
| 180 | Orden HAC/3514/2004 | Parcial — sin exportador posicional DR180 |
| 190 | Orden HAC/1431/2025 (BOE 12/12/2025) | Incumple — sin exportador posicional DR190e25v13; no presentable telemáticamente para >10 empleados |
| 202 | Art. 40 LIS | Parcial — base siempre 0 en ausencia de Mod.200 previo |
| 303 | DR303e26v101 | Incumple — casillas 01/04/07 asignadas de forma incorrecta en el constructor de casillas |
| 347 | Art. 33 RD 1065/2007 | Cumple en lo esencial; sin ref. catastral en arrendamientos de inmuebles |
| 349 | Art. 79 RIVA | Incumple — falta agregación por NIF y clave de operación obligatoria |
| 390 | DR390 ejercicio 2025 v1.02 | Parcial — builder correcto pero `PosicionalService` tiene ruta Firestore errónea |

---

## Deuda técnica

1. **Inconsistencia de colecciones Firestore para Mod.303**: `modelos_fiscales` vs `modelos303` en dos servicios distintos. Requiere unificar o crear colección derivada.
2. **Falta Mod.190 posicional**: es la exportación de retenciones más voluminosa y compleja; su ausencia impide la presentación telemática de empresas con empleados.
3. **Falta Mod.349 agregado**: el modelo tiene datos pero la agregación por tercero es obligatoria.
4. **Doble exportador Mod.303**: existe `mod_303_exporter.dart` (legacy) y `dr303e26v101_exporter.dart` (nuevo). La pantalla llama al nuevo, pero el legado sigue presente. Eliminar el legado o marcarlo claramente.
5. **Cloud Functions de modelos fiscales no conectadas a la app**: `calculateModel.ts` en CF no tiene función HTTP expuesta. Los modelos se calculan en cliente Dart. La CF solo procesa facturas OCR. Esta división tiene sentido pero no está documentada.
6. **Falta Mod.200 (IS anual)**: el Mod.202 depende de él pero no existe pantalla ni calculadora.
7. **Sin tests de exportadores posicionales**: el README del 303 menciona `test/dr303e26v101_exporter_test.dart` pero no fue comprobada su existencia; los exportadores del 111, 115, 390 y 347 no tienen cobertura de test visible.

---

## Lista priorizada de acciones

| Prioridad | Acción | Esfuerzo |
|-----------|--------|----------|
| 1 | Corregir casillas Mod.303 en `_construirCasillas`: 01=4%, 04=10%, 07=21% (y añadir casilla 07 que falta del super-reducido vs reducido) | S |
| 2 | Corregir ruta Firestore en `Mod390PosicionalService`: cambiar `modelos303` por `modelos_fiscales` y el filtro `where('anio')` por `where('ejercicio')` y `where('trimestre')` por el formato `1T..4T` | S |
| 3 | Corregir nombre empresa en `generarMod303Dr303e26v101`: pasar `nombreRazonSocial` real, no el NIF | S |
| 4 | Corregir parser de período en `historial_presentaciones_screen`: cambiar `Q1..Q4` por `1T..4T` | S |
| 5 | Bloquear Mod.130 y Mod.202 por forma jurídica: mostrar error/ocultarlo si `!tributaIRPF` o `!esSociedad` respectivamente | S |
| 6 | Corregir vencimientos del Mod.202 en calendario: 1P=20 abr, 2P=20 oct, 3P=20 dic | S |
| 7 | Implementar exportador posicional Mod.190 (DR190e25v13): registro tipo 1 (cabecera) + tipo 2 por perceptor | L |
| 8 | Implementar agregación por NIF en Mod.349 y exportador posicional DR349 con claves E/A/T/S | M |
| 9 | Crear pantalla básica Mod.200 (IS anual) para alimentar la base del Mod.202 | M |
| 10 | Añadir botón "Guardar en disco" en exportadores de ficheros para Windows (usar `FilePicker.saveFile`) | S |
| 11 | Implementar exportador posicional Mod.180 (DR180) | M |
| 12 | Completar CF `model111.ts` con secciones III–V (premios, forestales, derechos imagen) | M |
| 13 | Añadir libro de bienes de inversión y libro intracomunitarias en `PantallaLibrosRegistro` | M |
| 14 | Revisar y unificar colecciones Firestore: definir si los 303 van en `modelos_fiscales` o `modelos303` y actualizar todos los servicios | S |
| 15 | Escribir tests unitarios para todos los exportadores posicionales (especialmente el 303 y el 390) | M |
