import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ChatRoomPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String roomId;

  const ChatRoomPage({
    super.key,
    required this.sessionKey,
    required this.username,
    this.roomId = 'general',
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController msgCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();
  final FocusNode focusNode = FocusNode();

  // ── Server Config ────────────────────────────────────────────────────────
  static const String _baseUrl = 'http://beyy-panel.cyberpanel.web.id:2120';
  static const String _chatEndpoint = '/api/chatroom';

  List<Map<String, dynamic>> chats = [];
  bool loading = true;
  bool isSending = false;
  bool showSendButton = false;
  bool showScrollButton = false;
  int _lastMsgTs = 0;
  Timer? _pollTimer;

  final GlobalKey<RefreshIndicatorState> refreshKey =
      GlobalKey<RefreshIndicatorState>();

  final Color primaryColor   = const Color(0xFF1565C0);
  final Color secondaryColor = const Color(0xFF18181B);
  final Color backgroundColor = const Color(0xFF09090B);
  final Color bubbleOutgoing = const Color(0xFF1565C0);
  final Color bubbleIncoming = const Color(0xFF27272A);
  final Color accentColor    = const Color(0xFF0D47A1);
  final Color textColor      = Colors.white;
  final Color subtitleColor  = Colors.grey[400]!;

  @override
  void initState() {
    super.initState();
    _loadChats(initial: true);
    _startPolling();
    focusNode.addListener(_onFocusChange);
    scrollCtrl.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    focusNode.removeListener(_onFocusChange);
    scrollCtrl.removeListener(_scrollListener);
    focusNode.dispose();
    msgCtrl.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POLLING — Auto refresh tiap 3 detik
  // ═══════════════════════════════════════════════════════════════════════════
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadChats();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOAD CHATS dari server
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _loadChats({bool initial = false}) async {
    try {
      final url = '$_baseUrl$_chatEndpoint/messages'
          '?room=${widget.roomId}'
          '&session=${Uri.encodeComponent(widget.sessionKey)}'
          '${_lastMsgTs > 0 ? '&since=$_lastMsgTs' : ''}';

      final res = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final List<dynamic> list = (data['messages'] as List?) ?? [];

        if (list.isEmpty && !initial) return;

        final List<Map<String, dynamic>> newMessages = [];

        for (var item in list) {
          final raw = item as Map<String, dynamic>;

          final id = raw['id']?.toString() ?? '';
          final msg = {
            'id': id,
            'from': raw['sender']?.toString() ?? 'unknown',
            'message': raw['message']?.toString() ?? '',
            'time': (raw['timestamp'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch,
            'status': 'terkirim',
          };

          // Cek duplikasi
          if (!chats.any((c) => c['id'] == id)) {
            newMessages.add(msg);
            final ts = msg['time'] as int;
            if (ts > _lastMsgTs) _lastMsgTs = ts;
          }
        }

        setState(() {
          if (initial) loading = false;
          chats.addAll(newMessages);
          chats.sort((a, b) =>
              (a['time'] as int).compareTo(b['time'] as int));
        });

        if (newMessages.isNotEmpty) {
          _scrollToBottom();
        }
      } else {
        if (initial && mounted) setState(() => loading = false);
      }
    } catch (e) {
      debugPrint('Load chats error: $e');
      if (initial && mounted) setState(() => loading = false);
    }
  }

  Future<void> _refreshChats() async {
    _lastMsgTs = 0;
    setState(() => chats.clear());
    await _loadChats(initial: true);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEND MESSAGE ke server
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _sendMessage() async {
    final msg = msgCtrl.text.trim();
    if (msg.isEmpty || isSending) return;

    setState(() {
      isSending = true;
      showSendButton = false;
    });

    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final newMessage = {
      'id': localId,
      'from': widget.username,
      'message': msg,
      'time': DateTime.now().millisecondsSinceEpoch,
      'status': 'mengirim',
    };

    msgCtrl.clear();

    setState(() => chats.add(newMessage));
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_chatEndpoint/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session': widget.sessionKey,
          'username': widget.username,
          'room': widget.roomId,
          'message': msg,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final idx = chats.indexWhere((c) => c['id'] == localId);
        if (idx != -1) {
          setState(() {
            chats[idx]['status'] = 'terkirim';
          });
        }
        // Load ulang untuk sinkron dengan server (dapat ID asli)
        _loadChats();
      } else {
        final idx = chats.indexWhere((c) => c['id'] == localId);
        if (idx != -1) {
          setState(() => chats[idx]['status'] = 'gagal');
        }
      }
    } catch (e) {
      debugPrint('Send error: $e');
      final idx = chats.indexWhere((c) => c['id'] == localId);
      if (idx != -1) {
        setState(() => chats[idx]['status'] = 'gagal');
      }
    } finally {
      if (mounted) setState(() => isSending = false);
      focusNode.requestFocus();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  void _scrollListener() {
    if (!scrollCtrl.hasClients) return;
    final offset = scrollCtrl.offset;
    final maxScroll = scrollCtrl.position.maxScrollExtent;

    if (maxScroll - offset > 300 && !showScrollButton) {
      setState(() => showScrollButton = true);
    } else if (maxScroll - offset <= 300 && showScrollButton) {
      setState(() => showScrollButton = false);
    }
  }

  void _onFocusChange() {
    if (focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
    }
  }

  void _scrollToBottom() {
    if (scrollCtrl.hasClients) {
      scrollCtrl.animateTo(
        scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final today = DateTime.now();

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return "Hari Ini";
    } else if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day - 1) {
      return "Kemarin";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  Widget _buildMessageStatus(String status) {
    switch (status) {
      case "mengirim":
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.grey[400]!),
          ),
        );
      case "terkirim":
        return Icon(Icons.check, size: 16, color: Colors.grey[400]);
      case "diterima":
        return Icon(Icons.done_all, size: 16, color: Colors.grey[400]);
      case "dibaca":
        return Icon(Icons.done_all, size: 16, color: primaryColor);
      case "gagal":
        return Icon(Icons.error_outline, size: 16, color: Colors.red[400]);
      default:
        return Icon(Icons.check, size: 16, color: Colors.grey[400]);
    }
  }

  Widget _buildAvatar(String username, {bool isOnline = true}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [primaryColor, accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              username.isNotEmpty
                  ? username.substring(0, 1).toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 2,
                    color: Colors.black26,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
          if (isOnline)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: backgroundColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> item, bool isMe) {
    final currentIndex = chats.indexWhere((c) => c['id'] == item['id']);
    final isFirstInSequence = currentIndex == 0 ||
        chats[currentIndex - 1]['from'] != item['from'];

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInSequence ? 8 : 2,
        left: 12,
        right: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            AnimatedOpacity(
              opacity: isFirstInSequence ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _buildAvatar(item['from'].toString()),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && isFirstInSequence)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      item['from'].toString(),
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? bubbleOutgoing : bubbleIncoming,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft:
                          isMe ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight:
                          isMe ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['message'].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(item['time'] as int),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              _buildMessageStatus(
                                  item['status']?.toString() ?? 'terkirim'),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
              child: Divider(color: Colors.grey[700], thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: secondaryColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Text(
                date,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Expanded(
              child: Divider(color: Colors.grey[700], thickness: 0.5)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      backgroundColor,
                      secondaryColor.withOpacity(0.8)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 28),
                        color: Colors.white,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      _buildAvatar("Global"),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Obrolan Global",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${chats.length} pesan • ${chats.map((c) => c['from']).toSet().length} peserta",
                              style: TextStyle(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 22),
                        color: Colors.white,
                        onPressed: _refreshChats,
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, size: 24),
                        color: Colors.white,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),

              // ── Chat List ─────────────────────────────────────────────
              Expanded(
                child: loading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation(primaryColor),
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Memuat percakapan...",
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : chats.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            key: refreshKey,
                            backgroundColor: backgroundColor,
                            color: primaryColor,
                            onRefresh: _refreshChats,
                            child: ListView.builder(
                              controller: scrollCtrl,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              itemCount: chats.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return _buildDateSeparator("Hari Ini");
                                }
                                final item = chats[index - 1];
                                final isMe =
                                    item['from'] == widget.username;

                                if (index > 1) {
                                  final prevItem = chats[index - 2];
                                  final currentDate =
                                      _formatDate(item['time'] as int);
                                  final prevDate =
                                      _formatDate(prevItem['time'] as int);

                                  if (currentDate != prevDate) {
                                    return Column(
                                      children: [
                                        _buildDateSeparator(currentDate),
                                        _buildMessageBubble(item, isMe),
                                      ],
                                    );
                                  }
                                }

                                return _buildMessageBubble(item, isMe);
                              },
                            ),
                          ),
              ),

              // ── Sending Indicator ─────────────────────────────────────
              if (isSending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleIncoming,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(primaryColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Mengirim...",
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Input Bar ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(
                  color: secondaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined,
                            size: 24),
                        color: Colors.grey[400],
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.attach_file_rounded, size: 24),
                        color: Colors.grey[400],
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: msgCtrl,
                          focusNode: focusNode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          maxLines: null,
                          onChanged: (value) {
                            setState(() {
                              showSendButton = value.trim().isNotEmpty;
                            });
                          },
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: "Ketik pesan...",
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            suffixIcon: showSendButton
                                ? IconButton(
                                    icon: Icon(
                                      Icons.send_rounded,
                                      color: primaryColor,
                                      size: 24,
                                    ),
                                    onPressed: _sendMessage,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    if (!showSendButton) ...[
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.mic_rounded, size: 24),
                          color: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: showScrollButton
            ? FloatingActionButton.small(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onPressed: _scrollToBottom,
                child: const Icon(Icons.arrow_downward_rounded, size: 20),
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: secondaryColor,
              border: Border.all(color: Colors.grey[700]!, width: 1.5),
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.grey[500], size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            "Belum ada pesan",
            style: TextStyle(
              color: subtitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Kirim pesan pertama untuk memulai chat",
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }
}