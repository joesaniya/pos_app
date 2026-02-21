
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/edit_profile_provider.dart';
import 'package:pos_app/providers/profile_provider.dart';
import 'package:pos_app/screens/utils/user_profile.dart';

class _K {
  static const page        = Color(0xFFF4F7FF);
  static const white       = Color(0xFFFFFFFF);
  static const royal       = Color(0xFF1847C4);
  static const royalMid    = Color(0xFF3B6FE8);
  static const royalLight  = Color(0xFF6B93FF);
  static const royalSoft   = Color(0xFFEBF0FF);
  static const royalBorder = Color(0xFFCDD8FB);
  static const ink         = Color(0xFF0D1B3E);
  static const body        = Color(0xFF3A4A6B);
  static const muted       = Color(0xFF8C9AB8);
  static const line        = Color(0xFFE4EAF8);
  static const green       = Color(0xFF0EA472);
  static const amber       = Color(0xFFD97706);
  static const red         = Color(0xFFDC2626);
  static const teal        = Color(0xFF0891B2);
  static const violet      = Color(0xFF7C3AED);
}

// ─────────────────────────────────────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<ProfileProvider, EditProfileProvider>(
      create: (ctx) => EditProfileProvider(ctx.read<ProfileProvider>()),
      update: (ctx, profileProv, prev) =>
          prev ?? EditProfileProvider(profileProv),
      child: const _EditView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _EditView extends StatefulWidget {
  const _EditView();

  @override
  State<_EditView> createState() => _EditViewState();
}

class _EditViewState extends State<_EditView> with SingleTickerProviderStateMixin {
  late final TextEditingController _nameCtrl;
  late final AnimationController _saveAnim;
  late final Animation<double> _savePulse;

  @override
  void initState() {
    super.initState();
    final prov = context.read<EditProfileProvider>();
    _nameCtrl = TextEditingController(text: prov.name)
      ..addListener(() {
        context.read<EditProfileProvider>().onNameChanged(_nameCtrl.text);
      });

    _saveAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _savePulse = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _saveAnim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _saveAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Consumer2<EditProfileProvider, ProfileProvider>(
      builder: (ctx, edit, profile, _) {
        // Listen for save success → pop back
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (edit.saveState == EditSaveState.success) {
            edit.resetState();
            Navigator.pop(context, true);
          }
          if (edit.saveState == EditSaveState.error) {
            _showError(ctx, edit.errorMessage);
            edit.resetState();
          }
        });

        final p = profile.profile;

        return Scaffold(
          backgroundColor: _K.page,
          body: Stack(children: [
            // Dot-grid texture
            Positioned.fill(child: CustomPaint(painter: _DotPainter())),

            SafeArea(
              child: Column(children: [
                // ── Top bar ──────────────────────────────────
                _TopBar(
                  hasChanges: edit.hasChanges,
                  isSaving: edit.isSaving,
                  onBack: () => _handleBack(ctx, edit),
                  onSave: () => _save(ctx, edit),
                  savePulse: _savePulse,
                ),

                // ── Scrollable body ───────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Column(children: [

                      const SizedBox(height: 28),

                      // ── Photo picker ─────────────────────────
                      _PhotoSection(edit: edit),

                      const SizedBox(height: 32),

                      // ── Editable fields ───────────────────────
                      _SectionLabel(title: 'EDITABLE'),
                      const SizedBox(height: 10),
                      _EditableCard(nameCtrl: _nameCtrl, edit: edit),

                      const SizedBox(height: 28),

                      // ── Read-only fields ──────────────────────
                      _SectionLabel(title: 'READ-ONLY INFORMATION'),
                      const SizedBox(height: 10),
                      if (p != null) _ReadOnlyCard(profile: p),

                      const SizedBox(height: 28),

                      // ── Status banner ─────────────────────────
                      if (p != null) _StatusBanner(profile: p),
                    ]),
                  ),
                ),
              ]),
            ),

