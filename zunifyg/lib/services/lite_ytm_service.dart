import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/lite_song.dart';

class LiteAudioStream {
  final Uri url;
  final Uri? hlsUrl;
  final Map<String, String> headers;
  final int bitrateKbps;

  const LiteAudioStream({
    required this.url,
    this.hlsUrl,
    required this.headers,
    required this.bitrateKbps,
  });
}

class _CachedStream {
  final LiteAudioStream stream;
  final DateTime expiresAt;
  const _CachedStream(this.stream, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

/// Ultra-lean YouTube Music InnerTube engine for ZunifyG.
/// Zero bloat: ONLY Search, Smart Radio Algorithm (RDAMVM), & Direct Audio Stream.
class LiteYtmService {
  static const _searchUrl =
      'https://music.youtube.com/youtubei/v1/search?prettyPrint=false';
  static const _nextUrl =
      'https://music.youtube.com/youtubei/v1/next?prettyPrint=false';
  static const _suggestUrl =
      'https://music.youtube.com/youtubei/v1/music/get_search_suggestions?prettyPrint=false';
  static const _playerBaseUrl =
      'https://youtubei.googleapis.com/youtubei/v1/player?prettyPrint=false';
  static const _swJsDataUrl = 'https://www.youtube.com/sw.js_data';

  static const _chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

  final Random _rng = Random();
  final http.Client _http = http.Client();

  String? _visitorData;
  DateTime? _visitorFetchedAt;

  // Tightly bounded caches so RAM stays ultra-low on potato phones
  final Map<String, _CachedStream> _streamCache = {};
  final Map<String, List<LiteSong>> _searchCache = {};

  LiteYtmService() {
    unawaited(_getVisitorData());
  }

  String _randToken(int len) {
    final sb = StringBuffer();
    for (int i = 0; i < len; i++) {
      sb.write(_chars[_rng.nextInt(_chars.length)]);
    }
    return sb.toString();
  }

  void _captureVisitor(Map<String, dynamic> data) {
    final v = data['responseContext']?['visitorData']?.toString();
    if (v != null && v.isNotEmpty) {
      _visitorData = v;
      _visitorFetchedAt = DateTime.now();
    }
  }

  Future<String?> _getVisitorData() async {
    if (_visitorData != null &&
        _visitorFetchedAt != null &&
        DateTime.now().difference(_visitorFetchedAt!).inMinutes < 45) {
      return _visitorData;
    }
    try {
      final res = await _http.get(
        Uri.parse(_swJsDataUrl),
        headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        String raw = utf8.decode(res.bodyBytes);
        if (raw.startsWith(")]}'")) raw = raw.substring(4);
        final decoded = jsonDecode(raw) as List<dynamic>;
        final token = decoded[0][2][0][0][13]?.toString();
        if (token != null && token.isNotEmpty) {
          _visitorData = token;
          _visitorFetchedAt = DateTime.now();
        }
      }
    } catch (_) {}
    return _visitorData;
  }

  String _compactThumb(String url) {
    if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
      // Request tiny 120x120 square thumbnail to save RAM & mobile bandwidth while gaming
      return url.replaceAll(RegExp(r'=w\d+-h\d+.*'), '=w120-h120-l80-rj');
    }
    return url;
  }

  int _parseDuration(String text) {
    final parts = text.trim().replaceAll('.', ':').split(':');
    if (parts.length == 2) {
      return (int.tryParse(parts[0]) ?? 3) * 60 + (int.tryParse(parts[1]) ?? 30);
    }
    if (parts.length == 3) {
      return (int.tryParse(parts[0]) ?? 0) * 3600 +
          (int.tryParse(parts[1]) ?? 3) * 60 +
          (int.tryParse(parts[2]) ?? 0);
    }
    return 200;
  }

  bool _isJunk({
    required String title,
    required String subtitle,
    required String? mvType,
    required int durationSec,
    String rawQuery = '',
  }) {
    if (mvType != null &&
        mvType.isNotEmpty &&
        mvType != 'MUSIC_VIDEO_TYPE_ATV' &&
        mvType != 'MUSIC_VIDEO_TYPE_OFFICIAL_SOURCE_MUSIC') {
      return true;
    }
    final sub = subtitle.toLowerCase();
    if (sub.contains('ditonton') ||
        sub.contains('views') ||
        sub.contains('podcast') ||
        sub.contains('episode')) {
      return true;
    }
    if (durationSec < 45 || durationSec > 570) return true;
    final t = title.toLowerCase();
    final q = rawQuery.toLowerCase();
    const junk = [
      'full album',
      '1 jam',
      '1 hour',
      'nonstop',
      'reaction',
      'podcast',
      'karaoke version',
    ];
    for (final j in junk) {
      if (t.contains(j) && !q.contains(j)) return true;
    }
    return false;
  }

  /// Fast Songs-only search
  Future<List<LiteSong>> searchSongs(String query, {int limit = 18}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final key = '${trimmed.toLowerCase()}_$limit';
    final cached = _searchCache[key];
    if (cached != null) return cached;

    try {
      final res = await _http
          .post(
            Uri.parse(_searchUrl),
            headers: const {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Origin': 'https://music.youtube.com',
              'Referer': 'https://music.youtube.com/',
            },
            body: jsonEncode({
              'query': trimmed,
              'params': 'EgWKAQIIAWoKEAkQChAFEAMQBA==',
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

      if (res.statusCode != 200) return const [];
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      _captureVisitor(data);

      final songs = <LiteSong>[];
      final fallback = <LiteSong>[];

      final tabs = data['contents']?['tabbedSearchResultsRenderer']?['tabs']
          as List<dynamic>?;
      if (tabs == null || tabs.isEmpty) return const [];
      final sections = tabs[0]['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents'] as List<dynamic>?;
      if (sections == null) return const [];

      for (final sec in sections) {
        final shelf = (sec as Map<String, dynamic>)['musicShelfRenderer']
            as Map<String, dynamic>?;
        if (shelf == null) continue;
        final contents = shelf['contents'] as List<dynamic>? ?? const [];
        for (final raw in contents) {
          final item = (raw as Map<String, dynamic>)['musicResponsiveListItemRenderer']
              as Map<String, dynamic>?;
          if (item == null) continue;
          final vid = item['playlistItemData']?['videoId']?.toString();
          if (vid == null || vid.isEmpty) continue;
          final cols = item['flexColumns'] as List<dynamic>? ?? const [];
          if (cols.isEmpty) continue;

          final col0Runs = cols[0]['musicResponsiveListItemFlexColumnRenderer']
              ?['text']?['runs'] as List<dynamic>?;
          final firstRun = (col0Runs != null && col0Runs.isNotEmpty)
              ? col0Runs[0] as Map<String, dynamic>?
              : null;
          final title = firstRun?['text']?.toString() ?? 'Unknown';
          final mvType = firstRun?['navigationEndpoint']?['watchEndpoint']
                  ?['watchEndpointMusicSupportedConfigs']
                  ?['watchEndpointMusicConfig']?['musicVideoType']
              ?.toString();

          String artist = 'Unknown Artist';
          int durSec = 200;
          String subJoined = '';
          if (cols.length > 1) {
            final col1Runs = cols[1]['musicResponsiveListItemFlexColumnRenderer']
                ?['text']?['runs'] as List<dynamic>?;
            if (col1Runs != null && col1Runs.isNotEmpty) {
              subJoined = col1Runs
                  .map((r) => (r as Map<String, dynamic>)['text']?.toString() ?? '')
                  .join(' ');
              final parts = col1Runs
                  .map((r) => (r as Map<String, dynamic>)['text']?.toString() ?? '')
                  .where((t) =>
                      t.trim().isNotEmpty &&
                      t.trim() != '•' &&
                      t.trim().toLowerCase() != 'lagu' &&
                      t.trim().toLowerCase() != 'song')
                  .toList();
              if (parts.isNotEmpty) artist = parts.first;
              if (parts.length >= 2) durSec = _parseDuration(parts.last);
            }
          }

          final thumbs = item['thumbnail']?['musicThumbnailRenderer']?['thumbnail']
              ?['thumbnails'] as List<dynamic>?;
          String thumb = 'https://i.ytimg.com/vi/$vid/mqdefault.jpg';
          if (thumbs != null && thumbs.isNotEmpty) {
            final rawUrl = (thumbs.first as Map<String, dynamic>)['url']?.toString();
            if (rawUrl != null && rawUrl.isNotEmpty) {
              thumb = _compactThumb(rawUrl);
            }
          }

          final song = LiteSong(
            videoId: vid,
            title: title,
            artist: artist,
            durationSeconds: durSec,
            thumbnailUrl: thumb,
          );

          if (_isJunk(
            title: title,
            subtitle: subJoined,
            mvType: mvType,
            durationSec: durSec,
            rawQuery: trimmed,
          )) {
            if (durSec >= 45 && durSec <= 570) fallback.add(song);
            continue;
          }

          songs.add(song);
          if (songs.length >= limit) break;
        }
        if (songs.length >= limit) break;
      }

      final out = songs.isNotEmpty ? songs : fallback.take(limit).toList();
      if (out.isNotEmpty) {
        if (_searchCache.length >= 20) {
          _searchCache.remove(_searchCache.keys.first);
        }
        _searchCache[key] = out;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Autocomplete search suggestions
  Future<List<String>> getSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final res = await _http
          .post(
            Uri.parse(_suggestUrl),
            headers: const {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Origin': 'https://music.youtube.com',
            },
            body: jsonEncode({
              'input': trimmed,
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
          .timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) return const [];
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final contents = data['contents'] as List<dynamic>? ?? const [];
      final out = <String>[];
      final seen = <String>{};
      for (final sec in contents) {
        final items = (sec as Map<String, dynamic>)
                ['searchSuggestionsSectionRenderer']?['contents']
            as List<dynamic>?;
        if (items == null) continue;
        for (final it in items) {
          final runs = (it as Map<String, dynamic>)['searchSuggestionRenderer']
              ?['suggestion']?['runs'] as List<dynamic>?;
          if (runs == null) continue;
          final txt = runs
              .map((r) => (r as Map<String, dynamic>)['text']?.toString() ?? '')
              .join()
              .trim();
          if (txt.isNotEmpty && seen.add(txt.toLowerCase())) {
            out.add(txt);
            if (out.length >= 6) return out;
          }
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Quick preset feed for the Home tab (Gaming / Mood categories)
  Future<List<LiteSong>> getCategorySongs(String category) async {
    switch (category) {
      case 'Gaming':
        return searchSongs('Phonk EDM Gaming Hype Music NCS', limit: 16);
      case 'Pop Indo':
        return searchSongs('Tulus Bernadya Mahalini Juicy Luicy Lagu', limit: 16);
      case 'Pop Barat':
        return searchSongs('Bruno Mars The Weeknd Billie Eilish Hits', limit: 16);
      case 'Galau':
        return searchSongs('Lagu Galau Indonesia Pop Terbaru', limit: 16);
      case 'Chill':
        return searchSongs('Hindia Pamungkas Lofi Chill Acoustic', limit: 16);
      case 'Anime':
        return searchSongs('YOASOBI Kenshi Yonezu Anime Opening Hits', limit: 16);
      default:
        return searchSongs(category, limit: 16);
    }
  }

  void _extractPanelVideos(dynamic node, List<Map<String, dynamic>> out) {
    if (node is Map<String, dynamic>) {
      final wrapper = node['playlistPanelVideoWrapperRenderer'];
      if (wrapper is Map<String, dynamic>) {
        if (wrapper['primaryRenderer'] != null) {
          _extractPanelVideos(wrapper['primaryRenderer'], out);
        }
        return;
      }
      final vr = node['playlistPanelVideoRenderer'];
      if (vr is Map<String, dynamic>) {
        out.add(vr);
        return;
      }
      for (final v in node.values) {
        if (v is Map || v is List) _extractPanelVideos(v, out);
      }
    } else if (node is List) {
      for (final item in node) {
        if (item is Map || item is List) _extractPanelVideos(item, out);
      }
    }
  }

  Future<void> _fetchRadioBatch({
    required String videoId,
    required String playlistId,
    required String fallbackArtist,
    required Set<String> seen,
    required List<LiteSong> results,
    int maxResults = 24,
  }) async {
    if (results.length >= maxResults) return;
    try {
      final client = <String, dynamic>{
        'clientName': 'WEB_REMIX',
        'clientVersion': '1.20250101.01.00',
        'hl': 'id',
        'gl': 'ID',
        if (_visitorData != null && _visitorData!.isNotEmpty)
          'visitorData': _visitorData,
      };
      final res = await _http
          .post(
            Uri.parse(_nextUrl),
            headers: const {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Origin': 'https://music.youtube.com',
              'Referer': 'https://music.youtube.com/',
            },
            body: jsonEncode({
              'videoId': videoId,
              'playlistId': playlistId,
              'params': 'wAEB',
              'isAudioOnly': true,
              'enablePersistentPlaylistPanel': true,
              'tunerSettingValue': 'AUTOMIX_SETTING_NORMAL',
              'context': {'client': client},
            }),
          )
          .timeout(const Duration(seconds: 9));

      if (res.statusCode != 200) return;
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      _captureVisitor(data);

      final renderers = <Map<String, dynamic>>[];
      final root = data['contents']?['singleColumnMusicWatchNextResultsRenderer'] ??
          data['continuationContents'] ??
          data['contents'];
      _extractPanelVideos(root, renderers);

      for (final r in renderers) {
        final vid = r['videoId']?.toString();
        if (vid == null || vid.isEmpty || !seen.add(vid)) continue;

        final titleRuns = r['title']?['runs'] as List<dynamic>?;
        final title = titleRuns != null
            ? titleRuns
                .map((e) => (e as Map<String, dynamic>)['text']?.toString() ?? '')
                .join()
                .trim()
            : '';
        if (title.isEmpty) continue;

        final mvType = r['navigationEndpoint']?['watchEndpoint']
                ?['watchEndpointMusicSupportedConfigs']
                ?['watchEndpointMusicConfig']?['musicVideoType']
            ?.toString();

        final byline =
            (r['longBylineText']?['runs'] ?? r['shortBylineText']?['runs'])
                as List<dynamic>?;
        String artist = fallbackArtist;
        String bylineJoined = '';
        if (byline != null && byline.isNotEmpty) {
          bylineJoined = byline
              .map((e) => (e as Map<String, dynamic>)['text']?.toString() ?? '')
              .join(' ');
          final firstTxt = (byline.first as Map<String, dynamic>)['text']?.toString().trim();
          if (firstTxt != null && firstTxt.isNotEmpty && firstTxt != '•') {
            artist = firstTxt;
          }
        }

        final durText = r['lengthText']?['runs']?[0]?['text']?.toString() ?? '3:20';
        final durSec = _parseDuration(durText);
        if (_isJunk(
          title: title,
          subtitle: bylineJoined,
          mvType: mvType,
          durationSec: durSec,
        )) {
          continue;
        }

        final thumbs = r['thumbnail']?['thumbnails'] as List<dynamic>? ?? const [];
        String thumb = 'https://i.ytimg.com/vi/$vid/mqdefault.jpg';
        if (thumbs.isNotEmpty) {
          final rawUrl = (thumbs.first as Map<String, dynamic>)['url']?.toString();
          if (rawUrl != null && rawUrl.isNotEmpty) thumb = _compactThumb(rawUrl);
        }

        results.add(
          LiteSong(
            videoId: vid,
            title: title,
            artist: artist,
            durationSeconds: durSec,
            thumbnailUrl: thumb,
          ),
        );
        if (results.length >= maxResults) break;
      }
    } catch (_) {}
  }

  /// Smart Auto-Radio Algorithm (Spotify-style genre/vibe queue via RDAMVM)
  Future<List<LiteSong>> getRadioNext(
    LiteSong seed, {
    Set<String> excludeIds = const {},
  }) async {
    final seen = <String>{seed.videoId, ...excludeIds};
    final out = <LiteSong>[];

    await _fetchRadioBatch(
      videoId: seed.videoId,
      playlistId: 'RDAMVM${seed.videoId}',
      fallbackArtist: seed.artist,
      seen: seen,
      results: out,
      maxResults: 24,
    );

    if (out.length < 6) {
      await _fetchRadioBatch(
        videoId: seed.videoId,
        playlistId: 'RD${seed.videoId}',
        fallbackArtist: seed.artist,
        seen: seen,
        results: out,
        maxResults: 24,
      );
    }

    return out;
  }

  /// Direct audio stream resolver (VISIONOS InnerTube) with 3 quality tiers:
  /// - 'low': ~48-64 kbps (Ultra Hemat / Gaming Ping Aman)
  /// - 'standard': ~96-128 kbps (Normal)
  /// - 'high': ~160+ kbps (Tinggi)
  Future<LiteAudioStream?> resolveStream(
    String videoId, {
    String qualityTier = 'low',
  }) async {
    final key = '${videoId}_$qualityTier';
    final cached = _streamCache[key];
    if (cached != null && cached.isValid) return cached.stream;

    final visitor = await _getVisitorData();
    const clients = [
      {
        'ver': '1.04',
        'model': 'RealityDevice17,1',
        'os': '26.6.0.23O770',
        'ua': 'com.google.visionos.youtube/1.04(RealityDevice17,1; U; CPU visionOS 26_6_0 like Mac OS X; US)',
      },
      {
        'ver': '1.02',
        'model': 'RealityDevice14,1',
        'os': '25.6.0.23O471',
        'ua': 'com.google.visionos.youtube/1.02(RealityDevice14,1; U; CPU visionOS 25_6_0 like Mac OS X; US)',
      },
    ];

    for (final c in clients) {
      try {
        final ua = c['ua']!;
        final tParam = _randToken(12);
        final cpn = _randToken(16);

        final clientCtx = <String, dynamic>{
          'clientName': 'VISIONOS',
          'clientVersion': c['ver'],
          'clientScreen': 'WATCH',
          'platform': 'MOBILE',
          'deviceMake': 'Apple',
          'deviceModel': c['model'],
          'osName': 'visionOS',
          'osVersion': c['os'],
          'hl': 'en-GB',
          'gl': 'US',
          'utcOffsetMinutes': 0,
          if (visitor != null && visitor.isNotEmpty) 'visitorData': visitor,
        };

        final res = await _http
            .post(
              Uri.parse('$_playerBaseUrl&t=$tParam&id=$videoId'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': ua,
                'X-Goog-Api-Format-Version': '2',
                if (visitor != null && visitor.isNotEmpty)
                  'X-Goog-Visitor-Id': visitor,
              },
              body: jsonEncode({
                'context': {'client': clientCtx},
                'videoId': videoId,
                'cpn': cpn,
                'contentCheckOk': true,
                'racyCheckOk': true,
              }),
            )
            .timeout(const Duration(seconds: 9));

        if (res.statusCode != 200) continue;
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        _captureVisitor(data);

        final sd = data['streamingData'] as Map<String, dynamic>? ?? const {};
        final hlsUrl = sd['hlsManifestUrl']?.toString();
        final adaptive = sd['adaptiveFormats'] as List<dynamic>? ?? const [];
        final formats = sd['formats'] as List<dynamic>? ?? const [];

        final audioFormats = <Map<String, dynamic>>[];
        for (final f in [...adaptive, ...formats]) {
          final m = f as Map<String, dynamic>;
          final mime = m['mimeType']?.toString() ?? '';
          final u = m['url']?.toString();
          if (mime.startsWith('audio/') && u != null && u.isNotEmpty) {
            audioFormats.add(m);
          }
        }

        if (audioFormats.isEmpty && (hlsUrl == null || hlsUrl.isEmpty)) {
          continue;
        }

        if (audioFormats.isNotEmpty) {
          audioFormats.sort((a, b) {
            final ab = (a['bitrate'] as num?)?.toInt() ?? 0;
            final bb = (b['bitrate'] as num?)?.toInt() ?? 0;
            return ab.compareTo(bb);
          });

          Map<String, dynamic> chosen;
          if (qualityTier == 'low') {
            chosen = audioFormats.first;
          } else if (qualityTier == 'standard') {
            chosen = audioFormats.firstWhere(
              (f) {
                final br = ((f['bitrate'] as num?)?.toInt() ?? 0) ~/ 1000;
                return br >= 68 && br <= 138;
              },
              orElse: () => audioFormats[audioFormats.length ~/ 2],
            );
          } else {
            chosen = audioFormats.last;
          }

          String streamUrl = chosen['url'].toString();
          final len = int.tryParse(chosen['contentLength']?.toString() ?? '') ?? 0;
          if (!streamUrl.contains('&cpn=')) streamUrl = '$streamUrl&cpn=$cpn';
          if (len > 0 && !streamUrl.contains('&range=')) {
            streamUrl = '$streamUrl&range=0-$len';
          }

          final resolved = LiteAudioStream(
            url: Uri.parse(streamUrl),
            hlsUrl: hlsUrl != null && hlsUrl.isNotEmpty ? Uri.parse(hlsUrl) : null,
            headers: {'User-Agent': ua},
            bitrateKbps:
                (((chosen['bitrate'] as num?)?.toInt() ?? 64000) / 1000).round(),
          );
          if (_streamCache.length >= 24) {
            _streamCache.remove(_streamCache.keys.first);
          }
          _streamCache[key] = _CachedStream(
            resolved,
            DateTime.now().add(const Duration(hours: 2)),
          );
          return resolved;
        } else if (hlsUrl != null && hlsUrl.isNotEmpty) {
          final uri = Uri.parse(hlsUrl);
          final resolved = LiteAudioStream(
            url: uri,
            hlsUrl: uri,
            headers: {'User-Agent': ua},
            bitrateKbps: 96,
          );
          _streamCache[key] = _CachedStream(
            resolved,
            DateTime.now().add(const Duration(hours: 1)),
          );
          return resolved;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> prefetch(String videoId, {String qualityTier = 'low'}) async {
    try {
      await resolveStream(videoId, qualityTier: qualityTier);
    } catch (_) {}
  }
}
