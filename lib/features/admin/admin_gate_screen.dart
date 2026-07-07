import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/util/app_log.dart';
import '../../core/util/formatters.dart';
import '../content/domain/content_item.dart';
import 'admin_content_repository.dart';
import 'admin_controller.dart';
import 'admin_guard.dart';

class AdminGateScreen extends ConsumerWidget {
  const AdminGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(isAdminProvider);
    return admin.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, _) => const AdminCheckErrorScreen(),
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
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
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
      if (!mounted) return;
      ref.invalidate(isAdminProvider);
      final isAdmin = await ref.read(isAdminProvider.future);
      if (!isAdmin) {
        await auth.signOut();
        if (!mounted) return;
        ref.invalidate(isAdminProvider);
        setState(() => _error = 'Cuenta sin permiso de administración');
      }
    } on Object catch (error, stackTrace) {
      reportError(error, stackTrace, context: 'AdminLogin.submit');
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
                obscureText: _obscurePassword,
                textInputAction: _register
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) => _register ? null : _submit(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              if (_register) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Repetir contraseña',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
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
    (
      kind: ContentKind.meditation,
      icon: Icons.self_improvement,
      color: Color(0xFF7C3AED),
    ),
    (kind: ContentKind.practice, icon: Icons.spa, color: Color(0xFF059669)),
    (kind: ContentKind.channeling, icon: Icons.waves, color: Color(0xFF2563EB)),
    (
      kind: ContentKind.video,
      icon: Icons.play_circle,
      color: Color(0xFFDC2626),
    ),
    (
      kind: ContentKind.recommendation,
      icon: Icons.star,
      color: Color(0xFFD97706),
    ),
    // Extras
    (kind: ContentKind.intro, icon: Icons.wb_sunny, color: Color(0xFFEA8C2A)),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 480 ? 3 : 2;
              return GridView.count(
                padding: const EdgeInsets.all(20),
                crossAxisCount: columns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.92,
                children: [
                  for (final s in _sections)
                    _SectionCard(
                      label: s.kind == ContentKind.intro
                          ? 'Extras'
                          : s.kind.label,
                      icon: s.icon,
                      color: s.color,
                      onTap: () => context.push(
                        s.kind == ContentKind.intro
                            ? '/admin/extras'
                            : '/admin/${s.kind.databaseValue}',
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class AdminSectionScreen extends ConsumerWidget {
  const AdminSectionScreen({required this.kind, super.key});

  final ContentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              : _GroupedAdminList(kind: kind, rows: rows),
        ),
      ),
    );
  }
}

/// Lista del panel agrupada por mes de creación, con deslizar para eliminar.
class _GroupedAdminList extends ConsumerStatefulWidget {
  const _GroupedAdminList({required this.kind, required this.rows});

  final ContentKind kind;
  final List<AdminContentRow> rows;

  @override
  ConsumerState<_GroupedAdminList> createState() => _GroupedAdminListState();
}

class _GroupedAdminListState extends ConsumerState<_GroupedAdminList> {
  // Copia local: la fila descartada debe desaparecer del árbol en el mismo
  // frame (Dismissible lo exige); el provider se refresca después.
  late List<AdminContentRow> _rows = widget.rows;

  ContentKind get kind => widget.kind;

  @override
  void didUpdateWidget(covariant _GroupedAdminList old) {
    super.didUpdateWidget(old);
    if (!identical(old.rows, widget.rows)) _rows = widget.rows;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _groupByMonth(_rows);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        if (entry is _MonthHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(
              entry.label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        final row = (entry as _ContentEntry).row;
        return Dismissible(
          key: ValueKey(row.id),
          direction: DismissDirection.endToStart,
          background: ColoredBox(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
          confirmDismiss: (_) => _confirmAndDelete(context, row),
          onDismissed: (_) {
            setState(() {
              _rows = [..._rows]..removeWhere((r) => r.id == row.id);
            });
            ref.invalidate(adminItemsProvider(kind));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Eliminado')));
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ItemRow(
                  row: row,
                  onTap: () async {
                    await context.push(
                      '/admin/${kind.databaseValue}/editar/${row.id}',
                    );
                    ref.invalidate(adminItemsProvider(kind));
                  },
                ),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _confirmAndDelete(
    BuildContext context,
    AdminContentRow row,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Eliminar "${row.title}"? No se puede deshacer.'),
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
    if (confirmed != true) return false;
    try {
      await ref.read(adminContentRepositoryProvider).delete(row.id);
      return true;
    } on Object catch (error, stackTrace) {
      reportError(error, stackTrace, context: 'AdminList.delete');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se pudo eliminar')));
      }
      return false;
    }
  }
}

sealed class _AdminEntry {
  const _AdminEntry();
}

class _MonthHeader extends _AdminEntry {
  const _MonthHeader(this.label);
  final String label;
}

class _ContentEntry extends _AdminEntry {
  const _ContentEntry(this.row);
  final AdminContentRow row;
}

/// Agrupa por mes de creación, más reciente primero; sin fecha al final.
List<_AdminEntry> _groupByMonth(List<AdminContentRow> rows) {
  final sorted = [...rows]
    ..sort((a, b) {
      final da = a.createdAt;
      final db = b.createdAt;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
  final entries = <_AdminEntry>[];
  String? current;
  for (final row in sorted) {
    final label = formatMonthYear(row.createdAt);
    if (label != current) {
      current = label;
      entries.add(_MonthHeader(label));
    }
    entries.add(_ContentEntry(row));
  }
  return entries;
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
    final meta = [
      formatLongDate(row.createdAt),
      formatClock(row.durationSeconds),
    ].where((value) => value.isNotEmpty).join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      onTap: onTap,
      leading: _AdminCover(url: row.coverUrl),
      title: Text(row.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.author != null) Text(row.author!),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(meta, style: Theme.of(context).textTheme.labelSmall),
            ),
        ],
      ),
      isThreeLine: row.author != null && meta.isNotEmpty,
      trailing: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _AdminCover extends StatelessWidget {
  const _AdminCover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        size: 20,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 56,
        height: 42,
        child: url == null
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.85),
                          color.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(icon, color: Colors.white, size: 34),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
