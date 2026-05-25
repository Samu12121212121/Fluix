# 📊 ANÁLISIS DE EXPANSIÓN: B2C + Desktop + Comparativa WheelUp

> **Fecha**: 7 Mayo 2026  
> **Autor**: Análisis técnico FluixCRM  
> **Objetivo**: Evaluar la viabilidad de expandir la app a usuarios finales (B2C) y soporte Desktop (Windows/macOS)

---

## 📋 TABLA DE CONTENIDOS

1. [Transformación B2C: Usuario Final + Empresa](#1-transformación-b2c-usuario-final--empresa)
2. [Soporte Desktop: Windows/macOS](#2-soporte-desktop-windowsmacos)
3. [Comparativa con WheelUp](#3-comparativa-con-wheelup)
4. [Recomendaciones Finales](#4-recomendaciones-finales)

---

# 1. TRANSFORMACIÓN B2C: Usuario Final + Empresa

## 1.1 📐 ARQUITECTURA ACTUAL vs. PROPUESTA

### **Estado Actual (B2B — Solo Empresas)**

```
┌─────────────────────────────────────┐
│     Firebase Authentication         │
│   uid → usuario empresa/empleado    │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│    Firestore: /usuarios/{uid}       │
│    - rol: propietario|admin|staff   │
│    - empresa_id: string             │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Firestore: /empresas/{empresaId}   │
│    - Toda la data de la empresa     │
│    - Sub-colecciones: clientes,     │
│      reservas, pedidos, facturas... │
└─────────────────────────────────────┘

UI: BottomNavigationBar con módulos de gestión
    - Dashboard, Reservas, Clientes, Facturación
    - Todo enfocado a GESTIONAR el negocio
```

### **Arquitectura Propuesta (B2B + B2C)**

```
┌──────────────────────────────────────────────────────────────┐
│              Firebase Authentication (MISMO)                  │
│   uid → puede ser usuario_final O usuario_empresa            │
└────────────┬─────────────────────────────────────────────────┘
             │
             ▼
┌────────────┴────────────────────────────────────────────────┐
│          Firestore: /usuarios/{uid}                          │
│   NUEVO CAMPO: tipo_usuario: "empresa" | "cliente_final"    │
│                                                               │
│   SI tipo_usuario == "empresa":                              │
│     - rol: propietario|admin|staff                           │
│     - empresa_id: string                                     │
│     - permisos: [...]                                        │
│                                                               │
│   SI tipo_usuario == "cliente_final":                        │
│     - nombre: string                                         │
│     - correo: string                                         │
│     - telefono: string                                       │
│     - preferencias: {...}                                    │
│     - favoritos: [empresaId1, empresaId2...]                 │
│     - historial_reservas: referencia a sub-colección        │
└──────────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┴─────────────────┐
        │                                   │
        ▼                                   ▼
┌───────────────────┐          ┌─────────────────────────────┐
│ UI EMPRESA (B2B)  │          │  UI CLIENTE FINAL (B2C)     │
├───────────────────┤          ├─────────────────────────────┤
│ BottomNavBar:     │          │ BottomNavBar NUEVA:         │
│ - Dashboard       │          │ - Descubrir (Búsqueda)      │
│ - Reservas        │          │ - Mis Reservas              │
│ - Clientes        │          │ - Favoritos                 │
│ - Facturación     │          │ - Perfil                    │
│ - Estadísticas    │          │                             │
│ - Configuración   │          │ PANTALLAS:                  │
│                   │          │ - Filtros por categoría     │
│ (Sin cambios)     │          │ - Mapa de negocios cercanos │
│                   │          │ - Ficha de empresa pública  │
│                   │          │ - Formulario de reserva     │
│                   │          │ - Valoración y comentarios  │
└───────────────────┘          └─────────────────────────────┘
```

---

## 1.2 🔧 CAMBIOS TÉCNICOS NECESARIOS

### **A) Autenticación y Registro Dual**

#### ✅ **LO QUE YA TIENES:**
- Firebase Authentication (email/password, Google, Apple)
- Pantalla de login (`lib/features/autenticacion/pantallas/pantalla_login.dart`)
- Registro de empresas con validación

#### 🔴 **LO QUE NECESITAS IMPLEMENTAR:**

**1. Pantalla de Selección de Tipo de Cuenta** (Esfuerzo: 8-12h)

```dart
// lib/features/autenticacion/pantallas/pantalla_seleccion_tipo.dart

Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('¿Cómo quieres usar FluixCRM?'),
        SizedBox(height: 40),
        
        // Opción 1: Soy Cliente (quiero reservar)
        ElevatedButton(
          child: Text('Buscar y Reservar'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PantallaRegistroCliente()),
          ),
        ),
        
        // Opción 2: Tengo un Negocio
        OutlinedButton(
          child: Text('Gestionar mi Negocio'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PantallaRegistroEmpresa()),
          ),
        ),
      ],
    ),
  );
}
```

**2. Registro de Cliente Final** (Esfuerzo: 16-24h)

```dart
// lib/features/autenticacion/servicios/auth_service.dart

Future<void> registrarClienteFinal({
  required String nombre,
  required String correo,
  required String password,
  String? telefono,
}) async {
  // 1. Crear usuario en Firebase Auth
  final userCredential = await FirebaseAuth.instance
      .createUserWithEmailAndPassword(email: correo, password: password);
  
  // 2. Crear documento en Firestore
  await FirebaseFirestore.instance.collection('usuarios').doc(userCredential.user!.uid).set({
    'nombre': nombre,
    'correo': correo,
    'telefono': telefono,
    'tipo_usuario': 'cliente_final',  // 🔥 NUEVO CAMPO CRÍTICO
    'fecha_creacion': FieldValue.serverTimestamp(),
    'activo': true,
    'favoritos': [],
  });
  
  // 3. Inicializar sub-colecciones
  await FirebaseFirestore.instance
      .collection('usuarios')
      .doc(userCredential.user!.uid)
      .collection('reservas')
      .doc('_init')
      .set({'__placeholder': true});
}
```

**3. Flujo de Login Dual** (Esfuerzo: 12-16h)

```dart
// Después del login exitoso, detectar tipo de usuario y redirigir

Future<void> _handleLogin() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  final doc = await FirebaseFirestore.instance
      .collection('usuarios')
      .doc(user.uid)
      .get();
  
  final tipoUsuario = doc.data()?['tipo_usuario'] as String?;
  
  if (tipoUsuario == 'cliente_final') {
    // 🔷 Navegar a UI de Cliente
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PantallaClienteHome()),
    );
  } else {
    // 🔶 Navegar a UI de Empresa (actual)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PantallaDashboard()),
    );
  }
}
```

---

### **B) Firestore: Nuevas Colecciones y Campos**

#### **1. Modificar `/usuarios/{uid}`** (Esfuerzo: 4-6h)

```diff
{
  "nombre": "string",
  "correo": "string",
+ "tipo_usuario": "empresa | cliente_final",  // NUEVO
  
  // SOLO si tipo_usuario == "empresa":
  "rol": "propietario | admin | staff",
  "empresa_id": "string",
  "permisos": ["string"],
  
  // SOLO si tipo_usuario == "cliente_final":
+ "telefono": "string | null",
+ "fecha_nacimiento": "Timestamp | null",
+ "foto_perfil_url": "string | null",
+ "favoritos": ["empresaId1", "empresaId2"],
+ "notificaciones_reservas": true,
+ "notificaciones_marketing": false,
}
```

#### **2. Nueva Sub-colección `/usuarios/{uid}/reservas/{reservaId}`** (Esfuerzo: 8-12h)

Para almacenar las reservas hechas por el cliente final:

```json
{
  "empresa_id": "string",
  "empresa_nombre": "string",
  "servicio": "string",
  "fecha": "Timestamp",
  "hora_inicio": "string",
  "estado": "pendiente | confirmada | cancelada | completada",
  "notas": "string | null",
  "precio": 0.0,
  "valorada": false,
  "fecha_creacion": "Timestamp"
}
```

> ⚠️ **IMPORTANTE:** Esta reserva debe SINCRONIZARSE con `/empresas/{empresaId}/reservas/{reservaId}`.  
> Puedes usar **Cloud Functions** para mantener ambas colecciones sincronizadas.

#### **3. Nueva Colección `/empresas_publicas/{empresaId}`** (Esfuerzo: 12-16h)

Para mostrar información pública de las empresas sin exponer datos sensibles:

```json
{
  "nombre": "string",
  "categoria": "restaurante | estetica | tatuaje | salon | otros",
  "descripcion": "string",
  "direccion": "string",
  "ciudad": "string",
  "codigo_postal": "string",
  "telefono": "string",
  "correo_contacto": "string",
  "sitio_web": "string | null",
  "horarios": {
    "lunes": {"abierto": true, "inicio": "09:00", "fin": "18:00"},
    // ... resto de días
  },
  "servicios_destacados": [
    {"nombre": "string", "precio": 0.0, "duracion": 60}
  ],
  "imagenes": ["url1", "url2"],
  "foto_portada": "string | null",
  "valoracion_promedio": 4.5,
  "total_valoraciones": 120,
  "acepta_reservas_online": true,
  "ubicacion": {
    "latitud": 0.0,
    "longitud": 0.0
  },
  "activo": true,
  "fecha_creacion": "Timestamp"
}
```

> 💡 **NOTA:** Esta colección se puede poblar con una **Cloud Function** que sincroniza desde `/empresas/{empresaId}` solo los campos públicos.

---

### **C) UI: Pantallas Nuevas para Cliente Final**

#### **Estructura de Navegación Nueva**

```dart
// lib/features/cliente/pantallas/cliente_home_screen.dart

class ClienteHomeScreen extends StatefulWidget {
  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> {
  int _indiceActual = 0;
  
  final List<Widget> _pantallas = [
    PantallaDescubrir(),      // Tab 0: Búsqueda de negocios
    PantallaMisReservas(),    // Tab 1: Historial de reservas del usuario
    PantallaFavoritos(),      // Tab 2: Empresas favoritas
    PantallaPerfilCliente(),  // Tab 3: Perfil del usuario
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pantallas[_indiceActual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) => setState(() => _indiceActual = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Descubrir'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Mis Reservas'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoritos'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
```

---

#### **1. Pantalla Descubrir (Búsqueda y Filtros)** — Esfuerzo: 40-60h

```dart
// lib/features/cliente/pantallas/pantalla_descubrir.dart

class PantallaDescubrir extends StatefulWidget {
  @override
  State<PantallaDescubrir> createState() => _PantallaDescubrirState();
}

class _PantallaDescubrirState extends State<PantallaDescubrir> {
  String _categoriaSeleccionada = 'todos';
  String _busqueda = '';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Descubrir Negocios'),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o servicio...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _busqueda = value),
            ),
          ),
          
          // Chips de filtros por categoría
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildChipCategoria('Todos', 'todos'),
                _buildChipCategoria('Restaurantes', 'restaurante'),
                _buildChipCategoria('Estéticas', 'estetica'),
                _buildChipCategoria('Tatuajes', 'tatuaje'),
                _buildChipCategoria('Peluquerías', 'salon'),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Lista de empresas
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _obtenerStreamEmpresas(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                
                final empresas = snapshot.data!.docs;
                
                return ListView.builder(
                  itemCount: empresas.length,
                  itemBuilder: (context, index) {
                    final empresa = empresas[index];
                    return _buildTarjetaEmpresa(empresa);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Stream<QuerySnapshot> _obtenerStreamEmpresas() {
    Query query = FirebaseFirestore.instance.collection('empresas_publicas')
        .where('activo', isEqualTo: true);
    
    if (_categoriaSeleccionada != 'todos') {
      query = query.where('categoria', isEqualTo: _categoriaSeleccionada);
    }
    
    // Búsqueda por nombre (limitada en Firestore, considerar Algolia/Meilisearch)
    if (_busqueda.isNotEmpty) {
      query = query
          .where('nombre', isGreaterThanOrEqualTo: _busqueda)
          .where('nombre', isLessThanOrEqualTo: _busqueda + '\uf8ff');
    }
    
    return query.snapshots();
  }
  
  Widget _buildTarjetaEmpresa(DocumentSnapshot empresa) {
    final data = empresa.data() as Map<String, dynamic>;
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(data['foto_portada'] ?? ''),
        ),
        title: Text(data['nombre']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['categoria'] ?? ''),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                SizedBox(width: 4),
                Text('${data['valoracion_promedio']?.toStringAsFixed(1) ?? '0.0'} (${data['total_valoraciones'] ?? 0})'),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PantallaFichaEmpresa(empresaId: empresa.id),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildChipCategoria(String label, String categoria) {
    final seleccionado = _categoriaSeleccionada == categoria;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: seleccionado,
        onSelected: (selected) {
          setState(() => _categoriaSeleccionada = categoria);
        },
      ),
    );
  }
}
```

---

#### **2. Ficha de Empresa Pública** — Esfuerzo: 32-48h

```dart
// lib/features/cliente/pantallas/pantalla_ficha_empresa.dart

class PantallaFichaEmpresa extends StatelessWidget {
  final String empresaId;
  
  const PantallaFichaEmpresa({required this.empresaId});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('empresas_publicas')
            .doc(empresaId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          final empresa = snapshot.data!.data() as Map<String, dynamic>;
          
          return CustomScrollView(
            slivers: [
              // Imagen de portada
              SliverAppBar(
                expandedHeight: 250,
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(
                    empresa['foto_portada'] ?? '',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre y valoración
                      Text(
                        empresa['nombre'],
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber),
                          SizedBox(width: 4),
                          Text('${empresa['valoracion_promedio']?.toStringAsFixed(1)} (${empresa['total_valoraciones']} valoraciones)'),
                        ],
                      ),
                      
                      Divider(height: 32),
                      
                      // Descripción
                      Text(
                        'Descripción',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 8),
                      Text(empresa['descripcion'] ?? ''),
                      
                      SizedBox(height: 24),
                      
                      // Servicios destacados
                      Text(
                        'Servicios',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 8),
                      ...((empresa['servicios_destacados'] as List?) ?? [])
                          .map((servicio) => _buildServicio(servicio))
                          .toList(),
                      
                      SizedBox(height: 24),
                      
                      // Información de contacto
                      _buildInfoContacto(empresa),
                      
                      SizedBox(height: 32),
                      
                      // Botón de reserva
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PantallaFormularioReserva(empresaId: empresaId),
                              ),
                            );
                          },
                          child: Text('Reservar Ahora'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildServicio(Map<String, dynamic> servicio) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(servicio['nombre']),
        subtitle: Text('${servicio['duracion']} minutos'),
        trailing: Text(
          '${servicio['precio']}€',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
  
  Widget _buildInfoContacto(Map<String, dynamic> empresa) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.location_on),
          title: Text(empresa['direccion'] ?? ''),
          contentPadding: EdgeInsets.zero,
        ),
        ListTile(
          leading: Icon(Icons.phone),
          title: Text(empresa['telefono'] ?? ''),
          contentPadding: EdgeInsets.zero,
        ),
        if (empresa['sitio_web'] != null)
          ListTile(
            leading: Icon(Icons.language),
            title: Text(empresa['sitio_web']),
            contentPadding: EdgeInsets.zero,
          ),
      ],
    );
  }
}
```

---

#### **3. Formulario de Reserva** — Esfuerzo: 32-48h

```dart
// lib/features/cliente/pantallas/pantalla_formulario_reserva.dart

class PantallaFormularioReserva extends StatefulWidget {
  final String empresaId;
  
  const PantallaFormularioReserva({required this.empresaId});
  
  @override
  State<PantallaFormularioReserva> createState() => _PantallaFormularioReservaState();
}

class _PantallaFormularioReservaState extends State<PantallaFormularioReserva> {
  String? _servicioSeleccionado;
  DateTime? _fechaSeleccionada;
  String? _horaSeleccionada;
  final _notasController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nueva Reserva')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector de servicio
            Text('Servicio', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(widget.empresaId)
                  .collection('servicios')
                  .where('activo', isEqualTo: true)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                
                final servicios = snapshot.data!.docs;
                
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(border: OutlineInputBorder()),
                  value: _servicioSeleccionado,
                  items: servicios.map((servicio) {
                    final data = servicio.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: servicio.id,
                      child: Text('${data['nombre']} - ${data['precio']}€'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _servicioSeleccionado = value);
                  },
                );
              },
            ),
            
            SizedBox(height: 24),
            
            // Selector de fecha
            Text('Fecha', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            OutlinedButton.icon(
              icon: Icon(Icons.calendar_today),
              label: Text(_fechaSeleccionada == null
                  ? 'Seleccionar fecha'
                  : DateFormat('dd/MM/yyyy').format(_fechaSeleccionada!)),
              onPressed: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 90)),
                );
                if (fecha != null) {
                  setState(() => _fechaSeleccionada = fecha);
                }
              },
            ),
            
            SizedBox(height: 24),
            
            // Selector de hora
            Text('Hora', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            // Aquí irían los slots disponibles consultados desde Firestore
            Wrap(
              spacing: 8,
              children: ['09:00', '10:00', '11:00', '12:00', '15:00', '16:00', '17:00', '18:00']
                  .map((hora) => ChoiceChip(
                        label: Text(hora),
                        selected: _horaSeleccionada == hora,
                        onSelected: (selected) {
                          setState(() => _horaSeleccionada = selected ? hora : null);
                        },
                      ))
                  .toList(),
            ),
            
            SizedBox(height: 24),
            
            // Notas adicionales
            Text('Notas (opcional)', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            TextField(
              controller: _notasController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Instrucciones especiales...',
                border: OutlineInputBorder(),
              ),
            ),
            
            SizedBox(height: 32),
            
            // Botón confirmar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmarReserva,
                child: Text('Confirmar Reserva'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _confirmarReserva() async {
    if (_servicioSeleccionado == null || _fechaSeleccionada == null || _horaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }
    
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final userData = userDoc.data()!;
      
      final reservaId = FirebaseFirestore.instance.collection('_').doc().id;
      
      // Crear reserva en la empresa
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('reservas')
          .doc(reservaId)
          .set({
        'cliente': userData['nombre'],
        'servicio': _servicioSeleccionado,
        'fecha': Timestamp.fromDate(_fechaSeleccionada!),
        'hora_inicio': _horaSeleccionada,
        'estado': 'PENDIENTE',
        'notas': _notasController.text,
        'cliente_id': user.uid,  // 🔥 Referencia al cliente
        'origen': 'app_cliente',
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
      
      // Crear copia en el historial del usuario
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('reservas')
          .doc(reservaId)
          .set({
        'empresa_id': widget.empresaId,
        'servicio': _servicioSeleccionado,
        'fecha': Timestamp.fromDate(_fechaSeleccionada!),
        'hora_inicio': _horaSeleccionada,
        'estado': 'PENDIENTE',
        'notas': _notasController.text,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
      
      // TODO: Enviar notificación push a la empresa
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Reserva enviada. La empresa la confirmará pronto.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al crear reserva: $e')),
      );
    }
  }
}
```

---

#### **4. Mis Reservas** — Esfuerzo: 24-32h

```dart
// lib/features/cliente/pantallas/pantalla_mis_reservas.dart

class PantallaMisReservas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    
    return Scaffold(
      appBar: AppBar(title: Text('Mis Reservas')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .collection('reservas')
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          final reservas = snapshot.data!.docs;
          
          if (reservas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No tienes reservas todavía'),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Navegar a Descubrir
                    },
                    child: Text('Explorar Negocios'),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: reservas.length,
            itemBuilder: (context, index) {
              final reserva = reservas[index];
              final data = reserva.data() as Map<String, dynamic>;
              
              return _buildTarjetaReserva(data);
            },
          );
        },
      ),
    );
  }
  
  Widget _buildTarjetaReserva(Map<String, dynamic> reserva) {
    final fecha = (reserva['fecha'] as Timestamp).toDate();
    final estado = reserva['estado'] as String;
    
    Color colorEstado;
    IconData iconoEstado;
    
    switch (estado) {
      case 'CONFIRMADA':
        colorEstado = Colors.green;
        iconoEstado = Icons.check_circle;
        break;
      case 'CANCELADA':
        colorEstado = Colors.red;
        iconoEstado = Icons.cancel;
        break;
      case 'COMPLETADA':
        colorEstado = Colors.blue;
        iconoEstado = Icons.done_all;
        break;
      default:
        colorEstado = Colors.orange;
        iconoEstado = Icons.schedule;
    }
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(iconoEstado, color: colorEstado, size: 32),
        title: Text(reserva['servicio'] ?? 'Servicio'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('dd/MM/yyyy - HH:mm').format(fecha)),
            Text('Estado: $estado', style: TextStyle(color: colorEstado)),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          // Ver detalles de la reserva
        },
      ),
    );
  }
}
```

---

### **D) Firestore Security Rules**

Debes añadir reglas para proteger los datos de clientes finales:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Usuarios pueden leer/escribir su propio documento
    match /usuarios/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Sub-colección de reservas del usuario
      match /reservas/{reservaId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Empresas públicas: todos pueden leer, solo admin puede escribir
    match /empresas_publicas/{empresaId} {
      allow read: if request.auth != null;
      allow write: if false; // Solo Cloud Functions pueden escribir aquí
    }
    
    // Reservas en empresas: usuario puede crear, empresa puede leer/editar
    match /empresas/{empresaId}/reservas/{reservaId} {
      allow create: if request.auth != null;
      allow read, update, delete: if isUserOfEmpresa(empresaId);
    }
    
    function isUserOfEmpresa(empresaId) {
      return exists(/databases/$(database)/documents/usuarios/$(request.auth.uid))
        && get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.empresa_id == empresaId;
    }
  }
}
```

---

### **E) Cloud Functions para Sincronización**

#### **1. Sincronizar datos públicos de empresa**

```typescript
// functions/src/syncEmpresaPublica.ts

export const syncEmpresaPublica = functions.firestore
  .document('empresas/{empresaId}')
  .onWrite(async (change, context) => {
    const empresaId = context.params.empresaId;
    const after = change.after.data();
    
    if (!after) {
      // Empresa eliminada, eliminar también de empresas_publicas
      await admin.firestore()
        .collection('empresas_publicas')
        .doc(empresaId)
        .delete();
      return;
    }
    
    // Extraer solo campos públicos
    const publicData = {
      nombre: after.nombre,
      categoria: after.categoria || 'otros',
      descripcion: after.descripcion || '',
      direccion: after.direccion,
      ciudad: after.ciudad || '',
      codigo_postal: after.codigo_postal || '',
      telefono: after.telefono,
      correo_contacto: after.correo,
      sitio_web: after.sitio_web || null,
      foto_portada: after.foto_portada || null,
      activo: after.activo !== false,
      fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // Calcular valoración promedio desde sub-colección
    const valoracionesSnap = await admin.firestore()
      .collection(`empresas/${empresaId}/valoraciones`)
      .get();
    
    let sumaValoraciones = 0;
    valoracionesSnap.forEach(doc => {
      sumaValoraciones += doc.data().calificacion || 0;
    });
    
    publicData.valoracion_promedio = valoracionesSnap.size > 0
      ? sumaValoraciones / valoracionesSnap.size
      : 0;
    publicData.total_valoraciones = valoracionesSnap.size;
    
    // Guardar en empresas_publicas
    await admin.firestore()
      .collection('empresas_publicas')
      .doc(empresaId)
      .set(publicData, { merge: true });
  });
```

#### **2. Notificar a empresa cuando llega nueva reserva**

```typescript
// functions/src/notifyNuevaReserva.ts

export const notifyNuevaReserva = functions.firestore
  .document('empresas/{empresaId}/reservas/{reservaId}')
  .onCreate(async (snap, context) => {
    const reserva = snap.data();
    const empresaId = context.params.empresaId;
    
    // Obtener tokens de dispositivos de usuarios de la empresa
    const dispositivosSnap = await admin.firestore()
      .collection(`empresas/${empresaId}/dispositivos`)
      .where('activo', '==', true)
      .get();
    
    const tokens = [];
    dispositivosSnap.forEach(doc => {
      tokens.push(doc.data().token);
    });
    
    if (tokens.length === 0) return;
    
    // Enviar notificación push
    await admin.messaging().sendMulticast({
      tokens,
      notification: {
        title: '📅 Nueva Reserva',
        body: `${reserva.cliente} ha solicitado ${reserva.servicio} para el ${reserva.fecha.toDate().toLocaleDateString()}`,
      },
      data: {
        tipo: 'nueva_reserva',
        reserva_id: context.params.reservaId,
      },
    });
  });
```

---

## 1.3 📊 RESUMEN DE COMPLEJIDAD B2C

### **Tabla de Esfuerzo por Componente**

| Componente | Esfuerzo (horas) | Complejidad | Prioridad |
|---|---|---|---|
| **Autenticación dual (tipo de cuenta)** | 16-24h | MEDIA | 🔴 CRÍTICA |
| **Registro de cliente final** | 16-24h | MEDIA | 🔴 CRÍTICA |
| **Modificar esquema Firestore** | 12-16h | MEDIA | 🔴 CRÍTICA |
| **Firestore rules para clientes** | 8-12h | ALTA | 🔴 CRÍTICA |
| **Pantalla Descubrir (búsqueda + filtros)** | 40-60h | ALTA | 🔴 CRÍTICA |
| **Ficha de empresa pública** | 32-48h | MEDIA | 🔴 CRÍTICA |
| **Formulario de reserva cliente** | 32-48h | MEDIA | 🔴 CRÍTICA |
| **Mis Reservas (historial)** | 24-32h | BAJA | 🟠 ALTA |
| **Pantalla Favoritos** | 16-24h | BAJA | 🟡 MEDIA |
| **Perfil de cliente** | 16-24h | BAJA | 🟡 MEDIA |
| **Cloud Function sync empresas_publicas** | 12-16h | MEDIA | 🔴 CRÍTICA |
| **Cloud Function notificación nueva reserva** | 8-12h | BAJA | 🟠 ALTA |
| **Sistema de valoraciones mejorado** | 24-32h | MEDIA | 🟡 MEDIA |
| **Mapa de negocios cercanos (Google Maps)** | 32-40h | ALTA | 🟡 MEDIA |
| **Chat empresa-cliente** | 60-80h | MUY ALTA | 🔵 BAJA |
| **Total estimado MÍNIMO (MVP)** | **232-340h** | — | — |
| **Total con features completos** | **360-480h** | — | — |

### **¿Qué tan complicado es?**

#### 🟢 **ASPECTOS FAVORABLES:**

1. **Ya tienes Firebase configurado** — No necesitas cambiar de backend.
2. **Ya tienes autenticación** — Solo hay que añadir el flujo de selección de tipo.
3. **Ya tienes módulo de reservas** — El modelo existe, solo falta exponerlo al cliente.
4. **Ya tienes valoraciones** — Ya capturáis reseñas de Google y manuales.
5. **Flutter es multiplataforma** — El mismo código funcionará en iOS y Android.

#### 🔴 **ASPECTOS DESAFIANTES:**

1. **Búsqueda en Firestore es limitada** — Para búsqueda full-text necesitarás **Algolia**, **Meilisearch** o **Elasticsearch** (~40h extra).
2. **Geolocalización** — Si quieres "negocios cerca de mí", necesitas **geo-queries** con `geoflutterfire` o similar (~24h extra).
3. **Dos UI completamente separadas** — Duplica el trabajo de testing y mantenimiento.
4. **Sincronización de reservas** — Cloud Functions deben mantener ambas copias sincronizadas (riesgo de inconsistencias).
5. **Notificaciones bidireccionales** — La empresa debe recibir notificación cuando llega reserva, el cliente cuando la empresa confirma/cancela.
6. **Moderación de valoraciones** — Si permites que clientes dejen reseñas, necesitas sistema de moderación (~16h extra).

---

## 1.4 ⚠️ RIESGOS Y CONSIDERACIONES

### **1. Competencia directa con WheelUp / TheFork / Treatwell**

Si entras en el mercado B2C, compites con apps que tienen:
- ✅ Miles de negocios ya registrados
- ✅ Base de usuarios masiva
- ✅ Algoritmos de recomendación avanzados
- ✅ Inversión millonaria en marketing

**Mitigación:**
- Diferenciarte con **gestión integral** (no solo reservas, sino CRM + facturación + nóminas todo en uno).
- Enfocarte en **nicho local** (e.g., "La app de negocios de Canarias").
- Ofrecer **onboarding gratuito** para empresas que traigan a sus clientes.

### **2. Costo de infraestructura**

Con usuarios finales, el número de usuarios puede **explotar exponencialmente**:
- Más reads/writes en Firestore → más costos.
- Más notificaciones push → más costos FCM.
- Más almacenamiento de imágenes → más costos Firebase Storage.

**Mitigación:**
- Implementar **cache agresivo** en cliente.
- Limitar búsquedas con paginación estricta.
- Comprimir imágenes antes de subir.

### **3. Soporte y moderación**

Clientes finales generan **mucho más soporte** que empresas:
- Dudas sobre cómo reservar.
- Quejas de disponibilidad.
- Solicitudes de cancelación.
- Reportes de negocios.

**Mitigación:**
- Chatbot automatizado con FAQs.
- Sistema de tickets con prioridad.
- Documentación clara y onboarding interactivo.

---

## 1.5 📋 CHECKLIST DE IMPLEMENTACIÓN

### **Fase 1: MVP B2C (8-10 semanas)**
- [ ] Modificar `pantalla_login.dart` para detectar tipo de usuario
- [ ] Crear `pantalla_seleccion_tipo.dart` con botones "Cliente" / "Empresa"
- [ ] Crear `pantalla_registro_cliente.dart` para usuarios finales
- [ ] Modificar esquema `/usuarios/{uid}` con campo `tipo_usuario`
- [ ] Crear colección `/empresas_publicas/` con datos públicos
- [ ] Crear `pantalla_descubrir.dart` con filtros por categoría
- [ ] Crear `pantalla_ficha_empresa.dart` con información pública
- [ ] Crear `pantalla_formulario_reserva.dart` para clientes
- [ ] Crear `pantalla_mis_reservas.dart` con historial
- [ ] Implementar Cloud Function `syncEmpresaPublica`
- [ ] Implementar Cloud Function `notifyNuevaReserva`
- [ ] Actualizar Firestore rules para clientes
- [ ] Testing en iOS y Android
- [ ] Deploy en producción con feature flag

### **Fase 2: Mejoras UX (4-6 semanas)**
- [ ] Implementar búsqueda avanzada (Algolia)
- [ ] Añadir mapa de negocios cercanos (Google Maps)
- [ ] Sistema de favoritos funcional
- [ ] Notificaciones push bidireccionales
- [ ] Panel de administración para aprobar empresas
- [ ] Sistema de valoraciones mejorado (con moderación)

### **Fase 3: Escalado (6-8 semanas)**
- [ ] Implementar chat empresa-cliente
- [ ] Sistema de cupones/descuentos
- [ ] Programa de fidelización
- [ ] Dashboard de analytics para empresas (tráfico desde app)
- [ ] Integración con pasarelas de pago (pago anticipado de reservas)

---

# 2. SOPORTE DESKTOP: Windows/macOS

## 2.1 🖥️ ESTADO ACTUAL

Tu app está construida con **Flutter**, que soporta oficialmente:
- ✅ iOS
- ✅ Android
- ✅ Web
- ✅ Windows (estable desde Flutter 3.0)
- ✅ macOS (estable desde Flutter 3.0)
- ✅ Linux (estable desde Flutter 3.0)

**Buenas noticias:** El **80-90% de tu código actual funciona en Desktop sin cambios**.

---

## 2.2 📊 ANÁLISIS DE COMPLEJIDAD DESKTOP

### **¿Qué funciona inmediatamente?**

✅ **Widgets de UI** — Material3, botones, cards, listas, todo funciona.  
✅ **Firestore** — El SDK de Firebase funciona perfecto en Desktop.  
✅ **Autenticación** — Firebase Auth funciona en Windows/macOS.  
✅ **Navegación** — `Navigator`, rutas, todo funciona.  
✅ **Provider/Riverpod** — Gestión de estado funciona igual.  
✅ **HTTP/Dio** — Peticiones de red funcionan.

---

### **¿Qué necesita adaptación?**

#### 🔴 **1. Layout Responsive** (Esfuerzo: 40-60h)

**Problema:** La app está diseñada para móvil (pantallas pequeñas). En Desktop tienes 1920x1080 o más.

**Solución:**

```dart
// En lugar de siempre usar BottomNavigationBar, detectar plataforma

Widget build(BuildContext context) {
  final esDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  final ancho = MediaQuery.of(context).size.width;
  
  if (esDesktop && ancho > 800) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar fijo con navegación
          NavigationRail(
            destinations: [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.calendar_today), label: Text('Reservas')),
              // ...
            ],
            selectedIndex: _indiceActual,
            onDestinationSelected: (index) => setState(() => _indiceActual = index),
          ),
          VerticalDivider(thickness: 1, width: 1),
          // Contenido principal
          Expanded(child: _pantallas[_indiceActual]),
        ],
      ),
    );
  } else {
    // Mobile: Usar BottomNavigationBar actual
    return Scaffold(
      body: _pantallas[_indiceActual],
      bottomNavigationBar: BottomNavigationBar(...),
    );
  }
}
```

**Ejemplos que hay que adaptar:**
- Listas que ocupan todo el ancho → Limitar a 600-800px centrado.
- Diálogos pequeños → Expandir a 600x400px en Desktop.
- Formularios verticales → Convertir a 2 columnas en Desktop.

---

#### 🔴 **2. Notificaciones Push** (Esfuerzo: 24-32h)

**Problema:** Firebase Cloud Messaging (FCM) **NO funciona en Windows/macOS nativo**.

**Alternativas:**

1. **Web Push Notifications** (usando Flutter Web en Desktop):
   - Puedes usar el mismo código que la versión web.
   - Requiere que el usuario acepte notificaciones del navegador.

2. **Notificaciones locales** con `flutter_local_notifications`:
   - Funcionan en Windows/macOS.
   - Necesitas un **polling** periódico o **WebSocket** para recibir eventos desde backend.

3. **Desktop específicas:**
   - **Windows:** Usar `windows_notification` (integración con Action Center).
   - **macOS:** Usar notificaciones nativas de macOS.

**Recomendación:** Si las notificaciones son críticas, la app Desktop debe **consultar cada X minutos** si hay nuevas reservas/facturas.

---

#### 🔴 **3. Impresora Bluetooth** (Esfuerzo: 40-60h)

**Problema:** El módulo `ImpressoraBluetooth` usa plugins de Bluetooth para móvil. **No funciona en Desktop**.

**Alternativas:**

1. **USB/Red:** En Desktop, las impresoras suelen conectarse por USB o red local.
   - Usar `printing` package (soporta Windows/macOS).
   - O generar PDF y usar el driver nativo del sistema.

2. **Bluetooth Desktop:**
   - Para Windows: Existe `win32` package para acceder a Bluetooth API.
   - Para macOS: Usar `method_channel` con código Swift.
   - **Complejidad ALTA** (~60-80h).

**Recomendación para TPV:**  
Si quieres usar el módulo TPV en Desktop, mejor:
- Imprimir via **red local** (impresoras de ticket con IP).
- Usar `esc_pos_printer` conectando por red.

---

#### 🔴 **4. Cámara y Escáner** (Esfuerzo: 24-32h)

**Problema:** `image_picker` y cámaras funcionan diferente en Desktop.

**Solución:**
- En Desktop, `image_picker` abre un selector de archivos (no la cámara).
- Para escanear QR/códigos de barras, usar webcam con `mobile_scanner` (funciona en Desktop desde v3.0).

---

#### 🔴 **5. File Picker y Descargas** (Esfuerzo: 8-12h)

En móvil usas `file_picker` y guardas en `Downloads`. En Desktop:
- `file_picker` funciona perfecto.
- Para guardar PDFs, usar `path_provider` para obtener directorio de documentos del usuario.

```dart
// Desktop: Guardar PDF
final outputFile = File('${documentsPath}/factura_${facturaId}.pdf');
await outputFile.writeAsBytes(pdfBytes);

