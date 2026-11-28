import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song_model.dart';
import 'ytmusic_service.dart';

/// Zunify v3.0 Lossless FLAC Audio Engine (Monochrome / HiFi Tidal Public APIs)
/// - Dynamically fetches live instance registry from `monochrome-music/monochrome`
/// - Health-caches fastest working servers per session (zero wasted delay on dead nodes)
/// - Strict title + artist + duration matching to prevent wrong track / remix mismatches
/// - Decodes direct BTS FLAC streams (`16-bit/44.1kHz LOSSLESS` & `24-bit HI_RES_LOSSLESS`)
///   natively playable in Android ExoPlayer (`just_audio`), returning `null` quickly so
///   Zunify falls back seamlessly to YouTube Music High Quality whenever unavailable.
class LosslessAudioService {
  static const String _instancesRegistryUrl =
      'https://raw.githubusercontent.com/monochrome-music/monochrome/main/public/instances.json';

  static const List<String> _fallbackApiInstances = [
    'https://api.monochrome.tf',
    'https://arran.monochrome.tf',
    'https://eu-central.monochrome.tf',
    'https://us-west.monochrome.tf',
    'https://triton.squid.wtf',
    'https://wolf.qqdl.site',
    'https://maus.qqdl.site',
    'https://vogel.qqdl.site',
    'https://hund.qqdl.site',
    'https://tidal.kinoplus.online',
  ];

  static const List<String> _fallbackStreamingInstances = [
    'https://arran.monochrome.tf',
    'https://triton.squid.wtf',
    'https://wolf.qqdl.site',
    'https://maus.qqdl.site',
    'https://vogel.qqdl.site',
    'https://katze.qqdl.site',
    'https://hund.qqdl.site',
    'https://hifi.p1nkhamster.xyz',
  ];

  static const String _ua =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36';

  final http.Client _http;

  List<String> _apiInstances = List.of(_fallbackApiInstances);
  List<String> _streamingInstances = List.of(_fallbackStreamingInstances);
  DateTime? _registryLoadedAt;
  String? _preferredApiHost;
  String? _preferredStreamHost;
  final Map<String, DateTime> _failedHostsUntil = {};
  final Map<String, _CachedLosslessResult> _trackCache = {};

  LosslessAudioService({http.Client? client}) : _http = client ?? http.Client() {
    unawaited(_refreshInstancesRegistry());
  }

  Future<void> _refreshInstancesRegistry() async {
    if (_registryLoadedAt != null &&
        DateTime.now().difference(_registryLoadedAt!).inHours < 6) {
      return;
    }
    try {
      final res = await _http
          .get(
            Uri.parse(_instancesRegistryUrl),
            headers: const {'User-Agent': _ua},
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(utf8.decode(res.bodyBytes));
        if (json is Map<String, dynamic>) {
          final apiList = (json['api'] as List<dynamic>?)
              ?.map((e) => e.toString().trim().replaceAll(RegExp(r'/+$'), ''))
              .where((e) => e.startsWith('http'))
              .toList();
          final streamList = (json['streaming'] as List<dynamic>?)
              ?.map((e) => e.toString().trim().replaceAll(RegExp(r'/+$'), ''))
              .where((e) => e.startsWith('http'))
              .toList();
          if (apiList != null && apiList.isNotEmpty) {
            _apiInstances = apiList;
          }
          if (streamList != null && streamList.isNotEmpty) {
            _streamingInstances = streamList;
          }
          _registryLoadedAt = DateTime.now();
        }
      }
    } catch (_) {}
  }

