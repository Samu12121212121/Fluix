# GUÍA DE INTEGRACIÓN INMEDIATA — Lunes 21/03/2026

## 🎯 META HOY
Integrar validador fiscal en UI, de modo que cada factura que cree el usuario sea validada automáticamente contra la normativa.

---

## PASO 1 — Actualizar `facturacion_service.dart`

**Ubicación:** `lib/services/facturacion_service.dart`

**Qué hacer:** El código ya está. Solo necesitas obtener `EmpresaConfig`:

```dart
// En crearFactura(), antes de la línea await docRef.set()

// Obtener config empresa para validación
final empresaDocSnap = await _db.collection('empresas').doc(empresaId).get();
final empresaConfig = EmpresaConfig.fromMap(empresaDocSnap.data()!);

// Validar factura
final resultadoValidacion = ValidadorFiscalIntegral.validarFacturaCompleta(
  factura,
  empresaConfig,
  [], // TODO: pasar lista real en siguiente sprint
);

if (!resultadoValidacion.esValido) {
  throw Exception(
    'VALIDACIÓN FISCAL FALLIDA:\n${resultadoValidacion.obtenerResumen()}',
  );
}
```

---

## PASO 2 — Integrar Panel UI en Pantalla de Facturación

**Ubicación:** `lib/features/facturacion/pantallas/` (la que uses para crear facturas)

**Qué hacer:** Mostrar resultado de validación:

```dart
// En el widget de creación de factura:

import 'package:planeag_flutter/features/facturacion/widgets/panel_validacion_fiscal.dart';

// Después de validar y antes de guardar:
final resultado = ValidadorFiscalIntegral.validarFacturaCompleta(factura, empresa, []);

// Mostrar resultado
if (!resultado.esValido) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('❌ Factura Inválida'),
      content: SingleChildScrollView(
        child: PanelResultadoValidacionFiscal(resultado: resultado),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Corregir'),
        ),
      ],
    ),
  );
  return; // No continuar
}

// Si es válida (posible advertencias):
if (resultado.advertencias.isNotEmpty) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('⚠️ Advertencias Detectadas'),
      content: SingleChildScrollView(
        child: BannerValidacionFiscal(resultado: resultado),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Revisar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            // Continuar con guardado
            guardarFactura();
          },
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
} else {
  // ✅ VÁLIDA y sin advertencias: guardar directamente
  await guardarFactura();
}
```

---

## PASO 3 — Exportar MOD 303 desde la Pantalla

**Ubicación:** Pantalla de reportes / modelos fiscales

**Qué hacer:** Añadir botón "Exportar MOD 303 DR303e26v101":

```dart
import 'package:planeag_flutter/services/mod_303_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// En botón de exportación:
Future<void> exportarMod303() async {
  try {
    final mod303Service = Mod303Service();
    
    // Generar fichero
    final contenido = await mod303Service.generarMod303Dr303e26v101(
      empresaId: widget.empresaId,
      nifEmpresa: empresaConfig.nif,
      nombreEmpresa: empresaConfig.razonSocial,
      anio: 2026,
      trimestre: 1, // o lo que seleccione usuario
    );

    // Guardar en descarga
    final dir = await getDownloadsDirectory();
    final file = File('${dir!.path}/MOD303_2026_T1.txt');
    await file.writeAsString(contenido);

    // Compartir
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'MOD 303 2026 T1',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ MOD 303 exportado correctamente')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Error: $e')),
    );
  }
}
```

---

## PASO 4 — Exportar MOD 349 (Intracomunitarias)

**Ubicación:** Misma pantalla, opción "MOD 349"

**Qué hacer:** Similar al MOD 303:

