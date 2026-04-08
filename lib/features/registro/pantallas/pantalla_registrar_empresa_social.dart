import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../onboarding/pantallas/pantalla_onboarding.dart';

/// Pantalla que aparece cuando un usuario nuevo se autentica con Google o Apple
/// y aún no tiene empresa vinculada (empresa_id == '').
/// Solo recoge los datos de la empresa; los datos del propietario ya están
/// en Firebase Auth.
class PantallaRegistrarEmpresaSocial extends StatefulWidget {
  /// Nombre del usuario obtenido del proveedor social.
  final String nombreUsuario;

  /// Correo del usuario obtenido del proveedor social.
  final String correoUsuario;

  const PantallaRegistrarEmpresaSocial({
    super.key,
    required this.nombreUsuario,
    required this.correoUsuario,
  });

  @override
  State<PantallaRegistrarEmpresaSocial> createState() =>
      _PantallaRegistrarEmpresaSocialState();
}

class _PantallaRegistrarEmpresaSocialState
    extends State<PantallaRegistrarEmpresaSocial> {
  final _formKey = GlobalKey<FormState>();
  final _nombreEmpresaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  String _tipoNegocio = 'comercio';
  bool _cargando = false;
  String? _error;

  static const _tiposNegocio = [
    ('comercio', 'Comercio / Tienda'),
    ('hosteleria', 'Hostelería / Restaurante'),
    ('servicios', 'Servicios profesionales'),
    ('peluqueria', 'Peluquería / Estética'),
    ('salud', 'Salud / Clínica'),
    ('otro', 'Otro'),
  ];

  @override
  void dispose() {
    _nombreEmpresaCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _completarRegistro() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final empresaId = const Uuid().v4();

      // 1. Crear documento de empresa
      await db.collection('empresas').doc(empresaId).set({
        'nombre': _nombreEmpresaCtrl.text.trim(),
        'correo': widget.correoUsuario,
        'telefono': _telefonoCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
        'tipo_negocio': _tipoNegocio,
        'propietario_id': uid,
        'onboarding_completado': false,
        'plan': 'basico',
        'activo': true,
        'fecha_creacion': FieldValue.serverTimestamp(),
        'proveedor_registro': 'social',
      });

      // 2. Inicializar contadores de facturación
      await db
          .collection('empresas')
          .doc(empresaId)
          .collection('contadores')
          .doc('facturas')
          .set({
        'ultimo_numero_FAC': 0,
        'ultimo_numero_PROF': 0,
        'ultimo_numero_RECT': 0,
        'ultimo_numero_PED': 0,
        'anio_ultimo_FAC': DateTime.now().year,
        'anio_ultimo_PROF': DateTime.now().year,
        'anio_ultimo_RECT': DateTime.now().year,
        'anio_ultimo_PED': DateTime.now().year,
      });

      // 3. Vincular empresa al usuario
      await db.collection('usuarios').doc(uid).update({
        'empresa_id': empresaId,
        'nombre': widget.nombreUsuario,
        'correo': widget.correoUsuario,
      });

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PantallaOnboarding(empresaId: empresaId),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Error al crear la empresa: $e';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completa tu empresa'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bienvenida
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF1976D2),
                      child: Icon(Icons.check, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Hola, ${widget.nombreUsuario}!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Un último paso: dinos sobre tu empresa.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Error
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Formulario
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre empresa
                    TextFormField(
                      controller: _nombreEmpresaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la empresa *',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                    ),

                    const SizedBox(height: 16),

                    // Tipo de negocio
                    DropdownButtonFormField<String>(
                      initialValue: _tipoNegocio,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de negocio *',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: _tiposNegocio
                          .map((t) => DropdownMenuItem(
                                value: t.$1,
                                child: Text(t.$2),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _tipoNegocio = v);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Teléfono
                    TextFormField(
                      controller: _telefonoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 16),

                    // Dirección
                    TextFormField(
                      controller: _direccionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Botón
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _completarRegistro,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _cargando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Crear empresa y continuar',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


