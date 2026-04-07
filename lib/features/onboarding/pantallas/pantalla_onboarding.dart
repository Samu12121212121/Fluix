import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../dashboard/pantallas/pantalla_dashboard.dart';

/// Onboarding obligatorio de 4 pasos para nuevas empresas.
/// Se muestra una sola vez. Al completarlo, guarda onboarding_completado: true
/// en el documento de la empresa.
class PantallaOnboarding extends StatefulWidget {
  final String empresaId;
  const PantallaOnboarding({super.key, required this.empresaId});

  @override
  State<PantallaOnboarding> createState() => _PantallaOnboardingState();
}

class _PantallaOnboardingState extends State<PantallaOnboarding> {
  final _pageController = PageController();
  int _paginaActual = 0;
  bool _guardando = false;

  // Datos recopilados en cada paso
  final _datosPerfil = <String, String>{};
  final _datosServicio = <String, dynamic>{};
  final _datosHorario = <String, dynamic>{};
  bool _webActiva = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _siguiente(Map<String, dynamic> datos) {
    if (_paginaActual == 0) _datosPerfil.addAll(datos.cast());
    if (_paginaActual == 1) _datosServicio.addAll(datos);
    if (_paginaActual == 2) _datosHorario.addAll(datos);
    if (_paginaActual == 3) _webActiva = datos['web_activa'] as bool? ?? false;

    if (_paginaActual < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _paginaActual++);
    } else {
      _completarOnboarding();
    }
  }

  void _anterior() {
    if (_paginaActual > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _paginaActual--);
    }
  }

  Future<void> _completarOnboarding() async {
    setState(() => _guardando = true);
    final db = FirebaseFirestore.instance;
    final empresaRef = db.collection('empresas').doc(widget.empresaId);

    try {
      // 1. Guardar perfil de empresa
      await empresaRef.set({
        'nombre': _datosPerfil['nombre'] ?? '',
        'telefono': _datosPerfil['telefono'] ?? '',
        'direccion': _datosPerfil['direccion'] ?? '',
        'descripcion': _datosPerfil['descripcion'] ?? '',
        'tipo_negocio': _datosPerfil['tipo_negocio'] ?? '',
        'onboarding_completado': true,
        'fecha_creacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Crear primer servicio si se rellenó
      if (_datosServicio['nombre'] != null && (_datosServicio['nombre'] as String).isNotEmpty) {
        await empresaRef.collection('servicios').add({
          'nombre': _datosServicio['nombre'],
          'precio': double.tryParse(_datosServicio['precio']?.toString() ?? '0') ?? 0.0,
          'duracion_minutos': int.tryParse(_datosServicio['duracion']?.toString() ?? '60') ?? 60,
          'descripcion': _datosServicio['descripcion'] ?? '',
          'categoria': _datosServicio['categoria'] ?? 'General',
          'activo': true,
          'imagenes': [],
          'fecha_creacion': DateTime.now().toIso8601String(),
        });
      }

      // 3. Guardar horarios
      if (_datosHorario.isNotEmpty) {
        await empresaRef.set({'horarios': _datosHorario}, SetOptions(merge: true));
      }

      // 4. Configuración inicial de módulos (web activa si eligió)
      await empresaRef.collection('configuracion').doc('modulos').set({
        'reservas': true,
        'citas': false,
        'clientes': true,
        'empleados': true,
        'servicios': true,
        'estadisticas': true,
        'valoraciones': true,
        'web': _webActiva,
        'pedidos': false,
        'facturacion': false,
        'whatsapp': false,
        'tareas': false,
      }, SetOptions(merge: true));

      // 5. Suscripción de prueba (30 días)
      await empresaRef.collection('suscripcion').doc('actual').set({
        'estado': 'ACTIVA',
        'fecha_inicio': FieldValue.serverTimestamp(),
        'fecha_fin': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'plan': 'prueba',
        'aviso_enviado': false,
      });

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PantallaDashboard()),
          (_) => false,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header con progreso
            _buildHeader(),

            // Páginas
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _PasoPerfil(onSiguiente: _siguiente),
                  _PasoServicio(onSiguiente: _siguiente, onAnterior: _anterior),
                  _PasoHorarios(onSiguiente: _siguiente, onAnterior: _anterior),
                  _PasoWeb(
                    onSiguiente: _siguiente,
                    onAnterior: _anterior,
                    guardando: _guardando,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titulos = ['Tu negocio', 'Primer servicio', 'Horarios', 'Página web'];
    final iconos = [Icons.store, Icons.spa, Icons.schedule, Icons.web];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_center_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              const Text(
                'Configura tu cuenta',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${_paginaActual + 1}/4',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barra de progreso por pasos
          Row(
            children: List.generate(4, (i) {
              final completado = i < _paginaActual;
              final activo = i == _paginaActual;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: completado || activo
                              ? const Color(0xFF69F0AE)
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < 3) const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Paso actual
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconos[_paginaActual], color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Paso ${_paginaActual + 1}: ${titulos[_paginaActual]}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── PASO 1: PERFIL DEL NEGOCIO ────────────────────────────────────────────────

class _PasoPerfil extends StatefulWidget {
  final Function(Map<String, dynamic>) onSiguiente;
  const _PasoPerfil({required this.onSiguiente});

  @override
  State<_PasoPerfil> createState() => _PasoPerfilState();
}

class _PasoPerfilState extends State<_PasoPerfil> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  String _tipoNegocio = 'Peluquería / Estética';

  final _tiposNegocio = [
    'Peluquería / Estética',
    'Restaurante / Bar',
    'Clínica / Salud',
    'Spa / Masajes',
    'Gimnasio / Fitness',
    'Taller / Reparaciones',
    'Tienda / Comercio',
    'Otro',
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              '¿Cómo se llama tu negocio?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Esta información aparecerá en tu página web y en la app.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),

            _campo('Nombre del negocio *', Icons.store, _nombreCtrl,
                validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null),
            const SizedBox(height: 14),

            // Tipo de negocio
            DropdownButtonFormField<String>(
              value: _tipoNegocio,
              decoration: _deco('Tipo de negocio', Icons.category),
              items: _tiposNegocio.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _tipoNegocio = v ?? _tipoNegocio),
            ),
            const SizedBox(height: 14),

            _campo('Teléfono de contacto', Icons.phone, _telefonoCtrl,
                tipo: TextInputType.phone),
            const SizedBox(height: 14),

            _campo('Dirección', Icons.location_on, _direccionCtrl),
            const SizedBox(height: 14),

            _campo('Descripción breve del negocio', Icons.description, _descripcionCtrl,
                maxLines: 3),
            const SizedBox(height: 32),

            _botonSiguiente(() {
              if (_formKey.currentState!.validate()) {
                widget.onSiguiente({
                  'nombre': _nombreCtrl.text.trim(),
                  'tipo_negocio': _tipoNegocio,
                  'telefono': _telefonoCtrl.text.trim(),
                  'direccion': _direccionCtrl.text.trim(),
                  'descripcion': _descripcionCtrl.text.trim(),
                });
              }
            }),
          ],
        ),
      ),
    );
  }
}

// ── PASO 2: PRIMER SERVICIO ───────────────────────────────────────────────────

class _PasoServicio extends StatefulWidget {
  final Function(Map<String, dynamic>) onSiguiente;
  final VoidCallback onAnterior;
  const _PasoServicio({required this.onSiguiente, required this.onAnterior});

  @override
  State<_PasoServicio> createState() => _PasoServicioState();
}

class _PasoServicioState extends State<_PasoServicio> {
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _duracionCtrl = TextEditingController(text: '60');
  final _descripcionCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _duracionCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Crea tu primer servicio',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Los servicios son lo que ofreces a tus clientes. Puedes añadir más después.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),

          _campo('Nombre del servicio (ej: Corte de pelo)', Icons.spa, _nombreCtrl),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _campo('Precio (€)', Icons.euro, _precioCtrl, tipo: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _campo('Duración (min)', Icons.timer, _duracionCtrl, tipo: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 14),
          _campo('Descripción (opcional)', Icons.description, _descripcionCtrl, maxLines: 2),
          const SizedBox(height: 24),

          // Botón omitir
          Center(
            child: TextButton(
              onPressed: () => widget.onSiguiente({'nombre': '', 'precio': '0', 'duracion': '60'}),
              child: Text('Omitir este paso', style: TextStyle(color: Colors.grey[500])),
            ),
          ),
          const SizedBox(height: 8),

          _botonSiguiente(() {
            widget.onSiguiente({
              'nombre': _nombreCtrl.text.trim(),
              'precio': _precioCtrl.text.trim(),
              'duracion': _duracionCtrl.text.trim(),
              'descripcion': _descripcionCtrl.text.trim(),
            });
          }),
          const SizedBox(height: 12),
          _botonAnterior(widget.onAnterior),
        ],
      ),
    );
  }
}

