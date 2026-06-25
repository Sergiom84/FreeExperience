import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design_direction.dart';
import '../../core/providers.dart';
import '../admin/admin_controller.dart';
import '../identity/identity_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity =
        ref.watch(identityProvider).value ??
        const IdentitySnapshot(status: IdentityStatus.offlineGuest);
    final selected = ref.watch(designDirectionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
        children: [
          _IdentityBlock(identity: identity),
          const SizedBox(height: 38),
          Text(
            'Dirección visual',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 38),
          _AccountActions(identity: identity),
          const _AdminEntry(),
          const SizedBox(height: 38),
          Text(
            'Información',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
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
      ),
    );
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

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.identity});

  final IdentitySnapshot identity;

  @override
  Widget build(BuildContext context) {
    final label = switch (identity.status) {
      IdentityStatus.offlineGuest => 'Modo local',
      IdentityStatus.anonymous => 'Cuenta privada',
      IdentityStatus.linked => identity.email ?? 'Cuenta vinculada',
    };
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: const Icon(Icons.person_outline),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
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
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => _confirmDeletion(context, ref),
          child: const Text('Eliminar cuenta'),
        ),
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