            // ── Saving overlay ────────────────────────────────
            if (edit.isSaving) const _SavingOverlay(),
          ]),
        );
      },
    );
  }

  Future<void> _save(BuildContext ctx, EditProfileProvider edit) async {
    FocusScope.of(ctx).unfocus();
    await edit.saveChanges();
  }

  void _handleBack(BuildContext ctx, EditProfileProvider edit) {
    if (!edit.hasChanges) { Navigator.pop(ctx); return; }
    showDialog(
      context: ctx,
      builder: (_) => _DiscardDialog(
        onDiscard: () { Navigator.pop(ctx); Navigator.pop(ctx); },
        onKeep:    () => Navigator.pop(ctx),
      ),
    );
  }

  void _showError(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: _K.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool hasChanges, isSaving;
  final VoidCallback onBack, onSave;
  final Animation<double> savePulse;

  const _TopBar({
    required this.hasChanges,
    required this.isSaving,
    required this.onBack,
    required this.onSave,
    required this.savePulse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: _K.white,
        border: Border(bottom: BorderSide(color: _K.line)),
        boxShadow: [
          BoxShadow(color: _K.royal.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(children: [
        // Back
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _K.royalSoft,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _K.royalBorder)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _K.royal, size: 17)),
        ),
        const SizedBox(width: 14),

        // Title
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Edit Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                color: _K.ink, letterSpacing: -0.4)),
          Text(hasChanges ? 'Unsaved changes' : 'No changes yet',
            style: TextStyle(fontSize: 11,
                color: hasChanges ? _K.amber : _K.muted,
                fontWeight: FontWeight.w600)),
        ]),

        const Spacer(),

        // Save button
        ScaleTransition(
          scale: hasChanges && !isSaving ? savePulse : const AlwaysStoppedAnimation(1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: hasChanges && !isSaving ? onSave : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  gradient: hasChanges
                      ? const LinearGradient(
                          colors: [_K.royal, _K.royalMid],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : null,
                  color: hasChanges ? null : _K.line,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: hasChanges
                      ? [BoxShadow(color: _K.royal.withOpacity(0.35),
                            blurRadius: 10, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isSaving ? Icons.hourglass_top_rounded : Icons.check_rounded,
                    color: hasChanges ? Colors.white : _K.muted, size: 16),
                  const SizedBox(width: 6),
                  Text(isSaving ? 'Saving…' : 'Save',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: hasChanges ? Colors.white : _K.muted)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PHOTO SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoSection extends StatelessWidget {
  final EditProfileProvider edit;
  const _PhotoSection({required this.edit});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Big circular photo
      Stack(alignment: Alignment.bottomRight, children: [
        // Outer ring
        Container(
          width: 118, height: 118,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_K.royalLight.withOpacity(0.4), _K.royal.withOpacity(0.15)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(color: _K.royal.withOpacity(0.18),
                  blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
        ),
        // Photo / initials
        Positioned(left: 5, top: 5,
          child: _AvatarCircle(edit: edit, size: 108)),
        // Camera badge
        Positioned(right: 0, bottom: 0,
          child: GestureDetector(
            onTap: () => _showPickerSheet(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_K.royal, _K.royalMid],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                border: Border.all(color: _K.white, width: 2.5),
                boxShadow: [BoxShadow(color: _K.royal.withOpacity(0.40),
                    blurRadius: 8, offset: const Offset(0, 3))]),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 17)),
          ),
        ),
      ]),

      const SizedBox(height: 14),

      // Label
      const Text('Profile Photo',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
            color: _K.ink, letterSpacing: -0.2)),
      const SizedBox(height: 4),
      Text('Tap the camera icon to update',
        style: TextStyle(fontSize: 12, color: _K.muted)),

      const SizedBox(height: 16),

      // Action chips
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _PhotoChip(
          icon: Icons.photo_library_outlined,
          label: 'Gallery',
          color: _K.royal,
          onTap: () => edit.pickFromGallery(context),
        ),
        const SizedBox(width: 10),
        _PhotoChip(
          icon: Icons.camera_alt_outlined,
          label: 'Camera',
          color: _K.teal,
          onTap: () => edit.pickFromCamera(context),
        ),
        if (edit.pickedImage != null || edit.existingPhotoUrl.isNotEmpty) ...[
          const SizedBox(width: 10),
          _PhotoChip(
            icon: Icons.delete_outline_rounded,
            label: 'Remove',
            color: _K.red,
            onTap: () => edit.removePhoto(),
          ),
        ],
      ]),
    ]);
  }

  void _showPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(edit: edit),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final EditProfileProvider edit;
  final double size;
  const _AvatarCircle({required this.edit, required this.size});

  @override
  Widget build(BuildContext context) {
    final profile = context.read<ProfileProvider>().profile;
    final initials = profile?.avatarInitials ?? 'U';
    final roleColor = profile?.role.color ?? _K.royal;

    // Show local picked image
    if (edit.pickedImage != null) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: _K.white, width: 3)),
        child: ClipOval(
          child: Image.file(edit.pickedImage!,
              width: size, height: size, fit: BoxFit.cover)));
    }

    // Show existing network photo
    if (edit.existingPhotoUrl.isNotEmpty) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: _K.white, width: 3)),
        child: ClipOval(
          child: Image.network(
            edit.existingPhotoUrl,
            width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _InitialsCircle(
                initials: initials, color: roleColor, size: size),
          )));
    }

    // Fallback — initials
    return _InitialsCircle(initials: initials, color: roleColor, size: size);
  }
}

