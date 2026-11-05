class LyricWord {
  final String text;
  final int startMs;
  final int endMs;

  const LyricWord({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  Map<String, dynamic> toJson() => {
        't': text,
        's': startMs,
        'e': endMs,
      };

  factory LyricWord.fromJson(Map<String, dynamic> json) => LyricWord(
        text: json['t'] as String? ?? '',
        startMs: (json['s'] as num?)?.toInt() ?? 0,
        endMs: (json['e'] as num?)?.toInt() ?? 0,
      );
}

class LyricLine {
  final Duration timestamp;
  final int? endTimeMs;
  final String originalText;
  final String? translatedIndoText;
  final List<LyricWord> words;

  const LyricLine({
    required this.timestamp,
    this.endTimeMs,
    required this.originalText,
    this.translatedIndoText,
    this.words = const [],
  });

  LyricLine copyWith({
    Duration? timestamp,
    int? endTimeMs,
    String? originalText,
    String? translatedIndoText,
    List<LyricWord>? words,
  }) {
    return LyricLine(
      timestamp: timestamp ?? this.timestamp,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      originalText: originalText ?? this.originalText,
      translatedIndoText: translatedIndoText ?? this.translatedIndoText,
      words: words ?? this.words,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestampMs': timestamp.inMilliseconds,
        if (endTimeMs != null) 'endTimeMs': endTimeMs,
        'originalText': originalText,
        'translatedIndoText': translatedIndoText,
        if (words.isNotEmpty) 'words': words.map((w) => w.toJson()).toList(),
      };

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
        timestamp: Duration(
          milliseconds: (json['timestampMs'] as num?)?.toInt() ?? 0,
        ),
        endTimeMs: (json['endTimeMs'] as num?)?.toInt(),
        originalText: json['originalText'] as String? ?? '',
        translatedIndoText: json['translatedIndoText'] as String?,
        words: ((json['words'] as List<dynamic>?) ?? [])
            .map((e) => LyricWord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SyncedLyrics {
  final String videoId;
  final bool isSynced;
  final bool isOriginalIndonesian; // If true, translation row is automatically hidden
  final List<LyricLine> lines;
  final String sourceName;

  const SyncedLyrics({
    required this.videoId,
    required this.isSynced,
    required this.isOriginalIndonesian,
    required this.lines,
    this.sourceName = 'LRCLIB + Zunify ID Translator',
  });

  /// Returns true when Indonesian translation should be displayed under each line
  bool get shouldShowTranslation => !isOriginalIndonesian;

  SyncedLyrics copyWith({
    String? videoId,
    bool? isSynced,
    bool? isOriginalIndonesian,
    List<LyricLine>? lines,
    String? sourceName,
  }) {
    return SyncedLyrics(
      videoId: videoId ?? this.videoId,
      isSynced: isSynced ?? this.isSynced,
      isOriginalIndonesian: isOriginalIndonesian ?? this.isOriginalIndonesian,
      lines: lines ?? this.lines,
      sourceName: sourceName ?? this.sourceName,
    );
  }

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'isSynced': isSynced,
        'isOriginalIndonesian': isOriginalIndonesian,
        'sourceName': sourceName,
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  factory SyncedLyrics.fromJson(Map<String, dynamic> json) => SyncedLyrics(
        videoId: json['videoId'] as String? ?? '',
        isSynced: json['isSynced'] as bool? ?? false,
        isOriginalIndonesian: json['isOriginalIndonesian'] as bool? ?? false,
        sourceName: json['sourceName'] as String? ?? 'LRCLIB',
        lines: ((json['lines'] as List<dynamic>?) ?? [])
            .map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
