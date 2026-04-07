import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/app_config_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA DE NOTIFICACIONES
// ─────────────────────────────────────────────────────────────────────────────

class PantallaNotificaciones extends StatefulWidget {
  const PantallaNotificaciones({super.key});

  @override
  State<PantallaNotificaciones> createState() => _PantallaNotificacionesState();
}

class _PantallaNotificacionesState extends State<PantallaNotificaciones> {
  final AppConfigService _svc = AppConfigService();
  Map<String, bool> _prefs = {};
  bool _cargando = true;

  static const _items = [
    {
      'clave': 'reservas',
      'titulo': 'Reservas nuevas',
      'descripcion': 'Cuando llega una nueva reserva',
      'icono': Icons.event_available,
      'color': Color(0xFF1976D2),
    },
    {
      'clave': 'cancelaciones',
      'titulo': 'Cancelaciones',
      'descripcion': 'Cuando se cancela una reserva',
      'icono': Icons.event_busy,
      'color': Color(0xFFF44336),
    },
    {
      'clave': 'pedidos',
      'titulo': 'Pedidos nuevos',
      'descripcion': 'Cuando llega un nuevo pedido',
      'icono': Icons.shopping_bag,
      'color': Color(0xFF7B1FA2),
    },
    {
      'clave': 'valoraciones',
      'titulo': 'Nuevas reseñas',
      'descripcion': 'Cuando un cliente deja una valoración',
      'icono': Icons.star,
      'color': Color(0xFFF57C00),
    },
    {
      'clave': 'suscripcion',
      'titulo': 'Suscripción',
      'descripcion': 'Avisos de vencimiento próximo',
      'icono': Icons.workspace_premium,
      'color': Color(0xFF2E7D32),
    },
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final p = await _svc.cargarNotificaciones();
    if (mounted) setState(() { _prefs = p; _cargando = false; });
  }

  Future<void> _toggle(String clave, bool valor) async {
    setState(() => _prefs[clave] = valor);
    await _svc.guardarNotificacion(clave, valor);
  }

  bool get _todasActivas => _prefs.values.every((v) => v);