  bool _isHostCoolingDown(String host) {
    final until = _failedHostsUntil[host];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _failedHostsUntil.remove(host);
      return false;
    }
    return true;
  }

  void _markHostFailed(String host) {
    _failedHostsUntil[host] = DateTime.now().add(const Duration(minutes: 8));
    if (_preferredApiHost == host) _preferredApiHost = null;
    if (_preferredStreamHost == host) _preferredStreamHost = null;
  }

  List<String> _orderedHealthyHosts(List<String> pool, String? preferred) {
    final healthy = <String>[];
    if (preferred != null && !_isHostCoolingDown(preferred)) {
      healthy.add(preferred);
    }
    for (final h in pool) {
      if (h != preferred && !_isHostCoolingDown(h)) {
        healthy.add(h);
      }
    }
    // If every single host cooled down, allow retrying the top 3 fresh
    if (healthy.isEmpty) {
      return pool.take(3).toList();
    }
    return healthy;
  }

  /// Resolves a verified Lossless FLAC stream for [song], or returns `null` quickly
  /// if no accurate Lossless match / healthy server is available.
  Future<ResolvedAudioStream?> resolveLosslessStream(ZunifySong song) async {
    final cached = _trackCache[song.videoId];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.stream;
    }

    // Skip obvious non-studio / DJ / remix / karaoke uploads that won't match Tidal Lossless
    final lowerTitle = song.title.toLowerCase();
    if (RegExp(
      r'\b(slowed|sped\s*up|nightcore|8d\s*audio|jedag\s*jedug|dj\s+remix|koplo|karaoke|mashup|lofi\s*remix)\b',
    ).hasMatch(lowerTitle)) {
      return null;
    }

    try {
      await _refreshInstancesRegistry().timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () {},
      );

      final cleanTitle = _cleanTitle(song.title);
      final cleanArtist = _cleanArtist(song.artist);
      if (cleanTitle.isEmpty) return null;

      final match = await _searchBestTrack(
        cleanTitle: cleanTitle,
        cleanArtist: cleanArtist,
        rawTitle: song.title,
        targetDurationSec: song.durationSeconds,
      );
      if (match == null) {
        _cacheMiss(song.videoId);
        return null;
      }

      final stream = await _fetchFlacStreamForTrackId(match.id);
      if (stream != null) {
        if (_trackCache.length > 40) {
          _trackCache.remove(_trackCache.keys.first);
        }
        _trackCache[song.videoId] = _CachedLosslessResult(
          stream: stream,
          expiresAt: DateTime.now().add(const Duration(minutes: 45)),
        );
        return stream;
      }
    } catch (_) {}
    return null;
  }

  void _cacheMiss(String videoId) {
    if (_trackCache.length > 40) {
      _trackCache.remove(_trackCache.keys.first);
    }
    _trackCache[videoId] = _CachedLosslessResult(
      stream: null,
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  Future<_TidalMatch?> _searchBestTrack({
    required String cleanTitle,
    required String cleanArtist,
    required String rawTitle,
    required int targetDurationSec,
  }) async {
    final query = '$cleanArtist $cleanTitle'.trim();
    final hosts = _orderedHealthyHosts(_apiInstances, _preferredApiHost);
    if (hosts.isEmpty) return null;

    // Race top 3 healthy hosts in parallel so first responding server wins immediately
    final batch = hosts.take(3).toList();
    final completer = Completer<Map<String, dynamic>?>();
    int remaining = batch.length;

    for (final host in batch) {
      unawaited(() async {
        try {
          final uri = Uri.parse('$host/search/').replace(
            queryParameters: {'s': query},
          );
          final res = await _http
              .get(uri, headers: const {'User-Agent': _ua})
              .timeout(const Duration(seconds: 3));
          if (res.statusCode == 200) {
            final decoded = jsonDecode(utf8.decode(res.bodyBytes));
            if (decoded is Map<String, dynamic>) {
              final items = _extractSearchItems(decoded);
              if (items.isNotEmpty) {
                _preferredApiHost = host;
                if (!completer.isCompleted) {
                  completer.complete({'items': items});
                }
                return;
              }
            }
          } else if (res.statusCode >= 500 || res.statusCode == 404) {
            _markHostFailed(host);
          }
        } catch (_) {
          _markHostFailed(host);
        } finally {
          remaining--;
          if (remaining <= 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }());
    }

    final winner = await completer.future.timeout(
      const Duration(milliseconds: 3400),
      onTimeout: () => null,
    );
    if (winner == null) return null;

    final items = winner['items'] as List<dynamic>? ?? const [];
    return _pickBestMatchingTrack(
      items,
      cleanTitle: cleanTitle,
      cleanArtist: cleanArtist,
      rawTitle: rawTitle,
      targetDurationSec: targetDurationSec,
    );
  }

  List<dynamic> _extractSearchItems(Map<String, dynamic> data) {
    final direct = data['items'];
    if (direct is List) return direct;
    final inner = data['data'];
    if (inner is Map<String, dynamic>) {
      if (inner['items'] is List) return inner['items'] as List<dynamic>;
      final tracks = inner['tracks'];
      if (tracks is Map<String, dynamic> && tracks['items'] is List) {
        return tracks['items'] as List<dynamic>;
      }
    }
    final tracks = data['tracks'];
    if (tracks is Map<String, dynamic> && tracks['items'] is List) {
      return tracks['items'] as List<dynamic>;
    }
    return const [];
  }

  _TidalMatch? _pickBestMatchingTrack(
    List<dynamic> items, {
    required String cleanTitle,
    required String cleanArtist,
    required String rawTitle,
    required int targetDurationSec,
  }) {
    final normTitle = _normalizeForMatch(cleanTitle);
    final normArtist = _normalizeForMatch(cleanArtist);
    final rawLower = rawTitle.toLowerCase();
    final wantsAcoustic = rawLower.contains('acoustic');
    final wantsLive = rawLower.contains('live');
    final wantsRemix = rawLower.contains('remix');
    final wantsInstrumental = rawLower.contains('instrumental');

    _TidalMatch? best;
    double bestScore = -1.0;

    for (final rawItem in items.take(12)) {
      if (rawItem is! Map<String, dynamic>) continue;
      final id = rawItem['id'];
      if (id == null) continue;
      final itemTitle = rawItem['title']?.toString() ?? '';
      final version = rawItem['version']?.toString() ?? '';
      final fullTitle =
          version.isNotEmpty ? '$itemTitle ($version)' : itemTitle;
      if (itemTitle.isEmpty) continue;

      final lowerFull = fullTitle.toLowerCase();
      if (!wantsAcoustic && lowerFull.contains('acoustic')) continue;
      if (!wantsLive && RegExp(r'\blive\b').hasMatch(lowerFull)) continue;
      if (!wantsRemix && lowerFull.contains('remix')) continue;
      if (!wantsInstrumental && lowerFull.contains('instrumental')) continue;
      if (lowerFull.contains('karaoke') || lowerFull.contains('tribute')) {
        continue;
      }

      // Extract artist names
      final artistNames = <String>[];
      final mainArtist = rawItem['artist'];
      if (mainArtist is Map && mainArtist['name'] != null) {
        artistNames.add(mainArtist['name'].toString());
      }
      final artistsList = rawItem['artists'];
      if (artistsList is List) {
        for (final a in artistsList) {
          if (a is Map && a['name'] != null) {
            artistNames.add(a['name'].toString());
          }
        }
      }
      final joinedArtists = _normalizeForMatch(artistNames.join(' '));
      final normItemTitle = _normalizeForMatch(itemTitle);

      // Title match score
      double score = 0.0;
      if (normItemTitle == normTitle) {
        score += 55.0;
      } else if (normItemTitle.contains(normTitle) ||
          normTitle.contains(normItemTitle)) {
        score += 36.0;
      } else {
        final overlap = _tokenOverlap(normTitle, normItemTitle);
        if (overlap < 0.65) continue;
        score += overlap * 34.0;
      }

      // Artist match score
      if (normArtist.isNotEmpty && joinedArtists.isNotEmpty) {
        if (joinedArtists.contains(normArtist) ||
            normArtist.contains(joinedArtists)) {
          score += 35.0;
        } else {
          final aOverlap = _tokenOverlap(normArtist, joinedArtists);
          if (aOverlap < 0.45) continue;
          score += aOverlap * 30.0;
        }
      }

      // Duration match check (critical so MV vs studio or wrong covers never mismatch)
      final dur = (rawItem['duration'] as num?)?.round() ?? 0;
      if (targetDurationSec > 30 && dur > 30) {
        final diff = (dur - targetDurationSec).abs();
        if (diff <= 2) {
          score += 24.0;
        } else if (diff <= 5) {
          score += 14.0;
        } else if (diff <= 8) {
          score += 4.0;
        } else {
          // Duration off by >8s -> skip to avoid wrong cut / lyric desync!
          continue;
        }
      }

      // Bonus for explicit LOSSLESS / HI_RES_LOSSLESS tag
      final quality = rawItem['audioQuality']?.toString().toUpperCase() ?? '';
      if (quality.contains('LOSSLESS')) {
        score += 8.0;
      }

      if (score > bestScore) {
        bestScore = score;
        best = _TidalMatch(id: id.toString(), durationSec: dur);
      }
    }

    if (bestScore < 62.0) return null;
    return best;
  }

  Future<ResolvedAudioStream?> _fetchFlacStreamForTrackId(
    String trackId,
  ) async {
    final hosts =
        _orderedHealthyHosts(_streamingInstances, _preferredStreamHost);
    if (hosts.isEmpty) return null;

    // Request LOSSLESS (16-bit/44.1kHz BTS direct FLAC URL, 100% natively playable in ExoPlayer)
    for (final host in hosts.take(3)) {
      try {
        final uri = Uri.parse('$host/track/').replace(
          queryParameters: {
            'id': trackId,
            'quality': 'LOSSLESS',
          },
        );
        final res = await _http
            .get(uri, headers: const {'User-Agent': _ua})
            .timeout(const Duration(seconds: 3));
        if (res.statusCode != 200) {
          if (res.statusCode >= 500 || res.statusCode == 404) {
            _markHostFailed(host);
          }
          continue;
        }

        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        final parsed = _parseTrackStreamResponse(decoded);
        if (parsed != null) {
          _preferredStreamHost = host;
          return parsed;
        }
      } catch (_) {
        _markHostFailed(host);
      }
    }
    return null;
  }

  ResolvedAudioStream? _parseTrackStreamResponse(dynamic root) {
    Map<String, dynamic>? info;
    String? directUrl;

    if (root is Map<String, dynamic>) {
      final inner = root['data'];
      if (inner is Map<String, dynamic>) {
        info = inner;
      } else {
        info = root;
      }
      directUrl = info['OriginalTrackUrl']?.toString();
    } else if (root is List) {
      for (final entry in root) {
        if (entry is Map<String, dynamic>) {
          if (entry.containsKey('manifest')) info = entry;
          if (directUrl == null && entry['OriginalTrackUrl'] is String) {
            directUrl = entry['OriginalTrackUrl'] as String;
          }
        }
      }
    }

    String? streamUrl =
        (directUrl != null && directUrl.startsWith('http')) ? directUrl : null;
    String mimeType = 'audio/flac';

    if (streamUrl == null && info != null) {
      final manifest = info['manifest'];
      if (manifest is String && manifest.isNotEmpty) {
        final extracted = _extractUrlFromManifest(manifest);
        if (extracted != null) {
          streamUrl = extracted.$1;
          if (extracted.$2 != null && extracted.$2!.isNotEmpty) {
            mimeType = extracted.$2!;
          }
        }
      } else if (manifest is Map<String, dynamic>) {
        final urls = manifest['urls'];
        if (urls is List && urls.isNotEmpty) {
          streamUrl = urls.first.toString();
        }
        if (manifest['mimeType'] is String) {
          mimeType = manifest['mimeType'].toString();
        }
      }
    }

    if (streamUrl == null || !streamUrl.startsWith('http')) return null;

    final bitDepth = (info?['bitDepth'] as num?)?.toInt() ?? 16;
    final sampleRate = (info?['sampleRate'] as num?)?.toInt() ?? 44100;
    final isFlac = mimeType.toLowerCase().contains('flac') ||
        streamUrl.toLowerCase().contains('.flac');
    final khz = sampleRate >= 1000
        ? (sampleRate % 1000 == 0
            ? '${sampleRate ~/ 1000}kHz'
            : '${(sampleRate / 1000.0).toStringAsFixed(1)}kHz')
        : '44.1kHz';

    final String label = isFlac
        ? (bitDepth >= 24
            ? 'HI-RES FLAC • $bitDepth-bit $khz'
            : 'FLAC • $bitDepth-bit $khz')
        : 'LOSSLESS • $khz';

    return ResolvedAudioStream(
      url: Uri.parse(streamUrl),
      headers: const {'User-Agent': _ua},
      bitrateKbps: isFlac ? (bitDepth >= 24 ? 2100 : 950) : 320,
      mimeType: mimeType,
      isLossless: true,
      formatLabel: label,
      fileExtension: isFlac ? 'flac' : 'm4a',
    );
  }

  (String, String?)? _extractUrlFromManifest(String rawManifest) {
    String decodedText = rawManifest.trim();
    if (!decodedText.startsWith('{') && !decodedText.startsWith('<')) {
      try {
        decodedText = utf8.decode(base64Decode(decodedText));
      } catch (_) {
        return null;
      }
    }

    // 1. JSON BTS Manifest (`application/vnd.tidal.bts`) -> direct FLAC URL
    if (decodedText.startsWith('{')) {
      try {
        final map = jsonDecode(decodedText) as Map<String, dynamic>;
        final mime = map['mimeType']?.toString();
        final urls = map['urls'];
        if (urls is List && urls.isNotEmpty) {
          final candidates = urls
              .map((e) => e.toString())
              .where((u) => u.startsWith('http'))
              .toList();
          if (candidates.isNotEmpty) {
            // Prefer explicit FLAC URL if multiple present
            final flacPick = candidates.firstWhere(
              (u) => u.toLowerCase().contains('flac'),
              orElse: () => candidates.first,
            );
            return (flacPick, mime);
          }
        }
      } catch (_) {}
    }

    return null;
  }

  String _cleanTitle(String raw) {
    return raw
        .replaceAll(
          RegExp(
            r'\s*[\(\[][^)\]]*(official|video|lyric|lirik|audio|mv|visualizer|remaster|hd|4k|feat\.?|ft\.?|with\s)[^)\]]*[\)\]]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\s+(?:feat\.?|ft\.?)\s+.*$', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+-\s+.*$'), '')
        .trim();
  }

  String _cleanArtist(String raw) {
    return raw
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(?:feat\.?|ft\.?|&|,).*$', caseSensitive: false), '')
        .trim();
  }

  String _normalizeForMatch(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"['’`]"), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _tokenOverlap(String a, String b) {
    final ta = a.split(' ').where((w) => w.length >= 2).toSet();
    final tb = b.split(' ').where((w) => w.length >= 2).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0.0;
    final common = ta.intersection(tb).length;
    final denom = ta.length < tb.length ? ta.length : tb.length;
    return denom > 0 ? common / denom : 0.0;
  }
}

class _TidalMatch {
  final String id;
  final int durationSec;
  const _TidalMatch({required this.id, required this.durationSec});
}

class _CachedLosslessResult {
  final ResolvedAudioStream? stream;
  final DateTime expiresAt;
  const _CachedLosslessResult({required this.stream, required this.expiresAt});
}