// Abrir con app predeterminada
await OpenFile.open(outputFile.path);
```

---

#### 🟡 **6. Actualizaciones OTA** (Esfuerzo: 16-24h)

En móvil tienes App Store y Play Store que manejan actualizaciones. En Desktop:

**Opciones:**

1. **MSIX (Windows):**
   - Empaquetar como app de Microsoft Store.
   - Auto-updates manejados por Store.

2. **DMG (macOS):**
   - Distribución manual o via Mac App Store.

3. **Auto-updater custom:**
   - Package `updater` para Flutter Desktop.
   - Descargar nuevo `.exe` o `.app` y reemplazar.

**Sin esto, los usuarios deben descargar manualmente cada versión nueva.**

---

## 2.3 📦 PROCESO DE COMPILACIÓN DESKTOP

### **Compilar para Windows**

```powershell
# 1. Habilitar soporte Windows (solo primera vez)
flutter config --enable-windows-desktop

# 2. Compilar versión Release
flutter build windows --release

# 3. Resultado en:
# build\windows\runner\Release\
#   - planeag_flutter.exe
#   - + DLLs necesarias (Flutter engine, etc.)

# 4. Empaquetar con MSIX (opcional, para Microsoft Store)
flutter pub add msix
flutter pub run msix:create

# Genera setup.exe instalable para Windows
```

**Tamaño típico:** 40-60 MB (exe + DLLs).

---

### **Compilar para macOS**

```bash
# 1. Habilitar soporte macOS (solo primera vez)
flutter config --enable-macos-desktop

