# Validador Fiscal Integral

Implementación de las 10 reglas maestras de cumplimiento normativo fiscal español.

## Fuente Normativa

- ✅ Ley 58/2003 General Tributaria (LGT) — arts. 29.2.j, 46, 66, 93
- ✅ Real Decreto 1619/2012 — Reglamento de facturación (arts. 2-23)
- ✅ Real Decreto 1007/2023 — Reglamento Verifactu
- ✅ Real Decreto 254/2025 — Modificación RD 1007/2023
- ✅ Orden HAC/1177/2024 — Especificaciones técnicas Verifactu
- ✅ Resolución AEAT 18-dic-2024 — Representación de terceros
- ✅ Modelo 303 DR303e26v101 — Autoliquidación IVA

## Las 10 Reglas Maestras Implementadas

### R1 — CORRELATIVIDAD
**Norma:** Art. 6.1.a) RD 1619/2012

Los números de factura dentro de una serie deben ser estrictamente correlativos y sin huecos.

```dart
ValidadorFiscalIntegral.validarCorrelatividad(facturasPorSerie)
```

### R2 — HASH CHAIN (Preparado para Verifactu)
**Norma:** Art. 29.2.j LGT

El hash del registro N+1 debe referenciar correctamente el hash del registro N.
*Implementación pendiente en módulo Verifactu.*

### R3 — INALTERABILIDAD
**Norma:** Art. 201 bis LGT

Una vez generado un registro de facturación, no puede modificarse. Solo puede ANULARSE.
*Implementado en EstadoFactura.anulada.*

### R4 — NIF VÁLIDO
**Norma:** Art. 6.1 RD 1619/2012

Ninguna factura puede emitirse sin NIF válido del emisor.
Para facturas completas B2B: también NIF del destinatario.

```dart
ValidadorFiscalIntegral.validarNifesObligatorios(factura, empresa)
```

### R5 — REPRESENTACIÓN
**Norma:** Art. 46 LGT | Resolución AEAT 18-dic-2024

La app no puede enviar a la AEAT en nombre de un cliente sin documento de representación vigente.
*Implementación pendiente en módulo Verifactu.*

### R6 — TIEMPO
**Norma:** Art. 29.2.j LGT

La fecha/hora de generación de cada registro no puede ser superior en más de 1 minuto
a la fecha/hora actual del sistema.

```dart
ValidadorFiscalIntegral.validarTiempoGeneracion(factura)
```

### R7 — CONSERVACIÓN
**Norma:** Art. 66 LGT

Los registros de facturación no pueden eliminarse durante el plazo de prescripción
(4 años) sin consentimiento expreso.

```dart
ValidadorFiscalIntegral.validarConservacion(factura)
```

### R8 — DESGLOSE IVA
**Norma:** Art. 6.1 RD 1619/2012

Si en una factura hay operaciones a distintos tipos de IVA, deben desglosarse
separadamente por tipo.

```dart
ValidadorFiscalIntegral.validarDesgloseIva(factura)
```

### R9 — SERIES SEPARADAS
**Norma:** Art. 6.1 RD 1619/2012

Las facturas rectificativas SIEMPRE en serie propia.
Las autofacturas SIEMPRE en serie propia por destinatario.

```dart
ValidadorFiscalIntegral.validarSeriesPorTipo(facturas)
```

### R10 — FIRMA CUALIFICADA
**Norma:** Art. 30.5 RD 1619/2012 | Orden HAC/1177/2024

La firma electrónica de los registros debe hacerse con un certificado cualificado
de la EU Trusted List. Un certificado caducado o no cualificado NO es válido.
*Implementación pendiente en módulo Verifactu.*

## Uso Integral

Para validar una factura contra TODA la normativa:

```dart
final resultado = ValidadorFiscalIntegral.validarFacturaCompleta(
  factura,
  empresaConfig,
  facturasDelPeriodo, // Para validar correlatividad
);

print(resultado.obtenerResumen());
// ✅ Factura VÁLIDA conforme a normativa fiscal.
// o
// ❌ Factura INVÁLIDA. Se han detectado X error(es) crítico(s).
// ⚠️  Se han detectado Y advertencia(s).
```

## Respuestas Estándar de Error

Cuando se detecta un incumplimiento, el sistema responde con claridad:

```
╔════════════════════════════════════════════════════════════════╗
║ ADVERTENCIA DE INCUMPLIMIENTO FISCAL — R4-NIF-VALIDO
╠════════════════════════════════════════════════════════════════╣
║ DESCRIPCIÓN:
║ Ninguna factura puede emitirse sin NIF válido del emisor.
║
║ NORMA APLICABLE:
║ Art. 6.1 RD 1619/2012
║
║ SOLUCIÓN:
║ Verificar que el NIF sea correcto y esté bien formado.
║
║ RIESGO LEGAL:
║ Infracción tributaria grave. Hasta 150.000€/año (empresa) o
║ 50.000€/año (usuario) según RD 1619/2012 y LGT 58/2003.
╚════════════════════════════════════════════════════════════════╝
```

## Tests

- `test/validador_fiscal_integral_test.dart`

Cobertura:
- ✅ R1 — Correlatividad
- ✅ R4 — NIF válido
- ✅ R6 — Tiempo
- ✅ R7 — Conservación
- ✅ R8 — Desglose IVA
- ✅ R9 — Series separadas

## Próximas Fases (Roadmap Verifactu)

1. **R2, R3, R5, R10** — Módulo de Verifactu con:
   - Firma electrónica XAdES Enveloped
   - Encadenamiento de registros (hash chain)
   - Validación de certificados cualificados
   - Gestión de representación (Anexos I, II, III)

2. **Audit Trail Completo** — Registro de eventos e historial de modificaciones
   - Integridad garantizada (hash chain de eventos)
   - Trazabilidad 100% de todas las operaciones

3. **Exportación a la AEAT** — Integración con API de Verifactu
   - Envío automático de registros
   - Manejo de respuestas y reintentos
   - Notificación de incidencias al usuario

