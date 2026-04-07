# 🧪 Comandos para ejecutar los Tests de Fluix CRM

## Requisitos previos
```bash
# Instalar dependencias primero
flutter pub get
```

---

## ▶️ Ejecutar TODOS los tests de una vez
```bash
flutter test
```

---

## 📂 Tests Unitarios (raíz de /test)

| Test | Comando |
|------|---------|
| Antigüedad de trabajadores | `flutter test test/antiguedad_calculator_test.dart` |
| Exportador DR303 2026 v1.0.1 | `flutter test test/dr303e26v101_exporter_test.dart` |
| Config NIF de empresa | `flutter test test/empresa_config_nif_test.dart` |
| Exportaciones NIF real | `flutter test test/exportaciones_nif_real_test.dart` |
| Calculadora de finiquitos | `flutter test test/finiquito_calculator_test.dart` |
| Firma XAdES mínima | `flutter test test/firma_xades_minima_validator_test.dart` |
| Modelo 111 | `flutter test test/modelo111_test.dart` |
| Modelo 190 | `flutter test test/modelo190_test.dart` |
| Integración Mod.303 + DR303 | `flutter test test/mod_303_dr303e26v101_integration_test.dart` |
| Exportador Mod.303 | `flutter test test/mod_303_exporter_test.dart` |
| Exportador Mod.349 | `flutter test test/mod_349_exporter_test.dart` |
| Servicio de nóminas | `flutter test test/nominas_service_test.dart` |
| Política Verifactu 2027 | `flutter test test/politica_verifactu_2027_test.dart` |
| Representación Verifactu | `flutter test test/representacion_verifactu_test.dart` |
| SEPA XML | `flutter test test/sepa_xml_test.dart` |
| Vacaciones calculator | `flutter test test/vacaciones_calculator_test.dart` |
| Validador fiscal integral | `flutter test test/validador_fiscal_integral_test.dart` |
| Validador NIF/CIF | `flutter test test/validador_nif_cif_test.dart` |
| Cadena de hash Verifactu | `flutter test test/verifactu_hash_chain_test.dart` |
| Payload XML Verifactu | `flutter test test/xml_payload_verifactu_builder_test.dart` |
| Widget principal (smoke test) | `flutter test test/widget_test.dart` |

---

## 📂 Tests Fiscales (test/fiscal/)

| Test | Comando |
|------|---------|
| Modelo 115 | `flutter test test/fiscal/mod115_test.dart` |
| Modelo 130 | `flutter test test/fiscal/mod130_test.dart` |
| Modelo 390 | `flutter test test/fiscal/mod390_test.dart` |

Ejecutar todos los tests fiscales:
```bash
flutter test test/fiscal/
```

---

## 📂 Tests de Widgets (test/widget/)

| Test | Comando |
|------|---------|
| Dashboard (widget test) | `flutter test test/widget/dashboard_test.dart` |
| Formulario de empleado | `flutter test test/widget/empleado_form_test.dart` |
| Pantalla de login | `flutter test test/widget/login_screen_test.dart` |
| Lista de nóminas | `flutter test test/widget/nominas_list_test.dart` |

Ejecutar todos los tests de widget:
```bash
flutter test test/widget/
```

---

## 📂 Tests de Integración (test/integration/)

| Test | Comando |
|------|---------|
| Integridad de convenios | `flutter test test/integration/convenios_integridad_test.dart` |
| Reglas de Firestore | `flutter test test/integration/firestore_rules_test.dart` |
| Nóminas en Firestore | `flutter test test/integration/nominas_firestore_test.dart` |
| SEPA XML end-to-end | `flutter test test/integration/sepa_xml_e2e_test.dart` |

Ejecutar todos los tests de integración:
```bash
flutter test test/integration/
```

---

## 🎛️ Opciones útiles

```bash
# Ver output detallado (útil para debug)
flutter test --reporter=expanded

# Ejecutar un test por nombre (expresión regular)
flutter test --name "calcular finiquito"

# Ejecutar solo los que fallen
flutter test --run-skipped

# Ver cobertura de código
flutter test --coverage
# Luego abrir el reporte (requiere lcov):
# genhtml coverage/lcov.info -o coverage/html
# start coverage/html/index.html

# Modo verbose (muestra print() durante los tests)
flutter test -v
```

---

## 🚀 Generar icono de la app (tras colocar assets/icons/app_icon.png)

```bash
flutter pub run flutter_launcher_icons
```

---

## 📦 Otros comandos de mantenimiento

```bash
# Instalar/actualizar dependencias
flutter pub get

# Comprobar dependencias desactualizadas
flutter pub outdated

# Actualizar dependencias menores
flutter pub upgrade

# Limpiar build (recomendado antes de release)
flutter clean && flutter pub get

# Analizar el código
flutter analyze
```

