import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_version.dart';

class UpdateInfo {
  final String version;
  final String changelog;
  final String apkUrl;
  final String apkName;
  final int apkSizeBytes;
  final String releasePageUrl;
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.version,
    required this.changelog,
    required this.apkUrl,
    required this.apkName,
    required this.apkSizeBytes,
    required this.releasePageUrl,
    this.publishedAt,
  });

  String get sizeLabel {
    if (apkSizeBytes <= 0) return '';
    return '${(apkSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Serverless in-app updater & system status-bar notification service
/// powered by GitHub Releases & `announcements.json`.
class UpdateService {
  static const MethodChannel _nativeChannel =
      MethodChannel('com.fannz.zunify/equalizer');
  static const _prefLastCheck = 'update_last_check_ms';
  static const _prefSkipped = 'update_skipped_version';
  static const _prefCachedJson = 'update_cached_release_json';
  static const Duration _throttle = Duration(hours: 6);

  static final FlutterLocalNotificationsPlugin _notifPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _notifInitialized = false;

  static Future<void> _ensureNotifInitialized() async {
    if (_notifInitialized) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notifPlugin.initialize(initSettings);
      await _notifPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _notifInitialized = true;
    } catch (_) {}
  }

  /// Displays a system status-bar notification on the phone with sound & vibration.
  /// Supports optional [imageUrl] or [localImagePath].
  static Future<void> showSystemPushNotification({
    required int id,
    required String title,
    required String body,
    String? imageUrl,
    String? localImagePath,
  }) async {
    try {
      final ok = await _nativeChannel.invokeMethod<bool>(
        'showNativePushNotification',
        {
          'id': id,
          'title': title,
          'body': body,
          'imageUrl': imageUrl ?? '',
          'localImagePath': localImagePath ?? '',
        },
      );
      if (ok == true) return;
    } catch (_) {}

    try {
      await _ensureNotifInitialized();
      String? resolvedImgPath = localImagePath;
      if ((resolvedImgPath == null || resolvedImgPath.isEmpty) &&
          imageUrl != null &&
          imageUrl.trim().isNotEmpty) {
        try {
          final res = await http
              .get(Uri.parse(imageUrl.trim()))
              .timeout(const Duration(seconds: 6));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            final dir = await getTemporaryDirectory();
            final f = File('${dir.path}/notif_img_$id.jpg');
            await f.writeAsBytes(res.bodyBytes, flush: true);
            resolvedImgPath = f.path;
          }
        } catch (_) {}
      }

      StyleInformation styleInfo = BigTextStyleInformation(
        body,
        contentTitle: title,
      );
      AndroidBitmap<Object>? largeIconBmp;

      if (resolvedImgPath != null &&
          resolvedImgPath.isNotEmpty &&
          await File(resolvedImgPath).exists()) {
        final bmp = FilePathAndroidBitmap(resolvedImgPath);
        largeIconBmp = bmp;
        styleInfo = BigPictureStyleInformation(
          bmp,
          largeIcon: bmp,
          contentTitle: title,
          summaryText: body,
          hideExpandedLargeIcon: true,
        );
      }

      final androidDetails = AndroidNotificationDetails(
        'zunify_broadcast_sound_v3',
        'Notifikasi Zunify',
        channelDescription: 'Notifikasi informasi resmi Zunify',
        icon: '@drawable/ic_stat_zunify',
        largeIcon: largeIconBmp,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        styleInformation: styleInfo,
      );
      final details = NotificationDetails(android: androidDetails);
      await _notifPlugin.show(id, title, body, details);
    } catch (_) {}
  }

  static Future<Map<String, String>?> pickImageFromGallery() async {
    try {
      final res = await _nativeChannel.invokeMethod('pickImageFromGallery');
      if (res is Map) {
        return {
          'path': (res['path'] ?? '').toString(),
          'base64': (res['base64'] ?? '').toString(),
        };
      }
    } catch (_) {}
    return null;
  }

  static Future<void> openExternalUrl(String url) async {
    try {
      await _nativeChannel.invokeMethod('openExternalUrl', {'url': url});
    } catch (_) {}
  }

  /// Returns an [UpdateInfo] when a newer version exists for the built-in in-app UpdateSheet.
  /// Never pushes an automatic OS notification (in-app update prompt only).
  Future<UpdateInfo?> checkForUpdate({bool manual = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastCheck = prefs.getInt(_prefLastCheck) ?? 0;

    Map<String, dynamic>? release;

    final throttled = !manual && now - lastCheck < _throttle.inMilliseconds;
    if (throttled) {
      final cached = prefs.getString(_prefCachedJson);
      if (cached != null) {
        try {
          release = jsonDecode(cached) as Map<String, dynamic>;
        } catch (_) {}
      }
    } else {
      try {
        final res = await http
            .get(
              Uri.parse(
                'https://api.github.com/repos/$kUpdateRepo/releases/latest',
              ),
              headers: const {
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'Zunify-Updater',
              },
            )
            .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          release =
              jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          await prefs.setString(_prefCachedJson, jsonEncode(_slim(release)));
          await prefs.setInt(_prefLastCheck, now);
        }
      } catch (_) {
        if (manual) rethrow;
      }
    }

    if (release == null) return null;
    final info = _parseRelease(release);
    if (info == null) return null;
    if (!isNewer(info.version, kAppVersion)) return null;

    if (!manual && prefs.getString(_prefSkipped) == info.version) return null;

    return info;
  }

  /// Triggers the native Android notification engine to check `announcements.json`
  /// and post ONLY to the phone's system notification bar (never inside the app).
  Future<void> checkBroadcastAnnouncement() async {
    try {
      await _nativeChannel.invokeMethod('checkBroadcastNative');
    } catch (_) {}
  }

  /// Fire-and-forget publisher for Fannz's Zunify Notif Admin APK.
  /// Sends title + message + optional local phone gallery image once with zero history.
  Future<bool> publishBroadcastAnnouncement({
    required String title,
    required String message,
    String? imageBase64,
    required String githubToken,
  }) async {
    final cleanToken = githubToken.trim();
    if (cleanToken.isEmpty) return false;

    final headers = {
      'Authorization': 'Bearer $cleanToken',
      'Accept': 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'User-Agent': 'Zunify-Admin-Fannz',
    };

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final notifId = 'fannz_$nowMs';
    String finalImageUrl = '';

    // Upload local gallery image if selected
    if (imageBase64 != null && imageBase64.trim().isNotEmpty) {
      final imgPath = 'announcements/$notifId.jpg';
      final imgApiUri = Uri.parse(
        'https://api.github.com/repos/$kUpdateRepo/contents/$imgPath',
      );
      final imgPutRes = await http
          .put(
            imgApiUri,
            headers: headers,
            body: jsonEncode({
              'message':
                  'chore(broadcast): upload notif image $notifId [skip ci]',
              'content': imageBase64.trim(),
            }),
          )
          .timeout(const Duration(seconds: 18));
      if (imgPutRes.statusCode == 200 || imgPutRes.statusCode == 201) {
        finalImageUrl =
            'https://raw.githubusercontent.com/$kUpdateRepo/main/$imgPath';
      }
    }

    final apiUri = Uri.parse(
      'https://api.github.com/repos/$kUpdateRepo/contents/announcements.json',
    );

    String? existingSha;
    try {
      final getRes = await http
          .get(apiUri, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (getRes.statusCode == 200) {
        final meta =
            jsonDecode(utf8.decode(getRes.bodyBytes)) as Map<String, dynamic>;
        existingSha = meta['sha']?.toString();
      }
    } catch (_) {}

    final newPayload = <String, dynamic>{
      'id': notifId,
      'active': true,
      'title': title.trim().isEmpty ? 'Zunify' : title.trim(),
      'message': message.trim(),
      'imageUrl': finalImageUrl,
      'createdAtMs': nowMs,
      'createdAt':
          DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true)
              .toIso8601String(),
    };

    final jsonBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(newPayload),
    );
    final body = <String, dynamic>{
      'message': 'chore(broadcast): push notification from Fannz [skip ci]',
      'content': base64Encode(jsonBytes),
      if (existingSha != null) 'sha': existingSha,
    };

    final putRes = await http
        .put(apiUri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 12));
    return putRes.statusCode == 200 || putRes.statusCode == 201;
  }

  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSkipped, version);
  }

  /// Downloads the APK with progress (0..1). Returns the local file path.
  Future<String> downloadApk(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/zunify-update-${info.version}.apk');
    if (await file.exists() &&
        info.apkSizeBytes > 0 &&
        await file.length() == info.apkSizeBytes) {
      onProgress?.call(1);
      return file.path;
    }

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(info.apkUrl));
      final res = await client.send(req).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        throw Exception('Download gagal (HTTP ${res.statusCode})');
      }
      final total = res.contentLength ?? info.apkSizeBytes;
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
      }
      await sink.flush();
      await sink.close();
      return file.path;
    } finally {
      client.close();
    }
  }

  /// Opens the Android package installer for the downloaded APK via native FileProvider.
  Future<bool> installApk(String path) async {
    try {
      final ok = await _nativeChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': path},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static bool isNewer(String remote, String local) {
    final r = _parts(remote);
    final l = _parts(local);
    for (int i = 0; i < 3; i++) {
      if (r[i] != l[i]) return r[i] > l[i];
    }
    return false;
  }

  static List<int> _parts(String v) {
    final clean = v.replaceAll(RegExp(r'[^0-9.]'), '');
    final p = clean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (p.length < 3) {
      p.add(0);
    }
    return p.take(3).toList();
  }

  Map<String, dynamic> _slim(Map<String, dynamic> r) => {
        'tag_name': r['tag_name'],
        'body': r['body'],
        'html_url': r['html_url'],
        'published_at': r['published_at'],
        'assets': ((r['assets'] as List<dynamic>?) ?? [])
            .map((a) => {
                  'name': (a as Map<String, dynamic>)['name'],
                  'size': a['size'],
                  'browser_download_url': a['browser_download_url'],
                })
            .toList(),
      };

  UpdateInfo? _parseRelease(Map<String, dynamic> r) {
    final tag = (r['tag_name'] ?? '').toString();
    if (tag.isEmpty) return null;
    final assets = ((r['assets'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>()
        .where((a) => (a['name'] ?? '').toString().endsWith('.apk'))
        .toList();
    if (assets.isEmpty) return null;

    final isArm64 = Platform.version.contains('arm64');
    Map<String, dynamic>? pick;
    if (isArm64) {
      pick = assets.firstWhere(
        (a) => a['name'].toString().contains('Lite-arm64'),
        orElse: () => <String, dynamic>{},
      );
    }
    if (pick == null || pick.isEmpty) {
      pick = assets.firstWhere(
        (a) => a['name'].toString().contains('Universal'),
        orElse: () => assets.first,
      );
    }

    return UpdateInfo(
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      changelog: (r['body'] ?? '').toString().trim(),
      apkUrl: pick['browser_download_url'].toString(),
      apkName: pick['name'].toString(),
      apkSizeBytes: (pick['size'] as num?)?.toInt() ?? 0,
      releasePageUrl: (r['html_url'] ?? '').toString(),
      publishedAt: DateTime.tryParse((r['published_at'] ?? '').toString()),
    );
  }
}
