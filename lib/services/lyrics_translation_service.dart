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
  static const String _lyricsPlusUrl = 'https://lyricsplus.binimum.org/v2/lyrics/get';
  static const String _lrclibBase = 'https://lrclib.net/api';
  static const String _ytmNextUrl =
      'https://music.youtube.com/youtubei/v1/next?prettyPrint=false';
  static const String _ytmBrowseUrl =
      'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false';

  final Map<String, SyncedLyrics> _memoryLyricsCache = {};
  final Map<String, List<SyncedLyrics>> _providerOptionsCache = {};
  final http.Client _http = http.Client();

  List<SyncedLyrics> getProviderOptionsForVideo(String videoId) =>
      _providerOptionsCache[videoId] ?? const [];

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
            r'\s*[\(\[][^)\]]*(official|video|lyric|lirik|audio|mv|visualizer|remaster|live|hd|4k|karaoke|feat\.?|ft\.?|with\s)[^)\]]*[\)\]]',
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
    // Unsynced plain lyrics must NEVER outscore real synced LRC/TTML candidates!
    if (!isSynced) return -500.0 + lines.length.clamp(0, 40) * 0.4;

    double score = 300.0 + providerBonus;
    final vocalLines = lines
        .where((l) =>
            l.originalText.trim().isNotEmpty &&
            !l.originalText.contains('•'))
        .toList();
    if (vocalLines.isEmpty) return -9999;

    final firstSec = vocalLines.first.timestamp.inMilliseconds / 1000.0;
    final lastSec = vocalLines.last.timestamp.inMilliseconds / 1000.0;
    if (lastSec - firstSec < 20.0) return -600.0;

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
    final wordSyncedCount = vocalLines.where((l) => l.hasExactWordTiming && l.words.length > 1).length;
    if (wordSyncedCount >= (vocalLines.length * 0.4)) {
      score += 18.0;
    }

    // 6. Duet / Multi-Singer Agent Bonus (v1 & v2 left-right split like Spotify / Apple Music)
    final hasV1 = vocalLines.any((l) => l.vocalAgent == 'v1');
    final hasV2 = vocalLines.any((l) => l.vocalAgent == 'v2');
    if (hasV1 && hasV2) {
      score += 22.0;
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

    // Query all 5 synced providers in parallel so we can compare completeness & duration fit
    final results = await Future.wait([
      _fetchCandidatesFromSimpMusic(song.videoId, song.durationSeconds),
      _fetchCandidatesFromLrclib(
        song,
        cleanTitle: cleanTitle,
        cleanArtist: cleanArtist,
      ),
      _fetchCandidateFromLyricsPlus(
        song.videoId,
        cleanTitle.isNotEmpty ? cleanTitle : song.title,
        cleanArtist.isNotEmpty ? cleanArtist : song.artist,
        song.durationSeconds,
      ),
      _fetchCandidateFromLrcRed(
        song.videoId,
        cleanTitle.isNotEmpty ? cleanTitle : song.title,
        cleanArtist.isNotEmpty ? cleanArtist : song.artist,
        song.durationSeconds,
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
      ...results[3],
      ...results[4],
    ];

    if (allCandidates.isNotEmpty) {
      allCandidates.sort((a, b) => b.score.compareTo(a.score));

      // Store top candidate per unique provider for BitChord's "Pilih Penyedia Lirik" switcher
      final seenProviders = <String>{};
      final providerList = <SyncedLyrics>[];
      for (final c in allCandidates) {
        final alignedCandidate = _alignExtendedIntroIfNeeded(
          c.lyrics.isSynced
              ? c.lyrics
              : SyncedLyrics(
                  videoId: c.lyrics.videoId,
                  isSynced: true,
                  isOriginalIndonesian: c.lyrics.isOriginalIndonesian,
                  lines: c.lyrics.lines,
                  sourceName: '${c.lyrics.sourceName} (Auto)',
                ),
          declaredDurationSec: c.declaredDurationSec,
          targetDurationSec: song.durationSeconds,
        );
        if (seenProviders.add(alignedCandidate.sourceName)) {
          providerList.add(alignedCandidate);
        }
      }
      if (_providerOptionsCache.length > 30) {
        _providerOptionsCache.remove(_providerOptionsCache.keys.first);
      }
      _providerOptionsCache[song.videoId] = providerList;

      final aligned = providerList.first;
      _cacheLyrics(song.videoId, aligned);
      return aligned;
    }

    // 4. Fallback to YouTube Music Official Built-in Lyrics (`MPLYt_...` tab)
    final ytmResult = await _fetchFromYouTubeMusicMplyt(song);
    if (ytmResult != null) {
      final syncedYtm = SyncedLyrics(
        videoId: ytmResult.videoId,
        isSynced: true,
        isOriginalIndonesian: ytmResult.isOriginalIndonesian,
        lines: ytmResult.lines,
        sourceName: ytmResult.sourceName,
      );
      _providerOptionsCache[song.videoId] = [syncedYtm];
      _cacheLyrics(song.videoId, syncedYtm);
      return syncedYtm;
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
                (l) => l.copyWith(
                  timestamp: l.timestamp + offset,
                  endTimeMs:
                      l.endTimeMs != null ? l.endTimeMs! + offsetMs : null,
                  words: l.words
                      .map(
                        (w) => LyricWord(
                          text: w.text,
                          startMs: w.startMs + offsetMs,
                          endMs: w.endMs + offsetMs,
                        ),
                      )
                      .toList(),
                  backgroundWords: l.backgroundWords
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
  // PROVIDER 0: LrcRed Enhanced Word-Synced LRC (`https://lrc.red` from BitChord)
  // ---------------------------------------------------------------------------
  Future<List<_ScoredLyricsCandidate>> _fetchCandidateFromLrcRed(
    String videoId,
    String title,
    String artist,
    int totalDurationSec,
  ) async {
    try {
      final q = Uri.encodeComponent('$artist $title'.trim());
      final searchRes = await _http
          .get(
            Uri.parse('https://lrc.red/search.json?q=$q'),
            headers: const {'User-Agent': 'Zunify/1.7'},
          )
          .timeout(const Duration(seconds: 5));
      if (searchRes.statusCode != 200) return const [];
      final decoded = jsonDecode(utf8.decode(searchRes.bodyBytes));
      final hits = decoded['hits'] as List<dynamic>? ?? const [];
      if (hits.isEmpty) return const [];

      Map<String, dynamic>? bestHit;
      int bestDiff = 999999;
      final tLower = title.toLowerCase();
      for (final h in hits.take(5)) {
        if (h is! Map<String, dynamic>) continue;
        final isrc = h['isrc']?.toString() ?? '';
        if (isrc.isEmpty) continue;
        final hTitle = h['title']?.toString().toLowerCase() ?? '';
        if (!hTitle.contains(tLower) && !tLower.contains(hTitle)) continue;
        final dur = ((h['duration'] as num?)?.toDouble() ?? 0).round();
        final diff =
            totalDurationSec > 0 && dur > 0 ? (dur - totalDurationSec).abs() : 0;
        if (diff < bestDiff) {
          bestDiff = diff;
          bestHit = h;
        }
      }
      bestHit ??= hits.first as Map<String, dynamic>?;
      final isrc = bestHit?['isrc']?.toString() ?? '';
      if (isrc.isEmpty) return const [];
      final hitDur = ((bestHit?['duration'] as num?)?.toDouble() ?? 0).round();

      final lrcRes = await _http
          .get(
            Uri.parse('https://lrc.red/s/$isrc.lrc'),
            headers: const {'User-Agent': 'Zunify/1.7'},
          )
          .timeout(const Duration(seconds: 5));
      if (lrcRes.statusCode != 200) return const [];
      final lrcText = utf8.decode(lrcRes.bodyBytes);
      if (lrcText.trim().isEmpty) return const [];

      final lines = _parseLrcFormat(lrcText);
      if (lines.length < 3) return const [];
      final hasWordSync = lines.any((l) => l.words.isNotEmpty);
      final sample = lines.map((e) => e.originalText).join(' ');

      return [
        _ScoredLyricsCandidate(
          lyrics: SyncedLyrics(
            videoId: videoId,
            isSynced: true,
            isOriginalIndonesian: detectIsIndonesian(sample),
            lines: lines,
            sourceName: hasWordSync ? 'LrcRed Word-Sync' : 'LrcRed Synced',
          ),
          score: _scoreLyricsCandidate(
            lines: lines,
            isSynced: true,
            declaredDurationSec: hitDur,
            targetDurationSec: totalDurationSec,
            providerBonus: hasWordSync ? 20.0 : 8.5,
          ),
          declaredDurationSec: hitDur,
        ),
      ];
    } catch (_) {
      return const [];
    }
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
        final rawRich = item['richSyncLyrics']?.toString();
        final rawStd = item['syncedLyrics']?.toString();
        final rawPlain = item['plainLyric']?.toString();
        final itemDur =
            (item['durationSeconds'] as num?)?.toInt() ?? totalDurationSec;

        for (final rawSynced in [rawRich, rawStd]) {
          if (rawSynced == null || rawSynced.trim().isEmpty) continue;
          // Reject raw JSON blobs that aren't LRC format
          if (rawSynced.trimLeft().startsWith('[{')) continue;
          final lines = _parseLrcFormat(rawSynced);
          if (lines.length < 3) continue;

          final sample = lines.map((e) => e.originalText).join(' ');
          final lyr = SyncedLyrics(
            videoId: videoId,
            isSynced: true,
            isOriginalIndonesian: detectIsIndonesian(sample),
            lines: lines,
            sourceName: 'SimpMusic Synced',
          );

          final score = _scoreLyricsCandidate(
            lines: lines,
            isSynced: true,
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

        if (candidates.isEmpty && rawPlain != null && rawPlain.trim().isNotEmpty) {
          final lines = _parsePlainLines(rawPlain, totalDurationSec);
          if (lines.isNotEmpty) {
            final sample = lines.map((e) => e.originalText).join(' ');
            final lyr = SyncedLyrics(
              videoId: videoId,
              isSynced: false,
              isOriginalIndonesian: detectIsIndonesian(sample),
              lines: lines,
              sourceName: 'SimpMusic Lyrics',
            );
            candidates.add(
              _ScoredLyricsCandidate(
                lyrics: lyr,
                score: _scoreLyricsCandidate(
                  lines: lines,
                  isSynced: false,
                  declaredDurationSec: itemDur,
                  targetDurationSec: totalDurationSec,
                  providerBonus: 2.0,
                ),
                declaredDurationSec: itemDur,
              ),
            );
          }
        }
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
  // PROVIDER 2A: LyricsPlus / Binimum Apple Music Word-Synced API (`lyricsplus.binimum.org`)
  // ---------------------------------------------------------------------------
  Future<List<_ScoredLyricsCandidate>> _fetchCandidateFromLyricsPlus(
    String videoId,
    String title,
    String artist,
    int totalDurationSec,
  ) async {
    try {
      final queryParams = <String, String>{
        'title': title,
        'artist': artist,
        if (totalDurationSec > 30) 'duration': '$totalDurationSec',
      };
      final uri = Uri.parse(_lyricsPlusUrl).replace(queryParameters: queryParams);
      final res = await _http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return const [];

      final decoded =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final rawLyricsList = decoded['lyrics'] as List<dynamic>?;
      if (rawLyricsList == null || rawLyricsList.isEmpty) return const [];

      final parsedLines = <LyricLine>[];
      for (final item in rawLyricsList) {
        final m = item as Map<String, dynamic>;
        final timeMs = (m['time'] as num?)?.toInt() ?? 0;
        final durMs = (m['duration'] as num?)?.toInt() ?? 3000;
        final rawText = (m['text'] ?? '').toString();
        final cleanedText = _cleanAndSanitizeLyricText(rawText);
        if (cleanedText.isEmpty) continue;

        final syllabus = m['syllabus'] as List<dynamic>? ?? const [];
        final mergedWords = <LyricWord>[];
        String accWord = '';
        int accStart = 0;
        int accEnd = 0;

        for (final syl in syllabus) {
          final sm = syl as Map<String, dynamic>;
          final sText = (sm['text'] ?? '').toString();
          if (sText.isEmpty) continue;
          final sStart = (sm['time'] as num?)?.toInt() ?? timeMs;
          final sDur = (sm['duration'] as num?)?.toInt() ?? 240;
          final sEnd = sStart + (sDur > 40 ? sDur : 200);

          if (sText.startsWith(' ') && accWord.isNotEmpty) {
            final cleanW = _cleanAndSanitizeLyricText(accWord);
            if (cleanW.isNotEmpty) {
              mergedWords.add(
                LyricWord(text: cleanW, startMs: accStart, endMs: accEnd),
              );
            }
            accWord = '';
          }

          if (accWord.isEmpty) {
            accStart = sStart;
          }
          accWord += sText;
          accEnd = sEnd;

          if (sText.endsWith(' ')) {
            final cleanW = _cleanAndSanitizeLyricText(accWord);
            if (cleanW.isNotEmpty) {
              mergedWords.add(
                LyricWord(text: cleanW, startMs: accStart, endMs: accEnd),
              );
            }
            accWord = '';
          }
        }
        if (accWord.trim().isNotEmpty) {
          final cleanW = _cleanAndSanitizeLyricText(accWord);
          if (cleanW.isNotEmpty) {
            mergedWords.add(
              LyricWord(text: cleanW, startMs: accStart, endMs: accEnd),
            );
          }
        }

        final elem = m['element'] as Map<String, dynamic>?;
        final rawSinger = elem?['singer']?.toString().toLowerCase() ?? '';
        String? vocalAgent;
        if (rawSinger == 'v1' || rawSinger == '1') {
          vocalAgent = 'v1';
        } else if (rawSinger == 'v2' || rawSinger == '2' || rawSinger == 'v3') {
          vocalAgent = 'v2';
        } else if (rawSinger.contains('all') ||
            rawSinger.contains('group') ||
            rawSinger == 'v1000') {
          vocalAgent = 'group';
        }

        parsedLines.add(
          LyricLine(
            timestamp: Duration(milliseconds: timeMs),
            endTimeMs: timeMs + (durMs > 300 ? durMs : 2800),
            originalText: cleanedText,
            words: mergedWords,
            vocalAgent: vocalAgent,
            hasExactWordTiming: mergedWords.length > 1,
          ),
        );
      }

      final finalized = _finalizeWordTimingsAndInterludes(parsedLines);
      if (finalized.isEmpty) return const [];

      final estimatedDur = finalized.last.timestamp.inSeconds + 15;
      final sample = finalized.map((e) => e.originalText).join(' ');
      final lyr = SyncedLyrics(
        videoId: videoId,
        isSynced: true,
        isOriginalIndonesian: detectIsIndonesian(sample),
        lines: finalized,
        sourceName: 'Apple Music Synced',
      );

      final score = _scoreLyricsCandidate(
        lines: finalized,
        isSynced: true,
        declaredDurationSec: estimatedDur,
        targetDurationSec: totalDurationSec,
        providerBonus: 9.0,
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

  // ---------------------------------------------------------------------------
  // PROVIDER 2B: BetterLyrics / Apple Music TTML (`lyrics-api.boidu.dev`)
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
        providerBonus: 14.0,
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

    // 1. Parse <ttm:agent type="person|group" xml:id="v1"/> declarations for duet side mapping
    final groupAgentIds = <String>{};
    final personAgentOrder = <String>[];
    final agentRegExp = RegExp(r'<ttm:agent([^>]*)/?>', caseSensitive: false);
    final typeAttr = RegExp(r'type="([^"]+)"', caseSensitive: false);
    final idAttr = RegExp(r'xml:id="([^"]+)"', caseSensitive: false);
    for (final am in agentRegExp.allMatches(ttml)) {
      final attrs = am.group(1) ?? '';
      final id = idAttr.firstMatch(attrs)?.group(1)?.trim();
      final type = typeAttr.firstMatch(attrs)?.group(1)?.trim().toLowerCase();
      if (id == null || id.isEmpty) continue;
      if (type == 'group' || type == 'other') {
        groupAgentIds.add(id);
      } else if (!personAgentOrder.contains(id)) {
        personAgentOrder.add(id);
      }
    }

    String? normalizeTtmlAgent(String? rawAgent) {
      if (rawAgent == null || rawAgent.isEmpty) return null;
      if (groupAgentIds.contains(rawAgent) || rawAgent == 'v1000') {
        return 'group';
      }
      if (personAgentOrder.isNotEmpty) {
        final idx = personAgentOrder.indexOf(rawAgent);
        if (idx == 0) return 'v1';
        if (idx >= 1) return 'v2';
      }
      if (rawAgent == 'v1') return 'v1';
      if (rawAgent == 'v2' || rawAgent == 'v3') return 'v2';
      return 'group';
    }

    final pRegExp = RegExp(r'<p([^>]*)>(.*?)</p>', dotAll: true);
    final bgSpanRegExp = RegExp(
      r'<span[^>]*ttm:role="x-bg"[^>]*>(.*?)</span>',
      dotAll: true,
      caseSensitive: false,
    );
    final spanRegExp = RegExp(r'<span([^>]*)>(.*?)</span>', dotAll: true);
    final beginAttr = RegExp(r'begin="([^"]+)"');
    final endAttr = RegExp(r'end="([^"]+)"');
    final pAgentAttr = RegExp(r'ttm:agent="([^"]+)"', caseSensitive: false);

    List<LyricWord> extractSpanWords(String htmlChunk) {
      final words = <LyricWord>[];
      for (final sm in spanRegExp.allMatches(htmlChunk)) {
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
          words.add(
            LyricWord(
              text: wText,
              startMs: ws,
              endMs: we > ws ? we : ws + 180,
            ),
          );
        }
      }
      return words;
    }

    for (final m in pRegExp.allMatches(ttml)) {
      final pAttrs = m.group(1) ?? '';
      final rawInnerHtml = m.group(2) ?? '';
      final beginMatch = beginAttr.firstMatch(pAttrs);
      if (beginMatch == null) continue;

      final pStartMs = _parseTtmlTimestampMs(beginMatch.group(1)!.trim());
      final endMatch = endAttr.firstMatch(pAttrs);
      final pEndMs = endMatch != null
          ? _parseTtmlTimestampMs(endMatch.group(1)!.trim())
          : null;
      final vocalAgent = normalizeTtmlAgent(
        pAgentAttr.firstMatch(pAttrs)?.group(1)?.trim(),
      );

      // Separate Apple Music x-bg background/filler vocals cleanly so they don't throw off lead timing!
      final bgWords = <LyricWord>[];
      final bgParts = <String>[];
      final leadHtml = rawInnerHtml.replaceAllMapped(bgSpanRegExp, (bgm) {
        final bgInner = bgm.group(1) ?? '';
        final extracted = extractSpanWords(bgInner);
        if (extracted.isNotEmpty) {
          bgWords.addAll(extracted);
          bgParts.add(extracted.map((w) => w.text).join(' '));
        } else {
          final plainBg = _cleanAndSanitizeLyricText(
            bgInner.replaceAll(RegExp(r'<[^>]+>'), ' '),
            timestampMs: pStartMs,
          );
          if (plainBg.isNotEmpty) bgParts.add(plainBg);
        }
        return ' ';
      });

      final parsedWords = extractSpanWords(leadHtml);
      final rawLeadText = parsedWords.isNotEmpty
          ? parsedWords.map((w) => w.text).join(' ')
          : _decodeXmlEntities(
              leadHtml.replaceAll(RegExp(r'<[^>]+>'), ' '),
            ).replaceAll(RegExp(r'\s+'), ' ').trim();

      final cleanText = _cleanAndSanitizeLyricText(
        rawLeadText,
        timestampMs: pStartMs,
      );
      final cleanBg = bgParts.isNotEmpty
          ? _cleanAndSanitizeLyricText(bgParts.join(' '), timestampMs: pStartMs)
          : '';

      if (cleanText.isEmpty) continue;

      final leadEndMs = parsedWords.isNotEmpty
          ? parsedWords.last.endMs
          : pEndMs;

      lines.add(
        LyricLine(
          timestamp: Duration(milliseconds: pStartMs),
          endTimeMs: leadEndMs,
          originalText: cleanText,
          words: parsedWords,
          vocalAgent: vocalAgent,
          backgroundText: cleanBg.isNotEmpty ? cleanBg : null,
          backgroundWords: bgWords,
          hasExactWordTiming: parsedWords.length > 1 || pEndMs != null,
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
    // 1. Decode named HTML/XML entities
    String out = input
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '...');

    // 2. Decode ALL hex numeric entities like &#x27; (fixes Darkside "We&#x27;re", "Don&#x27;t")
    out = out.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);', caseSensitive: false),
      (m) {
        final code = int.tryParse(m.group(1)!, radix: 16);
        if (code == null || code <= 0 || code > 0x10FFFF) return '';
        return String.fromCharCode(code);
      },
    );

    // 3. Decode ALL decimal numeric entities like &#39;, &#8217;
    out = out.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) {
        final code = int.tryParse(m.group(1)!);
        if (code == null || code <= 0 || code > 0x10FFFF) return '';
        return String.fromCharCode(code);
      },
    );

    return out;
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
              headers: {'User-Agent': 'Zunify/2.0.0'},
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

  /// Strips random/garbage text from lyrics: hex/dec HTML entities (`&#x27;`),
  /// NetEase/QQMusic production credits (`MER Publishing / Sony / ATV`, `Executive Producer：`),
  /// closed-caption noise (`[Music]`, `[Applause]`), uploader credits/URLs, and singer labels.
  /// Returns empty string if the line is pure metadata/noise.
  String _cleanAndSanitizeLyricText(String input, {int? timestampMs}) {
    String s = _decodeXmlEntities(input)
        .replaceAll('\uFFFD', '')
        .replaceAll(RegExp(r'<\d{1,2}:\d{2}(?:[\.:]\d{1,3})?>'), ' ')
        .replaceAll(RegExp(r'\[\d{1,2}:\d{2}(?:[\.:]\d{1,3})?\]'), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(
          RegExp(
            r'^(?:v\d+|male|female|boy|girl|all|duet|both|penyanyi\s*\d*)\s*:\s*',
            caseSensitive: false,
          ),
          '',
        );

    // Strip bracketed/parenthesized closed-caption & stage directions
    s = s.replaceAll(
      RegExp(
        r'[\[\(\{]\s*(?:music|musik|applause|tepuk\s*tangan|laughter|tertawa|cheering|sorak|instrumental|instrumen|intro|outro|interlude|solo|guitar\s*solo|piano\s*solo|rapping|singing|speaking|chorus|reff|verse\s*\d*|bridge|hook|pre-?chorus|post-?chorus|beat\s*drop|fade\s*out|bgm|sfx|\?+)\s*[\]\)\}]',
        caseSensitive: false,
      ),
      ' ',
    );

    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '';

    final lower = s.toLowerCase();

    // 1. Drop LRC uploader credits, URLs, & watermarks
    if (RegExp(
      r'(?:^lrc\s*by|synced\s*by|created\s*by|transcribed\s*by|subtitles?\s*by|lirik\s*oleh|disinkronkan\s*oleh|editor\s*:|www\.|https?://|\.com\b|\.net\b|\.org\b|megalobiz|rentanadviser|kazelyrics|musixmatch|lrclib|@\w{3,})',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return '';
    }

    // 2. Drop NetEase / QQMusic / SimpMusic studio & publisher credit lines
    //    (e.g. "Background Vocals by：Tommy LaVerdi", "MER Publishing / Sony / ATV",
    //     "Executive Producer：", "Mastering Engineer：", "Repertoire Owner：", "词：", "曲：")
    if (RegExp(
      r'(?:(?:executive\s+)?producer|mastering(?:\s+engineer)?|mixing(?:\s+engineer)?|mixed\s+by|recorded\s+(?:at|by)|vocals?\s+(?:produced|by)|background\s+vocals?\s+by|written\s+by|composed\s+by|arranged\s+by|lyrics?\s+by|repertoire\s+owner|copyright\s+control|music\s+publishing|sony\s*/\s*atv|warner\s+chappell|stellar\s+songs|chrysalis|bmg\s+|cosmos\s+mastering|basecamp\s+studios|mer\s+studio|mer\s+recordings|all\s+rights\s+reserved)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return '';
    }
    if (RegExp(r'^(?:作?词|作?曲|编曲|制作人?|混音|母带|录音|出品|监制|发行|和声|演唱|企划|统筹)\s*[:：]').hasMatch(s)) {
      return '';
    }
    if (s.contains('：') &&
        RegExp(
          r'(?:by|producer|engineer|owner|studio|vocal|mix|master|write|compos|arrang|guitar|bass|drum|piano|synth)',
          caseSensitive: false,
        ).hasMatch(lower)) {
      return '';
    }

    // 3. Drop early intro (first 16s) credit dumps listing multiple songwriters/artists with slashes
    //    or "SongTitle - Artist" header lines (like Darkside [00:00.00] Darkside - Alan Walker / Au / Ra)
    if (timestampMs != null && timestampMs < 16000) {
      final slashCount = '/'.allMatches(s).length;
      if (slashCount >= 2) return '';
      if (timestampMs <= 1500 &&
          RegExp(r'\s[-–—]\s').hasMatch(s) &&
          s.length < 95) {
        return '';
      }
      if (RegExp(r'\bin\s+(?:stockholm|oslo|london|los\s+angeles|new\s+york|tokyo|seoul|jakarta)\b', caseSensitive: false)
          .hasMatch(lower)) {
        return '';
      }
    }

    // 4. Drop lines that consist only of punctuation/symbols/musical notes or stray digits
    final alpha = s.replaceAll(
      RegExp(r'[^a-zA-Z\u00C0-\u024F\u3040-\u30FF\u4E00-\u9FFF\uAC00-\uD7AF]'),
      '',
    );
    if (alpha.isEmpty) return '';

    return s;
  }

  /// Extracts speaker side ('v1' | 'v2' | 'group') from LRC prefix tags before stripping.
  String? _extractLrcVocalAgent(String rawBody) {
    final trimmed = rawBody.trimLeft();
    final m = RegExp(
      r'^(v\d+|male|female|boy|girl|all|duet|both|penyanyi\s*\d*)\s*:\s*',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (m == null) return null;
    final tag = m.group(1)!.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (tag == 'v1' || tag == 'male' || tag == 'boy' || tag == 'penyanyi1') {
      return 'v1';
    }
    if (tag == 'v2' || tag == 'female' || tag == 'girl' || tag == 'penyanyi2') {
      return 'v2';
    }
    if (tag == 'all' || tag == 'duet' || tag == 'both' || tag == 'v3' || tag == 'v4') {
      return 'group';
    }
    return null;
  }

  List<LyricLine> _parseLrcFormat(String lrcContent) {
    final rawParsed = <LyricLine>[];
    final regExp = RegExp(r'^\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?\](.*)');
    final wordTagRegExp = RegExp(
      r'[<\[](\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?[>\]]([^<\[]*)',
    );
    final trailingParenBg = RegExp(r'^(.*\S)\s+\(([^()]{2,42})\)\s*$');

    for (final rawLine in lrcContent.split('\n')) {
      final match = regExp.firstMatch(rawLine.trim());
      if (match != null) {
        final lineStartMs = _parseLrcTimeTokenMs(
          match.group(1)!,
          match.group(2)!,
          match.group(3),
        );
        final rawBodyOriginal = match.group(4)!;
        final vocalAgent = _extractLrcVocalAgent(rawBodyOriginal);
        final rawBody = rawBodyOriginal.replaceFirst(
          RegExp(
            r'^\s*(?:v\d+|male|female|boy|girl|all|duet|both|penyanyi\s*\d*)\s*:\s*',
            caseSensitive: false,
          ),
          '',
        );

        // Extract inline RichSync word/syllable timestamps like <00:12.34>word
        // and merge consecutive syllables without whitespace into whole words!
        final parsedWords = <LyricWord>[];
        final wordMatches = wordTagRegExp.allMatches(rawBody).toList();
        int? trailingEndTagMs;
        if (wordMatches.isNotEmpty) {
          // If the last match is a trailing closing timestamp with empty text (like LrcRed `<00:15.48>`),
          // capture it as the exact end time of the previous word/line!
          final lastM = wordMatches.last;
          if ((lastM.group(4) ?? '').trim().isEmpty) {
            trailingEndTagMs = _parseLrcTimeTokenMs(
              lastM.group(1)!,
              lastM.group(2)!,
              lastM.group(3),
            );
          }

          String accText = '';
          int accStart = 0;
          int accEnd = 0;

          for (int i = 0; i < wordMatches.length; i++) {
            final wm = wordMatches[i];
            final wStart = _parseLrcTimeTokenMs(
              wm.group(1)!,
              wm.group(2)!,
              wm.group(3),
            );
            final rawSeg = wm.group(4) ?? '';
            if (rawSeg.isEmpty) continue;

            int wEnd = wStart + 260;
            if (i + 1 < wordMatches.length) {
              final nextStart = _parseLrcTimeTokenMs(
                wordMatches[i + 1].group(1)!,
                wordMatches[i + 1].group(2)!,
                wordMatches[i + 1].group(3),
              );
              if (nextStart > wStart) wEnd = nextStart;
            }

            if (rawSeg.startsWith(' ') && accText.isNotEmpty) {
              final cleanW = _decodeXmlEntities(accText).trim();
              if (cleanW.isNotEmpty) {
                parsedWords.add(
                  LyricWord(text: cleanW, startMs: accStart, endMs: accEnd),
                );
              }
              accText = '';
            }

            if (accText.isEmpty) {
              accStart = wStart;
            }
            accText += rawSeg;
            accEnd = wEnd;

            if (rawSeg.endsWith(' ')) {
              final cleanW = _decodeXmlEntities(accText).trim();
              if (cleanW.isNotEmpty) {
                parsedWords.add(
                  LyricWord(text: cleanW, startMs: accStart, endMs: accEnd),
                );
              }
              accText = '';
            }
          }
          if (accText.trim().isNotEmpty) {
            final cleanW = _decodeXmlEntities(accText).trim();
            if (cleanW.isNotEmpty) {
              parsedWords.add(
                LyricWord(text: cleanW, startMs: accStart, endMs: accEnd),
              );
            }
          }
        }

        final strippedBody = rawBody
            .replaceAll(RegExp(r'<\d{1,2}:\d{2}(?:[\.:]\d{1,3})?>'), '')
            .replaceAll(RegExp(r'\[\d{1,2}:\d{2}(?:[\.:]\d{1,3})?\]'), '');
        final cleanedFull = _cleanAndSanitizeLyricText(
          strippedBody,
          timestampMs: lineStartMs,
        );

        // If the raw line had non-empty junk that was stripped (e.g. NetEase credits),
        // skip it completely rather than treating it as an instrumental pause marker!
        if (cleanedFull.isEmpty) {
          if (strippedBody.trim().isEmpty) {
            rawParsed.add(
              LyricLine(
                timestamp: Duration(milliseconds: lineStartMs),
                originalText: '',
              ),
            );
          }
          continue;
        }

        // Split trailing parenthesized ad-lib / filler vocals (e.g. "We're running out of time (Time, time)")
        // so background vocals don't disturb lead vocal cadence!
        String leadText = cleanedFull;
        String? bgText;
        List<LyricWord> leadWords = parsedWords;
        List<LyricWord> bgWords = const [];

        final bgMatch = trailingParenBg.firstMatch(cleanedFull);
        if (bgMatch != null) {
          final mainCandidate = bgMatch.group(1)!.trim();
          final adlibCandidate = bgMatch.group(2)!.trim();
          if (mainCandidate.length >= 4 && adlibCandidate.length >= 2) {
            leadText = mainCandidate;
            bgText = adlibCandidate;
            if (parsedWords.isNotEmpty) {
              final parenIdx = parsedWords.indexWhere(
                (w) => w.text.startsWith('('),
              );
              if (parenIdx > 0) {
                leadWords = parsedWords.sublist(0, parenIdx);
                bgWords = parsedWords
                    .sublist(parenIdx)
                    .map(
                      (w) => LyricWord(
                        text: w.text.replaceAll(RegExp(r'^[()]+|[()]+$'), ''),
                        startMs: w.startMs,
                        endMs: w.endMs,
                      ),
                    )
                    .where((w) => w.text.isNotEmpty)
                    .toList();
              } else {
                leadWords = const [];
              }
            }
          }
        }

        final exactEnd = leadWords.isNotEmpty
            ? leadWords.last.endMs
            : trailingEndTagMs;

        rawParsed.add(
          LyricLine(
            timestamp: Duration(milliseconds: lineStartMs),
            endTimeMs: exactEnd,
            originalText: leadText,
            words: leadWords,
            vocalAgent: vocalAgent,
            backgroundText: bgText,
            backgroundWords: bgWords,
            hasExactWordTiming: leadWords.length > 1 || trailingEndTagMs != null,
          ),
        );
      }
    }

    // Filter out explicit empty LRC markers unless they mark a true musical interlude (>= 7s gap)
    final cleaned = <LyricLine>[];
    for (int i = 0; i < rawParsed.length; i++) {
      final cur = rawParsed[i];
      if (cur.originalText.isNotEmpty) {
        cleaned.add(cur);
      } else if (cleaned.isNotEmpty && i + 1 < rawParsed.length) {
        final next = rawParsed[i + 1];
        if (next.originalText.isEmpty) continue;
        final gapMs =
            next.timestamp.inMilliseconds - cur.timestamp.inMilliseconds;
        if (gapMs >= 7000 && !cleaned.last.originalText.contains('•')) {
          cleaned.add(
            LyricLine(
              timestamp: cur.timestamp,
              endTimeMs: next.timestamp.inMilliseconds,
              originalText: '♪ • • • ♪',
              hasExactWordTiming: true,
            ),
          );
        }
      }
    }

    return _finalizeWordTimingsAndInterludes(cleaned);
  }

  /// Finalizes vocal timings & inserts `♪ • • • ♪` ONLY on genuine instrumental breaks
  /// (never interrupting a line that is still being sung!).
  List<LyricLine> _finalizeWordTimingsAndInterludes(List<LyricLine> input) {
    if (input.isEmpty) return input;
    final out = <LyricLine>[];

    // 1. Intro dots ONLY when first actual lyric starts >= 4.5s into the track
    final firstStartMs = input.first.timestamp.inMilliseconds;
    if (firstStartMs >= 4500 && !input.first.originalText.contains('•')) {
      out.add(
        LyricLine(
          timestamp: Duration.zero,
          endTimeMs: firstStartMs,
          originalText: '♪ • • • ♪',
          hasExactWordTiming: true,
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
          : (startMs + 5000);
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
          final weights = <int>[];
          int naturalTotalMs = 180;
          for (int wIdx = 0; wIdx < rawTokens.length; wIdx++) {
            final token = rawTokens[wIdx];
            final cleanLen = token
                .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
                .length
                .clamp(1, 14);
            int wMs = 175 + (cleanLen * 62);
            if (token.endsWith(',') ||
                token.endsWith('.') ||
                token.endsWith('!') ||
                token.endsWith('?')) {
              wMs += 200;
            }
            if (wIdx == rawTokens.length - 1) {
              wMs += 280;
            }
            weights.add(wMs);
            naturalTotalMs += wMs;
          }

          // Smoothly fit word fill to actual available span (without finishing way too early!)
          final maxSingSpan = (availableSpanMs - 100).clamp(500, 8800);
          final targetSpan = (availableSpanMs <= 8800)
              ? (availableSpanMs * 0.86).round().clamp(500, maxSingSpan)
              : naturalTotalMs.clamp(1800, maxSingSpan);
          final actualSingSpanMs = targetSpan > maxSingSpan
              ? maxSingSpan
              : targetSpan;
          lineEndMs = startMs + actualSingSpanMs;

          final totalWeight =
              weights.fold<int>(0, (a, b) => a + b).clamp(1, 999999);
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

      // 2. Insert mid-song interlude dots ONLY on a genuine long instrumental break
      //    so filler dots NEVER cut off a singer mid-phrase!
      if (i + 1 < input.length && !input[i + 1].originalText.contains('•')) {
        if (cur.hasExactWordTiming && cur.endTimeMs != null) {
          final realSilentRestMs = nextLineStartMs - cur.endTimeMs!;
          if (realSilentRestMs >= 7500) {
            out.add(
              LyricLine(
                timestamp: Duration(milliseconds: cur.endTimeMs! + 700),
                endTimeMs: nextLineStartMs,
                originalText: '♪ • • • ♪',
                hasExactWordTiming: true,
              ),
            );
          }
        } else {
          // For line-only LRC without explicit word end times, only insert dots on a huge >= 14s gap
          final lineGapMs = nextLineStartMs - startMs;
          if (lineGapMs >= 14000) {
            final dotStartMs = startMs + 6200;
            if (nextLineStartMs - dotStartMs >= 7000) {
              out.add(
                LyricLine(
                  timestamp: Duration(milliseconds: dotStartMs),
                  endTimeMs: nextLineStartMs,
                  originalText: '♪ • • • ♪',
                  hasExactWordTiming: false,
                ),
              );
            }
          }
        }
      }
    }

    return out;
  }

  List<LyricLine> _parsePlainLines(String plain, int totalDurationSec) {
    final rawLines = plain
        .split('\n')
        .map((e) => _cleanAndSanitizeLyricText(e))
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
