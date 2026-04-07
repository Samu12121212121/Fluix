# 📊 Cómo se calcula la nómina en PlaneaG

> Basado en `lib/services/nominas_service.dart` y `lib/domain/modelos/nomina.dart`  
> Normativa aplicada: **España 2026** — Última actualización: 15/03/2026

---

## 🗂️ Índice

1. [Datos de entrada](#1-datos-de-entrada)
2. [Paso 1 — Salario base mensual (con parcialidad)](#2-paso-1--salario-base-mensual-con-parcialidad)
3. [Paso 2 — Total devengos (bruto del mes)](#3-paso-2--total-devengos-bruto-del-mes)
4. [Paso 3 — Base de cotización a la SS](#4-paso-3--base-de-cotización-a-la-ss)
5. [Paso 4 — Cuotas SS del trabajador (con MEI)](#5-paso-4--cuotas-ss-del-trabajador-con-mei)
6. [Paso 5 — Retención IRPF (con reducción rendimientos)](#6-paso-5--retención-irpf-con-reducción-rendimientos)
7. [Paso 6 — Salario neto](#7-paso-6--salario-neto)
8. [Paso 7 — Coste empresa (SS empresa + MEI)](#8-paso-7--coste-empresa-ss-empresa--mei)
9. [Resumen de tipos y topes 2026](#9-resumen-de-tipos-y-topes-2026)
10. [Flujo YTD — Regularización anual del IRPF](#10-flujo-ytd--regularización-anual-del-irpf)
11. [Horas extra — UI y cálculo](#11-horas-extra--ui-y-cálculo)
12. [✅ Qué está bien calculado](#12--qué-está-bien-calculado)
13. [⚠️ Limitaciones que quedan](#13-️-limitaciones-que-quedan)

---

## 1. Datos de entrada

Antes de calcular, el sistema necesita los datos del empleado (`DatosNominaEmpleado`):

| Campo | Descripción | Impacto |
|---|---|---|
| `salarioBrutoAnual` | Salario bruto pactado en contrato | Base de todo el cálculo |
| `numPagas` | 12 ó 14 pagas | Cuánto cobra cada mes |
| `pagasProrrateadas` | Si las extras van diluidas en los 12 meses | Cambia el salario base mensual |
| `tipoContrato` | Indefinido / Temporal / Prácticas / Parcial | Cambia tipo de desempleo SS |
| `horasSemanales` | Horas trabajadas por semana (40 = jornada completa) | Coeficiente de parcialidad |
| `complementoFijo` | Plus convenio, antigüedad… (€/mes) | Se suma al bruto mensual |
| `estadoCivil` | Soltero / Casado / Viudo / Divorciado | Afecta al mínimo IRPF |
| `numHijos` | Hijos a cargo | Aumenta mínimo familiar IRPF |
| `numHijosMenores3` | Hijos < 3 años | +2.800 € por hijo al mínimo |
| `discapacidad` | Tiene discapacidad reconocida | +3.000 / +9.000 € al mínimo |
| `otrasRentas` | Arrendamientos, inversiones… | Sube la base anual estimada del IRPF |
| `irpfPersonalizado` | % fijo si Hacienda lo ha comunicado | Omite el cálculo automático |
| `baseAcumuladaYtd` | Bruto acumulado en el año hasta el mes anterior | Para regularización YTD |
| `irpfAcumuladoYtd` | IRPF retenido acumulado en el año | Para regularización YTD |

---

## 2. Paso 1 — Salario base mensual (con parcialidad)

### Coeficiente de parcialidad

```
coeficienteParcial = horasSemanales / 40     (clamped entre 0.0 y 1.0)
brutoAnualAjustado = salarioBrutoAnual × coeficienteParcial
```

> Si el empleado trabaja 20h/semana → coeficiente = 0.5 → el bruto anual se reduce a la mitad.
> Si trabaja 40h (jornada completa) → coeficiente = 1.0 → sin cambio.

### Cálculo del salario base mensual

```
Si 12 pagas (o 14 prorrateadas):
    salarioBase = brutoAnualAjustado / 12

Si 14 pagas NO prorrateadas:
    salarioBase = brutoAnualAjustado / 14
    pagaExtra   = brutoAnualAjustado / 14   (solo en junio y diciembre)
    otros meses → pagaExtra = 0
```

### Ejemplo con 30.000 €/año a jornada completa

| Modalidad | Mensual normal | Junio / Diciembre |
|---|---|---|
| 12 pagas | 2.500,00 € | 2.500,00 € |
| 14 pagas prorrateadas | 2.500,00 € | 2.500,00 € |
| 14 pagas no prorrateadas | 2.142,86 € | **4.285,71 €** (salario + paga extra) |

### Ejemplo con 30.000 €/año a media jornada (20h/semana)

| Modalidad | Mensual normal | Junio / Diciembre |
|---|---|---|
| 12 pagas | 1.250,00 € | 1.250,00 € |

---

## 3. Paso 2 — Total devengos (bruto del mes)

```
totalDevengos = salarioBase
              + pagaExtra             (si aplica, en junio/diciembre)
              + importeHorasExtra     (horas × precio/hora)
              + complementoFijo       (del contrato)
              + complementosVariables (pasados al calcular)
```

### Cálculo horas extra

```
Si se pasa precioHoraExtra > 0 (y importeHorasExtra no se pasa):
    importeHorasExtra = horasExtra × precioHoraExtra

Si se pasa importeHorasExtra directamente:
    se usa ese valor tal cual
```

> **UI**: Desde la pantalla de detalle de una nómina en borrador, el propietario puede añadir horas extra (nº de horas + €/hora) y pulsar "Recalcular nómina".

---

## 4. Paso 3 — Base de cotización a la SS

La base de cotización **no puede ser inferior al tope mínimo ni superior al tope máximo** mensual:

```
baseCotizacion = totalDevengos.clamp(1.260,00 €, 4.720,50 €)
```

| Tope | Valor 2026 | Fuente |
|---|---|---|
| Base mínima mensual | **1.260,00 €** | SMI 2026 mensualizado |
| Base máxima mensual | **4.720,50 €** | Tope máximo TGSS 2026 |

---

## 5. Paso 4 — Cuotas SS del trabajador (con MEI)

Sobre la `baseCotizacion` calculada en el paso anterior:

```
SS Contingencias Comunes     = baseCot × 4,70 %
SS Desempleo (indefinido)    = baseCot × 1,55 %
SS Desempleo (temporal/pract)= baseCot × 1,60 %
SS Formación Profesional     = baseCot × 0,10 %
SS MEI (Equidad Intergener.) = baseCot × 0,12 %

totalSSTrabajador = CC + Desempleo + FP + MEI
```

| Concepto | Tipo indefinido | Tipo temporal / prácticas |
|---|---|---|
| Contingencias Comunes | 4,70 % | 4,70 % |
| Desempleo | **1,55 %** | **1,60 %** |
| Formación Profesional | 0,10 % | 0,10 % |
| **MEI** | **0,12 %** | **0,12 %** |
| **TOTAL trabajador** | **6,47 %** | **6,52 %** |

---

## 6. Paso 5 — Retención IRPF (con reducción rendimientos)

### Reducción por rendimientos del trabajo (Art. 19/20 LIRPF)

Antes de aplicar los tramos, se restan de la base imponible:

```
Gastos deducibles fijos  = 2.000 €  (todo contribuyente)

Reducción escalonada:
  Si renta ≤ 14.852 €       → reducción = 7.302 €
  Si 14.852 < renta ≤ 19.747 € → reducción = 7.302 − 1,75 × (renta − 14.852)
  Si renta > 19.747 €       → reducción = 0 €

baseLiquidable = baseAnual − gastosDeducibles − reducción
```

> **Impacto**: Un sueldo de 15.000 €/año tiene ahora una baseLiquidable de ~5.698 € en vez de 15.000 €, lo que reduce drásticamente el IRPF en sueldos bajos.

### Tres caminos según la situación:

#### 6a. IRPF personalizado (Hacienda ha comunicado un tipo fijo)
```
retencionIrpf = totalDevengos × irpfPersonalizado / 100
```

#### 6b. Primer mes del año (o sin datos YTD)
```
mesesRestantes      = 13 - mesActual
baseAnualEstimada   = (totalDevengos × mesesRestantes) + otrasRentas

baseLiquidable     = baseAnualEstimada − reducciónRT
cuota              = impuestoBruto(baseLiquidable) − impuestoBruto(mínimoPF)
porcentajeIrpf     = cuota / baseAnualEstimada × 100
retencionIrpf      = totalDevengos × porcentajeIrpf / 100
```

#### 6c. Meses siguientes con datos YTD (método AEAT de regularización)
```
baseAnualEstimada = baseAcumuladaYtd + (totalDevengos × mesesRestantes) + otrasRentas
baseLiquidable    = baseAnualEstimada − reducciónRT

cuotaAnualTotal   = impuestoBruto(baseLiquidable) − impuestoBruto(mínimoPF)
IRPF pendiente    = cuotaAnualTotal − irpfYaRetenidoYtd
retencionMes      = IRPF pendiente / mesesRestantes
```

### Tramos progresivos 2026 (estatal + autonómica media)

| Base liquidable | Tipo marginal |
|---|---|
| Hasta 12.450 € | 19 % |
| 12.450 – 20.200 € | 24 % |
| 20.200 – 35.200 € | 30 % |
| 35.200 – 60.000 € | 37 % |
| 60.000 – 300.000 € | 45 % |
| Más de 300.000 € | 47 % |

### Mínimo personal y familiar

| Concepto | Importe |
|---|---|
| Mínimo personal (general) | 5.550 € |
| Mayores de 65 años | +1.150 € |
| Mayores de 75 años | +1.400 € |
| 1er hijo | +2.400 € |
| 2do hijo | +2.700 € |
| 3er hijo | +4.000 € |
| 4to hijo o más | +4.500 € |
| Hijo < 3 años (c/u) | +2.800 € |
| Discapacidad 33–64 % | +3.000 € |
| Discapacidad ≥ 65 % | +9.000 € |

---

## 7. Paso 6 — Salario neto

```
totalDeducciones = totalSSTrabajador + retencionIrpf
salarioNeto      = totalDevengos − totalDeducciones
```

---

## 8. Paso 7 — Coste empresa (SS empresa + MEI)

La empresa paga aparte (no sale del sueldo del empleado):

```
SS Contingencias Comunes    = baseCot × 23,60 %
SS Desempleo (indefinido)   = baseCot × 5,50 %
SS Desempleo (temporal)     = baseCot × 6,70 %
SS FOGASA                   = baseCot × 0,20 %
SS Formación Profesional    = baseCot × 0,60 %
SS Accidentes de Trabajo    = baseCot × 1,50 %  (media IT+IMS)
SS MEI (Equidad Intergener.)= baseCot × 0,58 %

totalSSEmpresa  = CC + Desempleo + FOGASA + FP + AT + MEI
costeTotalEmpresa = totalDevengos + totalSSEmpresa
```

| Concepto | Indefinido | Temporal |
|---|---|---|
| Contingencias Comunes | 23,60 % | 23,60 % |
| Desempleo | **5,50 %** | **6,70 %** |
| FOGASA | 0,20 % | 0,20 % |
| Formación Profesional | 0,60 % | 0,60 % |
| Accidentes de Trabajo | 1,50 % | 1,50 % |
| **MEI** | **0,58 %** | **0,58 %** |
| **TOTAL empresa** | **31,98 %** | **33,18 %** |

---

## 9. Resumen de tipos y topes 2026

| Dato | Valor |
|---|---|
| SMI mensual 2026 | 1.184,00 € (14 pagas) = **1.260 €/mes base mín.** |
| Base máxima de cotización | **4.720,50 €/mes** |
| MEI trabajador | **0,12 %** |
| MEI empresa | **0,58 %** |
| Reducción rendimientos (máx.) | **9.302 €** (2.000 + 7.302) |
| IRPF mínimo tipo efectivo | 0 % (bases bajas) |
| IRPF máximo tipo efectivo | 47 % (bases > 300.000 €) |

---

## 10. Flujo YTD — Regularización anual del IRPF

```
Enero      → Sin YTD → cálculo estándar proyectando anual
Febrero    → Con datos de Enero → método regularización AEAT
...
Diciembre  → Ajuste final: cuota - todo lo retenido / 1 mes
```

Cuando se paga una nómina (`pagarNomina`), el sistema **actualiza automáticamente** en Firestore:
- `datos_nomina.base_acumulada_ytd += totalDevengos`
- `datos_nomina.irpf_acumulado_ytd += retencionIrpf`

Si cambia de año, los acumulados se **resetean a cero**.

---

## 11. Horas extra — UI y cálculo

### Desde el formulario de datos de prueba
Se pasan `horasExtra` y `precioHoraExtra` directamente al motor de cálculo.

### Desde la pantalla de detalle de nómina
Cuando una nómina está en estado **borrador** y el usuario es **propietario**, aparece una sección editable:

1. Se introducen **nº de horas** y **precio por hora (€/h)**
2. Se pulsa **"Recalcular nómina"**
3. El sistema obtiene el `DatosNominaEmpleado` del empleado desde Firestore
4. Llama a `calcularNomina(...)` con los nuevos valores de horas extra
5. Guarda la nómina actualizada con el mismo ID

### En el PDF y detalle
Se muestra: `Horas extra (4h × 18.00€/h)  ..................  €72.00`

---

## 12. ✅ Qué está bien calculado

| Aspecto | Estado |
|---|---|
| Tramos IRPF 2026 progresivos | ✅ Correcto (6 tramos hasta 47 %) |
| **Reducción por rendimientos del trabajo** | ✅ **NUEVO** — 2.000€ gastos + escalonada hasta 7.302€ |
| Mínimo personal y familiar completo | ✅ Correcto (hijos, edad, discapacidad) |
| Método AEAT de regularización YTD | ✅ Implementado correctamente |
| Topes SS mínimo y máximo 2026 | ✅ Correctos |
| Tipos SS trabajador indefinido y temporal | ✅ Diferenciados (1,55 % vs 1,60 %) |
| Tipos SS empresa indefinido y temporal | ✅ Diferenciados (5,50 % vs 6,70 %) |
| **MEI trabajador (0,12 %)** | ✅ **NUEVO** — Incluido en SS trabajador |
| **MEI empresa (0,58 %)** | ✅ **NUEVO** — Incluido en SS empresa |
| FOGASA, FP, AT empresa | ✅ Incluidos |
| **Coeficiente de parcialidad** | ✅ **NUEVO** — Salario ajustado por horas/40h |
| 14 pagas no prorrateadas (jun/dic) | ✅ Paga extra en junio y diciembre |
| 14 pagas prorrateadas | ✅ Divide siempre entre 12 |
| IRPF personalizado fijo | ✅ Bypasea el cálculo automático |
| **Horas extra con precio por hora** | ✅ **NUEVO** — `horasExtra × precioHoraExtra` |
| **UI editar horas extra en borrador** | ✅ **NUEVO** — Botón recalcular en detalle |
| Vinculación nómina → gasto contabilidad | ✅ Al pagar genera gasto automático |
| Alertas contratos temporales a vencer | ✅ Preaviso 30 días |

---

## 13. ⚠️ Limitaciones que quedan

| Aspecto | Limitación | Riesgo |
|---|---|---|
| **Accidentes de Trabajo** | Se usa un tipo fijo del **1,50 %** (media IT+IMS) | El tipo real varía por CNAE (actividad). Puede ser 0,9 % o 7 % según sector |
| **Deducción autonómica** | Se usa la **media nacional**. No diferencia por CCAA | El tipo real puede diferir hasta 4 puntos según comunidad |
| **Contratos de formación dual** | El tipo SS es distinto (cuota fija mensual, no %) | Si hay empleados en formación dual podría ser incorrecto |
| **IRPF sobre horas extra estructurales** | Las horas extra cotizan igual que el salario ordinario | En la práctica las horas extra de fuerza mayor tributan diferente. Pequeña sobreestimación |
| **Tope de cotización por grupo** | España tiene grupos de cotización con bases mínimas específicas | Para titulados superiores (Grupo 1, min ~1.847 €/mes) podría haber infracotización |
| **Prorrata en 14 pagas** | Cuando `pagasProrrateadas = true` con 14 pagas, `pagaExtraProrrata` siempre es `0` | Correcto en resultado pero el desglose del recibo no muestra la prorrata explícita |
| **Cotización adicional solidaridad** | Desde 2025, tramos de cotización adicional para bases > máxima no implementados | Solo afecta a sueldos > 56.646 €/año |

---

## Ejemplo numérico completo

> Empleado: 30.000 €/año, indefinido, soltero, sin hijos, 14 pagas no prorrateadas, Enero 2026, 4 horas extra a 18 €/h

**Paso 1 — Salario base** (jornada completa, coef = 1.0)
```
brutoAnualAjustado = 30.000 × 1.0 = 30.000 €
salarioBase = 30.000 / 14 = 2.142,86 €
pagaExtra   = 0             (no es junio ni diciembre)
```

**Paso 2 — Total devengos**
```
importeHorasExtra = 4 × 18 = 72,00 €
totalDevengos = 2.142,86 + 0 + 72 + 0 = 2.214,86 €
```

**Paso 3 — Base cotización**
```
baseCot = clamp(2.214,86, 1.260, 4.720,50) = 2.214,86 €
```

**Paso 4 — SS trabajador (con MEI)**
```
CC        = 2.214,86 × 4,70 % = 104,10 €
Desempleo = 2.214,86 × 1,55 % =  34,33 €
FP        = 2.214,86 × 0,10 % =   2,21 €
MEI       = 2.214,86 × 0,12 % =   2,66 €
TOTAL SS  =                       143,30 €
```

**Paso 5 — IRPF** *(primer mes, sin YTD, con reducción rendimientos)*
```
baseAnualEstimada = 2.214,86 × 12 = 26.578,29 €

Reducción rendimientos:
  26.578 > 19.747 → reducción escalonada = 0 €
  gastos deducibles = 2.000 €
  baseLiquidable = 26.578,29 − 2.000 = 24.578,29 €

mínimoPF = 5.550 €

impuestoBruto(24.578) = 12.450×19% + (20.200−12.450)×24% + (24.578−20.200)×30%
                      = 2.365,50 + 1.860,00 + 1.313,49 = 5.538,99 €
impuestoBruto(5.550)  = 5.550 × 19% = 1.054,50 €

cuota   = 5.538,99 − 1.054,50 = 4.484,49 €
tipo%   = 4.484,49 / 26.578,29 × 100 = 16,87 %
retención = 2.214,86 × 16,87 % = 373,65 €
```

**Paso 6 — Salario neto**
```
Deducciones = 143,30 + 373,65 = 516,95 €
Neto        = 2.214,86 − 516,95 = 1.697,91 €
```

**Paso 7 — Coste empresa (con MEI)**
```
CC empresa   = 2.214,86 × 23,60 % = 522,71 €
Desempleo    = 2.214,86 × 5,50 %  = 121,82 €
FOGASA       = 2.214,86 × 0,20 %  =   4,43 €
FP           = 2.214,86 × 0,60 %  =  13,29 €
AT           = 2.214,86 × 1,50 %  =  33,22 €
MEI          = 2.214,86 × 0,58 %  =  12,85 €
TOTAL SS emp =                       708,32 €

Coste total empresa = 2.214,86 + 708,32 = 2.923,18 €
```

### Comparativa ANTES vs DESPUÉS de las mejoras

| Concepto | Antes (v1, sin horas extra) | Después (v2, con 4h extra) | Diferencia |
|---|---|---|---|
| SS Trabajador | 136,06 € | **143,30 €** | +7,24 € (MEI + base mayor) |
| IRPF retención | 402,23 € | **373,65 €** | −28,58 € (reducción RT) |
| Salario neto | 1.604,57 € | **1.697,91 €** | +93,34 € |
| SS Empresa | 672,86 € | **708,32 €** | +35,46 € (MEI + base mayor) |
| Coste total empresa | 2.815,72 € | **2.923,18 €** | +107,46 € |
