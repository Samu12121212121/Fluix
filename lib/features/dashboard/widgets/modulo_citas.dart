import 'package:flutter/material.dart';
import '../../../core/utils/permisos_service.dart';
import 'modulo_reservas.dart';

class ModuloCitas extends StatelessWidget {
  final String empresaId;
  final SesionUsuario? sesion;

  const ModuloCitas({
    super.key,
    required this.empresaId,
    this.sesion,
  });

  @override
  Widget build(BuildContext context) {
    return ModuloReservas(
      empresaId: empresaId,
      sesion: sesion,
      collectionId: 'citas',
      moduloSingular: 'Cita',
      moduloPlural: 'Citas',
      mostrarProfesional: true, // ← peluquerías, tatuajes, psicólogos, veterinarios
    );
  }
}
