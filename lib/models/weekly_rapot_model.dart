import 'song_model.dart';

class TopArtistStat {
  final String artistName;
  final int playCount;
  final int totalSeconds;
  final String sampleThumbnailUrl;

  const TopArtistStat({
    required this.artistName,
    required this.playCount,
    required this.totalSeconds,
    required this.sampleThumbnailUrl,
  });

  int get totalMinutes => (totalSeconds / 60).ceil();
}

class TopSongStat {
  final ZunifySong song;
  final int playCount;
  final int totalSeconds;

  const TopSongStat({
    required this.song,
    required this.playCount,
    required this.totalSeconds,
  });
}

class WeeklyRapot {
  final String weekId; // e.g., "2026-W45"
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalSecondsListened;
  final int totalTracksPlayed;
  final List<TopSongStat> topSongs;
  final List<TopArtistStat> topArtists;
  final String vibePersonaTitle; // e.g., "Night Owl Melancholic 🌙"
  final String vibePersonaSubtitle;
  final Map<int, int> minutesPerWeekday; // 1 (Mon) .. 7 (Sun)

  const WeeklyRapot({
    required this.weekId,
    required this.weekStart,
    required this.weekEnd,
    required this.totalSecondsListened,
    required this.totalTracksPlayed,
    required this.topSongs,
    required this.topArtists,
    required this.vibePersonaTitle,
    required this.vibePersonaSubtitle,
    required this.minutesPerWeekday,
  });

  int get totalMinutes => (totalSecondsListened / 60).round();

  String get formattedListenTime {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0) {
      return '$hours jam $mins menit';
    }
    return '$mins menit';
  }
}
