class ZunifySong {
  final String videoId;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final String thumbnailUrl;
  final String highResArtUrl;
  final String? localFilePath;
  final String? localArtPath;
  final bool isDownloaded;
  final int audioBitrateKbps; // 96 (Hemat Data) or 160 (High Quality)
  final DateTime addedAt;

  const ZunifySong({
    required this.videoId,
    required this.title,
    required this.artist,
    this.album = 'YouTube Music',
    required this.durationSeconds,
    required this.thumbnailUrl,
    required this.highResArtUrl,
    this.localFilePath,
    this.localArtPath,
    this.isDownloaded = false,
    this.audioBitrateKbps = 160,
    required this.addedAt,
  });

  Duration get duration => Duration(seconds: durationSeconds);

  String get formattedDuration {
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  ZunifySong copyWith({
    String? videoId,
    String? title,
    String? artist,
    String? album,
    int? durationSeconds,
    String? thumbnailUrl,
    String? highResArtUrl,
    String? localFilePath,
    String? localArtPath,
    bool? isDownloaded,
    int? audioBitrateKbps,
    DateTime? addedAt,
  }) {
    return ZunifySong(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      highResArtUrl: highResArtUrl ?? this.highResArtUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      localArtPath: localArtPath ?? this.localArtPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      audioBitrateKbps: audioBitrateKbps ?? this.audioBitrateKbps,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'title': title,
      'artist': artist,
      'album': album,
      'durationSeconds': durationSeconds,
      'thumbnailUrl': thumbnailUrl,
      'highResArtUrl': highResArtUrl,
      'localFilePath': localFilePath,
      'localArtPath': localArtPath,
      'isDownloaded': isDownloaded ? 1 : 0,
      'audioBitrateKbps': audioBitrateKbps,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory ZunifySong.fromMap(Map<String, dynamic> map) {
    return ZunifySong(
      videoId: map['videoId'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: (map['album'] as String?) ?? 'YouTube Music',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      highResArtUrl: map['highResArtUrl'] as String? ?? '',
      localFilePath: map['localFilePath'] as String?,
      localArtPath: map['localArtPath'] as String?,
      isDownloaded: (map['isDownloaded'] == 1 || map['isDownloaded'] == true),
      audioBitrateKbps: (map['audioBitrateKbps'] as num?)?.toInt() ?? 160,
      addedAt: DateTime.tryParse(map['addedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
