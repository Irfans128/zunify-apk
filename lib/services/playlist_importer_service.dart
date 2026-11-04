import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import 'ytmusic_service.dart';

typedef ImportProgressCallback = void Function(int current, int total, String currentTrackName);

/// Standalone Playlist Importer for Zunify (No Login Required!)
/// Supports:
/// 1. Spotify Public Playlist Links (`https://open.spotify.com/playlist/...`)
/// 2. YouTube Music & YouTube Playlist Links (`https://music.youtube.com/playlist?list=...`)
class PlaylistImporterService {
  final YoutubeExplode _yt = YoutubeExplode();
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
    throw Exception('Link tidak dikenali. Gunakan link playlist Spotify atau YouTube Music.');
  }

  /// Extracts tracks from a public YouTube / YouTube Music playlist
  Future<ZunifyPlaylist> _importYouTubePlaylist(
    String url, {
    ImportProgressCallback? onProgress,
  }) async {
    final playlist = await _yt.playlists.get(url);
    final videos = await _yt.playlists.getVideos(playlist.id).take(50).toList();

    final songs = <ZunifySong>[];
    for (int i = 0; i < videos.length; i++) {
      final v = videos[i];
      onProgress?.call(i + 1, videos.length, v.title);

      songs.add(
        ZunifySong(
          videoId: v.id.value,
          title: v.title,
          artist: v.author.replaceAll(' - Topic', '').trim(),
          album: playlist.title,
          durationSeconds: v.duration?.inSeconds ?? 210,
          thumbnailUrl: v.thumbnails.mediumResUrl,
          highResArtUrl: v.thumbnails.highResUrl,
          addedAt: DateTime.now(),
        ),
      );
    }

    return ZunifyPlaylist(
      id: 'yt_${playlist.id.value}_${DateTime.now().millisecondsSinceEpoch}',
      name: playlist.title,
      description: playlist.description.isNotEmpty
          ? playlist.description
          : 'Diimpor dari YouTube Music (${songs.length} lagu)',
      coverUrl: songs.isNotEmpty ? songs.first.highResArtUrl : null,
      origin: PlaylistOrigin.youtubeMusicImport,
      sourceUrl: url,
      songs: songs,
      createdAt: DateTime.now(),
    );
  }

  /// Extracts track titles & artists from a public Spotify Playlist embed page
  /// without needing a Spotify account or API key, then matches each song on YouTube Music!
  Future<ZunifyPlaylist> _importSpotifyPublicPlaylist(
    String url, {
    ImportProgressCallback? onProgress,
  }) async {
    final match = RegExp(r'playlist/([a-zA-Z0-9]+)').firstMatch(url);
    if (match == null) {
      throw Exception('Format link playlist Spotify tidak valid.');
    }
    final spotifyPlaylistId = match.group(1)!;
    final embedUrl = 'https://open.spotify.com/embed/playlist/$spotifyPlaylistId';

    final response = await http.get(
      Uri.parse(embedUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('Gagal mengakses playlist Spotify. Pastikan playlist berstatus Public.');
    }

    final html = utf8.decode(response.bodyBytes);
    String playlistTitle = 'Spotify Playlist';
    String? coverUrl;
    final rawTrackQueries = <String>[];

    // Parse __NEXT_DATA__ JSON inside Spotify's public embed HTML
    final nextDataMatch = RegExp(
      r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);

    if (nextDataMatch != null) {
      try {
        final jsonMap = jsonDecode(nextDataMatch.group(1)!) as Map<String, dynamic>;
        final entity = jsonMap['props']?['pageProps']?['state']?['data']?['entity']
            as Map<String, dynamic>?;

        if (entity != null) {
          playlistTitle = (entity['name'] ?? entity['title'] ?? 'Spotify Playlist').toString();
          final coverVisual = entity['coverArt']?['sources'] as List<dynamic>?;
          if (coverVisual != null && coverVisual.isNotEmpty) {
            coverUrl = (coverVisual.first as Map<String, dynamic>)['url'] as String?;
          }

          final trackList = entity['trackList'] as List<dynamic>? ?? [];
          for (final item in trackList.take(35)) {
            final tMap = item as Map<String, dynamic>;
            final title = (tMap['title'] ?? '').toString().trim();
            final subtitle = (tMap['subtitle'] ?? '').toString().trim();
            if (title.isNotEmpty) {
              rawTrackQueries.add('$subtitle - $title');
            }
          }
        }
      } catch (_) {}
    }

    if (rawTrackQueries.isEmpty) {
      throw Exception(
        'Tidak menemukan daftar lagu. Pastikan playlist Spotify disetel ke Public.',
      );
    }

    final matchedSongs = <ZunifySong>[];
    for (int i = 0; i < rawTrackQueries.length; i++) {
      final query = rawTrackQueries[i];
      onProgress?.call(i + 1, rawTrackQueries.length, query);

      final searchRes = await _ytMusicService.searchSongs(query, limit: 1);
      if (searchRes.isNotEmpty) {
        matchedSongs.add(searchRes.first);
      }
    }

    return ZunifyPlaylist(
      id: 'sp_${spotifyPlaylistId}_${DateTime.now().millisecondsSinceEpoch}',
      name: playlistTitle,
      description: 'Diimpor dari Spotify (${matchedSongs.length} lagu dicocokkan)',
      coverUrl: coverUrl ?? (matchedSongs.isNotEmpty ? matchedSongs.first.highResArtUrl : null),
      origin: PlaylistOrigin.spotifyImport,
      sourceUrl: url,
      songs: matchedSongs,
      createdAt: DateTime.now(),
    );
  }
}
