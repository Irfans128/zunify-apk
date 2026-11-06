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

/// Standalone Unlimited Playlist Importer for Zunify (Spotify & YouTube Music)
/// Supports importing 200, 500, or 1000+ tracks from public Spotify & YouTube Music playlists.
class PlaylistImporterService {
  final YTMusicService _ytMusicService;

  static const String _spotifyPathfinderUrl =
      'https://api-partner.spotify.com/pathfinder/v1/query';
  static const String _fetchPlaylistContentsHash =
      'cd2275433b29f7316176e7b5b5e098ae7744724e1a52d63549c76636b3257749';

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
    onProgress?.call(1, 2, 'Mengambil seluruh lagu dari YouTube Music...');

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

    onProgress?.call(0, 1, 'Membaca daftar lagu playlist Spotify...');

    final response = await http.get(
      Uri.parse(embedUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Pastikan playlist Spotify disetel ke Public.');
    }

    final html = utf8.decode(response.bodyBytes);
    String playlistTitle = 'Spotify Playlist';
    String? coverUrl;
    String? accessToken;
    final rawTrackEntries = <Map<String, String>>[];

    final nextDataMatch = RegExp(
      r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);

    if (nextDataMatch != null) {
      try {
        final jsonMap =
            jsonDecode(nextDataMatch.group(1)!) as Map<String, dynamic>;
        final state =
            jsonMap['props']?['pageProps']?['state'] as Map<String, dynamic>?;
        accessToken =
            state?['settings']?['session']?['accessToken']?.toString();
        final entity = state?['data']?['entity'] as Map<String, dynamic>?;

        if (entity != null) {
          playlistTitle =
              (entity['name'] ?? entity['title'] ?? 'Spotify Playlist')
                  .toString();
          final coverVisual = entity['coverArt']?['sources'] as List<dynamic>?;
          if (coverVisual != null && coverVisual.isNotEmpty) {
            coverUrl =
                (coverVisual.first as Map<String, dynamic>)['url'] as String?;
          }

          // Extract ALL tracks from initial embed list (no 60-track limit!)
          final trackList = entity['trackList'] as List<dynamic>? ?? [];
          for (final item in trackList) {
            final tMap = item as Map<String, dynamic>;
            final title = (tMap['title'] ?? '').toString().trim();
            final subtitle = (tMap['subtitle'] ?? '')
                .toString()
                .replaceAll('\u00A0', ' ')
                .trim();
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

    // If playlist has >= 100 tracks, paginate Spotify's Pathfinder GraphQL API
    // (`fetchPlaylistContents`) to fetch ALL remaining tracks (200, 500, 1000+ songs!)
    if (rawTrackEntries.length >= 100 &&
        accessToken != null &&
        accessToken.isNotEmpty) {
      int offset = rawTrackEntries.length;
      const int pageSize = 100;

      while (offset < 2000) {
        try {
          onProgress?.call(
            0,
            1,
            'Mengambil halaman lagu Spotify (${rawTrackEntries.length}+ lagu)...',
          );
          final bodyPayload = jsonEncode({
            'variables': {
              'uri': 'spotify:playlist:$spotifyPlaylistId',
              'offset': offset,
              'limit': pageSize,
            },
            'operationName': 'fetchPlaylistContents',
            'extensions': {
              'persistedQuery': {
                'version': 1,
                'sha256Hash': _fetchPlaylistContentsHash,
              },
            },
          });

          final pageRes = await http
              .post(
                Uri.parse(_spotifyPathfinderUrl),
                headers: {
                  'Authorization': 'Bearer $accessToken',
                  'Content-Type': 'application/json',
                  'App-Platform': 'WebPlayer',
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                },
                body: bodyPayload,
              )
              .timeout(const Duration(seconds: 12));

          if (pageRes.statusCode != 200) break;

          final pageJson =
              jsonDecode(utf8.decode(pageRes.bodyBytes)) as Map<String, dynamic>;
          final content = pageJson['data']?['playlistV2']?['content']
              as Map<String, dynamic>?;
          if (content == null) break;

          final totalCount = (content['totalCount'] as num?)?.toInt() ?? 0;
          final items = content['items'] as List<dynamic>? ?? [];
          if (items.isEmpty) break;

          int addedInPage = 0;
          for (final rawItem in items) {
            final itemMap = rawItem as Map<String, dynamic>;
            final trackData =
                itemMap['itemV2']?['data'] as Map<String, dynamic>?;
            if (trackData == null) continue;

            final title = (trackData['name'] ?? '').toString().trim();
            if (title.isEmpty) continue;

            String artist = '';
            final artistItems =
                trackData['artists']?['items'] as List<dynamic>?;
            if (artistItems != null && artistItems.isNotEmpty) {
              artist = artistItems
                  .map(
                    (a) =>
                        ((a as Map<String, dynamic>)['profile']?['name'] ?? '')
                            .toString()
                            .trim(),
                  )
                  .where((n) => n.isNotEmpty)
                  .join(', ');
            }

            rawTrackEntries.add({
              'title': title,
              'artist': artist,
              'query': '$title $artist'.trim(),
            });
            addedInPage++;
          }

          offset += items.length;
          if (addedInPage == 0 ||
              items.length < pageSize ||
              (totalCount > 0 && offset >= totalCount)) {
            break;
          }
        } catch (_) {
          break;
        }
      }
    }

    if (rawTrackEntries.isEmpty) {
      throw Exception(
        'Tidak dapat membaca lagu. Pastikan playlist Spotify berstatus Public.',
      );
    }

    // Resolve tracks in parallel batches of 10 for fast unlimited import while preserving order
    final List<ZunifySong?> orderedResults =
        List<ZunifySong?>.filled(rawTrackEntries.length, null);
    const int batchSize = 10;
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
            final searchRes = await _ytMusicService
                .searchSongs(query, limit: 1)
                .timeout(const Duration(seconds: 7));
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
