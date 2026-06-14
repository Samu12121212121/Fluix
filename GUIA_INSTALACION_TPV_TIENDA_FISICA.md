#  Guía de Instalación TPV PlaneaG en Tienda Física

> **Versión:** 1.0.0 | **Fecha:** Mayo 2026
> 
> **Documento oficial para instalación en cliente según tipo de negocio**

---

##  Índice

1. [Requisitos Previos](#requisitos-previos)
2. [Tipos de Instalación según Cliente](#tipos-de-instalación)
3. [Guía por Tipo de Negocio](#guía-por-tipo-de-negocio)
   - [ Tienda/Comercio](#-tiendacomercio)
   - [️ Bar/Restaurante](#-barrestaurante)
   - [ Peluquería/Salón de Belleza](#-peluqueríasalón-de-belleza)
4. [Hardware Recomendado](#hardware-recomendado)
5. [Configuración Paso a Paso](#configuración-paso-a-paso)
6. [Solución de Problemas](#solución-de-problemas)
7. [Capacitación del Personal](#capacitación-del-personal)

---

##  Requisitos Previos

### Hardware Mínimo

#### Para Android Tablet/Móvil
- **Sistema Operativo:** Android 7.0 (Nougat) o superior
- **RAM:** 2GB mínimo (4GB recomendado)
- **Almacenamiento:** 500MB libres
- **Pantalla:** 7" mínimo (10" recomendado para TPV fijo)
- **Conectividad:** WiFi o 4G/5G

#### Para Windows Desktop/Laptop
- **Sistema Operativo:** Windows 10/11
- **RAM:** 4GB mínimo (8GB recomendado)
- **Almacenamiento:** 1GB libre
- **Pantalla:** 1366x768 mínimo (Full HD recomendado)
- **Conectividad:** WiFi o Ethernet

### ⚠️ Importante
- ✅ Conexión a Internet estable (mínimo 5 Mbps)
- ✅ Cuenta de email del negocio
- ✅ Datos fiscales del negocio (CIF, domicilio, etc.)
- ⚠️ **En iOS:** La impresión Bluetooth tiene limitaciones. Recomendado usar impresoras WiFi

---

##  Tipos de Instalación según Cliente

### Tipo 1: Cliente con Tablet Android (más común)
**Ideal para:** Tiendas pequeñas, peluquerías, bares urbanos

**Ventajas:**
- ✅ Movilidad total
- ✅ Espacio reducido
- ✅ Bajo coste
- ✅ Lector de códigos de barras integrado (cámara)

**Instalación:** Google Play Store → PlaneaG TPV

---

### Tipo 2: Cliente con PC Windows de Escritorio
**Ideal para:** Restaurantes grandes, supermercados, comercios con facturación alta

**Ventajas:**
- ✅ Pantalla grande
- ✅ Mayor potencia
- ✅ Teclado físico
- ✅ Múltiples periféricos (impresoras, cajones, lectores USB)

**Instalación:** Descarga directa desde web PlaneaG

---

### Tipo 3: Cliente Híbrido (Recomendado para negocios medianos)
**Ideal para:** Restaurantes con comandas móviles, peluquerías con recepción

**Ventajas:**
- ✅ Lo mejor de ambos mundos
- ✅ PC en caja + tablets para camareros
- ✅ Sincronización en tiempo real

**Instalación:** Combinación de Tipo 1 + Tipo 2

---

##  Guía por Tipo de Negocio

---

##  Tienda/Comercio

### ¿Para quién es este TPV?
- Tiendas de ropa, calzado, complementos
- Ferreterías, librerías, jugueterías
- Bazares, tiendas de regalo
- Supermercados pequeños/medianos

### Hardware Específico Recomendado

#### Configuración Básica (200-400€)
```
✅ Tablet Android 10" (Samsung Galaxy Tab A7/A8)
✅ Impresora térmica Bluetooth 58mm
✅ Lector de códigos de barras Bluetooth (opcional)
✅ Protector antirrobo para tablet
```

#### Configuración Avanzada (600-1200€)
```
✅ PC Windows todo-en-uno táctil
✅ Impresora térmica USB 80mm
✅ Lector de códigos de barras USB láser
✅ Cajón portamonedas con apertura automática
✅ TPV táctil de 15" o 17"
```

### Proceso de Instalación - Tienda

#### Paso 1: Descarga e Instalación

**En Android:**
```
1. Abrir Google Play Store
2. Buscar "PlaneaG TPV"
3. Pulsar "Instalar"
4. Esperar descarga (50-80 MB)
5. Pulsar "Abrir"
```

**En Windows:**
```
1. Ir a https://planeag.com/descargas
2. Click en "Descargar PlaneaG TPV para Windows"
3. Ejecutar PlaneaG_TPV_Setup.exe
4. Seguir asistente de instalación
5. Crear acceso directo en escritorio
```

#### Paso 2: Configuración Inicial

```
1. Abrir PlaneaG TPV
2. Pulsar "Crear cuenta nueva" o "Iniciar sesión"
3. Introducir email del negocio
4. Crear contraseña segura (mínimo 8 caracteres)
5. Verificar email (revisar bandeja de entrada)
```

#### Paso 3: Configuración del Negocio

```
┌─────────────────────────────────────────┐
│   DATOS DE LA EMPRESA                   │
├─────────────────────────────────────────┤
│ Nombre comercial: [Tu Tienda S.L.]     │
│ CIF/NIF: [B12345678]                    │
│ Dirección: [Calle Principal 123]        │
│ Código Postal: [28001]                  │
│ Ciudad: [Madrid]                         │
│ Teléfono: [912345678]                    │
│ Email: [info@tutienda.es]               │
│                                          │
│ Tipo de TPV: ☑️ Tienda/Comercio         │
│              ☐ Bar/Restaurante           │
│              ☐ Peluquería/Salón          │
└─────────────────────────────────────────┘
```

#### Paso 4: Configurar Catálogo de Productos

**Opción A: Importación masiva (CSV)**
```
1. Ir a "Configuración" → "Catálogo"
2. Pulsar "Importar desde CSV"
3. Descargar plantilla Excel
4. Rellenar: Código, Nombre, Precio, Stock, Categoría
5. Subir archivo
```

**Ejemplo de CSV:**
```csv
codigo,nombre,precio,stock,categoria,iva
8412345678901,Camiseta Básica Azul,19.99,50,Ropa,21
8412345678902,Pantalón Vaquero Negro,39.99,30,Ropa,21
8412345678903,Zapatillas Deportivas,59.99,20,Calzado,21
```

**Opción B: Entrada manual (productos por separado)**
```
1. Ir a "Productos" → Botón "+"
2. Rellenar:
   - Código de barras (escanear o escribir)
   - Nombre del producto
   - Precio de venta (€)
   - Stock actual
   - Categoría (crear si no existe)
   - % IVA (21%, 10%, 4%)
3. Añadir foto (opcional)
4. Pulsar "Guardar"
```

#### Paso 5: Conectar Impresora Térmica (Bluetooth)

**En Android:**
```
1. Encender impresora térmica
2. Ir a "Ajustes" del móvil/tablet → Bluetooth
3. Buscar dispositivo (ej: "RPP02N" o "BlueTooth Printer")
4. Emparejar (PIN suele ser: 0000 o 1234)
5. En PlaneaG TPV → "Configuración" → "Impresora"
6. Seleccionar impresora emparejada
7. Pulsar "Imprimir prueba"
```

**En Windows (USB):**
```
1. Conectar impresora por USB
2. Windows instala drivers automáticamente
3. Ir a "Panel de Control" → "Dispositivos e Impresoras"
4. Verificar que aparece
5. En PlaneaG TPV → "Configuración" → "Impresora"
6. Seleccionar impresora USB
7. Pulsar "Imprimir prueba"
```

#### Paso 6: Configurar Lector de Códigos de Barras

**Opción 1: Lector Físico Bluetooth/USB**
```
1. Emparejar/conectar lector (igual que impresora)
2. En PlaneaG TPV → "Configuración" → "Hardware"
3. Activar "Lector de códigos externo"
4. Escanear un código de prueba
```

**Opción 2: Cámara del Dispositivo (sin hardware adicional)**
```
1. Al buscar producto, pulsar botón " Escanear"
2. Dar permisos de cámara (1ª vez)
3. Enfocar código de barras
4. Se detecta automáticamente
```

#### Paso 7: Primera Venta de Prueba

```
1. En pantalla principal del TPV
2. Buscar producto (por nombre o escanear código)
3. Producto se añade al ticket
4. Aplicar descuento si procede (botón "%")
5. Pulsar "Cobrar"
6. Seleccionar método de pago:
   - Efectivo → Introducir cantidad recibida
   - Tarjeta → Confirmar
   - Mixto → Combinar ambos
7. Se imprime ticket automáticamente
8. ✅ Venta completada
```

#### Paso 8: Gestión de Stock

```
 El stock se actualiza automáticamente con cada venta

Para ajustes manuales:
1. Ir a "Productos" → Seleccionar producto
2. Pulsar "Editar stock"
3. Opciones:
   - ➕ Añadir entrada (nueva compra)
   - ➖ Restar salida (devolución, rotura)
   - ✏️ Ajustar inventario (recuento físico)
```

#### Paso 9: Cierre de Caja (Z Report)

**Al final del día:**
```
1. Ir a "TPV" → Menú (☰)
2. Pulsar "Cierre de caja"
3. Revisar resumen:
   - Total ventas en efectivo
   - Total ventas con tarjeta
   - Número de tickets
   - Productos más vendidos
4. Pulsar "Cerrar turno"
5. Se genera PDF con cierre
6. Imprimir o enviar por email
```

### Funcionalidades del TPV Tienda (10/10)

#### ✅ Gestión de Ventas
- ✅ Búsqueda rápida de productos (nombre, código, escaneo)
- ✅ Ticket en tiempo real con suma automática
- ✅ Edición de precio/cantidad por línea
- ✅ Productos manuales/libres (para artículos sin código)
- ✅ Descuentos (% o importe fijo)
- ✅ Búsqueda y asociación de clientes
- ✅ Cobro (efectivo, tarjeta, mixto) con cálculo automático de cambio

#### ✅ Gestión de Inventario
- ✅ Stock actualizado en tiempo real
- ✅ Alertas de stock mínimo
- ✅ Historial de movimientos
- ✅ Importación masiva por CSV
- ✅ Categorías ilimitadas
- ✅ Fotos de productos

#### ✅ Devoluciones/Cambios
- ✅ Sistema completo de devoluciones
- ✅ Búsqueda de ticket por número o cliente
- ✅ Devolución parcial o total
- ✅ Generación de ticket de abono
- ✅ Restitución automática de stock
- ✅ Registro en historial del cliente

#### ✅ Facturación e Informes
- ✅ Tickets térmicos (58mm/80mm)
- ✅ Facturas simplificadas
- ✅ Cierre de caja diario (Z Report)
- ✅ Listado de mejores productos
- ✅ Estadísticas de ventas
- ✅ Exportación a PDF

#### ✅ Funcionalidades Adicionales
- ✅ Trabajo sin conexión (almacenamiento local)
- ✅ Sincronización automática al recuperar Internet
- ✅ Indicador visual de conectividad
- ✅ Multi-usuario (varios empleados con sus códigos)
- ✅ Protección de datos (Firebase encriptado)

---

## ️ Bar/Restaurante

### ¿Para quién es este TPV?
- Bares, cafeterías, cervecerías
- Restaurantes (todos los tamaños)
- Pubs, discotecas con servicio de barra
- Chiringuitos, terrazas

### Hardware Específico Recomendado

#### Configuración Básica (300-500€)
```
✅ Tablet Android 10" para caja
✅ 1-2 móviles Android para camareros
✅ Impresora térmica WiFi 80mm (cocina)
✅ Impresora térmica Bluetooth 58mm (comandas móviles)
```

#### Configuración Avanzada (1200-2500€)
```
✅ PC Windows TPV táctil 15" en caja
✅ 3-4 tablets Android 8" para camareros
✅ 2 impresoras térmicas WiFi (cocina + barra)
✅ Router WiFi potente (mínimo 100 Mbps)
✅ Sistema de llamada a cocina (opcional)
✅ Pantalla cliente (mostrar total)
```

### Proceso de Instalación - Bar/Restaurante

#### Paso 1: Instalación (igual que Tienda)
Ver sección anterior para descarga e instalación básica.

#### Paso 2: Configuración del Negocio

```
┌─────────────────────────────────────────┐
│   CONFIGURACIÓN BAR/RESTAURANTE         │
├─────────────────────────────────────────┤
│ Tipo de TPV: ☐ Tienda/Comercio         │
│              ☑️ Bar/Restaurante         │
│              ☐ Peluquería/Salón         │
│                                          │
│ Configuración específica:                │
│ ☑️ Gestión por mesas                    │
│ ☑️ Comandas por empleado                │
│ ☑️ Variantes de productos               │
│ ☐ Caja rápida (para take-away)         │
│ ☑️ Envío a cocina automático            │
└─────────────────────────────────────────┘
```

#### Paso 3: Crear Plano de Mesas

```
1. Ir a "Configuración" → "Mesas"
2. Click "Nueva zona":
   - Nombre: "Terraza", "Sala interior", "Barra"
3. Click "Nueva mesa":
   - Número: 1, 2, 3...
   - Capacidad: 2, 4, 6, 8 personas
   - Zona: Terraza
4. Repetir para todas las mesas
```

**Ejemplo de configuración:**
```
 TERRAZA (10 mesas)
   Mesa 1 → 4 personas
   Mesa 2 → 4 personas
   Mesa 3 → 2 personas
   ...

 SALA INTERIOR (15 mesas)
   Mesa 11 → 6 personas
   Mesa 12 → 4 personas
   ...

 BARRA (3 posiciones)
   Barra 1 → 2 personas
   Barra 2 → 2 personas
   Barra 3 → 2 personas
```

#### Paso 4: Configurar Catálogo de Productos

**Estructura recomendada:**

```
 BEBIDAS
   ├─ Cervezas (Estrella, Mahou, Heineken...)
   ├─ Refrescos (Coca-Cola, Fanta, Agua...)
   ├─ Vinos (Tinto, Blanco, Rosado...)
   ├─ Licores (Gin, Vodka, Ron...)
   └─ Cafés e Infusiones

 COMIDAS
   ├─ Entrantes (Ensaladas, Croquetas...)
   ├─ Principales (Carnes, Pescados, Pasta...)
   ├─ Guarniciones (Patatas, Arroz...)
   └─ Postres

 TAPAS & RACIONES
```

**Productos con Variantes (importante para hostelería):**

```
Ejemplo: "Café"
├─ Solo → 1,20€
├─ Cortado → 1,30€
├─ Con leche → 1,40€
└─ Americano → 1,50€

Ejemplo: "Cerveza"
├─ Caña → 2,00€
├─ Jarra → 3,50€
└─ Botella → 2,50€
```

**Cómo crear producto con variantes:**
```
1. "Productos" → "+"
2. Nombre: "Café"
3. Activar "Tiene variantes" ✅
4. Añadir variantes:
   - Solo: 1,20€
   - Cortado: 1,30€
   - Con leche: 1,40€
5. Guardar
```

#### Paso 5: Flujo de Trabajo - Servicio de Mesa

**1. Cliente llega → Asignar mesa**
```
Camarero en tablet:
1. Pantalla principal muestra plano de mesas
2. Mesas verdes = libres
3. Mesas rojas = ocupadas
4. Mesas naranjas = reservadas
5. Click en mesa libre → "Abrir mesa"
```

**2. Tomar comanda**
```
1. Mesa abierta, ahora en estado "ocupada"
2. Click en mesa → "Tomar comanda"
3. Buscar productos:
   - Por categoría (Bebidas → Cervezas)
   - Por búsqueda (escribir "coca")
4. Si tiene variantes → Selector aparece
5. Añadir al ticket con cantidad
6. Añadir nota si procede (ej: "Sin cebolla")
7. Botón "Enviar a cocina" → Comanda se imprime
```

**3. Añadir más productos (nuevos pedidos)**
```
1. Click en mesa ocupada
2. Añadir nuevos productos
3. "Enviar a cocina" de nuevo
   → Solo imprime lo nuevo (no duplica)
```

**4. Cobrar cuenta**
```
1. Click en mesa → "Ver cuenta"
2. Revisar total
3. Opciones:
   a) "Cobrar todo" → Cobro normal
   b) "Dividir cuenta" → Separar por comensales
4. Seleccionar método pago
5. Ticket se imprime
6. Mesa pasa a "libre" automáticamente
```

#### Paso 6: Comandas Móviles (Camareros con Tablet/Móvil)

**Configuración de dispositivos móviles:**

```
1. Instalar PlaneaG TPV en cada tablet de camarero
2. Iniciar sesión con la misma cuenta
3. El sistema sincroniza:
   ✅ Catálogo de productos
   ✅ Estado de mesas en tiempo real
   ✅ Comandas abiertas
```

**Funcionamiento multi-dispositivo:**
```
‍ Tablet Caja (fijo en mostrador)
   → Ve todas las mesas
   → Puede cobrar desde aquí
   → Cierre de caja

 Tablet Camarero 1
   → Toma comandas de su zona
   → Envía a cocina
   → No puede hacer cierre de caja

 Tablet Camarero 2
   → Igual, independiente
   → Ve estado en tiempo real
```

#### Paso 7: Impresoras en Cocina

**Configuración recomendada:**

```
️ Impresora Cocina (WiFi)
   → Conectada a red del local
   → Recibe comandas automáticamente
   → Imprime: Fecha/hora, Mesa, Productos, Notas

️ Impresora Barra (WiFi)
   → Para bebidas
   → Solo recibe productos de categoría "Bebidas"
```

**Configurar impresión por categoría (opcional):**
```
1. "Configuración" → "Impresoras"
2. "Añadir impresora"
3. Nombre: "Cocina"
4. Filtro: Categorías "Comidas", "Tapas"
5. "Añadir impresora"
6. Nombre: "Barra"
7. Filtro: Categorías "Bebidas"
```

#### Paso 8: Caja Rápida (Take Away / Para Llevar)

```
Para pedidos sin mesa (take away):

1. En pantalla principal → Botón "Caja Rápida"
2. Tomar pedido (igual que comanda)
3. Click "Cobrar"
4. Ticket se imprime de inmediato
5. No afecta a mesas
```

#### Paso 9: Transferir Comandas entre Mesas

```
Caso: Clientes cambian de mesa

1. Click en mesa origen
2. Botón "⚡ Transferir"
3. Seleccionar mesa destino
4. Se mueve toda la comanda
5. Mesa origen pasa a "libre"
6. Mesa destino ahora tiene la comanda
```

#### Paso 10: Dividir Cuenta

```
Caso: Grupo quiere pagar por separado

1. Click en mesa → "Ver cuenta"
2. Botón "Dividir cuenta"
3. Opciones:
   a) Por partes iguales (ej: 4 personas → 4 tickets de 25% cada uno)
   b) Manual (seleccionar qué productos va en cada ticket)
4. Generar tickets separados
5. Cobrar individualmente
```

### Funcionalidades del TPV Bar/Restaurante (10/10)

#### ✅ Gestión de Mesas
- ✅ Plano visual de mesas por zonas
- ✅ Estados en tiempo real (libre/ocupada/reservada)
- ✅ Capacidad por mesa
- ✅ Historial de ocupación
- ✅ Reservas (nombre, hora, personas)

#### ✅ Sistema de Comandas
- ✅ Comandas por mesa
- ✅ Añadir productos incrementalmente
- ✅ Variantes de productos (tamaños, extras)
- ✅ Notas por línea (ej: "Sin sal")
- ✅ Envío a cocina/barra
- ✅ Solo imprime productos nuevos (no duplica)

#### ✅ Trabajo Multi-Usuario
- ✅ Tablets/móviles sincronizados
- ✅ Cada camarero ve estado global
- ✅ Sin conflictos (actualización en tiempo real)
- ✅ Integración con múltiples impresoras

#### ✅ Cobro y Facturación
- ✅ Cobro desde cualquier dispositivo
- ✅ Dividir cuenta (igual o manual)
- ✅ Transferir comanda entre mesas
- ✅ Caja rápida (take away)
- ✅ Descuentos por línea o total
- ✅ Tickets térmicos
- ✅ Facturas simplificadas

#### ✅ Devoluciones
- ✅ Sistema completo de devoluciones
- ✅ Búsqueda de ticket por mesa o número
- ✅ Devolución parcial/total
- ✅ Ticket de abono

#### ✅ Informes
- ✅ Cierre de caja diario (Z Report)
- ✅ Productos más vendidos
- ✅ Ventas por camarero
- ✅ Histórico de mesas
- ✅ Exportación PDF

---

##  Peluquería/Salón de Belleza

### ¿Para quién es este TPV?
- Peluquerías
- Salones de belleza
- Barberías
- Centros de estética
- Spas con tratamientos

### Hardware Específico Recomendado

#### Configuración Básica (250-450€)
```
✅ Tablet Android 10" en recepción
✅ Impresora térmica Bluetooth 58mm
✅ Soporte de escritorio para tablet
```

#### Configuración Avanzada (700-1500€)
```
✅ PC Windows todo-en-uno táctil en recepción
✅ Tablet Android 8" por cada profesional (opcional)
✅ Impresora térmica WiFi 80mm
✅ Panel LED para llamada de clientes (opcional)
✅ Sistema de sonido/campana
```

### Proceso de Instalación - Peluquería

#### Paso 1: Instalación (igual que anteriores)
Ver sección de Tienda para descarga e instalación.

#### Paso 2: Configuración del Negocio

```
┌─────────────────────────────────────────┐
│   CONFIGURACIÓN PELUQUERÍA              │
├─────────────────────────────────────────┤
│ Tipo de TPV: ☐ Tienda/Comercio         │
│              ☐ Bar/Restaurante          │
│              ☑️ Peluquería/Salón        │
│                                          │
│ Configuración específica:                │
│ ☑️ Gestión de citas/agenda              │
│ ☑️ Profesionales con horarios           │
│ ☑️ Sistema de turnos walk-in            │
│ ☑️ Gestión de cabinas/salas             │
│ ☑️ Bonos/tarjetas de descuento          │
│ ☑️ Comisiones por profesional           │
└─────────────────────────────────────────┘
```

#### Paso 3: Crear Profesionales/Empleados

```
1. Ir a "Configuración" → "Profesionales"
2. Click "Nuevo profesional"
3. Rellenar datos:
   - Nombre: "Ana García"
   - Teléfono: 612345678
   - Especialidad: "Corte y Color"
   - Horario:
     * Entrada: 09:00
     * Salida: 20:00
   - Color de agenda: (elegir color único)
   - % Comisión: 40% (por defecto, editable)
4. Guardar
```

**Ejemplo de equipo:**
```
 Ana García
   Especialidad: Corte y Color
   Horario: 09:00-20:00
   Color:  Púrpura
   Comisión: 40%

 Carlos López
   Especialidad: Barbería
   Horario: 10:00-19:00
   Color:  Azul
   Comisión: 45%

 María Torres
   Especialidad: Estética facial
   Horario: 10:00-21:00
   Color:  Verde
   Comisión: 35%
```

#### Paso 4: Configurar Servicios

```
1. "Configuración" → "Servicios"
2. Crear categorías:
   - Corte
   - Color/Tinte
   - Peinado
   - Manicura/Pedicura
   - Tratamientos faciales
   - Depilación
3. Por cada categoría, añadir servicios:
```

**Ejemplo de servicios:**

```
 CORTE
   ├─ Corte Hombre → 15€ (30 min)
   ├─ Corte Mujer → 25€ (45 min)
   ├─ Corte Niño → 12€ (20 min)
   └─ Arreglo Barba → 8€ (15 min)

 COLOR/TINTE
   ├─ Tinte Completo → 45€ (90 min)
   ├─ Mechas → 60€ (120 min)
   ├─ Baño de Color → 30€ (60 min)
   └─ Balayage → 80€ (150 min)

 MANICURA/PEDICURA
   ├─ Manicura Básica → 20€ (40 min)
   ├─ Manicura Gel → 30€ (60 min)
   ├─ Pedicura → 25€ (50 min)
   └─ Pack Mani+Pedi → 40€ (90 min)

 TRATAMIENTOS
   ├─ Facial Hidratante → 35€ (45 min)
   ├─ Masaje Capilar → 15€ (20 min)
   └─ Limpieza Facial → 40€ (60 min)
```

**Datos de cada servicio:**
- Nombre
- Precio (€)
- Duración (minutos)
- Categoría
- Descripción (opcional)

#### Paso 5: Configurar Cabinas/Salas (Opcional)

```
1. "Configuración" → "Cabinas"
2. Crear salas:
   - Sala 1: "Corte"
   - Sala 2: "Color"
   - Sala 3: "Estética"
   - Sala 4: "Manicura"
3. Durante cada cita, se asigna cabina disponible
```

#### Paso 6: Vista de Agenda (Pantalla Principal)

**Layout de la agenda:**

```
┌─────────────────────────────────────────────────────────────┐
│  HOY: Martes 13 Mayo 2026          [◀ Anterior | Siguiente ▶] │
├──────┬────────────┬────────────┬────────────┬────────────┐
│ HORA │ Ana García │ Carlos López│ María Torres│ Recepción  │
│      │          │           │           │            │
├──────┼────────────┼────────────┼────────────┼────────────┤
│ 09:00│ [Cliente 1]│            │            │            │
│      │ Corte+Tinte│            │            │            │
├──────┼────────────┼────────────┼────────────┼────────────┤
│ 09:30│            │            │            │            │
├──────┼────────────┼────────────┼────────────┼────────────┤
│ 10:00│            │ [Cliente 2]│ [Cliente 3]│            │
│      │            │ Corte Homb │ Facial     │            │
├──────┼────────────┼────────────┼────────────┼────────────┤
│ 10:30│ [Cliente 4]│            │            │            │
│      │ Mechas     │            │            │            │
├──────┼────────────┼────────────┼────────────┼────────────┤
│ 11:00│            │            │            │   Juan   │
│      │            │            │            │  (Walk-in) │
└──────┴────────────┴────────────┴────────────┴────────────┘
```

**Códigos de color por estado:**
```
 Verde → Cita Pendiente (aún no ha llegado)
 Azul → En Curso (cliente en tratamiento)
✅ Gris → Completada (servicio terminado)
❌ Rojo → Cancelada o No Presentado
```

#### Paso 7: Crear Cita (con Cliente con Cita Previa)

```
Recepcionista o auto-gestión online:

1. Click en hueco libre de la agenda
2. Se abre diálogo "Nueva Cita"
3. Rellenar:
   ┌──────────────────────────────┐
   │ NUEVA CITA                   │
   ├──────────────────────────────┤
   │ Profesional: [Ana García ▼] │
   │ Fecha: [13/05/2026]          │
   │ Hora: [11:00 ▼]              │
   │                              │
   │ Cliente: [Buscar...]       │
   │ (Si no existe, crear nuevo)  │
   │                              │
   │ Servicios:                   │
   │ ☑️ Corte Mujer (25€, 45min) │
   │ ☑️ Tinte Completo (45€, 90m)│
   │ ☐ Peinado                    │
   │                              │
   │ Total: 70€                   │
   │ Duración: 135 minutos        │
   │                              │
   │ Notas: [Cliente prefiere...] │
   └──────────────────────────────┘
4. Pulsar "Guardar"
5. Aparece en agenda
```

**Envío de recordatorio automático (si está configurado):**
```
 Email/SMS → 24h antes:
"Hola María, te recordamos tu cita mañana 
a las 11:00 con Ana García en Peluquería Bella.
Servicios: Corte + Tinte. ¡Te esperamos!"
```

#### Paso 8: Sistema Walk-In (Sin Cita Previa)

```
Para clientes que llegan sin cita:

1. Click en "Turnos Walk-In" (botón en la parte derecha)
2. "Nuevo turno"
3. Rellenar:
   - Cliente: (nombre o "Walk-in 1", "Walk-in 2"...)
   - Servicio deseado: "Corte Hombre"
   - Profesional preferido: (opcional)
4. Se añade a cola de espera
5. Cuando profesional queda libre:
   - Sistema sugiere asignar siguiente turno
   - Click "Asignar cita"
   - Se crea cita y se elimina de cola
```

**Panel de turnos walk-in:**
```
┌─────────────────────────────┐
│   COLA DE ESPERA            │
├─────────────────────────────┤
│ 1. Juan Pérez               │
│    Corte Hombre (15€)       │
│    Esperando: 8 min         │
│    [Asignar ▶]              │
├─────────────────────────────┤
│ 2. María Sánchez            │
│    Manicura (20€)           │
│    Esperando: 3 min         │
│    [Asignar ▶]              │
└─────────────────────────────┘
```

#### Paso 9: Atender Cliente (Flujo Completo)

**1. Cliente llega (con/sin cita)**
```
- Si tiene cita → Aparece en agenda
- Si es walk-in → Añadir a cola
```

**2. Marcar cita como "En Curso"**
```
- Click en cita → Botón "Iniciar"
- Estado cambia a  Azul
- Si usa cabinas → Asignar cabina libre
```

**3. Durante el servicio**
```
- Cliente en cabina/silla
- Profesional realiza el servicio
- Si necesita más tiempo → Editar duración
- Si añade servicios → Click "Añadir servicio"
```

**4. Al terminar: Cobrar**
```
- Click en cita → "Completar y cobrar"
- Se abre diálogo de cobro:
  
  ┌─────────────────────────────┐
  │ COBRO - Ana García          │
  ├─────────────────────────────┤
  │ Servicios:                  │
  │ • Corte Mujer      25,00€   │
  │ • Tinte Completo   45,00€   │
  ├─────────────────────────────┤
  │ Subtotal:          70,00€   │
  │                             │
  │ Bono/Descuento: [Aplicar▼] │
  │                             │
  │ Propina:                    │
  │ [0€] [1€] [2€] [5€] [Otro] │
  │                             │
  │ TOTAL:             70,00€   │
  ├─────────────────────────────┤
  │ Método de pago:             │
  │ ⚪ Efectivo                 │
  │ ⚪ Tarjeta                  │
  │ ⚪ Mixto                    │
  └─────────────────────────────┘

- Seleccionar método
- Click "Cobrar"
- Ticket se imprime
- Cita pasa a ✅ Completada
```

**5. Comisión automática del profesional**
```
 Sistema registra automáticamente:
   Profesional: Ana García
   Servicio: Corte + Tinte
   Total venta: 70,00€
   % Comisión: 40%
   Comisión: 28,00€
   
   → Se acumula en informe diario
```

#### Paso 10: Gestión de Bonos/Tarjetas de Descuento

```
Caso: Cliente compra bono de 10 sesiones

1. "Clientes" → Buscar cliente
2. "Bonos" → "Crear bono"
3. Rellenar:
   - Tipo: "Bono 10 sesiones"
   - Precio: 200€ (ahorro de 50€ vs precio unitario)
   - Sesiones totales: 10
   - Servicios aplicables: "Corte Hombre"
   - Caducidad: 6 meses
4. Cobrar bono (200€)
5. Se registra en histórico del cliente

Al cobrar cada sesión posterior:
1. Al cobrar, sistema detecta bono activo
2. Pregunta: "¿Usar bono?" → Sí
3. Sesiones restantes: 9/10
4. No se cobra (o se cobra solo diferencia si añade extras)
```

#### Paso 11: Gestión de Cabinas en Tiempo Real

```
Panel de cabinas (vista opcional):

┌─────────────────────────────────────────┐
│          ESTADO DE CABINAS              │
├──────────┬──────────────────────────────┤
│ Cabina 1 │  Libre                     │
│ (Corte)  │ Última limpieza: 10:45       │
│          │ [Asignar cliente]            │
├──────────┼──────────────────────────────┤
│ Cabina 2 │  Ocupada                   │
│ (Color)  │ Cliente: María Ruiz          │
│          │ Profesional: Ana García      │
│          │ Tiempo restante: 35 min      │
│          │ [Marcar como libre]          │
├──────────┼──────────────────────────────┤
│ Cabina 3 │  En Limpieza               │
│ (Estética)│ Limpiando...                │
└──────────┴──────────────────────────────┘
```

#### Paso 12: Cierre de Caja + Comisiones

```
Al final del día:

1. "TPV" → "Cierre de caja"
2. Resumen general:
   - Total ventas: 850€
   - Nº citas: 15
   - Servicios más vendidos
   - Productos vendidos (si aplica)
   
3. COMISIONES POR PROFESIONAL:
   
    Ana García
      Citas atendidas: 7
      Facturación total: 420€
      Comisión (40%): 168,00€
   
    Carlos López
      Citas atendidas: 5
      Facturación total: 280€
      Comisión (45%): 126,00€
   
    María Torres
      Citas atendidas: 3
      Facturación total: 150€
      Comisión (35%): 52,50€
   
   TOTAL COMISIONES: 346,50€

4. Exportar/imprimir Z Report
5. Enviar por email a gerencia (opcional)
```

### Funcionalidades del TPV Peluquería (10/10)

#### ✅ Gestión de Profesionales
- ✅ Creación de profesionales con horarios
- ✅ Colores únicos para identificación visual
- ✅ Especialidades por profesional
- ✅ % Comisión configurable (0-60%, ajustable en pasos de 5%)
- ✅ Edición y eliminación
- ✅ Histórico de trabajo

#### ✅ Sistema de Citas/Agenda
- ✅ Vista timeline (30 min por slot, 08:00-21:00)
- ✅ Agenda por profesional (columnas separadas)
- ✅ Crear cita (con cliente, servicios, duración)
- ✅ Editar/cancelar cita
- ✅ Estados: Pendiente → En Curso → Completada/Cancelada/No Presentado
- ✅ Búsqueda de clientes
- ✅ Multi-servicio por cita
- ✅ Notas por cita
- ✅ Navegación por días (anterior/siguiente)

#### ✅ Sistema Walk-In (Sin Cita)
- ✅ Cola de espera en tiempo real
- ✅ Añadir turno walk-in
- ✅ Tiempo de espera visible
- ✅ Asignación automática cuando profesional queda libre
- ✅ Notificación sonora (opcional)

#### ✅ Gestión de Cabinas/Salas
- ✅ Crear cabinas con nombre y tipo
- ✅ Estado en tiempo real (libre/ocupada/limpieza)
- ✅ Asignación automática a cita
- ✅ Control de limpieza entre clientes
- ✅ Panel visual de estado

#### ✅ Cobro y Comisiones
- ✅ Cobro al completar cita
- ✅ Multi-servicio en mismo ticket
- ✅ Aplicación de bonos/descuentos
- ✅ Sistema de propinas (0€, 1€, 2€, 5€, personalizado)
- ✅ Cálculo automático de comisión por profesional
- ✅ Registro diario de comisiones
- ✅ Desglose en Z Report

#### ✅ Gestión de Bonos
- ✅ Crear bonos multi-sesión
- ✅ Asignar a cliente
- ✅ Aplicación automática al cobrar
- ✅ Control de sesiones restantes
- ✅ Caducidad configurable
- ✅ Histórico de uso

#### ✅ Clientes
- ✅ Búsqueda rápida
- ✅ Historial de citas
- ✅ Bonos activos del cliente
- ✅ Notas y preferencias
- ✅ Servicios favoritos

#### ✅ Informes
- ✅ Cierre de caja diario
- ✅ Desglose de comisiones por profesional
- ✅ Servicios más vendidos
- ✅ Ocupación por profesional
- ✅ Ingresos por período
- ✅ Exportación PDF

---

## ️ Hardware Recomendado (Detallado)

### Impresoras Térmicas

####  Especificaciones Técnicas

**Impresoras 58mm (Bluetooth)**
- **Para:** Tickets/recibos en tiendas pequeñas, peluquerías
- **Ventajas:** Portable, sin cables, papel más económico
- **Recomendadas:**
  - RPP02N Bluetooth (50-70€)
  - Goojprt PT-210 (40-60€)
  - Zjiang ZJ-5802 (35-50€)
- **Velocidad:** 60-80 mm/s
- **Papel:** Rollo térmico 58mm x 30m
- **Compatibilidad:** Android 4.0+, iOS (limitado), Windows
- **Batería:** 1500-2000 mAh (200-300 tickets por carga)

**Impresoras 80mm (USB/Bluetooth/WiFi)**
- **Para:** Restaurantes, comercios grandes, cocinas
- **Ventajas:** Texto más legible, velocidad mayor, más duraderas
- **Recomendadas:**
  - Epson TM-T20III USB (150-200€)
  - Rongta RP80 WiFi (100-150€)
  - Xprinter XP-Q200 Bluetooth (80-120€)
- **Velocidad:** 150-250 mm/s
- **Papel:** Rollo térmico 80mm x 80m
- **Compatibilidad:** Universal
- **Conectividad:** USB + Ethernet + WiFi (modelos superiores)

**Consumibles:**
```
Papel térmico 58mm x 30m → 0,50-1€/rollo
Papel térmico 80mm x 80m → 1,50-2,50€/rollo
Duración: 1 rollo = 100-200 tickets (según longitud)
```

### Lectores de Códigos de Barras

####  Tipos

**CCD (Contacto)**
- **Precio:** 20-40€
- **Alcance:** 2-5 cm
- **Uso:** Tiendas con pocos productos, mostrador fijo
- **Ejemplo:** Tera HW0006

**Láser (Sin contacto)**
- **Precio:** 50-120€
- **Alcance:** Hasta 30 cm
- **Uso:** Supermercados, almacenes
- **Ejemplo:** Honeywell Voyager 1200g, Symbol LS2208

**2D (QR + códigos)**
- **Precio:** 80-200€
- **Alcance:** Hasta 40 cm
- **Uso:** Tiendas modernas, lectura de QR en móviles
- **Ejemplo:** Zebra DS2208

**Conectividad:**
- USB (plug & play)
- Bluetooth (móvil, requiere emparejamiento)
- WiFi (red local, múltiples dispositivos)

### Cajones Portamonedas

####  Características

**Cajón Manual**
- **Precio:** 30-60€
- **Apertura:** Con llave
- **Compartimentos:** 5 billetes + 8 monedas
- **Uso:** Negocios pequeños

**Cajón Automático (RJ11/USB)**
- **Precio:** 80-150€
- **Apertura:** Automática al cobrar
- **Conexión:** Cable RJ11 desde impresora térmica
- **Compartimentos:** 5 billetes + 8 monedas
- **Uso:** Negocios medianos/grandes
- **Ejemplo:** Star SMD2

**Conexión:**
```
[TPV] → [Impresora térmica] → [Cajón (RJ11)]
Cuando impresora recibe señal de apertura, 
activa cajón automáticamente.
```

### Tablets y Dispositivos

####  Recomendaciones por Presupuesto

**Gama Baja (100-200€)**
- Samsung Galaxy Tab A7 Lite (8,7")
- Lenovo Tab M10 Plus (10,3")
- Amazon Fire HD 10
- **Nota:** Suficiente para TPV básico

**Gama Media (200-400€) ⭐ Recomendado**
- Samsung Galaxy Tab A8 (10,5")
- Lenovo Tab P11 (11")
- Xiaomi Pad 5 (11")
- **Nota:** Óptimo para uso profesional

**Gama Alta (400-800€)**
- Samsung Galaxy Tab S7/S8 (11"/12,4")
- iPad Air (10,9")
- iPad Pro (11" / 12,9")
- **Nota:** Para negocios premium o multi-tarea

**PCs Todo-en-Uno TPV (600-1500€)**
- TPV táctil 15" Windows
- Procesador Intel i3/i5 o AMD Ryzen
- 8GB RAM, 256GB SSD
- Incluye lector tarjetas, impresora (opcional)
- **Ejemplo:** POS-X EVO, HP ElitePOS

### Conectividad de Red

####  Requisitos

**Router WiFi para Negocio**
- **Velocidad:** Mínimo 100 Mbps
- **Banda dual:** 2.4 GHz + 5 GHz
- **Cobertura:** Según tamaño del local
- **Recomendado:** TP-Link Archer C6, Asus RT-AC68U
- **Precio:** 50-150€

**Internet**
- **Mínimo:** 10 Mbps descarga
- **Recomendado:** 50 Mbps o superior
- **Upload:** Mínimo 5 Mbps (para sincronización)

**Red local robusta para restaurantes:**
```
[Modem Fibra] → [Router empresarial] → [Switch PoE]
                                         ├─ Tablet caja
                                         ├─ Impresora cocina (WiFi)
                                         ├─ Impresora barra (WiFi)
                                         ├─ 4x Tablets camareros (WiFi)
                                         └─ PC gestión (Ethernet)
```

---

## ⚙️ Configuración Paso a Paso (Universal)

### 1️⃣ Crear Cuenta

```
1. Descargar PlaneaG TPV (Play Store / Web)
2. Abrir app
3. "Crear cuenta nueva"
4. Email: negocio@ejemplo.com
5. Contraseña: (mínimo 8 caracteres)
6. Confirmar email (revisar inbox)
7. Login con credenciales
```

### 2️⃣ Configurar Empresa

```
Ir a: "Configuración" → "Empresa"

 Datos obligatorios:
- Nombre comercial
- CIF/NIF
- Dirección completa
- CP y Ciudad
- Teléfono
- Email de contacto

 Datos opcionales:
- Logo (recomendado, aparece en tickets)
- Horario de apertura
- Web / Redes sociales
```

### 3️⃣ Seleccionar Tipo de TPV

```
"Configuración" → "Tipo de TPV"

Opciones:
⚪ Tienda/Comercio
⚪ Bar/Restaurante
⚪ Peluquería/Salón

ℹ️ Puedes cambiar en cualquier momento
```

### 4️⃣ Configurar Facturación

```
"Configuración" → "Facturación"

 Datos para tickets y facturas:
- Régimen fiscal: [General / Autónomo / Recargo Equiv.]
- Serie de facturación: [2026-]
- Próximo número: [1]
- Pie de ticket: "Gracias por su visita"
- ☑️ Incluir código QR
- ☑️ Enviar copia por email al cliente

 IVA por defecto:
- 21% (general)
- 10% (alimentación, hostelería)
- 4% (productos básicos)
```

### 5️⃣ Configurar Impresora

```
"Configuración" → "Impresoras"

️ Bluetooth (Android/iPhone):
1. Emparejar impresora en ajustes del dispositivo
2. En PlaneaG: "Añadir impresora"
3. Tipo: Bluetooth
4. Seleccionar de lista
5. "Test de impresión"

️ USB (Windows/Linux):
1. Conectar impresora por USB
2. Esperar instalación de drivers
3. En PlaneaG: "Añadir impresora"
4. Tipo: USB
5. Seleccionar de lista
6. "Test de impresión"

️ WiFi (Red local):
1. Conectar impresora a red WiFi del local
2. Anotar IP de impresora (ver config impresora)
3. En PlaneaG: "Añadir impresora"
4. Tipo: Red/WiFi
5. IP: 192.168.1.XXX
6. Puerto: 9100 (por defecto)
7. "Test de impresión"

 Múltiples impresoras (restaurantes):
- Añadir varias impresoras
- Asignar por categoría:
  * Cocina → Productos "Comidas"
  * Barra → Productos "Bebidas"
```

### 6️⃣ Configurar Métodos de Pago

```
"Configuración" → "Métodos de Pago"

Por defecto activados:
✅ Efectivo
✅ Tarjeta
✅ Mixto

Opcional:
☐ Bizum
☐ PayPal
☐ Transferencia
☐ Vale/Bono
☐ Otros
```

### 7️⃣ Configurar Usuarios/Empleados

```
"Configuración" → "Usuarios"

Para cada empleado:
- Nombre completo
- Email (opcional)
- Código PIN (4 dígitos)
- Permisos:
  * ☑️ Cobrar ventas
  * ☑️ Aplicar descuentos
  * ☑️ Hacer devoluciones
  * ☐ Cierre de caja (solo encargado)
  * ☐ Acceso a configuración (solo admin)

Al iniciar turno:
- Empleado introduce PIN
- Sistema registra ventas a su nombre
```

### 8️⃣ Importar Datos (Opcional)

```
Si vienes de otro TPV:

"Configuración" → "Importar/Exportar"

Opciones:
- Importar productos (CSV)
- Importar clientes (CSV/Excel)
- Importar histórico ventas (CSV)

Plantillas disponibles para descarga.
```

---

##  Solución de Problemas

### ❌ No se conecta la impresora Bluetooth

**Síntomas:**
- App no encuentra la impresora
- Se conecta pero no imprime
- Imprime caracteres extraños

**Soluciones:**

```
1️⃣ Verificar emparejamiento:
   - Ajustes → Bluetooth
   - Eliminar impresora
   - Emparejar de nuevo
   - PIN: 0000, 1234, o 1111

2️⃣ Reiniciar impresora:
   - Apagar y encender
   - Esperar 10 segundos
   - Volver a intentar

3️⃣ Comprobar batería:
   - Si es portátil, cargar completamente
   - Led verde = OK, rojo = batería baja

4️⃣ Comprobar papel:
   - Abrir tapa
   - Verificar que hay papel
   - Papel térmico instalado correctamente
   - Lado térmico (brillante) hacia arriba

5️⃣ En Android:
   - Permisos de app → Bluetooth activado
   - Permisos de localización (requerido)

6️⃣ Reinstalar:
   - Desinstalar PlaneaG TPV
   - Reinstalar desde Play Store
   - Volver a emparejar
```

### ❌ No aparecen productos al buscar

**Síntomas:**
- Catálogo vacío
- Productos creados no aparecen
- Búsqueda no funciona

**Soluciones:**

```
1️⃣ Verificar conexión:
   - Icono de conectividad en la app
   - WiFi/4G conectado
   - Recargar catálogo (pull down)

2️⃣ Filtros activos:
   - Comprobar si hay filtro de categoría
   - Botón "Ver todos"

3️⃣ Sincronización:
   - "Configuración" → "Sincronizar ahora"
   - Esperar 5-10 segundos

4️⃣ Productos inactivos:
   - Al crear producto, marcar "☑️ Activo"
   - Editar productos inactivos

5️⃣ Reiniciar app:
   - Cerrar app completamente
   - Volver a abrir
```

### ❌ Error al cobrar / No se guarda la venta

**Síntomas:**
- Click en "Cobrar" no hace nada
- Error "No se pudo procesar"
- Venta no aparece en histórico

**Soluciones:**

```
1️⃣ Verificar conexión Internet:
   - WiFi/4G activo
   - Probar navegar en browser

2️⃣ Modo offline:
   - Si no hay Internet, venta se guarda local
   - Al recuperar conexión, se sincroniza auto
   - Mensaje: "Sincronizando ventas pendientes"

3️⃣ Check de datos:
   - Total > 0€
   - Método de pago seleccionado
   - Cantidad recibida ≥ total (si efectivo)

4️⃣ Reiniciar sesión:
   - Cerrar sesión
   - Volver a iniciar

5️⃣ Actualizar app:
   - Play Store → Actualizar PlaneaG TPV
```

### ❌ Stock no se actualiza

**Síntomas:**
- Al vender, stock queda igual
- Stock negativo
- Diferencias entre app y realidad

**Soluciones:**

```
1️⃣ Activar control de stock:
   - "Productos" → Editar producto
   - ☑️ "Controlar stock"

2️⃣ Ajustar inventario:
   - "Productos" → Producto → "Ajustar stock"
   - Introducir cantidad real
   - Motivo: "Inventario físico"

3️⃣ Si vendes desde múltiples dispositivos:
   - Sincronizar todas las tablets
   - Stock se actualiza en tiempo real
   - WiFi debe estar activo

4️⃣ Check histórico:
   - "Productos" → Producto → "Movimientos"
   - Ver todas las entradas/salidas
```

### ❌ Cierre de caja no cuadra

**Síntomas:**
- Total en caja ≠ total del sistema
- Faltan ventas en el reporte
- Diferencia inexplicable

**Soluciones:**

```
1️⃣ Contar físicamente:
   - Efectivo en cajón
   - Tickets de tarjeta

2️⃣ Verificar período:
   - Cierre debe ser del turno actual
   - Check fecha/hora de inicio

3️⃣ Ventas sin sincronizar:
   - Si hubo caída de Internet, esperar sync
   - "Ver ventas pendientes"

4️⃣ Empleados:
   - Si varios usuarios, filtrar por empleado
   - Ver ventas individuales

5️⃣ Devoluciones:
   - Check si hubo devoluciones
   - Restar del total de ventas

6️⃣ Exportar informe:
   - Descargar Excel con detalle
   - Revisar línea por línea
```

### ❌ Olvidé mi contraseña

**Solución:**

```
1. Pantalla de login
2. Click "¿Olvidaste tu contraseña?"
3. Introducir email de la cuenta
4. Revisar email (puede tardar 1-2 min)
5. Click en enlace de recuperación
6. Crear nueva contraseña
7. Login con nueva clave
```

### ❌ App se cierra sola / Crash

**Soluciones:**

```
1️⃣ Actualizar app:
   - Play Store → PlaneaG TPV → Actualizar

2️⃣ Liberar memoria:
   - Cerrar otras apps
   - Reiniciar dispositivo

3️⃣ Limpiar caché:
   - Ajustes → Apps → PlaneaG TPV
   - "Limpiar caché" (NO "Borrar datos")

4️⃣ Reinstalar:
   - Desinstalar app
   - Reiniciar dispositivo
   - Instalar de nuevo
   - Login (datos se recuperan)

5️⃣ Contactar soporte:
   - Si persiste, enviar email a soporte@planeag.com
   - Indicar modelo de dispositivo y versión Android
```

---

## ‍ Capacitación del Personal

###  Formación Básica (30 minutos)

#### Para Empleados de Tienda

```
Módulo 1: Búsqueda de productos (5 min)
- Por nombre
- Por código de barras (escaneo)
- Por categoría

Módulo 2: Crear ticket (5 min)
- Añadir productos
- Editar cantidad
- Editar precio (si tiene permiso)
- Aplicar descuento

Módulo 3: Cobrar (5 min)
- Efectivo (calcular cambio)
- Tarjeta
- Pago mixto

Módulo 4: Devoluciones (5 min)
- Buscar ticket
- Seleccionar producto
- Motivo de devolución
- Generar abono

Módulo 5: Consultas rápidas (5 min)
- Ver stock de producto
- Buscar cliente
- Reimprimir ticket

Módulo 6: Cierre de caja (5 min)
- Cuándo hacerlo
- Contar efectivo
- Imprimir Z Report
```

#### Para Personal de Bar/Restaurante

```
Módulo 1: Mesas (10 min)
- Ver plano
- Estados de mesas
- Abrir mesa
- Cambiar estado

Módulo 2: Tomar comanda (10 min)
- Buscar productos
- Variantes (tamaños, extras)
- Añadir notas
- Enviar a cocina

Módulo 3: Gestión de comandas (5 min)
- Ver comanda abierta
- Añadir más productos
- Dividir cuenta
- Transferir mesa

Módulo 4: Cobrar (5 min)
- Cobro total
- Cobro parcial
- Efectivo vs Tarjeta
- Cerrar mesa
```

#### Para Personal de Peluquería

```
Módulo 1: Agenda y profesionales (10 min)
- Ver disponibilidad
- Navegar por días
- Estados de citas
- Profesionales activos

Módulo 2: Crear cita (10 min)
- Buscar cliente
- Seleccionar profesional
- Elegir servicios
- Asignar hora y duración

Módulo 3: Atender cliente (10 min)
- Marcar cita como "En curso"
- Asignar cabina
- Completar servicios
- Marcar como completada

Módulo 4: Cobrar y comisiones (5 min)
- Cobrar servicios
- Aplicar bonos
- Añadir propina
- Ver comisión del profesional

Módulo 5: Walk-ins (5 min)
- Añadir a cola
- Asignar cuando hay hueco
- Notificar cliente

Módulo 6: Gestión de bonos (5 min)
- Vender bono
- Aplicar bono en cobro
- Ver sesiones restantes
```

###  Manual de Usuario (PDF)

```
Crear documento interno con:
- Capturas de pantalla
- Flujos paso a paso
- Números de contacto
- FAQs específicas del negocio
- Políticas de devolución
- Códigos de empleado
```

**Descargar plantilla:** 
`https://planeag.com/recursos/manual-tpv-empleados.pdf`

###  Formación Avanzada (Opcional)

```
Para encargados/gerentes:

- Gestión de inventario
- Configuración de productos
- Gestión de usuarios
- Informes y estadísticas
- Exportación de datos
- Integración con contabilidad
- Backup y seguridad
```

---

##  Seguridad y Backup

### ️ Buenas Prácticas

```
✅ Contraseñas seguras (8+ caracteres, mayúsculas, números)
✅ Cambiar contraseña cada 3-6 meses
✅ No compartir credenciales entre empleados
✅ Usar PINs de 4 dígitos para empleados
✅ Cerrar sesión al dejar dispositivo desatendido
✅ Mantener app actualizada
✅ Activar autenticación en dos pasos (2FA)
✅ No conectar a WiFi públicas para cobrar
```

###  Backup Automático

```
PlaneaG realiza backup automático en la nube:
- Cada venta → Guardada en Firebase
- Cada cambio de stock → Sincronizado
- Cada modificación de catálogo → Replicada

No necesitas hacer backup manual.

Si cambias de dispositivo:
1. Instalar PlaneaG TPV en nuevo dispositivo
2. Login con mismas credenciales
3. Todos los datos se descargan automáticamente
```

###  Exportar Datos Localmente

```
Para tener copia adicional:

1. "Configuración" → "Exportar datos"
2. Seleccionar período:
   - Último mes
   - Último trimestre
   - Todo el histórico
3. Formato:
   - CSV (Excel)
   - PDF
   - JSON (avanzado)
4. Enviar por email o descargar
5. Guardar en carpeta segura
```

---

##  Soporte y Contacto

###  Canales de Soporte

```
 Email: soporte@planeag.com
   Respuesta: 24-48h

 Chat en vivo: https://planeag.com/chat
   Horario: L-V 9:00-19:00

 Teléfono: +34 912 345 678
   Horario: L-V 9:00-14:00 y 16:00-19:00

 Centro de ayuda: https://ayuda.planeag.com
   FAQs, tutoriales, vídeos

 YouTube: @PlaneaGTPV
   Video-tutoriales paso a paso
```

###  Onboarding Personalizado

```
Para negocios que contraten plan Premium o Enterprise:

✅ Llamada de bienvenida (30 min)
✅ Sesión de formación online (1h)
✅ Configuración asistida
✅ Importación de datos guiada
✅ Soporte prioritario 24/7
✅ Gestor de cuenta dedicado

Contactar: comercial@planeag.com
```

---

##  Planes y Precios

###  Comparativa de Planes

```
┌─────────────────┬──────────┬───────────┬─────────────┐
│                 │  BÁSICO  │  PRO      │  ENTERPRISE │
├─────────────────┼──────────┼───────────┼─────────────┤
│ Precio/mes      │ 29€      │ 79€       │ 149€        │
│ Dispositivos    │ 1        │ 5         │ Ilimitado   │
│ Usuarios        │ 2        │ 10        │ Ilimitado   │
│ Productos       │ 500      │ Ilimitados│ Ilimitados  │
│ Tickets/mes     │ 1.000    │ Ilimitados│ Ilimitados  │
│ Soporte         │ Email    │ Email+Chat│ 24/7 + Tfno │
│ Facturación     │ ✅       │ ✅        │ ✅          │
│ Informes        │ Básicos  │ Avanzados │ Personalizad│
│ Multi-empresa   │ ❌       │ ❌        │ ✅          │
│ API             │ ❌       │ ❌        │ ✅          │
│ Formación       │ ❌       │ Online 1h │ Presencial  │
└─────────────────┴──────────┴───────────┴─────────────┘
```

**Primer mes GRATIS** en todos los planes.
**Sin permanencia** - Cancela cuando quieras.

---

## ✅ Checklist de Instalación

### Para Tienda

```
☐ Dispositivo adquirido y cargado
☐ PlaneaG TPV instalado
☐ Cuenta creada y verificada
☐ Datos de empresa configurados
☐ Tipo TPV: Tienda seleccionado
☐ Catálogo de productos importado/creado
☐ Categorías configuradas
☐ Precios e IVA establecidos
☐ Stock inicial cargado
☐ Impresora conectada y probada
☐ Lector de códigos (opcional) conectado
☐ Métodos de pago activados
☐ Usuarios/empleados creados
☐ Primera venta de prueba realizada
☐ Devolución de prueba realizada
☐ Cierre de caja de prueba realizado
☐ Personal formado
☐ Manual de usuario creado
☐ Soporte de Planeag contactado (si dudas)
```

### Para Bar/Restaurante

```
☐ Dispositivo(s) adquiridos y cargados
☐ PlaneaG TPV instalado en todos los dispositivos
☐ Cuenta creada y verificada
☐ Datos de empresa configurados
☐ Tipo TPV: Bar/Restaurante seleccionado
☐ Plano de mesas creado (todas las zonas)
☐ Catálogo de productos y bebidas creado
☐ Variantes configuradas (tamaños, extras)
☐ Categorías (Comidas, Bebidas, Tapas...) creadas
☐ Impresoras conectadas (caja, cocina, barra)
☐ Filtros de impresión por categoría configurados
☐ Red WiFi estable verificada
☐ Métodos de pago activados
☐ Usuarios/camareros creados con PINs
☐ Prueba de comanda completa (abrir mesa → cobrar)
☐ Prueba de dividir cuenta
☐ Prueba de transferir mesa
☐ Prueba de caja rápida (take away)
☐ Personal formado
☐ Soporte de PlaneaG contactado (si dudas)
```

### Para Peluquería

```
☐ Dispositivo adquirido y cargado
☐ PlaneaG TPV instalado
☐ Cuenta creada y verificada
☐ Datos de empresa configurados
☐ Tipo TPV: Peluquería/Salón seleccionado
☐ Profesionales creados (nombre, horarios, comisión)
☐ Colores de agenda asignados
☐ Servicios creados (nombre, precio, duración)
☐ Categorías de servicios (Corte, Color, Manicura...)
☐ Cabinas/salas creadas (opcional)
☐ Impresora conectada y probada
☐ Métodos de pago activados
☐ Sistema de bonos configurado (si aplica)
☐ Usuarios/recepcionistas creados
☐ Prueba de cita completa (crear → atender → cobrar)
☐ Prueba de walk-in
☐ Prueba de cálculo de comisiones
☐ Cierre de caja con comisiones probado
☐ Personal formado
☐ Soporte de PlaneaG contactado (si dudas)
```

---

##  ¡Listo para Empezar!

###  Próximos Pasos

1. **Día 1-2:** Instalación y configuración básica
2. **Día 3-5:** Carga de productos/servicios y pruebas
3. **Día 6-7:** Formación del personal
4. **Día 8:** Ventas de prueba con clientes reales (modo piloto)
5. **Día 9+:** Operación normal

###  Optimización Continua

```
Semana 1: ✅ Operación básica funcionando
Semana 2: Review de ventas, ajustar catálogo
Semana 3: Configurar informes personalizados
Mes 2: Análisis de rentabilidad, best sellers
Mes 3: Integración con contabilidad (opcional)
```

###  Consejos Finales

```
✅ Empieza simple, no todo a la vez
✅ Forma bien a tu equipo
✅ Revisa los informes semanalmente
✅ Mantén el catálogo actualizado
✅ Escucha feedback de empleados
✅ Aprovecha el soporte de PlaneaG
✅ Actualiza la app regularmente
```

---

##  Recursos Adicionales

###  Descargas

```
 PlaneaG TPV para Android
https://play.google.com/store/apps/details?id=com.planeag.tpv

 PlaneaG TPV para Windows
https://planeag.com/descargas/windows

 Manual de Usuario (PDF)
https://planeag.com/recursos/manual-completo.pdf

 Plantilla CSV Productos
https://planeag.com/recursos/plantilla-productos.csv

 Plantilla CSV Clientes
https://planeag.com/recursos/plantilla-clientes.csv
```

###  Video Tutoriales

```
 Instalación y Configuración Inicial (15 min)
https://youtube.com/watch?v=xxxxx

 TPV Tienda - Caso Práctico Completo (20 min)
https://youtube.com/watch?v=xxxxx

 TPV Bar - Gestión de Mesas y Comandas (25 min)
https://youtube.com/watch?v=xxxxx

 TPV Peluquería - Agenda y Citas (30 min)
https://youtube.com/watch?v=xxxxx

 Conectar Impresora Bluetooth (10 min)
https://youtube.com/watch?v=xxxxx

 Cierre de Caja Paso a Paso (12 min)
https://youtube.com/watch?v=xxxxx
```

###  Documentación Técnica

```
 API Documentation (para desarrolladores)
https://docs.planeag.com/api

 Integraciones (Contabilidad, E-commerce)
https://docs.planeag.com/integraciones

 Changelog (Novedades y actualizaciones)
https://planeag.com/changelog
```

---

**Documento creado por:** Equipo PlaneaG  
**Última actualización:** Mayo 2026  
**Versión:** 1.0.0

---

© 2026 PlaneaG - Todos los derechos reservados  
 info@planeag.com |  www.planeag.com | ☎️ +34 912 345 678
