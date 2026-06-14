# Guía: Conectar impresora y cajón registradora

## Requisitos de hardware

| Componente | Requerimiento |
|-----------|--------------|
| Impresora térmica | Compatible ESC/POS con puerto "DK" o "Cash Drawer" en la parte trasera |
| Cajón registradora | Cable RJ-11 o RJ-12 (el mismo conector que los teléfonos fijos) |
| PC | Windows 10/11 con Bluetooth o USB |

La impresora compatible más común en España: **Epson TM-T20III**, **Epson TM-T88VI**, **Star TSP143**.

---

## Paso 1 — Conectar el cajón a la impresora

El cajón **no se conecta al PC directamente**. Se conecta a la impresora:

1. Coge el cable RJ-11/RJ-12 del cajón (parece un cable de teléfono)
2. Conéctalo al puerto trasero de la impresora marcado como **"DK"**, **"Cash Drawer"** o con un icono de cajón
3. Enciende la impresora
4. El cajón se alimenta eléctricamente desde la impresora — no necesita cable de corriente propio

```
[PC Windows]
     │
     │ Bluetooth o USB
     ↓
[Impresora térmica]  ◄── RJ-11/RJ-12 ──► [Cajón registradora]
     └── Puerto "DK" en la parte trasera
```

---

## Paso 2 — Conectar la impresora al PC (Bluetooth)

1. Enciende la impresora
2. En Windows: **Configuración → Bluetooth y dispositivos → Agregar dispositivo**
3. Selecciona la impresora (ej: "TM-T20III" o "Epson_T20")
4. Una vez emparejada, abre el **Administrador de dispositivos** (`Win + X → Administrador de dispositivos`)
5. Despliega **Puertos (COM y LPT)**
6. Busca algo como "Bluetooth Serial Port" o "Standard Serial over Bluetooth link"
7. Anota el número de puerto: ej **COM5**

> Si tienes dos puertos "Bluetooth Serial Port", usa el de número más bajo.

---

## Paso 2 (alternativa) — Conectar la impresora por USB

1. Conecta el cable USB de la impresora al PC
2. Windows instalará el driver automáticamente
3. Abre el **Administrador de dispositivos → Puertos (COM y LPT)**
4. Busca "USB Serial Port" o el nombre del fabricante
5. Anota el número de puerto: ej **COM3**

---

## Paso 2 (alternativa) — Impresora de red WiFi/Ethernet

Para modelos como Epson TM-T88VI con módulo de red:
1. Conecta la impresora a tu red WiFi o mediante cable de red
2. En Windows, abre la herramienta de configuración del fabricante para encontrar la IP (ej: `192.168.1.50`)
3. En la aplicación, usa el modo **"Red WiFi"** con esa IP y puerto `9100`

---

## Paso 3 — Configurar la impresora en la app

1. Abre el TPV y ve a **Configuración → Hardware**
2. Si la impresora es **Bluetooth/USB**: selecciona la pestaña `Bluetooth / USB`
   - Escribe el puerto COM anotado (ej: `COM5`) y pulsa **Guardar**
   - O pulsa **Auto-detectar** para que la app pruebe COM1 hasta COM20 automáticamente
3. Si la impresora es de **red WiFi**: selecciona la pestaña `Red (WiFi)`
   - Escribe la IP (ej: `192.168.1.50`) y el puerto (`9100`)
   - Pulsa **Guardar**

El indicador se pondrá en **verde** cuando la conexión sea correcta.

---

## Paso 4 — Configurar el cajón en la app

1. En **Configuración → Hardware → 🗄️ Cajón registradora**:
   - Activa **"Abrir cajón al cobrar"**
   - Opcional: **"Solo en pagos en efectivo"** (no abrirá con tarjeta/Bizum)
   - **Pin**: deja en "Pin 2 (estándar)" — funciona con el 99% de los cajones genéricos. Cambia a "Pin 5" solo si el cajón no abre con Pin 2.
2. Guarda la configuración

---

## Abrir el cajón manualmente

Hay dos formas de abrir el cajón desde la app sin necesidad de cobrar:

### Desde el cierre de caja
En la pantalla de **Cierre de caja**, en la barra superior hay un botón con el icono 📦 (**Abrir cajón**). Púlsalo para enviarlo al cajón en cualquier momento.

### Desde cobrar
Si tienes activado "Abrir cajón al cobrar", el cajón se abre automáticamente cada vez que confirmas un cobro (en efectivo, si tienes la opción de solo-efectivo activada).

---

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---------|---------------|----------|
| El cajón no abre al cobrar | Puerto COM no configurado | Ve a Config → Hardware y configura el COM |
| El cajón no abre con el botón manual | Impresora apagada o desconectada | Enciende la impresora y reconecta |
| Auto-detectar no encuentra la impresora | Bluetooth no emparejado | Empareja la impresora en Windows primero, luego auto-detecta |
| Cajón abre en Pin 2 pero no responde | Modelo antiguo con Pin 5 | Cambia a "Pin 5" en Config → Hardware |
| Impresora de red no responde | IP incorrecta o firewall | Verifica que estén en la misma red WiFi |

---

## Resumen del comando que se envía al cajón

La impresora recibe el comando ESC/POS estándar y lo transmite al cajón vía el puerto DK:

```
ESC p  →  1B 70 00 19 FA   (Pin 2, estándar)
ESC p  →  1B 70 01 19 FA   (Pin 5, alternativo)
```

Este comando es compatible con Epson, Star, Bixolon, SNBC y cualquier impresora que declare compatibilidad ESC/POS.
