import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Import halaman kamu ──────────────────────────────
import 'admin_page.dart';
import 'owner_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'change_password_page.dart';
import 'tools_gateway.dart';
import 'login_page.dart';
import 'bug_sender.dart';
import 'contact_page.dart';
import 'profile_page.dart';
import 'riwayat_page.dart';
import 'info_page.dart';
import 'newuser.dart';
import 'device_dashboard.dart';
import 'chat_room_page.dart';        // ← ⚠️ TAMBAH INI (WAJIB)
import 'al_quran_new.dart';           // ← Kalau al quran page ada
// ─── Palette: PUTIH CERAH ──────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF8FAFC); // Putih hampir murni
  static const surface   = Color(0xFFFFFFFF); // Putih murni
  static const card      = Color(0xFFFFFFFF); // Card putih
  static const cardAlt   = Color(0xFFE2E8F0); // Abu-abu terang
  static const border    = Color(0xFF3B82F6); // Biru terang
  static const borderLit = Color(0xFF1D4ED8); // Biru gelap
  static const teal      = Color(0xFF0891B2); // Cyan gelap
  static const green     = Color(0xFF10B981); // Hijau
  static const blue      = Color(0xFF2563EB); // Biru
  static const deepBlue  = Color(0xFF1E40AF); // Biru gelap
  static const amber     = Color(0xFFF59E0B); // Amber
  static const red       = Color(0xFFDC2626); // Merah
  static const pink      = Color(0xFFEC4899); // Pink
  static const indigo    = Color(0xFF4F46E5); // Indigo
  static const text      = Color(0xFF0F172A); // Hampir hitam
  static const textSub   = Color(0xFF475569); // Abu gelap
  static const textDim   = Color(0xFF94A3B8); // Abu terang
  static const black     = Color(0xFF0A0A0A);
  static const whiteNeon = Color(0xFFF1F5F9);
}

// ─── Role helpers ──────────────────────────────────────────────────────────────
Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':    return const Color(0xFFDC2626);
    case 'admin':    return const Color(0xFFEF4444);
    case 'reseller': return const Color(0xFF0891B2);
    case 'partner':  return const Color(0xFF10B981);
    case 'vip':      return const Color(0xFF6366F1);
    default:         return _C.pink;
  }
}

IconData _roleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'owner':    return Icons.workspace_premium_rounded;
    case 'admin':    return Icons.admin_panel_settings_rounded;
    case 'reseller': return Icons.storefront_rounded;
    case 'partner':  return Icons.handshake_rounded;
    case 'vip':      return Icons.star_rounded;
    default:         return Icons.shield_rounded;
  }
}

String _roleShort(String role) {
  if (role.isEmpty) return '??';
  return role.substring(0, math.min(2, role.length)).toUpperCase();
}

// ─── Feature Card Model ────────────────────────────────────────────────────────
class _FC {
  final IconData icon;
  final String title, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _FC({required this.icon, required this.title, required this.subtitle,
      required this.gradient, required this.onTap});
}

// ─── Menu Slide Model ──────────────────────────────────────────────────────────
class _MenuSlide {
  final String title, subtitle, description, badge;
  final IconData icon;
  final List<String> features;
  final List<Color> gradient;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;
  const _MenuSlide({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badge,
    required this.icon,
    required this.features,
    required this.gradient,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });
}

// ─── Thank You User Model ──────────────────────────────────────────────────────
class _ThankYouUser {
  final String name;
  final String role;
  final String telegram;
  final String whatsapp;
  final String? photoUrl;

  const _ThankYouUser({
    required this.name,
    required this.role,
    required this.telegram,
    required this.whatsapp,
    this.photoUrl,
  });
}