# 2. Compilar versión Release
flutter build macos --release

# 3. Resultado en:
# build/macos/Build/Products/Release/planeag_flutter.app

# 4. Firmar app con certificado de desarrollador Apple (obligatorio)
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Tu Nombre (TEAM_ID)" \
  build/macos/Build/Products/Release/planeag_flutter.app

# 5. Crear DMG para distribución
# (Usar herramienta como "create-dmg" o "appdmg")
```

**Tamaño típico:** 30-50 MB (.app bundle).

---

## 2.4 📊 TABLA DE COMPATIBILIDAD

| Feature | iOS | Android | Windows | macOS | Esfuerzo |
|---|---|---|---|---|---|
| **UI básica (Material3)** | ✅ | ✅ | ✅ | ✅ | 0h |
| **Firestore** | ✅ | ✅ | ✅ | ✅ | 0h |
| **Firebase Auth** | ✅ | ✅ | ✅ | ✅ | 0h |
| **HTTP/API calls** | ✅ | ✅ | ✅ | ✅ | 0h |
| **File picker** | ✅ | ✅ | ✅ | ✅ | 0h |
| **PDF generation** | ✅ | ✅ | ✅ | ✅ | 0h |
| **QR scanner** | ✅ | ✅ | ⚠️ Webcam | ⚠️ Webcam | 8-12h |
| **Notificaciones push** | ✅ | ✅ | ❌ | ❌ | 24-32h |
| **Bluetooth printer** | ✅ | ✅ | ❌ | ❌ | 40-60h |
| **Google Maps** | ✅ | ✅ | ❌ | ❌ | 0h (no se usa en tu app) |
| **Biometric auth** | ✅ | ✅ | ⚠️ Windows Hello | ⚠️ Touch ID | 16-24h |
| **Background services** | ✅ | ✅ | ✅ | ✅ | 0h |
| **Layout responsive** | N/A | N/A | 🔴 | 🔴 | 40-60h |
| **Total adaptación** | — | — | **112-176h** | **112-176h** | — |

---

## 2.5 ⚠️ LIMITACIONES Y CONSIDERACIONES

### **1. Experiencia de Usuario**

❌ **Desktop NO es ideal para:**
- Módulo TPV (necesita impresora térmica, pantalla táctil, movilidad).
- Escaneo de productos con cámara (en móvil es más natural).
- Reservas en movimiento (usuarios prefieren móvil).

✅ **Desktop SÍ es ideal para:**
- Gestión de facturación (pantalla grande, teclado físico).
- Generación de informes (PDF, CSV, Excel).
- Administración de empleados y nóminas.
- Contabilidad (muchos campos, necesitas teclado).
- Dashboard con gráficas grandes.

**Recomendación:** Si implementas Desktop, **enfócalo en el panel de admin** (facturación, contabilidad, configuración), NO en operaciones diarias (reservas, TPV).

---

### **2. Mantenimiento Duplicado**

Cada plataforma tiene:
- Dependencias específicas (`pubspec.yaml` condicionales).
- Builds separados (CI/CD más complejo).
- Testing en múltiples plataformas (Windows 10/11, macOS Ventura/Sonoma).

**Estimación:** **+30% de tiempo de desarrollo** si soportas Desktop.

---

### **3. Distribución**

| Plataforma | Método de Distribución | Coste | Complejidad |
|---|---|---|---|
| **iOS** | App Store | $99/año | MEDIA |
| **Android** | Play Store | $25 una vez | BAJA |
| **Windows** | Microsoft Store | Gratis | ALTA (certificado EV ~$300-500/año) |
| **Windows** | Web/descarga directa | Gratis | BAJA (usuarios desconfían de .exe sin firmar) |
| **macOS** | Mac App Store | $99/año (mismo de iOS) | MUY ALTA (notarización obligatoria) |
| **macOS** | Web/descarga directa | Gratis | ALTA (usuarios ven warning si no está notarizado) |

**Recomendación:** Si no tienes presupuesto para certificados, mejor hacer **versión web** (con `flutter build web`) accesible desde navegador. **Funciona en cualquier Desktop sin instalación**.

---

### **4. Versión Web vs. Desktop Nativa**

| | Web | Desktop Nativa |
|---|---|---|
| **Instalación** | No requiere, abre en navegador | Requiere descarga e instalación |
| **Actualizaciones** | Automáticas | Manuales o app store |
| **Permisos** | Limitados (notificaciones, archivos) | Completos |
| **Rendimiento** | Bueno (pero depende del navegador) | Excelente |
| **Offline** | Limitado (PWA con service worker) | Completo |
| **Acceso hardware** | Muy limitado | Completo |
| **Esfuerzo desarrollo** | Bajo | Medio-Alto |

**Recomendación:** Empieza con **versión Web** para Desktop. Si la demanda es alta, entonces invierte en versión nativa.

---

## 2.6 📋 CHECKLIST IMPLEMENTACIÓN DESKTOP

### **Fase 1: Versión Web Desktop (2-3 semanas)**
- [ ] Compilar con `flutter build web --release`
- [ ] Adaptar layout responsive (NavigationRail para Desktop)
- [ ] Testing en Chrome/Edge/Safari Desktop
- [ ] Deploy en Firebase Hosting o Netlify
- [ ] Configurar dominio (e.g., `app.fluixcrm.com`)

### **Fase 2: Versión Nativa Desktop (6-8 semanas)**
- [ ] Habilitar `flutter config --enable-windows-desktop --enable-macos-desktop`
- [ ] Adaptar plugins que usan hardware móvil
- [ ] Implementar notificaciones Desktop (polling o WebSocket)
- [ ] Adaptar impresión (usar `printing` package)
- [ ] Testing en Windows 10/11
- [ ] Testing en macOS Ventura/Sonoma
- [ ] Configurar build pipeline (GitHub Actions / GitLab CI)
- [ ] Firmar aplicación (certificado EV para Windows, Developer ID para macOS)
- [ ] Crear instaladores (MSIX para Windows, DMG para macOS)
- [ ] Documentar proceso de instalación

---

# 3. COMPARATIVA CON WHEELUP

## 3.1 🔍 ¿QUÉ ES WHEELUP?

**WheelUp** es una plataforma de **reservas online** enfocada en:
- Restaurantes
- Bares y cafeterías
- Espacios de ocio
- Eventos

**Funcionalidades principales:**
- Motor de reservas con gestión de turnos
- Panel de control para el restaurante
- App móvil para clientes (descubrir y reservar)
- Confirmación automática de reservas
- Recordatorios por email/SMS
- Sistema de reseñas y valoraciones
- Gestión de listas de espera

**Planes de precio (estimados, pueden variar):**

| Plan | Precio mensual | Comisión por reserva | Features |
|---|---|---|---|
| **Básico** | €29-49 | 5-10% | Motor de reservas, panel básico |
| **Pro** | €79-99 | 3-5% | + Marketing, CRM, reportes |
| **Enterprise** | €149-199 | 0% | + Multi-local, API, soporte prioritario |

---

## 3.2 📊 COMPARATIVA FLUIXCRM vs. WHEELUP

### **¿Qué tiene WheelUp que FluixCRM NO tiene?**

| Feature | WheelUp | FluixCRM | Impacto | Esfuerzo |
|---|---|---|---|---|
| **App cliente (B2C)** | ✅ | ❌ | 🔴 ALTO | 232-340h |
| **Marketplace de negocios** | ✅ | ❌ | 🔴 ALTO | 160-240h |
| **Búsqueda geolocalizada** | ✅ | ❌ | 🔴 ALTO | 24-40h |
| **Confirmación automática de reservas** | ✅ | ⚠️ Manual | 🟠 MEDIO | 16-24h |
| **Recordatorios automáticos (SMS/Email)** | ✅ | ❌ | 🟠 MEDIO | 16-24h |
| **Gestión de listas de espera** | ✅ | ❌ | 🟡 BAJO | 24-32h |
| **Reservas desde Google** | ✅ | ⚠️ Via GMB manual | 🟡 BAJO | 40-60h |
| **Integración con redes sociales** | ✅ | ❌ | 🟡 BAJO | 16-24h |

---

### **¿Qué tiene FluixCRM que WheelUp NO tiene?**

| Feature | FluixCRM | WheelUp | Ventaja Competitiva |
|---|---|---|---|
| **Facturación completa (9 modelos AEAT)** | ✅ | ❌ | 🔴 ENORME |
| **VeriFactu con hash chain** | ✅ | ❌ | 🔴 ENORME |
| **Módulo de nóminas con cálculo IRPF** | ✅ | ❌ | 🔴 MUY ALTA |
| **Gestión de gastos y proveedores** | ✅ | ❌ | 🔴 ALTA |
| **Generación de facturas desde pedidos** | ✅ | ❌ | 🔴 ALTA |
| **TPV completo (módulo bar/restaurante)** | ✅ | ❌ | 🟠 ALTA |
| **Gestión de empleados + permisos** | ✅ | ⚠️ Básico | 🟠 MEDIA |
| **WhatsApp para pedidos** | ✅ | ❌ | 🟠 MEDIA |
| **Módulo de tareas/proyectos** | ✅ | ❌ | 🟡 MEDIA |
| **Estadísticas avanzadas con cache** | ✅ | ⚠️ Básico | 🟡 MEDIA |
| **Integración Stripe + Redsys + PSD2** | ✅ | ⚠️ Solo Stripe | 🟡 MEDIA |
| **Configuración fiscal por empresa** | ✅ | ❌ | 🟡 ALTA |

---

## 3.3 💰 ANÁLISIS DE PRECIOS

### **Estructura de Precios WheelUp (aprox.):**

```
Plan Básico: €39/mes
  - Hasta 100 reservas/mes
  - Panel de control básico
  - Confirmación automática
  - Sin comisión por reserva

