class LiteSong {
  final String videoId;
  final String title;
  final String artist;
  final int durationSeconds;
  final String thumbnailUrl;

  const LiteSong({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    required this.thumbnailUrl,
  });

  Duration get duration => Duration(seconds: durationSeconds);

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'v': videoId,
        't': title,
        'a': artist,
        'd': durationSeconds,
        'u': thumbnailUrl,
      };

  factory LiteSong.fromJson(Map<String, dynamic> j) {
    return LiteSong(
      videoId: (j['v'] ?? '').toString(),
      title: (j['t'] ?? 'Unknown').toString(),
      artist: (j['a'] ?? 'Unknown Artist').toString(),
      durationSeconds: (j['d'] as num?)?.toInt() ?? 180,
      thumbnailUrl: (j['u'] ?? '').toString(),
    );
  }
}

class LitePlaylist {
  final String id;
  final String name;
  final List<LiteSong> songs;

  const LitePlaylist({
    required this.id,
    required this.name,
    required this.songs,
  });

  LitePlaylist copyWith({
    String? name,
    List<LiteSong>? songs,
  }) {
    return LitePlaylist(
      id: id,
      name: name ?? this.name,
      songs: songs ?? this.songs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'n': name,
        's': songs.map((e) => e.toJson()).toList(),
      };

  factory LitePlaylist.fromJson(Map<String, dynamic> j) {
    final rawSongs = (j['s'] as List<dynamic>?) ?? const [];
    return LitePlaylist(
      id: (j['id'] ?? '').toString(),
      name: (j['n'] ?? 'Playlist').toString(),
      songs: rawSongs
          .whereType<Map>()
          .map((m) => LiteSong.fromJson(Map<String, dynamic>.from(m)))
          .where((s) => s.videoId.isNotEmpty)
          .toList(),
    );
  }
}
