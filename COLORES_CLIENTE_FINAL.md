#  Paleta de Colores - Vista Cliente Final

Este documento describe la paleta de colores aplicada a la **vista del usuario final** (clientes que exploran negocios y hacen reservas).

##  Pantallas Afectadas

### ✅ Completamente Actualizadas

1. **`pantalla_explorar.dart`** - Pantalla principal de exploración de negocios
2. **`pantalla_perfil_cliente.dart`** - Perfil del usuario
3. **`detalle_negocio_screen.dart`** - Detalles de un negocio específico

### ❌ NO Afectadas (Mantienen colores originales)

- **`pantalla_login.dart`** - Login de empresas (verde)
- **`pantalla_dashboard.dart`** - Dashboard de empresas
- **`main.dart`** - Pantalla de carga (azul)

---

##  Paleta de Colores

### Colores Principales

```dart
// Primario - Cian Brillante
const Color primario = Color(0xFF00FFC8);      // #00FFC8

// Secundario - Magenta Rojizo
const Color secundario = Color(0xFFFF3296);    // #FF3296

// Acento Rosa
const Color acentoRosa = Color(0xFFFF4678);    // #FF4678

// Acento Rojo/Rosa Vibrante
const Color acentoRojo = Color(0xFFFF2850);    // #FF2850 - RGB(255,40,80)
```

### Colores de Fondo

```dart
// Fondo Principal - Azul Marino Oscuro
const Color fondo = Color(0xFF0A0F23);         // #0A0F23 - RGB(10,15,35)

// Superficie
const Color superficie = Color(0xFF151932);     // #151932

// Tarjeta
const Color tarjeta = Color(0xFF1E2139);       // #1E2139

// Divisores
const Color outlineVariant = Color(0xFF2A2E45); // #2A2E45
```

### Colores de Texto

```dart
// Textos
const Color textoPrimario = Color(0xFFFFFFFF);    // Blanco
const Color textoSecundario = Color(0xFFB0B3C1);  // Gris claro
const Color textoSugerencia = Color(0xFF6B6E82);  // Gris medio
```

---

##  Aplicación por Componente

### AppBar
- **Background**: `#00FFC8` (Cian brillante) o `#151932` (Superficie)
- **Foreground**: `#0A0F23` (Azul marino) para contraste sobre cian, o `#FFFFFF` sobre superficie
- **Icons**: `#FF3296` (Magenta)

### Cards / Tarjetas
- **Background**: `#1E2139` (Tarjeta)
- **Border**: `#2A2E45` (Outline variant)
- **Title**: `#FFFFFF` (Texto primario)
- **Subtitle**: `#B0B3C1` (Texto secundario)

### Botones Primarios
- **Background**: Gradiente de `#FF3296` a `#FF4678` (Magenta a rosa)
- **Text**: `#FFFFFF` (Blanco)

### Botones Secundarios
- **Background**: `#00FFC8` (Cian)
- **Text**: `#0A0F23` (Azul marino para contraste)

### Botones de Acción Destructiva
- **Color**: `#FF2850` (Rojo/rosa vibrante)
- **Uso**: Logout, cancelar, eliminar

### Estados de Reserva
- **Confirmada**: `#00FFC8` (Cian brillante)
- **Pendiente**: `#FF4678` (Rosa alternativo)
- **Cancelada**: `#FF2850` (Rojo/rosa vibrante)

### Rating / Valoraciones
- **Stars**: `#00FFC8` (Cian)
- **Value**: `#FFFFFF` (Texto blanco)
- **Label**: `#B0B3C1` (Texto secundario)

### Puntos de Fidelización
- **Badge Background**: Gradiente `#FF3296` a `#FF4678` (Magenta)
- **Badge Text**: `#FFFFFF` (Blanco)
- **Container**: Gradiente cian con opacidad
- **Icon**: `#00FFC8` (Cian)

### Categorías de Negocio
- **Background**: Gradiente `#FF3296` a `#FF4678` (Magenta)
- **Text**: `#FFFFFF` (Blanco)

### Dividers
- **Color**: `#2A2E45` (Outline variant)

### Progress Indicators
- **Color**: `#00FFC8` (Cian brillante)

---

##  Ejemplo de Uso

```dart
// Ejemplo de Card con el nuevo tema
Card(
  color: const Color(0xFF1E2139), // Tarjeta
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(color: Color(0xFF2A2E45)),
  ),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Título',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFFFFF), // Texto blanco
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Descripción',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFFB0B3C1), // Texto secundario
          ),
        ),
      ],
    ),
  ),
)

// Ejemplo de botón con gradiente magenta
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFFFF3296), Color(0xFFFF4678)], // Magenta a rosa
    ),
    borderRadius: BorderRadius.circular(12),
  ),
  child: ElevatedButton(
    onPressed: () {},
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
    ),
    child: Text('Reservar', style: TextStyle(color: Color(0xFFFFFFFF))),
  ),
)
```

---

## ✨ Características del Diseño

- **Tema oscuro futurista** con azul marino profundo como base
- **Colores neón vibrantes** (cian y magenta) para destacar elementos importantes
- **Gradientes dinámicos** en botones y etiquetas
- **Alto contraste** entre fondo oscuro y acentos brillantes
- **Jerarquía visual clara** mediante niveles de texto
- **Estados diferenciados** con colores específicos

---

##  Paleta Completa en Código

```dart
// Colores principales
static const cyan = Color(0xFF00FFC8);      // #00FFC8 - Cian brillante
static const magenta = Color(0xFFFF3296);   // #FF3296 - Magenta rojizo
static const pink = Color(0xFFFF4678);      // #FF4678 - Rosa alternativo
static const red = Color(0xFFFF2850);       // #FF2850 - RGB(255,40,80)

// Fondos
static const bgDark = Color(0xFF0A0F23);    // #0A0F23 - RGB(10,15,35)
static const surface = Color(0xFF151932);   // #151932
static const card = Color(0xFF1E2139);      // #1E2139
static const outline = Color(0xFF2A2E45);   // #2A2E45

// Textos
static const txtPrimary = Color(0xFFFFFFFF);   // Blanco
static const txtSecondary = Color(0xFFB0B3C1); // Gris claro
static const txtHint = Color(0xFF6B6E82);      // Gris medio
```

---

##  Notas

- Esta paleta se aplica **SOLO a la vista del cliente final**
- La vista de gestión de empresas mantiene su diseño original profesional
- Los colores están optimizados para modo oscuro con acentos neón
- Se ha priorizado el alto contraste y la accesibilidad
- El cian (`#00FFC8`) es el color primario para acciones principales
- El magenta (`#FF3296`) se usa para categorías y elementos secundarios
- El rojo/rosa (`#FF2850`) se reserva para acciones destructivas

---

**Última actualización**: 12 de Mayo de 2026  
**Tema**: Neon Cyber - Cian/Magenta sobre Azul Marino


