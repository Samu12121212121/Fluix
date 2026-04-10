import 'package:flutter/material.dart';
import '../../../domain/modelos/nomina.dart';
import '../../../services/antiguedad_calculator.dart';
import '../../finiquitos/pantallas/nuevo_finiquito_form.dart';
import '../../finiquitos/pantallas/finiquitos_screen.dart';
import '../../vacaciones/pantallas/nueva_solicitud_form.dart';
import '../../../widgets/saldo_vacaciones_widget.dart';
import '../pantallas/configurar_modulos_empleado_screen.dart';
import 'avatar_empleado_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA EMPLEADO
// ─────────────────────────────────────────────────────────────────────────────

class TarjetaEmpleado extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final bool esPropietario;
  final String empresaId;
  final VoidCallback onEditar;
  final VoidCallback onToggleActivo;
  final VoidCallback? onDatosNomina;
  final VoidCallback? onEmbargos;
  final VoidCallback? onFoto;

  const TarjetaEmpleado({
    super.key,
    required this.id,
    required this.data,
    required this.esPropietario,
    required this.empresaId,
    required this.onEditar,
    required this.onToggleActivo,
    this.onDatosNomina,
    this.onEmbargos,
    this.onFoto,
  });

  Color get _colorRol {
    switch (data['rol']) {
      case 'propietario': return const Color(0xFF7B1FA2);
      case 'admin':       return const Color(0xFF0D47A1);
      default:            return const Color(0xFF00796B);
    }
  }

  String get _nombreRol {
    switch (data['rol']) {
      case 'propietario': return 'Propietario';
      case 'admin':       return 'Administrador';
      default:            return 'Staff';
    }
  }

  String get _iniciales {
    final nombre = (data['nombre'] ?? '') as String;
    final partes = nombre.split(' ');
    if (partes.length >= 2 && partes[0].isNotEmpty && partes[1].isNotEmpty) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E';
  }

  @override
  Widget build(BuildContext context) {
    final activo  = data['activo'] ?? true;
    final fotoUrl = data['foto_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: esPropietario ? onFoto : null,
              child: AvatarEmpleado(
                fotoUrl: fotoUrl,
                iniciales: _iniciales,
                color: _colorRol,
                size: 50,
                mostrarBotonCamara: esPropietario,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(data['nombre'] ?? 'Sin nombre',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (!activo) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text('Inactivo', style: TextStyle(fontSize: 10, color: Colors.red[700])),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                if (data['correo'] != null)
                  Text(data['correo'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                if (data['telefono'] != null && data['telefono'] != '')
                  Text(data['telefono'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _colorRol.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_nombreRol,
                      style: TextStyle(color: _colorRol, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            if (esPropietario)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (v) {
                  try {
                    switch (v) {
                      case 'editar':
                        onEditar();
                        break;
                      case 'toggle':
                        onToggleActivo();
                        break;
                      case 'nomina':
                        onDatosNomina?.call();
                        break;
                      case 'embargos':
                        onEmbargos?.call();
                        break;
                      case 'foto':
                        onFoto?.call();
                        break;
                      case 'finiquito':
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => NuevoFiniquitoForm(
                                empresaId: empresaId, empleadoIdPreseleccionado: id)));
                        break;
                      case 'ver_finiquitos':
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => FiniquitosScreen(empresaId: empresaId, empleadoIdFiltro: id)));
                        break;
                      case 'vacaciones':
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          useSafeArea: true,
                          builder: (_) => NuevaSolicitudForm(empresaId: empresaId, empleadoIdFijo: id),
                        );
                        break;
                      case 'ver_saldo_vacaciones':
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Vacaciones — ${data['nombre'] ?? ''}'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: SaldoVacacionesWidget(
                                  empresaId: empresaId, empleadoId: id, anio: DateTime.now().year),
                            ),
                            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
                          ),
                        );
                        break;
                      case 'ver_antiguedad':
                        _mostrarDialogoAntiguedad(context, id, data);
                        break;
                      case 'modulos':
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ConfigurarModulosEmpleadoScreen(
                            empresaId: empresaId,
                            empleadoUid: id,
                            empleadoNombre: data['nombre'] ?? 'Empleado',
                          ),
                        ));
                        break;
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('❌ Error al ejecutar acción: $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'editar',
                      child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'), contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'foto',
                      child: ListTile(leading: Icon(Icons.add_a_photo, color: Color(0xFF00796B)),
                          title: Text('Foto de perfil'), contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'modulos',
                      child: ListTile(leading: Icon(Icons.apps, color: Color(0xFF1976D2)),
                          title: Text('Configurar módulos'), contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'nomina',
                      child: ListTile(leading: Icon(Icons.payments, color: Color(0xFF0D47A1)),
                          title: Text('Datos nómina'), contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'embargos',
                      child: ListTile(leading: Icon(Icons.gavel, color: Color(0xFFB71C1C)),
                          title: Text('Embargos judiciales'), contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'finiquito',
                      child: ListTile(leading: Icon(Icons.description, color: Colors.deepOrange),
                          title: Text('Generar finiquito'), contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'ver_finiquitos',
                      child: ListTile(leading: Icon(Icons.folder_open, color: Colors.orange),
                          title: Text('Ver finiquitos'), contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'vacaciones',
                      child: ListTile(leading: Icon(Icons.beach_access, color: Color(0xFF00796B)),
                          title: Text('Solicitar vacaciones'), contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'ver_saldo_vacaciones',
                      child: ListTile(leading: Icon(Icons.calendar_month, color: Color(0xFF26A69A)),
                          title: Text('Saldo vacaciones'), contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'ver_antiguedad',
                      child: ListTile(leading: Icon(Icons.workspace_premium, color: Color(0xFF5D4037)),
                          title: Text('Ver antigüedad'), contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(value: 'toggle',
                      child: ListTile(
                          leading: Icon(activo ? Icons.block : Icons.check_circle,
                              color: activo ? Colors.red : Colors.green),
                          title: Text(activo ? 'Desactivar' : 'Activar'),
                          contentPadding: EdgeInsets.zero)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoAntiguedad(
      BuildContext context, String empleadoId, Map<String, dynamic> data) {
    final datosNomina = data['datos_nomina'] as Map<String, dynamic>?;
    final nombre = data['nombre'] as String? ?? 'Empleado';

    if (datosNomina == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este empleado no tiene datos de nómina configurados')));
      return;
    }

    final config   = DatosNominaEmpleado.fromMap(datosNomina);
    final sector   = config.sectorEmpresa;
    final convenio = AntiguedadCalculator.normalizarConvenio(sector);
    final fechaInicio = config.fechaInicioContrato;

    if (fechaInicio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fecha de inicio de contrato no configurada')));
      return;
    }

    final resultado = AntiguedadCalculator.calcular(
      fechaInicio: fechaInicio,
      fechaCalculo: DateTime.now(),
      convenio: convenio,
      salarioBase: config.salarioBrutoAnual / 12,
      nivelCategoriaCarnicas: config.nivelCategoriaCarnicas,
    );

    final proximoCambio = AntiguedadCalculator.calcularProximoCambio(
        fechaInicioContrato: fechaInicio, convenio: convenio);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.workspace_premium, color: Color(0xFF5D4037)),
          const SizedBox(width: 8),
          Expanded(child: Text('Antigüedad — $nombre', overflow: TextOverflow.ellipsis)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _infoRow('Fecha inicio contrato',
              '${fechaInicio.day.toString().padLeft(2, '0')}/${fechaInicio.month.toString().padLeft(2, '0')}/${fechaInicio.year}'),
          _infoRow('Años completos', '${resultado.aniosCompletos}'),
          _infoRow('Convenio', convenio.isEmpty ? 'Sin convenio' : convenio),
          if (resultado.importe > 0) ...[
            const Divider(),
            _infoRow('Tramos cumplidos', '${resultado.tramosCumplidos} ${resultado.tipoTramo}s'),
            _infoRow('Plus antigüedad', '${resultado.importe.toStringAsFixed(2)} €/mes'),
          ],
          if (resultado.importe == 0 && convenio.isNotEmpty) ...[
            const Divider(),
            Text(
              convenio == AntiguedadCalculator.convPeluqueria ||
                      convenio == AntiguedadCalculator.convVeterinarios
                  ? 'Este convenio no tiene plus de antigüedad automático.'
                  : 'Aún no se han cumplido tramos de antigüedad.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
          if (config.antiguedadManual) ...[
            const Divider(),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(children: [
                const Icon(Icons.edit, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    'Antigüedad manual: ${config.antiguedadManualImporte.toStringAsFixed(2)} €/mes',
                    style: const TextStyle(fontSize: 13))),
              ]),
            ),
          ],
          if (proximoCambio != null) ...[
            const Divider(),
            _infoRow('Próximo cambio',
                '${proximoCambio.day.toString().padLeft(2, '0')}/${proximoCambio.month.toString().padLeft(2, '0')}/${proximoCambio.year}'),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Text(value, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT CHIP EMPLEADOS
// ─────────────────────────────────────────────────────────────────────────────

class EmpleadosStatChip extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icono;

  const EmpleadosStatChip({super.key, required this.label, required this.valor, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icono, color: Colors.white70, size: 18),
      const SizedBox(height: 4),
      Text(valor, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ]);
  }
}