// ─── Dashboard Page ────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  final String username, password, role, expiredDate, sessionKey;
  final List<Map<String, dynamic>> listBug, listDoos;
  final List<dynamic> news;
  const DashboardPage({
    super.key, required this.username, required this.password,
    required this.role, required this.expiredDate, required this.listBug,
    required this.listDoos, required this.sessionKey, required this.news,
  });
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {

  late String sessionKey, username, password, role, expiredDate;
  late List<Map<String, dynamic>> listBug, listDoos;
  late List<dynamic> newsList;

  late WebSocketChannel channel;
  String androidId = 'unknown';
  File? _profileImage;
  VideoPlayerController? _menuVideoCtrl;
  VideoPlayerController? _topBannerCtrl;

  int _navIndex = 0;
  Widget _body  = const SizedBox();
  int onlineUsers = 0, activeConns = 0;

  late AnimationController _bgCtrl, _pageCtrl, _pulseCtrl;
  late Animation<double> _pageFade, _pulse;
  late Animation<Offset> _pageSlide;

  final PageController _bannerCtrl = PageController();
  int _bannerPage = 0;

  final PageController _menuCarouselCtrl = PageController(viewportFraction: 0.92);
  int _menuCarouselPage = 0;

  bool get _isReseller => role.toLowerCase() == 'reseller';

  @override
  void initState() {
    super.initState();
    sessionKey  = widget.sessionKey; username = widget.username;
    password    = widget.password;   role     = widget.role;
    expiredDate = widget.expiredDate;
    listBug     = widget.listBug; listDoos = widget.listDoos;
    newsList    = widget.news;

    _bgCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _pageCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);

    _pageFade  = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pulse = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _body = _homeDashboard();
    _pageCtrl.forward();
    _initAndroidId();
    _loadProfileImage();
    _initMenuVideo();
    _initTopBannerVideo();
  }

  @override
  void dispose() {
    try { channel.sink.close(status.goingAway); } catch (_) {}
    _bgCtrl.dispose(); _pageCtrl.dispose(); _pulseCtrl.dispose();
    _menuVideoCtrl?.dispose();
    _topBannerCtrl?.dispose();
    _bannerCtrl.dispose();
    _menuCarouselCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path  = prefs.getString('profile_image_$username');
    if (path != null && path.isNotEmpty && mounted)
      setState(() => _profileImage = File(path));
  }

  void _initMenuVideo() {
    try {
      _menuVideoCtrl = VideoPlayerController.asset('assets/videos/banner.mp4')
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _menuVideoCtrl?.setLooping(true);
          _menuVideoCtrl?.setVolume(0);
          _menuVideoCtrl?.play();
        });
    } catch (e) {
      debugPrint('Menu video error: $e');
    }
  }

  void _initTopBannerVideo() {
    try {
      _topBannerCtrl = VideoPlayerController.asset('assets/videos/banner.mp4')
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _topBannerCtrl?.setLooping(true);
          _topBannerCtrl?.setVolume(0);
          _topBannerCtrl?.play();
        });
    } catch (e) {
      debugPrint('Top banner video error: $e');
    }
  }

  Future<void> _initAndroidId() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      androidId = info.id;
      _connectWS();
    } catch (e) {
      debugPrint('Android info error: $e');
    }
  }

  void _connectWS() {
    try {
      channel = WebSocketChannel.connect(
          Uri.parse('https://panel-legal.jhonaley.net:3519'));
      channel.sink.add(jsonEncode({'type': 'validate', 'key': sessionKey, 'androidId': androidId}));
      channel.sink.add(jsonEncode({'type': 'stats'}));
      channel.stream.listen(
        (event) {
          try {
            final data = jsonDecode(event);
            if (data['type'] == 'myInfo' && data['valid'] == false) {
              _handleInvalidSession(data['reason'] == 'androidIdMismatch'
                  ? 'Akun ini login di perangkat lain.'
                  : 'Sesi tidak valid. Silakan login ulang.');
            }
            if (data['type'] == 'stats' && mounted) {
              setState(() {
                onlineUsers = data['onlineUsers'] ?? 0;
                activeConns = data['activeConnections'] ?? 0;
              });
            }
          } catch (_) {}
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('WS connect error: $e');
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Open URL error: $e');
    }
  }

  void _handleInvalidSession(String msg) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    _showSystemDialog(title: 'Sesi Berakhir', message: msg,
        icon: Icons.lock_outline_rounded, color: _C.red,
        onOk: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false));
  }

  Future<void> _doLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  void _navigate(Widget page) {
    setState(() => _body = page);
    _pageCtrl.forward(from: 0);
  }

  void _openNewUserPage() {
    Navigator.push(context, _slideRoute(NewUserPage(sessionKey: sessionKey)));
  }

  void _onNavTap(int index) {
    setState(() => _navIndex = index);
    switch (index) {
      case 0: _navigate(_homeDashboard()); break;
      case 1: _navigate(InfoPage(sessionKey: sessionKey)); break;
      case 2: _navigate(HomePage(username: username, password: password,
          listBug: listBug, role: role, expiredDate: expiredDate,
          sessionKey: sessionKey)); break;
      case 3: _navigate(ToolsPage(sessionKey: sessionKey,
          userRole: role, listDoos: listDoos)); break;
      case 4: Navigator.push(context, _slideRoute(ProfilePage(
          username: username, password: password, role: role,
          expiredDate: expiredDate, sessionKey: sessionKey))); break;
    }
  }

  void _onDrawerNav(int index) {
    Navigator.pop(context);
    switch (index) {
      case 1: _navigate(SellerPage(keyToken: sessionKey)); break;
      case 2: _navigate(AdminPage(sessionKey: sessionKey)); break;
      case 3: _navigate(OwnerPage(sessionKey: sessionKey, username: username)); break;
    }
  }

  void _showSystemDialog({required String title, required String message,
      required IconData icon, required Color color, VoidCallback? onOk}) {
    showGeneralDialog(
      context: context, barrierDismissible: false, barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child)),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(color: _C.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 40)]),
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 60, height: 60,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: color.withOpacity(0.1),
                    border: Border.all(color: color.withOpacity(0.3))),
                child: Icon(icon, color: color, size: 28)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            _MxBtn(label: 'OK', fullWidth: true, color: color, onTap: () {
              Navigator.pop(ctx); onOk?.call();
            }),
          ]),
        ),
      ),
    );
  }

