import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF060B14);
  static const surface   = Color(0xFF0C1424);
  static const card      = Color(0xFF101A2E);
  static const border    = Color(0xFF1A2D4A);
  static const borderLit = Color(0xFF1E3A5F);

  static const blue      = Color(0xFF1B6FBD);
  static const blueMid   = Color(0xFF2D8FE8);
  static const blueLight = Color(0xFF56AEF5);

  static const green     = Color(0xFF22C55E);
  static const amber     = Color(0xFFF59E0B);
  static const red       = Color(0xFFEF4444);
  static const purple    = Color(0xFFA78BFA);

  static const text      = Color(0xFFE2EDF9);
  static const textSub   = Color(0xFF7A9BBF);
  static const textDim   = Color(0xFF3A5470);

  static const LinearGradient btnGrad = LinearGradient(
    colors: [blueMid, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Rules data ───────────────────────────────────────────────────────────────
const _rules = [
  _Rule(
    title: 'Larangan Barter Akun',
    desc:  'Akun tidak boleh ditukar dengan barang, jasa, atau akun lain dalam bentuk apa pun.',
    icon:  Icons.swap_horiz_rounded,
    color: Color(0xFFF59E0B),
  ),
  _Rule(
    title: 'Larangan Membagikan Akun',
    desc:  'Setiap akun bersifat pribadi dan hanya boleh digunakan oleh pemilik akun yang terdaftar.',
    icon:  Icons.share_rounded,
    color: Color(0xFF60A5FA),
  ),
  _Rule(
    title: 'Larangan Menjual Akun',
    desc:  'Member TIDAK diperbolehkan menjual akun. Penjualan hanya boleh dilakukan oleh role yang diizinkan secara resmi.',
    icon:  Icons.sell_rounded,
    color: Color(0xFFEF4444),
  ),
  _Rule(
    title: 'Larangan Jual Durasi Ilegal',
    desc:  'Dilarang menjual akses harian, mingguan, trial, atau sejenisnya di luar ketentuan yang telah ditetapkan.',
    icon:  Icons.timer_off_rounded,
    color: Color(0xFFA78BFA),
  ),
  _Rule(
    title: 'Larangan Banting Harga',
    desc:  'Dilarang merusak atau menurunkan harga yang telah ditentukan di bawah ketentuan TramsFlox.',
    icon:  Icons.trending_down_rounded,
    color: Color(0xFF34D399),
  ),
];

class _Rule {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  const _Rule({required this.title, required this.desc,
      required this.icon, required this.color});
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class InfoPage extends StatefulWidget {
  final String sessionKey;
  const InfoPage({super.key, required this.sessionKey});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> with TickerProviderStateMixin {
  Map<String, dynamic>? serverInfo;
  bool isLoading = true;

  bool   _apiOnline   = false;
  int    _pingMs      = 0;
  String _pingStatus  = 'Checking...';
  Timer? _pingTimer;

  // Animations
  late AnimationController _bgCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _pingDotCtrl;
  late AnimationController _sanctionCtrl;

  late Animation<double> _entrance;
  late Animation<double> _pingDot;
  late Animation<double> _sanctionGlow;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _entrance = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic);

    _pingDotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pingDot = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _pingDotCtrl, curve: Curves.easeInOut));

    _sanctionCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _sanctionGlow = Tween<double>(begin: 0.2, end: 0.6)
        .animate(CurvedAnimation(parent: _sanctionCtrl, curve: Curves.easeInOut));

    _fetchServerInfo();
    _startPingLoop();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    _pingDotCtrl.dispose();
    _sanctionCtrl.dispose();
    super.dispose();
  }

  // ─── API ────────────────────────────────────────────────────────────────────
  Future<void> _fetchServerInfo() async {
    try {
      final res = await http.get(Uri.parse(
          'http://denis.resjamin.awet.193.smasnug.web.id:4378/getServerInfo?key=${widget.sessionKey}'));
      if (res.statusCode == 200 && mounted) {
        setState(() { serverInfo = jsonDecode(res.body); isLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
    if (mounted) _entranceCtrl.forward();
  }

  void _startPingLoop() {
    _checkPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkPing());
  }

  Future<void> _checkPing() async {
    final start = DateTime.now();
    try {
      final res = await http.get(Uri.parse(
              'http://denis.resjamin.awet.193.smasnug.web.id:4378/ping?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 3));
      final ms = DateTime.now().difference(start).inMilliseconds;
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _apiOnline  = true;
          _pingMs     = ms;
          _pingStatus = '${ms}ms';
        });
      }
    } catch (_) {
      if (mounted) setState(() { _apiOnline = false; _pingMs = 0; _pingStatus = 'Offline'; });
    }
  }

  Color get _pingColor {
    if (!_apiOnline) return _C.red;
    if (_pingMs < 200) return _C.green;
    if (_pingMs < 500) return _C.amber;
    return const Color(0xFFF97316);
  }

  String get _pingLabel {
    if (!_apiOnline) return 'OFFLINE';
    if (_pingMs < 200) return 'EXCELLENT';
    if (_pingMs < 500) return 'GOOD';
    return 'SLOW';
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: _C.bg,
        body: Stack(children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          const Center(child: _DotsLoader()),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
          SafeArea(
            child: FadeTransition(
              opacity: _entrance,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                children: [
                  // API Status
                  _buildStatusCard(),
                  const SizedBox(height: 20),

                  // Rules header
                  _buildSectionHeader(
                    icon: Icons.gavel_rounded,
                    title: 'Peraturan Pengguna',
                    subtitle: '${_rules.length} aturan berlaku',
                  ),
                  const SizedBox(height: 14),

                  // Rules list
                  ..._rules.asMap().entries.map((e) =>
                    _StaggerItem(
                      index: e.key,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RuleCard(rule: e.value, number: e.key + 1),
                      ),
                    )),

                  const SizedBox(height: 20),

                  // Sanction card
                  _buildSanctionCard(),
                  const SizedBox(height: 24),

                  // Footer note
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _C.blue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.info_outline_rounded,
              color: _C.blueLight, size: 15),
        ),
        const SizedBox(width: 9),
        const Text('Peraturan & Info',
            style: TextStyle(color: _C.text, fontSize: 17,
                fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ]),
    );
  }

  // ─── Status Card ──────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: _pingColor.withOpacity(0.06),
              blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(children: [
        // Header
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _pingColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _pingColor.withOpacity(0.25)),
            ),
            child: Icon(Icons.router_rounded, color: _pingColor, size: 17),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('System Status', style: TextStyle(color: _C.text,
                fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Real-time server monitoring',
                style: TextStyle(color: _C.textSub, fontSize: 11)),
          ]),
          const Spacer(),
          // Ping badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _pingColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _pingColor.withOpacity(0.3)),
            ),
            child: Text(_pingLabel,
                style: TextStyle(color: _pingColor, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ),
        ]),

        const SizedBox(height: 16),
        Container(height: 1, color: _C.border),
        const SizedBox(height: 16),

        // Status row
        Row(children: [
          // Dot
          AnimatedBuilder(
            animation: _pingDot,
            builder: (_, __) => Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _apiOnline
                    ? _C.green.withOpacity(_pingDot.value)
                    : _C.red,
                boxShadow: _apiOnline
                    ? [BoxShadow(
                        color: _C.green.withOpacity(_pingDot.value * 0.5),
                        blurRadius: 8)]
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _apiOnline ? 'API Server Online' : 'API Server Offline',
            style: TextStyle(
              color: _apiOnline ? _C.text : _C.red,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_apiOnline) ...[
            const Icon(Icons.speed_rounded, color: _C.textSub, size: 14),
            const SizedBox(width: 5),
            Text(_pingStatus,
                style: TextStyle(color: _pingColor, fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ]),

        if (_apiOnline) ...[
          const SizedBox(height: 10),
          // Ping bar
          _PingBar(ms: _pingMs, color: _pingColor),
        ],
      ]),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(children: [
      Container(
        width: 4, height: 20,
        decoration: BoxDecoration(
          gradient: _C.btnGrad,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _C.text, fontSize: 15,
            fontWeight: FontWeight.w700)),
        Text(subtitle, style: const TextStyle(color: _C.textSub, fontSize: 11)),
      ]),
      const Spacer(),
      Icon(icon, color: _C.textSub, size: 18),
    ]);
  }

  // ─── Sanction Card ────────────────────────────────────────────────────────
  Widget _buildSanctionCard() {
    return AnimatedBuilder(
      animation: _sanctionCtrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _C.red.withOpacity(0.3 + _sanctionGlow.value * 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _C.red.withOpacity(_sanctionGlow.value * 0.15),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(children: [
            // Header stripe
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0xFFEF4444),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                // Icon
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.red.withOpacity(0.1),
                    border: Border.all(
                      color: _C.red.withOpacity(0.3 + _sanctionGlow.value * 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _C.red.withOpacity(_sanctionGlow.value * 0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(Icons.gavel_rounded,
                      color: _C.red.withOpacity(0.8 + _sanctionGlow.value * 0.2),
                      size: 28),
                ),
                const SizedBox(height: 14),
                const Text('SANKSI',
                    style: TextStyle(color: _C.red, fontSize: 20,
                        fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.border),
                  ),
                  child: Column(children: [
                    const Text(
                      'Jika pengguna terbukti melanggar salah satu peraturan di atas:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _C.textSub, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _C.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.red.withOpacity(0.25)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.block_rounded, color: _C.red, size: 16),
                          SizedBox(width: 8),
                          Text('Akun DIHAPUS secara permanen',
                              style: TextStyle(color: _C.text, fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tanpa pengembalian akun, saldo, atau kompensasi apa pun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _C.textSub, fontSize: 12,
                          height: 1.4),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_moon_rounded,
                color: _C.blueLight, size: 18),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Peraturan ini dibuat untuk menjaga keamanan, kenyamanan, dan '
                'kestabilan ekosistem FANVXP. Dengan menggunakan '
                'aplikasi ini, pengguna dianggap telah menyetujui seluruh '
                'peraturan di atas.',
                style: TextStyle(color: _C.textSub, fontSize: 12, height: 1.6,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          height: 3, width: 40,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        const Text('FANVXP',
            style: TextStyle(color: _C.textDim, fontSize: 11,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(width: 10),
        Container(
          height: 3, width: 40,
          decoration: BoxDecoration(
            gradient: _C.btnGrad,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ]),
    ]);
  }
}

// ─── Rule Card ────────────────────────────────────────────────────────────────
class _RuleCard extends StatefulWidget {
  final _Rule rule;
  final int number;
  const _RuleCard({required this.rule, required this.number});

  @override
  State<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<_RuleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.rule.color;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _expanded ? color.withOpacity(0.05) : _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded ? color.withOpacity(0.3) : _C.border,
            width: _expanded ? 1.5 : 1.0,
          ),
          boxShadow: _expanded
              ? [BoxShadow(color: color.withOpacity(0.08), blurRadius: 16,
                  offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                // Icon container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(_expanded ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                        color: color.withOpacity(_expanded ? 0.35 : 0.15)),
                  ),
                  child: Icon(widget.rule.icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                // Title + badge
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: Text('Rule ${widget.number}',
                            style: TextStyle(color: color, fontSize: 9,
                                fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(widget.rule.title,
                        style: const TextStyle(color: _C.text, fontSize: 13,
                            fontWeight: FontWeight.w700, height: 1.2)),
                  ],
                )),
                // Chevron
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _C.textDim, size: 20),
                ),
              ]),
            ),

            // Expanded desc
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _C.border),
                  ),
                  child: Text(widget.rule.desc,
                      style: const TextStyle(color: _C.textSub, fontSize: 13,
                          height: 1.6)),
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ping Bar ─────────────────────────────────────────────────────────────────
class _PingBar extends StatelessWidget {
  final int ms;
  final Color color;
  const _PingBar({required this.ms, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (ms / 1000).clamp(0.0, 1.0);
    return Row(children: [
      const Text('Latency', style: TextStyle(color: _C.textDim, fontSize: 10)),
      const SizedBox(width: 8),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(children: [
            Container(height: 4, color: _C.border),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 4,
              width: (MediaQuery.of(context).size.width - 80) * pct,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
                ],
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      Text('${ms}ms', style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w700)),
    ]);
  }
}

// ─── Stagger Item ─────────────────────────────────────────────────────────────
class _StaggerItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggerItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 80).clamp(0, 500)),
      curve: Curves.easeOutCubic,
      builder: (_, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: ch),
      ),
      child: child,
    );
  }
}

// ─── Dots Loader ──────────────────────────────────────────────────────────────
class _DotsLoader extends StatefulWidget {
  const _DotsLoader();

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
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
                width: 9, height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.blueMid.withOpacity(0.4 + s * 0.6),
                ),
              ),
            ),
          );
        }),
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
    final grid = Paint()
      ..color = _C.border.withOpacity(0.25)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        _C.blue.withOpacity(0.08 + math.sin(t * math.pi * 2) * 0.02),
        Colors.transparent,
      ], radius: 0.85).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.18),
          radius: size.width * 0.65));
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.18), size.width * 0.65, glow);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}
