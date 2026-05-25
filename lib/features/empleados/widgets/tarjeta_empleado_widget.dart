import 'package:flutter/material.dart';
import '../../../domain/modelos/nomina.dart';
import '../../../services/antiguedad_calculator.dart';
import '../../finiquitos/pantallas/nuevo_finiquito_form.dart';
import '../../finiquitos/pantallas/finiquitos_screen.dart';
import '../../vacaciones/pantallas/nueva_solicitud_form.dart';
import '../../../widgets/saldo_vacaciones_widget.dart';
import '../pantallas/configurar_modulos_empleado_screen.dart';
import 'avatar_empleado_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  void _mostrarOpciones(BuildContext context) {
    final activo = data['activo'] ?? true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(data['nombre'] ?? 'Empleado',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _colorRol.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_nombreRol,
                          style: TextStyle(color: _colorRol, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _opcionItem(ctx, Icons.edit, 'Editar empleado', Colors.blue, () => onEditar(), parentCtx: context),
              _opcionItem(ctx, Icons.badge_outlined, 'Editar DNI/NIE', const Color(0xFF455A64), () {
                _mostrarDialogoDni(context);
              }, parentCtx: context),
              _opcionItem(ctx, Icons.add_a_photo, 'Foto de perfil', const Color(0xFF00796B), () => onFoto?.call(), parentCtx: context),
              _opcionItem(ctx, Icons.apps, 'Configurar módulos', const Color(0xFF1976D2), () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ConfigurarModulosEmpleadoScreen(
                    empresaId: empresaId,
                    empleadoUid: id,
                    empleadoNombre: data['nombre'] ?? 'Empleado',
                  ),
                ));
              }, parentCtx: context),
              _opcionItem(ctx, Icons.description, 'Generar finiquito', Colors.deepOrange, () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NuevoFiniquitoForm(
                        empresaId: empresaId, empleadoIdPreseleccionado: id)));
              }, parentCtx: context),
              _opcionItem(ctx, Icons.folder_open, 'Ver finiquitos', Colors.orange, () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FiniquitosScreen(empresaId: empresaId, empleadoIdFiltro: id)));
              }, parentCtx: context),
              _opcionItem(ctx, Icons.beach_access, 'Solicitar vacaciones', const Color(0xFF00796B), () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  useSafeArea: true,
                  builder: (_) => NuevaSolicitudForm(empresaId: empresaId, empleadoIdFijo: id),
                );
              }, parentCtx: context),
              _opcionItem(ctx, Icons.calendar_month, 'Saldo vacaciones', const Color(0xFF26A69A), () {
                showDialog(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: Text('Vacaciones — ${data['nombre'] ?? ''}'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: SaldoVacacionesWidget(
                          empresaId: empresaId, empleadoId: id, anio: DateTime.now().year),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cerrar'))],
                  ),
                );
              }, parentCtx: context),
              _opcionItem(ctx, Icons.workspace_premium, 'Ver antigüedad', const Color(0xFF5D4037),
                      () => _mostrarDialogoAntiguedad(context, id, data), parentCtx: context),
              _opcionItem(
                ctx,
                activo ? Icons.block : Icons.check_circle,
                activo ? 'Desactivar empleado' : 'Activar empleado',
                activo ? Colors.red : Colors.green,
                    () => onToggleActivo(),
                parentCtx: context,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcionItem(BuildContext ctx, IconData icono, String titulo, Color color, VoidCallback accion, {BuildContext? parentCtx}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icono, color: color, size: 20),
      ),
      title: Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: () async {
        Navigator.pop(ctx);
        await Future.delayed(const Duration(milliseconds: 50));
        try {
          accion();
        } catch (e) {
          final sc = parentCtx != null && parentCtx.mounted
              ? ScaffoldMessenger.of(parentCtx)
              : null;
          sc?.showSnackBar(SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activo  = data['activo'] ?? true;
    final fotoUrl = data['foto_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: esPropietario ? () => _mostrarOpciones(context) : null,
        borderRadius: BorderRadius.circular(12),
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
                  if (data['dni'] != null && data['dni'] != '')
                    Row(children: [
                      Icon(Icons.badge_outlined, size: 11, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text(data['dni'],
                          style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ]),
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
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoDni(BuildContext context) {
    final ctrl = TextEditingController(
      text: data['dni'] as String? ?? '',
    );
    String? errorTexto;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.badge_outlined, color: Color(0xFF455A64)),
            SizedBox(width: 8),
            Text('DNI / NIE'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Necesario para el CSV de Inspección de Trabajo.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 9,
                decoration: InputDecoration(
                  labelText: 'DNI o NIE',
                  hintText: '12345678A',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  counterText: '',
                  errorText: errorTexto,
                ),
                onChanged: (_) {
                  if (errorTexto != null) setS(() => errorTexto = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final dni = ctrl.text.trim().toUpperCase();
                if (dni.isEmpty) {
                  setS(() => errorTexto = 'El DNI no puede estar vacío');
                  return;
                }
                if (!_validarDni(dni)) {
                  setS(() => errorTexto = 'Formato no válido (ej: 12345678A)');
                  return;
                }
                try {
                  await FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(id)
                      .update({'dni': dni});
                  if (ctx2.mounted) Navigator.pop(ctx2);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('DNI guardado correctamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  setS(() => errorTexto = 'Error al guardar: $e');
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  bool _validarDni(String dni) {
    final letras = 'TRWAGMYFPDXBNJZSQVHLCKE';
    final regexDni = RegExp(r'^[0-9]{8}[A-Z]$');
    final regexNie = RegExp(r'^[XYZ][0-9]{7}[A-Z]$');

    if (regexDni.hasMatch(dni)) {
      final numero = int.parse(dni.substring(0, 8));
      return dni[8] == letras[numero % 23];
    }

    if (regexNie.hasMatch(dni)) {
      final prefijo = {'X': '0', 'Y': '1', 'Z': '2'}[dni[0]]!;
      final numero = int.parse('$prefijo${dni.substring(1, 8)}');
      return dni[8] == letras[numero % 23];
    }

    return false;
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
                border: Border.all(color: Colors.amber[200] ?? Colors.amber),
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