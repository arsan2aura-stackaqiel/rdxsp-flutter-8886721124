import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ─── Palette: Neon Red & Neon White/Blue ───────────────────────────────────────
class _C {
  static const bg        = Color(0xFF05060A);
  static const surface   = Color(0xFF0B0D14);
  static const card      = Color(0xFF11141F);
  static const cardAlt   = Color(0xFF1A1F2E);
  static const border    = Color(0xFF00BFFF);
  static const borderLit = Color(0xFF00E5FF);
  static const teal      = Color(0xFF00E5FF);
  static const green     = Color(0xFF00FFD1);
  static const blue      = Color(0xFF00BFFF);
  static const red       = Color(0xFFFF073A);
  static const amber     = Color(0xFFFF4D6D);
  static const text      = Color(0xFFE0F7FF);
  static const textSub   = Color(0xFF7DF9FF);
  static const textDim   = Color(0xFF2E5A6B);
}

// ─── New User Page ─────────────────────────────────────────────────────────────
class NewUserPage extends StatefulWidget {
  final String sessionKey;
  const NewUserPage({super.key, required this.sessionKey});

  @override
  State<NewUserPage> createState() => _NewUserPageState();
}

class _NewUserPageState extends State<NewUserPage> {
  final _formKey      = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _expiryCtrl   = TextEditingController();

  String _selectedRole = 'member';
  bool _isLoading      = false;
  bool _obscurePass    = true;
  WebSocketChannel? _channel;
  bool _responseReceived = false;

