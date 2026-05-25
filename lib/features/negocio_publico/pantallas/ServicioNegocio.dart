import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ───────────────────────────── MODEL ─────────────────────────────

class ServicioNegocio {
  final String id;
  final String nombre;
  final String? descripcion;
  final double? precio;
  final double? precioDesde;

  ServicioNegocio({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.precio,
    this.precioDesde,
  });

  factory ServicioNegocio.fromMap(String id, Map<String, dynamic> map) {
    return ServicioNegocio(
      id: id,
      nombre: (map['nombre'] ?? '') as String,
      descripcion: map['descripcion'] as String?,
      precio: (map['precio'] as num?)?.toDouble(),
      precioDesde: (map['precio_desde'] as num?)?.toDouble(),
    );
  }
}

// ───────────────────────────── TAB RESERVAS ─────────────────────────────

class ReservasTab extends StatefulWidget {
  final String negocioId;
  final Function(ServicioNegocio) onSelect;

  const ReservasTab({
    super.key,
    required this.negocioId,
    required this.onSelect,
  });

  @override
  State<ReservasTab> createState() => _ReservasTabState();
}

class _ReservasTabState extends State<ReservasTab> {
  ServicioNegocio? _servicioSeleccionado;
  DateTime? _diaSeleccionado;
  String? _horaSeleccionada;
  String? _empleadoSeleccionado;

  bool get pasoServicio => _servicioSeleccionado == null;
  bool get pasoFecha => _servicioSeleccionado != null && _diaSeleccionado == null;
  bool get pasoHora => _diaSeleccionado != null && _horaSeleccionada == null;
  bool get pasoEmpleado => _horaSeleccionada != null && _empleadoSeleccionado == null;

  void _reset() {
    setState(() {
      _servicioSeleccionado = null;
      _diaSeleccionado = null;
      _horaSeleccionada = null;
      _empleadoSeleccionado = null;
    });
  }

  void _selectServicio(ServicioNegocio s) {
    setState(() {
      _servicioSeleccionado = s;
      _diaSeleccionado = null;
      _horaSeleccionada = null;
      _empleadoSeleccionado = null;
    });

    widget.onSelect(s);
  }

  void _selectDia(DateTime d) {
    setState(() {
      _diaSeleccionado = d;
      _horaSeleccionada = null;
      _empleadoSeleccionado = null;
    });
  }

  void _selectHora(String h) {
    setState(() => _horaSeleccionada = h);
  }

  void _selectEmpleado(String e) {
    setState(() => _empleadoSeleccionado = e);
  }

  @override
  Widget build(BuildContext context) {
    final step = pasoServicio
        ? 0
        : pasoFecha
        ? 1
        : pasoHora
        ? 2
        : 3;

    return Column(
      children: [
        _ProgressHeader(step: step),

        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: pasoServicio
                ? _ServiciosList(
              negocioId: widget.negocioId,
              onTap: _selectServicio,
            )
                : pasoFecha
                ? _DiasSelector(onTap: _selectDia)
                : pasoHora
                ? _HorasSelector(onTap: _selectHora)
                : _EmpleadosSelector(onTap: _selectEmpleado),
          ),
        ),

        if (_servicioSeleccionado != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_empleadoSeleccionado != null &&
                      _horaSeleccionada != null &&
                      _diaSeleccionado != null)
                      ? () {
                    // aquí confirmas reserva
                  }
                      : null,
                  child: const Text("Confirmar reserva"),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────────── PROGRESS ─────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final int step;
  const _ProgressHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: List.generate(4, (i) {
          final active = i <= step;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              decoration: BoxDecoration(
                color: active ? Colors.teal : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ───────────────────────────── SERVICIOS ─────────────────────────────

class _ServiciosList extends StatelessWidget {
  final String negocioId;
  final Function(ServicioNegocio) onTap;

  const _ServiciosList({
    required this.negocioId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(negocioId)
          .collection('servicios')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("Sin servicios disponibles"));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final servicio = ServicioNegocio.fromMap(doc.id, data);

            return ListTile(
              title: Text(servicio.nombre),
              subtitle: Text(servicio.descripcion ?? ''),
              trailing: Text(
                servicio.precio != null
                    ? "€${servicio.precio}"
                    : servicio.precioDesde != null
                    ? "Desde €${servicio.precioDesde}"
                    : '',
              ),
              onTap: () => onTap(servicio),
            );
          },
        );
      },
    );
  }
}

// ───────────────────────────── FECHA ─────────────────────────────

class _DiasSelector extends StatelessWidget {
  final Function(DateTime) onTap;
  const _DiasSelector({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dias = List.generate(14, (i) => now.add(Duration(days: i)));

    return ListView(
      children: dias
          .map(
            (d) => ListTile(
          title: Text("${d.day}/${d.month}/${d.year}"),
          onTap: () => onTap(d),
        ),
      )
          .toList(),
    );
  }
}

// ───────────────────────────── HORAS ─────────────────────────────

class _HorasSelector extends StatelessWidget {
  final Function(String) onTap;
  const _HorasSelector({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final horas = ["09:00", "10:00", "11:00", "12:00", "16:00", "17:00"];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: horas
          .map(
            (h) => ChoiceChip(
          label: Text(h),
          selected: false,
          onSelected: (_) => onTap(h),
        ),
      )
          .toList(),
    );
  }
}

// ───────────────────────────── EMPLEADOS ─────────────────────────────

class _EmpleadosSelector extends StatelessWidget {
  final Function(String) onTap;
  const _EmpleadosSelector({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final empleados = ["Cualquiera", "Empleado 1", "Empleado 2"];

    return ListView(
      children: empleados
          .map(
            (e) => ListTile(
          title: Text(e),
          onTap: () => onTap(e),
        ),
      )
          .toList(),
    );
  }
}