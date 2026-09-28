import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'splash.dart';

const String baseUrl = 'http://denis.resjamin.awet.193.smasnug.web.id:4378';

// ─── Palette: Abu-abu Gelap / Charcoal ────────────────────────────────────────
class _C {
  static const bg         = Color(0xFF0D0D0D);      // Hampir hitam
  static const surface    = Color(0xFF181818);      // Abu gelap surface
  static const card       = Color(0xFF1F1F1F);      // Abu card
  static const border     = Color(0xFF2E2E2E);      // Abu border
  static const borderLit  = Color(0xFF484848);      // Abu terang border

  // Gradasi abu-abu
  static const grayDark   = Color(0xFF1A1A1A);
  static const grayMid    = Color(0xFF2C2C2C);
  static const grayLight  = Color(0xFF3D3D3D);
  static const grayAccent = Color(0xFF606060);

  static const green      = Color(0xFF22C55E);
  static const amber      = Color(0xFFF59E0B);
  static const red        = Color(0xFFEF4444);

  static const text       = Color(0xFFEDEDED);      // Putih abu
  static const textSub    = Color(0xFFAAAAAA);      // Abu muda
  static const textDim    = Color(0xFF585858);      // Abu redup

  // Gradien abu-abu
  static const LinearGradient grayGrad = LinearGradient(
    colors: [Color(0xFF3D3D3D), Color(0xFF252525), Color(0xFF141414)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  final userCtrl    = TextEditingController();
  final passCtrl    = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  bool _isLoading       = false;
  bool _obscurePass     = true;
  String? _androidId;

  // Animations
  late AnimationController _bgCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _btnCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _fade;
  late Animation<Offset>  _slide;
  late Animation<double>  _logoGlow;
  late Animation<double>  _btnPulse;
  late Animation<double>  _shake;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _logoGlow = Tween<double>(begin: 0.3, end: 0.85)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOut));

    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _btnPulse = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -7.0),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0),   weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: 0.0),    weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _entranceCtrl.forward();
    _initLogin();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    _logoCtrl.dispose();
    _btnCtrl.dispose();
    _shakeCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  // ─── Init auto-login ──────────────────────────────────────────────────────
  Future<void> _initLogin() async {
    final info = await DeviceInfoPlugin().androidInfo;
    _androidId = info.id;

    final prefs    = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('username');
    final savedPass = prefs.getString('password');
    final savedKey  = prefs.getString('key');

    if (savedUser != null && savedPass != null && savedKey != null) {
      try {
        final res  = await http.get(Uri.parse(
            '$baseUrl/myInfo?username=$savedUser&password=$savedPass&androidId=$_androidId&key=$savedKey'));
        final data = jsonDecode(res.body);

        if (data['valid'] == true && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => SplashScreen(
              username: savedUser, password: savedPass,
              role: data['role'], sessionKey: data['key'],
              expiredDate: data['expiredDate'],
              listBug:  _parseList(data['listBug']),
              listDoos: _parseList(data['listDDoS']),
              news:     _parseList(data['news']),
            )),
          );
        }
      } catch (_) {}
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) =>
      (raw as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  // ─── Login ────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final username = userCtrl.text.trim();
    final password = passCtrl.text.trim();

    setState(() => _isLoading = true);

    try {
      final res  = await http.post(Uri.parse('$baseUrl/validate'), body: {
        'username': username,
        'password': password,
        'androidId': _androidId ?? 'unknown',
      });
      final data = jsonDecode(res.body);

      if (data['expired'] == true) {
        _shakeCtrl.forward(from: 0);
        _showAlert(
          title:   'Akses Habis',
          message: 'Masa akses Anda telah berakhir. Silakan perpanjang.',
          type:    _AlertType.warning,
          showContact: true,
        );
      } else if (data['valid'] != true) {
        _shakeCtrl.forward(from: 0);
        final msg = (data['message'] ?? '').toString().toLowerCase();
        if (msg.contains('perangkat') || msg.contains('device') ||
            msg.contains('another')) {
          _showAlert(
            title:   'Sesi Aktif',
            message: 'Akun ini sedang login di perangkat lain.',
            type:    _AlertType.warning,
          );
        } else {
          _showAlert(
            title:   'Login Gagal',
            message: 'Username atau password salah.',
            type:    _AlertType.error,
          );
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('username', username);
        prefs.setString('password', password);
        prefs.setString('key', data['key']);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => SplashScreen(
              username: username, password: password,
              role: data['role'], sessionKey: data['key'],
              expiredDate: data['expiredDate'],
              listBug:  _parseList(data['listBug']),
              listDoos: _parseList(data['listDDoS']),
              news:     _parseList(data['news']),
            )),
          );
        }
      }
    } catch (_) {
      _shakeCtrl.forward(from: 0);
      _showAlert(
        title:   'Koneksi Error',
        message: 'Gagal terhubung ke server. Periksa jaringan Anda.',
        type:    _AlertType.error,
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ─── Alert dialog ─────────────────────────────────────────────────────────
  void _showAlert({
    required String title,
    required String message,
    required _AlertType type,
    bool showContact = false,
  }) {
    final color = switch (type) {
      _AlertType.error   => _C.red,
      _AlertType.warning => _C.amber,
      _AlertType.success => _C.green,
    };
    final icon = switch (type) {
      _AlertType.error   => Icons.error_rounded,
      _AlertType.warning => Icons.warning_amber_rounded,
      _AlertType.success => Icons.check_circle_rounded,
    };

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.12), blurRadius: 50),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: _C.text,
                fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSub,
                    fontSize: 13, height: 1.5)),
            const SizedBox(height: 22),
            if (showContact) ...[
              _GradBtn(
                label: 'Hubungi Admin',
                fullWidth: true,
                onTap: () async {
                  Navigator.pop(ctx);
                  await launchUrl(Uri.parse('https://t.me/aqieproj'),
                      mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 10),
            ],
            _OutlineBtn(
              label: showContact ? 'Tutup' : 'OK',
              fullWidth: true,
              onTap: () => Navigator.pop(ctx),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 32),
                        _buildHeading(),
                        const SizedBox(height: 36),
                        AnimatedBuilder(
                          animation: _shake,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(_shake.value, 0),
                            child: child,
                          ),
                          child: _buildForm(),
                        ),
                        const SizedBox(height: 28),
                        _buildFooter(),
                      ],
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

  // ─── Logo ─────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoGlow,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _C.grayLight.withOpacity(_logoGlow.value * 0.2),
                width: 1,
              ),
            ),
          ),
          // Mid ring
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _C.grayMid.withOpacity(_logoGlow.value * 0.4),
                width: 1.5,
              ),
            ),
          ),
          // Core
          Hero(
            tag: 'logo',
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2A2A), Color(0xFF3A3A3A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _C.grayAccent.withOpacity(_logoGlow.value * 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.grayLight.withOpacity(_logoGlow.value * 0.35),
                    blurRadius: 28,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.water_rounded, color: _C.grayAccent, size: 36)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    return Column(children: [
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(
          colors: [Color(0xFFCCCCCC), Color(0xFF888888)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(b),
        child: const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
      const SizedBox(height: 6),
      const Text('Masukan akunmu untuk melanjutkan',
          style: TextStyle(color: _C.textSub, fontSize: 14)),
    ]);
  }

  // ─── Form ─────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4),
              blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(children: [
          _LoginField(
            controller: userCtrl,
            hintText: 'Username',
            prefixIcon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Username tidak boleh kosong' : null,
          ),
          const SizedBox(height: 14),

          _LoginField(
            controller: passCtrl,
            hintText: 'Password',
            prefixIcon: Icons.lock_outline_rounded,
            obscure: _obscurePass,
            onToggleObscure: () =>
                setState(() => _obscurePass = !_obscurePass),
            validator: (v) => (v == null || v.isEmpty)
                ? 'Password tidak boleh kosong' : null,
          ),
          const SizedBox(height: 24),

          _LoginButton(
            isLoading: _isLoading,
            pulseAnim: _btnPulse,
            onTap: _login,
          ),
        ]),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(children: [
      const SizedBox(height: 10),
      Text('© 2026 Copyright By FANVXP',
          style: TextStyle(color: _C.textDim, fontSize: 11)),
    ]);
  }
}