Plan Pro: €89/mes
  - Reservas ilimitadas
  - CRM + Marketing
  - Reportes avanzados
  - Integración redes sociales
  - Sin comisión

Plan Enterprise: €149/mes
  - Todo de Pro
  - Multi-local
  - API
  - Soporte prioritario
  - Account manager
```

### **Estructura de Precios FluixCRM (estimada de tus docs):**

Según el análisis de competencia, tus packs actuales deberían ser:

```
Pack Básico: €29-39/mes
  - CRM básico
  - Reservas
  - Clientes
  - Valoraciones

Pack Gestión: €59-79/mes
  - Todo de Básico
  - Facturación completa
  - Estadísticas
  - Whatsapp
  - TPV

Pack Tienda: €99-129/mes
  - Todo de Gestión
  - Pedidos online
  - Pasarelas de pago
  - Nóminas
  - Modelos AEAT
```

---

## 3.4 🎯 RECOMENDACIONES DE PRECIO

### **Estrategia 1: Posicionamiento Premium (Recomendada)**

**Argumento:** FluixCRM es **10x más completo** que WheelUp. No es solo reservas, es **gestión integral del negocio**.

```
┌────────────────────────────────────────────────────────┐
│ FLUIXCRM — GESTIÓN INTEGRAL PARA PYMES                 │
├────────────────────────────────────────────────────────┤
│ Plan STARTER: €49/mes                                  │
│   - CRM + Reservas + Valoraciones                      │
│   - Dashboard de estadísticas                          │
│   - 2 usuarios                                         │
│   - 100 reservas/mes                                   │
│                                                         │
│ Plan PROFESIONAL: €99/mes                              │
│   ✅ Todo de Starter                                   │
│   + Facturación completa (VeriFactu)                   │
│   + Módulo de pedidos + WhatsApp                       │
│   + Gestión de gastos                                  │
│   + 5 usuarios                                         │
│   + Reservas ilimitadas                                │
│                                                         │
│ Plan BUSINESS: €179/mes                                │
│   ✅ Todo de Profesional                               │
│   + Módulo de nóminas                                  │
│   + 9 modelos fiscales AEAT                            │
│   + TPV para bares/restaurantes                        │
│   + Pasarelas de pago (Stripe/Redsys)                  │
│   + Usuarios ilimitados                                │
│   + Soporte prioritario                                │
│                                                         │
│ Plan ENTERPRISE: Personalizado (€299+)                 │
│   ✅ Todo de Business                                  │
│   + Multi-empresa                                      │
│   + API privada                                        │
│   + Desarrollo a medida                                │
│   + Account manager dedicado                           │
└────────────────────────────────────────────────────────┘
```

**Justificación:**
- **€49 vs €39 de WheelUp:** +€10, pero incluyes CRM completo.
- **€99:** Precio justo por facturación VeriFactu (ningún competidor la tiene tan completa).
- **€179:** Nóminas + TPV + AEAT justifican el precio premium.

---

### **Estrategia 2: Competencia Directa (Agresiva)**

Si quieres **ganar cuota de mercado rápido**:

```
Plan LITE: €19/mes (PROMO 12 MESES)
  - CRM + Reservas
  - 1 usuario
  - 50 reservas/mes