  Future<void> _toggleTodas(bool valor) async {
    for (final item in _items) {
      await _toggle(item['clave'] as String, valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Encabezado ───────────────────────────────────────────
                _buildHeader(color),
                const SizedBox(height: 20),

                // ── Activar/desactivar todas ─────────────────────────────
                _buildCard(
                  child: SwitchListTile(
                    value: _todasActivas,
                    onChanged: _toggleTodas,
                    activeThumbColor: color,
                    title: const Text('Todas las notificaciones',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text(_todasActivas ? 'Activadas' : 'Desactivadas',
                        style: TextStyle(color: _todasActivas ? Colors.green : Colors.grey)),
                    secondary: Icon(
                      _todasActivas ? Icons.notifications_active : Icons.notifications_off,
                      color: _todasActivas ? color : Colors.grey,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Items individuales ────────────────────────────────────
                _buildCard(
                  child: Column(
                    children: _items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final clave = item['clave'] as String;
                      final itemColor = item['color'] as Color;
                      final activo = _prefs[clave] ?? true;
                      return Column(
                        children: [
                          if (i > 0) const Divider(height: 1),
                          SwitchListTile(
                            value: activo,
                            onChanged: (v) => _toggle(clave, v),
                            activeThumbColor: itemColor,
                            title: Text(item['titulo'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(item['descripcion'] as String,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (activo ? itemColor : Colors.grey).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(item['icono'] as IconData,
                                  color: activo ? itemColor : Colors.grey, size: 20),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Las notificaciones requieren conexión a internet y que los permisos estén activados en tu dispositivo.',
                      style: TextStyle(fontSize: 11, color: color),
                    )),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.notifications_active, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notificaciones Push', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 3),
            Text('Elige qué avisos quieres recibir', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        )),
      ]),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA DE TEMA Y COLORES
// ─────────────────────────────────────────────────────────────────────────────

class PantallaTemayColores extends StatelessWidget {
  const PantallaTemayColores({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();
    final color = config.colorPrimario;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Tema y Colores'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Encabezado ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.palette, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apariencia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 3),
                  Text('Personaliza el aspecto de la app', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Modo oscuro / claro ────────────────────────────────────────
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Modo de pantalla', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Row(children: [
                  Expanded(child: _buildModeBtn(
                    context, config,
                    mode: ThemeMode.light,
                    icono: Icons.light_mode,
                    label: 'Claro',
                    color: color,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _buildModeBtn(
                    context, config,
                    mode: ThemeMode.dark,
                    icono: Icons.dark_mode,
                    label: 'Oscuro',
                    color: color,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _buildModeBtn(
                    context, config,
                    mode: ThemeMode.system,
                    icono: Icons.brightness_auto,
                    label: 'Sistema',
                    color: color,
                  )),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Selector de color ──────────────────────────────────────────
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('Color principal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text('Afecta a botones, barras y acentos de la app',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppConfigService.coloresDisponibles.map((c) {
                    final colorItem = Color(c['valor'] as int);
                    final seleccionado = colorItem.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => context.read<AppConfigProvider>().cambiarColor(colorItem),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colorItem,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: seleccionado ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorItem.withValues(alpha: seleccionado ? 0.6 : 0.2),
                              blurRadius: seleccionado ? 12 : 4,
                              spreadRadius: seleccionado ? 2 : 0,
                            ),
                          ],
                        ),
                        child: seleccionado
                            ? const Icon(Icons.check, color: Colors.white, size: 22)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Nombre del color seleccionado
                Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppConfigService.coloresDisponibles.firstWhere(
                      (c) => Color(c['valor'] as int).toARGB32() == color.toARGB32(),
                      orElse: () => {'nombre': 'Personalizado'},
                    )['nombre'] as String,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Preview ────────────────────────────────────────────────────
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vista previa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.business_center, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Fluix CRM',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Activo', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                    child: const Text('Botón'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
                    child: const Text('Secundario'),
                  )),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBtn(BuildContext context, AppConfigProvider config, {
    required ThemeMode mode,
    required IconData icono,
    required String label,
    required Color color,
  }) {
    final sel = config.themeMode == mode;
    return GestureDetector(
      onTap: () => config.cambiarTema(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? color : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? color : Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icono, color: sel ? Colors.white : Colors.grey[600], size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
            color: sel ? Colors.white : Colors.grey[600],
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          )),
        ]),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA DE COPIA DE SEGURIDAD
// ─────────────────────────────────────────────────────────────────────────────

class PantallaBackup extends StatefulWidget {
  final String empresaId;
  const PantallaBackup({super.key, required this.empresaId});

  @override
  State<PantallaBackup> createState() => _PantallaBackupState();
}

class _PantallaBackupState extends State<PantallaBackup> {
  final AppConfigService _svc = AppConfigService();
  List<Map<String, dynamic>> _backups = [];
  bool _cargando = false;
  bool _realizando = false;

  @override
  void initState() {
    super.initState();
    _cargarBackups();
  }

  Future<void> _cargarBackups() async {
    setState(() => _cargando = true);
    final lista = await _svc.obtenerBackups(widget.empresaId);
    if (mounted) setState(() { _backups = lista; _cargando = false; });
  }

  Future<void> _realizarBackup() async {
    setState(() => _realizando = true);
    final result = await _svc.realizarBackup(widget.empresaId);
    if (mounted) {
      setState(() => _realizando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(result.exito ? Icons.check_circle : Icons.error, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(result.mensaje)),
        ]),
        backgroundColor: result.exito ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ));
      if (result.exito) _cargarBackups();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Copia de Seguridad'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.backup, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Copia de Seguridad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 3),
                  Text('Guarda hasta 5 copias de tus datos en la nube', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Qué se guarda ───────────────────────────────────────────────
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¿Qué se guarda?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Clientes', 'Empleados', 'Servicios', 'Reservas',
                    'Pedidos', 'Facturas', 'Productos', 'Valoraciones',
                    'Tareas', 'Transacciones', 'Contenido web',
                  ].map((s) => Chip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    backgroundColor: color.withValues(alpha: 0.08),
                    side: BorderSide(color: color.withValues(alpha: 0.2)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.cloud_done, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Los backups se guardan en Firebase y son accesibles desde cualquier dispositivo.',
                      style: TextStyle(fontSize: 11, color: Colors.green),
                    )),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Botón hacer backup ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _realizando ? null : _realizarBackup,
              icon: _realizando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.backup, size: 20),
              label: Text(_realizando ? 'Realizando copia...' : 'Hacer copia ahora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Historial de backups ────────────────────────────────────────
          const Text('Copias anteriores',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),

          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else if (_backups.isEmpty)
            _buildCard(
              child: Column(
                children: [
                  Icon(Icons.backup_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('Sin copias anteriores', style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('Haz tu primera copia de seguridad',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            )
          else
            ..._backups.map((b) {
              final fechaStr = b['fecha_legible'] as String? ?? '';
              DateTime? fecha;
              try { fecha = DateTime.parse(fechaStr); } catch (_) {}
              final cols = b['colecciones'] as Map? ?? {};
              int total = 0;
              cols.values.forEach((v) { if (v is List) total += v.length; });

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.cloud_done, color: color, size: 22),
                  ),
                  title: Text(
                    fecha != null
                        ? '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}'
                        : 'Copia anterior',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text('$total documentos guardados',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('✓ OK', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }),

          const SizedBox(height: 8),
          Center(child: Text(
            'Se mantienen las últimas 5 copias automáticamente',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}




