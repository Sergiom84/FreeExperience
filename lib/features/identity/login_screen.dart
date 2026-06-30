import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers.dart';
import 'identity_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _isSignUp = false;
  bool _pendingConfirmation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final identity = ref.read(identityProvider).asData?.value;
      if (identity?.status == IdentityStatus.linked) {
        context.go('/bienvenida');
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;
    if (_isSignUp && password != _confirmCtrl.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(identityServiceProvider);
      if (_isSignUp) {
        await svc.signUp(email, password);
        if (mounted) {
          setState(() {
            _loading = false;
            _pendingConfirmation = true;
          });
        }
        return;
      }
      await svc.signInWithPassword(email, password);
      if (mounted) context.go('/bienvenida');
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _acceptConfirmation() {
    setState(() {
      _pendingConfirmation = false;
      _isSignUp = false;
      _error = null;
      _passwordCtrl.clear();
      _confirmCtrl.clear();
    });
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login')) return 'Email o contraseña incorrectos.';
    if (msg.contains('email already')) {
      return 'Ya existe una cuenta con ese email.';
    }
    if (msg.contains('weak password')) {
      return 'Contraseña muy corta (mín. 6 caracteres).';
    }
    if (msg.contains('network')) return 'Sin conexión. Verifica tu red.';
    return 'Algo salió mal. Inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Background(size: size),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.50,
            child: _IllustrationLayer(size: size),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        _Header(),
                        const SizedBox(height: 28),
                        if (_pendingConfirmation)
                          _ConfirmationNotice(onAccept: _acceptConfirmation)
                        else ...[
                          _Form(
                            emailCtrl: _emailCtrl,
                            passwordCtrl: _passwordCtrl,
                            confirmCtrl: _confirmCtrl,
                            isSignUp: _isSignUp,
                            obscure: _obscure,
                            obscureConfirm: _obscureConfirm,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onToggleObscureConfirm: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 20),
                          _Actions(
                            loading: _loading,
                            isSignUp: _isSignUp,
                            onSubmit: _submit,
                            onToggleMode: () => setState(() {
                              _isSignUp = !_isSignUp;
                              _error = null;
                            }),
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Background ──────────────────────────────────────────────────────────────

class _Background extends StatelessWidget {
  const _Background({required this.size});
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF120820), Color(0xFF0C0A14)],
          stops: [0.0, 0.55],
        ),
      ),
    );
  }
}

// ─── Illustration ─────────────────────────────────────────────────────────────

class _IllustrationLayer extends StatelessWidget {
  const _IllustrationLayer({required this.size});
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Warm orange glow (bottom of illustration)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: size.height * 0.28,
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 0.8),
                radius: 1.0,
                colors: [Color(0xAAE8862A), Color(0x00E8862A)],
              ),
            ),
          ),
        ),
        // Purple/cosmic aura
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 0.85,
                colors: [Color(0x806B2FA0), Color(0x00000000)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Image.asset(
            'assets/images/login_illustration.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        // Fade to bg at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x000C0A14), Color(0xFF0C0A14)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _LotusSymbol(size: 22, color: Color(0xFFC8943A)),
        const SizedBox(height: 14),
        Text(
          'El Portal',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 34,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Respira. Entra. Conecta.',
          style: GoogleFonts.manrope(
            fontSize: 13.5,
            color: const Color(0xFFAA9EBB),
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        _GoldDivider(),
      ],
    );
  }
}

class _GoldDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 44, height: 0.5, color: const Color(0x55C8943A)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFC8943A),
            ),
          ),
        ),
        Container(width: 44, height: 0.5, color: const Color(0x55C8943A)),
      ],
    );
  }
}

// ─── Form ─────────────────────────────────────────────────────────────────────

