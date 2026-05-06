# 🛍️ Guía Completa: Integración Tienda Online con Stripe Connect

## 📋 Índice

1. [Resumen del Sistema](#resumen-del-sistema)
2. [Requisitos Previos](#requisitos-previos)
3. [Configuración Inicial](#configuración-inicial)
4. [Implementación Paso a Paso](#implementación-paso-a-paso)
5. [Uso por Empresa](#uso-por-empresa)
6. [Webhooks y Notificaciones](#webhooks-y-notificaciones)
7. [Gestión de Productos](#gestión-de-productos)
8. [Generación Automática de Facturas](#generación-automática-de-facturas)
9. [Estadísticas de Tienda](#estadísticas-de-tienda)
10. [Troubleshooting](#troubleshooting)

---

## 🎯 Resumen del Sistema

Este sistema permite que cada empresa conecte su propia cuenta de Stripe y gestione su tienda online:

### ✅ Funcionalidades Implementadas

- **Stripe Connect OAuth**: Cada empresa conecta su cuenta de Stripe de forma segura
- **Productos con precios dinámicos**: Cambiar precios desde la app sin tocar código
- **Sincronización automática**: Productos se sincronizan con Stripe al crear/editar
- **Recepción de pedidos**: Webhooks reciben pagos en tiempo real
- **Facturas automáticas**: Se genera factura al recibir pago
- **Notificaciones push**: Aviso instantáneo al llegar pedido
- **Estadísticas completas**: Productos más vendidos, rentables, ingresos, etc.
- **Gestión de stock**: Descuenta automáticamente al vender

---

## 📋 Requisitos Previos

### 1. Cuenta Stripe Platform

1. Ir a [https://dashboard.stripe.com](https://dashboard.stripe.com)
2. Crear cuenta (o usar existente)
3. Ir a `Settings` → `Connect` → `Get Started`
4. Completar información de tu plataforma (nombre,URL, etc.)
5. Obtener **Client ID** (ca_xxx...)
6. Crear **Webhook Secret** para recibir eventos

### 2. Configurar Firebase

```bash
# Instalar Firebase CLI si no la tienes
npm install -g firebase-tools

# Login
firebase login

# Configurar secretos de Stripe
firebase functions:config:set \
  stripe.secret_key="sk_live_xxxxx" \
  stripe.connect_secret="ca_xxxxx" \
  stripe.webhook_secret="whsec_xxxxx"
```

### 3. Dependencias Flutter

Ya están agregadas en `pubspec.yaml`:
```yaml
dependencies:
  url_launcher: ^6.3.1  # Para abrir OAuth
  # ...resto de dependencias
```

---

## 🛠️ Configuración Inicial

### Paso 1: Actualizar Constantes

**Archivo:** `lib/services/stripe_service.dart`

```dart
class StripeService {
  // TODO: Reemplazar con tus valores reales
  static const String stripeConnectClientId = 'ca_TU_CLIENT_ID_AQUI';
  static const String redirectUri = 'https://TUDOMINIO.com/stripe/callback';
  // ...
}
```

### Paso 2: Desplegar Cloud Functions

```bash
cd functions
npm install stripe
npm run build
firebase deploy --only functions
```

Esto desplegará:
- `stripeOAuthCallback` - Maneja la conexión OAuth
- `stripeWebhook` - Recibe eventos de Stripe
- `onProductoTiendaWrite` - Sincroniza productos con Stripe

### Paso 3: Configurar Webhook en Stripe

1. Ir a [Stripe Dashboard](https://dashboard.stripe.com)
2. `Developers` → `Webhooks` → `Add Endpoint`
3. URL: `https://REGION-PROYECTO.cloudfunctions.net/stripeWebhook`
4. Seleccionar eventos:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `charge.refunded`
5. Copiar **Signing Secret** (whsec_...)
6. Actualizar config de Firebase: 
   ```bash
   firebase functions:config:set stripe.webhook_secret="whsec_xxxxx"
   ```

### Paso 4: Desplegar Reglas de Firestore

```bash
firebase deploy --only firestore:rules
```

---

## 🚀 Implementación Paso a Paso

### Fase 1: Pantalla de Integraciones

**Archivo:** `lib/features/configuracion/pantallas/integraciones_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/stripe_service.dart';

class IntegracionesScreen extends StatefulWidget {
  final String empresaId;
  
  const IntegracionesScreen({Key? key,required this.empresaId}) : super(key: key);

  @override
  State<IntegracionesScreen> createState() => _IntegracionesScreenState();
}

class _IntegracionesScreenState extends State<IntegracionesScreen> {
  final _stripeService = StripeService();
  bool _cargando = true;
  bool _stripeConectado = false;

  @override
  void initState() {
    super.initState();
    _verificarConexion();
  }

  Future<void> _verificarConexion() async {
    final conectado = await _stripeService.tieneStripeConectado(widget.empresaId);
    setState(() {
      _stripeConectado = conectado;
      _cargando = false;
    });
  }

  Future<void> _conectarStripe() async {
    final url = _stripeService.construirUrlOAuth(widget.empresaId);
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      
      // Mostrar diálogo mientras conecta
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible:false,
          builder: (ctx) => AlertDialog(
            title: const Text('Conectando con Stripe'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Completa el proceso en el navegador...'),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _desconectarStripe() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar Stripe'),
        content: const Text('¿Estás seguro? No podrás recibir más pedidos online.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _stripeService.desconectarStripe(widget.empresaId);
      _verificarConexion();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Integraciones'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TarjetaIntegracion(
            icono: Icons.storefront,
            titulo: 'Tienda Online (Stripe)',
            descripcion: _stripeConectado
                ? 'Conectado - Recibiendo pedidos online'
                : 'Conecta tu cuenta de Stripe para vender online',
            conectado: _stripeConectado,
            onConectar: _conectarStripe,
            onDesconectar: _desconectarStripe,
          ),
          const SizedBox(height: 16),
          _TarjetaIntegracion(
            icono: Icons.star,
            titulo: 'Google Reviews',
            descripcion: 'Gestiona las valoraciones de tu negocio',
            conectado: true, // Ya implementado
          ),
          const SizedBox(height: 16),
          _TarjetaIntegracion(
            icono: Icons.calendar_today,
            titulo: 'Reservas Online',
            descripcion: 'Formulario web de reservas',
            conectado: true, // Ya implementado
          ),
        ],
      ),
    );
  }
}

class _TarjetaIntegracion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final bool conectado;
  final VoidCallback? onConectar;
  final VoidCallback? onDesconectar;

  const _TarjetaIntegracion({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.conectado,
    this.onConectar,
    this.onDesconectar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: conectado ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icono,
                size: 32,
                color: conectado ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (onConectar != null || onDesconectar != null)
              Column(
                children: [
                  if (conectado)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Activo',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (!conectado && onConectar != null)
                    ElevatedButton(
                      onPressed: onConectar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B1FA2),
                      ),
                      child: const Text('Conectar'),
                    )
                  else if (conectado && onDesconectar != null)
                    OutlinedButton(
                      onPressed: onDesconectar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Desconectar'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
```

### Fase 2: Gestión de Productos

**Archivo:** `lib/features/tienda/pantallas/productos_tienda_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/stripe_service.dart';
import '../../../domain/modelos/producto_tienda.dart';

class ProductosTiendaScreen extends StatefulWidget {
  final String empresaId;

  const ProductosTiendaScreen({Key? key, required this.empresaId}) : super(key: key);

  @override
  State<ProductosTiendaScreen> createState() => _ProductosTiendaScreenState();
}

class _ProductosTiendaScreenState extends State<ProductosTiendaScreen> {
  final _stripeService = StripeService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos de Tienda'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stripeService.obtenerProductos(widget.empresaId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final productos = snapshot.data!.docs
              .map((doc) => ProductoTienda.fromFirestore(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ))
              .toList();

          if (productos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay productos en tu tienda',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text('Pulsa + para agregar el primero'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final producto = productos[index];
              return _TarjetaProducto(
                producto: producto,
                onEditar: () => _editarProducto(producto),
                onCambiarPrecio: () => _cambiarPrecio(producto),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoProducto,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Producto'),
        backgroundColor: const Color(0xFF7B1FA2),
      ),
    );
  }

  Future<void> _nuevoProducto() async {
    await showDialog(
      context: context,
      builder: (_) => _FormularioProducto(
        empresaId: widget.empresaId,
        stripeService: _stripeService,
      ),
    );
  }

  Future<void> _editarProducto(ProductoTienda producto) async {
    await showDialog(
      context: context,
      builder: (_) => _FormularioProducto(
        empresaId: widget.empresaId,
        stripeService: _stripeService,
        producto: producto,
      ),
    );
  }

  Future<void> _cambiarPrecio(ProductoTienda producto) async {
    final controller = TextEditingController(text: producto.precio.toString());

    final nuevoPrecio = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar Precio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(producto.nombre),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Nuevo precio (€)',
                prefixIcon: Icon(Icons.euro),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final precio = double.tryParse(controller.text);
              if (precio != null && precio > 0) {
                Navigator.pop(ctx, precio);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (nuevoPrecio != null) {
      await _stripeService.actualizarPrecioProducto(
        widget.empresaId,
        producto.id,
        nuevoPrecio,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Precio actualizado y sincronizado con Stripe'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

class _TarjetaProducto extends StatelessWidget {
  final ProductoTienda producto;
  final VoidCallback onEditar;
  final VoidCallback onCambiarPrecio;

  const _TarjetaProducto({
    required this.producto,
    required this.onEditar,
    required this.onCambiarPrecio,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: producto.imagenUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  producto.imagenUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_bag, color: Colors.grey),
              ),
        title: Text(
          producto.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (producto.descripcion.isNotEmpty)
              Text(
                producto.descripcion,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (producto.gestionarStock)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: producto.stock! > 0
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Stock: ${producto.stock}',
                      style: TextStyle(
                        fontSize: 11,
                        color: producto.stock! > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                if (!producto.activo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Inactivo',
                      style: TextStyle(fontSize: 11, color: Colors.red),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '€${producto.precio.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B1FA2),
                  ),
                ),
                TextButton(
                  onPressed: onCambiarPrecio,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Cambiar precio',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEditar,
            ),
          ],
        ),
      ),
    );
  }
}

// Formulario para crear/editar producto
class _FormularioProducto extends StatefulWidget {
  final String empresaId;
  final StripeService stripeService;
  final ProductoTienda? producto;

  const _FormularioProducto({
    required this.empresaId,
    required this.stripeService,
    this.producto,
  });

  @override
  State<_FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<_FormularioProducto> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _descripcionCtrl;
  late TextEditingController _precioCtrl;
  late TextEditingController _stockCtrl;
  bool _gestionarStock = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.producto?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: widget.producto?.descripcion ?? '');
    _precioCtrl = TextEditingController(text: widget.producto?.precio.toString() ?? '');
    _stockCtrl = TextEditingController(text: widget.producto?.stock?.toString() ?? '0');
    _gestionarStock = widget.producto?.gestionarStock ?? false;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final datos = {
        'nombre': _nombreCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'precio': double.parse(_precioCtrl.text.trim()),
        'gestionar_stock': _gestionarStock,
        'stock': _gestionarStock ? int.parse(_stockCtrl.text.trim()) : null,
        'activo': true,
        'requiere_sync_stripe': true, // Trigger para Cloud Function
      };

      if (widget.producto == null) {
        // Crear nuevo
        await widget.stripeService.crearProducto(widget.empresaId, datos);
      } else {
        // Actualizar existente
        await widget.stripeService.sincronizarProducto(
          widget.empresaId,
          widget.producto!.id,
          datos,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.producto == null
                  ? '✅ Producto creado y sincronizado con Stripe'
                  : '✅ Producto actualizado',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.producto == null ? 'Nuevo Producto' : 'Editar Producto',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto *',
                    prefixIcon: Icon(Icons.shopping_bag),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _precioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio (€) *',
                    prefixIcon: Icon(Icons.euro),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Obligatorio';
                    final precio = double.tryParse(v);
                    if (precio == null || precio <= 0) return 'Precio inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Gestionar stock'),
                  subtitle: const Text('Controlar unidades disponibles'),
                  value: _gestionarStock,
                  onChanged: (v) => setState(() => _gestionarStock = v),
                ),
                if (_gestionarStock) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _stockCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad en stock',
                      prefixIcon: Icon(Icons.inventory),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (!_gestionarStock) return null;
                      if (v == null || v.isEmpty) return 'Obligatorio';
                      final stock = int.tryParse(v);
                      if (stock == null || stock < 0) return 'Stock inválido';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _guardando ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B1FA2),
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.producto == null ? 'Crear' : 'Guardar',
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 🔔 Webhooks y Notificaciones

### Configurar Notificaciones Push

Las notificaciones se envían automáticamente cuando llega un pedido. El sistema:

1. ✅ Recibe webhook de Stripe
2. ✅ Crea pedido en Firestore
3. ✅ Genera factura automática
4. ✅ Envía push a todos los dispositivos de la empresa
5. ✅ Actualiza estadísticas

**Formato de notificación:**

```
Título: 🛒 Nuevo pedido online
Cuerpo: María García - €45.99
Datos: {
  tipo: 'nuevo_pedido_tienda',
  pedido_id: 'abc123',
  empresa_id: 'xyz789',
  monto: '45.99'
}
```

### Manejar Notificación en la App

**Archivo:** `lib/features/dashboard/pantallas/pantalla_dashboard.dart`

Agregar al método `_manejarNavegacionNotificacion`:

```dart
void _manejarNavegacionNotificacion(Map<String, dynamic> data) {
  // ... código existente ...
  
  // Nuevo pedido de tienda
  if (data['tipo'] == 'nuevo_pedido_tienda') {
    final pedidoId = data['pedido_id'];
    if (pedidoId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetallePedidoTiendaScreen(
            empresaId: _sesion!.empresaId,
            pedidoId: pedidoId,
          ),
        ),
      );
    }
    return;
  }
}
```

---

## 📊 Estadísticas de Tienda

Las estadísticas se calculan automáticamente cada hora e incluyen:

### Métricas Disponibles

```dart
{
  'tienda_online_activa': true,
  'pedidos_tienda_mes': 45,
  'pedidos_tienda_30dias': 52,
  'ingresos_tienda_mes': 2345.50,
  'ingresos_tienda_30dias': 2890.00,
  'ticket_promedio_tienda': 52.12,
  'producto_mas_vendido': 'Curso Flutter Avanzado',
  'producto_mas_rentable': 'Consultoría Premium',
  'productos_vendidos_cantidad': {
    'prod_001': 28,
    'prod_002': 15,
  },
  'productos_ingresos': {
    'prod_001': 1120.00,
    'prod_002': 895.50,
  },
  'pedidos_pagados': 43,
  'pedidos_enviados': 38,
  'pedidos_completados': 35,
}
```

### Mostrar en Dashboard

**Archivo:** Dashboard o nueva pantalla de estadísticas de tienda

```dart
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
    .collection('empresas')
    .doc(empresaId)
    .collection('estadisticas')
    .doc('resumen')
    .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    
    final stats = snapshot.data!.data() as Map<String, dynamic>;
    final tiendaActiva = stats['tienda_online_activa'] ?? false;
    
    if (!tiendaActiva) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Conecta Stripe para ver estadísticas de tienda'),
        ),
      );
    }
    
    return Column(
      children: [
        _MetricaCard(
          titulo: 'Ingresos Tienda (mes)',
          valor: '€${stats['ingresos_tienda_mes']?.toStringAsFixed(2) ?? '0.00'}',
          icono: Icons.shopping_cart,
          color: Colors.green,
        ),
        _MetricaCard(
          titulo: 'Pedidos (mes)',
          valor: '${stats['pedidos_tienda_mes'] ?? 0}',
          icono: Icons.receipt,
          color: Colors.blue,
        ),
        _MetricaCard(
          titulo: 'Producto Más Vendido',
          valor: stats['producto_mas_vendido'] ?? 'N/A',
          icono: Icons.trending_up,
          color: Colors.orange,
        ),
        _MetricaCard(
          titulo: 'Ticket Promedio',
          valor: '€${stats['ticket_promedio_tienda']?.toStringAsFixed(2) ?? '0.00'}',
          icono: Icons.euro,
          color: Colors.purple,
        ),
      ],
    );
  },
)
```

---

## 💡 Uso por Empresa (Guía para Empresarios)

### 1. Conectar Stripe (Primera vez)

1. Ir a `Configuración` → `Integraciones`
2. Pulsar `Conectar` en "Tienda Online (Stripe)"
3. Se abrirá navegador con formulario de Stripe
4. Completar datos de la empresa:
   - Nombre del negocio
   - CIF/NIF
   - Dirección
   - Datos bancarios (para recibir pagos)
5. Aceptar términos y condiciones
6. Volver a la app - ¡Listo!

### 2. Agregar Productos

1. Ir a `Tienda` → `Productos`
2. Pulsar botón `+ Nuevo Producto`
3. Completar formulario:
   - **Nombre**: Ej. "Curso de Marketing Digital"
   - **Descripción**: Ej. "Aprende marketing en 30 días"
   - **Precio**: Ej. 99.00
   - **Gestionar stock**: Activar si quieres control de inventario
   - **Cantidad**: Ej. 50 unidades
4. Pulsar `Crear`
5. El producto se sincroniza automáticamente con Stripe

### 3. Cambiar Precio de Producto

1. Ir a `Tienda` → `Productos`
2. Buscar el producto
3. Pulsar `Cambiar precio` (debajo del precio actual)
4. Introducir nuevo precio: Ej. 79.00
5. Pulsar `Guardar`
6. El cambio se sincroniza automáticamente con Stripe
7. **Importante**: Los clientes que ya compraron pagan el precio anterior

### 4. Recibir Pedidos

Cuando un cliente compra desde tu web:

1. ✅ Recibes **notificación push** en tu teléfono
2. ✅ Se crea **pedido** en sección Pedidos
3. ✅ Se genera **factura** automáticamente
4. ✅ Se descuenta **stock** (si está activado)
5. ✅ Aparece en **estadísticas**

### 5. Ver Pedidos

1. Ir a `Pedidos`
2. Filtrar por `Origen: Tienda Online`
3. Ver detalles:
   - Cliente (nombre, email, teléfono)
   - Productos comprados
   - Monto total
   - Factura asociada
   - Estado del pedido

### 6. Gestionar Pedido

Estados disponibles:
- **Pagado**: Pago confirmado por Stripe
- **Enviado**: Marcas que enviaste el producto
- **Completado**: Cliente recibió el producto
- **Reembolsado**: Devolviste el dinero

Para cambiar estado:
1. Abrir detalle del pedido
2. Seleccionar nuevo estado
3. Guardar

### 7. Ver Estadísticas

1. Ir a `Dashboard` → `Estadísticas de Tienda`
2. Ver métricas:
   - Ingresos del mes
   - Número de pedidos
   - Producto más vendido
   - Producto más rentable
   - Ticket promedio
   - Gráficas de ventas

---

## 🔧 Troubleshooting

### Problema: "No se sincroniza con Stripe"

**Solución:**
1. Verificar que Stripe está conectado: `Integraciones` → Ver estado
2. Comprobar logs de Cloud Functions:
   ```bash
   firebase functions:log
   ```
3. Verificar que `requiere_sync_stripe: true` está en el producto

### Problema: "No llegan notificaciones de pedidos"

**Solución:**
1. Verificar que webhooks están configurados en Stripe Dashboard
2. URL correcta: `https://REGION-PROYECTO.cloudfunctions.net/stripeWebhook`
3. Eventos seleccionados: ` payment_intent.succeeded`
4. Probar webhook desde Stripe Dashboard → `Send test webhook`

### Problema: "No se genera factura automática"

**Solución:**
1. Verificar que la empresa tiene `ultimo_numero_factura` en Firestore
2. Si no existe, crear manualmente:
   ```javascript
   db.collection('empresas').doc('EMPRESA_ID').update({
     ultimo_numero_factura: 0
   });
   ```

### Problema: "Stock no se descuenta"

**Solución:**
1. Verificar que producto tiene `gestionar_stock: true`
2. Verificar que `stock` es un número
3. Revisar logs de Cloud Function `procesarPagoExitoso`

---

## 📝 Checklist de Despliegue

- [ ] Crear cuenta Stripe Platform
- [ ] Obtener Client ID y secretos
- [ ] Configurar Firebase Functions config
- [ ] Desplegar Cloud Functions
- [ ] Configurar Webhook en Stripe
- [ ] Actualizar `stripe_service.dart` con valores reales
- [ ] Desplegar Firestore Rules
- [ ] Crear pantalla de integraciones
- [ ] Crear pantalla de productos
- [ ] Probar conexión OAuth
- [ ] Probar creación de producto
- [ ] Probar cambio de precio
- [ ] Enviar pago de prueba desde Stripe Testing
- [ ] Verificar notificación push
- [ ] Verificar factura generada
- [ ] Verificar estadísticas actualizadas

---

## 🎓 Recursos Adicionales

- [Stripe Connect Docs](https://stripe.com/docs/connect)
- [Stripe Webhooks](https://stripe.com/docs/webhooks)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [Flutter URL Launcher](https://pub.dev/packages/url_launcher)

---

**Fecha:** 06 de mayo de 2026  
**Versión:** 1.0  
**Estado:** ✅ Implementación Completa

