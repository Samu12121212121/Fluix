# 🏦 Validación de IBAN Español en Fluix CRM

## 📋 Formato del IBAN Español

El sistema **SOLO acepta IBANs españoles válidos** con validación completa de dígitos de control.

### Estructura del IBAN Español (24 caracteres)

```
ES 91 2100 0418 45 0200051332
││ ││ │      │  ││ │
││ ││ │      │  ││ └─── Número de cuenta (10 dígitos)
││ ││ │      │  │└───── DC2: Dígito de control de la cuenta
││ ││ │      │  └────── DC1: Dígito de control de entidad+oficina
││ ││ │      └───────── Código de oficina (4 dígitos)
││ ││ └──────────────── Código de entidad bancaria (4 dígitos)
││ │└─────────────────── CCC (Código Cuenta Cliente) - 20 dígitos
││ └──────────────────── Dígitos de control IBAN (2 dígitos)
│└────────────────────── Código de país (ES)
└─────────────────────── Total: 24 caracteres
```

---

## ✅ Validación en 3 Niveles

### Nivel 1: Formato Básico

```dart
// 24 caracteres exactos
clean.length == 24

// Debe empezar por ES
clean.startsWith('ES')

// Solo números después de ES
RegExp(r'^ES\d{22}$').hasMatch(clean)
```

### Nivel 2: Dígitos de Control IBAN (Módulo 97)

Algoritmo ISO 7064:

1. Reorganizar: mover "ES" + 2 dígitos al final
2. Convertir letras a números: E=14, S=28
3. Calcular módulo 97
4. **Debe dar exactamente 1**

**Ejemplo:** `ES9121000418450200051332`

```
1. Mover ES91 al final:
   21000418450200051332ES91

2. Convertir letras:
   2100041845020005133214 28 91
   
3. BigInt módulo 97:
   210004184502000513321428 91 % 97 = 1 ✅
```

### Nivel 3: Dígitos de Control CCC (20 dígitos)

El CCC (Código Cuenta Cliente) son los 20 dígitos después de "ES" + 2 dígitos IBAN.

**Estructura CCC:**
```
2100 0418 45 0200051332
│    │    ││ │
│    │    ││ └─ Número de cuenta (10 dígitos)
│    │    │└── DC2: Control de la cuenta
│    │    └─── DC1: Control de entidad+oficina
│    └──────── Código oficina (4 dígitos)
└───────────── Código entidad (4 dígitos)
```

**Algoritmo de validación:**

```dart
// DC1 se calcula sobre: "00" + Entidad + Oficina
String cadena1 = "00" + "2100" + "0418" = "0021000418"

// DC2 se calcula sobre: Número de cuenta
String cadena2 = "0200051332"

// Pesos para ambos cálculos:
const pesos = [1, 2, 4, 8, 5, 10, 9, 7, 3, 6]

// Función de cálculo:
int suma = 0;
for (int i = 0; i < 10; i++) {
  suma += int.parse(cadena[i]) * pesos[i];
}
int resto = suma % 11;
int dc = 11 - resto;
if (dc == 11) dc = 0;
if (dc == 10) return ERROR; // No válido

// Verificar:
DC1 calculado == DC1 en IBAN
DC2 calculado == DC2 en IBAN
```

---

## 🔍 Ejemplos de IBANs Válidos

### ✅ Válidos (usados en el seed)

```javascript
'ES9121000418450200051332'  // Banco Santander
'ES7921000813610123456789'  // Banco Santander
'ES1720852066623456789011'  // Banco Sabadell
```

### ❌ Inválidos y por qué

```javascript
'ES0021000418450200051332'  // Dígitos de control IBAN incorrectos (00 en vez de 91)
'ES91210004'                // Muy corto (solo 10 caracteres, necesita 24)
'DE89370400440532013000'    // No es español (DE)
'ES91ABCD0418450200051332'  // Contiene letras en parte numérica
'ES91 2100 0418 45 0200051332' // ✅ Válido (espacios se eliminan automáticamente)
```

---

## 🛠️ Cómo Generar un IBAN Válido

