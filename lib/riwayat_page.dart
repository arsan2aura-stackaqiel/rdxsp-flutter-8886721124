import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

class RiwayatPage extends StatefulWidget {
  final String sessionKey;
  final String role;

  const RiwayatPage({
    super.key,
    required this.sessionKey,
    required this.role,
  });

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  List<ActivityModel> activities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    const baseUrl = "http://ridoampasbego.smasnug.web.id:4763";

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getMyActivity?key=${widget.sessionKey}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid']) {
          List<dynamic> rawList = data['activities'];

          setState(() {
            activities = rawList.map((item) {
              return ActivityModel(
                type: item['type'] ?? 'system',
                title: item['title'] ?? 'Aktivitas',
                description: item['description'] ?? '-',
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                    item['timestamp'] ?? DateTime.now().millisecondsSinceEpoch
                ),
              );
            }).toList();
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        debugPrint("Server Error: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
      setState(() => isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: Text(
          "Riwayat Aktivitas",
          style: TextStyle(
            color: _C.text,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: _C.blueMid.withOpacity(0.8),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _C.text),
          onPressed: () => Navigator.pop(context),
        ),
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
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _C.blueMid,
                ),
              )
            : activities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 60, color: _C.textDim),
                        const SizedBox(height: 16),
                        Text(
                          "Belum ada aktivitas",
                          style: TextStyle(color: _C.textSub, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Pastikan server aktif",
                          style: TextStyle(color: _C.textDim.withOpacity(0.6), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadActivities,
                    color: _C.blueLight,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        return _buildActivityCard(activity);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityModel activity) {
    Color iconColor;
    IconData iconData;
    String typeLabel;

    switch (activity.type) {
      case 'login':
        iconColor = _C.green;
        iconData = Icons.login_rounded;
        typeLabel = "LOGIN";
        break;
      case 'bug':
        iconColor = _C.amber;
        iconData = Icons.bug_report_outlined;
        typeLabel = "ATTACK";
        break;
      case 'create':
        iconColor = _C.blueLight;
        iconData = Icons.person_add_alt_1_rounded;
        typeLabel = "ACCOUNT";
        break;
      default:
        iconColor = _C.textDim;
        iconData = Icons.info_outline;
        typeLabel = "SYSTEM";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: _C.blueDark.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withOpacity(0.3)),
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        activity.title,
                        style: TextStyle(
                          color: _C.text,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.blueMid.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: _C.blueLight,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  activity.description,
                  style: TextStyle(
                    color: _C.textSub,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: _C.textDim.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(activity.timestamp),
                      style: TextStyle(
                        color: _C.textDim.withOpacity(0.7),
                        fontSize: 11,
                        fontFamily: 'ShareTechMono',
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
}

class ActivityModel {
  final String type;
  final String title;
  final String description;
  final DateTime timestamp;

  ActivityModel({
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
  });
}