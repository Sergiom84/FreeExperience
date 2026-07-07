import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/app_log.dart';
import 'admin_controller.dart';

/// Acceso al panel: inicio de sesión y alta de cuenta de administración.
/// Extraído de admin_gate_screen.dart.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
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
