import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/lite_song.dart';
import 'lite_ytm_service.dart';

/// Ultra-lightweight private in-app offline downloader for ZunifyG.
class LiteDownloadService {
  final LiteYtmService _ytm;

  LiteDownloadService(this._ytm);

  Future<Directory> _vaultDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/zunifyg_vault');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<LiteSong?> downloadSong(
    LiteSong song, {
    required String qualityTier,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final dir = await _vaultDir();
      final stream = await _ytm.resolveStream(
        song.videoId,
        qualityTier: qualityTier,
      );
      if (stream == null) return null;

      final audioPath = '${dir.path}/track_${song.videoId}.m4a';
      final req = http.Request('GET', stream.url);
      req.headers.addAll(stream.headers);

      final res = await req.send().timeout(const Duration(seconds: 25));
      if (res.statusCode >= 400) return null;

      final total = res.contentLength ?? 0;
      int received = 0;
      final file = File(audioPath);
      final sink = file.openWrite();

      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call((received / total).clamp(0.0, 0.98));
        }
      }
      await sink.flush();
      await sink.close();

      if (!await file.exists() || await file.length() < 1024) {
        return null;
      }

      onProgress?.call(1.0);
      return song.copyWith(localPath: audioPath, isDownloaded: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteSong(String videoId) async {
    try {
      final dir = await _vaultDir();
      final f = File('${dir.path}/track_$videoId.m4a');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
