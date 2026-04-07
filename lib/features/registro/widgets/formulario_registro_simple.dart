import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormularioRegistro extends StatefulWidget {
  const FormularioRegistro({super.key});

  @override
  State<FormularioRegistro> createState() => _FormularioRegistroState();
}

class _FormularioRegistroState extends State<FormularioRegistro> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Controladores para datos de empresa
  final _nombreEmpresaController = TextEditingController();
  final _correoEmpresaController = TextEditingController();
  final _telefonoEmpresaController = TextEditingController();
  final _direccionEmpresaController = TextEditingController();

  // Controladores para datos del propietario
  final _nombrePropietarioController = TextEditingController();
  final _correoPropietarioController = TextEditingController();
  final _telefonoPropietarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();

  int _pasoActual = 0;
  bool _cargando = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nombreEmpresaController.dispose();
    _correoEmpresaController.dispose();
    _telefonoEmpresaController.dispose();
    _direccionEmpresaController.dispose();
    _nombrePropietarioController.dispose();
    _correoPropietarioController.dispose();
    _telefonoPropietarioController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Indicador de progreso
          _buildIndicadorProgreso(),
          const SizedBox(height: 32),

          // Mensaje de error
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _error = null),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Formulario con páginas
          SizedBox(
            height: 400,
            child: PageView(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _pasoActual = page;
                });
              },
              children: [
                _buildPasoEmpresa(),
                _buildPasoPropietario(),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Botones de navegación
          _buildBotonesNavegacion(),
        ],
      ),
    );
  }

  Widget _buildIndicadorProgreso() {
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: (_pasoActual + 1) / 2,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Paso ${_pasoActual + 1} de 2',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1976D2),
          ),
        ),
      ],
    );
  }

  Widget _buildPasoEmpresa() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información de la Empresa',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ingresa los datos de tu empresa para comenzar.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _nombreEmpresaController,
            decoration: const InputDecoration(
              labelText: 'Nombre de la empresa',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa el nombre de la empresa';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _correoEmpresaController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo de la empresa',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa el correo de la empresa';
              }
              if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _telefonoEmpresaController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono de la empresa',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa el teléfono de la empresa';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _direccionEmpresaController,
            decoration: const InputDecoration(
              labelText: 'Dirección de la empresa',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa la dirección de la empresa';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasoPropietario() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datos del Propietario',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Crea tu cuenta de administrador.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _nombrePropietarioController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu nombre completo';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _correoPropietarioController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo personal',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu correo personal';
              }
              if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _telefonoPropietarioController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono personal',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu teléfono personal';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa una contraseña';
              }
              if (value.length < 6) {
                return 'La contraseña debe tener al menos 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _confirmarPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirma tu contraseña';
              }
              if (value != _passwordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesNavegacion() {
    return Row(
      children: [
        if (_pasoActual > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _cargando ? null : _anterior,
              child: const Text('Anterior'),
            ),
          ),

        if (_pasoActual > 0) const SizedBox(width: 16),

        Expanded(
          child: ElevatedButton(
            onPressed: _cargando ? null : (_pasoActual == 1 ? _registrar : _siguiente),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _cargando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _pasoActual == 1 ? 'Registrar Empresa' : 'Siguiente',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _anterior() {
    if (_pasoActual > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _siguiente() {
    if (_validarPasoActual()) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  bool _validarPasoActual() {
    switch (_pasoActual) {
      case 0:
        return _nombreEmpresaController.text.trim().isNotEmpty &&
               _correoEmpresaController.text.trim().isNotEmpty &&
               _telefonoEmpresaController.text.trim().isNotEmpty &&
               _direccionEmpresaController.text.trim().isNotEmpty;
      case 1:
        return _formKey.currentState!.validate();
      default:
        return false;
    }
  }

  void _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _cargando = true; _error = null; });

    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();

      // 1. Crear usuario en Firebase Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _correoPropietarioController.text.trim(),
        password: _passwordController.text,
      );
      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(_nombrePropietarioController.text.trim());

      // 2. Crear documento de empresa
      final empresaRef = db.collection('empresas').doc();
      final empresaId = empresaRef.id;

      await empresaRef.set({
        'nombre':      _nombreEmpresaController.text.trim(),
        'correo':      _correoEmpresaController.text.trim(),
        'telefono':    _telefonoEmpresaController.text.trim(),
        'direccion':   _direccionEmpresaController.text.trim(),
        'descripcion': '',
        'sitio_web':   null,
        'categoria':   null,
        'fecha_creacion': Timestamp.fromDate(now),
      });

      // 3. Crear documento de usuario
      await db.collection('usuarios').doc(uid).set({
        'nombre':            _nombrePropietarioController.text.trim(),
        'correo':            _correoPropietarioController.text.trim(),
        'telefono':          _telefonoPropietarioController.text.trim(),
        'rol':               'propietario',
        'empresa_id':        empresaId,
        'activo':            true,
        'permisos':          [],
        'fecha_creacion':    now.toIso8601String(),
        'token_dispositivo': null,
        'token_actualizado': null,
        'plataforma':        null,
      });

      // 4. configuracion/modulos — catálogo inicial (citas apagado por defecto)
      await empresaRef.collection('configuracion').doc('modulos').set({
        'modulos': [
          {'id': 'dashboard',    'activo': true},
          {'id': 'valoraciones', 'activo': true},
          {'id': 'estadisticas', 'activo': true},
          {'id': 'reservas',     'activo': true},
          {'id': 'citas',        'activo': false},
          {'id': 'web',          'activo': true},
          {'id': 'whatsapp',     'activo': true},
          {'id': 'facturacion',  'activo': true},
          {'id': 'pedidos',      'activo': true},
          {'id': 'tareas',       'activo': true},
        ],
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      });

      // 5. suscripcion/actual — 30 días de prueba gratuita
      await empresaRef.collection('suscripcion').doc('actual').set({
        'estado':        'ACTIVA',
        'plan':          'basico',
        'fecha_inicio':  Timestamp.fromDate(now),
        'fecha_fin':     Timestamp.fromDate(now.add(const Duration(days: 30))),
        'aviso_enviado': false,
        'ultimo_aviso':  null,
      });

      // 6. estadisticas/resumen — vacío inicial
      await empresaRef.collection('estadisticas').doc('resumen').set({
        'fecha_calculo':       now.toIso8601String(),
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Empresa registrada exitosamente!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapearErrorAuth(e));
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _mapearErrorAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este correo ya está en uso.';
      case 'invalid-email':
        return 'Correo electrónico inválido.';
      case 'weak-password':
        return 'La contraseña es muy débil.';
      default:
        return 'Error al crear la cuenta: ${e.message}';
    }
  }
}
