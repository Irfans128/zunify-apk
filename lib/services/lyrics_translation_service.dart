import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lyric_model.dart';
import '../models/song_model.dart';

/// Zunify v1.3 4-Layer Synced Karaoke Lyrics & Smart Bahasa Indonesia Translation Service
/// Inspired by AusDMusic (`SimpMusicLyricsClient` + `BetterLyrics` + `YouTube Music MPLYt` + `LRCLIB`)
/// 1. SimpMusic Lyrics API (`https://api-lyrics.simpmusic.org/v1/{videoId}`) with `SimpMusicLyrics/1.0.0` UA
/// 2. Apple Music / BetterLyrics TTML (`https://lyrics-api.boidu.dev/getLyrics`)
/// 3. LRCLIB Synced Database (`https://lrclib.net/api/search`)
/// 4. YouTube Music Official Lyrics (`https://music.youtube.com/youtubei/v1/next` -> `MPLYt_...`)
class LyricsTranslationService {
  static const String _simpMusicBase = 'https://api-lyrics.simpmusic.org/v1';
  static const String _simpMusicUa = 'SimpMusicLyrics/1.0.0';
  static const String _betterLyricsUrl = 'https://lyrics-api.boidu.dev/getLyrics';
  static const String _lrclibBase = 'https://lrclib.net/api';
  static const String _ytmNextUrl =
      'https://music.youtube.com/youtubei/v1/next?prettyPrint=false';
  static const String _ytmBrowseUrl =
      'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false';

  final Map<String, SyncedLyrics> _memoryLyricsCache = {};
  final http.Client _http = http.Client();

  void _cacheLyrics(String videoId, SyncedLyrics lyrics) {
    if (_memoryLyricsCache.length > 50) {
      _memoryLyricsCache.remove(_memoryLyricsCache.keys.first);
    }
    _memoryLyricsCache[videoId] = lyrics;
  }

  // Common Indonesian words to accurately detect Bahasa Indonesia lyrics
  static const Set<String> _indonesianMarkers = {
    'yang', 'dan', 'aku', 'kamu', 'kau', 'kita', 'tidak', 'tak', 'bisa',
    'dengan', 'untuk', 'dalam', 'karena', 'jika', 'bila', 'saat', 'hati',
    'cinta', 'rindu', 'malam', 'hari', 'ini', 'itu', 'ada', 'lagi',
    'pernah', 'selalu', 'hanya', 'ingin', 'mengapa', 'kenapa', 'jangan',
    'masih', 'telah', 'sudah', 'akan', 'sampai', 'bahagia', 'luka',
    'sendiri', 'bersama', 'dirimu', 'diriku', 'ku', 'mu', 'nya',
  };

  String _cleanSongTitle(String raw) {
    return raw
        .replaceAll(
          RegExp(
            r'\s*[\(\[][^)\]]*(official|video|lyric|lirik|audio|mv|visualizer|remaster|live|hd|4k|karaoke)[^)\]]*[\)\]]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+-\s+.*$'), '')
        .trim();
  }

  String _cleanArtistName(String raw) {
    return raw
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(feat\.|ft\.|&|,).*$', caseSensitive: false), '')
        .trim();
  }

