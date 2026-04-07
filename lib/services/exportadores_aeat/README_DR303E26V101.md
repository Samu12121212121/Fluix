# DR303e26v101 Exporter

Implementacion inicial del exportador del Modelo 303 (AEAT) para diseno DR303e26v101.

## Archivo principal

- `lib/services/exportadores_aeat/dr303e26v101_exporter.dart`

## Alcance de esta version

- Registro envolvente pagina 0 (`<T3030...>` + `<AUX>` + cierre).
- Pagina 01 (identificacion + liquidacion principal).
- Pagina 03 (informacion adicional + resultado).
- Pagina DID opcional (`<T303DID00>`) cuando `incluirDid = true`.
- Formateo de campos `An`, `Num`, `N`, importes de 17 posiciones y porcentajes de 5.
- Validaciones basicas de ejercicio, periodo, NIF, forma de pago y rectificativa.

## Ejemplo rapido

```dart
final exporter = Dr303e26v101Exporter();
final txt = exporter.exportar(
  const DatosDr303e26v101(
    nifDeclarante: 'B76543210',
    nombreRazonSocial: 'EMPRESA TEST SL',
    ejercicio: 2026,
    periodo: '1T',
    casillas: {
      '04': 1000,
      '06': 210,
      '20': 50,
      '46': 210,
      '47': 50,
      '71': 160,
    },
  ),
);
```

## Tests

- `test/dr303e26v101_exporter_test.dart`