Plan ESTÁNDAR: €49/mes
  - CRM + Reservas + Facturación básica
  - 3 usuarios
  - 200 reservas/mes

Plan PREMIUM: €89/mes
  - Todo ilimitado
  - VeriFactu + Nóminas + TPV
  - Soporte prioritario
```

**Riesgo:** Te posicionas como "low-cost", difícil subir precios después.

---

### **Estrategia 3: Modelo Híbrido (Más Flexible)**

```
BASE: €39/mes
  - CRM + Reservas + Dashboard

MÓDULOS ADICIONALES (a la carta):
  + Facturación: +€20/mes
  + Nóminas: +€30/mes
  + TPV: +€25/mes
  + Pedidos Online: +€15/mes
  + Pasarelas de pago: +€20/mes

Ejemplo:
  - Peluquería pequeña: €39 (solo CRM + reservas)
  - Restaurante mediano: €39 + €25 (TPV) = €64/mes
  - Agencia: €39 + €20 (facturación) + €30 (nóminas) = €89/mes
```

**Ventaja:** Usuario paga solo lo que necesita.  
**Desventaja:** Más complejo de gestionar (billing a medida).

---

## 3.5 📋 COMPARATIVA FINAL: FLUIXCRM vs. WHEELUP

### **Si implementas B2C (cliente final):**

| Categoría | WheelUp | FluixCRM (con B2C) | Ganador |
|---|---|---|---|
| **Reservas online** | ✅ Excelente | ✅ Excelente | **EMPATE** |
| **App cliente** | ✅ Nativa | ✅ Flutter (post-MVP) | **EMPATE** |
| **Facturación** | ❌ | ✅ VeriFactu completa | **FLUIXCRM** |
| **Nóminas** | ❌ | ✅ Con IRPF + Seguridad Social | **FLUIXCRM** |
| **TPV** | ❌ | ✅ Módulo completo | **FLUIXCRM** |
| **Gestión de gastos** | ❌ | ✅ | **FLUIXCRM** |
| **Marketplace** | ✅ Red grande | ⚠️ Red pequeña (al inicio) | **WHEELUP** |
| **Geolocalización** | ✅ | ⚠️ (requiere implementación) | **WHEELUP** |
| **Precio** | €39-149/mes | €49-179/mes | **WHEELUP** (más barato) |
| **Valor por dinero** | Medio | **Muy Alto** | **FLUIXCRM** |

---

### **Puntuación Global:**

```
WheelUp:  7/10
  ✅ Especializado en reservas
  ✅ App cliente pulida
  ✅ Marketplace grande
  ❌ Sin facturación
  ❌ Sin nóminas
  ❌ Sin gestión integral

