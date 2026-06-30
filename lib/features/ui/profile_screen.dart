import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design_direction.dart';
import '../../core/providers.dart';
import '../admin/admin_controller.dart';
import '../admin/file_pick.dart';
import '../identity/identity_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity =
        ref.watch(identityProvider).value ??
        const IdentitySnapshot(status: IdentityStatus.offlineGuest);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
        children: [
          _ProfileHeader(identity: identity),
          const SizedBox(height: 32),
          const _DesignDirectionSection(),
          const SizedBox(height: 8),
          const _InformationSection(),
          const SizedBox(height: 28),
          _AccountActions(identity: identity),
          const _AdminEntry(),
        ],
      ),
    );
  }
}

class _ProfileHeader extends ConsumerStatefulWidget {
  const _ProfileHeader({required this.identity});

  final IdentitySnapshot identity;

  @override
  ConsumerState<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<_ProfileHeader> {
  bool _busy = false;

  bool get _canEdit => widget.identity.status == IdentityStatus.linked;

  Future<void> _changePhoto() async {
    if (_busy) return;
    final picked = await pickFile('image/*');
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).uploadAvatar(picked.bytes);
      ref.invalidate(avatarUrlProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Foto actualizada')));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo subir la foto')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (widget.identity.status) {
      IdentityStatus.offlineGuest => 'Modo local',
      IdentityStatus.anonymous => 'Cuenta privada',
      IdentityStatus.linked => widget.identity.email ?? 'Cuenta vinculada',
    };
    final avatarUrl = ref.watch(avatarUrlProvider).value;
    return Row(
      children: [
        Semantics(
          button: _canEdit,
          label: 'Cambiar foto de perfil',
          child: InkWell(
            onTap: _canEdit && !_busy ? _changePhoto : null,
            customBorder: const CircleBorder(),
            child: _Avatar(url: avatarUrl, busy: _busy, editable: _canEdit),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_canEdit) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _busy ? null : _changePhoto,
                  child: Text(
                    avatarUrl == null ? 'Añadir foto' : 'Cambiar foto',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.busy,
    required this.editable,
  });

  final String? url;
  final bool busy;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.person_outline,
      color: Theme.of(context).colorScheme.outline,
    );
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          ClipOval(
            child: SizedBox(
              width: 64,
              height: 64,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  shape: BoxShape.circle,
                ),
                child: url == null
                    ? Center(child: placeholder)
                    : Image.network(
                        url!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(child: placeholder),
                      ),
              ),
            ),
          ),
          if (busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          else if (editable)
            Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 13,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesignDirectionSection extends ConsumerWidget {
  const _DesignDirectionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(designDirectionProvider);
    return _SectionTile(
      title: 'Dirección visual',
      children: [
        for (final direction in DesignDirection.values) ...[
          _DirectionTile(
            direction: direction,
            selected: selected == direction,
            onTap: () =>
                ref.read(designDirectionProvider.notifier).select(direction),
          ),
          if (direction != DesignDirection.values.last)
            const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _InformationSection extends StatelessWidget {
  const _InformationSection();

  @override
  Widget build(BuildContext context) {
    return _SectionTile(
      title: 'Información',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Privacidad'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/legal/privacy'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Términos'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/legal/terms'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bienestar'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/legal/wellbeing'),
        ),
      ],
    );
  }
}

/// Collapsible section that matches the flat, borderless profile style.
class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4, bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        children: children,
      ),
    );
  }
}

class _DirectionTile extends StatelessWidget {
  const _DirectionTile({
    required this.direction,
    required this.selected,
    required this.onTap,
  });

  final DesignDirection direction;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  direction.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountActions extends ConsumerWidget {
  const _AccountActions({required this.identity});

  final IdentitySnapshot identity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = identity.status != IdentityStatus.offlineGuest;
    if (identity.status == IdentityStatus.linked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: () => _confirmSignOut(context, ref),
            child: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _confirmDeletion(context, ref),
              child: const Text('Eliminar cuenta'),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: enabled ? () => _linkEmail(context, ref) : null,
          child: const Text('Vincular email'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: enabled
              ? () => _runAction(
                  context,
                  ref.read(identityServiceProvider).linkApple,
                  'No se pudo vincular Apple',
                )
              : null,
          child: const Text('Continuar con Apple'),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(
      context,
      ref.read(identityServiceProvider).signOut,
      'No se pudo cerrar sesión',
    );
  }

  Future<void> _linkEmail(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular email'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.trim().isEmpty || !context.mounted) return;
    await _runAction(
      context,
      () => ref.read(identityServiceProvider).linkEmail(email),
      'No se pudo vincular el email',
    );
  }

  Future<void> _confirmDeletion(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(
      context,
      ref.read(identityServiceProvider).deleteAccount,
      'No se pudo eliminar la cuenta',
    );
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
    String errorMessage,
  ) async {
    try {
      await action();
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }
}

class _AdminEntry extends ConsumerWidget {
  const _AdminEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    if (!isAdmin) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => context.push('/admin'),
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: const Text('Administración'),
        ),
      ),
    );
  }
}
