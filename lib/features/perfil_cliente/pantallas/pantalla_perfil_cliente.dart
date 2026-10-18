import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';
import '../../autenticacion/pantallas/pantalla_login.dart';
import '../../dashboard/pantallas/pantalla_dashboard.dart';
import 'pantalla_trofeos.dart';
import 'pantalla_monedero.dart';
import '../../../services/trofeos_service.dart';
import '../../tienda_monedas/pantalla_tienda_monedas.dart';
import '../../tienda_monedas/widgets/avatar_con_marco.dart';
import '../widgets/avatar_picker_sheet.dart';
const _kBg      = Color(0xFFF4F6FB);
const _kBorde   = Color(0xFFDDE3ED);
const _kAccent  = Color(0xFF00BFA5);
const _kRosa    = Color(0xFFE91E63);
const _kOro     = Color(0xFFFFB830);
const _kTexto   = Color(0xFF1E293B);
const _kMuted   = Color(0xFF64748B);

class PantallaPerfilCliente extends StatelessWidget {
  const PantallaPerfilCliente({super.key});

  @override
  Widget build(BuildContext context) {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) return const PantallaLogin();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        automaticallyImplyLeading: false,
        title: const Text('Fluix',
            style: TextStyle(color: _kAccent, fontSize: 24,
                fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(fbUser.uid).snapshots(),
        builder: (context, snap) {
          final data = snap.data?.exists == true ? snap.data!.data() as Map<String, dynamic> : <String, dynamic>{};
          final user = AppUser.fromJson({
            'nombre': fbUser.displayName ?? fbUser.email?.split('@').first ?? 'Usuario',
            'email': fbUser.email ?? '',
            'rol': 'usuario',
            'empresa_id': '',
            ...data,
          });
          final empresaId = data['empresa_id'] as String?;

          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _HeroHeader(user: user, uid: fbUser.uid, userData: data)),
            SliverToBoxAdapter(child: _QuickActions(uid: fbUser.uid, userData: data)),
            SliverToBoxAdapter(child: _ReservasRecientes(uid: fbUser.uid)),
            SliverToBoxAdapter(child: _InfoSection(user: user, data: data)),
            if (empresaId != null && empresaId.isNotEmpty)
              SliverToBoxAdapter(child: _EmpresaButton()),
            SliverToBoxAdapter(child: _LogoutButton()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ]);
        },
      ),
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final AppUser user;
  final String uid;
  final Map<String, dynamic> userData;
  const _HeroHeader({required this.user, required this.uid, required this.userData});

  Future<void> _editarAvatar(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => AvatarPickerSheet(
        gradientIndex: (userData['avatar_gradient'] as int?) ?? 0,
        emojiActual: userData['avatar_emoji'] as String?,
        fotoUrlActual: userData['avatar_foto_url'] as String?,
        onGuardar: (grad, emoji, fotoUrl) async {
          Navigator.pop(context);
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
            'avatar_gradient': grad,
            'avatar_emoji': emoji,
            if (fotoUrl != null) 'avatar_foto_url': fotoUrl,
          }, SetOptions(merge: true));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradIdx = ((userData['avatar_gradient'] as int?) ?? 0).clamp(0, kAvatarGradients.length - 1);
    final emoji    = userData['avatar_emoji'] as String?;
    final fotoUrl  = userData['avatar_foto_url'] as String?;
    final grad     = kAvatarGradients[gradIdx];
    final marco    = userData['canje_marco'] as String?;
    final pulsante = userData['canje_avatar_pulsante'] as bool? ?? false;
    final titulo   = userData['canje_titulo'] as String?;
    final midnight = (userData['canje_tema'] as String?) == 'midnight';
    final colorHex = userData['canje_color_nombre'] as String?;
    Color nombreColor = _kTexto;
    if (colorHex != null) {
      try { nombreColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF'))); } catch (_) {}
    }

    final avatarInner = Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        gradient: fotoUrl == null ? LinearGradient(colors: grad) : null,
        shape: BoxShape.circle,
      ),
      child: fotoUrl != null
          ? ClipOval(child: Image.network(fotoUrl, width: 90, height: 90, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)))))
          : Center(child: emoji != null
              ? Text(emoji, style: const TextStyle(fontSize: 42))
              : Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white))),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorde),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16, offset: const Offset(0, 4),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Avatar + edit
          Stack(alignment: Alignment.bottomRight, children: [
            GestureDetector(
              onTap: () => _editarAvatar(context),
              child: AvatarConMarco(size: 90, marco: marco, pulsante: pulsante, temaMidnight: midnight, child: avatarInner),
            ),
            GestureDetector(
              onTap: () => _editarAvatar(context),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: _kAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Text(user.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: nombreColor)),
          if (titulo != null && titulo.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(titulo, style: const TextStyle(fontSize: 12, color: _kAccent, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 3),
          Text(user.email, style: const TextStyle(fontSize: 13, color: _kMuted)),
          const SizedBox(height: 16),
          // Stats row
          StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: TrofeosService.streamTrofeos(uid),
            builder: (_, snapT) {
              final trofeos = snapT.data ?? {};
              final completados = trofeos.values.where((d) => d['completado'] == true).length;
              return StreamBuilder<int>(
                stream: TrofeosService.streamMonedas(uid),
                builder: (_, snapM) {
                  return Row(children: [
                    Expanded(child: _StatChip(label: 'Trofeos', value: '$completados', emoji: '🏆', color: _kOro)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatChip(label: 'Monedas', value: '${snapM.data ?? 0}', emoji: '🪙', color: _kOro)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatChip(label: 'Miembro', value: _since(user.createdAt), emoji: '⭐', color: _kAccent)),
                  ]);
                },
              );
            },
          ),
        ]),
      ),
    );
  }

  String _since(DateTime dt) {
    final months = DateTime.now().difference(dt).inDays ~/ 30;
    if (months < 1) return 'Nuevo';
    if (months < 12) return '${months}m';
    return '${months ~/ 12}a';
  }
}

