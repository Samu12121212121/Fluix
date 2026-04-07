import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/auth/auditoria_service.dart';
import '../../../core/utils/permisos_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA — Auditoría de accesos (solo Propietario)
// ─────────────────────────────────────────────────────────────────────────────

class PantallaAuditoria extends StatefulWidget {
  final String empresaId;
  const PantallaAuditoria({super.key, required this.empresaId});

  @override
  State<PantallaAuditoria> createState() => _PantallaAuditoriaState();
}

class _PantallaAuditoriaState extends State<PantallaAuditoria> {
  final _svc = AuditoriaService();
  String? _filtroUsuario;
  TipoEventoAuditoria? _filtroTipo;
  bool _hayFallidosRecientes = false;

  @override
  void initState() {
    super.initState();
    _svc.hayLoginsFallidosRecientes(widget.empresaId).then((v) {
      if (mounted) setState(() => _hayFallidosRecientes = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(children: [
          const Text('Auditoría de accesos',
              style: TextStyle(fontWeight: FontWeight.w700)),
          if (_hayFallidosRecientes) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('⚠️ Fallos 24h',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _mostrarFiltros,
          ),
        ],
      ),
      body: Column(
        children: [
          // Chips de filtro activos
          if (_filtroTipo != null || _filtroUsuario != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                if (_filtroTipo != null)
                  Chip(
                    label: Text(_filtroTipo!.nombre),
                    onDeleted: () => setState(() => _filtroTipo = null),
                    backgroundColor:
                        const Color(0xFF0D47A1).withValues(alpha: 0.1),
                  ),
                if (_filtroUsuario != null) ...[
                  const SizedBox(width: 6),
                  Chip(
                    label: Text('Usuario: $_filtroUsuario'),
                    onDeleted: () => setState(() => _filtroUsuario = null),
                    backgroundColor:
                        const Color(0xFF0D47A1).withValues(alpha: 0.1),
                  ),
                ],
              ]),
            ),

          // Lista de eventos
          Expanded(
            child: StreamBuilder<List<EventoAuditoria>>(
              stream: _svc.eventosStream(widget.empresaId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var eventos = snap.data ?? [];

                // Aplicar filtros
                if (_filtroTipo != null) {
                  eventos =
                      eventos.where((e) => e.tipo == _filtroTipo).toList();
                }
                if (_filtroUsuario != null) {
                  eventos = eventos
                      .where((e) =>
                          e.email.contains(_filtroUsuario!) ||
                          (e.usuarioId?.contains(_filtroUsuario!) ?? false))
                      .toList();
                }

                if (eventos.isEmpty) {
                  return Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('Sin eventos registrados',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 16)),
                        ]),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: eventos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) => _TarjetaEvento(evento: eventos[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarFiltros() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrar eventos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),

              const Text('Tipo de evento',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: TipoEventoAuditoria.values.map((t) {
                  final sel = _filtroTipo == t;
                  return FilterChip(
                    label: Text('${t.emoji} ${t.nombre}'),
                    selected: sel,
                    onSelected: (_) {
                      setS(() {});
                      setState(() =>
                          _filtroTipo = sel ? null : t);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA DE EVENTO
// ─────────────────────────────────────────────────────────────────────────────

class _TarjetaEvento extends StatelessWidget {
  final EventoAuditoria evento;

  const _TarjetaEvento({required this.evento});

  Color get _colorBorde {
    switch (evento.tipo) {
      case TipoEventoAuditoria.loginFallido:
        return Colors.red;
      case TipoEventoAuditoria.loginOk:
        return Colors.green;
      case TipoEventoAuditoria.logout:
        return Colors.orange;
      case TipoEventoAuditoria.sesionExpirada:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('dd/MM/yyyy HH:mm:ss').format(evento.timestamp);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: _colorBorde, width: 4)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(evento.tipo.emoji,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  evento.email,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Text(fecha,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _chip(evento.tipo.nombre, _colorBorde),
              const SizedBox(width: 6),
              _chip(evento.metodo.name, Colors.blueGrey),
              if (evento.rol != null) ...[
                const SizedBox(width: 6),
                _chip(evento.rol!, Colors.indigo),
              ],
            ]),
            if (evento.mensajeError != null) ...[
              const SizedBox(height: 4),
              Text('⚠️ ${evento.mensajeError}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.red)),
            ],
            const SizedBox(height: 4),
            Text(
              '${evento.dispositivo['modelo'] ?? ''} · '
              '${evento.dispositivo['os'] ?? ''} · '
              'v${evento.dispositivo['version_app'] ?? ''}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );
}