class _InitialsCircle extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  const _InitialsCircle({required this.initials, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.65)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: _K.white, width: 3)),
      child: Center(
        child: Text(initials, style: TextStyle(
            color: Colors.white, fontSize: size * 0.32,
            fontWeight: FontWeight.w900, letterSpacing: 1))));
  }
}

class _PhotoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PhotoChip({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: color)),
        ]),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final EditProfileProvider edit;
  const _PickerSheet({required this.edit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      decoration: const BoxDecoration(
        color: _K.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: _K.line,
              borderRadius: BorderRadius.circular(2))),
        const Text('Update Profile Photo',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _K.ink)),
        const SizedBox(height: 6),
        Text('Choose a source for your photo',
          style: TextStyle(fontSize: 13, color: _K.muted)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
            child: _SheetOption(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              sub: 'Pick from photos',
              color: _K.royal,
              onTap: () { Navigator.pop(context); edit.pickFromGallery(context); },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _SheetOption(
              icon: Icons.camera_alt_rounded,
              label: 'Camera',
              sub: 'Take a new photo',
              color: _K.teal,
              onTap: () { Navigator.pop(context); edit.pickFromCamera(context); },
            ),
          ),
        ]),
        if (edit.pickedImage != null || edit.existingPhotoUrl.isNotEmpty) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () { Navigator.pop(context); edit.removePhoto(); },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _K.red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _K.red.withOpacity(0.20))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.delete_outline_rounded, color: _K.red, size: 18),
                SizedBox(width: 8),
                Text('Remove Photo', style: TextStyle(color: _K.red,
                    fontSize: 14, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _SheetOption({required this.icon, required this.label,
      required this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.18))),
        child: Column(children: [
          Container(width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.75)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: color.withOpacity(0.30),
                blurRadius: 8, offset: const Offset(0, 4))]),
            child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: _K.ink)),
          const SizedBox(height: 3),
          Text(sub, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _K.muted, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EDITABLE CARD — only name
// ─────────────────────────────────────────────────────────────────────────────
class _EditableCard extends StatelessWidget {
  final TextEditingController nameCtrl;
  final EditProfileProvider edit;
  const _EditableCard({required this.nameCtrl, required this.edit});

  @override
  Widget build(BuildContext context) {
    return _LuxCard(
      child: Column(children: [
        // Card header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: _K.royalSoft,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(bottom: BorderSide(color: _K.royalBorder))),
          child: Row(children: [
            Container(width: 28, height: 28,
              decoration: BoxDecoration(
                color: _K.royal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.edit_rounded, color: _K.royal, size: 15)),
            const SizedBox(width: 10),
            const Text('You can edit this',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                  color: _K.royal)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _K.royal.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20)),
              child: const Text('EDITABLE',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                    color: _K.royal, letterSpacing: 0.8))),
          ]),
        ),

        // Name field
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _K.royal.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.badge_outlined, color: _K.royal, size: 18)),
              const SizedBox(width: 13),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('FULL NAME', style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, color: _K.muted, letterSpacing: 0.5)),
                SizedBox(height: 1),
                Text('You can update your display name',
                  style: TextStyle(fontSize: 11, color: _K.muted)),
              ]),
            ]),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: _K.page,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: edit.nameChanged
                        ? _K.royal.withOpacity(0.50)
                        : _K.line,
                    width: edit.nameChanged ? 1.5 : 1.0)),
              child: Row(children: [
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: _K.ink),
                    decoration: const InputDecoration(
                      hintText: 'Enter your name',
                      hintStyle: TextStyle(color: _K.muted, fontSize: 15),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                if (edit.nameChanged)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(width: 8, height: 8,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _K.amber))),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  READ-ONLY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ReadOnlyCard extends StatelessWidget {
  final UserProfile profile;
  const _ReadOnlyCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final shortUid = profile.id.length > 18
        ? '${profile.id.substring(0, 18)}…'
        : profile.id;

    return _LuxCard(
      child: Column(children: [
        // Card header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(bottom: BorderSide(color: _K.line))),
          child: Row(children: [
            Container(width: 28, height: 28,
              decoration: BoxDecoration(
                  color: _K.muted.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.lock_outline_rounded, color: _K.muted, size: 15)),
            const SizedBox(width: 10),
            const Text('Read-only information',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: _K.muted)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _K.muted.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('LOCKED',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                    color: _K.muted, letterSpacing: 0.8))),
          ]),
        ),

        // Fields
        _RORow(label: 'EMAIL ADDRESS', value: profile.email,
          icon: Icons.alternate_email_rounded, iconColor: _K.violet,
          trailing: _SmallBadge(label: 'Verified', color: _K.green)),
        _Divider(),
        _RORow(label: 'PHONE NUMBER',
          value: profile.phone.isEmpty ? 'Not added' : profile.phone,
          icon: Icons.phone_outlined, iconColor: _K.teal),
        _Divider(),
        _RORow(label: 'ROLE',
          value: '${profile.role.emoji}  ${profile.role.label}',
          icon: Icons.work_outline_rounded, iconColor: profile.role.color),
        _Divider(),
        _RORow(label: 'BUSINESS',
          value: profile.businessName.isEmpty ? '—' : profile.businessName,
          icon: Icons.storefront_outlined, iconColor: _K.royal),
        _Divider(),
        _RORow(label: 'USER ID',
          value: shortUid,
          icon: Icons.fingerprint_rounded, iconColor: _K.muted,
          isLast: true,
          trailing: GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: profile.id));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('UID copied'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 1)));
            },
            child: Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: _K.royalSoft,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.copy_outlined, size: 13, color: _K.royal)))),
      ]),
    );
  }
}