class _StatChip extends StatelessWidget {
  final String label, value, emoji;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.emoji, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: _kMuted, fontSize: 10)),
    ]),
  );
}

// ── Acciones rápidas ──────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userData;
  const _QuickActions({required this.uid, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        _QBtn(icon: '🏆', label: 'Trofeos', color: _kOro,   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaTrofeos()))),
        const SizedBox(width: 8),
        _QBtn(icon: '🪙', label: 'Monedero', color: _kOro,  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaMonedero()))),
        const SizedBox(width: 8),
        _QBtn(icon: '🛍️', label: 'Tienda',  color: _kAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaTiendaMonedas()))),
        const SizedBox(width: 8),
        _QBtn(icon: '✏️', label: 'Editar', color: _kRosa, onTap: () => _editarPerfil(context)),
      ]),
    );
  }

  void _editarPerfil(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditarPerfilSheet(uid: uid, userData: userData),
    );
  }
}

class _QBtn extends StatelessWidget {
  final String icon, label;
  final Color color;
  final VoidCallback onTap;
  const _QBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}

// ── Editar perfil ─────────────────────────────────────────────────────────────

class _EditarPerfilSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> userData;
  const _EditarPerfilSheet({required this.uid, required this.userData});
  @override
  State<_EditarPerfilSheet> createState() => _EditarPerfilSheetState();
}

class _EditarPerfilSheetState extends State<_EditarPerfilSheet> {
  late final TextEditingController _nombre, _telefono, _bio;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombre   = TextEditingController(text: widget.userData['nombre'] as String? ?? '');
    _telefono = TextEditingController(text: widget.userData['telefono'] as String? ?? '');
    _bio      = TextEditingController(text: widget.userData['bio'] as String? ?? '');
  }

  @override
  void dispose() { _nombre.dispose(); _telefono.dispose(); _bio.dispose(); super.dispose(); }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    await FirebaseFirestore.instance.collection('usuarios').doc(widget.uid).set({
      'nombre': _nombre.text.trim(),
      if (_telefono.text.trim().isNotEmpty) 'telefono': _telefono.text.trim(),
      if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
    }, SetOptions(merge: true));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: _kTexto);
    final deco = InputDecoration(
      filled: true, fillColor: _kBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorde)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorde)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kAccent)),
      labelStyle: const TextStyle(color: _kMuted),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, decoration: BoxDecoration(color: _kBorde, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Editar perfil', style: TextStyle(color: _kTexto, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(controller: _nombre, style: style, decoration: deco.copyWith(labelText: 'Nombre')),
        const SizedBox(height: 12),
        TextField(controller: _telefono, style: style, keyboardType: TextInputType.phone, decoration: deco.copyWith(labelText: 'Teléfono')),
        const SizedBox(height: 12),
        TextField(controller: _bio, style: style, maxLines: 2, decoration: deco.copyWith(labelText: 'Bio (opcional)')),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _guardando ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        )),
      ]),
    );
  }
}

