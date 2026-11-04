import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song_model.dart';

class _CachedStreamEntry {
  final Uri uri;
  final DateTime expiresAt;
  const _CachedStreamEntry(this.uri, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

/// Standalone YouTube Music Engine for Zunify (No Login / OAuth Required)
/// Handles search, mood curation, Spotify-like Up-Next Radio algorithm,
/// and 96kbps vs 160kbps stream extraction with TTL Stream Caching & Pre-fetching.
class YTMusicService {
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, _CachedStreamEntry> _streamCache = {};
  final Map<String, List<ZunifySong>> _searchCache = {};

  /// Search songs on YouTube Music without requiring user login
  Future<List<ZunifySong>> searchSongs(String query, {int limit = 20}) async {
    final cleanKey = '${query.trim().toLowerCase()}_$limit';
    if (query.trim().isEmpty) return [];
    if (_searchCache.containsKey(cleanKey)) {
      return _searchCache[cleanKey]!;
    }
    try {
      final results = await _yt.search.search('$query official audio');
      final songs = <ZunifySong>[];

      for (final video in results.take(limit)) {
        // Filter out overly long compilations (> 12 mins) unless explicitly searched
        final dur = video.duration?.inSeconds ?? 0;
        if (dur == 0 || dur > 720) continue;

        songs.add(_mapVideoToSong(video));
      }
      if (songs.isNotEmpty) {
        _searchCache[cleanKey] = songs;
      }
      return songs;
    } catch (_) {
      return [];
    }
  }

  /// Spotify-style "Up Next / Radio" Recommendation Algorithm
  /// Analyzes the current song's artist and title to fetch a continuous
  /// mix of similar tracks, filtering out duplicates.
  Future<List<ZunifySong>> getRadioRecommendations(
    ZunifySong seedSong, {
    Set<String> excludeVideoIds = const {},
  }) async {
    try {
      final results = <ZunifySong>[];
      final seenIds = <String>{seedSong.videoId, ...excludeVideoIds};

      // 1. Fetch YouTube's native related videos stream (InnerTube Watch Next)
      final video = await _yt.videos.get(seedSong.videoId);
      final related = await _yt.videos.getRelatedVideos(video);

      if (related != null) {
        for (final rel in related) {
          final dur = rel.duration?.inSeconds ?? 0;
          if (dur > 60 && dur <= 540 && !seenIds.contains(rel.id.value)) {
            seenIds.add(rel.id.value);
            results.add(_mapVideoToSong(rel));
            if (results.length >= 12) break;
          }
        }
      }

      // 2. Fallback / Enrichment: Smart Artist + Vibe Mix query
      if (results.length < 6) {
        final mixTracks = await searchSongs(
          '${seedSong.artist} mix lagu mirip ${seedSong.title}',
          limit: 10,
        );
        for (final track in mixTracks) {
          if (!seenIds.contains(track.videoId)) {
            seenIds.add(track.videoId);
            results.add(track);
          }
        }
      }

      return results;
    } catch (_) {
      return searchSongs('${seedSong.artist} hits', limit: 10);
    }
  }

  /// Trending Indonesia & Global Charts for Home Screen
  Future<List<ZunifySong>> getTrendingIndonesia() async {
    return searchSongs('lagu pop indonesia terbaru hits terpopuler', limit: 12);
  }

  Future<List<ZunifySong>> getTrendingGlobal() async {
    return searchSongs('top global hits songs official audio', limit: 12);
  }

  /// Curated Mood / Genre Chips on Home Screen
  Future<List<ZunifySong>> getSongsByMood(String mood) async {
    final moodQueries = <String, String>{
      'Chill': 'chill vibes lofi r&b santai official audio',
      'Galau': 'lagu galau indonesia sedih malam hari official audio',
      'Fokus': 'deep focus study chillhop instrumental',
      'Workout': 'workout gym phonk energetic bass boost songs',
      'Pop Indo': 'lagu pop indonesia hits Hindia Tulus Mahalini Bernady',
      'K-Pop': 'kpop hits newjeans aespa jungkook official audio',
      'Anime': 'anime opening ost hits yoasobi kenshi yonezu official',
    };
    final query = moodQueries[mood] ?? '$mood music hits';
    return searchSongs(query, limit: 15);
  }

  /// Resolves direct playable audio stream URI from videoId with 2-hour TTL Cache
  /// Supports Audio Quality Selector:
  /// - highQuality = true  -> ~160 kbps Opus/M4A (Jernih Maksimal)
  /// - highQuality = false -> ~96 kbps (Hemat Kuota)
  Future<Uri?> getAudioStreamUri(
    String videoId, {
    required bool highQuality,
  }) async {
    final cacheKey = '${videoId}_${highQuality ? "hq" : "low"}';
    final cached = _streamCache[cacheKey];
    if (cached != null && cached.isValid) {
      return cached.uri;
    }

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly.toList();
      if (audioStreams.isEmpty) return null;

      // Sort by bitrate ascending
      audioStreams.sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));

      Uri resolvedUri;
      if (highQuality) {
        // Highest quality stream (~160kbps Opus or AAC)
        resolvedUri = audioStreams.last.url;
      } else {
        // Hemat Kuota: pick stream closest to 64-96 kbps
        AudioOnlyStreamInfo selected = audioStreams.first;
        for (final s in audioStreams) {
          if (s.bitrate.kiloBitsPerSecond <= 105) {
            selected = s;
          }
        }
        resolvedUri = selected.url;
      }

      _streamCache[cacheKey] = _CachedStreamEntry(
        resolvedUri,
        DateTime.now().add(const Duration(hours: 2)),
      );
      return resolvedUri;
    } catch (_) {
      return null;
    }
  }

  /// Pre-resolves the next song's stream URI in the background for zero-delay gapless transition
  Future<void> prefetchNextSongStream(String videoId, {required bool highQuality}) async {
    try {
      await getAudioStreamUri(videoId, highQuality: highQuality);
    } catch (_) {}
  }

  ZunifySong _mapVideoToSong(Video video) {
    String cleanTitle = video.title
        .replaceAll(RegExp(r'\(Official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[Official.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Lyric.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Audio.*?\)', caseSensitive: false), '')
        .trim();

    String artist = video.author.replaceAll(' - Topic', '').trim();

    // If title is formatted as "Artist - Song Title", split cleanly
    if (cleanTitle.contains(' - ')) {
      final parts = cleanTitle.split(' - ');
      if (parts.length >= 2 && parts[0].trim().length < 35) {
        artist = parts[0].trim();
        cleanTitle = parts.sublist(1).join(' - ').trim();
      }
    }

    return ZunifySong(
      videoId: video.id.value,
      title: cleanTitle,
      artist: artist,
      album: 'YouTube Music',
      durationSeconds: video.duration?.inSeconds ?? 210,
      thumbnailUrl: video.thumbnails.mediumResUrl,
      highResArtUrl: video.thumbnails.highResUrl,
      addedAt: DateTime.now(),
    );
  }

  void dispose() {
    _yt.close();
  }
}
