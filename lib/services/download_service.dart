import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/lyric_model.dart';
import '../models/song_model.dart';
import 'lyrics_translation_service.dart';
import 'ytmusic_service.dart';

/// Zunify Private In-App Offline Downloader
/// Uses the authenticated `ResolvedAudioStream` headers (`User-Agent`) so downloads
/// from YouTube Music never get HTTP 403.
class DownloadService {
  final YTMusicService _ytMusicService;
  final LyricsTranslationService _lyricsService;

  DownloadService(this._ytMusicService, this._lyricsService);

  Future<Directory> _getVaultDir() async {
    final base = await getApplicationSupportDirectory();
    final vault = Directory(p.join(base.path, 'zunify_private_vault'));
    if (!await vault.exists()) {
      await vault.create(recursive: true);
    }
    return vault;
  }

  Future<ZunifySong?> downloadSongToPrivateVault(
    ZunifySong song, {
    required bool highQuality,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final vaultDir = await _getVaultDir();
      // Always download in High Quality ('high') automatically
      final resolvedStream = await _ytMusicService.resolveAudioStream(
        song.videoId,
        highQuality: true,
        qualityTier: 'high',
      );
      if (resolvedStream == null) return null;

      final audioPath = p.join(vaultDir.path, 'track_${song.videoId}.m4a');
      final artPath = p.join(vaultDir.path, 'art_${song.videoId}.jpg');
      final lyricsPath = p.join(vaultDir.path, 'lyrics_${song.videoId}.json');

      // 1. Stream and save audio file with matching client User-Agent header
      final request = http.Request('GET', resolvedStream.url);
      request.headers.addAll(resolvedStream.headers);

      final streamedResponse = await request.send();
      if (streamedResponse.statusCode >= 400) return null;

      final totalBytes = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;

      final audioFile = File(audioPath);
      final sink = audioFile.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call((receivedBytes / totalBytes).clamp(0.0, 0.95));
        }
      }
      await sink.flush();
      await sink.close();

      // 2. Cache high-res album art locally
      String? savedArtPath;
      try {
        final artRes = await http
            .get(Uri.parse(song.highResArtUrl))
            .timeout(const Duration(seconds: 8));
        if (artRes.statusCode == 200) {
          final artFile = File(artPath);
          await artFile.writeAsBytes(artRes.bodyBytes);
          savedArtPath = artPath;
        }
      } catch (_) {}

      // 3. Cache synced + translated lyrics locally
      try {
        final syncedLyrics = await _lyricsService.fetchSyncedBilingualLyrics(song);
        final lyricsFile = File(lyricsPath);
        await lyricsFile.writeAsString(jsonEncode(syncedLyrics.toJson()));
      } catch (_) {}

      onProgress?.call(1.0);

      return song.copyWith(
        localFilePath: audioPath,
        localArtPath: savedArtPath,
        isDownloaded: true,
        audioBitrateKbps: resolvedStream.bitrateKbps,
      );
    } catch (_) {
      return null;
    }
  }

  Future<SyncedLyrics?> getOfflineCachedLyrics(String videoId) async {
    try {
      final vaultDir = await _getVaultDir();
      final lyricsFile = File(p.join(vaultDir.path, 'lyrics_$videoId.json'));
      if (await lyricsFile.exists()) {
        final raw = await lyricsFile.readAsString();
        return SyncedLyrics.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<void> deleteDownloadedSong(String videoId) async {
    try {
      final vaultDir = await _getVaultDir();
      for (final name in [
        'track_$videoId.m4a',
        'art_$videoId.jpg',
        'lyrics_$videoId.json',
      ]) {
        final f = File(p.join(vaultDir.path, name));
        if (await f.exists()) {
          await f.delete();
        }
      }
    } catch (_) {}
  }
}
