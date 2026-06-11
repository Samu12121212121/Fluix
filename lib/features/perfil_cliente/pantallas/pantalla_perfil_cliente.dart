import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../models/user_model.dart';
import '../../autenticacion/pantallas/pantalla_login.dart';
import '../../dashboard/pantallas/pantalla_dashboard.dart';
import 'pantalla_trofeos.dart';
import '../../../services/trofeos_service.dart';
import '../../tienda_monedas/pantalla_tienda_monedas.dart';
import '../../tienda_monedas/widgets/avatar_con_marco.dart';

// ── Paleta del perfil ────────────────────────────────────────────────────────
const _kBg         = Color(0xFF0A0F23);
const _kSurface    = Color(0xFF151932);
const _kCard       = Color(0xFF1E2139);
const _kAccent     = Color(0xFF00FFC8);
const _kRosa       = Color(0xFFFF3296);
const _kTexto      = Color(0xFFFFFFFF);
const _kMuted      = Color(0xFFB0B3C1);

// Emojis / colores disponibles para el avatar
const _kEmojis = ['🦊','🐺','🦁','🐸','🦋','🐙','🦄','🐼','🎭','🏄','🎸','🚀','⚡','🌈','🍀'];
const _kGradients = [
  [Color(0xFF00FFC8), Color(0xFF00D9FF)],
  [Color(0xFFFF3296), Color(0xFFFF8C42)],
  [Color(0xFF7B2FBE), Color(0xFF3F8EFC)],
  [Color(0xFF56CCF2), Color(0xFF2F80ED)],
  [Color(0xFFF7971E), Color(0xFFFFD200)],
  [Color(0xFF11998E), Color(0xFF38EF7D)],
  [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
  [Color(0xFF4CAF50), Color(0xFF8BC34A)],
];

class PantallaPerfilCliente extends StatefulWidget {
  const PantallaPerfilCliente({super.key});

  @override
  State<PantallaPerfilCliente> createState() => _PantallaPerfilClienteState();
}

class _PantallaPerfilClienteState extends State<PantallaPerfilCliente> {

  Future<void> _editarAvatar(Map<String, dynamic> userData) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final gradIdx = (userData['avatar_gradient'] as int?) ?? 0;
    final emoji = userData['avatar_emoji'] as String?;
    final fotoActual = userData['avatar_foto_url'] as String?;

    await showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => _AvatarPickerSheet(
        gradientIndex: gradIdx,
        emojiActual: emoji,
        fotoUrlActual: fotoActual,
        onGuardar: (newGrad, newEmoji, newFotoUrl) async {
          Navigator.pop(ctx);
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
            'avatar_gradient': newGrad,
            'avatar_emoji': newEmoji,
            if (newFotoUrl != null) 'avatar_foto_url': newFotoUrl,
          }, SetOptions(merge: true));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) return const PantallaLogin();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: _kSurface,
        foregroundColor: _kTexto,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(fbUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _kAccent));
          }

          // Construir datos con fallback a Firebase Auth si no hay doc en Firestore
          Map<String, dynamic> userData;
          if (snapshot.hasData && snapshot.data!.exists) {
            userData = snapshot.data!.data() as Map<String, dynamic>;
          } else {
            userData = {
              'nombre': fbUser.displayName ?? fbUser.email?.split('@').first ?? 'Usuario',
              'email': fbUser.email ?? '',
              'rol': 'usuario',
              'empresa_id': '',
            };
          }

          final user = AppUser.fromJson(userData);
          final empresaId = userData['empresa_id'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileHeader(user, userData),
                const SizedBox(height: 24),
                _buildInfoSection(user),
                const SizedBox(height: 16),
                _buildReservasSection(fbUser.uid),
                const SizedBox(height: 16),
                _buildTrofeosCard(fbUser.uid),
                const SizedBox(height: 16),
                _buildPuntosSection(fbUser.uid),
                // ── Botón Switch a vista empresa (solo si tiene empresa vinculada) ──
                if (empresaId != null && empresaId.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSwitchEmpresaButton(context, empresaId),
                ],
                const SizedBox(height: 24),
                _buildLogoutButton(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(AppUser user, Map<String, dynamic> userData) {
    final gradIdx = ((userData['avatar_gradient'] as int?) ?? 0).clamp(0, _kGradients.length - 1);
    final emoji     = userData['avatar_emoji'] as String?;
    final fotoUrl   = userData['avatar_foto_url'] as String?;
    final grad      = _kGradients[gradIdx];
    final marco     = userData['canje_marco'] as String?;
    final pulsante  = userData['canje_avatar_pulsante'] as bool? ?? false;
    final titulo    = userData['canje_titulo'] as String?;
    final midnight  = (userData['canje_tema'] as String?) == 'midnight';
    final colorHex  = userData['canje_color_nombre'] as String?;
    final Color nombreColor = colorHex != null
        ? Color(int.parse(colorHex.replaceFirst('#', '0xFF')))
        : _kTexto;

    final Widget avatarInner = Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        gradient: fotoUrl == null ? LinearGradient(colors: grad) : null,
        shape: BoxShape.circle,
      ),
      child: fotoUrl != null
          ? ClipOval(child: Image.network(fotoUrl, width: 100, height: 100, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: _kBg),
              ))))
          : Center(child: emoji != null
              ? Text(emoji, style: const TextStyle(fontSize: 46))
              : Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: _kBg))),
    );

    return Card(
      color: midnight ? const Color(0xFF0D1B2A) : _kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Stack(alignment: Alignment.bottomRight, children: [
            GestureDetector(
              onTap: () => _editarAvatar(userData),
              child: AvatarConMarco(
                size: 100,
                marco: marco,
                pulsante: pulsante,
                temaMidnight: midnight,
                child: avatarInner,
              ),
            ),
            GestureDetector(
              onTap: () => _editarAvatar(userData),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _kAccent, shape: BoxShape.circle,
                  border: Border.all(color: _kCard, width: 2),
                ),
                child: const Icon(Icons.edit, size: 14, color: _kBg),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text(user.name, style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: nombreColor)),
          if (titulo != null && titulo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(titulo, style: TextStyle(
                fontSize: 12, color: midnight
                    ? const Color(0xFF3F8EFC)
                    : _kAccent, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 4),
          Text(user.email, style: const TextStyle(fontSize: 14, color: _kMuted)),
        ]),
      ),
    );
  }

  Widget _buildInfoSection(AppUser user) {
    return Card(
      color: const Color(0xFF1E2139), // Tarjeta
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información de contacto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFFFFF), // Texto blanco
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.email_outlined, 'Email', user.email),
            if (user.telefono != null)
              _buildInfoRow(Icons.phone_outlined, 'Teléfono', user.telefono!),
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Miembro desde',
              _formatDate(user.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00FFC8)), // Cian
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6E82), // Texto sugerencia
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFFFFFF), // Texto blanco
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservasSection(String uid) {
    return Card(
      color: const Color(0xFF1E2139), // Tarjeta
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_month, color: Color(0xFFFF3296)), // Magenta
                SizedBox(width: 8),
                Text(
                  'Mis Reservas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFFFFF), // Texto blanco
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('reservas')
                  .where('usuario_uid', isEqualTo: uid)
                  .orderBy('creado_en', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00FFC8), // Cian
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No tienes reservas aún',
                        style: TextStyle(color: Color(0xFFB0B3C1)), // Texto secundario
                      ),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildReservaItem(data);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservaItem(Map<String, dynamic> data) {
    final negocioNombre = data['negocio_nombre'] ?? 'Negocio';
    final fechaHora = (data['fecha_hora'] as Timestamp?)?.toDate();
    final estado = data['estado'] ?? 'pendiente';

    Color estadoColor;
    String estadoText;
    switch (estado) {
      case 'confirmada':
        estadoColor = const Color(0xFF00FFC8); // Cian para confirmada
        estadoText = 'Confirmada';
        break;
      case 'cancelada':
        estadoColor = const Color(0xFFFF2850); // Rojo/rosa vibrante
        estadoText = 'Cancelada';
        break;
      default:
        estadoColor = const Color(0xFFFF4678); // Rosa alternativo para pendiente
        estadoText = 'Pendiente';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151932), // Superficie
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2E45)), // Outline variant
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  negocioNombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFFFFFFFF), // Texto blanco
                  ),
                ),
                const SizedBox(height: 4),
                if (fechaHora != null)
                  Text(
                    _formatDateTime(fechaHora),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB0B3C1), // Texto secundario
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              estadoText,
              style: TextStyle(
                color: estadoColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrofeosCard(String uid) {
    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: TrofeosService.streamTrofeos(uid),
      builder: (context, snap) {
        final datos = snap.data ?? {};
        final completados = datos.values.where((d) => d['completado'] == true).length;
        final total = 50; // kTrofeos.length
        final monedas = datos.values
            .where((d) => d['completado'] == true)
            .fold(0, (s, d) => s + ((d['monedas_otorgadas'] as int?) ?? 0));
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaTrofeos())),
          child: Card(
            color: const Color(0xFF1E2139),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF2A2E45), width: 0.5)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB830).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🏆', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mis Trofeos', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('$completados/$total completados', style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 12)),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? completados / total : 0,
                      minHeight: 4,
                      backgroundColor: const Color(0xFF2A2E45),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB830)),
                    ),
                  ),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('🪙', style: TextStyle(fontSize: 18)),
                  Text('$monedas', style: const TextStyle(color: Color(0xFFFFB830), fontSize: 14, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B6E82), size: 20),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPuntosSection(String uid) {
    return Card(
      color: const Color(0xFF1E2139), // Tarjeta
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFFF3296)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Programa de Fidelización',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const PantallaTiendaMonedas())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB830).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFB830).withValues(alpha: 0.4)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('🪙', style: TextStyle(fontSize: 13)),
                      SizedBox(width: 4),
                      Text('Canjear', style: TextStyle(
                          color: Color(0xFFFFB830), fontSize: 11,
                          fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(uid)
                  .collection('puntos')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00FFC8), // Cian
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aún no tienes puntos de fidelización',
                        style: TextStyle(color: Color(0xFFB0B3C1)), // Texto secundario
                      ),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final puntos = data['puntos'] ?? 0;
                    final empresaNombre = data['empresa_nombre'] ?? 'Negocio';
                    
                    return _buildPuntosItem(empresaNombre, puntos);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuntosItem(String negocio, int puntos) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00FFC8).withOpacity(0.1), // Cian
            const Color(0xFF00D9FF).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FFC8).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.store,
            color: Color(0xFF00FFC8), // Cian
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              negocio,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFFFFFFFF), // Texto blanco
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF3296), Color(0xFFFF4678)], // Gradiente magenta
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$puntos pts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E2139), // Tarjeta
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Color(0xFFFFFFFF)), // Texto blanco
              ),
              content: const Text(
                '¿Estás seguro que deseas cerrar sesión?',
                style: TextStyle(color: Color(0xFFB0B3C1)), // Texto secundario
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Color(0xFFB0B3C1)), // Texto secundario
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2850), // Rojo/rosa vibrante
                  ),
                  child: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );

          if (confirm == true && context.mounted) {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const PantallaLogin()),
                (_) => false,
              );
            }
          }
        },
        icon: const Icon(Icons.logout, color: Color(0xFFFF2850)), // Rojo/rosa vibrante
        label: const Text(
          'Cerrar sesión',
          style: TextStyle(color: Color(0xFFFF2850), fontSize: 16), // Rojo/rosa vibrante
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFFF2850)), // Rojo/rosa vibrante
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSwitchEmpresaButton(BuildContext context, String empresaId) {
    return Card(
      color: const Color(0xFF1E2139),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF00FFC8).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.business_center_rounded, color: Color(0xFF00FFC8)),
                SizedBox(width: 8),
                Text(
                  'Panel de empresa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tienes acceso a un panel de empresa. Cambia a la vista de propietario para gestionar tu negocio.',
              style: TextStyle(fontSize: 13, color: Color(0xFFB0B3C1)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PantallaDashboard()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.storefront_rounded),
                label: const Text(
                  'Cambiar a vista empresa',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC8),
                  foregroundColor: const Color(0xFF0A0F23),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} • ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SELECTOR DE AVATAR
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarPickerSheet extends StatefulWidget {
  final int gradientIndex;
  final String? emojiActual;
  final String? fotoUrlActual;
  final void Function(int grad, String? emoji, String? fotoUrl) onGuardar;

  const _AvatarPickerSheet({
    required this.gradientIndex,
    required this.emojiActual,
    this.fotoUrlActual,
    required this.onGuardar,
  });

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  late int _grad;
  String? _emoji;
  String? _fotoUrl;
  bool _subiendoFoto = false;

  @override
  void initState() {
    super.initState();
    _grad = widget.gradientIndex;
    _emoji = widget.emojiActual;
    _fotoUrl = widget.fotoUrlActual;
  }

  Future<void> _subirFoto() async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (imagen == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final ref = FirebaseStorage.instance.ref('avatares/$uid.jpg');
      await ref.putFile(File(imagen.path));
      final url = await ref.getDownloadURL();
      setState(() {
        _fotoUrl = url;
        _emoji = null; // quitar emoji si hay foto
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Personaliza tu avatar',
              style: TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          // Preview
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: _fotoUrl == null ? LinearGradient(colors: _kGradients[_grad]) : null,
                  shape: BoxShape.circle,
                ),
                child: _fotoUrl != null
                    ? ClipOval(
                        child: Image.network(_fotoUrl!, width: 80, height: 80, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(child: Text(_emoji ?? 'A',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _kBg))),
                        ))
                    : Center(child: _emoji != null
                        ? Text(_emoji!, style: const TextStyle(fontSize: 38))
                        : const Text('A', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _kBg))),
              ),
              if (_fotoUrl != null)
                GestureDetector(
                  onTap: () => setState(() => _fotoUrl = null),
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle,
                        border: Border.all(color: _kCard, width: 1.5)),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Botón subir foto
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _subiendoFoto ? null : _subirFoto,
              icon: _subiendoFoto
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent))
                  : const Icon(Icons.photo_library_outlined, size: 16, color: _kAccent),
              label: Text(_subiendoFoto ? 'Subiendo...' : 'Subir foto de galería',
                  style: const TextStyle(color: _kAccent, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Selector de gradiente
          const Align(alignment: Alignment.centerLeft,
              child: Text('Color de fondo', style: TextStyle(color: _kMuted, fontSize: 12))),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _kGradients.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() { _grad = i; _fotoUrl = null; }),
                child: Container(
                  width: 40, height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _kGradients[i]),
                    shape: BoxShape.circle,
                    border: _grad == i && _fotoUrl == null ? Border.all(color: _kAccent, width: 2.5) : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Selector de emoji
          const Align(alignment: Alignment.centerLeft,
              child: Text('Emoji (opcional)', style: TextStyle(color: _kMuted, fontSize: 12))),
          const SizedBox(height: 8),
          // Grid con scroll para todos los emojis
          SizedBox(
            height: 100,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 8,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              children: [
                // Opción "sin emoji"
                GestureDetector(
                  onTap: () => setState(() => _emoji = null),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kCard,
                      shape: BoxShape.circle,
                      border: _emoji == null ? Border.all(color: _kAccent, width: 2) : Border.all(color: Colors.white12),
                    ),
                    child: const Center(child: Text('A', style: TextStyle(
                        color: _kBg, fontWeight: FontWeight.bold, fontSize: 14))),
                  ),
                ),
                ..._kEmojis.map((e) => GestureDetector(
                  onTap: () => setState(() { _emoji = e; _fotoUrl = null; }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kCard,
                      shape: BoxShape.circle,
                      border: _emoji == e ? Border.all(color: _kAccent, width: 2) : Border.all(color: Colors.white12),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onGuardar(_grad, _emoji, _fotoUrl),
              style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg),
              child: const Text('Guardar avatar', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
