import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/programa_fidelizacion_model.dart';
import '../../../models/tarjeta_sellos_model.dart';
import '../../../services/fidelizacion_service.dart';
import 'pantalla_escanear_qr_negocio.dart';
import 'pantalla_qr_canje.dart';

class PantallaTarjetaSellos extends StatefulWidget {
  final String negocioId;
  final String? negocioNombre;
  final String? negocioFoto;

  const PantallaTarjetaSellos({
    super.key,
    required this.negocioId,
    this.negocioNombre,
    this.negocioFoto,
  });

  @override
  State<PantallaTarjetaSellos> createState() => _PantallaTarjetaSello sState();
}

class _PantallaTarjetaSellostate extends State<PantallaTarjetaSellos> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('No autenticado')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151932),
        elevation: 0,
        title: const Text('Tarjeta de Fidelización', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<ProgramaFidelizacionModel?>(
        stream: FidelizacionService.escucharPrograma(widget.negocioId),
        builder: (context, programaSnap) {
          if (programaSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final programa = programaSnap.data;
          if (programa == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.card_giftcard, size: 80, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'Este negocio aún no tiene programa de fidelización',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<TarjetaSelloModel?>(
            stream: FidelizacionService.escucharTarjeta(uid, widget.negocioId),
            builder: (context, tarjetaSnap) {
              final tarjeta = tarjetaSnap.data;
              
              return Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER
                        _buildHeader(tarjeta),
                        const SizedBox(height: 24),
                        
                        // TARJETA DE SELLOS
                        _buildTarjetaSellos(programa, tarjeta),
                        const SizedBox(height: 24),
                        
                        // MIS RECOMPENSAS
                        _buildRecompensas(programa, tarjeta),
                        const SizedBox(height: 24),
                        
                        // ¿CÓMO FUNCIONA?
                        _buildComoFunciona(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                  
                  // CONFETTI
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      colors: const [Color(0xFFFFBB00), Color(0xFF00FFC8), Color(0xFFFF3296), Colors.white],
                      numberOfParticles: 30,
                      gravity: 0.3,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirEscanearQR(context),
        backgroundColor: const Color(0xFF00FFC8),
        foregroundColor: const Color(0xFF0A0F23),
        icon: const Icon(Icons.qr_code_scanner, size: 28),
        label: const Text('Escanear QR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }

  Widget _buildHeader(TarjetaSelloModel? tarjeta) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2139), Color(0xFF151932)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E45), width: 1),
      ),
      child: Row(
        children: [
          if (widget.negocioFoto != null || tarjeta?.negocioFoto != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: widget.negocioFoto ?? tarjeta!.negocioFoto!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF2A2E45)),
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF2A2E45)),
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2E45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.store, color: Colors.white70, size: 30),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.negocioNombre ?? tarjeta?.negocioNombre ?? 'Negocio',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  tarjeta != null ? 'Miembro desde ${_formatFecha(tarjeta.creadoAt)}' : 'Nueva tarjeta',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaSellos(ProgramaFidelizacionModel programa, TarjetaSelloModel? tarjeta) {
    final sellosActuales = tarjeta?.sellosActuales ?? 0;
    final sellosTotal = programa.sellosParaRecompensa;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2139), Color(0xFF151932)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFBB00), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                programa.nombre,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFBB00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFBB00)),
                ),
                child: Text(
                  '$sellosActuales / $sellosTotal',
                  style: const TextStyle(color: Color(0xFFFFBB00), fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // GRID DE SELLOS
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(sellosTotal, (index) {
              final completado = index < sellosActuales;
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (index * 50)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: completado ? value : 0.95,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: completado
                            ? const LinearGradient(
                                colors: [Color(0xFFFFBB00), Color(0xFFFF8800)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: completado ? null : const Color(0xFF2A2E45),
                        border: Border.all(
                          color: completado ? const Color(0xFFFFBB00) : const Color(0xFF3A3E55),
                          width: 2,
                        ),
                      ),
                      child: completado
                          ? const Icon(Icons.check, color: Colors.white, size: 24)
                          : Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, fontWeight: FontWeight.w600, height: 4),
                            ),
                    ),
                  );
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          
          // BARRA DE PROGRESO
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: sellosActuales / sellosTotal,
              backgroundColor: const Color(0xFF2A2E45),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFFBB00)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            sellosActuales >= sellosTotal
                ? '¡Tarjeta completada! 🎉'
                : 'Te faltan ${sellosTotal - sellosActuales} sellos para tu recompensa',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRecompensas(ProgramaFidelizacionModel programa, TarjetaSelloModel? tarjeta) {
    final recompensasDisponibles = tarjeta?.recompensasDisponibles ?? [];
    final recompensasCanjeadas = tarjeta?.recompensasCanjeadas ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mis Recompensas',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        
        if (recompensasDisponibles.isNotEmpty) ...[
          ...recompensasDisponibles.map((r) => _buildRecompensaCard(r, programa, true)),
          const SizedBox(height: 12),
        ],
        
        if (recompens asCanjeadas.isNotEmpty) ...[
          const Text(
            'Canjeadas',
            style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...recompensasCanjeadas.map((r) => _buildRecompensaCard(r, programa, false)),
        ],
        
        if (recompensasDisponibles.isEmpty && recompensasCanjeadas.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF151932),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2E45)),
            ),
            child: Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.white.withOpacity(0.3), size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Aún no tienes recompensas.\n¡Sigue visitando para desbloquearlas!',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRecompensaCard(RecompensaDesbloqueada recompensa, ProgramaFidelizacionModel programa, bool disponible) {
    final recompensaPrograma = programa.recompensas.firstWhere(
      (r) => r.id == recompensa.recompensaId,
      orElse: () => RecompensaPrograma(id: '', titulo: recompensa.titulo, descripcion: '', tipo: 'otro', valor: '', sellosNecesarios: 0),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: disponible ? const Color(0xFF1E2139) : const Color(0xFF151932),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: disponible ? const Color(0xFF00FFC8) : const Color(0xFF2A2E45),
          width: disponible ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (disponible ? const Color(0xFF00FFC8) : const Color(0xFF6B6E82)).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getRecompensaIcon(recompensaPrograma.tipo),
                  color: disponible ? const Color(0xFF00FFC8) : const Color(0xFF6B6E82),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recompensa.titulo,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (recompensaPrograma.descripcion.isNotEmpty)
                      Text(
                        recompensaPrograma.descripcion,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (disponible)
                Icon(Icons.arrow_forward_ios, color: const Color(0xFF00FFC8), size: 16),
              if (!disponible)
                const Icon(Icons.check_circle, color: Color(0xFF6B6E82), size: 20),
            ],
          ),
          if (disponible) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _abrirQRCanje(recompensaPrograma),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC8),
                  foregroundColor: const Color(0xFF0A0F23),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Canjear Ahora', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComoFunciona() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Cómo funciona?',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        _buildPaso(1, 'Visita el negocio y escanea su QR al llegar', Icons.qr_code_scanner),
        _buildPaso(2, 'Acumula sellos con cada visita', Icons.style),
        _buildPaso(3, 'Al completarlos, desbloqueas una recompensa', Icons.card_giftcard),
        _buildPaso(4, 'Pulsa "Canjear", genera tu QR y pídele al negocio que lo escanee', Icons.qr_code_2),
      ],
    );
  }

  Widget _buildPaso(int numero, String texto, IconData icono) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00FFC8), Color(0xFF00CCB8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$numero',
                style: const TextStyle(color: Color(0xFF0A0F23), fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
            ),
          ),
          Icon(icono, color: const Color(0xFF00FFC8), size: 20),
        ],
      ),
    );
  }

  void _abrirEscanearQR(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaEscanearQRNegocio(negocioId: widget.negocioId),
      ),
    ).then((resultado) {
      if (resultado == true) {
        _confettiController.play();
      }
    });
  }

  void _abrirQRCanje(RecompensaPrograma recompensa) async {
    final qrId = await FidelizacionService.generarQrCanje(
      negocioId: widget.negocioId,
      recompensa: recompensa,
    );

    if (qrId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaQRCanje(
            negocioId: widget.negocioId,
            qrId: qrId,
            recompensa: recompensa,
          ),
        ),
      );
    }
  }

  IconData _getRecompensaIcon(String tipo) {
    switch (tipo) {
      case 'descuento_porcentaje':
        return Icons.percent;
      case 'visita_gratis':
        return Icons.free_breakfast;
      case 'producto':
        return Icons.redeem;
      default:
        return Icons.card_giftcard;
    }
  }

  String _formatFecha(DateTime fecha) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${meses[fecha.month - 1]} ${fecha.year}';
  }
}

