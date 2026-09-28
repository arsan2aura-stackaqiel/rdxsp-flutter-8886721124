import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Surah {
  final String name;
  final Map<String, String> nameTranslations;
  final String englishName;
  final int numberOfAyahs;
  final int number;
  final String place;
  final String revelationType;
  final String? recitation;

  Surah({
    required this.name,
    required this.nameTranslations,
    required this.englishName,
    required this.numberOfAyahs,
    required this.number,
    required this.place,
    required this.revelationType,
    this.recitation,
  });

  String get nameTranslation => nameTranslations['id'] ?? englishName;
  String get arabicName => nameTranslations['ar'] ?? name;

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      name: json['name'],
      nameTranslations: Map<String, String>.from(json['name_translations']),
      englishName: json['name_translations']['en'],
      numberOfAyahs: json['number_of_ayah'],
      number: json['number_of_surah'],
      place: json['place'],
      revelationType: json['type'],
      recitation: json['recitation'],
    );
  }
}

class Ayah {
  final int number;
  final String text;
  final String translationEn;
  final String translationId;

  Ayah({
    required this.number,
    required this.text,
    required this.translationEn,
    required this.translationId,
  });

  factory Ayah.fromJson(Map<String, dynamic> json) {
    return Ayah(
      number: json['number'],
      text: json['text'],
      translationEn: json['translation_en'],
      translationId: json['translation_id'],
    );
  }
}

class SurahDetail {
  final Surah surah;
  final List<Ayah> verses;
  final List<Recitation> recitations;
  final Map<String, dynamic> tafsir;

  SurahDetail({
    required this.surah,
    required this.verses,
    required this.recitations,
    required this.tafsir,
  });

  factory SurahDetail.fromJson(Map<String, dynamic> json, Surah surah) {
    return SurahDetail(
      surah: surah,
      verses: (json['verses'] as List)
          .map((verse) => Ayah.fromJson(verse))
          .toList(),
      recitations: (json['recitations'] as List)
          .map((recitation) => Recitation.fromJson(recitation))
          .toList(),
      tafsir: json['tafsir'] ?? {},
    );
  }
}

class Recitation {
  final String name;
  final String audioUrl;

  Recitation({
    required this.name,
    required this.audioUrl,
  });

  factory Recitation.fromJson(Map<String, dynamic> json) {
    return Recitation(
      name: json['name'],
      audioUrl: json['audio_url'],
    );
  }
}

class QuranSettings {
  bool showTranslation;
  double arabicFontSize;
  int selectedReciterIndex;
  String themeColor;

  QuranSettings({
    this.showTranslation = true,
    this.arabicFontSize = 28.0,
    this.selectedReciterIndex = 0,
    this.themeColor = 'blue',
  });

  Map<String, dynamic> toJson() => {
        'showTranslation': showTranslation,
        'arabicFontSize': arabicFontSize,
        'selectedReciterIndex': selectedReciterIndex,
        'themeColor': themeColor,
      };

  factory QuranSettings.fromJson(Map<String, dynamic> json) => QuranSettings(
        showTranslation: json['showTranslation'] ?? true,
        arabicFontSize: (json['arabicFontSize'] ?? 28.0).toDouble(),
        selectedReciterIndex: json['selectedReciterIndex'] ?? 0,
        themeColor: json['themeColor'] ?? 'blue',
      );
}

class ThemeColors {
  static Map<String, List<Color>> colorSchemes = {
    'blue': [
      Color(0xFF0A2540),
      Color(0xFF0A1929),
      Color(0xFF00B4D8),
      Color(0xFF0077B6),
      Color(0xFF0096C7),
      Color(0xFF023E8A),
    ],
    'green': [
      Color(0xFF0A4029),
      Color(0xFF0A1929),
      Color(0xFF00D8A8),
      Color(0xFF00B67B),
      Color(0xFF00C796),
      Color(0xFF028A3E),
    ],
    'purple': [
      Color(0xFF2D0A40),
      Color(0xFF1A0A29),
      Color(0xFFA855F7),
      Color(0xFF7C3AED),
      Color(0xFF9333EA),
      Color(0xFF5B21B6),
    ],
    'gold': [
      Color(0xFF40300A),
      Color(0xFF29200A),
      Color(0xFFD8B600),
      Color(0xFFB67B00),
      Color(0xFFC79600),
      Color(0xFF8A5E02),
    ],
  };

