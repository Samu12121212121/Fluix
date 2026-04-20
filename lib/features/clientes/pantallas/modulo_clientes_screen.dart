import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../domain/modelos/cliente.dart';
import '../../../domain/modelos/factura.dart';
import '../../../services/clientes_service.dart';
import '../../../services/facturacion_service.dart';
import '../../../services/bulk_actions_service.dart';
import '../../../services/exportacion_clientes_service.dart';
import '../../../widgets/estado_cliente_badge.dart';
import '../../../widgets/bulk_actions_bar.dart';
import '../../../widgets/timeline_actividad_widget.dart';
import '../../facturacion/pantallas/detalle_factura_screen.dart';
import 'clientes_silenciosos_screen.dart';
import 'duplicados_cliente_screen.dart';
import 'importar_csv_screen.dart';

class ModuloClientesScreen extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  const ModuloClientesScreen({super.key, required this.empresaId, this.sesion});

  @override
  State<ModuloClientesScreen> createState() => _ModuloClientesScreenState();
}

class _ModuloClientesScreenState extends State<ModuloClientesScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _busquedaCtrl = TextEditingController();
  String _filtro = '';

  // ── Filtros de segmentación ──────────────────────────────────────────────────
  final Set<String> _etiquetasActivas = {};
  double? _minFacturacion;
  int? _mesesActividad; // +N = activo últimos N meses; -N = inactivo N meses
  String _localidadFiltro = '';

  bool get _hayFiltrosActivos =>
      _etiquetasActivas.isNotEmpty ||
      _minFacturacion != null ||
      _mesesActividad != null ||
      _localidadFiltro.isNotEmpty;

  int get _numFiltrosAvanzados =>
      (_minFacturacion != null ? 1 : 0) +
      (_mesesActividad != null ? 1 : 0) +
      (_localidadFiltro.isNotEmpty ? 1 : 0);

  void _limpiarFiltros() => setState(() {
        _etiquetasActivas.clear();
        _minFacturacion = null;
        _mesesActividad = null;
        _localidadFiltro = '';
      });

  bool get _puedeGestionar =>
      widget.sesion?.puedeGestionarClientes ?? true;

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Clientes', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_puedeGestionar)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Importar clientes desde CSV',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImportarCsvScreen(empresaId: widget.empresaId),
                  ),
                );
                // Si retorna true, la lista se actualiza sola por el StreamBuilder
                if (result == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Importación completada')),
                  );
                }
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('clientes')
            .orderBy('nombre')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          var clientes = snapshot.data?.docs ?? [];

          // Aplicar todos los filtros de segmentación
          clientes = ClientesService.filtrarClientes(
            docs: clientes,
            textoBusqueda: _filtro,
            etiquetasActivas: _etiquetasActivas,
            minFacturacion: _minFacturacion,
            mesesActividad: _mesesActividad,
            localidad: _localidadFiltro,
          );

          return CustomScrollView(
            slivers: [
              // Buscador
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _busquedaCtrl,
                    onChanged: (v) => setState(() => _filtro = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente por nombre o teléfono...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _filtro.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _busquedaCtrl.clear();
                                setState(() => _filtro = '');
                              })
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),

              // Barra de filtros de segmentación
              SliverToBoxAdapter(child: _buildFiltrosBar()),

              // Lista vacía o contenido
              if (clientes.isEmpty)
                SliverFillRemaining(child: _buildVacio())
              else ...[
                // Resumen estadístico
                SliverToBoxAdapter(child: _buildResumen(clientes)),
                // Tarjetas de clientes
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final data =
                            clientes[i].data() as Map<String, dynamic>;
                        return _TarjetaCliente(
                          id: clientes[i].id,
                          data: data,
                          onTap: () => _verDetalle(clientes[i].id, data),
                        );
                      },
                      childCount: clientes.length,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: (widget.sesion?.puedeGestionarClientes ?? true)
          ? FloatingActionButton.extended(
              heroTag: 'fab_clientes',
              onPressed: _abrirFormulario,
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text('Nuevo cliente'),
            )
          : null,
    ),
    );
  }

  // ── Barra de filtros de segmentación ─────────────────────────────────────────

  Widget _buildFiltrosBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // ── Botón filtros avanzados ──────────────────────────────────────
            GestureDetector(
              onTap: _abrirFiltrosAvanzados,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _numFiltrosAvanzados > 0
                      ? const Color(0xFF00796B)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _numFiltrosAvanzados > 0
                        ? const Color(0xFF00796B)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune,
                        size: 14,
                        color: _numFiltrosAvanzados > 0
                            ? Colors.white
                            : Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Filtros',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _numFiltrosAvanzados > 0
                            ? Colors.white
                            : Colors.grey[700],
                      ),
                    ),
                    if (_numFiltrosAvanzados > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_numFiltrosAvanzados',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00796B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Separador visual
            Container(width: 1, height: 22, color: Colors.grey[300]),
            const SizedBox(width: 6),

            // ── Chips de etiquetas predefinidas ──────────────────────────────
            ...kEtiquetasPredefinidas.map((tag) {
              final activo = _etiquetasActivas.contains(tag);
              final color = ClientesService.colorEtiqueta(tag);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      color: activo ? color : Colors.grey[700],
                      fontWeight:
                          activo ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  selected: activo,
                  onSelected: (v) => setState(
                      () => v ? _etiquetasActivas.add(tag) : _etiquetasActivas.remove(tag)),
                  selectedColor: color.withValues(alpha: 0.14),
                  checkmarkColor: color,
                  backgroundColor: Colors.grey[100],
                  side: BorderSide(
                      color: activo ? color : Colors.grey[300]!),
                  avatar: activo
                      ? null
                      : Icon(ClientesService.iconoEtiqueta(tag),
                          size: 13, color: Colors.grey[500]),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              );
            }),

            // ── Chips de filtros avanzados activos ───────────────────────────
            if (_minFacturacion != null)
              _chipFiltroActivo(
                _labelFacturacion(_minFacturacion!),
                () => setState(() => _minFacturacion = null),
              ),
            if (_mesesActividad != null)
              _chipFiltroActivo(
                _labelActividad(_mesesActividad!),
                () => setState(() => _mesesActividad = null),
              ),
            if (_localidadFiltro.isNotEmpty)
              _chipFiltroActivo(
                '📍 $_localidadFiltro',
                () => setState(() => _localidadFiltro = ''),
              ),

            // ── Botón limpiar todo ───────────────────────────────────────────
            if (_hayFiltrosActivos) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _limpiarFiltros,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear_all, size: 13, color: Colors.red[700]),
                      const SizedBox(width: 3),
                      Text('Limpiar',
                          style: TextStyle(
                              fontSize: 11, color: Colors.red[700])),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chipFiltroActivo(String label, VoidCallback onClear) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF00796B))),
        deleteIcon: const Icon(Icons.close, size: 13, color: Color(0xFF00796B)),
        onDeleted: onClear,
        backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.1),
        side: const BorderSide(color: Color(0xFF00796B)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      ),
    );
  }

  String _labelFacturacion(double min) {
    if (min >= 5000) return '>5.000 €';
    if (min >= 1000) return '>1.000 €';
    return '>500 €';
  }

  String _labelActividad(int meses) =>
      meses > 0 ? 'Activos ${meses}m' : 'Inactivos +${meses.abs()}m';

  Future<void> _abrirFiltrosAvanzados() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PanelFiltrosAvanzados(
        minFacturacion: _minFacturacion,
        mesesActividad: _mesesActividad,
        localidad: _localidadFiltro,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _minFacturacion = result['min_facturacion'] as double?;
        _mesesActividad = result['meses_actividad'] as int?;
        _localidadFiltro = (result['localidad'] as String?) ?? '';
      });
    }
  }

  Widget _buildResumen(List<QueryDocumentSnapshot> clientes) {
    final activos = clientes.where((c) {
      final d = c.data() as Map<String, dynamic>;
      return d['activo'] != false;
    }).length;

    final totalGastado = clientes.fold<double>(0, (sum, c) {
      final d = c.data() as Map<String, dynamic>;
      return sum + ((d['total_gastado'] ?? 0.0) as num).toDouble();
    });

    final frecuentes = clientes.where((c) {
      final d = c.data() as Map<String, dynamic>;
      return (d['numero_reservas'] ?? 0) >= 5;
    }).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00796B), Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'Total', valor: '${clientes.length}', icono: Icons.people),
          _StatChip(label: 'Activos', valor: '$activos', icono: Icons.check_circle),
          _StatChip(label: 'Frecuentes', valor: '$frecuentes', icono: Icons.star),
          _StatChip(label: 'Facturado', valor: '€${totalGastado.toStringAsFixed(0)}', icono: Icons.euro),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _filtro.isNotEmpty ? 'No se encontraron clientes' : 'No hay clientes registrados',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _filtro.isNotEmpty ? 'Prueba con otro término de búsqueda' : 'Pulsa el botón para añadir el primero',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Future<void> _verDetalle(String id, Map<String, dynamic> data) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleCliente(
        empresaId: widget.empresaId,
        id: id,
        data: data,
        puedeEditar: _puedeGestionar,
        onEditar: () => _abrirFormulario(id: id, data: data),
      ),
    );
  }

  Future<void> _abrirFormulario({String? id, Map<String, dynamic>? data}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioCliente(
        empresaId: widget.empresaId,
        id: id,
        data: data,
      ),
    );
  }
}

