# 📋 VALORACIÓN — Módulo Modelo 111 (Retenciones IRPF empleados)

## Archivos creados (6)

| Archivo | Descripción |
|---|---|
| `lib/domain/modelos/modelo111.dart` | Modelo de datos: `Modelo111`, `TipoDeclaracion111`, `EstadoModelo111` con serialización Firestore |
| `lib/services/modelo111_service.dart` | Servicio: agrega nóminas pagadas por trimestre → genera Modelo111; CRUD Firestore |
| `lib/services/exportadores_aeat/modelo111_aeat_exporter.dart` | Exportador fichero .txt formato posicional DR111e16v18 (ISO-8859-1, 2 registros × 500 chars) |
| `lib/services/modelo111_pdf_service.dart` | Generador PDF: 3 ejemplares idénticos al formulario BOE (sujeto pasivo / entidad / administración) |
| `lib/features/fiscal/pantallas/modelo111_screen.dart` | Pantalla: listado trimestres T1-T4 con estado, datos, acciones PDF/AEAT/presentado |
| `test/modelo111_test.dart` | 25+ tests: 4 casos funcionales + formato AEAT + modelo de datos + edge cases |

## Archivo modificado (1)

| Archivo | Cambio |
|---|---|
| `lib/features/facturacion/pantallas/tab_modelos_fiscales.dart` | Tab "Modelo 111 Retenc. IRPF" integrado en el selector 303/130/111 |

## Base legal implementada

| Concepto | Artículo | Implementado |
|---|---|---|
| Obligación retenciones IRPF | Art. 101 LIRPF + Art. 108 RIRPF | ✅ |
| Periodicidad trimestral PYMEs | Art. 108.1 RIRPF | ✅ (1T–4T) |
| Plazos presentación | Orden EHA/3127/2009 | ✅ (20/abr, 20/jul, 20/oct, 20/ene) |
| Declaración negativa | Art. 108.4 RIRPF | ✅ (tipo "N") |
| Declaración complementaria | Art. 122 LGT | ✅ (c29 deduce anterior) |
| Casillas 01-30 formulario BOE | Modelo 111 oficial | ✅ todas |
| Secciones I-V (trabajo/RAE/premios/forestales/imagen) | — | ✅ (II-V = 0 PYMEs) |
| Retribuciones en especie + ingresos a cuenta | Art. 102 LIRPF | ✅ |
| Formato fichero AEAT DR111e16v18 | Diseño registro AEAT | ✅ posicional 500 chars |

## Casillas implementadas

```
Sección I — Rendimientos del trabajo:
  [01] Nº perceptores dinerarios    ← empleados únicos con salario > 0
  [02] Importe percepciones          ← totalDevengosCash de nóminas pagadas
  [03] Retenciones dinerarias        ← retencionIrpf proporcional a dinerario
  [04] Nº perceptores especie        ← empleados con retribucionesEspecie > 0
  [05] Valor retrib. especie         ← suma retribucionesEspecie trimestre
  [06] Ingresos a cuenta especie     ← IRPF × (especie/totalDevengos)

Secciones II-V: a 0 para PYMEs estándar (bares, peluquerías, carnicerías)

[28] Total retenciones = 03+06+09+12+15+18+21+24+27
[29] A deducir complementaria
[30] Resultado a ingresar = max(28-29, 0)
```

## Formato fichero AEAT (DR111e16v18)

- Codificación: ISO-8859-1
- 2 registros × 500 chars + CRLF
- Registro 1 (tipo "11"): cabecera declarante (NIF, razón social, tipo, c28)
- Registro 2 (tipo "21"): datos liquidación (c01-c30 en céntimos)
- Importes en céntimos sin decimales, rellenos con ceros a la izquierda
- Textos sin acentos, mayúsculas, rellenos con espacios a la derecha

## PDF oficial (3 ejemplares)

Secciones del formulario BOE reproducidas:
1. Cabecera (Agencia Tributaria + recuadro "111")
2. Declarante + Devengo (NIF, razón social, ejercicio, período)
3. Liquidación (tabla I-V con casillas 01-27 + totales 28-30)
4. Ingreso (importe casilla 30)
5. Negativa (checkbox)
6. Complementaria (checkbox + nº justificante)
7. Firma (lugar, fecha, firma)
8. Pie legal + ejemplar

## Tests implementados

- **Caso 1**: Bar con 3 empleados T1 2026 (c01=3, c02=13500, c03=1674, c30=1674)
- **Caso 2**: Retribución en especie 100€/mes → c04=1, c05=300, c06=56.25
- **Caso 3**: Declaración negativa (sin nóminas → tipo N, c28=0)
- **Caso 4**: Complementaria (c28=700, c29=500, c30=200)
- **Fichero AEAT**: longitud registros, posiciones, céntimos, NIF, tipo, normalización acentos
- **Modelo datos**: serialización ida/vuelta, c28 suma, c30 nunca negativo, plazos, rangos
- **Edge cases**: copyWith, 0€ retención sigue siendo perceptor, 1 empleado 3 meses = 1 perceptor

