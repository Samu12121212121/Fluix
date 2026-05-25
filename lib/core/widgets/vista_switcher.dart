import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Widget que permite cambiar entre vista Empresa y vista Usuario
/// Solo se muestra si el usuario tiene una empresa asociada
class VistaSwitcher extends StatefulWidget {
  final String vistaActual; // 'empresa' o 'usuario'
  
  const VistaSwitcher({super.key, this.vistaActual = 'empresa'});

  @override
  State<VistaSwitcher> createState() => _VistaSwitcherState();
}

class _VistaSwitcherState extends State<VistaSwitcher> {
  bool _tieneEmpresa = false;
  bool _cargando = true;
  String? _empresaId;

  @override
  void initState() {
    super.initState();
    _verificarPermisos();
  }

  Future<void> _verificarPermisos() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _cargando = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      
      final empresaId = userDoc.data()?['empresa_id'] as String?;
      
      if (mounted) {
        setState(() {
          _tieneEmpresa = empresaId != null && empresaId.isNotEmpty;
          _empresaId = empresaId;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // No mostrar si está cargando o no tiene empresa
    if (_cargando || !_tieneEmpresa) {
      return const SizedBox.shrink();
    }

    final esVistaEmpresa = widget.vistaActual == 'empresa';

    return Container(
      margin: const EdgeInsets.only(bottom: 80, right: 16),
      child: FloatingActionButton.extended(
        onPressed: () => _cambiarVista(context),
        backgroundColor: esVistaEmpresa 
            ? const Color(0xFF00FFC8) // Cian para cambiar a usuario
            : const Color(0xFF43A047), // Verde para cambiar a empresa
        foregroundColor: esVistaEmpresa 
            ? const Color(0xFF0A0F23)
            : Colors.white,
        elevation: 6,
        icon: Icon(
          esVistaEmpresa ? Icons.person : Icons.business,
          size: 24,
        ),
        label: Text(
          esVistaEmpresa ? 'Vista Cliente' : 'Vista Empresa',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  void _cambiarVista(BuildContext context) {
    final esVistaEmpresa = widget.vistaActual == 'empresa';
    
    if (esVistaEmpresa) {
      // Cambiar a vista cliente (Usuario)
      Navigator.of(context).pushNamedAndRemoveUntil('/explorar', (route) => false);
    } else {
      // Cambiar a vista empresa (Dashboard)
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    }
    
    // Mostrar confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          esVistaEmpresa 
              ? '✅ Cambiado a vista Cliente' 
              : '✅ Cambiado a vista Empresa',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: esVistaEmpresa 
            ? const Color(0xFF00FFC8)
            : const Color(0xFF43A047),
      ),
    );
  }
}