class _Form extends StatelessWidget {
  const _Form({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.isSignUp,
    required this.obscure,
    required this.obscureConfirm,
    required this.onToggleObscure,
    required this.onToggleObscureConfirm,
    required this.onSubmitted,
  });

  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final bool isSignUp;
  final bool obscure;
  final bool obscureConfirm;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleObscureConfirm;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassField(
          controller: emailCtrl,
          hint: 'Correo electrónico',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _GlassField(
          controller: passwordCtrl,
          hint: 'Contraseña',
          icon: Icons.lock_outline_rounded,
          obscureText: obscure,
          textInputAction: isSignUp
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted: isSignUp ? null : onSubmitted,
          suffix: _EyeToggle(obscured: obscure, onTap: onToggleObscure),
        ),
        if (isSignUp) ...[
          const SizedBox(height: 12),
          _GlassField(
            controller: confirmCtrl,
            hint: 'Repetir contraseña',
            icon: Icons.lock_outline_rounded,
            obscureText: obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmitted,
            suffix: _EyeToggle(
              obscured: obscureConfirm,
              onTap: onToggleObscureConfirm,
            ),
          ),
        ],
      ],
    );
  }
}

class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.obscured, required this.onTap});

  final bool obscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: const Color(0xFF7A7090),
        size: 20,
      ),
    );
  }
}

class _ConfirmationNotice extends StatelessWidget {
  const _ConfirmationNotice({required this.onAccept});

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1C1628),
        border: Border.all(color: const Color(0x28FFFFFF), width: 0.6),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.mark_email_read_outlined,
            color: Color(0xFFC8943A),
            size: 38,
          ),
          const SizedBox(height: 16),
          Text(
            'Revisa tu correo',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Te hemos enviado un correo para confirmar tu acceso. '
            'Valida el enlace y vuelve para iniciar sesión.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.45,
              color: const Color(0xFFAA9EBB),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8913A), Color(0xFFD4721E)],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: onAccept,
                  child: Center(
                    child: Text(
                      'Aceptar',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1C1628),
        border: Border.all(color: const Color(0x28FFFFFF), width: 0.6),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.manrope(
            color: const Color(0xFF6A6080),
            fontSize: 15,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(icon, color: const Color(0xFF7A7090), size: 20),
          ),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffix,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 17,
            horizontal: 4,
          ),
        ),
      ),
    );
  }
}

// ─── Actions ──────────────────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  const _Actions({
    required this.loading,
    required this.isSignUp,
    required this.onSubmit,
    required this.onToggleMode,
  });

  final bool loading;
  final bool isSignUp;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [Color(0xFFE8913A), Color(0xFFD4721E)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE8913A).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: loading ? null : onSubmit,
                child: Center(
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _LotusSymbol(size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              isSignUp ? 'Crear cuenta' : 'Iniciar sesión',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 28, height: 0.5, color: const Color(0x25FFFFFF)),
            const SizedBox(width: 10),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x30FFFFFF),
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 28, height: 0.5, color: const Color(0x25FFFFFF)),
          ],
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onToggleMode,
          child: Text(
            isSignUp ? 'Ya tengo cuenta' : 'Crear cuenta',
            style: GoogleFonts.manrope(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Lotus symbol ─────────────────────────────────────────────────────────────

class _LotusSymbol extends StatelessWidget {
  const _LotusSymbol({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.72),
      painter: _LotusPainter(color: color),
    );
  }
}

class _LotusPainter extends CustomPainter {
  const _LotusPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.08
      ..strokeCap = StrokeCap.round;

    final cx = s.width / 2;
    final cy = s.height * 0.62;

    // Center petal
    _petal(canvas, p, cx, cy, 0, s.height * 0.72, s);
    // Side petals
    _petal(canvas, p, cx, cy, -s.width * 0.28, s.height * 0.52, s);
    _petal(canvas, p, cx, cy, s.width * 0.28, s.height * 0.52, s);
    _petal(canvas, p, cx, cy, -s.width * 0.46, s.height * 0.28, s);
    _petal(canvas, p, cx, cy, s.width * 0.46, s.height * 0.28, s);

    // Base line
    canvas.drawLine(
      Offset(cx - s.width * 0.42, cy + 1),
      Offset(cx + s.width * 0.42, cy + 1),
      p..strokeWidth = s.width * 0.06,
    );
  }

  void _petal(
    Canvas canvas,
    Paint p,
    double cx,
    double cy,
    double dx,
    double dy,
    Size s,
  ) {
    final path = Path()
      ..moveTo(cx, cy)
      ..quadraticBezierTo(cx + dx * 0.6, cy - dy * 0.55, cx + dx, cy - dy)
      ..quadraticBezierTo(cx + dx * 0.3, cy - dy * 0.4, cx, cy);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_LotusPainter o) => color != o.color;
}