FluixCRM: 9/10 (con B2C implementado)
  ✅ Gestión integral (CRM + Facturación + Nóminas + TPV)
  ✅ VeriFactu (ventaja competitiva ENORME)
  ✅ Multi-sector (no solo hostelería)
  ⚠️ Marketplace pequeño (al inicio)
  ⚠️ App cliente pendiente (232-340h)
```

---

# 4. RECOMENDACIONES FINALES

## 4.1 🎯 PRIORIZACIÓN ESTRATÉGICA

### **Escenario 1: Enfoque B2B (Recomendado)**

**Si tu objetivo es rentabilidad rápida:**

1. ✅ **NO implementes B2C aún**. Es una inversión enorme (360-480h).
2. ✅ **Enfócate en cerrar los gaps de facturación** (del análisis de competencia):
   - Facturas recurrentes (24-32h)
   - Cobros parciales (16-24h)
   - Presupuestos (40-60h)
   - Recordatorios de cobro (16-24h)
3. ✅ **Posicionamiento:** "La mejor app de gestión integral con VeriFactu para pymes españolas".
4. ✅ **Precio:** €99/mes plan profesional, €179/mes plan business.
5. ✅ **Canal de venta:** Directo a empresas (gestoría, asociaciones, LinkedIn Ads).

**ROI esperado:** 6-8 meses para recuperar inversión en desarrollo.

---

### **Escenario 2: Expansión B2C (Largo Plazo)**

**Si quieres construir un marketplace:**

**Fase 1 (3-4 meses):**
1. Implementar MVP B2C (232-340h).
2. Lanzar con **100 empresas beta** (tus clientes actuales).
3. Marketing digital enfocado en **ciudad piloto** (e.g., Las Palmas).

**Fase 2 (6-8 meses):**
4. Iterar basado en feedback.
5. Implementar búsqueda avanzada (Algolia) y geolocalización.
6. Lanzar campaña de usuario final (TikTok, Instagram Ads).

**Fase 3 (12-18 meses):**
7. Escalar a nivel nacional.
8. Buscar inversión para competir con WheelUp/TheFork.

**ROI esperado:** 18-24 meses, requiere inversión externa (~€100-200k).

---

### **Escenario 3: Desktop Nativo (Opcional)**

**SOLO si tienes demanda explícita de clientes.**

1. ✅ **Empieza con versión Web** (2-3 semanas).
2. ✅ Promociona la versión web como "Fluix para Desktop".
3. ⚠️ **SOLO si hay adopción alta (>100 usuarios web)**, invierte en nativo (6-8 semanas).

**ROI esperado:** Marginal. Desktop es un "nice to have", no un "must have".

---

## 4.2 💰 ESTIMACIÓN DE COSTOS TOTALES

### **Desarrollo B2C (MVP):**
- **Horas:** 232-340h
- **Coste interno** (si tienes desarrollador a €30-40/h): **€6,960 - €13,600**
- **Coste externo** (freelance a €50-70/h): **€11,600 - €23,800**
- **Infraestructura adicional** (Firebase, Algolia, etc.): **€50-150/mes**

### **Desarrollo Desktop:**
- **Horas:** 112-176h (solo Windows + macOS)
- **Coste interno:** €3,360 - €7,040
- **Coste externo:** €5,600 - €12,320
- **Certificados de firma:** €300-500/año (Windows) + €99/año (macOS)

### **Marketing B2C:**
- **Landing page + campaigns:** €2,000-5,000
- **Ads (Google/Meta/TikTok):** €500-2,000/mes (primeros 6 meses)
- **Total primer año:** €8,000-20,000

---

## 4.3 📊 TABLA DE DECISIÓN

| Criterio | B2B Solo | B2C | Desktop | Puntuación |
|---|---|---|---|---|
| **Inversión inicial** | 💰 Baja (€0) | 💰💰💰 Alta (€12-24k) | 💰💰 Media (€6-12k) | B2B |
| **Complejidad técnica** | 🟢 Baja | 🔴 Alta | 🟠 Media | B2B |
| **Time to market** | 🟢 0 meses | 🔴 3-4 meses | 🟠 2-3 meses | B2B |
| **Potencial de escala** | 🟡 Medio | 🟢 Alto | 🟠 Bajo | B2C |
| **Riesgo competitivo** | 🟢 Bajo | 🔴 Alto (WheelUp) | 🟡 Medio | B2B |
| **Ventaja competitiva** | ✅ VeriFactu única | ⚠️ Marketplace pequeño vs WheelUp | ⚠️ Web suficiente | B2B |
| **Adecuación producto** | ✅ Perfecto | ⚠️ Falta marketplace | ⚠️ Mejor web | B2B |

**Recomendación final: ENFOQUE B2B + Versión Web Desktop**

---

## 4.4 🚀 PLAN DE ACCIÓN RECOMENDADO (PRÓXIMOS 6 MESES)

### **Mes 1-2: Completar Paridad con WheelUp (B2B)**
- [ ] Facturas recurrentes automáticas (24-32h)
- [ ] Recordatorios de cobro (16-24h)
- [ ] Cobros parciales (16-24h)
- [ ] Confirmación automática de reservas (16-24h)
- **Resultado:** Plan Profesional sólido a €99/mes.

### **Mes 3-4: Optimización y Marketing**
- [ ] Mejorar onboarding (tutoriales interactivos)
- [ ] Crear casos de éxito (testimonios en video)
- [ ] Campaña LinkedIn Ads enfocada a pymes
- [ ] Partnerships con gestorías
- **Resultado:** +50 clientes nuevos.

### **Mes 5-6: Decisión B2C**
- [ ] Evaluar demanda real (encuestas a clientes actuales)
- [ ] Si >30% quiere B2C, iniciar desarrollo MVP
- [ ] Si no, invertir en **módulo de presupuestos** (40-60h) y **albaranes** (32-48h)
- **Resultado:** Roadmap confirmado para segundo semestre.

---

## 📝 CONCLUSIONES

### **B2C (Usuario Final):**
- ✅ **Técnicamente viable** — Flutter + Firebase lo soportan.
- ⚠️ **Inversión alta** — 232-340h para MVP, €12-24k costo desarrollo.
- 🔴 **Competencia fuerte** — WheelUp, TheFork, Treatwell ya establecidos.
- 🟢 **Ventaja:** Tu app es **gestión integral**, no solo reservas.

### **Desktop (Windows/macOS):**
- ✅ **Técnicamente viable** — Flutter Desktop es estable.
- 🟠 **Adaptación media** — 112-176h para versión completa.
- 🟢 **Alternativa mejor:** **Versión Web** accesible desde navegador (2-3 semanas).
- ⚠️ **Limitación:** Notificaciones push y Bluetooth no funcionan nativo.

### **Comparativa WheelUp:**
- ✅ **FluixCRM es SUPERIOR en:** Facturación, nóminas, TPV, gestión integral.
- ⚠️ **WheelUp es SUPERIOR en:** Marketplace establecido, app cliente pulida.
- 🎯 **Recomendación de precio:** €49/€99/€179 (Starter/Pro/Business).

---

**DECISIÓN RECOMENDADA:**

1. **Mes 1-4:** Completar gaps B2B, subir precios a €99/€179.
2. **Mes 5-6:** Lanzar versión **Web para Desktop** (no nativa).
3. **Mes 7-12:** **SOLO si hay demanda validada**, iniciar B2C MVP.

**Con esta estrategia, maximizas ROI con mínimo riesgo.** 🚀

---

*Fecha del análisis: 7 Mayo 2026*  
*Versión: 1.0*