// ── Reservas recientes ────────────────────────────────────────────────────────

class _ReservasRecientes extends StatelessWidget {
  final String uid;
  const _ReservasRecientes({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorde, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.calendar_today_rounded, size: 16, color: _kAccent),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('Mis Reservas', style: TextStyle(color: _kTexto, fontSize: 15, fontWeight: FontWeight.bold))),
            TextButton(onPressed: () {}, child: const Text('Ver todo', style: TextStyle(color: _kAccent, fontSize: 12))),
          ]),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collectionGroup('reservas')
              .where('cliente_uid', isEqualTo: uid)
              .orderBy('fecha_creacion', descending: true)
              .limit(3)
              .snapshots(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2)));
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 16), child: Text('Sin reservas aún', style: TextStyle(color: _kMuted, fontSize: 13)));
            return Column(children: docs.map((d) => _ReservaRow(d.data() as Map<String, dynamic>)).toList());
          },
        ),
      ]),
    );
  }
}

class _ReservaRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReservaRow(this.data);

  @override
  Widget build(BuildContext context) {
    final nombre = data['negocio_nombre'] ?? data['servicio_nombre'] ?? 'Reserva';
    final fecha  = (data['fecha_creacion'] as Timestamp?)?.toDate();
    final estado = (data['estado'] as String? ?? '').toLowerCase();
    final color  = estado == 'completada' ? _kAccent : estado == 'cancelada' ? Colors.red[300]! : _kOro;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(children: [
        Container(width: 4, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: const TextStyle(color: _kTexto, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          if (fecha != null) Text(_fmt(fecha), style: const TextStyle(color: _kMuted, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(estado.isEmpty ? 'pendiente' : estado, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  String _fmt(DateTime dt) {
    const m = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${dt.day} ${m[dt.month-1]} ${dt.year}';
  }
}

// ── Info section ──────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final AppUser user;
  final Map<String, dynamic> data;
  const _InfoSection({required this.user, required this.data});

  @override
  Widget build(BuildContext context) {
    final bio = data['bio'] as String?;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorde, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Información', style: TextStyle(color: _kTexto, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (bio != null && bio.isNotEmpty) ...[
          Text(bio, style: const TextStyle(color: _kMuted, fontSize: 13, height: 1.4)),
          const SizedBox(height: 10),
          const Divider(color: _kBorde, height: 1),
          const SizedBox(height: 10),
        ],
        _InfoRow(Icons.email_outlined, user.email),
        if (user.telefono != null && user.telefono!.isNotEmpty) _InfoRow(Icons.phone_outlined, user.telefono!),
        _InfoRow(Icons.calendar_today_outlined, 'Desde ${_fmtDate(user.createdAt)}'),
      ]),
    );
  }

  String _fmtDate(DateTime d) {
    const m = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${d.day} ${m[d.month-1]} ${d.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;
  const _InfoRow(this.icon, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 16, color: _kAccent),
      const SizedBox(width: 10),
      Expanded(child: Text(value, style: const TextStyle(color: _kTexto, fontSize: 13))),
    ]),
  );
}

// ── Empresa button ────────────────────────────────────────────────────────────

class _EmpresaButton extends StatelessWidget {
  const _EmpresaButton();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    decoration: BoxDecoration(
      color: _kAccent.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
    ),
    child: ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.storefront_rounded, color: _kAccent, size: 20)),
      title: const Text('Panel de empresa', style: TextStyle(color: _kTexto, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: const Text('Cambia a vista de propietario', style: TextStyle(color: _kMuted, fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: _kAccent, size: 14),
      onTap: () => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PantallaDashboard()), (_) => false),
    ),
  );
}

// ── Logout ────────────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
      onPressed: () => _confirmLogout(context),
      icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF2850), size: 18),
      label: const Text('Cerrar sesión', style: TextStyle(color: Color(0xFFFF2850), fontSize: 15)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFFF2850), width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    )),
  );

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Cerrar sesión', style: TextStyle(color: _kTexto)),
      content: const Text('¿Seguro que deseas cerrar sesión?', style: TextStyle(color: _kMuted)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
        FilledButton(onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF2850), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Cerrar sesión')),
      ],
    ));
    if (ok == true && context.mounted) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PantallaLogin()), (_) => false);
    }
  }
}
