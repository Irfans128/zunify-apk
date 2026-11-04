import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import 'ytmusic_service.dart';

typedef ImportProgressCallback = void Function(
  int current,
  int total,
  String currentTrackName,
);

/// Standalone Playlist Importer for Zunify (Spotify & YouTube Music)
class PlaylistImporterService {
  final YTMusicService _ytMusicService;

  PlaylistImporterService(this._ytMusicService);

  Future<ZunifyPlaylist?> importFromUrl(
    String rawUrl, {
    ImportProgressCallback? onProgress,
  }) async {
    final url = rawUrl.trim();
    if (url.contains('spotify.com')) {
      return _importSpotifyPublicPlaylist(url, onProgress: onProgress);
    } else if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return _importYouTubePlaylist(url, onProgress: onProgress);
    }
    throw Exception('Gunakan link playlist publik Spotify atau YouTube Music.');
  }

  Future<ZunifyPlaylist> _importYouTubePlaylist(
    String url, {
    ImportProgressCallback? onProgress,
  }) async {
    final listMatch = RegExp(r'list=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (listMatch == null) {
      throw Exception('Link playlist YouTube Music tidak valid.');
    }
    final playlistId = listMatch.group(1)!;
    onProgress?.call(1, 2, 'Mengambil daftar lagu dari YouTube Music...');

    final songs = await _ytMusicService.fetchYouTubePlaylistTracks(playlistId);
    if (songs.isEmpty) {
      throw Exception('Playlist kosong atau berstatus Private.');
    }

    onProgress?.call(2, 2, 'Selesai (${songs.length} lagu)');
    return ZunifyPlaylist(
      id: 'yt_${playlistId}_${DateTime.now().millisecondsSinceEpoch}',
      name: 'YT Music Playlist',
      description: '${songs.length} lagu • YouTube Music',
      coverUrl: songs.first.highResArtUrl,
      origin: PlaylistOrigin.youtubeMusicImport,
      sourceUrl: url,
      songs: songs,
      createdAt: DateTime.now(),
    );
  }

  Future<ZunifyPlaylist> _importSpotifyPublicPlaylist(
    String url, {
    ImportProgressCallback? onProgress,
  }) async {
    final match = RegExp(r'playlist/([a-zA-Z0-9]+)').firstMatch(url);
    if (match == null) {
      throw Exception('Link playlist Spotify tidak valid.');
    }
    final spotifyPlaylistId = match.group(1)!;
    final embedUrl = 'https://open.spotify.com/embed/playlist/$spotifyPlaylistId';

    final response = await http.get(
      Uri.parse(embedUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      },
    ).timeout(const Duration(seconds: 14));

    if (response.statusCode != 200) {
      throw Exception('Pastikan playlist Spotify disetel ke Public.');
    }

    final html = utf8.decode(response.bodyBytes);
    String playlistTitle = 'Spotify Playlist';
    String? coverUrl;
    final rawTrackEntries = <Map<String, String>>[];

    final nextDataMatch = RegExp(
      r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);

    if (nextDataMatch != null) {
      try {
        final jsonMap =
            jsonDecode(nextDataMatch.group(1)!) as Map<String, dynamic>;
        final entity = jsonMap['props']?['pageProps']?['state']?['data']
            ?['entity'] as Map<String, dynamic>?;

        if (entity != null) {
          playlistTitle =
              (entity['name'] ?? entity['title'] ?? 'Spotify Playlist')
                  .toString();
          final coverVisual = entity['coverArt']?['sources'] as List<dynamic>?;
          if (coverVisual != null && coverVisual.isNotEmpty) {
            coverUrl =
                (coverVisual.first as Map<String, dynamic>)['url'] as String?;
          }

          final trackList = entity['trackList'] as List<dynamic>? ?? [];
          for (final item in trackList.take(60)) {
            final tMap = item as Map<String, dynamic>;
            final title = (tMap['title'] ?? '').toString().trim();
            final subtitle = (tMap['subtitle'] ?? '').toString().trim();
            if (title.isNotEmpty) {
              rawTrackEntries.add({
                'title': title,
                'artist': subtitle,
                'query': '$title $subtitle'.trim(),
              });
            }
          }
        }
      } catch (_) {}
    }

    if (rawTrackEntries.isEmpty) {
      throw Exception(
        'Tidak dapat membaca lagu. Pastikan playlist Spotify berstatus Public.',
      );
    }

    // Resolve tracks in parallel batches of 5 for fast import while preserving order
    final List<ZunifySong?> orderedResults =
        List<ZunifySong?>.filled(rawTrackEntries.length, null);
    const int batchSize = 5;
    int completedCount = 0;

    for (int start = 0; start < rawTrackEntries.length; start += batchSize) {
      final end = (start + batchSize < rawTrackEntries.length)
          ? start + batchSize
          : rawTrackEntries.length;

      final futures = <Future<void>>[];
      for (int idx = start; idx < end; idx++) {
        final entry = rawTrackEntries[idx];
        final query = entry['query']!;
        final displayTitle = '${entry['title']} - ${entry['artist']}';

        futures.add(() async {
          try {
            final searchRes =
                await _ytMusicService.searchSongs(query, limit: 1);
            if (searchRes.isNotEmpty) {
              orderedResults[idx] = searchRes.first;
            }
          } catch (_) {}
          completedCount++;
          onProgress?.call(
            completedCount,
            rawTrackEntries.length,
            displayTitle,
          );
        }());
      }
      await Future.wait(futures);
    }

    final matchedSongs = orderedResults.whereType<ZunifySong>().toList();

    return ZunifyPlaylist(
      id: 'sp_${spotifyPlaylistId}_${DateTime.now().millisecondsSinceEpoch}',
      name: playlistTitle,
      description: '${matchedSongs.length} lagu • Spotify Import',
      coverUrl: coverUrl ??
          (matchedSongs.isNotEmpty ? matchedSongs.first.highResArtUrl : null),
      origin: PlaylistOrigin.spotifyImport,
      sourceUrl: url,
      songs: matchedSongs,
      createdAt: DateTime.now(),
    );
  }
}
