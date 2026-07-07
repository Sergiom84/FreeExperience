import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/util/app_log.dart';
import '../../core/util/formatters.dart';
import '../content/domain/content_item.dart';
import 'admin_content_repository.dart';
import 'admin_controller.dart';
import 'admin_dashboard_screen.dart';
import 'admin_guard.dart';
import 'admin_login_screen.dart';

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
          isAdmin ? const AdminDashboard() : const AdminLoginScreen(),
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
    final meta = joinMeta([
      formatLongDate(row.createdAt),
      formatClock(row.durationSeconds),
    ]);
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
