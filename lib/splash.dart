import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dashboard_page.dart';

// ─── Palette: Abu-abu Gelap (selaras login_page) ──────────────────────────────
class _C {
  static const bg         = Color(0xFF0D0D0D);
  static const surface    = Color(0xFF181818);
  static const card       = Color(0xFF1F1F1F);
  static const border     = Color(0xFF2E2E2E);
  static const borderLit  = Color(0xFF484848);

  static const grayDark   = Color(0xFF1A1A1A);
  static const grayMid    = Color(0xFF2C2C2C);
  static const grayLight  = Color(0xFF3D3D3D);
  static const grayAccent = Color(0xFF606060);

  static const green      = Color(0xFF22C55E);
  static const amber      = Color(0xFFF59E0B);
  static const red        = Color(0xFFEF4444);

  static const text       = Color(0xFFEDEDED);
  static const textSub    = Color(0xFFAAAAAA);
  static const textDim    = Color(0xFF585858);

  static const LinearGradient btnGrad = LinearGradient(
    colors: [Color(0xFF3D3D3D), Color(0xFF252525), Color(0xFF141414)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class SplashScreen extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const SplashScreen({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
    required this.listBug,
    required this.listDoos,
    required this.news,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoCtrl;
  bool _videoReady      = false;
  bool _fadeOutStarted  = false;
  bool _isSkipping      = false;

  // Animations
  late AnimationController _fadeOutCtrl;
  late AnimationController _uiCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _ringCtrl;
  late AnimationController _progressCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _skipBtnCtrl;    // fade-in untuk tombol skip

  late Animation<double> _uiFade;
  late Animation<Offset>  _uiSlide;
  late Animation<double>  _glowAnim;
  late Animation<double>  _fadeOut;
  late Animation<double>  _skipFade;
  late Animation<double>  _skipScale;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initVideo();
  }

  void _initAnimations() {
    _fadeOutCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeOut = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeIn));

    _uiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _uiFade  = CurvedAnimation(parent: _uiCtrl, curve: Curves.easeOut);
    _uiSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _uiCtrl, curve: Curves.easeOutCubic));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat();

    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4));

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();

    // Skip button: muncul 1.5 detik setelah layar terbuka
    _skipBtnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _skipFade  = CurvedAnimation(parent: _skipBtnCtrl, curve: Curves.easeOut);
    _skipScale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _skipBtnCtrl, curve: Curves.easeOutBack));
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.asset('assets/videos/splash.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoCtrl.setLooping(false);
        _videoCtrl.play();

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _uiCtrl.forward();
            _progressCtrl.forward();
          }
        });

        // Tombol skip muncul 1.5 detik setelah video mulai
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) _skipBtnCtrl.forward();
        });

        _videoCtrl.addListener(_onVideoProgress);
      }).catchError((_) {
        if (mounted) {
          setState(() => _videoReady = false);
          _uiCtrl.forward();
          _progressCtrl.forward();
          // Tanpa video, skip tetap muncul
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) _skipBtnCtrl.forward();
          });
          Future.delayed(const Duration(seconds: 4), _navigate);
        }
      });
  }

  void _onVideoProgress() {
    if (!mounted) return;
    final pos = _videoCtrl.value.position;
    final dur = _videoCtrl.value.duration;
    if (dur == Duration.zero) return;

    if (pos >= dur - const Duration(seconds: 1) && !_fadeOutStarted) {
      _fadeOutStarted = true;
      _fadeOutCtrl.forward();
    }

    if (pos >= dur) _navigate();
  }

  // ─── Skip intro ───────────────────────────────────────────────────────────
  Future<void> _skipIntro() async {
    if (_isSkipping) return;
    setState(() => _isSkipping = true);

    // Hentikan video
    if (_videoCtrl.value.isInitialized) {
      await _videoCtrl.pause();
    }

    // Fade out lalu navigate
    if (!_fadeOutStarted) {
      _fadeOutStarted = true;
      await _fadeOutCtrl.forward();
    }

    _navigate();
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => DashboardPage(
          username:    widget.username,
          password:    widget.password,
          role:        widget.role,
          expiredDate: widget.expiredDate,
          sessionKey:  widget.sessionKey,
          listBug:     widget.listBug,
          listDoos:    widget.listDoos,
          news:        widget.news,
        ),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoCtrl.removeListener(_onVideoProgress);
    _videoCtrl.dispose();
    _fadeOutCtrl.dispose();
    _uiCtrl.dispose();
    _glowCtrl.dispose();
    _ringCtrl.dispose();
    _progressCtrl.dispose();
    _particleCtrl.dispose();
    _skipBtnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Particles background ───────────────────────────────────────
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(_particleCtrl.value),
              size: size,
            ),
          ),

          // ── Video (full cover) ─────────────────────────────────────────
          if (_videoReady)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width:  _videoCtrl.value.size.width,
                  height: _videoCtrl.value.size.height,
                  child: VideoPlayer(_videoCtrl),
                ),
              ),
            ),

          // ── Dark overlay ───────────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(_videoReady ? 0.2 : 0.0),
                    Colors.black.withOpacity(_videoReady ? 0.7 : 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Center logo & title ────────────────────────────────────────
          Positioned.fill(
            child: FadeTransition(
              opacity: _uiFade,
              child: SlideTransition(
                position: _uiSlide,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogoRing(),
                    const SizedBox(height: 36),
                    _buildTitle(),
                    const SizedBox(height: 10),
                    _buildSubtitle(),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom progress & loading ──────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _uiFade,
              child: _buildBottomBar(),
            ),
          ),

          // ── Skip Intro button (kanan atas) ─────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: FadeTransition(
              opacity: _skipFade,
              child: ScaleTransition(
                scale: _skipScale,
                child: _SkipButton(
                  onTap: _skipIntro,
                  isSkipping: _isSkipping,
                ),
              ),
            ),
          ),

          // ── Fade-out overlay ───────────────────────────────────────────
          if (_fadeOutStarted)
            FadeTransition(
              opacity: _fadeOut,
              child: Container(color: _C.bg),
            ),
        ],
      ),
    );
  }

  // ─── Logo Ring ─────────────────────────────────────────────────────────────
  Widget _buildLogoRing() {
    return AnimatedBuilder(
      animation: Listenable.merge([_ringCtrl, _glowCtrl]),
      builder: (_, __) => SizedBox(
        width: 160, height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer static ring
            Container(
              width: 158, height: 158,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _C.grayLight.withOpacity(_glowAnim.value * 0.15),
                  width: 1,
                ),
              ),
            ),
            // Rotating sweep ring
            Transform.rotate(
              angle: _ringCtrl.value * math.pi * 2,
              child: Container(
                width: 138, height: 138,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      _C.grayLight.withOpacity(_glowAnim.value * 0.7),
                      Colors.transparent,
                      _C.grayAccent.withOpacity(_glowAnim.value * 0.4),
                      Colors.transparent,
                      _C.grayLight.withOpacity(_glowAnim.value * 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Counter-rotating inner ring
            Transform.rotate(
              angle: -_ringCtrl.value * math.pi * 2 * 0.6,
              child: Container(
                width: 118, height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _C.grayMid.withOpacity(_glowAnim.value * 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // Core
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.bg,
                boxShadow: [
                  BoxShadow(
                    color: _C.grayLight.withOpacity(_glowAnim.value * 0.4),
                    blurRadius: 40,
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                  color: _C.grayAccent.withOpacity(_glowAnim.value * 0.5),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.water_rounded,
                        color: _C.grayAccent.withOpacity(_glowAnim.value),
                        size: 44),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Title ─────────────────────────────────────────────────────────────────
  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => ShaderMask(
        shaderCallback: (b) => LinearGradient(
          colors: [
            const Color(0xFFCCCCCC),
            Color.lerp(const Color(0xFF999999), const Color(0xFFEEEEEE),
                _glowAnim.value)!,
            const Color(0xFF888888),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(b),
        child: Text(
          'RDXSP',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: _C.grayLight.withOpacity(_glowAnim.value * 0.6),
                blurRadius: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _C.border.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _C.grayMid.withOpacity(_glowAnim.value * 0.35),
          ),
        ),
        child: Text(
          'Project by AQIEL X FAN',
          style: TextStyle(
            color: _C.textSub.withOpacity(0.7 + _glowAnim.value * 0.3),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // ─── Bottom Bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 52),
      child: Column(
        children: [
          const _LoadingDots(),
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: _progressCtrl,
            builder: (_, __) => Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(children: [
                  Container(
                    height: 3,
                    width: double.infinity,
                    color: _C.border.withOpacity(0.5),
                  ),
                  Container(
                    height: 3,
                    width: (MediaQuery.of(context).size.width - 64) *
                        _progressCtrl.value,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2C2C2C),
                          Color(0xFF505050),
                          Color(0xFF787878),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: _C.grayLight.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Text(
                '${(_progressCtrl.value * 100).toInt()}%  Memuat...',
                style: const TextStyle(
                  color: _C.textSub,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Skip Button ──────────────────────────────────────────────────────────────
class _SkipButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isSkipping;

  const _SkipButton({required this.onTap, required this.isSkipping});

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        if (!widget.isSkipping) widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _down
              ? _C.grayLight.withOpacity(0.55)
              : _C.surface.withOpacity(0.75),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _down ? _C.borderLit : _C.border,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isSkipping)
              const SizedBox(
                width: 11, height: 11,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: _C.textSub),
              )
            else
              const Icon(Icons.skip_next_rounded,
                  color: _C.textSub, size: 15),
            const SizedBox(width: 5),
            Text(
              widget.isSkipping ? 'Skipping...' : 'Skip Intro',
              style: const TextStyle(
                color: _C.textSub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading Dots ─────────────────────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_c.value - i / 3) % 1.0).clamp(0.0, 1.0);
          final s = math.sin(t * math.pi);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: 0.4 + s * 0.6,
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.grayLight.withOpacity(0.35 + s * 0.65),
                  boxShadow: [
                    BoxShadow(
                      color: _C.grayLight.withOpacity(s * 0.35),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Particle Painter ─────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double t;
  _ParticlePainter(this.t);

  static final _rand = math.Random(42);
  static final _particles = List.generate(28, (i) => _Particle(
    x: _rand.nextDouble(),
    y: _rand.nextDouble(),
    size: 1.0 + _rand.nextDouble() * 2.0,
    speed: 0.04 + _rand.nextDouble() * 0.1,
    phase: _rand.nextDouble(),
    opacity: 0.15 + _rand.nextDouble() * 0.35,
  ));

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final grid = Paint()
      ..color = const Color(0xFF2E2E2E).withOpacity(0.3)
      ..strokeWidth = 0.5;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Central glow abu-abu
    final center = Offset(size.width / 2, size.height * 0.38);
    final glow   = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF3D3D3D).withOpacity(
            0.18 + math.sin(t * math.pi * 2) * 0.06),
        Colors.transparent,
      ], radius: 0.6).createShader(
          Rect.fromCircle(center: center, radius: size.width * 0.7));
    canvas.drawCircle(center, size.width * 0.7, glow);

    // Floating particles
    for (final p in _particles) {
      final px = p.x * size.width;
      final rawY = p.y + (t * p.speed) % 1.0;
      final py = (rawY % 1.0) * size.height;
      final drift = math.sin((t + p.phase) * math.pi * 2) * 8;
      final osc = math.sin((t * 2 + p.phase) * math.pi);
      final opacity = p.opacity * (0.5 + osc * 0.5);

      canvas.drawCircle(
        Offset(px + drift, py),
        p.size,
        Paint()
          ..color = const Color(0xFF606060).withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

class _Particle {
  final double x, y, size, speed, phase, opacity;
  const _Particle({
    required this.x, required this.y, required this.size,
    required this.speed, required this.phase, required this.opacity,
  });
}