// ─── Login Field ──────────────────────────────────────────────────────────────
class _LoginField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;

  const _LoginField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
  });

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  bool _focused = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? _C.grayAccent : _C.border,
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: Colors.white.withOpacity(0.05),
                blurRadius: 14, offset: const Offset(0, 4))]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscure,
        validator: widget.validator,
        style: const TextStyle(color: _C.text, fontSize: 15,
            fontWeight: FontWeight.w500),
        cursorColor: _C.grayAccent,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: _C.textSub.withOpacity(0.7), fontSize: 14),
          prefixIcon: Icon(widget.prefixIcon,
              color: _focused ? _C.grayAccent : _C.textSub, size: 20),
          suffixIcon: widget.onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    widget.obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _C.textSub, size: 20,
                  ),
                  onPressed: widget.onToggleObscure,
                )
              : null,
          errorStyle: const TextStyle(color: _C.red, fontSize: 11),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ─── Login Button ─────────────────────────────────────────────────────────────
class _LoginButton extends StatefulWidget {
  final bool isLoading;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  const _LoginButton({
    required this.isLoading,
    required this.pulseAnim,
    required this.onTap,
  });

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedBuilder(
        animation: widget.pulseAnim,
        builder: (_, __) => Transform.scale(
          scale: widget.isLoading || _down ? 1.0 : widget.pulseAnim.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: _C.grayGrad,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _down || widget.isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                            widget.pulseAnim.value * 0.5),
                        blurRadius: 22,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: widget.isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        key: ValueKey('idle'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.login_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Text('Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              )),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Gradient Button ──────────────────────────────────────────────────────────
class _GradBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  const _GradBtn({required this.label, required this.onTap,
      this.fullWidth = false});

  @override
  State<_GradBtn> createState() => _GradBtnState();
}

class _GradBtnState extends State<_GradBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 46,
          width: widget.fullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            gradient: _C.grayGrad,
            borderRadius: BorderRadius.circular(13),
            boxShadow: _down ? [] : [
              BoxShadow(color: Colors.black.withOpacity(0.35),
                  blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(widget.label,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

// ─── Outline Button ───────────────────────────────────────────────────────────
class _OutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  const _OutlineBtn({required this.label, required this.onTap,
      this.fullWidth = false});

  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 46,
        width: widget.fullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: _down ? _C.border.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _C.border),
        ),
        child: Center(
          child: Text(widget.label,
              style: const TextStyle(color: _C.textSub,
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ),
    );
  }
}

// ─── Animated Background ──────────────────────────────────────────────────────
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) =>
          CustomPaint(painter: _BgPainter(controller.value)),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid abu-abu tipis
    final grid = Paint()
      ..color = const Color(0xFF2E2E2E).withOpacity(0.35)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Glow utama abu-abu gelap
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF3D3D3D).withOpacity(
            0.18 + math.sin(t * math.pi * 2) * 0.05),
        Colors.transparent,
      ], radius: 0.75).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.35),
          radius: size.width * 0.7));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.35), size.width * 0.7, glow);

    // Secondary orb abu-abu tipis
    final glow2 = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF505050).withOpacity(
            0.10 + math.cos(t * math.pi * 2) * 0.03),
        Colors.transparent,
      ], radius: 0.5).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.1, size.height * 0.7),
          radius: size.width * 0.4));
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.7), size.width * 0.4, glow2);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

enum _AlertType { error, warning, success }
