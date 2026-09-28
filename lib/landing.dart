import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final AnimationController _scanController;

  static const Color _bg          = Color(0xFF070F1E);
  static const Color _card        = Color(0xFF0F172A);
  static const Color _line        = Color(0xFF1E293B);
  static const Color _primary     = Color(0xFF2563EB);
  static const Color _primarySoft = Color(0xFF3B82F6);
  static const Color _text        = Color(0xFFF1F5F9);
  static const Color _muted       = Color(0xFF94A3B8);
  static const Color _green       = Color(0xFF10B981);
  static const Color _red         = Color(0xFFEF4444);

  final List<Map<String, dynamic>> _pricingPlans = [
  {
    'role': 'MEMBER',
    'desc': 'Akses dasar',
    'price': '7K',
    'color': const Color(0xFF10B981),
    'icon': Icons.person_rounded,
    'isBest': false,
  },
  {
    'role': 'RESELLER',
    'desc': 'Bisa jual akun',
    'price': '10K',
    'color': const Color(0xFF0891B2),
    'icon': Icons.storefront_rounded,
    'isBest': false,
  },
  {
    'role': 'ROLE OWN',
    'desc': 'Akses fitur khusus',
    'price': '12K',
    'color': const Color(0xFFF59E0B),
    'icon': Icons.workspace_premium_rounded,
    'isBest': false,
  },
  {
    'role': 'ADMIN',
    'desc': 'Kontrol penuh panel',
    'price': '20K',
    'color': const Color(0xFFEF4444),
    'icon': Icons.admin_panel_settings_rounded,
    'isBest': false,
  },
  {
    'role': 'OWN PERMANENT',
    'desc': 'Akses lifetime tanpa batas',
    'price': '25K',
    'color': const Color(0xFF8B5CF6),
    'icon': Icons.all_inclusive_rounded,
    'isBest': true, // ← BADGE
  },
];
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) { _showSnack('Link tidak valid.'); return; }
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) _showSnack('Tidak dapat membuka link.');
    } catch (_) {
      _showSnack('Terjadi kesalahan saat membuka link.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ── FINGERPRINT → INTRO CAROUSEL ──────────────────────────────────────
  void _startFingerprintScan() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return FadeTransition(
          opacity: anim1,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 160, height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _line, width: 2),
                          ),
                        ),
                        SizedBox(
                          width: 160, height: 160,
                          child: CircularProgressIndicator(
                            value: _scanController.value,
                            strokeWidth: 4,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _scanController.value == 1.0 ? _green : _primary,
                            ),
                          ),
                        ),
                        Icon(
                          _scanController.value == 1.0
                              ? Icons.check_circle
                              : Icons.fingerprint,
                          size: 70,
                          color: _scanController.value == 1.0
                              ? _green
                              : _primarySoft,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
                AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, child) {
                    return Text(
                      _scanController.value == 1.0
                          ? 'VERIFIKASI BERHASIL'
                          : 'MEMINDAI SIDIK JARI...',
                      style: TextStyle(
                        color: _scanController.value == 1.0 ? _green : _text,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Harap tunggu selama 5 detik',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );

    _scanController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop();
          // ← LANGSUNG KE INTRO CAROUSEL
          Navigator.pushNamed(context, '/intro');
        }
      });
    });
  }

  // ── PRICING PLAN MODAL ────────────────────────────────────────────────
  void _showPricingPlan() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: _line, width: 1.5)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.diamond, color: _primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('PRICING PLAN',
                        style: TextStyle(color: _text, fontSize: 18,
                            fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: _muted),
                    ),
                  ],
                ),
              ),
              const Divider(color: _line, height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _pricingPlans.length,
                  itemBuilder: (context, index) {
                    final plan = _pricingPlans[index];
                    return _buildPricingCard(
  role: plan['role'],
  desc: plan['desc'],
  price: plan['price'],
  color: plan['color'],
  icon: plan['icon'],
  isBest: plan['isBest'] ?? false,
);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openUrl('https://t.me/Crashbug1');
                    },
                    icon: const Icon(FontAwesomeIcons.telegram,
                        color: Colors.white, size: 18),
                    label: const Text('Chat Admin for Order',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPricingCard({
  required String role,
  required String desc,
  required String price,
  required Color color,
  required IconData icon,
  bool isBest = false,
}) {
  return GestureDetector(
    onTap: () => _openUrl('https://t.me/Crashbug1'),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12, top: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.12), color.withOpacity(0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withOpacity(isBest ? 0.8 : 0.4),
              width: isBest ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isBest ? 0.3 : 0.15),
                blurRadius: isBest ? 24 : 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.25), color.withOpacity(0.1)],
                  ),
                  border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)],
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role, style: const TextStyle(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    Text(desc, style: TextStyle(
                      color: _muted, fontSize: 11)),
                  ],
                ),
              ),

              // Harga
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Text('Rp$price', style: TextStyle(
                      color: color, fontSize: 15,
                      fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 4),
                  Text('Permanent', style: TextStyle(
                    color: _muted, fontSize: 9,
                    fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),

        // ── BADGE "BEST VALUE" ─────────────────────────────
        if (isBest)
          Positioned(
            top: 0, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8)),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Text(
                'BEST VALUE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF070F1E), Color(0xFF020617), Color(0xFF070F1E)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _GridBackground()),
            Positioned(
              top: -50, left: size.width * 0.1,
              child: _glow(size.width * 0.6, _primary.withOpacity(0.1)),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildTopImage(),
                            const SizedBox(height: 15),
                            _buildMascot(),
                            const SizedBox(height: 15),
                            _buildInfoSection(),
                            const SizedBox(height: 25),
                            _buildLoginButton(),
                            const SizedBox(height: 15),
                            _buildBuyAccessButton(),
                            const SizedBox(height: 15),
                            _buildFreeClickButton(),
                            const SizedBox(height: 25),
                            _buildContactHeader(),
                            const SizedBox(height: 15),
                            _buildBottomButtons(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity, height: 180, color: _card,
        child: Image.asset('assets/images/reze.png', fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(Icons.image, color: _muted, size: 50)),
        ),
      ),
    );
  }

  Widget _buildMascot() {
    return SizedBox(
      height: 100, width: 100,
      child: Image.asset('assets/images/reze.png', fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.person, color: _muted, size: 50)),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: _primarySoft, size: 20),
            const SizedBox(width: 8),
            const Text('INFO FANVXP', style: TextStyle(color: _primarySoft,
                fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: const Text(
            'APK FANVXP AKAN SELALU MEMBERIKAN UPDATE BAGUS DAN BUG WORK. SUPPORT KAMI LEWAT SALURAN WA & TELE DENGAN RESPON CEPAT 24/7.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 11, height: 1.6, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity, height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        boxShadow: [BoxShadow(color: _primary.withOpacity(0.4),
            blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _startFingerprintScan,
          borderRadius: BorderRadius.circular(30),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ENTER TO LOGIN', style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuyAccessButton() {
    return Container(
      width: double.infinity, height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
        boxShadow: [BoxShadow(color: _red.withOpacity(0.4),
            blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showPricingPlan,
          borderRadius: BorderRadius.circular(30),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('BELI ACCESS', style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFreeClickButton() {
    return Container(
      width: double.infinity, height: 50,
      decoration: BoxDecoration(
        color: _card.withOpacity(0.8),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSnack('APK Bug Free Clicked!'),
          borderRadius: BorderRadius.circular(25),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: _primarySoft, size: 18),
                SizedBox(width: 8),
                Text('APK BUG FREE CLIK', style: TextStyle(color: _text,
                    fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactHeader() {
    return const Text('HUBUNGI KAMI LEWAT', style: TextStyle(color: _muted,
        fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600));
  }

  Widget _buildBottomButtons() {
    return Row(
      children: [
        Expanded(
          child: _bottomButton(
            icon: FontAwesomeIcons.telegram,
            label: 'TELEGRAM',
            color: _primary,
            onTap: () => _openUrl('https://t.me/Crashbug1'),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _bottomButton(
            icon: FontAwesomeIcons.users,
            label: 'SALURAN',
            color: _green,
            onTap: () => _openUrl('https://t.me/fanvxpp'),
          ),
        ),
      ],
    );
  }

  Widget _bottomButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(color: color,
                    fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _GridBackground extends StatelessWidget {
  const _GridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0A3B82F6)
      ..strokeWidth = 1.0;
    const double step = 40.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}