### Opción 1: Usar tu IBAN Real

El más fácil: copia el IBAN de tu cuenta bancaria.

**Dónde encontrarlo:**
- App del banco
- Extracto bancario
- Área privada web del banco

**Formato aceptado:**
```
ES91 2100 0418 45 0200051332  ✅ Con espacios
ES9121000418450200051332      ✅ Sin espacios
es9121000418450200051332      ✅ Minúsculas
```

### Opción 2: Generador Online

Si necesitas IBANs de prueba válidos:

1. [IBAN Calculator](https://www.ibancalculator.com/iban_validar.html)
2. Introduce:
   - País: **España (ES)**
   - Entidad: 2100 (Santander), 0049 (Santander), 2080 (Abanca), etc.
   - Oficina: cualquier 4 dígitos
   - Dígitos de control: se calculan automáticamente
   - Número de cuenta: 10 dígitos

3. Copiar IBAN generado

### Opción 3: IBANs de Prueba Reales (bancos sandbox)

Algunos bancos tienen IBANs de prueba oficiales:

```javascript
// IBANs de prueba de Banco Santander (sandbox)
'ES9121000418450200051332'  // ✅ Válido
'ES7921000813610123456789'  // ✅ Válido
'ES1720852066623456789011'  // ✅ Válido (Sabadell)
```

---

## 💡 Por Qué Tu IBAN No Funciona

### Error: "Dígitos de control IBAN inválidos"

**Causa:** Los 2 dígitos después de "ES" son incorrectos.

**Solución:** 
- Verifica que copiaste bien el IBAN completo
- No inventes números, usa uno real o generado

**Ejemplo:**
```
❌ ES00 2100 0418 45 0200051332  // DC IBAN = 00 (incorrecto)
✅ ES91 2100 0418 45 0200051332  // DC IBAN = 91 (correcto)
```

### Error: "IBAN debe tener 24 caracteres"

**Causa:** Falta o sobra algún dígito.

**Solución:**
- Cuenta bien los dígitos (sin espacios deben ser 24)
- Formato: ES + 22 dígitos

### Error: "CCC contiene caracteres no numéricos"

**Causa:** Pusiste letras donde van números.

**Solución:**
- Después de "ES" + 2 dígitos, todo debe ser numérico
- No confundir con BIC/SWIFT (que sí tiene letras)

---

## 🧪 Probar Validación

Desde la app, puedes probar si un IBAN es válido:

1. Ve a **Empleados → Editar empleado**
2. Pestaña **Datos de nómina**
3. Campo **IBAN para transferencias**
4. Introduce el IBAN
5. Si es válido: ✅ Sin error
6. Si es inválido: ❌ Mensaje específico

---

## 📊 IBANs en el Seed de Datos Demo

Los empleados del seed tienen IBANs válidos:

| Empleado | IBAN | Banco |
|----------|------|-------|
| María García | `ES9121000418450200051332` | Santander |
| Carlos López | `ES7921000813610123456789` | Santander |
| Ana Martínez | `ES1720852066623456789011` | Sabadell |

Estos IBANs están **validados** y funcionarán para:
- Generar ficheros SEPA XML
- Crear remesas de pago de nóminas
- Transferencias bancarias

---

## 🔐 Seguridad

⚠️ **IMPORTANTE:** 

- Los IBANs del seed son **de prueba**
- **NO uses IBANs reales** de otras personas
- Para producción, cada empleado debe proporcionar **su propio IBAN**

---

## 📚 Referencias

- [ISO 7064 - Algoritmo Módulo 97](https://es.wikipedia.org/wiki/C%C3%B3digo_de_cuenta_bancaria#C%C3%A1lculo_del_c%C3%B3digo_IBAN)
- [Código Cuenta Cliente (CCC)](https://es.wikipedia.org/wiki/C%C3%B3digo_de_cuenta_bancaria)
- [Validador IBAN Online](https://www.ibancalculator.com/iban_validar.html)

---

*Documentación generada: 20 Abril 2026 - Fluix CRM v1.0*

