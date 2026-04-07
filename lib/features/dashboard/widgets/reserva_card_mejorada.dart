import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReservaCardMejorada extends StatelessWidget {
  final Map<String, dynamic> data;
  final String empresaId;

  const ReservaCardMejorada({
    super.key,
    required this.data,
    required this.empresaId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _resolverNombres(),
      builder: (context, snapshot) {
        final nombres = snapshot.data ?? {};
        final nombreCliente = nombres['cliente'] ?? 'Cargando...';
        final nombreServicio = nombres['servicio'] ?? 'Cargando...';
        final nombreEmpleado = nombres['empleado'] ?? '';

        return _buildReservaCard(context, nombreCliente, nombreServicio, nombreEmpleado);
      },
    );
  }

  /// Resolver nombres reales de cliente, servicio y empleado
  Future<Map<String, String>> _resolverNombres() async {
    try {
      final clienteId = data['cliente_id']?.toString() ?? '';
      final servicioId = data['servicio_id']?.toString() ?? '';
      final empleadoId = data['empleado_asignado']?.toString() ?? '';

      final futures = <Future<String>>[];

      // Resolver nombre del cliente
      if (clienteId.isNotEmpty) {
        futures.add(_obtenerNombreCliente(clienteId));
      } else {
        futures.add(Future.value(data['cliente']?.toString() ?? 'Sin cliente'));
      }

      // Resolver nombre del servicio
      if (servicioId.isNotEmpty) {
        futures.add(_obtenerNombreServicio(servicioId));
      } else {
        futures.add(Future.value(data['servicio']?.toString() ?? 'Sin servicio'));
      }

      // Resolver nombre del empleado
      if (empleadoId.isNotEmpty) {
        futures.add(_obtenerNombreEmpleado(empleadoId));
      } else {
        futures.add(Future.value(''));
      }

      final resultados = await Future.wait(futures);

      return {
        'cliente': resultados[0],
        'servicio': resultados[1],
        'empleado': resultados[2],
      };
    } catch (e) {
      print('❌ Error resolviendo nombres: $e');
      return {
        'cliente': data['cliente']?.toString() ?? 'Cliente',
        'servicio': data['servicio']?.toString() ?? 'Servicio',
        'empleado': '',
      };
    }
  }

  Future<String> _obtenerNombreCliente(String clienteId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('clientes')
          .doc(clienteId)
          .get();

      if (doc.exists) {
        return doc.data()?['nombre']?.toString() ?? 'Cliente $clienteId';
      }
      return 'Cliente $clienteId';
    } catch (e) {
      return 'Cliente $clienteId';
    }
  }

  Future<String> _obtenerNombreServicio(String servicioId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('servicios')
          .doc(servicioId)
          .get();

      if (doc.exists) {
        final nombre = doc.data()?['nombre']?.toString() ?? 'Servicio';
        final precio = doc.data()?['precio'];
        if (precio != null) {
          return '$nombre (€${precio.toString()})';
        }
        return nombre;
      }
      return 'Servicio $servicioId';
    } catch (e) {
      return 'Servicio $servicioId';
    }
  }

  Future<String> _obtenerNombreEmpleado(String empleadoId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('empleados')
          .doc(empleadoId)
          .get();

      if (doc.exists) {
        return doc.data()?['nombre']?.toString() ?? 'Empleado';
      }
      return 'Empleado';
    } catch (e) {
      return 'Empleado';
    }
  }

  Widget _buildReservaCard(BuildContext context, String nombreCliente, String nombreServicio, String nombreEmpleado) {
    final estado = data['estado'] ?? 'PENDIENTE';
    final notas = data['notas']?.toString() ?? '';

    // Combinar fecha y hora_inicio para crear fechaHora
    final fechaTimestamp = data['fecha'] as Timestamp?;
    final horaInicio = data['hora_inicio'] ?? '09:00';
    DateTime fechaHora;

    if (fechaTimestamp != null) {
      final fecha = fechaTimestamp.toDate();
      final partesHora = horaInicio.split(':');
      final hora = int.tryParse(partesHora[0]) ?? 9;
      final minutos = int.tryParse(partesHora[1]) ?? 0;
      fechaHora = DateTime(fecha.year, fecha.month, fecha.day, hora, minutos);
    } else {
      fechaHora = DateTime.now();
    }

    Color colorEstado;
    IconData iconoEstado;
    String textoEstado;

    switch (estado) {
      case 'CONFIRMADA':
        colorEstado = const Color(0xFF4CAF50);
        iconoEstado = Icons.check_circle;
        textoEstado = 'Confirmada';
        break;
      case 'CANCELADA':
        colorEstado = const Color(0xFFF44336);
        iconoEstado = Icons.cancel;
        textoEstado = 'Cancelada';
        break;
      case 'COMPLETADA':
        colorEstado = const Color(0xFF9E9E9E);
        iconoEstado = Icons.task_alt;
        textoEstado = 'Completada';
        break;
      default: // PENDIENTE
        colorEstado = const Color(0xFFF57C00);
        iconoEstado = Icons.pending;
        textoEstado = 'Pendiente';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorEstado.withValues(alpha: 0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con cliente y estado
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nombreCliente,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorEstado.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconoEstado, size: 14, color: colorEstado),
                        const SizedBox(width: 4),
                        Text(
                          textoEstado,
                          style: TextStyle(
                            color: colorEstado,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Servicio
              Row(
                children: [
                  Icon(Icons.design_services, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nombreServicio,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fecha y hora
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MM/yyyy').format(fechaHora),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    horaInicio,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),

              // Empleado si existe
              if (nombreEmpleado.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      nombreEmpleado,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],

              // Notas si existen
              if (notas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notes, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notas,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Indicador de Dama Juana
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🏪 Dama Juana Guadalajara',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF1976D2),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