// ── PASO 3: HORARIOS ──────────────────────────────────────────────────────────

class _PasoHorarios extends StatefulWidget {
  final Function(Map<String, dynamic>) onSiguiente;
  final VoidCallback onAnterior;
  const _PasoHorarios({required this.onSiguiente, required this.onAnterior});

  @override
  State<_PasoHorarios> createState() => _PasoHorariosState();
}

class _PasoHorariosState extends State<_PasoHorarios> {
  final _apertura = TextEditingController(text: '09:00');
  final _cierre = TextEditingController(text: '20:00');

  final _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  final _diasClave = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
  late List<bool> _diasActivos;

  @override
  void initState() {
    super.initState();
    // Por defecto: lunes a viernes activos
    _diasActivos = [true, true, true, true, true, false, false];
  }

  @override
  void dispose() {
    _apertura.dispose();
    _cierre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Configura tus horarios',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Define cuándo está abierto tu negocio. Puedes ajustarlo después.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Días activos
          const Text('Días de apertura', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (i) {
              final activo = _diasActivos[i];
              return GestureDetector(
                onTap: () => setState(() => _diasActivos[i] = !activo),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: activo ? const Color(0xFF0D47A1) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: activo ? const Color(0xFF0D47A1) : Colors.grey[300]!,
                    ),
                    boxShadow: activo ? [BoxShadow(color: const Color(0xFF0D47A1).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : [],
                  ),
                  child: Text(
                    _diasSemana[i],
                    style: TextStyle(
                      color: activo ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Horario
          const Text('Horario general', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _apertura,
                  decoration: _deco('Apertura', Icons.wb_sunny),
                ),
              ),
              const SizedBox(width: 16),
              const Text('—', style: TextStyle(fontSize: 20, color: Colors.grey)),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _cierre,
                  decoration: _deco('Cierre', Icons.nightlight_round),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          _botonSiguiente(() {
            final horario = <String, dynamic>{
              'apertura': _apertura.text,
              'cierre': _cierre.text,
            };
            for (int i = 0; i < _diasClave.length; i++) {
              horario[_diasClave[i]] = _diasActivos[i];
            }
            widget.onSiguiente(horario);
          }),
          const SizedBox(height: 12),
          _botonAnterior(widget.onAnterior),
        ],
      ),
    );
  }
}

// ── PASO 4: PÁGINA WEB ────────────────────────────────────────────────────────

class _PasoWeb extends StatefulWidget {
  final Function(Map<String, dynamic>) onSiguiente;
  final VoidCallback onAnterior;
  final bool guardando;
  const _PasoWeb({required this.onSiguiente, required this.onAnterior, required this.guardando});

