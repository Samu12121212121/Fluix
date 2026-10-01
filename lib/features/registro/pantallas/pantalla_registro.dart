import 'package:flutter/material.dart';
import '../widgets/formulario_registro_simple.dart';
import '../../../core/widgets/fluix_app_bar.dart';

class PantallaRegistro extends StatelessWidget {
  const PantallaRegistro({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FluixAppBar(titulo: 'Registrar Empresa', showLeading: true),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: FormularioRegistro(),
        ),
      ),
    );
  }
}
