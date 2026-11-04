import 'song_model.dart';

enum PlaylistOrigin {
  local,
  spotifyImport,
  youtubeMusicImport,
}

class ZunifyPlaylist {
  final String id;
  final String name;
  final String description;
  final String? coverUrl;
  final PlaylistOrigin origin;
  final String? sourceUrl;
  final List<ZunifySong> songs;
  final DateTime createdAt;

  const ZunifyPlaylist({
    required this.id,
    required this.name,
    this.description = '',
    this.coverUrl,
    this.origin = PlaylistOrigin.local,
    this.sourceUrl,
    required this.songs,
    required this.createdAt,
  });

  String get originBadgeLabel {
    switch (origin) {
      case PlaylistOrigin.spotifyImport:
        return 'Spotify Import';
      case PlaylistOrigin.youtubeMusicImport:
        return 'YT Music Import';
      case PlaylistOrigin.local:
        return 'Zunify Lokal';
    }
  }

  ZunifyPlaylist copyWith({
    String? id,
    String? name,
    String? description,
    String? coverUrl,
    PlaylistOrigin? origin,
    String? sourceUrl,
    List<ZunifySong>? songs,
    DateTime? createdAt,
  }) {
    return ZunifyPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      origin: origin ?? this.origin,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'coverUrl': coverUrl,
        'origin': origin.name,
        'sourceUrl': sourceUrl,
        'songs': songs.map((s) => s.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ZunifyPlaylist.fromJson(Map<String, dynamic> json) {
    final originStr = json['origin'] as String? ?? 'local';
    final origin = PlaylistOrigin.values.firstWhere(
      (e) => e.name == originStr,
      orElse: () => PlaylistOrigin.local,
    );
    return ZunifyPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      origin: origin,
      sourceUrl: json['sourceUrl'] as String?,
      songs: ((json['songs'] as List<dynamic>?) ?? [])
          .map((e) => ZunifySong.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
