# 📋 VALORACIÓN — Módulo SEPA XML (Pago masivo nóminas)

## Archivos creados (5)

| Archivo | Descripción |
|---|---|
| `lib/domain/modelos/remesa_sepa.dart` | Modelo de datos: `RemesaSepa`, `EstadoRemesa` (generada/enviada/confirmada/rechazada), serialización Firestore |
| `lib/services/sepa_xml_generator.dart` | Generador XML pain.001.001.03: `generarXML()`, `validarLote()`, `validarIBAN()`, festivos nacionales, escape XML |
| `lib/services/remesa_sepa_service.dart` | Servicio CRUD Firestore + orquestación: crear remesa, obtener datos empleados, IBAN empresa, compartir XML |
| `lib/features/nominas/pantallas/remesa_sepa_screen.dart` | Pantalla listado de remesas con estados, acciones (compartir XML, marcar enviada/confirmada) |
| `lib/features/nominas/pantallas/nueva_remesa_form.dart` | Formulario: selector mes/año, fecha ejecución, lista nóminas con estado IBAN, validaciones, generación XML |
| `test/sepa_xml_test.dart` | 30+ tests: IBAN, lote, XML generado, edge cases, festivos, modelo datos |

## Archivos modificados (2)

| Archivo | Cambio |
|---|---|
| `lib/domain/modelos/empresa_config.dart` | Añadidos `ibanEmpresa`, `bicEmpresa` a EmpresaConfig (campos, constructor, fromSources, toEmpresaDoc, copyWith) |
| `lib/features/nominas/pantallas/modulo_nominas_screen.dart` | Botones "Remesa SEPA" y "Historial remesas" en barra de acciones (junto a CSV y PDFs), solo propietarios |

## Esquema XML implementado — pain.001.001.03

| Bloque | Elemento | Implementado |
|---|---|---|
| GrpHdr | MsgId (NIF+timestamp, max 35) | ✅ |
| GrpHdr | CreDtTm (ISO 8601) | ✅ |
| GrpHdr | NbOfTxs | ✅ |
| GrpHdr | CtrlSum (2 decimales) | ✅ |
| GrpHdr | InitgPty (Nm + OrgId/Othr/Id) | ✅ |
| PmtInf | PmtInfId (NIF+YYYYMM+NOMINAS) | ✅ |
| PmtInf | PmtMtd = TRF | ✅ |
| PmtInf | BtchBookg = true | ✅ |
| PmtInf | InstrPrty = NORM | ✅ |
| PmtInf | SvcLvl/Cd = SEPA | ✅ |
| PmtInf | CtgyPurp/Cd = SALA | ✅ |
| PmtInf | ReqdExctnDt (YYYY-MM-DD) | ✅ |
| PmtInf | Dbtr (Nm, PstlAdr, Id/OrgId) | ✅ |
| PmtInf | DbtrAcct/IBAN | ✅ |
| PmtInf | DbtrAgt/BIC | ✅ |
| PmtInf | ChrgBr = SLEV | ✅ |
| CdtTrfTxInf | InstrId (NIF_emp+MES+NIF_empl) | ✅ |
| CdtTrfTxInf | EndToEndId (NOMINA-YYYY-MM-NIF) | ✅ |
| CdtTrfTxInf | InstdAmt Ccy="EUR" | ✅ |
| CdtTrfTxInf | CdtrAgt/BIC | ✅ |
| CdtTrfTxInf | Cdtr/Nm (max 70) | ✅ |
| CdtTrfTxInf | CdtrAcct/IBAN | ✅ |
| CdtTrfTxInf | RmtInf/Ustrd (max 140) | ✅ |

## Validaciones implementadas

| # | Validación | Implementado |
|---|---|---|
| 1 | Nóminas en estado "aprobada" | ✅ |
| 2 | IBAN empleado presente y válido (mod-97) | ✅ |
| 3 | IBAN empresa presente y válido | ✅ |
| 4 | Fecha ejecución en día hábil | ✅ |
| 5 | Importes netos > 0 | ✅ |
| 6 | Sin duplicados (empleado+mes) | ✅ |
| 7 | Festivos nacionales España (fijos + Semana Santa) | ✅ |
| 8 | Escape entidades XML (&amp; &lt; &gt; &quot; &apos;) | ✅ |
| 9 | Truncado campos max (35, 70, 140 chars) | ✅ |
| 10 | Eliminación acentos en concepto | ✅ |

## Algoritmo IBAN (ISO 7064)

```
1. Limpiar espacios, mayúsculas
2. Verificar 24 chars, prefijo "ES", formato ES + 22 dígitos
3. Reorganizar: BBAN + "ES" + dígitos control
4. Convertir letras a números (A=10...Z=35)
5. BigInt módulo 97 == 1 → válido
```

## Modelo Firestore

```
empresas/{empresaId}/remesas_sepa/{remesaId}
  ├── id, empresa_id, mes, anio
  ├── fecha_ejecucion (Timestamp)
  ├── nominas_ids [string]
  ├── n_transferencias (int)
  ├── importe_total (double)
  ├── estado: generada | enviada | confirmada | rechazada
  ├── msg_id (string)
  ├── xml_generado (string, opcional)
  ├── fecha_creacion, fecha_envio (Timestamp)

empresas/{empresaId}
  ├── iban_empresa (string)
  └── bic_empresa (string, opcional)
```

## UI implementada

1. **Pantalla RemesaSepaScreen**: listado remesas con estado, importe, período, acciones
2. **NuevaRemesaForm**: selector mes, fecha ejecución (datepicker sin fines de semana), lista nóminas con estado IBAN (✅/⚠️), validaciones con errores detallados, resumen importe, botón generar + compartir
3. **IBAN empresa**: editable inline desde el formulario con validación mod-97 en tiempo real
4. **Integración modulo_nominas_screen**: botones 🏦 Remesa SEPA + 📋 Historial (solo propietarios)

## Tests implementados (30+)

- **IBAN válido**: ES9121000418450200051332, con espacios, minúsculas
- **IBAN inválido**: nulo, vacío, corto, no español, dígitos control erróneos, letras
- **Formateo/limpieza**: limpiarIBAN, formatearIBAN
- **Lote válido**: 3 empleados sin errores
- **Sin IBAN**: error específico por empleado
- **IBAN inválido**: error específico
- **Nómina borrador**: rechazada
- **Fecha fin de semana**: error + sugerirDiaHabil
- **XML structure**: namespace, CstmrCdtTrfInitn, NbOfTxs, CtrlSum, MsgId
- **XML contenido**: TRF, SALA, SEPA, SLEV, BtchBookg, ReqdExctnDt
- **XML ordenante**: IBAN, BIC, NIF, razón social, país ES
- **XML transferencias**: 3 CdtTrfTxInf, EndToEndId únicos, InstdAmt EUR, importes
- **Caso bar 3 empleados**: NbOfTxs=3, CtrlSum=total, SALA
- **Modelo RemesaSepa**: fromMap/toMap, periodoTexto, copyWith
- **Festivos**: 1 enero, sugerirDiaHabil salta Navidad
- **Escape XML**: &amp; &lt; &gt; &quot; &apos;
- **MsgId truncado**: max 35 chars
- **1 nómina**: genera XML válido con NbOfTxs=1

