import 'package:flutter/material.dart';
import 'music_player.dart';

class IntroCarouselPage extends StatefulWidget {
  const IntroCarouselPage({super.key});

  @override
  State<IntroCarouselPage> createState() => _IntroCarouselPageState();
}

class _IntroCarouselPageState extends State<IntroCarouselPage> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  final List<_SlideData> _slides = const [
    _SlideData(
      title: 'FANVXP BEDA DARI PROJECT YANG LAMA',
      subtitle: 'Versi terbaru dengan fitur lengkap dan stabil',
      badge: 'INFO APLIKASI',
      bgColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF0F172A),
      accentColor: Color(0xFF2563EB),
      icon: Icons.new_releases_rounded,
    ),
    _SlideData(
      title: 'DEVELOPER ROMBAK BASE AQIEL',
      subtitle: 'Yang telah merombak base aplikasi ini',
      badge: 'DEVELOPER',
      bgColor: Color(0xFF2563EB),
      textColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFFDBEAFE),
      icon: Icons.build_circle_rounded,
    ),
    _SlideData(
      title: 'DEVELOPER UTAMA FAN GANTENG',
      subtitle: 'Pengembang utama aplikasi FANVXP',
      badge: 'DEVELOPER',
      bgColor: Color(0xFFDC2626),
      textColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFFFEE2E2),
      icon: Icons.person_rounded,
    ),
    _SlideData(
      title: 'SELAMAT DATANG KE FANVXP',
      subtitle: 'SELAMAT MENGGUNAKAN APK INI. PATUHI ATURAN APLIKASI YA!',
      badge: 'WELCOME',
      bgColor: Color(0xFF000000),
      textColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFF3B82F6),
      icon: Icons.waving_hand_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _slides[_currentPage];

    return Scaffold(
      backgroundColor: current.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: current.accentColor, size: 20),
                  const SizedBox(width: 10),
                  Text('INTRO FANVXP', style: TextStyle(
                      color: current.textColor, fontSize: 13,
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const Spacer(),
                  Text('${_currentPage + 1}/${_slides.length}',
                      style: TextStyle(
                          color: current.textColor.withOpacity(0.6),
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _buildSlide(_slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? current.accentColor
                              : current.textColor.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        // ← KE MUSIC PLAYER
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MusicPlayerPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: current.accentColor,
                        foregroundColor: current.bgColor == Colors.white
                            ? Colors.white
                            : current.bgColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('GO TO DASHBOARD', style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900,
                              letterSpacing: 2)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
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
    );
  }

  Widget _buildSlide(_SlideData slide) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: slide.accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: slide.accentColor.withOpacity(0.5)),
            ),
            child: Text(slide.badge, style: TextStyle(
                color: slide.accentColor, fontSize: 10,
                fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),
          const SizedBox(height: 40),
          Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: slide.accentColor.withOpacity(0.15),
              border: Border.all(color: slide.accentColor, width: 3),
              boxShadow: [
                BoxShadow(color: slide.accentColor.withOpacity(0.3),
                    blurRadius: 30, spreadRadius: 5),
              ],
            ),
            child: Icon(slide.icon, color: slide.accentColor, size: 60),
          ),
          const SizedBox(height: 50),
          Text(slide.title, textAlign: TextAlign.center, style: TextStyle(
              color: slide.textColor, fontSize: 24,
              fontWeight: FontWeight.w900, letterSpacing: 1.2, height: 1.3)),
          const SizedBox(height: 20),
          Container(
            width: 60, height: 3,
            decoration: BoxDecoration(
              color: slide.accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(slide.subtitle, textAlign: TextAlign.center,
                style: TextStyle(color: slide.textColor.withOpacity(0.75),
                    fontSize: 14, height: 1.6)),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final String title;
  final String subtitle;
  final String badge;
  final Color bgColor;
  final Color textColor;
  final Color accentColor;
  final IconData icon;

  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.bgColor,
    required this.textColor,
    required this.accentColor,
    required this.icon,
  });
}