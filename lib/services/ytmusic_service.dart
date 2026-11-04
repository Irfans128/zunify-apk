import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/song_model.dart';

class ResolvedAudioStream {
  final Uri url;
  final Uri? hlsUrl;
  final Map<String, String> headers;
  final int bitrateKbps;
  final String mimeType;
  final int contentLength;

  const ResolvedAudioStream({
    required this.url,
    this.hlsUrl,
    required this.headers,
    required this.bitrateKbps,
    required this.mimeType,
    this.contentLength = 0,
  });
}

class _CachedStreamEntry {
  final ResolvedAudioStream stream;
  final DateTime expiresAt;
  const _CachedStreamEntry(this.stream, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

/// Zunify v1.2 Direct YouTube Music (`WEB_REMIX`) + `VISIONOS` (`AusDMusic` NewPipe/SmartTube)
/// InnerTube Audio Stream Engine.
/// Verified HTTP 200/206 ExoPlayer playback without PoToken/403 blocks or login.
class YTMusicService {
  static const String _ytmSearchUrl =
      'https://music.youtube.com/youtubei/v1/search?prettyPrint=false';
  static const String _ytmNextUrl =
      'https://music.youtube.com/youtubei/v1/next?prettyPrint=false';
  static const String _ytmBrowseUrl =
      'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false';
  static const String _ytVisionOsPlayerBaseUrl =
      'https://youtubei.googleapis.com/youtubei/v1/player?prettyPrint=false';
  static const String _swJsDataUrl = 'https://www.youtube.com/sw.js_data';

  static const String _alphaNumChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  final Random _random = Random();
  final http.Client _http = http.Client();

  String? _cachedVisitorData;
  DateTime? _visitorDataFetchedAt;

  final Map<String, _CachedStreamEntry> _streamCache = {};
  final Map<String, List<ZunifySong>> _searchCache = {};

  String _generateRandomToken(int length) {
    final sb = StringBuffer();
    for (int i = 0; i < length; i++) {
      sb.write(_alphaNumChars[_random.nextInt(_alphaNumChars.length)]);
    }
    return sb.toString();
  }

  void _captureVisitorDataFromResponse(Map<String, dynamic> data) {
    final token = data['responseContext']?['visitorData']?.toString();
    if (token != null && token.isNotEmpty) {
      _cachedVisitorData = token;
      _visitorDataFetchedAt = DateTime.now();
    }
  }

  /// Fetches fresh `visitorData` token from YouTube `sw.js_data` or cached responseContext
  Future<String?> _getVisitorData() async {
    if (_cachedVisitorData != null &&
        _visitorDataFetchedAt != null &&
        DateTime.now().difference(_visitorDataFetchedAt!).inMinutes < 45) {
      return _cachedVisitorData;
    }
    try {
      final res = await _http.get(
        Uri.parse(_swJsDataUrl),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        String raw = utf8.decode(res.bodyBytes);
        if (raw.startsWith(")]}'")) {
          raw = raw.substring(4);
        }
        final decoded = jsonDecode(raw) as List<dynamic>;
        final token = decoded[0][2][0][0][13]?.toString();
        if (token != null && token.isNotEmpty) {
          _cachedVisitorData = token;
          _visitorDataFetchedAt = DateTime.now();
          return token;
        }
      }
    } catch (_) {}
    return _cachedVisitorData;
  }

  /// Searches genuine YouTube Music Songs via `WEB_REMIX` (`ytmusicapi` protocol)
  Future<List<ZunifySong>> searchSongs(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final cacheKey = '${trimmed.toLowerCase()}_$limit';
    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    try {
      final payload = {
        'query': trimmed,
        // Official YouTube Music "Songs" filter param
        'params': 'EgWKAQIIAWoKEAkQBRAKEAMQBA==',
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20250101.01.00',
            'hl': 'id',
            'gl': 'ID',
          },
        },
      };

      final res = await _http
          .post(
            Uri.parse(_ytmSearchUrl),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Origin': 'https://music.youtube.com',
              'Referer': 'https://music.youtube.com/',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      _captureVisitorDataFromResponse(data);
      final songs = _parseWebRemixSearchItems(data, limit: limit);
      if (songs.isNotEmpty) {
        if (_searchCache.length > 60) {
          _searchCache.remove(_searchCache.keys.first);
        }
        _searchCache[cacheKey] = songs;
      }
      return songs;
    } catch (_) {
      return [];
    }
  }

  List<ZunifySong> _parseWebRemixSearchItems(
    Map<String, dynamic> data, {
    required int limit,
  }) {
    final songs = <ZunifySong>[];
    try {
      final tabs = data['contents']?['tabbedSearchResultsRenderer']?['tabs']
          as List<dynamic>?;
      if (tabs == null || tabs.isEmpty) return [];

      final sections = tabs[0]['tabRenderer']?['content']?['sectionListRenderer']
          ?['contents'] as List<dynamic>?;
      if (sections == null) return [];

      for (final sec in sections) {
        final shelf = (sec as Map<String, dynamic>)['musicShelfRenderer']
            as Map<String, dynamic>?;
        if (shelf == null) continue;

        final contents = shelf['contents'] as List<dynamic>? ?? [];
        for (final rawItem in contents) {
          final item = (rawItem as Map<String, dynamic>)['musicResponsiveListItemRenderer']
              as Map<String, dynamic>?;
          if (item == null) continue;

          final videoId = item['playlistItemData']?['videoId']?.toString();
          if (videoId == null || videoId.isEmpty) continue;

          final flexCols = item['flexColumns'] as List<dynamic>? ?? [];
          if (flexCols.isEmpty) continue;

          // Column 0: Song Title
          final col0Runs = flexCols[0]['musicResponsiveListItemFlexColumnRenderer']
              ?['text']?['runs'] as List<dynamic>?;
          final title = col0Runs != null && col0Runs.isNotEmpty
              ? col0Runs[0]['text']?.toString() ?? 'Unknown'
              : 'Unknown';

          // Column 1: Artist • Album • Duration
          String artist = 'Unknown Artist';
          String album = 'YouTube Music';
          int durationSec = 210;

          if (flexCols.length > 1) {
            final col1Runs = flexCols[1]['musicResponsiveListItemFlexColumnRenderer']
                ?['text']?['runs'] as List<dynamic>?;
            if (col1Runs != null && col1Runs.isNotEmpty) {
              final parts = col1Runs
                  .map((r) => (r as Map<String, dynamic>)['text']?.toString() ?? '')
                  .where((t) => t.trim().isNotEmpty && t != '•' && t.trim() != '•')
                  .toList();
              if (parts.isNotEmpty) artist = parts[0];
              if (parts.length >= 3) album = parts[1];
              if (parts.length >= 2) {
                durationSec = _parseDurationText(parts.last);
              }
            }
          }

          // Thumbnails (Upgrade to 544x544 HD square cover art)
          final thumbs = item['thumbnail']?['musicThumbnailRenderer']?['thumbnail']
              ?['thumbnails'] as List<dynamic>?;
          String thumbUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
          String highResUrl = thumbUrl;
          if (thumbs != null && thumbs.isNotEmpty) {
            thumbUrl = (thumbs.last as Map<String, dynamic>)['url']?.toString() ?? thumbUrl;
            highResUrl = _upgradeThumbnailToSquareHD(thumbUrl);
          }

          songs.add(
            ZunifySong(
              videoId: videoId,
              title: title,
              artist: artist,
              album: album,
              durationSeconds: durationSec,
              thumbnailUrl: thumbUrl,
              highResArtUrl: highResUrl,
              addedAt: DateTime.now(),
            ),
          );

          if (songs.length >= limit) return songs;
        }
      }
    } catch (_) {}
    return songs;
  }

  /// Spotify-style Radio / Up-Next Engine via YouTube Music `RDAMVM` Watch Playlist
  Future<List<ZunifySong>> getRadioRecommendations(
    ZunifySong seedSong, {
    Set<String> excludeVideoIds = const {},
  }) async {
    try {
      final seen = <String>{seedSong.videoId, ...excludeVideoIds};
      final payload = {
        'videoId': seedSong.videoId,
        'playlistId': 'RDAMVM${seedSong.videoId}',
        'isAudioOnly': true,
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20250101.01.00',
            'hl': 'id',
            'gl': 'ID',
          },
        },
      };

      final res = await _http
          .post(
            Uri.parse(_ytmNextUrl),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Origin': 'https://music.youtube.com',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        _captureVisitorDataFromResponse(data);
        final tabs = data['contents']?['singleColumnMusicWatchNextResultsRenderer']
                ?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs']
            as List<dynamic>?;
        final tracks = tabs?[0]?['tabRenderer']?['content']?['musicQueueRenderer']
            ?['content']?['playlistPanelRenderer']?['contents'] as List<dynamic>?;

        if (tracks != null) {
          final results = <ZunifySong>[];
          for (final t in tracks) {
            final r = (t as Map<String, dynamic>)['playlistPanelVideoRenderer']
                as Map<String, dynamic>?;
            if (r == null) continue;

            final vid = r['videoId']?.toString();
            if (vid == null || seen.contains(vid)) continue;
            seen.add(vid);

            final title =
                r['title']?['runs']?[0]?['text']?.toString() ?? 'Unknown';
            final artist =
                r['longBylineText']?['runs']?[0]?['text']?.toString() ??
                    seedSong.artist;
            final durText =
                r['lengthText']?['runs']?[0]?['text']?.toString() ?? '3:30';
            final thumbs =
                r['thumbnail']?['thumbnails'] as List<dynamic>? ?? [];
            String thumb = 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';
            if (thumbs.isNotEmpty) {
              thumb =
                  (thumbs.last as Map<String, dynamic>)['url']?.toString() ??
                      thumb;
            }

            results.add(
              ZunifySong(
                videoId: vid,
                title: title,
                artist: artist,
                album: 'Zunify Radio',
                durationSeconds: _parseDurationText(durText),
                thumbnailUrl: thumb,
                highResArtUrl: _upgradeThumbnailToSquareHD(thumb),
                addedAt: DateTime.now(),
              ),
            );
            if (results.length >= 18) break;
          }
          if (results.isNotEmpty) return results;
        }
      }
    } catch (_) {}

