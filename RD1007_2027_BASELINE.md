# RD1007 Baseline 2027

Resumen operativo consolidado del Reglamento Verifactu (RD 1007/2023) con cambios de RD 254/2025 y RDL 15/2025.

## Plazos vigentes
- IS (`art. 3.1.a`): adaptacion antes de `01/01/2027`.
- Resto obligados (`art. 3.1`): adaptacion antes de `01/07/2027`.
- Productores software (`art. 3.2`): `28/07/2025`.

## Alcance y exclusiones
- Obligados: IS, IRPF actividad economica, EP IRNR, entidades en atribucion.
- Exclusion total si el obligado lleva libros por `SII` (`art. 3.3`).
- Exclusion objetiva adicional: DA 3a/6a RD 1619/2012 y EP en extranjero.

## Reglas tecnicas clave
- Alta y anulacion con encadenamiento hash en cadena unica por NIF.
- Hash obligatorio en todos los registros.
- Firma electronica obligatoria solo en `NO VERI*FACTU`.
- En `VERI*FACTU`, remision automatica de todos los registros a AEAT y exencion de firma.

## Checklist minimo
- [ ] Alta simultanea o inmediatamente anterior a expedicion.
- [ ] Anulacion con registro dedicado.
- [ ] Hash SHA-256 en todos los registros.
- [ ] Firma solo si NO VERI*FACTU.
- [ ] QR en todas las facturas; leyenda VERI*FACTU solo en ese modo.
- [ ] Cadena separada por obligado tributario en multi-tenant.
- [ ] Registro de eventos y exportacion legible.
- [ ] Declaracion responsable visible por version.

## Implementacion en repo
- Politica normativa: `lib/services/verifactu/politica_verifactu_2027.dart`
- Test de politica: `test/politica_verifactu_2027_test.dart`
- Representacion terceros: `lib/services/verifactu/representacion_verifactu.dart`
- Test representacion: `test/representacion_verifactu_test.dart`


