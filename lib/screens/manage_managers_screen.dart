import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';

class ManageManagersScreen extends StatefulWidget {
  final Company company;
  final AppUser currentUser;

  const ManageManagersScreen({
    super.key,
    required this.company,
    required this.currentUser,
  });

  @override
  State<ManageManagersScreen> createState() => _ManageManagersScreenState();
}

class _ManageManagersScreenState extends State<ManageManagersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _addManager() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Crear usuario en Firebase Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (credential.user == null) {
        throw Exception('No se pudo crear el usuario');
      }

      // 2. Crear perfil de manager
      final manager = AppUser(
        id: credential.user!.uid,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        role: UserRole.companyManager,
        companyId: widget.company.id,
        createdAt: DateTime.now(),
      );

      // 3. Actualizar empresa con el nuevo manager
      final updatedManagerIds = List<String>.from(widget.company.managerIds);
      updatedManagerIds.add(credential.user!.uid);

      // 4. Guardar usando batch
      final batch = FirebaseFirestore.instance.batch();

      batch.set(
        FirebaseFirestore.instance.collection('users').doc(credential.user!.uid),
        manager.toJson(),
      );

      batch.update(
        FirebaseFirestore.instance.collection('companies').doc(widget.company.id),
        {'managerIds': updatedManagerIds},
      );

      await batch.commit();

      // Limpiar formulario
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manager agregado exitosamente')),
        );
        setState(() {}); // Refrescar la lista
      }

    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = 'Ya existe una cuenta con este correo.';
            break;
          case 'weak-password':
            _errorMessage = 'La contraseña es muy débil.';
            break;
          case 'invalid-email':
            _errorMessage = 'El correo electrónico no es válido.';
            break;
          default:
            _errorMessage = 'Error al crear manager: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeManager(String managerId) async {
    try {
      // Actualizar empresa removiendo el manager
      final updatedManagerIds = List<String>.from(widget.company.managerIds);
      updatedManagerIds.remove(managerId);

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.company.id)
          .update({'managerIds': updatedManagerIds});

      // Actualizar usuario removiendo la empresa
      await FirebaseFirestore.instance
          .collection('users')
          .doc(managerId)
          .update({
        'companyId': null,
        'role': UserRole.normalUser.name,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manager removido exitosamente')),
        );
        setState(() {}); // Refrescar la lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al remover manager: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Managers'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Formulario para agregar manager
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Agregar Nuevo Manager',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa el nombre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa el email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Ingresa un email válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa una contraseña';
                          }
                          if (value.length < 6) {
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _addManager,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Agregar Manager',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lista de managers actuales
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Managers Actuales',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: widget.company.managerIds.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay managers registrados',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: widget.company.managerIds.length,
                                itemBuilder: (context, index) {
                                  final managerId = widget.company.managerIds[index];
                                  return FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(managerId)
                                        .get(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const ListTile(
                                          leading: CircularProgressIndicator(),
                                          title: Text('Cargando...'),
                                        );
                                      }

                                      if (!snapshot.data!.exists) {
                                        return const ListTile(
                                          leading: Icon(Icons.error),
                                          title: Text('Manager no encontrado'),
                                        );
                                      }

                                      final manager = AppUser.fromJson(
                                        snapshot.data!.data() as Map<String, dynamic>,
                                      );

                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(0xFF0D47A1),
                                          child: Text(
                                            manager.name[0].toUpperCase(),
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                        title: Text(manager.name),
                                        subtitle: Text(manager.email),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Confirmar'),
                                                content: Text(
                                                  '¿Estás seguro de que quieres remover a ${manager.name} como manager?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: const Text('Cancelar'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _removeManager(managerId);
                                                    },
                                                    child: const Text(
                                                      'Remover',
                                                      style: TextStyle(color: Colors.red),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