// ✅ HANYA 1 method _getMenuSlides() di seluruh file
List<_MenuSlide> _getMenuSlides() => [
  // Slide 1: BUG FANXVP
  _MenuSlide(
    title: 'BUG FANXVP',
    subtitle: 'Hanya Bug',
    description: 'Gunakan langsung dengan cepat',
    badge: 'RECOMMENDED',
    icon: Icons.bug_report_rounded,
    features: const ['Mudah digunakan', 'Function terbaru', 'All work gacor'],
    gradient: const [Color(0xFF1E293B), Color(0xFF334155)],
    accentColor: const Color(0xFF60A5FA),
    textColor: const Color(0xFFFFFFFF),
    onTap: () => _onNavTap(2),
  ),

  // Slide 2: MANAGE SENDER
  _MenuSlide(
    title: 'MANAGE SENDER',
    subtitle: 'Pairing & Configuration',
    description: 'Kelola sender WhatsApp kamu',
    badge: 'POPULAR',
    icon: FontAwesomeIcons.whatsapp,
    features: const ['Auto pairing', 'Multi device', 'Stabil 24/7'],
    gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
    accentColor: const Color(0xFFDBEAFE),
    textColor: const Color(0xFFFFFFFF),
    onTap: () => Navigator.push(context, _slideRoute(BugSenderPage(
        sessionKey: sessionKey, username: username, role: role))),
  ),

  // Slide 3: TOOLS
  _MenuSlide(
    title: 'TOOLS',
    subtitle: 'Gateway Utility',
    description: 'Kumpulan tools serbaguna',
    badge: 'NEW',
    icon: Icons.build_rounded,
    features: const ['Bug tools', 'Gateway', 'Spam tools'],
    gradient: const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
    accentColor: const Color(0xFF0284C7),
    textColor: const Color(0xFF0F172A),
    onTap: () => _onNavTap(3),
  ),

  // Slide 4: AL QURAN
  _MenuSlide(
    title: 'AL QURAN',
    subtitle: 'Alim Dulu',
    description: 'Ngaji Yuk',
    badge: 'HALAL',
    icon: Icons.menu_book_rounded,
    features: const ['Al Quran', '30 Juz', 'Tafsir'],
    gradient: const [Color(0xFF047857), Color(0xFF10B981)],
    accentColor: const Color(0xFFD1FAE5),
    textColor: const Color(0xFFFFFFFF),
    onTap: () => Navigator.push(context, _slideRoute(AlQuranPage())),  // ← TANPA const
  ),

  // Slide 5: RAT
  _MenuSlide(
    title: 'RAT',
    subtitle: 'Device Dashboard',
    description: 'Remote Access Trojan',
    badge: 'PRO',
    icon: Icons.security_rounded,
    features: const ['Remote access', 'Live lokasi', 'File manager'],
    gradient: const [Color(0xFF1E40AF), Color(0xFF1E3A8A)],
    accentColor: const Color(0xFF60A5FA),
    textColor: const Color(0xFFFFFFFF),
    onTap: () => Navigator.push(context, _slideRoute(DeviceDashboard(
        sessionKey: sessionKey, username: username, role: role))),
  ),

  // Slide 6: CHAT ROOM
  _MenuSlide(
    title: 'CHAT ROOM',
    subtitle: 'Live Community Chat',
    description: 'Chat dengan member lain',
    badge: 'LIVE',
    icon: Icons.forum_rounded,
    features: const ['Real-time chat', 'Multi user', 'Aman & privat'],
    gradient: const [Color(0xFF000000), Color(0xFF1F1F1F)],
    accentColor: const Color(0xFF00E5FF),
    textColor: const Color(0xFFFFFFFF),
    onTap: () => Navigator.push(context, _slideRoute(ChatRoomPage(
      sessionKey: sessionKey,
      username: username,
      roomId: 'general',
    ))),
  ),
];   // ← Pastikan kurung tutup list ini ADA
  // ─── THANKS TO DATA ──────────────────────────────────────────────────────
  List<_ThankYouUser> _getThanksToList() => const [
    _ThankYouUser(
      name: 'FAN ',
      role: 'DEV1',
      telegram: '@Crashbug1',
      whatsapp: '60194808502',
      photoUrl: null,
    ),
    _ThankYouUser(
      name: 'AQIELL',
      role: ' DEV2',
      telegram: '@aqieproj',
      whatsapp: '6283175890280',
      photoUrl: null,
    ),
  ];

  // ── Feature Cards ──────────────────────────────────────────────────────────
  List<_FC> _buildFeatureCards() {
    final List<_FC> cards = [];

    if (_isReseller) {
      cards.add(_FC(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Reseller Menu',
        subtitle: 'Tambah user baru',
        gradient: [const Color(0xFF10B981), const Color(0xFF0891B2)],
        onTap: _openNewUserPage,
      ));
    }

    cards.addAll([
      _FC(icon: FontAwesomeIcons.whatsapp, title: 'Manage Sender',
          subtitle: 'Pairing & Configuration',
          gradient: [const Color(0xFFDC2626), const Color(0xFFEF4444)],
          onTap: () => Navigator.push(context, _slideRoute(BugSenderPage(
              sessionKey: sessionKey, username: username, role: role)))),
      _FC(icon: FontAwesomeIcons.telegram, title: 'Info Channel',
          subtitle: 'Gabung update channel',
          gradient: [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
          onTap: () => _openUrl('https://t.me/fanvxp')),
      _FC(icon: Icons.headset_mic_outlined, title: 'Kontak Kami',
          subtitle: 'Hubungi tim support',
          gradient: [const Color(0xFF10B981), const Color(0xFF34D399)],
          onTap: () => Navigator.push(context, _slideRoute(const ContactPage()))),
      _FC(icon: Icons.history_rounded, title: 'Riwayat Akun',
          subtitle: 'Log aktivitas akun kamu',
          gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
          onTap: () => Navigator.push(context,
              _slideRoute(RiwayatPage(sessionKey: sessionKey, role: role)))),
      _FC(icon: Icons.lock_outline_rounded, title: 'Ganti Password',
          subtitle: 'Perbarui keamanan akun',
          gradient: [const Color(0xFFDC2626), const Color(0xFFF87171)],
          onTap: () => Navigator.push(context, _slideRoute(
              ChangePasswordPage(username: username, sessionKey: sessionKey)))),
    ]);

    return cards;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOME DASHBOARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _homeDashboard() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 10),
        _buildTopBanner(),
        const SizedBox(height: 4),
        _userCard(),
        const SizedBox(height: 16),
        _buildMenuCarouselHeader(),
        const SizedBox(height: 12),
        _buildMenuCarousel(),
        const SizedBox(height: 8),
        _buildMenuCarouselDots(),
        if (_isReseller) ...[
          const SizedBox(height: 20),
          _buildResellerBanner(),
        ],
        const SizedBox(height: 20),
        _buildQuickActionsHeader(),
        const SizedBox(height: 12),
        _buildFeatureCardsSection(),
        const SizedBox(height: 24),
        _buildLatestUpdatesSection(),
        const SizedBox(height: 24),
        _buildHadithSection(),
        const SizedBox(height: 80),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP BANNER — Video MP4
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTopBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _C.blue.withOpacity(0.35),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: _C.deepBlue.withOpacity(0.2),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(
            color: _C.blue.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_topBannerCtrl != null &&
                  _topBannerCtrl!.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _topBannerCtrl!.value.size.width,
                    height: _topBannerCtrl!.value.size.height,
                    child: VideoPlayer(_topBannerCtrl!),
                  ),
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _C.blue,
                      ),
                    ),
                  ),
                ),
              // Dark overlay biar teks tetap kebaca
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.35),
                        Colors.black.withOpacity(0.75),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -30, right: -30,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _C.teal.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -40, left: -40,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _C.deepBlue.withOpacity(0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18, bottom: 16, right: 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _C.teal.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _C.teal.withOpacity(0.7),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              '● LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'FANVXP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              shadows: [
                                Shadow(
                                  color: Color(0xFF2563EB),
                                  blurRadius: 15,
                                ),
                                Shadow(
                                  color: Color(0xFF0891B2),
                                  blurRadius: 25,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'BUG WHATSAPP CRASHER',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _C.teal.withOpacity(0.4),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0, left: 20, right: 20,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _C.teal,
                        _C.blue,
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: _C.teal.withOpacity(0.8),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CAROUSEL HEADER ────────────────────────────────────────────────────
  Widget _buildMenuCarouselHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _C.teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.teal.withOpacity(0.3)),
            ),
            child: const Icon(Icons.grid_view_rounded, color: _C.teal, size: 16),
          ),
          const SizedBox(width: 10),
          const Text(
            'FANVXP ENGINE',
            style: TextStyle(
              color: _C.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Text(
            '${_menuCarouselPage + 1}/4',
            style: const TextStyle(
              color: _C.textSub,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── CAROUSEL ────────────────────────────────────────────────────────────
  Widget _buildMenuCarousel() {
    final slides = _getMenuSlides();
    return SizedBox(
      height: 380,
      child: PageView.builder(
        controller: _menuCarouselCtrl,
        onPageChanged: (i) => setState(() => _menuCarouselPage = i),
        itemCount: slides.length,
        padEnds: true,
        itemBuilder: (_, i) => _buildMenuSlide(slides[i]),
      ),
    );
  }

  // ── SINGLE SLIDE ────────────────────────────────────────────────────────
  Widget _buildMenuSlide(_MenuSlide slide) {
    return AnimatedBuilder(
      animation: _menuCarouselCtrl,
      builder: (context, child) {
        double pageOffset = 0;
        try {
          pageOffset = _menuCarouselCtrl.page ?? _menuCarouselPage.toDouble();
        } catch (_) {
          pageOffset = _menuCarouselPage.toDouble();
        }
        final diff = (pageOffset - _getMenuSlides().indexOf(slide)).abs();
        final scale = (1 - (diff * 0.06)).clamp(0.9, 1.0);
        final opacity = (1 - (diff * 0.15)).clamp(0.7, 1.0);
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: slide.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: slide.accentColor.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: slide.gradient[0].withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: -30, bottom: -30,
                child: Icon(slide.icon, size: 200,
                    color: Colors.white.withOpacity(0.08)),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        slide.gradient.last.withOpacity(0.4),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: slide.textColor == _C.text
                                ? Colors.white.withOpacity(0.5)
                                : Colors.white.withOpacity(0.2),
                            border: Border.all(
                              color: slide.textColor == _C.text
                                  ? slide.accentColor.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.3),
                              width: 1.5),
                          ),
                          child: Icon(slide.icon,
                              color: slide.textColor == _C.text
                                  ? slide.accentColor
                                  : Colors.white,
                              size: 24),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: slide.textColor == _C.text
                                ? Colors.white.withOpacity(0.6)
                                : Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: slide.accentColor.withOpacity(0.6)),
                          ),
                          child: Text(
                            slide.badge,
                            style: TextStyle(
                              color: slide.textColor == _C.text
                                  ? slide.accentColor
                                  : Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      slide.title,
                      style: TextStyle(
                        color: slide.textColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slide.subtitle,
                      style: TextStyle(
                        color: slide.textColor.withOpacity(0.75),
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                        height: 1,
                        color: slide.textColor == _C.text
                            ? Colors.black.withOpacity(0.1)
                            : Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Text(
                      slide.description,
                      style: TextStyle(
                        color: slide.textColor.withOpacity(0.9),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: slide.features.map((f) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: slide.textColor == _C.text
                                ? Colors.white.withOpacity(0.6)
                                : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: slide.textColor == _C.text
                                    ? Colors.black.withOpacity(0.1)
                                    : Colors.white.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: slide.textColor.withOpacity(0.85), size: 10),
                              const SizedBox(width: 4),
                              Text(
                                f,
                                style: TextStyle(
                                  color: slide.textColor.withOpacity(0.85),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: slide.onTap,
                      child: Container(
                        height: 46,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: slide.textColor == _C.text
                              ? Colors.white.withOpacity(0.75)
                              : Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: slide.textColor.withOpacity(0.4), width: 1.2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'START MODULE',
                              style: TextStyle(
                                color: slide.textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.arrow_forward_ios_rounded,
                                color: slide.textColor, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CAROUSEL DOTS ───────────────────────────────────────────────────────
  Widget _buildMenuCarouselDots() {
    final slides = _getMenuSlides();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(slides.length, (i) {
        final active = i == _menuCarouselPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 6, height: 6,
          decoration: BoxDecoration(
            color: active
                ? slides[i].accentColor
                : _C.textDim.withOpacity(0.4),
            borderRadius: BorderRadius.circular(3),
            boxShadow: active
                ? [BoxShadow(
                    color: slides[i].accentColor.withOpacity(0.5),
                    blurRadius: 8)]
                : [],
          ),
        );
      }),
    );
  }

  // ── BANNER RESELLER ───────────────────────────────────────────────────────
  Widget _buildResellerBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GestureDetector(
        onTap: _openNewUserPage,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _C.blue.withOpacity(0.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.25),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESELLER MENU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tekan untuk buat user baru',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── LATEST UPDATES ──────────────────────────────────────────────────────
  Widget _buildLatestUpdatesSection() {
    final List<Map<String, String>> dummyNews = [
      {
        'title': 'RAT | BETA | DAN DDOS',
        'subtitle': 'Penambahan Fitur RAT dan DDOS Game',
        'date': '3/9/2026',
        'image': 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?auto=format&fit=crop&q=80&w=600',
        'url': 'https://example.com/news/1'
      },
      {
        'title': 'FANVXP BEDA DARI YANG LAMA',
        'subtitle': 'KAMPILAN MECE ABIS',
        'date': '3/9/2026',
        'image': 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?auto=format&fit=crop&q=80&w=600',
        'url': 'https://example.com/news/1'
      },
      {
        'title': 'UPDATE APK FANVXP',
        'subtitle': 'Perbaikan Bug dan Peningkatan Performa',
        'date': '1/9/2026',
        'image': 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&q=80&w=600',
        'url': 'https://example.com/news/2'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _C.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_open, color: _C.amber, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'LATEST UPDATES',
                style: TextStyle(
                  color: _C.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.amber.withOpacity(0.5)),
                ),
                child: const Text(
                  '3 Updates',
                  style: TextStyle(color: _C.amber, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 14, right: 8),
            itemCount: dummyNews.length,
            itemBuilder: (context, index) {
              final news = dummyNews[index];
              return GestureDetector(
                onTap: () => _openUrl(news['url']!),
                child: Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: _C.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _C.border.withOpacity(0.3), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: _C.text.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: Image.network(
                          news['image']!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: _C.cardAlt,
                            child: const Center(child: Icon(Icons.image, color: _C.textSub)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _C.teal.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _C.teal.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_upload_outlined, color: _C.teal, size: 12),
                                  const SizedBox(width: 4),
                                  const Text('UPDATE', style: TextStyle(color: _C.teal, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              news['title']!,
                              style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              news['subtitle']!,
                              style: const TextStyle(color: _C.textSub, fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, color: _C.textDim, size: 12),
                                    const SizedBox(width: 4),
                                    Text(news['date']!, style: const TextStyle(color: _C.textDim, fontSize: 10)),
                                  ],
                                ),
                                const Row(
                                  children: [
                                    Text('SELENGKAPNYA', style: TextStyle(color: _C.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward, color: _C.blue, size: 12),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── HADITH ──────────────────────────────────────────────────────────────
  Widget _buildHadithSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _C.teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.menu_book, color: _C.teal, size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HADITH OF THE DAY',
                    style: TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                  Text(
                    'Refleksi singkat untuk hari ini',
                    style: TextStyle(color: _C.textSub, fontSize: 10),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.fullscreen, color: _C.textSub, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border.withOpacity(0.3), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: _C.text.withOpacity(0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _C.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.border.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _C.text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sesungguhnya setiap amalan tergantung pada niatnya. Dan sesungguhnya setiap orang akan mendapatkan apa yang ia niatkan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _C.textSub,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: _C.teal, size: 14),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Shahih Bukhari - Kitab Niat',
                        style: TextStyle(color: _C.textSub, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _openUrl('https://equran.id/apidev/v2'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _C.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _C.teal.withOpacity(0.5)),
                        ),
                        child: const Row(
                          children: [
                            Text('BACA', style: TextStyle(color: _C.teal, fontSize: 11, fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, color: _C.teal, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── USER CARD ───────────────────────────────────────────────────────────
  Widget _userCard() {
    final rColor = _roleColor(role);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border.withOpacity(0.3), width: 1.2),
          boxShadow: [
            BoxShadow(color: _C.text.withOpacity(0.08),
                blurRadius: 22, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: rColor,
                  boxShadow: [
                    BoxShadow(color: rColor.withOpacity(0.4), blurRadius: 16,
                        offset: const Offset(0, 4)),
                    BoxShadow(color: rColor.withOpacity(0.15), blurRadius: 28),
                  ],
                ),
                child: _profileImage != null
                    ? ClipOval(child: Image.file(_profileImage!, fit: BoxFit.cover))
                    : Icon(_roleIcon(role), color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome Back,',
                    style: TextStyle(color: _C.textSub, fontSize: 12)),
                const SizedBox(height: 1),
                Text(username.toUpperCase(),
                    style: const TextStyle(color: _C.text, fontSize: 20,
                        fontWeight: FontWeight.w900, height: 1.15,
                        letterSpacing: 0.5)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.cardAlt,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _C.border.withOpacity(0.3)),
                  ),
                  child: Text(_roleShort(role),
                      style: const TextStyle(color: _C.textSub, fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ])),
              GestureDetector(
                onTap: () => Navigator.push(context, _slideRoute(ProfilePage(
                    username: username, password: password, role: role,
                    expiredDate: expiredDate, sessionKey: sessionKey))),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.teal.withOpacity(0.12),
                      border: Border.all(
                          color: _C.teal.withOpacity(_pulse.value * 0.8), width: 2),
                      boxShadow: [
                        BoxShadow(color: _C.teal.withOpacity(_pulse.value * 0.3),
                            blurRadius: 14),
                      ],
                    ),
                    child: const Icon(Icons.timer_outlined, color: _C.teal, size: 19),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(color: _C.border.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
                color: _C.bg.withOpacity(0.7),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 4, height: 4,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _C.teal.withOpacity(0.6))),
                const SizedBox(width: 8),
                Text('FANVXP DASHBOARD',
                    style: TextStyle(color: _C.teal.withOpacity(0.9),
                        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.2)),
                const SizedBox(width: 8),
                Container(width: 4, height: 4,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _C.teal.withOpacity(0.6))),
              ]),
            ),
          ),
          Container(margin: const EdgeInsets.only(top: 14), height: 1, color: _C.cardAlt),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 18, 10, 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _HexStat(icon: Icons.people_alt_rounded,
                  value: '$onlineUsers', label: 'Online Users',
                  color: _C.green, showLive: true),
              _HexStat(icon: Icons.link_rounded,
                  value: '$activeConns', label: 'Active Connections',
                  color: _C.blue),
              _HexStat(icon: Icons.calendar_month_rounded,
                  value: expiredDate, label: 'Expiration',
                  color: _C.amber, smallValue: true),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── QUICK ACTIONS HEADER ────────────────────────────────────────────────
  Widget _buildQuickActionsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border.withOpacity(0.3), width: 1.2),
          boxShadow: [BoxShadow(color: _C.text.withOpacity(0.06),
              blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.amber.withOpacity(0.1),
              border: Border.all(color: _C.amber.withOpacity(0.35)),
              boxShadow: [BoxShadow(
                  color: _C.amber.withOpacity(0.2), blurRadius: 10)],
            ),
            child: const Icon(Icons.bolt_rounded,
                color: _C.amber, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('QUICK\nACTIONS',
                style: TextStyle(color: _C.text, fontSize: 16,
                    fontWeight: FontWeight.w900, height: 1.1, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            const Text('Beberapa Menu Tambahan',
                style: TextStyle(color: _C.textSub, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: _C.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.teal.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: _C.teal,
                  boxShadow: [BoxShadow(
                      color: _C.teal.withOpacity(0.6), blurRadius: 5)],
                ),
              ),
              const SizedBox(width: 5),
              const Text('FANVXP',
                  style: TextStyle(color: _C.teal, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── FEATURE CARDS SECTION ───────────────────────────────────────────────
  Widget _buildFeatureCardsSection() {
    final fcs = _buildFeatureCards();
    return SizedBox(
      height: 192,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 14, right: 8),
        itemCount: fcs.length,
        itemBuilder: (_, i) => _FeatureCard(fc: fcs[i]),
      ),
    );
  }

  // ── SCAFFOLD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: Stack(children: [
        Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
        SafeArea(
          child: FadeTransition(opacity: _pageFade,
              child: SlideTransition(position: _pageSlide, child: _body)),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── APPBAR ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.surface,
      elevation: 2,
      shadowColor: _C.text.withOpacity(0.1),
      centerTitle: true, titleSpacing: 0,
      leading: Builder(builder: (ctx) =>
          _MenuBtn(onTap: () => Scaffold.of(ctx).openDrawer())),
      title: _buildAppBarLogo(),
      actions: [
        _AppBarIconBtn(icon: Icons.headphones_outlined, onTap: () {}),
        _AppBarIconBtn(icon: Icons.notifications_outlined, onTap: () {}),
        _AppBarIconBtn(icon: Icons.logout_rounded, onTap: _doLogout),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                _C.teal.withOpacity(0.5),
                _C.blue.withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarLogo() {
    return Stack(alignment: Alignment.center, children: [
      Text('FANVXP',
        style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = _C.blue,
        ),
      ),
      const Text('FANVXP',
        style: TextStyle(
          color: _C.text,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    ]);
  }

  // ── BOTTOM NAV ──────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.cardAlt, width: 1)),
        boxShadow: [BoxShadow(color: _C.text.withOpacity(0.12),
            blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            SizedBox(
              height: 64,
              child: Row(children: [
                _buildNavItem5(0, Icons.home_rounded, 'Home'),
                _buildNavItem5(1, Icons.chat_bubble_outline_rounded, 'Berita'),
                const Expanded(child: SizedBox()),
                _buildNavItem5(3, Icons.build_outlined, 'Tools'),
                _buildNavItem5(4, Icons.person_outline_rounded, 'Profile'),
              ]),
            ),
            Positioned(
              top: -22,
              child: GestureDetector(
                onTap: () => _onNavTap(2),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _C.red,
                      border: Border.all(color: _C.surface, width: 3),
                      boxShadow: [
                        BoxShadow(color: _C.red.withOpacity(0.4),
                            blurRadius: 16, offset: const Offset(0, 4)),
                        BoxShadow(color: _C.red.withOpacity(0.2),
                            blurRadius: 28),
                      ],
                    ),
                    child: const Icon(Icons.group_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 3),
                  Text('BUG WHATSAPP',
                      style: TextStyle(
                        color: _navIndex == 2 ? _C.text : _C.textSub,
                        fontSize: 9, fontWeight: FontWeight.w600,
                      )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem5(int index, IconData icon, String label) {
    final active = _navIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2, width: active ? 22 : 0,
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: _C.indigo,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Icon(icon, size: 22,
              color: active ? _C.indigo : _C.textSub),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
              color: active ? _C.indigo : _C.textSub,
              fontSize: 9,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DRAWER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.78,
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          border: Border(right: BorderSide(color: _C.cardAlt))),
        child: Column(children: [
          _DrawerHeader(
            username: username,
            role: role,
            expiredDate: expiredDate,
            profileImage: _profileImage,
            videoCtrl: _menuVideoCtrl,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              physics: const BouncingScrollPhysics(),
              children: [
                if (role == 'reseller') ...[
                  _DrawerItem(
                    icon: Icons.storefront_rounded,
                    label: 'Seller Page',
                    onTap: () => _onDrawerNav(1),
                  ),
                  _DrawerItem(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Buat User Baru',
                    onTap: () {
                      Navigator.pop(context);
                      _openNewUserPage();
                    },
                  ),
                ],
                if (role == 'admin')
                  _DrawerItem(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Admin Page',
                    onTap: () => _onDrawerNav(2),
                  ),
                if (role == 'owner')
                  _DrawerItem(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Owner Page',
                    onTap: () => _onDrawerNav(3),
                  ),

                const SizedBox(height: 16),
                _buildThanksToSection(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Keluar',
              isDestructive: true,
              onTap: () async {
                Navigator.pop(context);
                await _doLogout();
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // THANKS TO SECTION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildThanksToSection() {
    final users = _getThanksToList();

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _C.text.withOpacity(0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _C.teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _C.teal.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: _C.teal.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: _C.teal, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'THANKS TO',
                        style: TextStyle(
                          color: _C.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        '${users.length} contributor aktif',
                        style: const TextStyle(
                          color: _C.textSub,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _C.teal.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'TEAM',
                    style: TextStyle(
                      color: _C.teal,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: _C.cardAlt),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                  vertical: 8, horizontal: 8),
              itemCount: users.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: _C.cardAlt,
                indent: 56,
              ),
              itemBuilder: (context, i) =>
                  _buildThanksToItem(users[i]),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: 8, horizontal: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: _C.cardAlt),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: _C.teal, size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Terima kasih atas dukungannya',
                    style: TextStyle(
                      color: _C.textSub.withOpacity(0.9),
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThanksToItem(_ThankYouUser user) {
    final rColor = _roleColor(user.role);

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 10, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.cardAlt,
                  border: Border.all(
                    color: rColor.withOpacity(0.6),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rColor.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: user.photoUrl != null &&
                        user.photoUrl!.isNotEmpty
                    ? ClipOval(
                        child: user.photoUrl!.startsWith('http')
                            ? Image.network(
                                user.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  _roleIcon(user.role),
                                  color: rColor,
                                  size: 20,
                                ),
                              )
                            : Image.asset(
                                user.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  _roleIcon(user.role),
                                  color: rColor,
                                  size: 20,
                                ),
                              ),
                      )
                    : Icon(
                        _roleIcon(user.role),
                        color: rColor,
                        size: 20,
                      ),
              ),
              Positioned(
                right: 1, bottom: 1,
                child: Container(
                  width: 11, height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.green,
                    border: Border.all(color: _C.card, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _C.green.withOpacity(0.5),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        style: const TextStyle(
                          color: _C.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: rColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: rColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: TextStyle(
                          color: rColor,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _openUrl(
                            'https://t.me/${user.telegram.replaceAll('@', '')}');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _C.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.telegram,
                                color: _C.blue, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              user.telegram,
                              style: const TextStyle(
                                color: _C.blue,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _openUrl(
                            'https://wa.me/${user.whatsapp}');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _C.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_rounded,
                                color: _C.green, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              user.whatsapp,
                              style: const TextStyle(
                                color: _C.green,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: _C.textDim,
            size: 16,
          ),
        ],
      ),
    );
  }
}

// ─── Hexagon Stat Widget ───────────────────────────────────────────────────────
class _HexStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  final bool showLive, smallValue;

  const _HexStat({required this.icon, required this.value, required this.label,
      required this.color, this.showLive = false, this.smallValue = false});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Stack(clipBehavior: Clip.none, children: [
        SizedBox(
          width: 70, height: 70,
          child: CustomPaint(
            painter: _HexPainter(color),
            child: Center(child: Icon(icon, color: color, size: 26)),
          ),
        ),
        if (showLive)
          Positioned(
            top: 6, right: 8,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: _C.green,
                border: Border.all(color: _C.card, width: 1.5),
                boxShadow: [BoxShadow(color: _C.green.withOpacity(0.6), blurRadius: 6)],
              ),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(
          color: _C.text, fontSize: smallValue ? 11 : 16,
          fontWeight: FontWeight.w800),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      SizedBox(
        width: 85,
        child: Text(label, style: const TextStyle(color: _C.textSub, fontSize: 9),
            textAlign: TextAlign.center, maxLines: 2),
      ),
      if (showLive) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: _C.green.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(20),
            color: _C.green.withOpacity(0.08),
          ),
          child: const Text('LIVE',
              style: TextStyle(color: _C.green, fontSize: 8,
                  fontWeight: FontWeight.w800, letterSpacing: 1)),
        ),
      ],
    ]);
  }
}

// ─── Hexagon Painter ───────────────────────────────────────────────────────────
class _HexPainter extends CustomPainter {
  final Color color;
  _HexPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 2;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();

    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.fill);

    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_HexPainter old) => false;
}

// ─── Feature Card Widget ───────────────────────────────────────────────────────
class _FeatureCard extends StatefulWidget {
  final _FC fc;
  const _FeatureCard({required this.fc});
  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); fc.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 260,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: fc.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: fc.gradient[0].withOpacity(0.4),
                  blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Stack(children: [
            Positioned(
              right: -10, bottom: -10,
              child: Icon(fc.icon, size: 90,
                  color: Colors.white.withOpacity(0.15)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.25),
                        ),
                        child: Icon(fc.icon, color: Colors.white, size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Tap →',
                            style: TextStyle(
                                color: Colors.white, fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(fc.title,
                      style: const TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w900, height: 1.1)),
                  const SizedBox(height: 3),
                  Text(fc.subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Drawer Header ─────────────────────────────────────────────────────────────
class _DrawerHeader extends StatefulWidget {
  final String username, role, expiredDate;
  final File? profileImage;
  final VideoPlayerController? videoCtrl;
  const _DrawerHeader({required this.username, required this.role,
      required this.expiredDate, required this.profileImage, required this.videoCtrl});
  @override
  State<_DrawerHeader> createState() => _DrawerHeaderState();
}

class _DrawerHeaderState extends State<_DrawerHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _fade  = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rColor = _roleColor(widget.role);
    return Container(
      height: 230, clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: _C.card,
          border: Border(bottom: BorderSide(color: _C.cardAlt))),
      child: Stack(children: [
        if (widget.videoCtrl != null && widget.videoCtrl!.value.isInitialized)
          Positioned.fill(child: FittedBox(fit: BoxFit.cover,
              child: SizedBox(width: widget.videoCtrl!.value.size.width,
                  height: widget.videoCtrl!.value.size.height,
                  child: VideoPlayer(widget.videoCtrl!)))),
        Positioned.fill(child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x88F8FAFC), Color(0xF2FFFFFF)],
          )),
        )),
        Positioned.fill(child: SafeArea(
          child: FadeTransition(opacity: _fade, child: SlideTransition(
            position: _slide,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Stack(children: [
                Container(
                  width: 74, height: 74,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: rColor,
                      border: Border.all(color: rColor.withOpacity(0.6), width: 2),
                      boxShadow: [BoxShadow(color: rColor.withOpacity(0.3), blurRadius: 16)]),
                  child: ClipOval(child: widget.profileImage != null
                      ? Image.file(widget.profileImage!, fit: BoxFit.cover)
                      : Icon(_roleIcon(widget.role), size: 32, color: Colors.white)),
                ),
                Positioned(right: 0, bottom: 0, child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: rColor, shape: BoxShape.circle,
                      border: Border.all(color: _C.card, width: 2)),
                  child: Icon(_roleIcon(widget.role), size: 9, color: Colors.white),
                )),
              ]),
              const SizedBox(height: 12),
              Text(widget.username, style: const TextStyle(
                  color: _C.text, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: rColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: rColor.withOpacity(0.3))),
                child: Text(widget.role.toUpperCase(), style: TextStyle(
                    color: rColor, fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
              const SizedBox(height: 5),
              Text('Exp: ${widget.expiredDate}',
                  style: const TextStyle(color: _C.textSub, fontSize: 10)),
            ]),
          )),
        )),
      ]),
    );
  }
}

// ─── Drawer Item ───────────────────────────────────────────────────────────────
class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _DrawerItem({required this.icon, required this.label,
      required this.onTap, this.isDestructive = false});
  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive ? _C.red : _C.textSub;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _pressed ? color.withOpacity(0.25) : _C.cardAlt),
        ),
        child: Row(children: [
          Icon(widget.icon, color: color, size: 17),
          const SizedBox(width: 14),
          Text(widget.label, style: TextStyle(
              color: widget.isDestructive ? _C.red : _C.text,
              fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, color: _C.textDim, size: 11),
        ]),
      ),
    );
  }
}

// ─── AppBar Icon Button ────────────────────────────────────────────────────────
class _AppBarIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarIconBtn({required this.icon, required this.onTap});
  @override
  State<_AppBarIconBtn> createState() => _AppBarIconBtnState();
}

class _AppBarIconBtnState extends State<_AppBarIconBtn> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _down ? _C.blue.withOpacity(0.1) : _C.bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _C.cardAlt),
          ),
          child: Icon(widget.icon, color: _C.textSub, size: 17),
        ),
      ),
    );
  }
}

// ─── Menu Button ───────────────────────────────────────────────────────────────
class _MenuBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _MenuBtn({required this.onTap});
  @override
  State<_MenuBtn> createState() => _MenuBtnState();
}

class _MenuBtnState extends State<_MenuBtn> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          decoration: BoxDecoration(
            color: _down ? _C.blue.withOpacity(0.1) : _C.bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _C.cardAlt),
          ),
          child: const Icon(Icons.menu_rounded, color: _C.textSub, size: 19),
        ),
      ),
    );
  }
}

// ─── Animated Background (Hex Grid) — LIGHT ───────────────────────────────────
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
          painter: _BgPainter(controller.value), size: Size.infinite),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Background putih
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _C.bg);

    // Grid tipis
    final gridPaint = Paint()
      ..color = _C.border.withOpacity(0.08)
      ..strokeWidth = 0.5 ..style = PaintingStyle.stroke;
    const hexSize = 36.0;
    final hexW = hexSize * math.sqrt(3);
    final hexH = hexSize * 2;
    final rows = (size.height / (hexH * 0.75)).ceil() + 2;
    final cols = (size.width / hexW).ceil() + 2;
    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final dx = col * hexW + (row.isOdd ? hexW / 2 : 0);
        final dy = row * hexH * 0.75;
        _drawHex(canvas, Offset(dx, dy), hexSize, gridPaint);
      }
    }

    // Glow biru lembut di atas
    canvas.drawCircle(
      Offset(size.width / 2, -size.height * 0.1), size.width * 0.8,
      Paint()..shader = RadialGradient(colors: [
        _C.blue.withOpacity(0.08 + math.sin(t * math.pi * 2) * 0.03),
        Colors.transparent,
      ], radius: 0.6).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, -size.height * 0.1),
          radius: size.width * 0.8)),
    );

    // Glow ungu lembut di bawah
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height), size.width * 0.5,
      Paint()..shader = RadialGradient(colors: [
        _C.indigo.withOpacity(0.05 + math.sin(t * math.pi * 2 + 1) * 0.02),
        Colors.transparent,
      ], radius: 0.5).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height),
          radius: size.width * 0.5)),
    );
  }

  void _drawHex(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 180) * (60 * i - 30);
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Mx Button ─────────────────────────────────────────────────────────────────
class _MxBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;
  final Color color;
  const _MxBtn({required this.label, required this.onTap,
      this.fullWidth = false, this.color = _C.teal});
  @override
  State<_MxBtn> createState() => _MxBtnState();
}

