import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_controller.dart';
import 'admin_gate_screen.dart';

/// Envuelve cualquier pantalla de administración: muestra un indicador
/// mientras se comprueba el permiso y la puerta de acceso si no es admin.
/// Centraliza el guard que antes copiaba cada pantalla (y que el wizard
/// no tenía, dejando su UI accesible por enlace directo).
class AdminGuard extends ConsumerWidget {
  const AdminGuard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(isAdminProvider);
    return admin.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, _) => const AdminGateScreen(),
      data: (isAdmin) => isAdmin ? child : const AdminGateScreen(),
    );
  }
}
