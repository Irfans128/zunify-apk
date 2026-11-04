import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
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

/// Serverless in-app updater powered by GitHub Releases.
///
/// Performance: the check never blocks app startup. It runs in the background
/// a few seconds after the UI is shown, has a short timeout, and is throttled
/// to once every 6 hours (manual "Cek Update" ignores the throttle).
class UpdateService {
  static const MethodChannel _nativeChannel =
      MethodChannel('com.fannz.zunify/equalizer');
  static const _prefLastCheck = 'update_last_check_ms';
  static const _prefSkipped = 'update_skipped_version';
  static const _prefCachedJson = 'update_cached_release_json';
  static const Duration _throttle = Duration(hours: 6);

  /// Returns an [UpdateInfo] when a newer version exists, otherwise null.
  /// When [manual] is false, skipped versions are hidden and the throttle applies.
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