```dart
import 'package:planeag_flutter/services/mod_349_service.dart';
import 'package:planeag_flutter/services/exportadores_aeat/mod_349_exporter.dart';

Future<void> exportarMod349() async {
  try {
    final mod349Service = Mod349Service();
    final mod349Exporter = Mod349Exporter();

    // Obtener operadores intracomunitarios
    final operadores = mod349Service.calcularOperadoresPeriodo(
      facturasDelPeriodo, // obtener de BD
      facturasRecibidasDelPeriodo, // obtener de BD
      '1T', // período seleccionado
      2026,
    );

    if (operadores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ℹ️ No hay operaciones intracomunitarias')),
      );
      return;
    }

    // Generar fichero
    final bytes = await mod349Exporter.exportar(
      DatosMod349(
        empresa: empresaConfig,
        ejercicio: 2026,
        periodo: '1T',
        operadores: operadores,
      ),
    );

    // Guardar
    final dir = await getDownloadsDirectory();
    final file = File('${dir!.path}/MOD349_2026_T1.txt');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)]);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ MOD 349 exportado')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Error: $e')),
    );
  }
}
```

---

## PASO 5 — Tests Locales

**Comando:**

```bash
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter

# Ejecutar todos los tests de fiscal
flutter test test/validador_fiscal_integral_test.dart -v

# Tests de Verifactu
flutter test test/verifactu_hash_chain_test.dart -v

# Tests de exportadores
flutter test test/dr303e26v101_exporter_test.dart -v
flutter test test/mod_349_exporter_test.dart -v

# Todos los tests fiscal
flutter test test/ -k fiscal -v
```

---

## PASO 6 — Marcar Clientes como Intracomunitarios

**En formulario de cliente:**

Añadir checkbox + campo:

```dart
CheckboxListTile(
  title: const Text('¿Cliente intracomunitario (EU)?'),
  value: esIntracomunitario,
  onChanged: (v) => setState(() => esIntracomunitario = v ?? false),
),

if (esIntracomunitario)
  TextFormField(
    decoration: const InputDecoration(labelText: 'NIF-IVA Comunitario (ej: DE123456789)'),
    onChanged: (v) => nifIvaComunitario = v,
    validator: (v) {
      if (!Mod349Service().esVatIntracomunitarioValido(v ?? '')) {
        return 'NIF-IVA inválido para el país';
      }
      return null;
    },
  ),
```

---

## PASO 7 — Crear Factura de Prueba

**Flujo:**

1. Crear cliente con:
   - Nombre: "Acme GmbH"
   - NIF: "DE123456789"
   - esIntracomunitario: true

2. Crear factura de venta:
   - Cliente: Acme GmbH
   - Importe: 1.000€
   - IVA: 0% (debe forzarse automáticamente)

3. Debería:
   - ✅ Validar sin errores
   - ✅ Generar registro Verifactu con hash SHA-256
   - ✅ Incluir en MOD 349 (no en MOD 303)
   - ✅ QR con URL AEAT

---

## CHECKLIST PARA HOY

- [ ] Actualizar `facturacion_service.dart` con validación
- [ ] Importar panel validación en UI
- [ ] Añadir validación antes de guardar
- [ ] Botón exportar MOD 303
- [ ] Botón exportar MOD 349
- [ ] Checkbox "intracomunitario" en cliente
- [ ] Tests locales (10 tests = 10 ✅)
- [ ] Crear factura test intracomunitaria
- [ ] Verificar MOD 349 se genera
- [ ] Verificar MOD 303 no incluye intracom.

---

## PRÓXIMA SESIÓN (Martes)

- Integración con UI pantalla reportes
- Tests con datos reales
- Preparar envío sandbox AEAT
- Documentación para auditor

---

## 📞 SOPORTE TÉCNICO

Si algo falla:

1. **Importaciones:** Verifica rutas relativas. Todos los archivos están en `lib/services/verifactu/`
2. **Errors de compilación:** Ejecuta `flutter pub get` y reconstruye
3. **Tests fallan:** Lee el mensaje de error — son descritos explícitamente (ej: "R1-CORRELATIVIDAD")
4. **NIF-IVA no válido:** Usa formato oficial (ej: `DE123456789`, `FR12345678901`, `IT12345678901`)

---

**¡Buena suerte! 🚀 Hoy comenzamos a cumplir la normativa en serio.**

