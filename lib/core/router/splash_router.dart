import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:planeag_flutter/features/autenticacion/pantallas/pantalla_login.dart';
import 'package:planeag_flutter/features/dashboard/pantallas/pantalla_dashboard.dart';
import 'package:planeag_flutter/features/registro/pantallas/pantalla_registrar_empresa_social.dart';
import 'package:planeag_flutter/features/suscripcion/pantallas/pantalla_suscripcion_vencida.dart';

final _log = Logger();

/// Pantalla de arranque que resuelve todos los Futures de forma paralela
/// (usuario, empresa, suscripción) y navega a la pantalla correcta.
class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  late Future<Widget> _futureDestino;

  @override
  void initState() {
    super.initState();
    _futureDestino = _resolverDestino();
  }

  Future<Widget> _resolverDestino() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const PantallaLogin();

    try {
      final db = FirebaseFirestore.instance;

      // 1. Leer documento de usuario
      final userDoc = await db.collection('usuarios').doc(uid).get();
      final userData = userDoc.data();
      final empresaId = userData?['empresa_id'] as String?;

      // Sin empresa → flujo de registro social incompleto
      if (empresaId == null || empresaId.isEmpty) {
        final nombre = (userData?['nombre'] as String?) ?? '';
        final correo = (userData?['correo'] as String?) ?? '';
        if (nombre.isEmpty && correo.isEmpty) return const PantallaDashboard();
        return PantallaRegistrarEmpresaSocial(
          nombreUsuario: nombre.isNotEmpty ? nombre : 'Usuario',
          correoUsuario: correo,
        );
      }

      // 2. Traer empresa y suscripción en paralelo
      final results = await Future.wait([
        db.collection('empresas').doc(empresaId).get(),
        db.collection('empresas').doc(empresaId).collection('suscripcion').doc('actual').get(),
      ]);

      final suscDoc = results[1];
      final suscData = suscDoc.data();

      // 3. Verificar suscripción
      if (suscData != null && suscDoc.exists) {
        final estado = suscData['estado'] as String? ?? 'ACTIVA';
        if (estado == 'VENCIDA' || estado == 'SUSPENDIDA') {
          DateTime? fechaFin;
          final raw = suscData['fecha_fin'];
          if (raw is Timestamp) fechaFin = raw.toDate();

          return PantallaSuscripcionVencida(
            empresaId: empresaId,
            estado: estado,
            fechaFin: fechaFin,
          );
        }
      }

      return const PantallaDashboard();
    } catch (e) {
      _log.e('Error resolviendo ruta inicial', error: e);
      return const PantallaDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _futureDestino,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return snapshot.data!;
        }
        return _PantallaCarga();
      },
    );
  }
}

class _PantallaCarga extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1976D2),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.business_center_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Fluix CRM',
              style: TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cargando...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}