// ── TARJETA CLIENTE ───────────────────────────────────────────────────────────

class _TarjetaCliente extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _TarjetaCliente({required this.id, required this.data, required this.onTap});

  String get _iniciales {
    final nombre = data['nombre'] ?? '';
    final partes = nombre.split(' ');
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C';
  }

  @override
  Widget build(BuildContext context) {
    final reservas = data['numero_reservas'] ?? 0;
    final totalGastado = (data['total_gastado'] ?? 0.0 as num).toDouble();
    final esFrecuente = reservas >= 5;
    final esVip = totalGastado >= 1000;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _iniciales,
                    style: const TextStyle(color: Color(0xFF00796B), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['nombre'] ?? 'Sin nombre',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        if (esVip) const Icon(Icons.diamond, color: Color(0xFF7B1FA2), size: 16),
                        if (esFrecuente && !esVip) const Icon(Icons.star, color: Color(0xFFF57C00), size: 16),
                      ],
                    ),
                    if (data['telefono'] != null && data['telefono'] != '')
                      Text(data['telefono'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text('$reservas reservas', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        const SizedBox(width: 12),
                        Icon(Icons.euro, size: 12, color: Colors.grey[500]),
                        Text(totalGastado.toStringAsFixed(2), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                    // ── Etiquetas ─────────────────────────────────────────
                    if ((data['etiquetas'] as List?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: (data['etiquetas'] as List)
                            .take(4)
                            .map((e) {
                              final color = ClientesService.colorEtiqueta(e.toString());
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  e.toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ── DETALLE CLIENTE (tabbed bottom-sheet) ────────────────────────────────────

class _DetalleCliente extends StatelessWidget {
  final String empresaId;
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onEditar;
  final bool puedeEditar;

  const _DetalleCliente({
    required this.empresaId,
    required this.id,
    required this.data,
    required this.onEditar,
    this.puedeEditar = true,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return DefaultTabController(
      length: 2,
      child: Container(
        height: h * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Drag handle ──────────────────────────────────────────────
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Cabecera: avatar + nombre + botón editar ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        (data['nombre'] ?? 'C')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF00796B),
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['nombre'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ((data['correo'] ?? '').toString().isNotEmpty)
                          Text(
                            data['correo'],
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  if (puedeEditar)
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onEditar();
                      },
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar cliente',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── TabBar ───────────────────────────────────────────────────
            const TabBar(
              indicatorColor: Color(0xFF00796B),
              labelColor: Color(0xFF00796B),
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(fontWeight: FontWeight.w600),
              tabs: [
                Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Información'),
                Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Historial'),
              ],
            ),

            // ── TabBarView ────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 0 — Información
                  _TabInfoCliente(data: data),
                  // Tab 1 — Historial de facturas
                  _TabHistorialCliente(
                    empresaId: empresaId,
                    clienteId: id,
                    clienteData: data,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TAB INFO ──────────────────────────────────────────────────────────────────

class _TabInfoCliente extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TabInfoCliente({required this.data});

  @override
  Widget build(BuildContext context) {
    final totalGastado = ((data['total_gastado'] ?? 0.0) as num).toDouble();
    final reservas = data['numero_reservas'] ?? 0;
    final fmt = DateFormat('dd/MM/yyyy');
    final ultimaVisita = data['ultima_visita'] != null
        ? fmt.format(DateTime.parse(data['ultima_visita'].toString()))
        : 'Sin visitas';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats
          Row(
            children: [
              _InfoCard(
                label: 'Reservas',
                valor: '$reservas',
                icono: Icons.calendar_today,
                color: const Color(0xFF0D47A1),
              ),
              const SizedBox(width: 12),
              _InfoCard(
                label: 'Total gastado',
                valor: '€${totalGastado.toStringAsFixed(2)}',
                icono: Icons.euro,
                color: const Color(0xFF00796B),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _Fila(icono: Icons.phone, label: 'Teléfono', valor: data['telefono'] ?? 'No registrado'),
          if ((data['nif'] ?? '').toString().isNotEmpty)
            _Fila(icono: Icons.badge, label: 'NIF/CIF', valor: data['nif'].toString()),
          _Fila(icono: Icons.location_on, label: 'Dirección', valor: data['direccion'] ?? 'No registrada'),
          if ((data['localidad'] ?? '').toString().isNotEmpty)
            _Fila(icono: Icons.place, label: 'Localidad', valor: data['localidad'].toString()),
          _Fila(icono: Icons.access_time, label: 'Última visita', valor: ultimaVisita),
          if ((data['notas'] ?? '').toString().isNotEmpty)
            _Fila(icono: Icons.notes, label: 'Notas', valor: data['notas']),

          if (data['etiquetas'] != null &&
              (data['etiquetas'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: (data['etiquetas'] as List)
                  .map((e) => Chip(
                        label: Text(e.toString()),
                        backgroundColor:
                            const Color(0xFF0D47A1).withValues(alpha: 0.1),
                        labelStyle: const TextStyle(
                          color: Color(0xFF0D47A1),
                          fontSize: 12,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── TAB HISTORIAL ─────────────────────────────────────────────────────────────

class _TabHistorialCliente extends StatefulWidget {
  final String empresaId;
  final String clienteId;
  final Map<String, dynamic> clienteData;

  const _TabHistorialCliente({
    required this.empresaId,
    required this.clienteId,
    required this.clienteData,
  });

  @override
  State<_TabHistorialCliente> createState() => _TabHistorialClienteState();
}

class _TabHistorialClienteState extends State<_TabHistorialCliente>
    with AutomaticKeepAliveClientMixin {
  final _svc = FacturacionService();

  Map<String, dynamic>? _resumen;
  bool _cargando = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resumen = await _svc.resumenClienteFacturas(
        empresaId: widget.empresaId,
        clienteNombre: widget.clienteData['nombre'] ?? '',
        clienteCorreo: widget.clienteData['correo']?.toString(),
      );
      if (mounted) setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  // ── Formato moneda ──────────────────────────────────────────────────────────
  static final _fmtEur = NumberFormat.currency(locale: 'es_ES', symbol: '€');
  static final _fmtFecha = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final facturas = (_resumen!['facturas'] as List<Factura>);
    final totalFacturado = _resumen!['total_facturado'] as double;
    final pendienteCobro = _resumen!['pendiente_cobro'] as double;
    final ultimaFactura = _resumen!['ultima_factura'] as Factura?;
    final facturacionMensual =
        _resumen!['facturacion_mensual'] as Map<String, double>;

    if (facturas.isEmpty) {
      return _buildVacio();
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ── KPIs ──────────────────────────────────────────────────────────
          _buildKpis(totalFacturado, pendienteCobro, ultimaFactura),
          const SizedBox(height: 16),

          // ── Gráfico barras mensual ────────────────────────────────────────
          _buildGrafico(facturacionMensual),
          const SizedBox(height: 16),

          // ── Lista facturas ────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 16, color: Color(0xFF0D47A1)),
              const SizedBox(width: 6),
              Text(
                '${facturas.length} factura${facturas.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...facturas.map((f) => _TarjetaFacturaCliente(
                factura: f,
                empresaId: widget.empresaId,
              )),
        ],
      ),
    );
  }

  // ── Vacío ───────────────────────────────────────────────────────────────────
  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Sin facturas registradas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Las facturas emitidas a este cliente\naparecerán aquí automáticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── KPIs ────────────────────────────────────────────────────────────────────
  Widget _buildKpis(double total, double pendiente, Factura? ultima) {
    return Column(
      children: [
        Row(
          children: [
            _KpiCard(
              label: 'Total facturado',
              valor: _fmtEur.format(total),
              icono: Icons.euro_symbol,
              color: const Color(0xFF00796B),
            ),
            const SizedBox(width: 10),
            _KpiCard(
              label: 'Pendiente cobro',
              valor: _fmtEur.format(pendiente),
              icono: Icons.hourglass_empty,
              color: pendiente > 0
                  ? const Color(0xFFE65100)
                  : const Color(0xFF388E3C),
            ),
          ],
        ),
        if (ultima != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time,
                    size: 16, color: Color(0xFF0D47A1)),
                const SizedBox(width: 8),
                const Text(
                  'Última factura: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${ultima.numeroFactura} · ${_fmtFecha.format(ultima.fechaEmision)} · ${_fmtEur.format(ultima.total)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D47A1),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Gráfico de barras (últimos 6 meses) ─────────────────────────────────────
  Widget _buildGrafico(Map<String, double> datos) {
    final entradas = datos.entries.toList();
    final maxValor = entradas.fold(0.0, (m, e) => e.value > m ? e.value : m);
    final nombresMes = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    final grupos = entradas.asMap().entries.map((entry) {
      final idx = entry.key;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: entry.value.value,
            color: entry.value.value > 0
                ? const Color(0xFF00796B)
                : const Color(0xFFB0BEC5),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
        showingTooltipIndicators: entry.value.value > 0 ? [] : [],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 16, color: Color(0xFF00796B)),
              const SizedBox(width: 6),
              const Text(
                'Facturación últimos 6 meses',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF37474F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: maxValor == 0
                ? Center(
                    child: Text(
                      'Sin facturación en este período',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxValor * 1.25,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.grey.withValues(alpha: 0.15),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: grupos,
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= entradas.length) {
                                return const SizedBox.shrink();
                              }
                              final mesKey = entradas[idx].key;
                              final mesNum =
                                  int.tryParse(mesKey.split('-')[1]) ?? 1;
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  nombresMes[mesNum - 1],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF78909C),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (rod.toY == 0) return null;
                            return BarTooltipItem(
                              _fmtEur.format(rod.toY),
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── TARJETA FACTURA EN HISTORIAL CLIENTE ──────────────────────────────────────

class _TarjetaFacturaCliente extends StatelessWidget {
  final Factura factura;
  final String empresaId;

  const _TarjetaFacturaCliente({
    required this.factura,
    required this.empresaId,
  });

  static final _fmtEur = NumberFormat.currency(locale: 'es_ES', symbol: '€');
  static final _fmtFecha = DateFormat('dd/MM/yyyy');

  Color get _colorEstado {
    switch (factura.estado) {
      case EstadoFactura.pagada:
        return const Color(0xFF388E3C);
      case EstadoFactura.pendiente:
        return const Color(0xFFF57C00);
      case EstadoFactura.vencida:
        return const Color(0xFFD32F2F);
      case EstadoFactura.anulada:
        return Colors.grey;
      case EstadoFactura.rectificada:
        return const Color(0xFF7B1FA2);
    }
  }

  IconData get _iconoEstado {
    switch (factura.estado) {
      case EstadoFactura.pagada:
        return Icons.check_circle;
      case EstadoFactura.pendiente:
        return Icons.hourglass_empty;
      case EstadoFactura.vencida:
        return Icons.warning_amber;
      case EstadoFactura.anulada:
        return Icons.cancel;
      case EstadoFactura.rectificada:
        return Icons.swap_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleFacturaScreen(
              factura: factura,
              empresaId: empresaId,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icono estado
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _colorEstado.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconoEstado, color: _colorEstado, size: 20),
              ),
              const SizedBox(width: 12),

              // Número + fecha
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factura.numeroFactura,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _fmtFecha.format(factura.fechaEmision),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _colorEstado.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            factura.estado.etiqueta,
                            style: TextStyle(
                              color: _colorEstado,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Importe
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmtEur.format(factura.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── KPI CARD ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icono;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              valor,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icono;
  final Color color;

  const _InfoCard({required this.label, required this.valor, required this.icono, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(height: 6),
            Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;

  const _Fila({required this.icono, required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icono, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

// ── FORMULARIO CLIENTE ────────────────────────────────────────────────────────

class _FormularioCliente extends StatefulWidget {
  final String empresaId;
  final String? id;
  final Map<String, dynamic>? data;

  const _FormularioCliente({required this.empresaId, this.id, this.data});

  @override
  State<_FormularioCliente> createState() => _FormularioClienteState();
}

class _FormularioClienteState extends State<_FormularioCliente> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  late TextEditingController _nombreCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _correoCtrl;
  late TextEditingController _direccionCtrl;
  late TextEditingController _localidadCtrl;
  late TextEditingController _notasCtrl;
  final TextEditingController _etiquetaCustomCtrl = TextEditingController();
  List<String> _etiquetasSeleccionadas = [];
  bool _guardando = false;

  bool get _esEdicion => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.data?['nombre'] ?? '');
    _telefonoCtrl = TextEditingController(text: widget.data?['telefono'] ?? '');
    _correoCtrl = TextEditingController(text: widget.data?['correo'] ?? '');
    _direccionCtrl = TextEditingController(text: widget.data?['direccion'] ?? '');
    _localidadCtrl = TextEditingController(text: widget.data?['localidad'] ?? '');
    _notasCtrl = TextEditingController(text: widget.data?['notas'] ?? '');
    _etiquetasSeleccionadas = List<String>.from(widget.data?['etiquetas'] ?? []);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _direccionCtrl.dispose();
    _localidadCtrl.dispose();
    _notasCtrl.dispose();
    _etiquetaCustomCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final datos = {
        'nombre': _nombreCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'correo': _correoCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
        'localidad': _localidadCtrl.text.trim(),
        'notas': _notasCtrl.text.trim(),
        'etiquetas': _etiquetasSeleccionadas,
        'activo': true,
      };

      final ref = _firestore.collection('empresas').doc(widget.empresaId).collection('clientes');

      if (_esEdicion) {
        await ref.doc(widget.id).update(datos);
      } else {
        await ref.add({
          ...datos,
          'total_gastado': 0.0,
          'numero_reservas': 0,
          'fecha_registro': DateTime.now().toIso8601String(),
        });
        // Registrar etiquetas custom en el catálogo de la empresa
        final svc = ClientesService();
        for (final tag in _etiquetasSeleccionadas) {
          if (!kEtiquetasPredefinidas.contains(tag)) {
            unawaited(svc.agregarEtiquetaCustom(widget.empresaId, tag));
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esEdicion ? '✅ Cliente actualizado' : '✅ Cliente registrado'),
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _esEdicion ? 'Editar Cliente' : 'Nuevo Cliente',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombreCtrl,
                decoration: _inputDeco('Nombre completo *', Icons.person),
                validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: _inputDeco('Teléfono', Icons.phone),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _correoCtrl,
                decoration: _inputDeco('Correo electrónico', Icons.email),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _direccionCtrl,
                decoration: _inputDeco('Dirección', Icons.location_on),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _localidadCtrl,
                decoration: _inputDeco('Localidad / Ciudad', Icons.place),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notasCtrl,
                decoration: _inputDeco('Notas internas', Icons.notes),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // ── Etiquetas ──────────────────────────────────────────────────
              _buildSeccionEtiquetas(),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _guardando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_esEdicion ? 'Guardar cambios' : 'Registrar cliente', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sección etiquetas ─────────────────────────────────────────────────────

  Widget _buildSeccionEtiquetas() {
    final customTags = _etiquetasSeleccionadas
        .where((e) => !kEtiquetasPredefinidas.contains(e))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Etiquetas',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 3),
        Text(
          'Segmenta al cliente con etiquetas predefinidas o crea las tuyas',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 12),

        // Predefinidas
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: kEtiquetasPredefinidas.map((tag) {
            final activa = _etiquetasSeleccionadas.contains(tag);
            final color = ClientesService.colorEtiqueta(tag);
            return FilterChip(
              label: Text(tag,
                  style: TextStyle(
                    fontSize: 13,
                    color: activa ? color : Colors.grey[700],
                    fontWeight:
                        activa ? FontWeight.w600 : FontWeight.normal,
                  )),
              selected: activa,
              avatar: Icon(ClientesService.iconoEtiqueta(tag),
                  size: 14,
                  color: activa ? color : Colors.grey[500]),
              onSelected: (v) => setState(() =>
                  v ? _etiquetasSeleccionadas.add(tag) : _etiquetasSeleccionadas.remove(tag)),
              selectedColor: color.withValues(alpha: 0.14),
              checkmarkColor: color,
              backgroundColor: Colors.grey[100],
              side: BorderSide(color: activa ? color : Colors.grey[300]!),
            );
          }).toList(),
        ),

        // Etiquetas personalizadas seleccionadas
        if (customTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: customTags
                .map((tag) => Chip(
                      label: Text(tag,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[800])),
                      deleteIcon:
                          const Icon(Icons.close, size: 13),
                      onDeleted: () => setState(
                          () => _etiquetasSeleccionadas.remove(tag)),
                      backgroundColor: Colors.grey[100],
                      side: BorderSide(color: Colors.grey[350]!),
                    ))
                .toList(),
          ),
        ],

        const SizedBox(height: 10),
        // Añadir etiqueta personalizada
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _etiquetaCustomCtrl,
                decoration: InputDecoration(
                  hintText: 'Nueva etiqueta personalizada...',
                  prefixIcon:
                      const Icon(Icons.label_outline, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _agregarEtiquetaCustom(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _agregarEtiquetaCustom,
              icon: const Icon(Icons.add_circle,
                  color: Color(0xFF00796B), size: 28),
              tooltip: 'Añadir etiqueta',
            ),
          ],
        ),
      ],
    );
  }

  void _agregarEtiquetaCustom() {
    final tag = _etiquetaCustomCtrl.text.trim();
    if (tag.isNotEmpty && !_etiquetasSeleccionadas.contains(tag)) {
      setState(() {
        _etiquetasSeleccionadas.add(tag);
        _etiquetaCustomCtrl.clear();
      });
    }
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ── PANEL FILTROS AVANZADOS ───────────────────────────────────────────────────

class _PanelFiltrosAvanzados extends StatefulWidget {
  final double? minFacturacion;
  final int? mesesActividad;
  final String localidad;

  const _PanelFiltrosAvanzados({
    this.minFacturacion,
    this.mesesActividad,
    required this.localidad,
  });

  @override
  State<_PanelFiltrosAvanzados> createState() =>
      _PanelFiltrosAvanzadosState();
}

class _PanelFiltrosAvanzadosState extends State<_PanelFiltrosAvanzados> {
  double? _minFacturacion;
  int? _mesesActividad;
  late TextEditingController _localidadCtrl;

  @override
  void initState() {
    super.initState();
    _minFacturacion = widget.minFacturacion;
    _mesesActividad = widget.mesesActividad;
    _localidadCtrl = TextEditingController(text: widget.localidad);
  }

  @override
  void dispose() {
    _localidadCtrl.dispose();
    super.dispose();
  }

  bool get _hayAlgunFiltro =>
      _minFacturacion != null ||
      _mesesActividad != null ||
      _localidadCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filtros avanzados',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                if (_hayAlgunFiltro)
                  TextButton(
                    onPressed: () => setState(() {
                      _minFacturacion = null;
                      _mesesActividad = null;
                      _localidadCtrl.clear();
                    }),
                    child: const Text('Limpiar todo',
                        style: TextStyle(color: Color(0xFF00796B))),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Sección: Volumen de facturación ──────────────────────────────
            _seccion(
              titulo: 'Volumen de facturación',
              icono: Icons.euro_symbol,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: kOpcionesFacturacion
                    .map((op) => ChoiceChip(
                          label: Text(op.label),
                          selected: _minFacturacion == op.value,
                          onSelected: (v) => setState(
                              () => _minFacturacion = v ? op.value : null),
                          selectedColor: const Color(0xFF00796B)
                              .withValues(alpha: 0.14),
                          checkmarkColor: const Color(0xFF00796B),
                          labelStyle: TextStyle(
                            color: _minFacturacion == op.value
                                ? const Color(0xFF00796B)
                                : Colors.grey[700],
                            fontWeight: _minFacturacion == op.value
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ))
                    .toList(),
              ),
            ),

            // ── Sección: Última actividad ────────────────────────────────────
            _seccion(
              titulo: 'Última actividad',
              icono: Icons.access_time,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: kOpcionesActividad
                    .map((op) {
                      final esInactivo = op.value < 0;
                      final colorActivo = esInactivo
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF0D47A1);
                      return ChoiceChip(
                        label: Text(op.label),
                        selected: _mesesActividad == op.value,
                        onSelected: (v) => setState(
                            () => _mesesActividad = v ? op.value : null),
                        selectedColor:
                            colorActivo.withValues(alpha: 0.12),
                        checkmarkColor: colorActivo,
                        labelStyle: TextStyle(
                          color: _mesesActividad == op.value
                              ? colorActivo
                              : Colors.grey[700],
                          fontWeight: _mesesActividad == op.value
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      );
                    })
                    .toList(),
              ),
            ),

            // ── Sección: Localidad ───────────────────────────────────────────
            _seccion(
              titulo: 'Localidad',
              icono: Icons.place,
              child: TextField(
                controller: _localidadCtrl,
                decoration: InputDecoration(
                  hintText: 'Filtrar por ciudad o localidad...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _localidadCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _localidadCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // ── Botón Aplicar ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, {
                  'min_facturacion': _minFacturacion,
                  'meses_actividad': _mesesActividad,
                  'localidad': _localidadCtrl.text.trim(),
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check),
                label: const Text('Aplicar filtros',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccion({
    required String titulo,
    required IconData icono,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 16, color: const Color(0xFF00796B)),
            const SizedBox(width: 6),
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF37474F))),
          ],
        ),
        const SizedBox(height: 10),
        child,
        const SizedBox(height: 16),
        Divider(color: Colors.grey[200]),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icono;

  const _StatChip({required this.label, required this.valor, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}







