import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ═════════════════════════════════════════════════════════════════════════════
// CALENDARIO FISCAL — Alertas de vencimientos AEAT
// ═════════════════════════════════════════════════════════════════════════════

class CalendarioFiscalScreen extends StatelessWidget {
  final String empresaId;

  const CalendarioFiscalScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final vencimientos = _generarVencimientos(now.year);
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calendario Fiscal'),
            Text(
              'Vencimientos AEAT ${now.year}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: vencimientos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final v = vencimientos[i];
          final vencido = v.fecha.isBefore(now);
          final proximoVencimiento = v.fecha.isAfter(now) && 
                                   v.fecha.difference(now).inDays <= 10;
          
          return Card(
            color: vencido 
                ? Colors.red.shade50 
                : proximoVencimiento 
                    ? Colors.orange.shade50 
                    : null,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: vencido 
                    ? Colors.red.shade100 
                    : proximoVencimiento 
                        ? Colors.orange.shade100 
                        : Colors.blue.shade100,
                child: Text(
                  v.modelo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: vencido 
                        ? Colors.red.shade700 
                        : proximoVencimiento 
                            ? Colors.orange.shade700 
                            : Colors.blue.shade700,
                  ),
                ),
              ),
              title: Text(
                v.descripcion,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vence: ${DateFormat('dd/MM/yyyy').format(v.fecha)}'),
                  const SizedBox(height: 2),
                  Text(
                    v.obligacion,
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              trailing: vencido 
                  ? Icon(Icons.error, color: Colors.red.shade600, size: 20)
                  : proximoVencimiento
                      ? Icon(Icons.warning, color: Colors.orange.shade600, size: 20)
                      : Icon(Icons.schedule, color: Colors.grey.shade500, size: 20),
            ),
          );
        },
      ),
    );
  }

  List<VencimientoFiscal> _generarVencimientos(int anio) {
    final vencimientos = <VencimientoFiscal>[];
    
    // Trimestres - día 20 del mes siguiente
    for (int trim = 1; trim <= 4; trim++) {
      final mesVencimiento = trim * 3 + 1; // Ene=4, Abr=7, Jul=10, Oct=13
      final fecha = DateTime(
        anio + (mesVencimiento > 12 ? 1 : 0), 
        mesVencimiento > 12 ? mesVencimiento - 12 : mesVencimiento, 
        20
      );
      
      final trimestre = '${trim}T/$anio';
      
      vencimientos.addAll([
        VencimientoFiscal(
          modelo: '303',
          descripcion: 'Modelo 303 - IVA $trimestre',
          obligacion: 'IVA trimestral',
          fecha: fecha,
        ),
        VencimientoFiscal(
          modelo: '111',
          descripcion: 'Modelo 111 - Retenciones IRPF $trimestre',
          obligacion: 'Retenciones sobre rendimientos del trabajo y actividades económicas',
          fecha: fecha,
        ),
        VencimientoFiscal(
          modelo: '115',
          descripcion: 'Modelo 115 - Retenciones alquileres $trimestre',
          obligacion: 'Retenciones sobre arrendamientos de inmuebles urbanos',
          fecha: fecha,
        ),
        VencimientoFiscal(
          modelo: '130',
          descripcion: 'Modelo 130 - Pago fraccionado IRPF $trimestre',
          obligacion: 'Pago fraccionado de IRPF (autónomos en estimación directa)',
          fecha: fecha,
        ),
        VencimientoFiscal(
          modelo: '202',
          descripcion: 'Modelo 202 - Pago fraccionado IS $trimestre',
          obligacion: 'Pago fraccionado del Impuesto sobre Sociedades',
          fecha: fecha,
        ),
      ]);
      
      // Modelo 349 solo en trimestres donde hay operaciones intracomunitarias
      vencimientos.add(
        VencimientoFiscal(
          modelo: '349',
          descripcion: 'Modelo 349 - Intracomunitarias $trimestre',
          obligacion: 'Operaciones intracomunitarias (si procede)',
          fecha: DateTime(fecha.year, fecha.month, 25), // Día 25
        ),
      );
    }
    
    // Anuales - enero del año siguiente
    final anioSiguiente = anio + 1;
    vencimientos.addAll([
      VencimientoFiscal(
        modelo: '390',
        descripcion: 'Modelo 390 - Resumen anual IVA $anio',
        obligacion: 'Resumen anual del IVA',
        fecha: DateTime(anioSiguiente, 1, 30),
      ),
      VencimientoFiscal(
        modelo: '190',
        descripcion: 'Modelo 190 - Resumen anual retenciones IRPF $anio',
        obligacion: 'Resumen anual de retenciones e ingresos a cuenta del IRPF',
        fecha: DateTime(anioSiguiente, 1, 31),
      ),
      VencimientoFiscal(
        modelo: '180',
        descripcion: 'Modelo 180 - Resumen anual retenciones alquileres $anio',
        obligacion: 'Resumen anual de retenciones sobre arrendamientos',
        fecha: DateTime(anioSiguiente, 1, 31),
      ),
      VencimientoFiscal(
        modelo: '347',
        descripcion: 'Modelo 347 - Operaciones con terceros $anio',
        obligacion: 'Declaración anual de operaciones con terceros',
        fecha: DateTime(anioSiguiente, 2, 28),
      ),
    ]);
    
    // Ordenar por fecha
    vencimientos.sort((a, b) => a.fecha.compareTo(b.fecha));
    
    return vencimientos;
  }
}

class VencimientoFiscal {
  final String modelo;
  final String descripcion;
  final String obligacion;
  final DateTime fecha;

  VencimientoFiscal({
    required this.modelo,
    required this.descripcion,
    required this.obligacion,
    required this.fecha,
  });
}


