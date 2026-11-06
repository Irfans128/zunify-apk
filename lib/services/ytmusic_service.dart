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
        // BitChord Official YouTube Music Strict "Songs Only" filter param
        'params': 'EgWKAQIIAWoKEAkQChAFEAMQBA==',
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
      final songs = _parseWebRemixSearchItems(
        data,
        limit: limit,
        rawQuery: trimmed,
      );
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

  bool _isNonSongYouTubeJunk({
    required String title,
    required String subtitle,
    required String? musicVideoType,
    required int durationSec,
    String rawQuery = '',
  }) {
    // 1. Strict InnerTube MusicVideoType check:
    // Only allow official Album Track Videos (ATV) or Official Source Music.
    // Reject User-Generated Content (UGC), Official Music Videos (OMV), and Podcasts.
    if (musicVideoType != null &&
        musicVideoType.isNotEmpty &&
        musicVideoType != 'MUSIC_VIDEO_TYPE_ATV' &&
        musicVideoType != 'MUSIC_VIDEO_TYPE_OFFICIAL_SOURCE_MUSIC') {
      return true;
    }

    // 2. Reject YouTube video view-count subtitles ("12 jt x ditonton", "views", etc.)
    final subLower = subtitle.toLowerCase();
    if (subLower.contains('ditonton') ||
        subLower.contains('tayangan') ||
        subLower.contains('views') ||
        subLower.contains('jt x') ||
        subLower.contains('rb x') ||
        subLower.contains('subscribers') ||
        subLower.contains('podcast') ||
        subLower.contains('episode')) {
      return true;
    }

    // 3. Reject non-song durations (< 45s skits/shorts or > 9.5 min compilations/full albums)
    if (durationSec < 45 || durationSec > 570) {
      return true;
    }

    // 4. Reject YouTube compilation / reaction / karaoke / full-album titles unless explicitly queried
    final tLower = title.toLowerCase();
    final qLower = rawQuery.toLowerCase();
    const junkMarkers = [
      'full album',
      'kompilasi',
      'compilation',
      '1 jam',
      '1 hour',
      '2 jam',
      'nonstop',
      'reaction',
      'podcast',
      'karaoke version',
      'lirik video',
      'lyric video',
      'official music video',
      'official video',
    ];
    for (final m in junkMarkers) {
      if (tLower.contains(m) && !qLower.contains(m)) {
        return true;
      }
    }
    return false;
  }

  List<ZunifySong> _parseWebRemixSearchItems(
    Map<String, dynamic> data, {
    required int limit,
    String rawQuery = '',
  }) {
    final songs = <ZunifySong>[];
    final fallbackSongs = <ZunifySong>[];
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

          // Column 0: Song Title + MusicVideoType
          final col0Runs = flexCols[0]['musicResponsiveListItemFlexColumnRenderer']
              ?['text']?['runs'] as List<dynamic>?;
          final firstRun = (col0Runs != null && col0Runs.isNotEmpty)
              ? col0Runs[0] as Map<String, dynamic>?
              : null;
          final title = firstRun?['text']?.toString() ?? 'Unknown';
          final String? mvType = firstRun?['navigationEndpoint']
                  ?['watchEndpoint']?['watchEndpointMusicSupportedConfigs']
                  ?['watchEndpointMusicConfig']?['musicVideoType']
                  ?.toString() ??
              item['overlay']?['musicItemThumbnailOverlayRenderer']?['content']
                      ?['musicPlayButtonRenderer']?['playNavigationEndpoint']
                      ?['watchEndpoint']?['watchEndpointMusicSupportedConfigs']
                      ?['watchEndpointMusicConfig']?['musicVideoType']
                  ?.toString();

          // Column 1: Artist • Album • Duration
          String artist = 'Unknown Artist';
          String album = 'YouTube Music';
          int durationSec = 210;
          String rawSubtitleJoined = '';

          if (flexCols.length > 1) {
            final col1Runs = flexCols[1]['musicResponsiveListItemFlexColumnRenderer']
                ?['text']?['runs'] as List<dynamic>?;
            if (col1Runs != null && col1Runs.isNotEmpty) {
              rawSubtitleJoined = col1Runs
                  .map((r) => (r as Map<String, dynamic>)['text']?.toString() ?? '')
                  .join(' ');
              final parts = col1Runs
                  .map((r) => (r as Map<String, dynamic>)['text']?.toString() ?? '')
                  .where((t) =>
                      t.trim().isNotEmpty &&
                      t != '•' &&
                      t.trim() != '•' &&
                      t.trim().toLowerCase() != 'lagu' &&
                      t.trim().toLowerCase() != 'song')
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

          final candidate = ZunifySong(
            videoId: videoId,
            title: title,
            artist: artist,
            album: album,
            durationSeconds: durationSec,
            thumbnailUrl: thumbUrl,
            highResArtUrl: highResUrl,
            addedAt: DateTime.now(),
          );

          if (_isNonSongYouTubeJunk(
            title: title,
            subtitle: rawSubtitleJoined,
            musicVideoType: mvType,
            durationSec: durationSec,
            rawQuery: rawQuery,
          )) {
            if (durationSec >= 45 && durationSec <= 570) {
              fallbackSongs.add(candidate);
            }
            continue;
          }

          songs.add(candidate);
          if (songs.length >= limit) return songs;
        }
      }
    } catch (_) {}
    if (songs.isEmpty && fallbackSongs.isNotEmpty) {
      return fallbackSongs.take(limit).toList();
    }
    return songs;
  }

  /// Spotify-style Genre / Mood Radio Engine via YouTube Music `RDAMVM` AutoMix Watch Playlist
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
        'enablePersistentPlaylistPanel': true,
        'tunerSettingValue': 'AUTOMIX_SETTING_NORMAL',
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
            final mvType = r['navigationEndpoint']?['watchEndpoint']
                    ?['watchEndpointMusicSupportedConfigs']
                    ?['watchEndpointMusicConfig']?['musicVideoType']
                ?.toString();
            final bylineRuns = r['longBylineText']?['runs'] as List<dynamic>?;
            final bylineJoined = bylineRuns != null
                ? bylineRuns
                    .map((e) => (e as Map<String, dynamic>)['text']?.toString() ?? '')
                    .join(' ')
                : '';
            final artist =
                bylineRuns != null && bylineRuns.isNotEmpty
                    ? (bylineRuns[0]['text']?.toString() ?? seedSong.artist)
                    : seedSong.artist;
            final album =
                bylineRuns != null && bylineRuns.length >= 3
                    ? (bylineRuns[2]['text']?.toString() ?? 'Zunify Radio')
                    : 'Zunify Radio';
            final durText =
                r['lengthText']?['runs']?[0]?['text']?.toString() ?? '3:30';
            final parsedDurSec = _parseDurationText(durText);

            if (_isNonSongYouTubeJunk(
              title: title,
              subtitle: bylineJoined,
              musicVideoType: mvType,
              durationSec: parsedDurSec,
            )) {
              continue;
            }

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
                album: album,
                durationSeconds: parsedDurSec,
                thumbnailUrl: thumb,
                highResArtUrl: _upgradeThumbnailToSquareHD(thumb),
                addedAt: DateTime.now(),
              ),
            );
            if (results.length >= 36) break;
          }
          if (results.isNotEmpty) return results;
        }
      }
    } catch (_) {}

    return searchSongs('Mix lagu mirip ${seedSong.artist}', limit: 20);
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

  static final RegExp _nonIndoGlobalArtistRegex = RegExp(
    r'\b(one direction|taylor swift|bruno mars|the weeknd|ed sheeran|coldplay|justin bieber|ariana grande|billie eilish|sabrina carpenter|olivia rodrigo|harry styles|zayn|niall horan|liam payne|louis tomlinson|maroon 5|shawn mendes|charlie puth|dua lipa|adele|sam smith|katy perry|lady gaga|rihanna|beyonce|eminem|post malone|drake|sza|kendrick lamar|travis scott|radiohead|oasis|arctic monkeys|linkin park|green day|queen|the beatles|alan walker|the chainsmokers|avicii|calvin harris|david guetta|martin garrix|imagine dragons|onedirection|laufey|cigarettes after sex|cas|the 1975|keshi|joji|niki|rich brian|wave to earth|lany|lauv|conan gray|hozier|benson boone|gracie abrams|chappell roan|d4vd|jvke|stephen sanchez|ruth b|lewis capaldi|james arthur|calum scott|passenger|kodaline|the script|westlife|backstreet boys|blue|mltr|michael learns to rock|mcr|my chemical romance|paramore|blink-182|nirvana|guns n|metallica|bon jovi|aerosmith|scorpions|avenged sevenfold|bring me the horizon|bmth|bts|blackpink|newjeans|aespa|twice|exo|nct|seventeen|stray kids|itzy|ive|le sserafim|babymonster|illit|treasure|enhypen|txt|day6|jung kook|jimin|lisa|rose|jennie|jisoo|iu|bigbang|2ne1|red velvet|yoasobi|kenshi yonezu|fujii kaze|ado|lisa|aimer|radwimps|official hige dandism|king gnu|mrs\. green apple|creepy nuts|eve|vaundy|imase|yuuri)\b',
    caseSensitive: false,
  );

  bool _isAllowedForIndoCategory(ZunifySong song) {
    if (_nonIndoGlobalArtistRegex.hasMatch(song.artist)) return false;
    if (_nonIndoGlobalArtistRegex.hasMatch(song.title)) return false;
    return true;
  }

  Future<List<ZunifySong>> _mergeMultiQueryResults(
    List<String> queries, {
    int perQueryLimit = 8,
    int totalLimit = 16,
    bool filterIndoOnly = false,
  }) async {
    final batches = await Future.wait(
      queries.map((q) => searchSongs(q, limit: perQueryLimit)),
    );
    final seen = <String>{};
    final merged = <ZunifySong>[];
    for (final list in batches) {
      for (final s in list) {
        if (filterIndoOnly && !_isAllowedForIndoCategory(s)) continue;
        if (seen.add(s.videoId)) {
          merged.add(s);
          if (merged.length >= totalLimit) return merged;
        }
      }
    }
    return merged;
  }

  Future<List<ZunifySong>> getTrendingIndonesia() async {
    return _mergeMultiQueryResults(
      const [
        'Lagu Pop Indonesia Hits Terbaru',
        'Bernadya Sal Priadi Mahalini Lagu',
        'Tulus Juicy Luicy Hindia Lagu',
      ],
      perQueryLimit: 8,
      totalLimit: 15,
      filterIndoOnly: true,
    );
  }

  Future<List<ZunifySong>> getTrendingGlobal() async {
    return _mergeMultiQueryResults(
      const [
        'Bruno Mars The Weeknd Billie Eilish Hits',
        'One Direction Taylor Swift Sabrina Carpenter Hits',
      ],
      perQueryLimit: 9,
      totalLimit: 15,
    );
  }

  Future<List<ZunifySong>> getSongsByMood(String mood) async {
    switch (mood) {
      case 'Pop Indo':
      case 'Semua':
        return _mergeMultiQueryResults(
          const [
            'Tulus Mahalini Bernadya Lagu Pop Indonesia',
            'Juicy Luicy Tiara Andini Lyodra Rizky Febian',
            'Sheila On 7 Dewa 19 Noah Hindia Perunggu',
          ],
          perQueryLimit: 8,
          totalLimit: 16,
          filterIndoOnly: true,
        );
      case 'Pop Barat':
        return _mergeMultiQueryResults(
          const [
            'One Direction Bruno Mars The Weeknd Pop Hits',
            'Taylor Swift Sabrina Carpenter Billie Eilish Coldplay',
          ],
          perQueryLimit: 9,
          totalLimit: 16,
        );
      case 'Galau':
        return _mergeMultiQueryResults(
          const [
            'Bernadya Mahalini Juicy Luicy Lagu Galau Indonesia',
            'Fabio Asher Lyodra Nadhif Basalamah Sal Priadi',
          ],
          perQueryLimit: 9,
          totalLimit: 16,
          filterIndoOnly: true,
        );
      case 'Chill':
        return _mergeMultiQueryResults(
          const [
            'Hindia Pamungkas Nadin Amizah Payung Teduh',
            'Kunto Aji Barasuara Dere Reality Club',
          ],
          perQueryLimit: 9,
          totalLimit: 16,
        );
      case 'K-Pop':
        return _mergeMultiQueryResults(
          const [
            'NewJeans aespa DAY6 IVE LE SSERAFIM',
            'BLACKPINK Jung Kook SEVENTEEN BABYMONSTER',
          ],
          perQueryLimit: 9,
          totalLimit: 16,
        );
      case 'Anime':
        return _mergeMultiQueryResults(
          const [
            'YOASOBI Kenshi Yonezu Fujii Kaze Official HIGE DANdism',
            'Mrs GREEN APPLE Creepy Nuts RADWIMPS LiSA Anime',
          ],
          perQueryLimit: 9,
          totalLimit: 16,
        );
      case 'Workout':
        return searchSongs('Workout Gym Energetic Upbeat Pop EDM Hits', limit: 15);
      case 'Fokus':
        return searchSongs('Focus Study Chill Acoustic Lofi Instrumental', limit: 15);
      default:
        return searchSongs(mood, limit: 15);
    }
  }

  /// Fetches tracks from a public YouTube / YouTube Music playlist ID (Unlimited pagination)
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
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Origin': 'https://music.youtube.com',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];

      final raw = utf8.decode(res.bodyBytes);
      final vidMatches = RegExp(r'"videoId":"([a-zA-Z0-9_-]{11})"').allMatches(raw);
      final uniqueIds = <String>{};
      for (final m in vidMatches) {
        uniqueIds.add(m.group(1)!);
      }

      final songs = <ZunifySong>[];
      final idList = uniqueIds.toList();
      const int batchSize = 8;
      for (int s = 0; s < idList.length; s += batchSize) {
        final end = (s + batchSize < idList.length) ? s + batchSize : idList.length;
        final batch = await Future.wait(
          idList.sublist(s, end).map((id) => searchSongs(id, limit: 1)),
        );
        for (final found in batch) {
          if (found.isNotEmpty) songs.add(found.first);
        }
      }
      return songs;
    } catch (_) {
      return [];
    }
  }

  /// Real-time Autocomplete Search Suggestions (`get_search_suggestions`)
  Future<List<String>> getSearchSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final payload = {
        'input': trimmed,
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
            Uri.parse(
              'https://music.youtube.com/youtubei/v1/music/get_search_suggestions?prettyPrint=false',
            ),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Origin': 'https://music.youtube.com',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final contents = data['contents'] as List<dynamic>? ?? const [];
        final suggestions = <String>[];
        final seen = <String>{};

        for (final sec in contents) {
          final secItems = (sec as Map<String, dynamic>)
                  ['searchSuggestionsSectionRenderer']?['contents']
              as List<dynamic>?;
          if (secItems == null) continue;
          for (final item in secItems) {
            final itemMap = item as Map<String, dynamic>;
            final runs = itemMap['searchSuggestionRenderer']?['suggestion']
                ?['runs'] as List<dynamic>?;
            if (runs != null && runs.isNotEmpty) {
              final text = runs
                  .map((r) => (r as Map<String, dynamic>)['text']?.toString() ?? '')
                  .join()
                  .trim();
              if (text.isNotEmpty && seen.add(text.toLowerCase())) {
                suggestions.add(text);
              }
            }
          }
        }
        if (suggestions.isNotEmpty) {
          return suggestions.take(8).toList();
        }
      }
    } catch (_) {}
    return const [];
  }

  static const Set<String> _genericSearchWords = {
    'lagu',
    'musik',
    'music',
    'song',
    'songs',
    'audio',
    'lirik',
    'lyrics',
    'sad',
    'galau',
    'sedih',
    'baper',
    'cinta',
    'patah',
    'hati',
    'broken',
    'pop',
    'hits',
    'viral',
    'tiktok',
    'trending',
    'chill',
    'santai',
    'indie',
    'senja',
    'pagi',
    'siang',
    'malam',
    'hujan',
    'tidur',
    'sleep',
    'study',
    'belajar',
    'fokus',
    'kerja',
    'workout',
    'gym',
    'gaming',
    'lofi',
    'remix',
    'dj',
    'koplo',
    'dangdut',
    'acoustic',
    'akustik',
    'slowed',
    'reverb',
    'sped',
    'nightcore',
    'karaoke',
    'instrumental',
    'cover',
    'indonesia',
    'indo',
    'barat',
    'global',
    'korea',
    'kpop',
    'jpop',
    'anime',
    'ost',
    'soundtrack',
    'terbaru',
    'terpopuler',
    'terbaik',
    'top',
    'best',
    'playlist',
    'full',
    'album',
    'enak',
    'nyaman',
    'happy',
    'semangat',
    'party',
    'rock',
    'jazz',
    'rnb',
    'hiphop',
    'rap',
    'klasik',
    'nostalgia',
    'various',
    'artists',
    'official',
    'channel',
    'topic',
  };

  List<String> _tokenizeNormalized(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Resolves an Artist Profile card ONLY when the user explicitly searched
  /// for an artist name or `song + artist` (never on generic mood/genre queries
  /// like "lagu sad", "lagu galau", "pop indo", etc.).
  Future<ZunifyArtistSummary?> resolveArtistForSearchQuery(
    String rawQuery,
    List<ZunifySong> songResults,
  ) async {
    final queryTokens = _tokenizeNormalized(rawQuery);
    if (queryTokens.isEmpty) return null;

    // 1. Reject if the query consists only of generic mood/genre/category words
    final meaningfulQueryTokens =
        queryTokens.where((w) => !_genericSearchWords.contains(w)).toList();
    if (meaningfulQueryTokens.isEmpty) return null;

    // 2. Find an artist from the top song results whose name is explicitly
    //    present in the user's search query.
    String? matchedArtistName;
    final queryTokenSet = queryTokens.toSet();

    for (final song in songResults.take(8)) {
      final rawArtists = song.artist.split(
        RegExp(r',|&| x | feat\.?| ft\.?', caseSensitive: false),
      );
      for (final rawArt in rawArtists) {
        final candidate = rawArt.trim();
        if (candidate.length < 2) continue;
        final artTokens = _tokenizeNormalized(candidate);
        if (artTokens.isEmpty) continue;

        // Ignore fake/generic channel names like "Lagu Sad", "Various Artists"
        final nonGenericArtTokens =
            artTokens.where((w) => !_genericSearchWords.contains(w)).toList();
        if (nonGenericArtTokens.isEmpty) continue;

        // Every token of the artist's name must appear in the user's query
        final allTokensInQuery =
            artTokens.every((t) => queryTokenSet.contains(t));
        if (allTokensInQuery) {
          matchedArtistName = candidate;
          break;
        }
      }
      if (matchedArtistName != null) break;
    }

    if (matchedArtistName == null) return null;

    final summary = await searchTopArtistMatch(matchedArtistName);
    if (summary == null) return null;

    // 3. Final sanity check: returned artist name must overlap with matchedArtistName
    final summaryTokens = _tokenizeNormalized(summary.name);
    final targetTokens = _tokenizeNormalized(matchedArtistName);
    if (summaryTokens.isEmpty || targetTokens.isEmpty) return null;
    final hasOverlap =
        targetTokens.every((t) => summaryTokens.contains(t)) ||
        summaryTokens.every((t) => targetTokens.contains(t));
    if (!hasOverlap) return null;

    return summary;
  }

  /// Resolves an artist's YouTube Music Channel `browseId` (`UC...`) by name
  Future<ZunifyArtistSummary?> searchTopArtistMatch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    try {
      final payload = {
        'query': trimmed,
        'params': 'EgWKAQIgAWoKEAkQChADEAUQBA%3D%3D', // Artists filter
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
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 7));
      if (res.statusCode != 200) return null;

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final tabs = data['contents']?['tabbedSearchResultsRenderer']?['tabs']
          as List<dynamic>?;
      final sections = tabs?[0]?['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents'] as List<dynamic>?;
      if (sections == null) return null;

      for (final sec in sections) {
        final items = (sec as Map<String, dynamic>)['musicShelfRenderer']
            ?['contents'] as List<dynamic>?;
        if (items == null || items.isEmpty) continue;
        final r = (items.first
                as Map<String, dynamic>)['musicResponsiveListItemRenderer']
            as Map<String, dynamic>?;
        if (r == null) continue;

        final browseId = r['navigationEndpoint']?['browseEndpoint']?['browseId']
            ?.toString();
        if (browseId == null || !browseId.startsWith('UC')) continue;

        final flex = r['flexColumns'] as List<dynamic>? ?? const [];
        String name = trimmed;
        String subtitle = 'Artis';
        if (flex.isNotEmpty) {
          final runs0 = (flex[0] as Map<String, dynamic>)
                  ['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
              as List<dynamic>?;
          if (runs0 != null && runs0.isNotEmpty) {
            name = runs0[0]['text']?.toString() ?? trimmed;
          }
        }
        if (flex.length >= 2) {
          final runs1 = (flex[1] as Map<String, dynamic>)
                  ['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
              as List<dynamic>?;
          if (runs1 != null && runs1.isNotEmpty) {
            subtitle = runs1
                .map((e) => (e as Map<String, dynamic>)['text']?.toString() ?? '')
                .join();
          }
        }

        final thumbs = r['thumbnail']?['musicThumbnailRenderer']?['thumbnail']
                ?['thumbnails'] as List<dynamic>? ??
            const [];
        String avatar = '';
        if (thumbs.isNotEmpty) {
          avatar = _upgradeThumbnailToSquareHD(
            (thumbs.last as Map<String, dynamic>)['url']?.toString() ?? '',
          );
        }

        return ZunifyArtistSummary(
          browseId: browseId,
          name: name,
          subtitle: subtitle,
          avatarUrl: avatar,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Fetches full Artist Profile (`UC...` channel page + top songs + albums/singles + similar artists)
  Future<ZunifyArtistProfile> fetchArtistProfile(
    String artistName, {
    String? browseId,
  }) async {
    final cleanName = artistName
        .split(RegExp(r',|&| x | feat\.?| ft\.?', caseSensitive: false))
        .first
        .trim();
    final targetName = cleanName.isNotEmpty ? cleanName : artistName.trim();

    String? resolvedBrowseId = browseId;
    String fallbackAvatar = '';
    if (resolvedBrowseId == null || !resolvedBrowseId.startsWith('UC')) {
      final matched = await searchTopArtistMatch(targetName);
      resolvedBrowseId = matched?.browseId;
      fallbackAvatar = matched?.avatarUrl ?? '';
    }

    String resolvedTitle = targetName;
    String bannerUrl = fallbackAvatar;
    String description = '';
    final topSongs = <ZunifySong>[];
    final albums = <ZunifyAlbumSummary>[];
    final similarArtists = <ZunifyArtistSummary>[];
    final seenVideoIds = <String>{};

    // Fetch Artist Channel Browse Page and Popular Songs in parallel
    final futures = await Future.wait([
      if (resolvedBrowseId != null && resolvedBrowseId.isNotEmpty)
        _http
            .post(
              Uri.parse(_ytmBrowseUrl),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                'Origin': 'https://music.youtube.com',
              },
              body: jsonEncode({
                'browseId': resolvedBrowseId,
                'context': {
                  'client': {
                    'clientName': 'WEB_REMIX',
                    'clientVersion': '1.20250101.01.00',
                    'hl': 'id',
                    'gl': 'ID',
                  },
                },
              }),
            )
            .timeout(const Duration(seconds: 9))
      else
        Future<http.Response?>.value(null),
      searchSongs('$targetName populer', limit: 15),
    ]);

    final browseRes = futures[0] as http.Response?;
    final searchedSongs = futures[1] as List<ZunifySong>;

    if (browseRes != null && browseRes.statusCode == 200) {
      try {
        final data =
            jsonDecode(utf8.decode(browseRes.bodyBytes)) as Map<String, dynamic>;
        final header = (data['header']?['musicImmersiveHeaderRenderer'] ??
                data['header']?['musicVisualHeaderRenderer'])
            as Map<String, dynamic>?;
        if (header != null) {
          resolvedTitle =
              header['title']?['runs']?[0]?['text']?.toString() ?? resolvedTitle;
          description =
              header['description']?['runs']?[0]?['text']?.toString() ?? '';
          final thumbs = (header['thumbnail']?['musicThumbnailRenderer'] ??
                  header['foregroundThumbnail']?['musicThumbnailRenderer'])
              ?['thumbnail']?['thumbnails'] as List<dynamic>?;
          if (thumbs != null && thumbs.isNotEmpty) {
            final rawUrl =
                (thumbs.last as Map<String, dynamic>)['url']?.toString() ?? '';
            if (rawUrl.isNotEmpty) {
              bannerUrl = rawUrl.replaceAll(
                RegExp(r'=w\d+-h\d+.*'),
                '=w1200-h800-p-l90-rj',
              );
            }
          }
        }

        final sections = data['contents']?['singleColumnBrowseResultsRenderer']
                ?['tabs']?[0]?['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents'] as List<dynamic>?;

        if (sections != null) {
          for (final sec in sections) {
            final secMap = sec as Map<String, dynamic>;

            // 1. Top Songs Shelf ("Lagu teratas")
            final shelf = secMap['musicShelfRenderer'] as Map<String, dynamic>?;
            if (shelf != null) {
              final items = shelf['contents'] as List<dynamic>? ?? const [];
              for (final item in items) {
                final r = (item as Map<String, dynamic>)
                    ['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
                if (r == null) continue;
                final vid = r['playlistItemData']?['videoId']?.toString();
                if (vid == null || !seenVideoIds.add(vid)) continue;

                final flex = r['flexColumns'] as List<dynamic>? ?? const [];
                String sTitle = 'Unknown';
                String sAlbum = resolvedTitle;
                if (flex.isNotEmpty) {
                  final runs = (flex[0] as Map<String, dynamic>)
                          ['musicResponsiveListItemFlexColumnRenderer']?['text']
                      ?['runs'] as List<dynamic>?;
                  if (runs != null && runs.isNotEmpty) {
                    sTitle = runs[0]['text']?.toString() ?? sTitle;
                  }
                }
                if (flex.length >= 3) {
                  final runs = (flex[2] as Map<String, dynamic>)
                          ['musicResponsiveListItemFlexColumnRenderer']?['text']
                      ?['runs'] as List<dynamic>?;
                  if (runs != null && runs.isNotEmpty) {
                    sAlbum = runs[0]['text']?.toString() ?? sAlbum;
                  }
                }
                final thumbs = r['thumbnail']?['musicThumbnailRenderer']
                        ?['thumbnail']?['thumbnails'] as List<dynamic>? ??
                    const [];
                String thumb = 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';
                if (thumbs.isNotEmpty) {
                  thumb = (thumbs.last as Map<String, dynamic>)['url']
                          ?.toString() ??
                      thumb;
                }
                topSongs.add(
                  ZunifySong(
                    videoId: vid,
                    title: sTitle,
                    artist: resolvedTitle,
                    album: sAlbum,
                    durationSeconds: 215,
                    thumbnailUrl: thumb,
                    highResArtUrl: _upgradeThumbnailToSquareHD(thumb),
                    addedAt: DateTime.now(),
                  ),
                );
              }
            }

            // 2. Carousels: Albums, Singles & EP, Similar Artists
            final carousel =
                secMap['musicCarouselShelfRenderer'] as Map<String, dynamic>?;
            if (carousel != null) {
              final cTitle = (carousel['header']
                              ?['musicCarouselShelfBasicHeaderRenderer']
                          ?['title']?['runs']?[0]?['text'] ??
                      '')
                  .toString()
                  .toLowerCase();
              final cItems = carousel['contents'] as List<dynamic>? ?? const [];

              for (final ci in cItems) {
                final twoRow = (ci as Map<String, dynamic>)
                    ['musicTwoRowItemRenderer'] as Map<String, dynamic>?;
                if (twoRow == null) continue;

                final itemTitle =
                    twoRow['title']?['runs']?[0]?['text']?.toString() ?? '';
                final subRuns =
                    twoRow['subtitle']?['runs'] as List<dynamic>? ?? const [];
                final itemSub = subRuns
                    .map((e) => (e as Map<String, dynamic>)['text']?.toString() ?? '')
                    .join()
                    .trim();
                final itemBrowseId = twoRow['navigationEndpoint']
                        ?['browseEndpoint']?['browseId']
                    ?.toString();
                final thumbs = twoRow['thumbnailRenderer']
                        ?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
                    as List<dynamic>?;
                String thumbUrl = '';
                if (thumbs != null && thumbs.isNotEmpty) {
                  thumbUrl = _upgradeThumbnailToSquareHD(
                    (thumbs.last as Map<String, dynamic>)['url']?.toString() ??
                        '',
                  );
                }

                if (itemBrowseId != null &&
                    itemBrowseId.startsWith('MPREb') &&
                    itemTitle.isNotEmpty) {
                  albums.add(
                    ZunifyAlbumSummary(
                      browseId: itemBrowseId,
                      title: itemTitle,
                      artist: resolvedTitle,
                      yearOrSubtitle: itemSub,
                      coverUrl: thumbUrl,
                    ),
                  );
                } else if (itemBrowseId != null &&
                    itemBrowseId.startsWith('UC') &&
                    itemTitle.isNotEmpty &&
                    (cTitle.contains('penggemar') ||
                        cTitle.contains('fans') ||
                        cTitle.contains('mirip') ||
                        cTitle.contains('similar'))) {
                  similarArtists.add(
                    ZunifyArtistSummary(
                      browseId: itemBrowseId,
                      name: itemTitle,
                      subtitle: itemSub,
                      avatarUrl: thumbUrl,
                    ),
                  );
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    for (final s in searchedSongs) {
      if (seenVideoIds.add(s.videoId)) {
        topSongs.add(s);
        if (topSongs.length >= 15) break;
      }
    }

    if (bannerUrl.isEmpty && topSongs.isNotEmpty) {
      bannerUrl = topSongs.first.highResArtUrl;
    }

    return ZunifyArtistProfile(
      browseId: resolvedBrowseId ?? '',
      name: resolvedTitle,
      bannerUrl: bannerUrl,
      description: description,
      topSongs: topSongs,
      albums: albums,
      similarArtists: similarArtists,
    );
  }

  /// Fetches all tracks inside a YouTube Music Album / EP (`MPREb_...`)
  Future<ZunifyAlbumDetail> fetchAlbumDetail(ZunifyAlbumSummary album) async {
    final songs = <ZunifySong>[];
    try {
      final res = await _http
          .post(
            Uri.parse(_ytmBrowseUrl),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Origin': 'https://music.youtube.com',
            },
            body: jsonEncode({
              'browseId': album.browseId,
              'context': {
                'client': {
                  'clientName': 'WEB_REMIX',
                  'clientVersion': '1.20250101.01.00',
                  'hl': 'id',
                  'gl': 'ID',
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 9));

      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final shelfContents = (data['contents']?['twoColumnBrowseResultsRenderer']
                    ?['secondaryContents']?['sectionListRenderer']?['contents']
                ?[0]?['musicShelfRenderer']?['contents'] ??
            data['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]
                    ?['tabRenderer']?['content']?['sectionListRenderer']
                ?['contents']?[0]?['musicShelfRenderer']?['contents'])
            as List<dynamic>?;

        if (shelfContents != null) {
          for (final item in shelfContents) {
            final r = (item as Map<String, dynamic>)
                ['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
            if (r == null) continue;
            final vid = r['playlistItemData']?['videoId']?.toString();
            if (vid == null || vid.isEmpty) continue;

            final flex = r['flexColumns'] as List<dynamic>? ?? const [];
            String title = 'Track';
            if (flex.isNotEmpty) {
              final runs = (flex[0] as Map<String, dynamic>)
                      ['musicResponsiveListItemFlexColumnRenderer']?['text']
                  ?['runs'] as List<dynamic>?;
              if (runs != null && runs.isNotEmpty) {
                title = runs[0]['text']?.toString() ?? title;
              }
            }

            final fixed = r['fixedColumns'] as List<dynamic>? ?? const [];
            String durText = '3:30';
            if (fixed.isNotEmpty) {
              final runs = (fixed[0] as Map<String, dynamic>)
                      ['musicResponsiveListItemFixedColumnRenderer']?['text']
                  ?['runs'] as List<dynamic>?;
              if (runs != null && runs.isNotEmpty) {
                durText = runs[0]['text']?.toString() ?? durText;
              }
            }

            songs.add(
              ZunifySong(
                videoId: vid,
                title: title,
                artist: album.artist,
                album: album.title,
                durationSeconds: _parseDurationText(durText),
                thumbnailUrl: album.coverUrl.isNotEmpty
                    ? album.coverUrl
                    : 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
                highResArtUrl: album.coverUrl.isNotEmpty
                    ? album.coverUrl
                    : 'https://i.ytimg.com/vi/$vid/maxresdefault.jpg',
                addedAt: DateTime.now(),
              ),
            );
          }
        }
      }
    } catch (_) {}

    if (songs.isEmpty) {
      final fallback =
          await searchSongs('${album.artist} ${album.title}', limit: 12);
      songs.addAll(fallback);
    }

    return ZunifyAlbumDetail(summary: album, tracks: songs);
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

class ZunifyAlbumSummary {
  final String browseId;
  final String title;
  final String artist;
  final String yearOrSubtitle;
  final String coverUrl;

  const ZunifyAlbumSummary({
    required this.browseId,
    required this.title,
    required this.artist,
    required this.yearOrSubtitle,
    required this.coverUrl,
  });
}

class ZunifyArtistSummary {
  final String browseId;
  final String name;
  final String subtitle;
  final String avatarUrl;

  const ZunifyArtistSummary({
    required this.browseId,
    required this.name,
    required this.subtitle,
    required this.avatarUrl,
  });
}

class ZunifyArtistProfile {
  final String browseId;
  final String name;
  final String bannerUrl;
  final String description;
  final List<ZunifySong> topSongs;
  final List<ZunifyAlbumSummary> albums;
  final List<ZunifyArtistSummary> similarArtists;

  const ZunifyArtistProfile({
    required this.browseId,
    required this.name,
    required this.bannerUrl,
    required this.description,
    required this.topSongs,
    required this.albums,
    required this.similarArtists,
  });
}

class ZunifyAlbumDetail {
  final ZunifyAlbumSummary summary;
  final List<ZunifySong> tracks;

  const ZunifyAlbumDetail({
    required this.summary,
    required this.tracks,
  });
}
