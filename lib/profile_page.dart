import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'change_password_page.dart';

// ─── Palette: Biru Modern (sama dengan halaman lain) ─────────────────────────
class _C {
  static const bg         = Color(0xFF0A1929);      // Biru gelap background
  static const surface    = Color(0xFF0F2B40);      // Biru tua surface
  static const card       = Color(0xFF143D5C);      // Biru card
  static const border     = Color(0xFF1A5A8A);      // Biru border
  static const borderLit  = Color(0xFF2B7ABF);      // Biru terang border
  
  static const blueDark   = Color(0xFF0A4D8C);
  static const blueMid    = Color(0xFF1A6FB0);
  static const blueLight  = Color(0xFF2D8FD9);
  static const blueAccent = Color(0xFF4AA5F0);
  
  static const green      = Color(0xFF22C55E);
  static const amber      = Color(0xFFF59E0B);
  static const red        = Color(0xFFEF4444);
  
  static const text       = Color(0xFFF0F8FF);      // Putih kebiruan
  static const textSub    = Color(0xFFB0D4F0);      // Biru muda
  static const textDim    = Color(0xFF5A9BC0);      // Biru redup
  
  static const LinearGradient btnGrad = LinearGradient(
    colors: [Color(0xFF1A6FB0), Color(0xFF2D8FD9), Color(0xFF4AA5F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ProfilePage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;

  const ProfilePage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_${widget.username}');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  String _censorText(String text, {bool isPassword = false}) {
    if (text.isEmpty) return "N/A";
    if (isPassword) {
      return "••••••••";
    }
    if (text.length <= 2) return "${text.substring(0, 1)}••";
    return "${text.substring(0, 2)}${'•' * (text.length - 2)}";
  }

  Future<void> _showImageSourceDialog() {
    return showModalBottomSheet(
      context: context,
      backgroundColor: _C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _C.blueLight),
              title: const Text("Kamera", style: TextStyle(color: _C.text)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _C.blueAccent),
              title: const Text("Galeri", style: TextStyle(color: _C.text)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_${widget.username}', imageFile.path);

        setState(() {
          _profileImage = imageFile;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _C.blueLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: _C.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _C.bg,
              _C.blueDark.withOpacity(0.3),
              _C.bg,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              Center(
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [_C.blueMid, _C.blueLight],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _C.blueMid.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: ClipOval(
                          child: _profileImage != null
                              ? Image.file(
                                  _profileImage!,
                                  fit: BoxFit.cover,
                                )
                              : Icon(
                                  FontAwesomeIcons.userAstronaut,
                                  size: 50,
                                  color: _C.text.withOpacity(0.8),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _C.blueLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: _C.bg, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                widget.username,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
              Text(
                widget.role.toUpperCase(),
                style: TextStyle(
                  color: _C.blueLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.person_outline,
                      label: "Username",
                      value: _censorText(widget.username),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.lock_outline,
                      label: "Password",
                      value: _censorText(widget.password, isPassword: true),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.verified_user_outlined,
                      label: "Role",
                      value: widget.role.toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.calendar_today_outlined,
                      label: "Expired",
                      value: widget.expiredDate,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              _buildInfoCard(
                icon: Icons.vpn_key,
                label: "Session Key",
                value: "${widget.sessionKey.substring(0, 8)}...",
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_reset, color: Colors.white),
                  label: const Text(
                    "CHANGE PASSWORD",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.blueMid,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    shadowColor: _C.blueMid.withOpacity(0.5),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangePasswordPage(
                          username: widget.username,
                          sessionKey: widget.sessionKey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: _C.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _C.blueMid.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _C.blueLight, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _C.textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: _C.text,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'ShareTechMono',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}