    return searchSongs('${seedSong.artist} populer', limit: 12);
  }

  /// Resolves direct playable Audio Stream (`HTTP 200/206`) using `AusDMusic`'s
  /// `VISIONOS` (`1.04` / `1.02`) InnerTube Client + `visitorData` + `cpn` + `range=0-contentLength`.
  /// Bypasses PoToken/SABR HTTP 403 on `googlevideo.com` with ExoPlayer (`just_audio`).
  Future<ResolvedAudioStream?> resolveAudioStream(
    String videoId, {
    required bool highQuality,
  }) async {
    final cacheKey = '${videoId}_${highQuality ? "hq" : "low"}';
    final cached = _streamCache[cacheKey];
    if (cached != null && cached.isValid) {
      return cached.stream;
    }

    final visitorData = await _getVisitorData();

    // AusDMusic's verified VISIONOS clients (SmartTube 1.04 & NewPipe 1.02)
    final visionOsClients = [
      {
        'clientVersion': '1.04',
        'deviceModel': 'RealityDevice17,1',
        'osVersion': '26.6.0.23O770',
        'userAgent':
            'com.google.visionos.youtube/1.04(RealityDevice17,1; U; CPU visionOS 26_6_0 like Mac OS X; US)',
      },
      {
        'clientVersion': '1.02',
        'deviceModel': 'RealityDevice14,1',
        'osVersion': '25.6.0.23O471',
        'userAgent':
            'com.google.visionos.youtube/1.02(RealityDevice14,1; U; CPU visionOS 25_6_0 like Mac OS X; US)',
      },
    ];

    for (final client in visionOsClients) {
      try {
        final ua = client['userAgent']!;
        final tParam = _generateRandomToken(12);
        final cpn = _generateRandomToken(16);

        final clientContext = <String, dynamic>{
          'clientName': 'VISIONOS',
          'clientVersion': client['clientVersion'],
          'clientScreen': 'WATCH',
          'platform': 'MOBILE',
          'deviceMake': 'Apple',
          'deviceModel': client['deviceModel'],
          'osName': 'visionOS',
          'osVersion': client['osVersion'],
          'hl': 'en-GB',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        };
        if (visitorData != null && visitorData.isNotEmpty) {
          clientContext['visitorData'] = visitorData;
        }

        final payload = {
          'context': {'client': clientContext},
          'videoId': videoId,
          'cpn': cpn,
          'contentCheckOk': true,
          'racyCheckOk': true,
        };

        final headers = <String, String>{
          'Content-Type': 'application/json',
          'User-Agent': ua,
          'X-Goog-Api-Format-Version': '2',
        };
        if (visitorData != null && visitorData.isNotEmpty) {
          headers['X-Goog-Visitor-Id'] = visitorData;
        }

        final playerUri = Uri.parse(
          '$_ytVisionOsPlayerBaseUrl&t=$tParam&id=$videoId',
        );

        final res = await _http
            .post(
              playerUri,
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) continue;

        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        _captureVisitorDataFromResponse(data);

        final streamingData =
            data['streamingData'] as Map<String, dynamic>? ?? {};
        final hlsManifestUrl = streamingData['hlsManifestUrl']?.toString();
        final adaptive =
            streamingData['adaptiveFormats'] as List<dynamic>? ?? [];
        final formats = streamingData['formats'] as List<dynamic>? ?? [];

        final mp4AudioFormats = <Map<String, dynamic>>[];
        final otherAudioFormats = <Map<String, dynamic>>[];

        for (final f in [...adaptive, ...formats]) {
          final map = f as Map<String, dynamic>;
          final mime = map['mimeType']?.toString() ?? '';
          final url = map['url']?.toString();
          if (mime.startsWith('audio/') && url != null && url.isNotEmpty) {
            if (mime.contains('mp4')) {
              mp4AudioFormats.add(map);
            } else {
              otherAudioFormats.add(map);
            }
          }
        }

        final candidateFormats =
            mp4AudioFormats.isNotEmpty ? mp4AudioFormats : otherAudioFormats;
        if (candidateFormats.isEmpty &&
            (hlsManifestUrl == null || hlsManifestUrl.isEmpty)) {
          continue;
        }

        // Fire non-blocking YouTube playback telemetry ping (same as AusDMusic initPlayback)
        unawaited(_initPlaybackTelemetry(data, cpn: cpn, visitorData: visitorData));

        if (candidateFormats.isNotEmpty) {
          candidateFormats.sort((a, b) {
            final aBr = (a['bitrate'] as num?)?.toInt() ?? 0;
            final bBr = (b['bitrate'] as num?)?.toInt() ?? 0;
            return aBr.compareTo(bBr);
          });

          final chosen =
              highQuality ? candidateFormats.last : candidateFormats.first;

          String streamUrl = chosen['url'].toString();
          final contentLen =
              int.tryParse(chosen['contentLength']?.toString() ?? '') ?? 0;

          if (!streamUrl.contains('&cpn=')) {
            streamUrl = '$streamUrl&cpn=$cpn';
          }
          if (contentLen > 0 && !streamUrl.contains('&range=')) {
            streamUrl = '$streamUrl&range=0-$contentLen';
          }

          final resolved = ResolvedAudioStream(
            url: Uri.parse(streamUrl),
            hlsUrl: hlsManifestUrl != null && hlsManifestUrl.isNotEmpty
                ? Uri.parse(hlsManifestUrl)
                : null,
            headers: {'User-Agent': ua},
            bitrateKbps:
                (((chosen['bitrate'] as num?)?.toInt() ?? 128000) / 1000)
                    .round(),
            mimeType: chosen['mimeType']?.toString() ?? 'audio/mp4',
            contentLength: contentLen,
          );

          _streamCache[cacheKey] = _CachedStreamEntry(
            resolved,
            DateTime.now().add(const Duration(hours: 2)),
          );
          return resolved;
        } else if (hlsManifestUrl != null && hlsManifestUrl.isNotEmpty) {
          final hlsUri = Uri.parse(hlsManifestUrl);
          final resolved = ResolvedAudioStream(
            url: hlsUri,
            hlsUrl: hlsUri,
            headers: {'User-Agent': ua},
            bitrateKbps: 128,
            mimeType: 'application/x-mpegURL',
          );
          _streamCache[cacheKey] = _CachedStreamEntry(
            resolved,
            DateTime.now().add(const Duration(hours: 1)),
          );
          return resolved;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Non-blocking playback tracking ping matching `AusDMusic` (`StreamRepositoryImpl.initPlayback`)
  Future<void> _initPlaybackTelemetry(
    Map<String, dynamic> playerData, {
    required String cpn,
    String? visitorData,
  }) async {
    try {
      final tracking =
          playerData['playbackTracking'] as Map<String, dynamic>? ?? {};
      final playbackUrl = tracking['videostatsPlaybackUrl']?['baseUrl']
          ?.toString()
          .replaceFirst('https://s.youtube.com', 'https://music.youtube.com');
      final atrUrl = tracking['atrUrl']?['baseUrl']
          ?.toString()
          .replaceFirst('https://s.youtube.com', 'https://music.youtube.com');

      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        if (visitorData != null && visitorData.isNotEmpty)
          'X-Goog-Visitor-Id': visitorData,
      };

      if (playbackUrl != null && playbackUrl.isNotEmpty) {
        final sep = playbackUrl.contains('?') ? '&' : '?';
        await _http
            .get(Uri.parse('$playbackUrl${sep}ver=2&c=WEB_REMIX&cpn=$cpn'),
                headers: headers)
            .timeout(const Duration(seconds: 5));
      }
      if (atrUrl != null && atrUrl.isNotEmpty) {
        final sep = atrUrl.contains('?') ? '&' : '?';
        await _http
            .post(Uri.parse('$atrUrl${sep}ver=2&c=WEB_REMIX&cpn=$cpn'),
                headers: headers)
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
  }

  /// Backward-compatible helper returning direct URI
  Future<Uri?> getAudioStreamUri(
    String videoId, {
    required bool highQuality,
  }) async {
    final s = await resolveAudioStream(videoId, highQuality: highQuality);
    return s?.url;
  }

  Future<void> prefetchNextSongStream(
    String videoId, {
    required bool highQuality,
  }) async {
    try {
      await resolveAudioStream(videoId, highQuality: highQuality);
    } catch (_) {}
  }

  Future<List<ZunifySong>> getTrendingIndonesia() async {
    return searchSongs('Top Hits Indonesia Populer Terbaru', limit: 14);
  }

  Future<List<ZunifySong>> getTrendingGlobal() async {
    return searchSongs('Top Global Hits Pop Songs', limit: 14);
  }

  Future<List<ZunifySong>> getSongsByMood(String mood) async {
    final moodQueries = <String, String>{
      'Pop Indo': 'Hindia Tulus Bernadya Mahalini Juicy Luicy',
      'Chill': 'Chill R&B Lofi Santai Hits',
      'Galau': 'Lagu Galau Indonesia Paling Sedih',
      'Workout': 'Workout Gym Energetic Upbeat Hits',
      'Fokus': 'Focus Study Chill Instrumental',
      'K-Pop': 'NewJeans aespa Jung Kook DAY6 Hits',
      'Anime': 'YOASOBI Kenshi Yonezu Anime Opening Hits',
    };
    return searchSongs(moodQueries[mood] ?? mood, limit: 14);
  }

  /// Fetches tracks from a public YouTube / YouTube Music playlist ID
  Future<List<ZunifySong>> fetchYouTubePlaylistTracks(String playlistId) async {
    try {
      final browseId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
      final payload = {
        'browseId': browseId,
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20250101.01.00',
            'hl': 'id',
            'gl': 'ID',
          },
        },
      };
      final res = await _http
          .post(
            Uri.parse(_ytmBrowseUrl),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0',
              'Origin': 'https://music.youtube.com',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final raw = utf8.decode(res.bodyBytes);
      final vidMatches = RegExp(r'"videoId":"([a-zA-Z0-9_-]{11})"').allMatches(raw);
      final uniqueIds = <String>{};
      for (final m in vidMatches) {
        uniqueIds.add(m.group(1)!);
        if (uniqueIds.length >= 25) break;
      }

      final songs = <ZunifySong>[];
      for (final id in uniqueIds) {
        final found = await searchSongs(id, limit: 1);
        if (found.isNotEmpty) songs.add(found.first);
      }
      return songs;
    } catch (_) {
      return [];
    }
  }

  String _upgradeThumbnailToSquareHD(String url) {
    if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
      return url.replaceAll(RegExp(r'=w\d+-h\d+.*'), '=w544-h544-l90-rj');
    }
    return url;
  }

  int _parseDurationText(String text) {
    final cleaned = text.trim().replaceAll('.', ':');
    final parts = cleaned.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 3;
      final s = int.tryParse(parts[1]) ?? 30;
      return m * 60 + s;
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 3;
      final s = int.tryParse(parts[2]) ?? 0;
      return h * 3600 + m * 60 + s;
    }
    return 210;
  }
}