  /// Stage 1: Fetches synced/plain lyrics as fast as possible (< 400ms) from the 4 providers
  /// so the UI can display lyrics immediately while translation loads in the background.
  Future<SyncedLyrics> fetchRawLyricsInstant(ZunifySong song) async {
    final cached = _memoryLyricsCache[song.videoId];
    if (cached != null && cached.lines.length > 1) {
      return cached;
    }

    final cleanTitle = _cleanSongTitle(song.title);
    final cleanArtist = _cleanArtistName(song.artist);

    // 1. Try SimpMusic Lyrics API by videoId (AusDMusic Primary Source)
    final simpResult =
        await _fetchFromSimpMusic(song.videoId, song.durationSeconds);
    if (simpResult != null && simpResult.isSynced) {
      _cacheLyrics(song.videoId, simpResult);
      return simpResult;
    }

    // 2 & 3. Query Apple Music / BetterLyrics TTML + LRCLIB in parallel for instant fallback
    final parallelResults = await Future.wait([
      _fetchFromBetterLyrics(
        song.videoId,
        cleanTitle.isNotEmpty ? cleanTitle : song.title,
        cleanArtist.isNotEmpty ? cleanArtist : song.artist,
      ),
      _fetchFromLrclib(
        song,
        cleanTitle: cleanTitle,
        cleanArtist: cleanArtist,
      ),
    ]);

    final betterResult = parallelResults[0];
    final lrcResult = parallelResults[1];

    if (betterResult != null && betterResult.isSynced) {
      _cacheLyrics(song.videoId, betterResult);
      return betterResult;
    }
    if (lrcResult != null && lrcResult.isSynced) {
      _cacheLyrics(song.videoId, lrcResult);
      return lrcResult;
    }
    if (simpResult != null) {
      _cacheLyrics(song.videoId, simpResult);
      return simpResult;
    }
    if (betterResult != null) {
      _cacheLyrics(song.videoId, betterResult);
      return betterResult;
    }
    if (lrcResult != null) {
      _cacheLyrics(song.videoId, lrcResult);
      return lrcResult;
    }

    // 4. Try YouTube Music Official Built-in Lyrics (`MPLYt_...` tab)
    final ytmResult = await _fetchFromYouTubeMusicMplyt(song);
    if (ytmResult != null) {
      _cacheLyrics(song.videoId, ytmResult);
      return ytmResult;
    }

    return _emptyFallback(song.videoId);
  }

  /// Stage 2: Translates non-Indonesian lyrics into Bahasa Indonesia in background
  Future<SyncedLyrics> translateLyricsToIndonesian(SyncedLyrics rawLyrics) async {
    if (rawLyrics.isOriginalIndonesian || rawLyrics.lines.length <= 1) {
      return rawLyrics;
    }

    // Check if already translated
    final alreadyTranslated =
        rawLyrics.lines.any((l) => l.translatedIndoText != null);
    if (alreadyTranslated) {
      return rawLyrics;
    }

    // Try SimpMusic Translated Lyrics DB first (`/v1/translated/{videoId}/id`)
    final simpTrans = await _trySimpMusicTranslation(rawLyrics);
    if (simpTrans != null) {
      _memoryLyricsCache[rawLyrics.videoId] = simpTrans;
      return simpTrans;
    }

    // Otherwise batch-translate with Google Translate GTX
    final translatedLines = await _translateLinesWithGoogle(rawLyrics.lines);
    final stillIndonesian =
        translatedLines.every((l) => l.translatedIndoText == null);

    final updated = rawLyrics.copyWith(
      lines: translatedLines,
      isOriginalIndonesian:
          stillIndonesian ? true : rawLyrics.isOriginalIndonesian,
    );
    _memoryLyricsCache[rawLyrics.videoId] = updated;
    return updated;
  }

  /// Full 2-stage helper (used by Offline Vault Downloader & direct callers)
  Future<SyncedLyrics> fetchSyncedBilingualLyrics(ZunifySong song) async {
    final cached = _memoryLyricsCache[song.videoId];
    if (cached != null &&
        cached.lines.length > 1 &&
        (cached.isOriginalIndonesian ||
            cached.lines.any((l) => l.translatedIndoText != null))) {
      return cached;
    }
    final raw = await fetchRawLyricsInstant(song);
    if (raw.lines.length <= 1 || raw.isOriginalIndonesian) {
      return raw;
    }
    return translateLyricsToIndonesian(raw);
  }