  @override
  State<_PasoWeb> createState() => _PasoWebState();
}

class _PasoWebState extends State<_PasoWeb> {
  bool _webActiva = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            '¿Tienes página web?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Si tienes una web con WordPress u otra plataforma, puedes conectarla para mostrar tu contenido dinámicamente.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 32),

          // Opción SI
          _OpcionWeb(
            seleccionada: _webActiva,
            icono: Icons.web,
            titulo: 'Sí, tengo página web',
            descripcion: 'Conecta tu web y gestiona el contenido desde la app',
            color: const Color(0xFF0D47A1),
            onTap: () => setState(() => _webActiva = true),
          ),
          const SizedBox(height: 12),

          // Opción NO
          _OpcionWeb(
            seleccionada: !_webActiva,
            icono: Icons.phonelink_off,
            titulo: 'No, solo usaré la app',
            descripcion: 'Puedes activar la web más adelante desde ajustes',
            color: const Color(0xFF455A64),
            onTap: () => setState(() => _webActiva = false),
          ),
          const SizedBox(height: 32),

          // Resumen final
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF69F0AE).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Ya casi estás! Pulsa "Completar" para acceder a tu panel de control.',
                    style: TextStyle(color: Color(0xFF2E7D32), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: widget.guardando
                  ? null
                  : () => widget.onSiguiente({'web_activa': _webActiva}),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: widget.guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.rocket_launch),
              label: Text(
                widget.guardando ? 'Configurando...' : '¡Completar configuración!',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _botonAnterior(widget.onAnterior),
        ],
      ),
    );
  }
}

class _OpcionWeb extends StatelessWidget {
  final bool seleccionada;
  final IconData icono;
  final String titulo;
  final String descripcion;
  final Color color;
  final VoidCallback onTap;

  const _OpcionWeb({
    required this.seleccionada,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionada ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionada ? color : Colors.grey[300]!,
            width: seleccionada ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(descripcion, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            if (seleccionada) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }
}

// ── HELPERS COMPARTIDOS ───────────────────────────────────────────────────────

Widget _campo(
  String label,
  IconData icono,
  TextEditingController ctrl, {
  TextInputType tipo = TextInputType.text,
  int maxLines = 1,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: ctrl,
    keyboardType: tipo,
    maxLines: maxLines,
    decoration: _deco(label, icono),
    validator: validator,
  );
}

InputDecoration _deco(String label, IconData icono) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icono),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

Widget _botonSiguiente(VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      ),
      icon: const Icon(Icons.arrow_forward),
      label: const Text('Siguiente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ),
  );
}

Widget _botonAnterior(VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 46,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: Colors.grey[400]!),
      ),
      icon: const Icon(Icons.arrow_back, size: 18),
      label: const Text('Anterior', style: TextStyle(fontSize: 15)),
    ),
  );
}



