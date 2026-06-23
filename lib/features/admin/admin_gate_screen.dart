import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/domain/content_item.dart';
import 'admin_content_repository.dart';
import 'admin_controller.dart';

class AdminGateScreen extends ConsumerWidget {
  const AdminGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(isAdminProvider);
    return admin.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, _) => const _AdminLogin(),
      data: (isAdmin) =>
          isAdmin ? const _AdminDashboard() : const _AdminLogin(),
    );
  }
}

class _AdminLogin extends ConsumerStatefulWidget {
  const _AdminLogin();

  @override
  ConsumerState<_AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends ConsumerState<_AdminLogin> {
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _register = false;
  bool _pendingConfirmation = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_user.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Completa el email y la contraseña');
      return;
    }
    if (_register && _password.text != _confirm.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(adminAuthProvider);
      if (_register) {
        await auth.register(_user.text, _password.text);
        if (mounted) {
          setState(() {
            _busy = false;
            _pendingConfirmation = true;
          });
        }
        return;
      }
      await auth.signIn(_user.text, _password.text);
      ref.invalidate(isAdminProvider);
      final isAdmin = await ref.read(isAdminProvider.future);
      if (!isAdmin) {
        await auth.signOut();
        ref.invalidate(isAdminProvider);
        if (mounted) {
          setState(() => _error = 'Cuenta sin permiso de administración');
        }
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error = _register
              ? 'No se pudo crear la cuenta'
              : 'Usuario o contraseña incorrectos',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restablecer contraseña'),
      content: const Text(
        'Contacta con el administrador para restablecer tu contraseña.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_pendingConfirmation) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Free Experience',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Hemos enviado un mail a tu cuenta. Confirma tu dirección de correo para poder acceder.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => setState(() {
                      _pendingConfirmation = false;
                      _register = false;
                      _password.clear();
                      _confirm.clear();
                    }),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Free Experience',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _user,
                autofocus: true,
                enabled: !_busy,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                textInputAction: _register
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) => _register ? null : _submit(),
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
              if (_register) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Repetir contraseña',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_register ? 'Crear cuenta' : 'Entrar'),
              ),
              const SizedBox(height: 8),
              if (!_register)
                TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _register = !_register;
                        _error = null;
                      }),
                child: Text(_register ? 'Ya tengo cuenta' : 'Regístrate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDashboard extends ConsumerWidget {
  const _AdminDashboard();

  static const _sections = [
    ContentKind.meditation,
    ContentKind.practice,
    ContentKind.channeling,
    ContentKind.video,
    ContentKind.recommendation,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(adminAuthProvider).signOut();
              ref.invalidate(isAdminProvider);
              if (context.mounted) context.go('/meditar');
            },
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.6,
        children: [
          for (final kind in _sections)
            _SectionCard(
              label: kind.label,
              onTap: () => context.push('/admin/${kind.databaseValue}'),
            ),
        ],
      ),
    );
  }
}

class AdminSectionScreen extends ConsumerWidget {
  const AdminSectionScreen({required this.kind, super.key});

  final ContentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(isAdminProvider).value ?? false;
    if (!admin) return const AdminGateScreen();
    final items = ref.watch(adminItemsProvider(kind));
    return Scaffold(
      appBar: AppBar(title: Text(kind.label)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/admin/${kind.databaseValue}/nuevo');
          ref.invalidate(adminItemsProvider(kind));
        },
        icon: const Icon(Icons.add),
        label: const Text('Crear'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.invalidate(adminItemsProvider(kind)),
        child: items.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (_, _) => const Center(child: Text('No se pudo cargar')),
          data: (rows) => rows.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(
                      height: 280,
                      child: Center(child: Text('Sin contenido')),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                  itemBuilder: (context, i) => _ItemRow(
                    row: rows[i],
                    onTap: () async {
                      await context.push(
                        '/admin/${kind.databaseValue}/editar/${rows[i].id}',
                      );
                      ref.invalidate(adminItemsProvider(kind));
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.row, required this.onTap});

  final AdminContentRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (row.status) {
      'published' => 'Publicado',
      'archived' => 'Archivado',
      _ => 'Borrador',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(row.title),
      subtitle: row.author == null ? null : Text(row.author!),
      trailing: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Text(label, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
    );
  }
}
