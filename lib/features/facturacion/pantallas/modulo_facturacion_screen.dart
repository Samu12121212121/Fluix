import 'package:flutter/material.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/tab_facturas.dart';

class ModuloFacturacionScreen extends StatelessWidget {
  final String empresaId;
  const ModuloFacturacionScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: TabFacturas(empresaId: empresaId),
    );
  }
}