  // ---------------------------------------------------------------------------
  // PROVIDER 1: SimpMusic Lyrics API (`https://api-lyrics.simpmusic.org/v1`)
  // ---------------------------------------------------------------------------
  Future<SyncedLyrics?> _fetchFromSimpMusic(
    String videoId,
    int totalDurationSec,
  ) async {
    try {
      final res = await _http
          .get(
            Uri.parse('$_simpMusicBase/$videoId'),
            headers: {'User-Agent': _simpMusicUa},
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final dataList = decoded['data'] as List<dynamic>? ?? [];
      if (dataList.isEmpty) return null;

      // Pick item with syncedLyrics or richSyncLyrics first
      Map<String, dynamic>? chosen;
      for (final raw in dataList) {
        final item = raw as Map<String, dynamic>;
        final synced = item['syncedLyrics']?.toString() ?? '';
        final rich = item['richSyncLyrics']?.toString() ?? '';
        if (synced.trim().isNotEmpty || rich.trim().isNotEmpty) {
          chosen = item;
          break;
        }
      }
      chosen ??= dataList.first as Map<String, dynamic>;

      final rawSynced =
          (chosen['syncedLyrics']?.toString().trim().isNotEmpty == true)
              ? chosen['syncedLyrics'].toString()
              : chosen['richSyncLyrics']?.toString();
      final rawPlain = chosen['plainLyric']?.toString();

      List<LyricLine> lines = [];
      bool isSynced = false;

      if (rawSynced != null && rawSynced.trim().isNotEmpty) {
        lines = _parseLrcFormat(rawSynced);
        isSynced = lines.isNotEmpty;
      }
      if (lines.isEmpty && rawPlain != null && rawPlain.trim().isNotEmpty) {
        lines = _parsePlainLines(rawPlain, totalDurationSec);
        isSynced = false;
      }
      if (lines.isEmpty) return null;

      final sample = lines.map((e) => e.originalText).join(' ');
      return SyncedLyrics(
        videoId: videoId,
        isSynced: isSynced,
        isOriginalIndonesian: detectIsIndonesian(sample),
        lines: lines,
        sourceName: isSynced ? 'SimpMusic Synced' : 'SimpMusic Lyrics',
      );
    } catch (_) {
      return null;
    }
  }

  Future<SyncedLyrics?> _trySimpMusicTranslation(SyncedLyrics rawLyrics) async {
    try {
      final res = await _http
          .get(
            Uri.parse('$_simpMusicBase/translated/${rawLyrics.videoId}/id'),
            headers: {'User-Agent': _simpMusicUa},
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>?;
      final transLrc = data?['translatedLyric']?.toString();
      if (transLrc == null || transLrc.trim().isEmpty) return null;

      final transLines = _parseLrcFormat(transLrc);
      if (transLines.isEmpty) return null;

      // Match by timestamp proximity or index
      final merged = <LyricLine>[];
      for (int i = 0; i < rawLyrics.lines.length; i++) {
        final orig = rawLyrics.lines[i];
        String? matchText;
        for (final tl in transLines) {
          if ((tl.timestamp.inMilliseconds - orig.timestamp.inMilliseconds).abs() <=
              1200) {
            matchText = tl.originalText;
            break;
          }
        }
        if (matchText == null && i < transLines.length) {
          matchText = transLines[i].originalText;
        }
        merged.add(orig.copyWith(translatedIndoText: matchText));
      }

      return rawLyrics.copyWith(lines: merged);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PROVIDER 2: BetterLyrics / Apple Music TTML (`lyrics-api.boidu.dev`)
  // ---------------------------------------------------------------------------
  Future<SyncedLyrics?> _fetchFromBetterLyrics(
    String videoId,
    String title,
    String artist,
  ) async {
    try {
      final uri = Uri.parse(_betterLyricsUrl).replace(
        queryParameters: {'s': title, 'a': artist},
      );
      final res = await _http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final ttml = decoded['ttml']?.toString() ?? '';
      if (ttml.isEmpty) return null;

      final lines = _parseTtmlFormat(ttml);
      if (lines.isEmpty) return null;

      final sample = lines.map((e) => e.originalText).join(' ');
      return SyncedLyrics(
        videoId: videoId,
        isSynced: true,
        isOriginalIndonesian: detectIsIndonesian(sample),
        lines: lines,
        sourceName: 'Apple Music Synced',
      );
    } catch (_) {
      return null;
    }
  }

  List<LyricLine> _parseTtmlFormat(String ttml) {
    final lines = <LyricLine>[];
    final pRegExp = RegExp(
      r'<p[^>]*begin="([^"]+)"[^>]*>(.*?)</p>',
      dotAll: true,
    );

    for (final m in pRegExp.allMatches(ttml)) {
      final beginStr = m.group(1)!.trim();
      final innerHtml = m.group(2)!;
      final cleanText = _decodeXmlEntities(
        innerHtml.replaceAll(RegExp(r'<[^>]+>'), ' '),
      ).replaceAll(RegExp(r'\s+'), ' ').trim();

      if (cleanText.isEmpty) continue;

      final ms = _parseTtmlTimestampMs(beginStr);
      lines.add(
        LyricLine(
          timestamp: Duration(milliseconds: ms),
          originalText: cleanText,
        ),
      );
    }
    return lines;
  }

  int _parseTtmlTimestampMs(String raw) {
    final s = raw.replaceAll('s', '').trim();
    if (s.contains(':')) {
      final parts = s.split(':');
      if (parts.length == 2) {
        final mins = int.tryParse(parts[0]) ?? 0;
        final secs = double.tryParse(parts[1]) ?? 0.0;
        return ((mins * 60 + secs) * 1000).round();
      } else if (parts.length == 3) {
        final hrs = int.tryParse(parts[0]) ?? 0;
        final mins = int.tryParse(parts[1]) ?? 0;
        final secs = double.tryParse(parts[2]) ?? 0.0;
        return (((hrs * 3600) + (mins * 60) + secs) * 1000).round();
      }
    }
    final secs = double.tryParse(s) ?? 0.0;
    return (secs * 1000).round();
  }

  String _decodeXmlEntities(String input) {
    return input
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  // ---------------------------------------------------------------------------
  // PROVIDER 3: LRCLIB (`https://lrclib.net/api/search`)
  // ---------------------------------------------------------------------------
  Future<SyncedLyrics?> _fetchFromLrclib(
    ZunifySong song, {
    required String cleanTitle,
    required String cleanArtist,
  }) async {
    try {
      final queries = <Map<String, String>>[
        {
          'track_name': cleanTitle.isNotEmpty ? cleanTitle : song.title,
          'artist_name': cleanArtist.isNotEmpty ? cleanArtist : song.artist,
        },
        {'q': '$cleanArtist $cleanTitle'.trim()},
        {'q': cleanTitle.isNotEmpty ? cleanTitle : song.title},
      ];

      List<dynamic> items = [];
      for (final q in queries) {
        final uri = Uri.parse('$_lrclibBase/search').replace(queryParameters: q);
        final res = await _http
            .get(
              uri,
              headers: {'User-Agent': 'Zunify/1.6.1 (Crafted by Fannz)'},
            )
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          items = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
          if (items.isNotEmpty) break;
        }
      }

      if (items.isEmpty) return null;

      Map<String, dynamic>? chosen;
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        if ((map['syncedLyrics'] as String?)?.trim().isNotEmpty == true) {
          chosen = map;
          break;
        }
      }
      chosen ??= items.first as Map<String, dynamic>;

      final rawSynced = chosen['syncedLyrics'] as String?;
      final rawPlain = chosen['plainLyrics'] as String?;

      List<LyricLine> parsedLines = [];
      bool isSynced = false;

      if (rawSynced != null && rawSynced.trim().isNotEmpty) {
        parsedLines = _parseLrcFormat(rawSynced);
        isSynced = parsedLines.isNotEmpty;
      }
      if (parsedLines.isEmpty && rawPlain != null && rawPlain.trim().isNotEmpty) {
        parsedLines = _parsePlainLines(rawPlain, song.durationSeconds);
        isSynced = false;
      }

      if (parsedLines.isEmpty) return null;

      final sample = parsedLines.map((e) => e.originalText).join(' ');
      return SyncedLyrics(
        videoId: song.videoId,
        isSynced: isSynced,
        isOriginalIndonesian: detectIsIndonesian(sample),
        lines: parsedLines,
        sourceName: isSynced ? 'LRCLIB Synced' : 'LRCLIB Plain',
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PROVIDER 4: YouTube Music Built-In Lyrics (`MPLYt_...` via `/next` & `/browse`)
  // ---------------------------------------------------------------------------
  Future<SyncedLyrics?> _fetchFromYouTubeMusicMplyt(ZunifySong song) async {
    try {
      final contextPayload = {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20250101.01.00',
          'hl': 'id',
          'gl': 'ID',
        },
      };

      final nextRes = await _http
          .post(
            Uri.parse(_ytmNextUrl),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Origin': 'https://music.youtube.com',
            },
            body: jsonEncode({
              'videoId': song.videoId,
              'context': contextPayload,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (nextRes.statusCode != 200) return null;
      final nextData =
          jsonDecode(utf8.decode(nextRes.bodyBytes)) as Map<String, dynamic>;
      final tabs = nextData['contents']?['singleColumnMusicWatchNextResultsRenderer']
              ?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs']
          as List<dynamic>?;
      if (tabs == null) return null;

      String? lyricsBrowseId;
      for (final t in tabs) {
        final bid = (t as Map<String, dynamic>)['tabRenderer']?['endpoint']
                ?['browseEndpoint']?['browseId']
            ?.toString();
        if (bid != null && bid.startsWith('MPLYt')) {
          lyricsBrowseId = bid;
          break;
        }
      }
      if (lyricsBrowseId == null) return null;

      final browseRes = await _http
          .post(
            Uri.parse(_ytmBrowseUrl),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Origin': 'https://music.youtube.com',
            },
            body: jsonEncode({
              'browseId': lyricsBrowseId,
              'context': contextPayload,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (browseRes.statusCode != 200) return null;
      final browseData =
          jsonDecode(utf8.decode(browseRes.bodyBytes)) as Map<String, dynamic>;
      final contents = browseData['contents']?['sectionListRenderer']?['contents']
          as List<dynamic>?;
      if (contents == null || contents.isEmpty) return null;

      final runs = (contents.first as Map<String, dynamic>)['musicDescriptionShelfRenderer']
          ?['description']?['runs'] as List<dynamic>?;
      if (runs == null || runs.isEmpty) return null;

      final plainText = runs
          .map((r) => (r as Map<String, dynamic>)['text']?.toString() ?? '')
          .join();
      if (plainText.trim().isEmpty) return null;

      final lines = _parsePlainLines(plainText, song.durationSeconds);
      if (lines.isEmpty) return null;

      final sample = lines.map((e) => e.originalText).join(' ');
      return SyncedLyrics(
        videoId: song.videoId,
        isSynced: false,
        isOriginalIndonesian: detectIsIndonesian(sample),
        lines: lines,
        sourceName: 'YouTube Music',
      );
    } catch (_) {
      return null;
    }
  }

  /// Smart Bahasa Indonesia Detector
  bool detectIsIndonesian(String text) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toList();

    if (words.isEmpty) return false;

    int indoHits = 0;
    for (final w in words) {
      if (_indonesianMarkers.contains(w) ||
          w.startsWith('ber') ||
          w.startsWith('men') ||
          w.startsWith('ter') ||
          w.endsWith('kan') ||
          w.endsWith('nya')) {
        indoHits++;
      }
    }

    final ratio = indoHits / words.length;
    return ratio >= 0.14;
  }

  List<LyricLine> _parseLrcFormat(String lrcContent) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?\](.*)');

    for (final rawLine in lrcContent.split('\n')) {
      final match = regExp.firstMatch(rawLine.trim());
      if (match != null) {
        final mins = int.tryParse(match.group(1)!) ?? 0;
        final secs = int.tryParse(match.group(2)!) ?? 0;
        final msRaw = match.group(3) ?? '0';
        int millis = int.tryParse(msRaw) ?? 0;
        if (msRaw.length == 1) {
          millis *= 100;
        } else if (msRaw.length == 2) {
          millis *= 10;
        }

        // Strip any secondary word-level timestamps like <00:08.50> inside richSyncLyrics
        final text = match
            .group(4)!
            .replaceAll(RegExp(r'<\d{1,2}:\d{2}(?:[\.:]\d{1,3})?>'), '')
            .replaceAll(RegExp(r'\[\d{1,2}:\d{2}(?:[\.:]\d{1,3})?\]'), '')
            .replaceAll(RegExp(r'^v\d+:\s*', caseSensitive: false), '')
            .trim();

        if (text.isNotEmpty) {
          lines.add(
            LyricLine(
              timestamp: Duration(
                minutes: mins,
                seconds: secs,
                milliseconds: millis,
              ),
              originalText: text,
            ),
          );
        }
      }
    }
    return lines;
  }

  List<LyricLine> _parsePlainLines(String plain, int totalDurationSec) {
    final rawLines = plain
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (rawLines.isEmpty) return [];

    final effectiveDur = totalDurationSec > 30 ? totalDurationSec : 210;
    final stepMs = ((effectiveDur * 1000) / rawLines.length).round();
    return List.generate(
      rawLines.length,
      (i) => LyricLine(
        timestamp: Duration(milliseconds: i * stepMs),
        originalText: rawLines[i],
      ),
    );
  }

  /// Batch-translates non-Indonesian lyric lines into Bahasa Indonesia
  Future<List<LyricLine>> _translateLinesWithGoogle(List<LyricLine> lines) async {
    try {
      final joinedText = lines.map((l) => l.originalText).join('\n');
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single',
      ).replace(
        queryParameters: {
          'client': 'gtx',
          'sl': 'auto',
          'tl': 'id',
          'dt': 't',
          'q': joinedText,
        },
      );

      final res = await _http
          .get(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return lines;

      final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      final detectedLang = decoded.length > 2 ? (decoded[2] as String?) : null;

      if (detectedLang == 'id') {
        return lines;
      }

      final segments = decoded[0] as List<dynamic>;
      final translatedBuffer = StringBuffer();
      for (final seg in segments) {
        if (seg is List && seg.isNotEmpty && seg[0] != null) {
          translatedBuffer.write(seg[0].toString());
        }
      }

      final translatedLines = translatedBuffer.toString().split('\n');
      final updated = <LyricLine>[];

      for (int i = 0; i < lines.length; i++) {
        final orig = lines[i].originalText.trim();
        final trans =
            i < translatedLines.length ? translatedLines[i].trim() : null;

        final shouldKeep = trans != null &&
            trans.isNotEmpty &&
            trans.toLowerCase() != orig.toLowerCase();

        updated.add(
          lines[i].copyWith(translatedIndoText: shouldKeep ? trans : null),
        );
      }
      return updated;
    } catch (_) {
      return lines;
    }
  }

  SyncedLyrics _emptyFallback(String videoId) {
    return SyncedLyrics(
      videoId: videoId,
      isSynced: false,
      isOriginalIndonesian: true,
      sourceName: 'Instrumental',
      lines: const [
        LyricLine(
          timestamp: Duration.zero,
          originalText: '♪ Instrumental / Lirik belum tersedia ♪',
        ),
      ],
    );
  }
}
