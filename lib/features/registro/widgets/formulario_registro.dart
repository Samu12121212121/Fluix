// ⚠️ ARCHIVO LEGACY — REEMPLAZADO
// La implementación real está en:
//   lib/features/registro/widgets/formulario_registro_simple.dart
//
// Este archivo puede eliminarse con seguridad.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../autenticacion/providers/provider_autenticacion.dart';
import '../../../core/tema/tema_app.dart';

class FormularioRegistro extends StatefulWidget {
  const FormularioRegistro({super.key});

  @override
  State<FormularioRegistro> createState() => _FormularioRegistroState();
}

class _FormularioRegistroState extends State<FormularioRegistro> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _paginaActual = 0;

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

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _aceptaTerminos = false;

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
    return Consumer<ProviderAutenticacion>(
      builder: (context, providerAuth, child) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicador de progreso
              _buildIndicadorProgreso(),
              const SizedBox(height: Espaciado.xl),

              // Mensaje de error
              if (providerAuth.mensajeError != null) ...[
                Container(
                  padding: const EdgeInsets.all(Espaciado.m),
                    color: TemaApp.colorError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Espaciado.m),
                    borderRadius: BorderRadius.circular(BorderRadius.m),
                      color: TemaApp.colorError.withValues(alpha: 0.3),
                    border: Border.all(
                      color: TemaApp.colorError.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: TemaApp.colorError,
                      ),
                      const SizedBox(width: Espaciado.s),
                      Expanded(
                        child: Text(
                          providerAuth.mensajeError!,
                          style: TextStyle(color: TemaApp.colorError),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: providerAuth.limpiarError,
                        iconSize: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Espaciado.l),
              ],

              // Contenido de páginas
              SizedBox(
                height: 500,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _paginaActual = index;
                    });
                  },
                  children: [
                    _buildPaginaEmpresa(),
                    _buildPaginaPropietario(),
                  ],
                ),
              ),

              const SizedBox(height: Espaciado.xl),

              // Botones de navegación
              _buildBotonesNavegacion(providerAuth),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIndicadorProgreso() {
    return Row(
      children: [
        _buildPasoIndicador(0, 'Empresa'),
        Expanded(
          child: Container(
            height: 2,
            color: _paginaActual >= 1
                ? context.colores.primary
                : context.colores.outline,
          ),
        ),
        _buildPasoIndicador(1, 'Propietario'),
      ],
    );
  }

  Widget _buildPasoIndicador(int paso, String titulo) {
    final esActivo = _paginaActual >= paso;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: esActivo
                ? context.colores.primary
                : context.colores.outline,
          ),
          child: Center(
            child: esActivo
                ? Icon(
                    Icons.check,
                    color: context.colores.onPrimary,
                    size: 18,
                  )
                : Text(
                    '${paso + 1}',
                    style: TextStyle(
                      color: context.colores.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: Espaciado.s),
        Text(
          titulo,
          style: context.textos.labelMedium?.copyWith(
            color: esActivo
                ? context.colores.primary
                : context.colores.onSurfaceVariant,
            fontWeight: esActivo ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPaginaEmpresa() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Datos de la Empresa',
          style: context.textos.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colores.primary,
          ),
        ),
        const SizedBox(height: Espaciado.s),
        Text(
          'Ingresa la información básica de tu empresa',
          style: context.textos.bodyMedium?.copyWith(
            color: context.colores.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Espaciado.l),

        TextFormField(
          controller: _nombreEmpresaController,
          decoration: const InputDecoration(
            labelText: 'Nombre de la empresa',
            prefixIcon: Icon(Icons.business),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa el nombre de la empresa';
            }
            if (value.trim().length < 2) {
              return 'El nombre debe tener al menos 2 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: Espaciado.m),

        TextFormField(
          controller: _correoEmpresaController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo de la empresa',
            prefixIcon: Icon(Icons.email),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa el correo de la empresa';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Ingresa un correo válido';
            }
            return null;
          },
        ),
        const SizedBox(height: Espaciado.m),

        TextFormField(
          controller: _telefonoEmpresaController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Teléfono de la empresa',
            prefixIcon: Icon(Icons.phone),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa el teléfono de la empresa';
            }
            if (value.trim().length < 10) {
              return 'Ingresa un teléfono válido';
            }
            return null;
          },
        ),
        const SizedBox(height: Espaciado.m),

        TextFormField(
          controller: _direccionEmpresaController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Dirección de la empresa',
            prefixIcon: Icon(Icons.location_on),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa la dirección de la empresa';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPaginaPropietario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Datos del Propietario',
          style: context.textos.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colores.primary,
          ),
        ),
        const SizedBox(height: Espaciado.s),
        Text(
          'Crea tu cuenta de administrador',
          style: context.textos.bodyMedium?.copyWith(
            color: context.colores.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Espaciado.l),

        TextFormField(
          controller: _nombrePropietarioController,
          decoration: const InputDecoration(
            labelText: 'Nombre completo',
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa tu nombre completo';
            }
            if (value.trim().length < 2) {
              return 'El nombre debe tener al menos 2 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: Espaciado.m),

        TextFormField(
          controller: _correoPropietarioController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo personal',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa tu correo personal';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Ingresa un correo válido';
            }
            return null;
          },
        ),
        const SizedBox(height: Espaciado.m),

        TextFormField(
          controller: _telefonoPropietarioController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Teléfono personal',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa tu teléfono personal';
            }
            if (value.trim().length < 10) {
              return 'Ingresa un teléfono válido';
            }
            return null;
          },
        ),
        const SizedBox(height: Espaciado.m),

        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
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
        const SizedBox(height: Espaciado.m),

        TextFormField(
          controller: _confirmarPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirmar contraseña',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
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
        const SizedBox(height: Espaciado.m),

        // Checkbox de términos
        CheckboxListTile(
          value: _aceptaTerminos,
          onChanged: (value) {
            setState(() {
              _aceptaTerminos = value ?? false;
            });
          },
          title: Text(
            'Acepto los términos y condiciones',
            style: context.textos.bodySmall,
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildBotonesNavegacion(ProviderAutenticacion providerAuth) {
    return Row(
      children: [
        if (_paginaActual > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: providerAuth.estaCargando ? null : _paginaAnterior,
              child: const Text('Anterior'),
            ),
          ),
          const SizedBox(width: Espaciado.m),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: providerAuth.estaCargando
                ? null
                : (_paginaActual == 1 ? () => _registrar(providerAuth) : _siguientePagina),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colores.primary,
              padding: const EdgeInsets.symmetric(vertical: Espaciado.m),
            ),
            child: providerAuth.estaCargando
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colores.onPrimary,
                    ),
                  )
                : Text(
                    _paginaActual == 1 ? 'Crear Empresa' : 'Siguiente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.colores.onPrimary,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _siguientePagina() {
    if (_validarPaginaActual()) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _paginaAnterior() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  bool _validarPaginaActual() {
    if (_paginaActual == 0) {
      // Validar página de empresa
      return _nombreEmpresaController.text.trim().isNotEmpty &&
          _correoEmpresaController.text.trim().isNotEmpty &&
          _telefonoEmpresaController.text.trim().isNotEmpty &&
          _direccionEmpresaController.text.trim().isNotEmpty;
    }
    return true;
  }

  void _registrar(ProviderAutenticacion providerAuth) {
    if (_formKey.currentState!.validate() && _aceptaTerminos) {
      providerAuth.registrarEmpresa(
        nombreEmpresa: _nombreEmpresaController.text.trim(),
        correoEmpresa: _correoEmpresaController.text.trim(),
        telefonoEmpresa: _telefonoEmpresaController.text.trim(),
        direccionEmpresa: _direccionEmpresaController.text.trim(),
        nombrePropietario: _nombrePropietarioController.text.trim(),
        correoPropietario: _correoPropietarioController.text.trim(),
        telefonoPropietario: _telefonoPropietarioController.text.trim(),
        password: _passwordController.text,
      );
    } else if (!_aceptaTerminos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y condiciones'),
          backgroundColor: TemaApp.colorAdvertencia,
        ),
      );
    }
  }
}
