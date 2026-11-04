class LyricLine {
  final Duration timestamp;
  final String originalText;
  final String? translatedIndoText;

  const LyricLine({
    required this.timestamp,
    required this.originalText,
    this.translatedIndoText,
  });

  LyricLine copyWith({
    Duration? timestamp,
    String? originalText,
    String? translatedIndoText,
  }) {
    return LyricLine(
      timestamp: timestamp ?? this.timestamp,
      originalText: originalText ?? this.originalText,
      translatedIndoText: translatedIndoText ?? this.translatedIndoText,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestampMs': timestamp.inMilliseconds,
        'originalText': originalText,
        'translatedIndoText': translatedIndoText,
      };

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
        timestamp: Duration(milliseconds: (json['timestampMs'] as num?)?.toInt() ?? 0),
        originalText: json['originalText'] as String? ?? '',
        translatedIndoText: json['translatedIndoText'] as String?,
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