  final List<Map<String, dynamic>> _roles = [
    {'name': 'member',   'color': Color(0xFF7DF9FF), 'icon': Icons.person_outline},
    {'name': 'reseller', 'color': Color(0xFF00E5FF), 'icon': Icons.storefront_rounded},
    {'name': 'partner',  'color': Color(0xFF00FFD1), 'icon': Icons.handshake_rounded},
    {'name': 'vip',      'color': Color(0xFF7DF9FF), 'icon': Icons.star_rounded},
    {'name': 'admin',    'color': Color(0xFFFF4D6D), 'icon': Icons.admin_panel_settings_rounded},
    {'name': 'owner',    'color': Color(0xFFFF073A), 'icon': Icons.workspace_premium_rounded},
  ];

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _expiryCtrl.dispose();
    try { _channel?.sink.close(status.goingAway); } catch (_) {}
    super.dispose();
  }

  Future<void> _submitUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _responseReceived = false;
    });

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('http://beyy-panel.cyberpanel.web.id:2120'),
      );

      _channel!.sink.add(jsonEncode({
        'type': 'createUser',
        'sessionKey': widget.sessionKey,
        'newUsername': _usernameCtrl.text.trim(),
        'newPassword': _passwordCtrl.text,
        'newRole': _selectedRole,
        'expiryDate': _expiryCtrl.text.trim().isEmpty ? 'lifetime' : _expiryCtrl.text.trim(),
      }));

      // Listen untuk response
      _channel!.stream.listen(
        (event) {
          try {
            final data = jsonDecode(event);
            if (data['type'] == 'createUserResponse') {
              if (!mounted) return;
              _responseReceived = true;
              setState(() => _isLoading = false);
              _showResultDialog(
                success: data['success'] == true,
                message: data['message']?.toString() ?? 
                    (data['success'] == true ? 'User berhasil dibuat' : 'Gagal membuat user'),
              );
            }
          } catch (_) {}
        },
        onError: (e) {
          if (!mounted) return;
          _responseReceived = true;
          setState(() => _isLoading = false);
          _showResultDialog(success: false, message: 'Error koneksi: $e');
        },
      );

      // Timeout 12 detik
      Future.delayed(const Duration(seconds: 12), () {
        if (!_responseReceived && mounted) {
          setState(() => _isLoading = false);
          _showResultDialog(
            success: false,
            message: 'Timeout. Server tidak merespons.\nPastikan backend mendukung "createUser".',
          );
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showResultDialog(success: false, message: 'Terjadi kesalahan: $e');
    }
  }

  void _showResultDialog({required bool success, required String message}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (success ? _C.green : _C.red).withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (success ? _C.green : _C.red).withOpacity(0.15),
                blurRadius: 40,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (success ? _C.green : _C.red).withOpacity(0.12),
                  border: Border.all(
                    color: (success ? _C.green : _C.red).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  success ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: success ? _C.green : _C.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                success ? 'BERHASIL' : 'GAGAL',
                style: TextStyle(
                  color: success ? _C.green : _C.red,
                  fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSub, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    if (success) {
                      _usernameCtrl.clear();
                      _passwordCtrl.clear();
                      _expiryCtrl.clear();
                      setState(() => _selectedRole = 'member');
                    }
                  },
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: (success ? _C.green : _C.red).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (success ? _C.green : _C.red).withOpacity(0.4),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        success ? 'BUAT USER LAIN' : 'COBA LAGI',
                        style: TextStyle(
                          color: success ? _C.green : _C.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 13, letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textSub, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'BUAT USER BARU',
          style: TextStyle(
            color: _C.text,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.border),
        ),
      ),
      body: Stack(
        children: [
          // Grid BG
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Card ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _C.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _C.border.withOpacity(0.5), width: 1.2),
                        boxShadow: [
                          BoxShadow(color: _C.blue.withOpacity(0.1), blurRadius: 20),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _C.teal.withOpacity(0.15),
                              border: Border.all(color: _C.teal.withOpacity(0.4), width: 1.5),
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded,
                                color: _C.teal, size: 22),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TAMBAH USER',
                                  style: TextStyle(
                                    color: _C.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Buat akun user baru dengan role tertentu',
                                  style: TextStyle(color: _C.textSub, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Form Username ───────────────────────────────────
                    _buildLabel('USERNAME', Icons.person_outline),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _usernameCtrl,
                      hint: 'Masukkan username baru',
                      icon: Icons.alternate_email_rounded,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Username wajib diisi';
                        if (v.trim().length < 3) return 'Minimal 3 karakter';
                        if (v.contains(' ')) return 'Tidak boleh ada spasi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // ── Form Password ───────────────────────────────────
                    _buildLabel('PASSWORD', Icons.lock_outline),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _passwordCtrl,
                      hint: 'Masukkan password',
                      icon: Icons.vpn_key_rounded,
                      obscureText: _obscurePass,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: _C.textSub, size: 18,
                        ),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password wajib diisi';
                        if (v.length < 4) return 'Minimal 4 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // ── Form Expiry (Opsional) ──────────────────────────
                    _buildLabel('EXPIRY DATE (OPSIONAL)', Icons.calendar_month_outlined),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _expiryCtrl,
                      hint: 'Contoh: 2026-12-31 (kosongkan = lifetime)',
                      icon: Icons.event_outlined,
                      validator: (_) => null,
                    ),
                    const SizedBox(height: 18),

                    // ── Dropdown Role ───────────────────────────────────
                    _buildLabel('PILIH ROLE', Icons.shield_outlined),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _C.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _C.border.withOpacity(0.5), width: 1.2),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: _C.cardAlt,
                          dividerColor: _C.border,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRole,
                            isExpanded: true,
                            icon: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.keyboard_arrow_down_rounded,
                                  color: _C.textSub, size: 22),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            dropdownColor: _C.cardAlt,
                            borderRadius: BorderRadius.circular(12),
                            items: _roles.map((r) {
                              return DropdownMenuItem<String>(
                                value: r['name'] as String,
                                child: Row(
                                  children: [
                                    Icon(r['icon'] as IconData,
                                        color: r['color'] as Color, size: 18),
                                    const SizedBox(width: 10),
                                    Text(
                                      (r['name'] as String).toUpperCase(),
                                      style: TextStyle(
                                        color: r['color'] as Color,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedRole = v);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Preview Role Color ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _roleColor(_selectedRole).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _roleColor(_selectedRole).withOpacity(0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(_roleIcon(_selectedRole),
                              color: _roleColor(_selectedRole), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'User akan dibuat dengan role: ${_selectedRole.toUpperCase()}',
                              style: TextStyle(
                                color: _roleColor(_selectedRole),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Submit Button ───────────────────────────────────
                    GestureDetector(
                      onTap: _isLoading ? null : _submitUser,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 56,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: _isLoading
                              ? LinearGradient(colors: [
                                  _C.textDim, _C.textDim,
                                ])
                              : const LinearGradient(
                                  colors: [Color(0xFF00BFFF), Color(0xFF00E5FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _isLoading
                              ? []
                              : [
                                  BoxShadow(
                                    color: _C.teal.withOpacity(0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_rounded,
                                        color: Colors.black, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'TAMBAHKAN USER',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        '⚠️ Hanya reseller yang boleh mengakses fitur ini',
                        style: TextStyle(
                          color: _C.textDim,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':    return const Color(0xFFFF073A);
      case 'admin':    return const Color(0xFFFF4D6D);
      case 'reseller': return const Color(0xFF00E5FF);
      case 'partner':  return const Color(0xFF00FFD1);
      case 'vip':      return const Color(0xFF7DF9FF);
      default:         return const Color(0xFF7DF9FF);
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'owner':    return Icons.workspace_premium_rounded;
      case 'admin':    return Icons.admin_panel_settings_rounded;
      case 'reseller': return Icons.storefront_rounded;
      case 'partner':  return Icons.handshake_rounded;
      case 'vip':      return Icons.star_rounded;
      default:         return Icons.person_outline_rounded;
    }
  }

  Widget _buildLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _C.teal, size: 14),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: _C.textSub,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w600),
      cursorColor: _C.teal,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _C.textDim, fontSize: 12),
        prefixIcon: Icon(icon, color: _C.textSub, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _C.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _C.border.withOpacity(0.5), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.red, width: 1.5),
        ),
        errorStyle: const TextStyle(color: _C.red, fontSize: 11),
      ),
    );
  }
}

// ─── Grid Painter ──────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _C.border.withOpacity(0.08)
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