# Módulo: Nóminas

## Qué hace

Cálculo, generación y gestión completa de nóminas españolas. Incluye: cotizaciones a la Seguridad Social (trabajador y empresa), IRPF autonómico con tramos 2026, convenios colectivos, horas extraordinarias, pagas extras, embargos judiciales, remesas SEPA y firma digital del empleado.

---

## Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/nominas/pantallas/detalle_nomina_screen.dart` | Desglose completo de la nómina |
| `features/nominas/pantallas/revision_nomina_empleado_screen.dart` | Vista de revisión pre-envío |
| `features/nominas/pantallas/nueva_remesa_form.dart` | Crear período de nóminas |
| `features/nominas/pantallas/remesa_sepa_screen.dart` | Generar XML SEPA para banco |
| `features/nominas/widgets/firma_digital_canvas.dart` | Canvas de firma del empleado |
| `features/nominas/widgets/resumen_costes_widget.dart` | Coste total para la empresa |
| `features/nominas/widgets/complementos_mes_widget.dart` | Pluses y complementos |
| `features/nominas/widgets/resumen_ausencias_mes_widget.dart` | Ausencias del período |
| `domain/modelos/remesa_sepa.dart` | Modelo de remesa SEPA |
| `services/remesa_sepa_service.dart` | Generación XML ISO 20022 |

---

## Modelo de datos: Nómina

```dart
Nomina {
  id: String
  empleadoId: String
  mes: int
  año: int
  estado: EstadoNomina        // borrador, aprobada, pagada
  
  // Devengos (bruto)
  salarioBase: double
  complementos: double
  horasExtraEstructurales: double
  horasExtraFuerzaMayor: double
  pagas: double               // prorrateo pagas extras
  antiguedad: double
  plusTransporte: double
  diasTrabajados: int
  diasMes: int
  
  // Deducciones
  cotizacionSsTrabajador: double
  retencionIrpf: double
  embargoDescuento: double
  otrasDeducc: double
  
  // Cuotas empresa (no aparecen en nómina pero se calculan)
  cotizacionSsEmpresa: double
  
  // Resultado
  totalDevengos: double
  totalDeducciones: double
  liquidoPerc: double          // Salario neto
  
  // Pago
  iban: String?
  fechaPago: DateTime?
  firmaEmpleado: String?       // Base64 del canvas de firma
}

enum EstadoNomina { borrador, aprobada, pagada }
```

---

## Cómo funciona internamente

### Cálculo de nómina (2026)

#### 1. Cotización a la Seguridad Social
Los tipos se aplican sobre la **base de cotización** = salario bruto mensual (con límites mínimo/máximo por categoría):

| Concepto | Trabajador | Empresa |
|----------|-----------|---------|
| Contingencias comunes | 4,7% | 23,6% |
| Desempleo (indefinido) | 1,55% | 5,5% |
| Desempleo (temporal) | 1,6% | 6,7% |
| Formación profesional | 0,1% | 0,6% |
| FOGASA | — | 0,2% |
| MEI (pensiones) | 0,13% | 0,50% |

#### 2. Retención IRPF
Se calcula según los tramos autonómicos 2026. El tipo efectivo depende de:
- Comunidad Autónoma de la empresa
- Salario bruto anual estimado
- Número de hijos
- Edad (reducción para > 65 años)
- Tipo de contrato

#### 3. Horas extraordinarias
- **Estructurales:** cotización normal + 2% adicional empleado / 12% empresa
- **Fuerza mayor:** reducción: 2% empleado / 12% empresa
- **No estructurales:** cotización como horas normales

#### 4. Embargos
- Se calcula sobre el **salario neto** (tras SS e IRPF)
- La escala sigue el SMI: la primera fracción equivalente al SMI es inembargable
- El exceso tiene tramos del 30%, 50%, 60%, 75%, 90%

#### 5. SMI 2026
- **15.876 €/año** en 14 pagas (1.134 €/mes)

### Flujo de generación de nóminas
1. El propietario crea una "remesa" para el mes en `nueva_remesa_form.dart`
2. El sistema genera automáticamente nóminas en borrador para todos los empleados activos
3. Se calculan los importes según la lógica anterior
4. El propietario revisa cada nómina en `detalle_nomina_screen.dart`, puede ajustar complementos
5. Al aprobar, el estado pasa a `aprobada`
6. El empleado puede ver su nómina en `revision_nomina_empleado_screen.dart` y firmarla digitalmente
7. Al marcar como pagada, se actualiza el estado y se registra la fecha de pago

### Remesa SEPA
- `remesa_sepa_screen.dart` agrupa las nóminas del mes en estado `aprobada`
- `remesa_sepa_service.dart` genera el XML ISO 20022 (PAIN.001)
- El fichero se descarga y se sube al banco para hacer la transferencia masiva

### Firma digital
- `firma_digital_canvas.dart` es un canvas donde el empleado dibuja su firma con el dedo
- La firma se guarda como Base64 en la nómina
- Se puede imprimir en el PDF de la nómina

---

## Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/nominas` | Nómina mensual por empleado |
| `empresas/{empresaId}/nominas/{id}/complementos` | Pluses y complementos del mes |
| `empresas/{empresaId}/configuracion/fiscal` | SMI, tipo IRPF general, CC.AA. |
| `empresas/{empresaId}/empleados` | Datos del empleado para cálculo |
| `convocatorios` (colección global) | Convenios colectivos españoles |

---

## Cloud Functions relacionadas

| Función | Cuándo se ejecuta |
|---------|------------------|
| `scheduledGenerarTareasRecurrentes` | Job mensual — crea recordatorio de nóminas |
| `scheduledRecordatoriosTareas` | Job — alerta si hay nóminas pendientes de aprobar |
| `enviarEmailConPdf` | Callable — envía la nómina por email al empleado |

---

## Conexión con otros módulos

- **Empleados** — fuente de datos: salario, tipo de contrato, SS, embarazos, bajas
- **Vacaciones** — días de vacaciones disfrutados en el mes se descuentan si corresponde
- **Fichajes** — ausencias del mes calculadas desde fichajes reales
- **Finiquitos** — el finiquito usa el historial de nóminas para calcular importes
- **Fiscal** — las retenciones de nóminas alimentan el Modelo 111