  static Color getPrimaryColor(String theme) => colorSchemes[theme]![2];
  static Color getSecondaryColor(String theme) => colorSchemes[theme]![3];
  static Color getGradientStart(String theme) => colorSchemes[theme]![0];
  static Color getGradientEnd(String theme) => colorSchemes[theme]![1];
}

class SettingsService {
  static const String _settingsKey = 'quran_settings';

  static Future<QuranSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);
    if (jsonString != null) {
      final json = jsonDecode(jsonString);
      return QuranSettings.fromJson(json);
    }
    return QuranSettings();
  }

  static Future<void> saveSettings(QuranSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_settingsKey, jsonString);
  }
}

class AlQuranPage extends StatefulWidget {
  @override
  _AlQuranPageState createState() => _AlQuranPageState();
}

class _AlQuranPageState extends State<AlQuranPage> {
  List<Surah> _surahs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  List<Surah> _filteredSurahs = [];
  int _currentJuz = 1;
  QuranSettings _settings = QuranSettings();

  @override
  void initState() {
    super.initState();
    _initializeApp();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ThemeColors.getGradientEnd(_settings.themeColor),
    ));
  }

  Future<void> _initializeApp() async {
    await _loadSettings();
    await _fetchSurahs();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.loadSettings();
    setState(() {
      _settings = settings;
    });
  }

  Future<void> _fetchSurahs() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://raw.githubusercontent.com/penggguna/QuranJSON/master/quran.json'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _surahs = data.map((item) => Surah.fromJson(item)).toList();
          _filteredSurahs = _surahs;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSurahs = _surahs;
      } else {
        _filteredSurahs = _surahs.where((surah) {
          return surah.name.toLowerCase().contains(query.toLowerCase()) ||
              surah.nameTranslation.toLowerCase().contains(query.toLowerCase()) ||
              surah.englishName.toLowerCase().contains(query.toLowerCase()) ||
              surah.number.toString().contains(query);
        }).toList();
      }
    });
  }

  Widget _buildJuzSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(30, (index) {
          final juzNumber = index + 1;
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentJuz = juzNumber;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: _currentJuz == juzNumber
                    ? LinearGradient(
                        colors: [
                          ThemeColors.getPrimaryColor(_settings.themeColor),
                          ThemeColors.getSecondaryColor(_settings.themeColor),
                        ],
                      )
                    : null,
                color: _currentJuz == juzNumber
                    ? null
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                'Juz $juzNumber',
                style: TextStyle(
                  color: _currentJuz == juzNumber
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.white.withOpacity(0.05),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Container(
            margin: EdgeInsets.only(bottom: 12),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Iconsax.search_status,
                size: 48,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Surah tidak ditemukan',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Coba kata kunci lain untuk pencarian',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahList() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            ThemeColors.getGradientEnd(_settings.themeColor),
          ],
        ),
      ),
      child: ListView.builder(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.only(top: 8, bottom: 100),
        itemCount: _filteredSurahs.length,
        itemBuilder: (context, index) {
          final surah = _filteredSurahs[index];
          return _SurahCard(
            surah: surah,
            themeColor: _settings.themeColor,
            onTap: () => _navigateToSurahDetail(surah),
          );
        },
      ),
    );
  }

  void _navigateToSurahDetail(Surah surah) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SurahDetailPage(surah: surah, initialSettings: _settings),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 300),
      ),
    ).then((value) async {
      final updatedSettings = await SettingsService.loadSettings();
      setState(() {
        _settings = updatedSettings;
      });
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SettingsPage(initialSettings: _settings),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 300),
      ),
    ).then((value) async {
      if (value != null && value is QuranSettings) {
        setState(() {
          _settings = value;
        });
        await SettingsService.saveSettings(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.getGradientEnd(_settings.themeColor),
      body: NestedScrollView(
        physics: BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        ThemeColors.getGradientStart(_settings.themeColor),
                        ThemeColors.getGradientEnd(_settings.themeColor),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: MediaQuery.of(context).padding.top + 20),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assalamualaikum',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Al-Quran Digital',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _openSettings,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    margin: EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Iconsax.setting_4,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        ThemeColors.getPrimaryColor(_settings.themeColor),
                                        ThemeColors.getSecondaryColor(_settings.themeColor),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Iconsax.bookmark,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 24),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    ThemeColors.getPrimaryColor(_settings.themeColor),
                                    ThemeColors.getSecondaryColor(_settings.themeColor),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  Iconsax.play_circle,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Terakhir Dibaca',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Al-Fatihah • Ayat 1',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Iconsax.arrow_right_3,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: _buildJuzSelector(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchHeaderDelegate(
                onSearch: _onSearch,
                themeColor: _settings.themeColor,
              ),
            ),
          ];
        },
        body: _isLoading
            ? _buildLoadingState()
            : _filteredSurahs.isEmpty
                ? _buildEmptyState()
                : _buildSurahList(),
      ),
    );
  }
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Function(String) onSearch;
  final String themeColor;

  _SearchHeaderDelegate({required this.onSearch, required this.themeColor});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: ThemeColors.getGradientEnd(themeColor),
      padding: EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: TextField(
          onChanged: onSearch,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Cari surah...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            prefixIcon: Icon(
              Iconsax.search_normal,
              color: Colors.white.withOpacity(0.5),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 80;

  @override
  double get minExtent => 80;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

class _SurahCard extends StatelessWidget {
  final Surah surah;
  final String themeColor;
  final VoidCallback onTap;

  const _SurahCard({
    required this.surah,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMakkiyah = surah.revelationType == 'Makkiyah';
    final primaryColor = ThemeColors.getPrimaryColor(themeColor);
    final secondaryColor = ThemeColors.getSecondaryColor(themeColor);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withOpacity(0.05),
          highlightColor: Colors.white.withOpacity(0.02),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.03),
                  Colors.white.withOpacity(0.01),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isMakkiyah ? primaryColor : secondaryColor,
                        isMakkiyah ? primaryColor.withOpacity(0.8) : secondaryColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      surah.number.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  surah.name,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  surah.nameTranslation,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Iconsax.book_1,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '${surah.numberOfAyahs}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isMakkiyah
                                  ? primaryColor.withOpacity(0.2)
                                  : secondaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Iconsax.location,
                                  size: 12,
                                  color: isMakkiyah ? primaryColor : secondaryColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  isMakkiyah ? 'Makkiyah' : 'Madaniyah',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMakkiyah ? primaryColor : secondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              surah.englishName,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Iconsax.arrow_right_3,
                      color: Colors.white.withOpacity(0.3),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SurahDetailPage extends StatefulWidget {
  final Surah surah;
  final QuranSettings initialSettings;

  SurahDetailPage({required this.surah, required this.initialSettings});

  @override
  _SurahDetailPageState createState() => _SurahDetailPageState();
}

class _SurahDetailPageState extends State<SurahDetailPage> {
  SurahDetail? _surahDetail;
  bool _isLoading = true;
  AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  QuranSettings _settings;

  _SurahDetailPageState() : _settings = QuranSettings();

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _fetchSurahDetail();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchSurahDetail() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.alquran.cloud/v1/surah/${widget.surah.number}/editions/quran-uthmani,id.indonesian'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['code'] == 200 && data['status'] == 'OK') {
          final List<dynamic> surahData = data['data'];
          
          if (surahData.length >= 2) {
            final arabicVerses = surahData[0]['ayahs'] as List;
            final translationVerses = surahData[1]['ayahs'] as List;
            
            final verses = List<Ayah>.generate(arabicVerses.length, (index) {
              return Ayah(
                number: arabicVerses[index]['numberInSurah'],
                text: arabicVerses[index]['text'],
                translationEn: '',
                translationId: index < translationVerses.length ? translationVerses[index]['text'] : '',
              );
            });
            
            setState(() {
              _surahDetail = SurahDetail(
                surah: widget.surah,
                verses: verses,
                recitations: [
                  Recitation(
                    name: 'Mishari Rashid al-Afasy',
                    audioUrl: 'https://download.quranicaudio.com/quran/mishaari_raashid_al_3afaasee/${widget.surah.number}.mp3',
                  ),
                  Recitation(
                    name: 'Abdul Basit Abdul Samad',
                    audioUrl: 'https://download.quranicaudio.com/quran/abdul_basit_murattal/${widget.surah.number}.mp3',
                  ),
                ],
                tafsir: {},
              );
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      _loadLocalData();
    }
  }

  void _loadLocalData() {
    List<Ayah> verses = [];
    
    for (int i = 1; i <= widget.surah.numberOfAyahs; i++) {
      verses.add(Ayah(
        number: i,
        text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
        translationEn: 'Dengan nama Allah Yang Maha Pengasih, Maha Penyayang',
        translationId: 'Dengan nama Allah Yang Maha Pengasih, Maha Penyayang',
      ));
    }
    
    setState(() {
      _surahDetail = SurahDetail(
        surah: widget.surah,
        verses: verses,
        recitations: [
          Recitation(
            name: 'Mishari Rashid al-Afasy',
            audioUrl: '',
          ),
          Recitation(
            name: 'Abdul Basit Abdul Samad',
            audioUrl: '',
          ),
        ],
        tafsir: {},
      );
      _isLoading = false;
    });
  }

  Future<void> _playAudio() async {
    if (_surahDetail == null || _surahDetail!.recitations.isEmpty) return;
    
    final url = _surahDetail!.recitations[_settings.selectedReciterIndex].audioUrl;
    if (url.isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(UrlSource(url));
      }
    } catch (e) {}
  }

  void _showTafsirModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ThemeColors.getGradientStart(_settings.themeColor),
                ThemeColors.getGradientEnd(_settings.themeColor),
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tafsir ${widget.surah.name}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Kemenag RI',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            Iconsax.close_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Text(
                      'Tafsir lengkap untuk surah ${widget.surah.nameTranslation} akan tersedia dalam update berikutnya. Fitur ini sedang dalam pengembangan untuk memberikan pengalaman membaca Al-Quran yang lebih bermakna dengan penjelasan dari berbagai sumber terpercaya.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ThemeColors.getPrimaryColor(_settings.themeColor),
                  ThemeColors.getSecondaryColor(_settings.themeColor),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Memuat Surah...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeColors.getPrimaryColor(_settings.themeColor);
    final secondaryColor = ThemeColors.getSecondaryColor(_settings.themeColor);

    return Scaffold(
      backgroundColor: ThemeColors.getGradientEnd(_settings.themeColor),
      body: _isLoading
          ? _buildLoadingState()
          : Stack(
              children: [
                NestedScrollView(
                  physics: BouncingScrollPhysics(),
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverAppBar(
                        expandedHeight: 200.0,
                        floating: false,
                        pinned: true,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: Container(
                          margin: EdgeInsets.only(left: 8, top: 8),
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  Iconsax.arrow_left_2,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        actions: [
                          Container(
                            margin: EdgeInsets.only(right: 8, top: 8),
                            child: GestureDetector(
                              onTap: _showTafsirModal,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    Iconsax.info_circle,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(right: 8, top: 8),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        SettingsPage(initialSettings: _settings),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return SlideTransition(
                                        position: Tween<Offset>(
                                          begin: Offset(0, 1),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      );
                                    },
                                    transitionDuration: Duration(milliseconds: 300),
                                  ),
                                ).then((value) async {
                                  if (value != null && value is QuranSettings) {
                                    setState(() {
                                      _settings = value;
                                    });
                                    await SettingsService.saveSettings(value);
                                  }
                                });
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    Iconsax.setting_4,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(right: 16, top: 8),
                            child: GestureDetector(
                              onTap: _playAudio,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primaryColor, secondaryColor],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    _isPlaying
                                        ? Iconsax.pause
                                        : Iconsax.play,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                          collapseMode: CollapseMode.pin,
                          background: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  ThemeColors.getGradientStart(_settings.themeColor),
                                  ThemeColors.getGradientEnd(_settings.themeColor),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: MediaQuery.of(context).padding.top + 60,
                                bottom: 20,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    widget.surah.name,
                                    style: TextStyle(
                                      fontSize: 44,
                                      color: Colors.white,
                                      fontFamily: 'Amiri',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    widget.surah.nameTranslation,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Iconsax.book_1,
                                              size: 12,
                                              color: Colors.white.withOpacity(0.7),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              '${widget.surah.numberOfAyahs} Ayat',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white.withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: widget.surah.revelationType ==
                                                  'Makkiyah'
                                              ? primaryColor.withOpacity(0.2)
                                              : secondaryColor.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Iconsax.location,
                                              size: 12,
                                              color: widget.surah.revelationType ==
                                                      'Makkiyah'
                                                  ? primaryColor
                                                  : secondaryColor,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              widget.surah.revelationType,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: widget.surah.revelationType ==
                                                        'Makkiyah'
                                                    ? primaryColor
                                                    : secondaryColor,
                                              ),
                                            ),
                                          ],
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
                    ];
                  },
                  body: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          ThemeColors.getGradientEnd(_settings.themeColor),
                        ],
                      ),
                    ),
                    child: ListView.builder(
                      physics: BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: 20,
                        bottom: 100,
                        left: 20,
                        right: 20,
                      ),
                      itemCount: _surahDetail!.verses.length,
                      itemBuilder: (context, index) {
                        final ayah = _surahDetail!.verses[index];
                        return _AyahCard(
                          ayah: ayah,
                          showTranslation: _settings.showTranslation,
                          fontSize: _settings.arabicFontSize,
                          themeColor: _settings.themeColor,
                          index: index,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  final Ayah ayah;
  final bool showTranslation;
  final double fontSize;
  final String themeColor;
  final int index;

  const _AyahCard({
    required this.ayah,
    required this.showTranslation,
    required this.fontSize,
    required this.themeColor,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeColors.getPrimaryColor(themeColor);
    final secondaryColor = ThemeColors.getSecondaryColor(themeColor);

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    ayah.number.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Divider(
                  color: Colors.white.withOpacity(0.1),
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.03),
                  Colors.white.withOpacity(0.01),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ayah.text,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontFamily: 'Amiri',
                    color: Colors.white,
                    height: 1.8,
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
                if (showTranslation && ayah.translationId.isNotEmpty) ...[
                  SizedBox(height: 20),
                  Container(
                    width: 40,
                    height: 1,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  SizedBox(height: 16),
                  Text(
                    ayah.translationId,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final QuranSettings initialSettings;

  SettingsPage({required this.initialSettings});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late QuranSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  void _saveAndExit() {
    Navigator.pop(context, _settings);
  }

  Widget _buildColorOption(String colorName, Color color, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _settings.themeColor = colorName;
        });
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: isSelected
            ? Center(
                child: Icon(
                  Iconsax.tick_circle,
                  color: Colors.white,
                  size: 20,
                ),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeColors.getPrimaryColor(_settings.themeColor);
    final secondaryColor = ThemeColors.getSecondaryColor(_settings.themeColor);

    return Scaffold(
      backgroundColor: ThemeColors.getGradientEnd(_settings.themeColor),
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).padding.top + 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Iconsax.arrow_left_2,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Pengaturan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _saveAndExit,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Simpan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(20),
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.translate,
                            color: primaryColor,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Terjemahan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tampilkan Terjemahan',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16,
                            ),
                          ),
                          Switch(
                            value: _settings.showTranslation,
                            onChanged: (value) {
                              setState(() {
                                _settings.showTranslation = value;
                              });
                            },
                            activeColor: primaryColor,
                            inactiveTrackColor: Colors.white.withOpacity(0.1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.text,
                            color: primaryColor,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Teks Arab',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Ukuran Font Arab',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Aa',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _settings.arabicFontSize,
                              min: 20,
                              max: 40,
                              divisions: 10,
                              activeColor: primaryColor,
                              inactiveColor: Colors.white.withOpacity(0.1),
                              onChanged: (value) {
                                setState(() {
                                  _settings.arabicFontSize = value;
                                });
                              },
                            ),
                          ),
                          Text(
                            'Aa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_settings.arabicFontSize.toInt()}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (_settings.arabicFontSize > 20) {
                                    setState(() {
                                      _settings.arabicFontSize -= 2;
                                    });
                                  }
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Iconsax.minus,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  if (_settings.arabicFontSize < 40) {
                                    setState(() {
                                      _settings.arabicFontSize += 2;
                                    });
                                  }
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Iconsax.add,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.color_swatch,
                            color: primaryColor,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Tema',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Pilih Warna Tema',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildColorOption(
                            'blue',
                            Color(0xFF00B4D8),
                            _settings.themeColor == 'blue',
                          ),
                          _buildColorOption(
                            'green',
                            Color(0xFF00D8A8),
                            _settings.themeColor == 'green',
                          ),
                          _buildColorOption(
                            'purple',
                            Color(0xFFA855F7),
                            _settings.themeColor == 'purple',
                          ),
                          _buildColorOption(
                            'gold',
                            Color(0xFFD8B600),
                            _settings.themeColor == 'gold',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.music,
                            color: primaryColor,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Audio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Pilih Qari',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: DropdownButton<int>(
                          value: _settings.selectedReciterIndex,
                          dropdownColor: ThemeColors.getGradientStart(_settings.themeColor),
                          style: TextStyle(color: Colors.white),
                          underline: SizedBox(),
                          icon: Icon(
                            Iconsax.arrow_down_1,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          items: [
                            DropdownMenuItem<int>(
                              value: 0,
                              child: Text(
                                'Mishari Rashid al-Afasy',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem<int>(
                              value: 1,
                              child: Text(
                                'Abdul Basit Abdul Samad',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _settings.selectedReciterIndex = value!;
                            });
                          },
                        ),
                      ),
                    ],
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