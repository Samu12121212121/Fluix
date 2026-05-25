import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA FICHAJE EMPLEADO
//
// FIXES aplicados:
//   [FIX-1] horasTrabajadas → tiempoNeto  (getter renombrado en fichaje.dart)
//   [FIX-2] EstadoFichaje.salida → EstadoFichaje.cerrado
// ═══════════════════════════════════════════════════════════════════════════════

class PantallaFichajeEmpleado extends StatefulWidget {
  final String empresaId;
  final String dispositivoId;

  const PantallaFichajeEmpleado({
    super.key,
    required this.empresaId,
    required this.dispositivoId,
  });

  @override
  State<PantallaFichajeEmpleado> createState() =>
      _PantallaFichajeEmpleadoState();
}

class _PantallaFichajeEmpleadoState extends State<PantallaFichajeEmpleado> {
  final FichajeService _service = FichajeService();

  EmpleadoFichaje? _empleado;
  Fichaje? _fichaje;
  bool _cargando = false;
  String? _error;
  String _pin = '';

  // Reloj en tiempo real
  late Timer _timer;
  String _horaActual = '';

  @override
  void initState() {
    super.initState();
    _actualizarHora();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => _actualizarHora(),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _actualizarHora() {
    if (mounted) {
      setState(() {
        _horaActual = DateFormat('HH:mm:ss').format(DateTime.now());
      });
    }
  }

  // ── PIN ────────────────────────────────────────────────────────────────────

  void _pulsarDigito(String digito) {
    if (_pin.length >= 4 || _cargando) return;
    setState(() {
      _pin += digito;
      _error = null;
    });
    if (_pin.length == 4) _verificarPIN();
  }

  void _borrarDigito() {
    if (_pin.isEmpty || _cargando) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _verificarPIN() async {
    setState(() => _cargando = true);

    try {
      final empleado = await _service.verificarPIN(
        empresaId: widget.empresaId,
        pin: _pin,
      );

      if (empleado == null) {
        setState(() {
          _error = 'PIN incorrecto';
          _pin = '';
        });
        return;
      }

      final fichaje = await _service.obtenerFichajeHoy(
        widget.empresaId,
        empleado.uid,
      );

      setState(() {
        _empleado = empleado;
        _fichaje = fichaje;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al verificar PIN';
        _pin = '';
      });
    } finally {
      setState(() => _cargando = false);
    }
  }

  // ── Acciones de fichaje ────────────────────────────────────────────────────

  Future<void> _ejecutarAccion(Future<void> Function() accion, String mensajeOk) async {
    setState(() => _cargando = true);
    try {
      await accion();
      if (!mounted) return;
      _mostrarExito(mensajeOk);
      await Future.delayed(const Duration(seconds: 2));
      _cerrarSesion();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      _mostrarError(e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _ficharEntrada() => _ejecutarAccion(
        () => _service.ficharEntrada(
      empresaId: widget.empresaId,
      empleadoId: _empleado!.uid,
      empleadoNombre: _empleado!.nombre,
      dispositivoId: widget.dispositivoId,
    ),
    'Entrada registrada: $_horaActual',
  );

  Future<void> _iniciarPausa() => _ejecutarAccion(
        () => _service.iniciarPausa(
      empresaId: widget.empresaId,
      empleadoId: _empleado!.uid,
    ),
    'Pausa iniciada: $_horaActual',
  );

  Future<void> _finalizarPausa() => _ejecutarAccion(
        () => _service.finalizarPausa(
      empresaId: widget.empresaId,
      empleadoId: _empleado!.uid,
    ),
    'Pausa finalizada: $_horaActual',
  );

  Future<void> _ficharSalida() => _ejecutarAccion(
        () => _service.ficharSalida(
      empresaId: widget.empresaId,
      empleadoId: _empleado!.uid,
    ),
    'Salida registrada: $_horaActual',
  );

  void _cerrarSesion() {
    setState(() {
      _empleado = null;
      _fichaje = null;
      _pin = '';
      _error = null;
    });
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 18)),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Sistema de Fichaje'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _empleado == null
                  ? _buildPantallaPIN()
                  : _buildPantallaAcciones(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pantalla PIN ───────────────────────────────────────────────────────────

  Widget _buildPantallaPIN() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'es_ES')
              .format(DateTime.now()),
          style: const TextStyle(fontSize: 15, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 28, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              _horaActual,
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        const CircleAvatar(
          radius: 36,
          backgroundColor: Colors.blue,
          child: Icon(Icons.person, size: 44, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          'Introduce tu PIN',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),

        // Indicadores de dígitos
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final relleno = i < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: relleno ? Colors.blue : Colors.transparent,
                border: Border.all(color: Colors.blue, width: 2),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        _buildTeclado(),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],

        if (_cargando)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildTeclado() {
    final filas = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: filas.map((fila) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: fila.map((key) {
              if (key.isEmpty) return const SizedBox(width: 72);
              if (key == '⌫') return _teclaIcono(Icons.backspace_outlined, _borrarDigito, Colors.red);
              return _teclaNumero(key);
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _teclaNumero(String n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 60,
        height: 60,
        child: ElevatedButton(
          onPressed: () => _pulsarDigito(n),
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 2,
          ),
          child: Text(n, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }

  Widget _teclaIcono(IconData icon, VoidCallback onTap, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 60,
        height: 60,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            backgroundColor: color.withValues(alpha: 0.1),
            foregroundColor: color,
            elevation: 2,
          ),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }

  // ── Pantalla acciones ──────────────────────────────────────────────────────

  Widget _buildPantallaAcciones() {
    // [FIX-2] EstadoFichaje.cerrado (antes .salida)
    final estado = _fichaje?.estado ?? EstadoFichaje.sinFichar;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hola, ${_empleado!.nombre}!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _horaActual,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),

        // Resumen de jornada si ya hay fichaje
        if (_fichaje != null) ...[
          const SizedBox(height: 12),
          _buildResumenJornada(_fichaje!),
        ],

        const SizedBox(height: 28),

        // Botones según estado
        if (estado == EstadoFichaje.sinFichar)
          _botonAccion(
            icono: Icons.login,
            texto: 'FICHAR ENTRADA',
            color: Colors.green,
            onTap: _ficharEntrada,
          ),

        if (estado == EstadoFichaje.trabajando) ...[
          _botonAccion(
            icono: Icons.pause_circle,
            texto: 'INICIAR PAUSA',
            color: Colors.orange,
            onTap: _iniciarPausa,
          ),
          const SizedBox(height: 12),
          _botonAccion(
            icono: Icons.logout,
            texto: 'FICHAR SALIDA',
            color: Colors.red,
            onTap: _ficharSalida,
          ),
        ],

        if (estado == EstadoFichaje.enPausa)
          _botonAccion(
            icono: Icons.play_circle,
            texto: 'FIN DE PAUSA',
            color: Colors.blue,
            onTap: _finalizarPausa,
          ),

        // [FIX-2] .cerrado en lugar de .salida
        if (estado == EstadoFichaje.cerrado)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Jornada finalizada',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: _cerrarSesion,
          icon: const Icon(Icons.close),
          label: const Text('Cancelar'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
        ),

        if (_cargando)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildResumenJornada(Fichaje f) {
    final entrada = f.entrada != null
        ? DateFormat('HH:mm').format(f.entrada!.toDate())
        : '--:--';

    // [FIX-1] tiempoNeto en lugar de horasTrabajadas
    final neto = f.tiempoNeto;
    final totalStr = neto != null
        ? '${neto.inHours}h ${neto.inMinutes.remainder(60)}m'
        : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _resumenItem('Entrada', entrada, Icons.login),
          _resumenItem('Pausas', '${f.pausas.length}', Icons.pause),
          _resumenItem('Total neto', totalStr, Icons.timer),
        ],
      ),
    );
  }

  Widget _resumenItem(String label, String valor, IconData icono) {
    return Column(
      children: [
        Icon(icono, size: 18, color: Colors.blue[700]),
        const SizedBox(height: 2),
        Text(valor,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _botonAccion({
    required IconData icono,
    required String texto,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 66,
      child: ElevatedButton.icon(
        onPressed: _cargando ? null : onTap,
        icon: Icon(icono, size: 28),
        label: Text(
          texto,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}