class _RORow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconColor;
  final bool isLast;
  final Widget? trailing;

  const _RORow({required this.label, required this.value,
      required this.icon, required this.iconColor,
      this.isLast = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 17, color: iconColor.withOpacity(0.6))),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: _K.muted, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: _K.ink.withOpacity(0.55))),
        ])),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      height: 1, color: _K.line,
      margin: const EdgeInsets.only(left: 69));
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22))),
    child: Text(label, style: TextStyle(fontSize: 10,
        fontWeight: FontWeight.w800, color: color)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATUS BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final UserProfile profile;
  const _StatusBanner({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_K.royal.withOpacity(0.06), _K.royalLight.withOpacity(0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _K.royalBorder)),
      child: Row(children: [
        Container(width: 46, height: 46,
          decoration: BoxDecoration(
            color: profile.isActive
                ? _K.green.withOpacity(0.12)
                : _K.muted.withOpacity(0.10),
            borderRadius: BorderRadius.circular(15)),
          child: Icon(
            profile.isActive
                ? Icons.verified_user_outlined
                : Icons.block_outlined,
            color: profile.isActive ? _K.green : _K.muted, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            profile.isActive ? 'Account Active' : 'Account Inactive',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: profile.isActive ? _K.green : _K.muted)),
          const SizedBox(height: 3),
          Text('Member since ${profile.formattedJoinDate} · ${profile.tenureLabel}',
            style: const TextStyle(fontSize: 11, color: _K.muted)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: profile.isActive
                ? _K.green.withOpacity(0.10)
                : _K.muted.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: profile.isActive ? _K.green : _K.muted)),
            const SizedBox(width: 5),
            Text(profile.isActive ? 'Active' : 'Inactive',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                  color: profile.isActive ? _K.green : _K.muted)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SAVING OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
class _SavingOverlay extends StatelessWidget {
  const _SavingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.70),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: _K.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: _K.royal.withOpacity(0.15),
                blurRadius: 32, offset: const Offset(0, 10))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 48, height: 48,
              child: CircularProgressIndicator(
                color: _K.royal, strokeWidth: 3,
                backgroundColor: _K.royalBorder)),
            const SizedBox(height: 16),
            const Text('Saving changes…',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: _K.ink)),
            const SizedBox(height: 4),
            const Text('Uploading to Firebase',
              style: TextStyle(fontSize: 12, color: _K.muted)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DISCARD DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _DiscardDialog extends StatelessWidget {
  final VoidCallback onDiscard, onKeep;
  const _DiscardDialog({required this.onDiscard, required this.onKeep});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: _K.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10),
              blurRadius: 40, offset: const Offset(0, 12))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 54, height: 54,
            decoration: BoxDecoration(
                color: _K.amber.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.warning_amber_rounded,
                color: _K.amber, size: 26)),
          const SizedBox(height: 16),
          const Text('Discard changes?',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _K.ink)),
          const SizedBox(height: 8),
          const Text(
            'You have unsaved changes.\nAre you sure you want to go back?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _K.muted, height: 1.5)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: onKeep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                side: const BorderSide(color: _K.line, width: 1.5)),
              child: const Text('Keep Editing',
                style: TextStyle(color: _K.body, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: onDiscard,
              style: ElevatedButton.styleFrom(
                backgroundColor: _K.amber, foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              child: const Text('Discard',
                style: TextStyle(fontWeight: FontWeight.w800)))),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _LuxCard extends StatelessWidget {
  final Widget child;
  const _LuxCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _K.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _K.line),
      boxShadow: [
        BoxShadow(color: _K.royal.withOpacity(0.06),
            blurRadius: 22, offset: const Offset(0, 7)),
        BoxShadow(color: Colors.black.withOpacity(0.02),
            blurRadius: 4, offset: const Offset(0, 2)),
      ]),
    child: child);
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(title, style: const TextStyle(fontSize: 10,
        fontWeight: FontWeight.w800, color: _K.muted, letterSpacing: 2.0)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  DOT-GRID PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF1847C4).withOpacity(0.03);
    for (double x = 0; x < size.width; x += 22) {
      for (double y = 0; y < size.height; y += 22) {
        canvas.drawCircle(Offset(x, y), 1.1, p);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}