class _MxBtnState extends State<_MxBtn> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 46,
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.fullWidth
              ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withOpacity(0.35)),
            boxShadow: _down ? [] : [BoxShadow(color: widget.color.withOpacity(0.12),
                blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: Center(child: Text(widget.label, style: TextStyle(
              color: widget.color, fontWeight: FontWeight.w800,
              fontSize: 14, letterSpacing: 0.5))),
        ),
      ),
    );
  }
}

// ─── Shared ────────────────────────────────────────────────────────────────────
PageRoute _slideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 320),
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: anim, child: child)),
);

// ─── NewsMedia ─────────────────────────────────────────────────────────────────
class NewsMedia extends StatefulWidget {
  final String url;
  const NewsMedia({super.key, required this.url});
  @override
  State<NewsMedia> createState() => _NewsMediaState();
}

class _NewsMediaState extends State<NewsMedia> {
  VideoPlayerController? _ctrl;
  @override
  void initState() {
    super.initState();
    if (_isVideo(widget.url)) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _ctrl?.setLooping(true); _ctrl?.setVolume(0); _ctrl?.play();
        });
    }
  }
  bool _isVideo(String url) => url.endsWith('.mp4') || url.endsWith('.webm')
      || url.endsWith('.mov') || url.endsWith('.mkv');
  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (_isVideo(widget.url)) {
      if (_ctrl?.value.isInitialized == true) {
        return AspectRatio(aspectRatio: _ctrl!.value.aspectRatio,
            child: VideoPlayer(_ctrl!));
      }
      return Container(color: _C.cardAlt, child: const Center(child: SizedBox(
          width: 18, height: 18, child: CircularProgressIndicator(
              strokeWidth: 1.5, color: _C.blue))));
    }
    return Image.network(widget.url, fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null ? child
          : Container(color: _C.cardAlt, child: Center(child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null,
              strokeWidth: 1.5, color: _C.blue))),
      errorBuilder: (_, __, ___) => Container(color: _C.cardAlt,
          child: const Icon(Icons.broken_image_outlined,
              color: _C.textSub, size: 28)),
    );
  }
}