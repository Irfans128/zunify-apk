import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lyric_model.dart';
import '../models/song_model.dart';

/// Zunify Synced Karaoke Lyrics & Smart Bahasa Indonesia Translation Service
/// 1. Fetches synced (.lrc) lyrics from LRCLIB (free & unlimited).
/// 2. Detects if the song is already in Bahasa Indonesia.
///    - If already Indonesian -> Hides translation row automatically to keep UI clean!
///    - If foreign (English, Japanese, Korean, etc.) -> Translates each line to Bahasa Indonesia.
class LyricsTranslationService {
  static const String _lrclibBase = 'https://lrclib.net/api';
  final Map<String, SyncedLyrics> _memoryLyricsCache = {};

  // Common Indonesian words to accurately detect Bahasa Indonesia lyrics
  static const Set<String> _indonesianMarkers = {
    'yang', 'dan', 'aku', 'kamu', 'kau', 'kita', 'tidak', 'tak', 'bisa',
    'dengan', 'untuk', 'dalam', 'karena', 'jika', 'bila', 'saat', 'hati',
    'cinta', 'rindu', 'malam', 'hari', 'ini', 'itu', 'ada', 'lagi',
    'pernah', 'selalu', 'hanya', 'ingin', 'mengapa', 'kenapa', 'jangan',
    'masih', 'telah', 'sudah', 'akan', 'sampai', 'bahagia', 'luka',
    'sendiri', 'bersama', 'dirimu', 'diriku', 'ku', 'mu', 'nya',
  };

  Future<SyncedLyrics> fetchSyncedBilingualLyrics(ZunifySong song) async {
    if (_memoryLyricsCache.containsKey(song.videoId)) {
      return _memoryLyricsCache[song.videoId]!;
    }
    try {
      // 1. Query LRCLIB by track_name & artist_name
      final searchUri = Uri.parse('$_lrclibBase/search').replace(
        queryParameters: {
          'track_name': song.title,
          'artist_name': song.artist,
        },
      );

      var response = await http.get(
        searchUri,
        headers: {'User-Agent': 'Zunify/1.0.0 (Crafted by Fannz)'},
      ).timeout(const Duration(seconds: 8));

      List<dynamic> items = [];
      if (response.statusCode == 200) {
        items = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      }

      // Fallback search with general query q
      if (items.isEmpty) {
        final fallbackUri = Uri.parse('$_lrclibBase/search').replace(
          queryParameters: {'q': '${song.artist} ${song.title}'},
        );
        response = await http.get(
          fallbackUri,
          headers: {'User-Agent': 'Zunify/1.0.0 (Crafted by Fannz)'},
        ).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          items = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        }
      }

      if (items.isEmpty) {
        return _emptyFallback(song.videoId);
      }

      // Prefer item that has syncedLyrics
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
      } else if (rawPlain != null && rawPlain.trim().isNotEmpty) {
        parsedLines = _parsePlainLines(rawPlain, song.durationSeconds);
        isSynced = false;
      }

      if (parsedLines.isEmpty) {
        return _emptyFallback(song.videoId);
      }

      // 2. Check if original lyrics are already in Bahasa Indonesia
      final fullLyricsSample = parsedLines.map((e) => e.originalText).join(' ');
      final isOriginalIndonesian = detectIsIndonesian(fullLyricsSample);

      // 3. If NOT Indonesian, translate lines into Bahasa Indonesia
      if (!isOriginalIndonesian) {
        parsedLines = await _translateLinesToIndonesian(parsedLines);
      }

      final result = SyncedLyrics(
        videoId: song.videoId,
        isSynced: isSynced,
        isOriginalIndonesian: isOriginalIndonesian,
        lines: parsedLines,
      );
      _memoryLyricsCache[song.videoId] = result;
      return result;
    } catch (_) {
      return _emptyFallback(song.videoId);
    }
  }

  /// Smart Bahasa Indonesia Detector
  /// Returns true if the lyric text is predominantly Bahasa Indonesia.
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
    return ratio >= 0.14; // >= 14% Indonesian lexical markers confirms Bahasa Indonesia
  }

  List<LyricLine> _parseLrcFormat(String lrcContent) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final rawLine in lrcContent.split('\n')) {
      final match = regExp.firstMatch(rawLine.trim());
      if (match != null) {
        final mins = int.tryParse(match.group(1)!) ?? 0;
        final secs = int.tryParse(match.group(2)!) ?? 0;
        final msRaw = match.group(3)!;
        final millis = (int.tryParse(msRaw) ?? 0) * (msRaw.length == 2 ? 10 : 1);
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          lines.add(
            LyricLine(
              timestamp: Duration(minutes: mins, seconds: secs, milliseconds: millis),
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

    final stepMs = ((totalDurationSec * 1000) / rawLines.length).round();
    return List.generate(
      rawLines.length,
      (i) => LyricLine(
        timestamp: Duration(milliseconds: i * stepMs),
        originalText: rawLines[i],
      ),
    );
  }

  /// Batch-translates non-Indonesian lyric lines into Bahasa Indonesia
  /// Also verifies via Google Translate detected source language (`src == 'id'`)
  Future<List<LyricLine>> _translateLinesToIndonesian(List<LyricLine> lines) async {
    try {
      // Join with newline delimiter for fast single-request batch translation
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

      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return lines;

      final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      final detectedLang = decoded.length > 2 ? (decoded[2] as String?) : null;

      // If Google Translate detects source language is already Indonesian ('id' or 'ms'),
      // return lines without translation so translation row stays hidden!
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
        final trans = i < translatedLines.length ? translatedLines[i].trim() : null;

        // Avoid redundant translation if identical to original line
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
      lines: const [
        LyricLine(
          timestamp: Duration.zero,
          originalText: '♪ Lirik belum tersedia untuk lagu ini ♪',
        ),
      ],
    );
  }
}
