import 'package:flutter/material.dart';
import 'music_service.dart';

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key});

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage>
    with TickerProviderStateMixin {
  final MusicService _music = MusicService();
  late AnimationController _rotateCtrl;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _music.play(assetPath: 'audio/bug.mp3'));
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _rotate = Tween<double>(begin: 0, end: 1).animate(_rotateCtrl);
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A15),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _music,
          builder: (context, _) {
            return Column(
              children: [
                // ── Header ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                          ),
                        ),
                        child: const Icon(Icons.music_note_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MANTA AUDIO ENGINE', style: TextStyle(
                                color: Color(0xFFF1F5F9), fontSize: 12,
                                fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                            Text('USER // KINGTAMM', style: TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 10,
                                letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Info Card ──────────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF3B82F6).withOpacity(0.5)),
                        ),
                        child: const Text('SOUNDTRACK', style: TextStyle(
                            color: Color(0xFF3B82F6), fontSize: 10,
                            fontWeight: FontWeight.w900, letterSpacing: 2)),
                      ),
                      const SizedBox(height: 14),
                      const Text('DENGARKAN MUSIC', style: TextStyle(
                          color: Color(0xFFF1F5F9), fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: 2)),
                      const SizedBox(height: 6),
                      const Text(
                        'Nikmati lagu pembuka sebelum masuk ke dashboard utama',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF94A3B8),
                            fontSize: 11, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // ── Disc ───────────────────────────────────────────
                Expanded(
                  child: Center(
                    child: RotationTransition(
                      turns: _rotate,
                      child: Container(
                        width: 220, height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0A0A0A),
                          border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.4),
                              width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              blurRadius: 40, spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 130, height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0F172A),
                              border: Border.all(
                                  color: const Color(0xFF10B981).withOpacity(0.6),
                                  width: 2),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.music_note_rounded,
                                      color: Color(0xFF10B981), size: 40),
                                  SizedBox(height: 6),
                                  Text("FANVXP", style: TextStyle(
                                      color: Color(0xFFF1F5F9), fontSize: 14,
                                      fontWeight: FontWeight.w900, letterSpacing: 2)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Controls ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      if (_music.isPlaying)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    const Color(0xFF10B981).withOpacity(0.7)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text('Memuat intro...', style: TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 12)),
                          ],
                        )
                      else
                        const Text('Tap play untuk memutar', style: TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 12)),
                      const SizedBox(height: 24),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF10B981),
                          inactiveTrackColor:
                              const Color(0xFF10B981).withOpacity(0.2),
                          thumbColor: const Color(0xFF10B981),
                          overlayColor: const Color(0xFF10B981).withOpacity(0.2),
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                        ),
                        child: Slider(
                          value: _music.duration.inMilliseconds > 0
                              ? _music.position.inMilliseconds /
                                  _music.duration.inMilliseconds
                              : 0.0,
                          onChanged: (v) {
                            final pos = Duration(
                              milliseconds: (v *
                                      _music.duration.inMilliseconds)
                                  .toInt(),
                            );
                            _music.seek(pos);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(_music.position),
                                style: const TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 11)),
                            Text(_fmt(_music.duration),
                                style: const TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => _music.toggle(),
                        child: Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.5),
                                blurRadius: 20, spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _music.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white, size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                // ── Tombol MASUK LOGIN ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        // ← KE LOGIN PAGE
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, size: 20),
                          SizedBox(width: 10),
                          Text('MASUK LOGIN', style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900,
                              letterSpacing: 2)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}