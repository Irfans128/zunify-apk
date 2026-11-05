import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lyric_model.dart';
import '../models/song_model.dart';

class _ScoredLyricsCandidate {
  final SyncedLyrics lyrics;
  final double score;
  final int declaredDurationSec;

  const _ScoredLyricsCandidate({
    required this.lyrics,
    required this.score,
    required this.declaredDurationSec,
  });
}

/// Zunify v1.7 Smart Duration-Fit & Spoken-Intro Aware Lyrics Engine
/// Queries SimpMusic, LRCLIB, and BetterLyrics in parallel and scores every candidate
/// by duration accuracy, timestamp span coverage (start-to-end), spoken intro completeness,
/// and line richness — preventing mismatched studio vs MV/monologue lyrics.
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

  /// Scores a parsed lyrics candidate against the playing track's actual duration.
  /// Catching cases where a shorter studio LRC is attached to a longer spoken-intro track.
  double _scoreLyricsCandidate({
    required List<LyricLine> lines,
    required bool isSynced,
    required int declaredDurationSec,
    required int targetDurationSec,
    required double providerBonus,
  }) {
    if (lines.isEmpty) return -9999;
    if (!isSynced) return 10.0 + lines.length.clamp(0, 40) * 0.4;

    double score = 100.0 + providerBonus;
    final vocalLines = lines
        .where((l) =>
            l.originalText.trim().isNotEmpty &&
            !l.originalText.contains('•'))
        .toList();
    if (vocalLines.isEmpty) return -9999;

    final firstSec = vocalLines.first.timestamp.inMilliseconds / 1000.0;
    final lastSec = vocalLines.last.timestamp.inMilliseconds / 1000.0;

    // 1. Declared duration accuracy
    if (targetDurationSec > 30 && declaredDurationSec > 30) {
      final durDiff = (declaredDurationSec - targetDurationSec).abs();
      if (durDiff <= 3) {
        score += 48.0;
      } else if (durDiff <= 7) {
        score += 32.0;
      } else if (durDiff <= 14) {
        score += 10.0;
      } else {
        score -= (durDiff * 1.8).clamp(15.0, 75.0);
      }
    }

    // 2. Actual timestamp span coverage ( catches mislabeled SimpMusic uploads! )
    if (targetDurationSec > 60) {
      final tailGap = targetDurationSec - lastSec;
      if (tailGap >= 3 && tailGap <= 33) {
        // Last vocal ends naturally before the song's outro
        score += 42.0;
      } else if (tailGap > 36) {
        // Ends way too early -> likely a studio cut LRC on an extended/spoken-intro MV!
        score -= ((tailGap - 30) * 2.1).clamp(20.0, 85.0);
      } else if (tailGap < -6) {
        // Timestamps exceed the audio duration!
        score -= (tailGap.abs() * 3.0).clamp(25.0, 95.0);
      }

      // 3. Spoken intro / early vocal coverage bonus:
      // If the LRC starts early (<= 14s) AND still reaches the end of the song,
      // it includes the spoken monologue / intro verse!
      if (firstSec <= 14.0 && tailGap >= 2 && tailGap <= 34) {
        score += 34.0;
      }
    }

    // 4. Completeness / line count bonus
    score += (vocalLines.length.clamp(0, 65) * 1.15);

    // 5. True Word-by-Word / Syllable Synced Bonus (Apple Music TTML / RichSync)
    final wordSyncedCount = vocalLines.where((l) => l.words.length > 1).length;
    if (wordSyncedCount >= (vocalLines.length * 0.4)) {
      score += 18.0;
    }

    return score;
  }

  /// Fetches the most accurate synced lyrics by racing SimpMusic, LRCLIB, and BetterLyrics
  /// in parallel and picking the candidate that best fits the song's duration & intro structure.
  Future<SyncedLyrics> fetchRawLyricsInstant(ZunifySong song) async {
    final cached = _memoryLyricsCache[song.videoId];
    if (cached != null && cached.lines.length > 1) {
      return cached;
    }

    final cleanTitle = _cleanSongTitle(song.title);
    final cleanArtist = _cleanArtistName(song.artist);

    // Query all 3 synced providers in parallel so we can compare completeness & duration fit
    final results = await Future.wait([
      _fetchCandidatesFromSimpMusic(song.videoId, song.durationSeconds),
      _fetchCandidatesFromLrclib(
        song,
        cleanTitle: cleanTitle,
        cleanArtist: cleanArtist,
      ),
      _fetchCandidateFromBetterLyrics(
        song.videoId,
        cleanTitle.isNotEmpty ? cleanTitle : song.title,
        cleanArtist.isNotEmpty ? cleanArtist : song.artist,
        song.durationSeconds,
      ),
    ]);

    final allCandidates = <_ScoredLyricsCandidate>[
      ...results[0],
      ...results[1],
      ...results[2],
    ];

    if (allCandidates.isNotEmpty) {
      allCandidates.sort((a, b) => b.score.compareTo(a.score));
      final best = allCandidates.first;
      final aligned = _alignExtendedIntroIfNeeded(
        best.lyrics,
        declaredDurationSec: best.declaredDurationSec,
        targetDurationSec: song.durationSeconds,
      );
      _cacheLyrics(song.videoId, aligned);
      return aligned;
    }

    // 4. Fallback to YouTube Music Official Built-in Lyrics (`MPLYt_...` tab)
    final ytmResult = await _fetchFromYouTubeMusicMplyt(song);
    if (ytmResult != null) {
      _cacheLyrics(song.videoId, ytmResult);
      return ytmResult;
    }

    return _emptyFallback(song.videoId);
  }

  /// If a song's audio is an MV with a long spoken/cinematic intro (e.g. 310s)
  /// and the only available LRC in the world is for the shorter studio cut (e.g. 265s),
  /// automatically shifts the timestamps by the intro offset so vocals still sync!
  SyncedLyrics _alignExtendedIntroIfNeeded(
    SyncedLyrics lyrics, {
    required int declaredDurationSec,
    required int targetDurationSec,
  }) {
    if (!lyrics.isSynced || lyrics.lines.length < 4 || targetDurationSec < 120) {
      return lyrics;
    }

    final vocalLines = lyrics.lines
        .where((l) =>
            l.originalText.trim().isNotEmpty &&
            !l.originalText.contains('•'))
        .toList();
    if (vocalLines.isEmpty) return lyrics;

    final firstSec = vocalLines.first.timestamp.inSeconds;
    final lastSec = vocalLines.last.timestamp.inSeconds;
    final tailGap = targetDurationSec - lastSec;

    // Only auto-shift if the LRC clearly starts after >15s AND ends >38s too early
    // AND its declared duration is shorter than the audio track by 22..75s
    if (firstSec >= 15 && tailGap >= 38 && declaredDurationSec > 60) {
      final deltaSec = targetDurationSec - declaredDurationSec;
      if (deltaSec >= 22 && deltaSec <= 75) {
        final offset = Duration(seconds: deltaSec);
        final offsetMs = offset.inMilliseconds;
        final shifted = <LyricLine>[
          const LyricLine(
            timestamp: Duration.zero,
            originalText: '♪ • • • ♪',
          ),
          ...lyrics.lines
              .where((l) => !l.originalText.contains('•'))
              .map(
                (l) => LyricLine(
                  timestamp: l.timestamp + offset,
                  endTimeMs:
                      l.endTimeMs != null ? l.endTimeMs! + offsetMs : null,
                  originalText: l.originalText,
                  translatedIndoText: l.translatedIndoText,
                  words: l.words
                      .map(
                        (w) => LyricWord(
                          text: w.text,
                          startMs: w.startMs + offsetMs,
                          endMs: w.endMs + offsetMs,
                        ),
                      )
                      .toList(),
                ),
              ),
        ];
        return lyrics.copyWith(lines: shifted);
      }
    }
    return lyrics;
  }

  /// Stage 2: Translates non-Indonesian lyrics into Bahasa Indonesia in background
  Future<SyncedLyrics> translateLyricsToIndonesian(SyncedLyrics rawLyrics) async {
    if (rawLyrics.isOriginalIndonesian || rawLyrics.lines.length <= 1) {
      return rawLyrics;
    }

    final alreadyTranslated =
        rawLyrics.lines.any((l) => l.translatedIndoText != null);
    if (alreadyTranslated) {
      return rawLyrics;
    }

    final simpTrans = await _trySimpMusicTranslation(rawLyrics);
    if (simpTrans != null) {
      _cacheLyrics(rawLyrics.videoId, simpTrans);
      return simpTrans;
    }

    final translatedLines = await _translateLinesWithGoogle(rawLyrics.lines);
    final stillIndonesian =
        translatedLines.every((l) => l.translatedIndoText == null);

    final updated = rawLyrics.copyWith(
      lines: translatedLines,
      isOriginalIndonesian:
          stillIndonesian ? true : rawLyrics.isOriginalIndonesian,
    );
    _cacheLyrics(rawLyrics.videoId, updated);
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
  Future<List<_ScoredLyricsCandidate>> _fetchCandidatesFromSimpMusic(
    String videoId,
    int totalDurationSec,
  ) async {
    final candidates = <_ScoredLyricsCandidate>[];
    try {
      final res = await _http
          .get(
            Uri.parse('$_simpMusicBase/$videoId'),
            headers: {'User-Agent': _simpMusicUa},
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) return candidates;

      final decoded =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final dataList = decoded['data'] as List<dynamic>? ?? [];
      if (dataList.isEmpty) return candidates;

      for (final raw in dataList) {
        final item = raw as Map<String, dynamic>;
        // Prefer richSyncLyrics first when available because it carries per-word <mm:ss.xx> tags!
        final rawRich = item['richSyncLyrics']?.toString();
        final rawStd = item['syncedLyrics']?.toString();
        final rawSynced = (rawRich != null && rawRich.trim().isNotEmpty)
            ? rawRich
            : rawStd;
        final rawPlain = item['plainLyric']?.toString();
        final itemDur =
            (item['durationSeconds'] as num?)?.toInt() ?? totalDurationSec;

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
        if (lines.isEmpty) continue;

        final sample = lines.map((e) => e.originalText).join(' ');
        final lyr = SyncedLyrics(
          videoId: videoId,
          isSynced: isSynced,
          isOriginalIndonesian: detectIsIndonesian(sample),
          lines: lines,
          sourceName: isSynced ? 'SimpMusic Synced' : 'SimpMusic Lyrics',
        );

        final score = _scoreLyricsCandidate(
          lines: lines,
          isSynced: isSynced,
          declaredDurationSec: itemDur,
          targetDurationSec: totalDurationSec,
          providerBonus: 6.0,
        );

        candidates.add(
          _ScoredLyricsCandidate(
            lyrics: lyr,
            score: score,
            declaredDurationSec: itemDur,
          ),
        );
      }
    } catch (_) {}
    return candidates;
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
      final decoded =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>?;
      final transLrc = data?['translatedLyric']?.toString();
      if (transLrc == null || transLrc.trim().isEmpty) return null;

      final transLines = _parseLrcFormat(transLrc);
      if (transLines.isEmpty) return null;

      final merged = <LyricLine>[];
      for (int i = 0; i < rawLyrics.lines.length; i++) {
        final orig = rawLyrics.lines[i];
        if (orig.originalText.contains('•')) {
          merged.add(orig);
          continue;
        }
        String? matchText;
        for (final tl in transLines) {
          if ((tl.timestamp.inMilliseconds - orig.timestamp.inMilliseconds)
                  .abs() <=
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
  Future<List<_ScoredLyricsCandidate>> _fetchCandidateFromBetterLyrics(
    String videoId,
    String title,
    String artist,
    int totalDurationSec,
  ) async {
    try {
      final uri = Uri.parse(_betterLyricsUrl).replace(
        queryParameters: {'s': title, 'a': artist},
      );
      final res = await _http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return const [];

      final decoded =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final ttml = decoded['ttml']?.toString() ?? '';
      if (ttml.isEmpty) return const [];

      final lines = _parseTtmlFormat(ttml);
      if (lines.isEmpty) return const [];

      final estimatedDur = lines.last.timestamp.inSeconds + 16;
      final sample = lines.map((e) => e.originalText).join(' ');
      final lyr = SyncedLyrics(
        videoId: videoId,
        isSynced: true,
        isOriginalIndonesian: detectIsIndonesian(sample),
        lines: lines,
        sourceName: 'Apple Music Synced',
      );

      final score = _scoreLyricsCandidate(
        lines: lines,
        isSynced: true,
        declaredDurationSec: estimatedDur,
        targetDurationSec: totalDurationSec,
        providerBonus: 4.0,
      );

      return [
        _ScoredLyricsCandidate(
          lyrics: lyr,
          score: score,
          declaredDurationSec: estimatedDur,
        ),
      ];
    } catch (_) {
      return const [];
    }
  }

  List<LyricLine> _parseTtmlFormat(String ttml) {
    final lines = <LyricLine>[];
    final pRegExp = RegExp(
      r'<p([^>]*)>(.*?)</p>',
      dotAll: true,
    );
    final spanRegExp = RegExp(
      r'<span([^>]*)>(.*?)</span>',
      dotAll: true,
    );
    final beginAttr = RegExp(r'begin="([^"]+)"');
    final endAttr = RegExp(r'end="([^"]+)"');

    for (final m in pRegExp.allMatches(ttml)) {
      final pAttrs = m.group(1) ?? '';
      final innerHtml = m.group(2) ?? '';
      final beginMatch = beginAttr.firstMatch(pAttrs);
      if (beginMatch == null) continue;

      final pStartMs = _parseTtmlTimestampMs(beginMatch.group(1)!.trim());
      final endMatch = endAttr.firstMatch(pAttrs);
      final pEndMs = endMatch != null
          ? _parseTtmlTimestampMs(endMatch.group(1)!.trim())
          : null;

      final parsedWords = <LyricWord>[];
      for (final sm in spanRegExp.allMatches(innerHtml)) {
        final sAttrs = sm.group(1) ?? '';
        final rawWordHtml = sm.group(2) ?? '';
        final wText = _decodeXmlEntities(
          rawWordHtml.replaceAll(RegExp(r'<[^>]+>'), ''),
        ).trim();
        if (wText.isEmpty) continue;
        final sb = beginAttr.firstMatch(sAttrs);
        final se = endAttr.firstMatch(sAttrs);
        if (sb != null) {
          final ws = _parseTtmlTimestampMs(sb.group(1)!.trim());
          final we = se != null
              ? _parseTtmlTimestampMs(se.group(1)!.trim())
              : (ws + 260);
          parsedWords.add(
            LyricWord(
              text: wText,
              startMs: ws,
              endMs: we > ws ? we : ws + 180,
            ),
          );
        }
      }

      final cleanText = parsedWords.isNotEmpty
          ? parsedWords.map((w) => w.text).join(' ')
          : _decodeXmlEntities(
              innerHtml.replaceAll(RegExp(r'<[^>]+>'), ' '),
            ).replaceAll(RegExp(r'\s+'), ' ').trim();

      if (cleanText.isEmpty) continue;

      lines.add(
        LyricLine(
          timestamp: Duration(milliseconds: pStartMs),
          endTimeMs: pEndMs ??
              (parsedWords.isNotEmpty ? parsedWords.last.endMs : null),
          originalText: cleanText,
          words: parsedWords,
        ),
      );
    }
    return _finalizeWordTimingsAndInterludes(lines);
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
  // Evaluates ALL matching tracks in LRCLIB so spoken-intro versions (e.g. 308s)
  // and studio versions (e.g. 272s) each get their exact matching LRC!
  // ---------------------------------------------------------------------------
  Future<List<_ScoredLyricsCandidate>> _fetchCandidatesFromLrclib(
    ZunifySong song, {
    required String cleanTitle,
    required String cleanArtist,
  }) async {
    final candidates = <_ScoredLyricsCandidate>[];
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
        final uri =
            Uri.parse('$_lrclibBase/search').replace(queryParameters: q);
        final res = await _http
            .get(
              uri,
              headers: {'User-Agent': 'Zunify/1.7.0 (Crafted by Fannz)'},
            )
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          items = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
          if (items.isNotEmpty) break;
        }
      }

      if (items.isEmpty) return candidates;

      final targetTitleLower =
          (cleanTitle.isNotEmpty ? cleanTitle : song.title).toLowerCase();

      for (final item in items.take(15)) {
        final map = item as Map<String, dynamic>;
        final trackName = (map['trackName']?.toString() ?? '').toLowerCase();
        // Skip unrelated songs returned by broad search
        if (targetTitleLower.length >= 4 &&
            trackName.isNotEmpty &&
            !trackName.contains(targetTitleLower) &&
            !targetTitleLower.contains(trackName)) {
          continue;
        }

        final rawSynced = map['syncedLyrics'] as String?;
        final rawPlain = map['plainLyrics'] as String?;
        final itemDur =
            (map['duration'] as num?)?.round() ?? song.durationSeconds;

        List<LyricLine> parsedLines = [];
        bool isSynced = false;

        if (rawSynced != null && rawSynced.trim().isNotEmpty) {
          parsedLines = _parseLrcFormat(rawSynced);
          isSynced = parsedLines.isNotEmpty;
        }
        if (parsedLines.isEmpty &&
            rawPlain != null &&
            rawPlain.trim().isNotEmpty) {
          parsedLines = _parsePlainLines(rawPlain, song.durationSeconds);
          isSynced = false;
        }
        if (parsedLines.isEmpty) continue;

        // Verify that timestamps are actually progressing (rejects broken LRCs where all lines have the same timestamp)
        if (isSynced && parsedLines.length >= 5) {
          final spanSec = parsedLines.last.timestamp.inSeconds -
              parsedLines.first.timestamp.inSeconds;
          if (spanSec < 25) continue;
        }

        final sample = parsedLines.map((e) => e.originalText).join(' ');
        final lyr = SyncedLyrics(
          videoId: song.videoId,
          isSynced: isSynced,
          isOriginalIndonesian: detectIsIndonesian(sample),
          lines: parsedLines,
          sourceName: isSynced ? 'LRCLIB Synced' : 'LRCLIB Plain',
        );

        final score = _scoreLyricsCandidate(
          lines: parsedLines,
          isSynced: isSynced,
          declaredDurationSec: itemDur,
          targetDurationSec: song.durationSeconds,
          providerBonus: 5.0,
        );

        candidates.add(
          _ScoredLyricsCandidate(
            lyrics: lyr,
            score: score,
            declaredDurationSec: itemDur,
          ),
        );
      }
    } catch (_) {}
    return candidates;
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
      final tabs = nextData['contents']
              ?['singleColumnMusicWatchNextResultsRenderer']?['tabbedRenderer']
              ?['watchNextTabbedResultsRenderer']?['tabs']
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
      final contents = browseData['contents']?['sectionListRenderer']
          ?['contents'] as List<dynamic>?;
      if (contents == null || contents.isEmpty) return null;

      final runs = (contents.first
              as Map<String, dynamic>)['musicDescriptionShelfRenderer']
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

  int _parseLrcTimeTokenMs(String minsStr, String secsStr, String? fracStr) {
    final mins = int.tryParse(minsStr) ?? 0;
    final secs = int.tryParse(secsStr) ?? 0;
    final msRaw = fracStr ?? '0';
    int millis = int.tryParse(msRaw) ?? 0;
    if (msRaw.length == 1) {
      millis *= 100;
    } else if (msRaw.length == 2) {
      millis *= 10;
    }
    return (mins * 60 + secs) * 1000 + millis;
  }

  List<LyricLine> _parseLrcFormat(String lrcContent) {
    final rawParsed = <LyricLine>[];
    final regExp = RegExp(r'^\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?\](.*)');
    final wordTagRegExp = RegExp(
      r'[<\[](\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?[>\]]([^<\[]*)',
    );

    for (final rawLine in lrcContent.split('\n')) {
      final match = regExp.firstMatch(rawLine.trim());
      if (match != null) {
        final lineStartMs = _parseLrcTimeTokenMs(
          match.group(1)!,
          match.group(2)!,
          match.group(3),
        );
        final rawBody = match
            .group(4)!
            .replaceAll(RegExp(r'^v\d+:\s*', caseSensitive: false), '');

        // Extract inline RichSync word timestamps like <00:12.34>word if present
        final parsedWords = <LyricWord>[];
        final wordMatches = wordTagRegExp.allMatches(rawBody).toList();
        if (wordMatches.isNotEmpty) {
          for (int i = 0; i < wordMatches.length; i++) {
            final wm = wordMatches[i];
            final wStart = _parseLrcTimeTokenMs(
              wm.group(1)!,
              wm.group(2)!,
              wm.group(3),
            );
            final wText = (wm.group(4) ?? '').trim();
            if (wText.isEmpty) continue;
            int wEnd = wStart + 280;
            if (i + 1 < wordMatches.length) {
              final nextStart = _parseLrcTimeTokenMs(
                wordMatches[i + 1].group(1)!,
                wordMatches[i + 1].group(2)!,
                wordMatches[i + 1].group(3),
              );
              if (nextStart > wStart) wEnd = nextStart;
            }
            parsedWords.add(
              LyricWord(text: wText, startMs: wStart, endMs: wEnd),
            );
          }
        }

        final text = rawBody
            .replaceAll(RegExp(r'<\d{1,2}:\d{2}(?:[\.:]\d{1,3})?>'), ' ')
            .replaceAll(RegExp(r'\[\d{1,2}:\d{2}(?:[\.:]\d{1,3})?\]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        rawParsed.add(
          LyricLine(
            timestamp: Duration(milliseconds: lineStartMs),
            endTimeMs: parsedWords.isNotEmpty ? parsedWords.last.endMs : null,
            originalText: text,
            words: parsedWords,
          ),
        );
      }
    }

    // Filter out empty lines unless they mark a real musical interlude (>= 6s gap)
    final cleaned = <LyricLine>[];
    for (int i = 0; i < rawParsed.length; i++) {
      final cur = rawParsed[i];
      if (cur.originalText.isNotEmpty) {
        cleaned.add(cur);
      } else if (cleaned.isNotEmpty && i + 1 < rawParsed.length) {
        final next = rawParsed[i + 1];
        final gapMs =
            next.timestamp.inMilliseconds - cur.timestamp.inMilliseconds;
        if (gapMs >= 6000 && !cleaned.last.originalText.contains('•')) {
          cleaned.add(
            LyricLine(
              timestamp: cur.timestamp,
              endTimeMs: next.timestamp.inMilliseconds,
              originalText: '♪ • • • ♪',
            ),
          );
        }
      }
    }

    return _finalizeWordTimingsAndInterludes(cleaned);
  }

  /// Synthesizes natural Apple Music Sing vocal cadence for lines without explicit word tags,
  /// and inserts `♪ • • • ♪` 3-dot markers for intros (>= 3.5s) and instrumental breaks (>= 6.5s).
  List<LyricLine> _finalizeWordTimingsAndInterludes(List<LyricLine> input) {
    if (input.isEmpty) return input;
    final out = <LyricLine>[];

    // 1. If the first vocal line starts at >= 3.5s, insert a 3-dot intro row at 00:00
    final firstStartMs = input.first.timestamp.inMilliseconds;
    if (firstStartMs >= 3500 && !input.first.originalText.contains('•')) {
      out.add(
        LyricLine(
          timestamp: Duration.zero,
          endTimeMs: firstStartMs,
          originalText: '♪ • • • ♪',
        ),
      );
    }

    for (int i = 0; i < input.length; i++) {
      final cur = input[i];
      if (cur.originalText.contains('•')) {
        final nextMs = i + 1 < input.length
            ? input[i + 1].timestamp.inMilliseconds
            : (cur.timestamp.inMilliseconds + 6000);
        out.add(cur.copyWith(endTimeMs: nextMs));
        continue;
      }

      final startMs = cur.timestamp.inMilliseconds;
      final nextLineStartMs = i + 1 < input.length
          ? input[i + 1].timestamp.inMilliseconds
          : (startMs + 4800);
      final availableSpanMs = (nextLineStartMs - startMs).clamp(600, 60000);

      List<LyricWord> words = cur.words;
      int lineEndMs = cur.endTimeMs ?? (startMs + availableSpanMs);

      if (words.isEmpty) {
        final rawTokens = cur.originalText
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList();

        if (rawTokens.isNotEmpty) {
          // Estimate natural human singing duration for each word (syllable & punctuation aware)
          final weights = <int>[];
          int naturalTotalMs = 200;
          for (int wIdx = 0; wIdx < rawTokens.length; wIdx++) {
            final token = rawTokens[wIdx];
            final cleanLen =
                token.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').length.clamp(1, 14);
            int wMs = 155 + (cleanLen * 56);
            if (token.endsWith(',') ||
                token.endsWith('.') ||
                token.endsWith('!') ||
                token.endsWith('?')) {
              wMs += 190; // breath pause after punctuation
            }
            if (wIdx == rawTokens.length - 1) {
              wMs += 240; // vocal sustain on last word of line
            }
            weights.add(wMs);
            naturalTotalMs += wMs;
          }

          // Never stretch vocal sweep across a long silent instrumental pause!
          final maxSingSpan = (availableSpanMs - 140).clamp(500, 60000);
          final actualSingSpanMs = naturalTotalMs < maxSingSpan
              ? naturalTotalMs
              : maxSingSpan;
          lineEndMs = startMs + actualSingSpanMs;

          final totalWeight = weights.fold<int>(0, (a, b) => a + b).clamp(1, 999999);
          int cursorMs = startMs;
          final builtWords = <LyricWord>[];
          for (int wIdx = 0; wIdx < rawTokens.length; wIdx++) {
            final sliceMs =
                ((weights[wIdx] / totalWeight) * actualSingSpanMs).round();
            final wEnd = (wIdx == rawTokens.length - 1)
                ? lineEndMs
                : (cursorMs + sliceMs).clamp(cursorMs + 60, lineEndMs);
            builtWords.add(
              LyricWord(
                text: rawTokens[wIdx],
                startMs: cursorMs,
                endMs: wEnd,
              ),
            );
            cursorMs = wEnd;
          }
          words = builtWords;
        }
      }

      out.add(
        cur.copyWith(
          endTimeMs: lineEndMs,
          words: words,
        ),
      );

      // 2. If there is an instrumental pause of >= 6.5s after the singer finishes this line
      // before the next line starts, insert the 3 animated dots (`♪ • • • ♪`)!
      if (i + 1 < input.length && !input[i + 1].originalText.contains('•')) {
        final silentRestMs = nextLineStartMs - lineEndMs;
        if (silentRestMs >= 6500) {
          out.add(
            LyricLine(
              timestamp: Duration(milliseconds: lineEndMs + 300),
              endTimeMs: nextLineStartMs,
              originalText: '♪ • • • ♪',
            ),
          );
        }
      }
    }

    return out;
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
  Future<List<LyricLine>> _translateLinesWithGoogle(
    List<LyricLine> lines,
  ) async {
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
        if (orig.contains('•')) {
          updated.add(lines[i]);
          continue;
        }
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
