import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lyric_model.dart';
import '../models/song_model.dart';
import '../models/weekly_rapot_model.dart';
import '../services/download_service.dart';
import '../services/equalizer_service.dart';
import '../services/lyrics_translation_service.dart';
import '../services/rapot_service.dart';
import '../services/ytmusic_service.dart';
import 'library_provider.dart';
import 'theme_provider.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final YTMusicService _ytMusicService;
  final LyricsTranslationService _lyricsService;
  final DownloadService _downloadService;
  final EqualizerService _equalizerService;
  final RapotService _rapotService;
  final LibraryProvider _libraryProvider;
  final ThemeProvider _themeProvider;

  ZunifySong? _currentSong;
  List<ZunifySong> _queue = [];
  int _currentIndex = 0;

  bool _isLoadingTrack = false;
  bool _offlineModeEnabled = false;
  bool _highQualityAudio = true; // true = 160kbps, false = 96kbps (Hemat Kuota)
  final bool _autoRadioEnabled = true; // Spotify-like Up Next recommendation algorithm

  // Synced Bilingual Lyrics State
  SyncedLyrics? _currentLyrics;
  bool _isLoadingLyrics = false;
  int _activeLyricIndex = 0;

  // Sleep Timer State
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  bool _stopAfterCurrentSong = false;

  // Hardware Equalizer State
  bool _eqEnabled = true;
  String _selectedEqPresetName = 'Bass Boost 🔥';
  List<int> _bandLevels = [950, 650, 0, 150, 300];
  int _bassBoostStrength = 850;
  int _virtualizerStrength = 350;

  // Listening Tracker for Weekly Rapot
  DateTime? _trackPlayStartedAt;

  PlayerProvider({
    required YTMusicService ytMusicService,
    required LyricsTranslationService lyricsService,
    required DownloadService downloadService,
    required EqualizerService equalizerService,
    required RapotService rapotService,
    required LibraryProvider libraryProvider,
    required ThemeProvider themeProvider,
  })  : _ytMusicService = ytMusicService,
        _lyricsService = lyricsService,
        _downloadService = downloadService,
        _equalizerService = equalizerService,
        _rapotService = rapotService,
        _libraryProvider = libraryProvider,
        _themeProvider = themeProvider {
    _initAudioListeners();
  }

  AudioPlayer get audioPlayer => _audioPlayer;
  ZunifySong? get currentSong => _currentSong;
  List<ZunifySong> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get isPlaying => _audioPlayer.playing;
  bool get isLoadingTrack => _isLoadingTrack;
  bool get offlineModeEnabled => _offlineModeEnabled;
  bool get highQualityAudio => _highQualityAudio;
  bool get autoRadioEnabled => _autoRadioEnabled;

  SyncedLyrics? get currentLyrics => _currentLyrics;
  bool get isLoadingLyrics => _isLoadingLyrics;
  int get activeLyricIndex => _activeLyricIndex;

  // Sleep timer getters
  bool get hasActiveSleepTimer => _sleepTimerEndTime != null || _stopAfterCurrentSong;
  bool get stopAfterCurrentSong => _stopAfterCurrentSong;
  Duration? get remainingSleepTime {
    if (_sleepTimerEndTime == null) return null;
    final diff = _sleepTimerEndTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  // Equalizer getters
  bool get eqEnabled => _eqEnabled;
  String get selectedEqPresetName => _selectedEqPresetName;
  List<int> get bandLevels => List.unmodifiable(_bandLevels);
  int get bassBoostStrength => _bassBoostStrength;
  int get virtualizerStrength => _virtualizerStrength;

  Future<void> initPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _highQualityAudio = prefs.getBool('high_quality_audio') ?? true;
    _offlineModeEnabled = prefs.getBool('offline_mode_enabled') ?? false;
    _eqEnabled = prefs.getBool('eq_enabled') ?? true;
    _selectedEqPresetName = prefs.getString('eq_preset_name') ?? 'Bass Boost 🔥';
    notifyListeners();
  }

  void _initAudioListeners() {
    // Bind hardware equalizer when Android audio session ID becomes active
    _audioPlayer.androidAudioSessionIdStream.listen((sessionId) {
      if (sessionId != null && sessionId > 0) {
        _equalizerService.bindAudioSession(sessionId, enabled: _eqEnabled);
        final preset = EqualizerService.presets.firstWhere(
          (p) => p.name == _selectedEqPresetName,
          orElse: () => EqualizerService.presets[1],
        );
        _equalizerService.applyPreset(preset);
      }
    });

    // Sync active karaoke lyric line on position change
    _audioPlayer.positionStream.listen((pos) {
      _updateActiveLyricLine(pos);
    });

    // Handle track completion, Sleep Timer "End of Track", and Auto Radio Up-Next
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _flushListenLog();
        if (_stopAfterCurrentSong) {
          cancelSleepTimer();
          _audioPlayer.pause();
        } else {
          playNext();
        }
      }
      notifyListeners();
    });
  }

  void _updateActiveLyricLine(Duration position) {
    final lyrics = _currentLyrics;
    if (lyrics == null || lyrics.lines.isEmpty) return;

    int newIdx = 0;
    for (int i = 0; i < lyrics.lines.length; i++) {
      if (position >= lyrics.lines[i].timestamp) {
        newIdx = i;
      } else {
        break;
      }
    }
    if (newIdx != _activeLyricIndex) {
      _activeLyricIndex = newIdx;
      notifyListeners();
    }
  }

  /// Plays a song and optionally populates Spotify-style Radio Up-Next queue
  Future<void> playSong(
    ZunifySong song, {
    List<ZunifySong>? customQueue,
  }) async {
    _flushListenLog();

    _isLoadingTrack = true;
    _currentSong = song;
    _activeLyricIndex = 0;
    notifyListeners();

    if (customQueue != null && customQueue.isNotEmpty) {
      _queue = List.from(customQueue);
      _currentIndex = _queue.indexWhere((s) => s.videoId == song.videoId);
      if (_currentIndex < 0) {
        _queue.insert(0, song);
        _currentIndex = 0;
      }
    } else {
      _queue = [song];
      _currentIndex = 0;
    }

    try {
      // Check if song is downloaded in Private Vault first!
      final offlineCopy = _libraryProvider.getDownloadedSong(song.videoId);
      AudioSource source;

      if (offlineCopy != null && offlineCopy.localFilePath != null) {
        source = AudioSource.uri(
          Uri.file(offlineCopy.localFilePath!),
          tag: MediaItem(
            id: song.videoId,
            album: song.album,
            title: song.title,
            artist: song.artist,
            duration: song.duration,
            artUri: offlineCopy.localArtPath != null
                ? Uri.file(offlineCopy.localArtPath!)
                : Uri.parse(song.highResArtUrl),
          ),
        );
      } else {
        if (_offlineModeEnabled) {
          _isLoadingTrack = false;
          notifyListeners();
          return;
        }
        final resolvedStream = await _ytMusicService.resolveAudioStream(
          song.videoId,
          highQuality: _highQualityAudio,
        );
        if (resolvedStream == null) {
          _isLoadingTrack = false;
          notifyListeners();
          return;
        }
        source = AudioSource.uri(
          resolvedStream.url,
          headers: resolvedStream.headers,
          tag: MediaItem(
            id: song.videoId,
            album: song.album,
            title: song.title,
            artist: song.artist,
            duration: song.duration,
            artUri: Uri.parse(song.highResArtUrl),
          ),
        );
      }

      try {
        await _audioPlayer.setAudioSource(source);
      } catch (_) {
        // Fallback if MediaItem notification fails on strict OEM ROMs
        if (offlineCopy != null && offlineCopy.localFilePath != null) {
          await _audioPlayer.setFilePath(offlineCopy.localFilePath!);
        } else {
          final fallbackStream = await _ytMusicService.resolveAudioStream(
            song.videoId,
            highQuality: _highQualityAudio,
          );
          if (fallbackStream != null) {
            await _audioPlayer.setAudioSource(
              AudioSource.uri(fallbackStream.url, headers: fallbackStream.headers),
            );
          }
        }
      }

      _isLoadingTrack = false;
      _trackPlayStartedAt = DateTime.now();
      await _audioPlayer.play();
      await _libraryProvider.addToRecentlyPlayed(song);

      // Extract Dynamic Album Art Color for Ambient Glow
      if (song.highResArtUrl.isNotEmpty) {
        _themeProvider.updateDynamicColorFromImage(
          CachedNetworkImageProvider(song.highResArtUrl),
        );
      }

      // Load Synced Karaoke Lyrics + Indonesian Translation in background
      _loadLyricsForSong(song);

      // Pre-fetch next song's stream URI in queue for instant gapless transition
      if (_currentIndex + 1 < _queue.length && !_offlineModeEnabled) {
        _ytMusicService.prefetchNextSongStream(
          _queue[_currentIndex + 1].videoId,
          highQuality: _highQualityAudio,
        );
      }

      // Populate Spotify-like Radio Up-Next queue if needed
      if (_autoRadioEnabled && !_offlineModeEnabled && _queue.length <= 2) {
        _populateRadioRecommendations(song);
      }
    } catch (_) {
      _isLoadingTrack = false;
      notifyListeners();
    }
  }

  Future<void> _loadLyricsForSong(ZunifySong song) async {
    _isLoadingLyrics = true;
    _currentLyrics = null;
    notifyListeners();

    // Check offline vault lyrics first
    final cached = await _downloadService.getOfflineCachedLyrics(song.videoId);
    if (cached != null) {
      _currentLyrics = cached;
      _isLoadingLyrics = false;
      notifyListeners();
      return;
    }

    if (!_offlineModeEnabled) {
      _currentLyrics = await _lyricsService.fetchSyncedBilingualLyrics(song);
    }
    _isLoadingLyrics = false;
    notifyListeners();
  }

  Future<void> _populateRadioRecommendations(ZunifySong seedSong) async {
    final existingIds = _queue.map((s) => s.videoId).toSet();
    final recs = await _ytMusicService.getRadioRecommendations(
      seedSong,
      excludeVideoIds: existingIds,
    );
    if (recs.isNotEmpty) {
      _queue.addAll(recs);
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    notifyListeners();
  }

  Future<void> playNext() async {
    if (_queue.isEmpty) return;
    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
      await playSong(_queue[_currentIndex], customQueue: _queue);
    } else if (_autoRadioEnabled && _currentSong != null && !_offlineModeEnabled) {
      await _populateRadioRecommendations(_currentSong!);
      if (_currentIndex + 1 < _queue.length) {
        _currentIndex++;
        await playSong(_queue[_currentIndex], customQueue: _queue);
      }
    }
  }

  Future<void> playPrevious() async {
    if (_audioPlayer.position.inSeconds > 4) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      await playSong(_queue[_currentIndex], customQueue: _queue);
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
    _updateActiveLyricLine(position);
  }

  // Offline Mode & Audio Quality Toggles
  Future<void> setOfflineMode(bool enabled) async {
    _offlineModeEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_mode_enabled', enabled);

    if (enabled && _libraryProvider.downloadedSongs.isNotEmpty && _currentSong == null) {
      await playSong(
        _libraryProvider.downloadedSongs.first,
        customQueue: _libraryProvider.downloadedSongs,
      );
    }
  }

  Future<void> setHighQualityAudio(bool highQuality) async {
    _highQualityAudio = highQuality;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('high_quality_audio', highQuality);
  }

  // Sleep Timer Controls (Fitur B)
  void setSleepTimerDuration(Duration duration) {
    cancelSleepTimer();
    _stopAfterCurrentSong = false;
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      _audioPlayer.pause();
      cancelSleepTimer();
    });
    notifyListeners();
  }

  void setSleepTimerEndOfTrack() {
    cancelSleepTimer();
    _stopAfterCurrentSong = true;
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    _stopAfterCurrentSong = false;
    notifyListeners();
  }

  // Hardware Equalizer Controls
  Future<void> setEqualizerEnabled(bool enabled) async {
    _eqEnabled = enabled;
    await _equalizerService.setEnabled(enabled);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled', enabled);
  }

  Future<void> selectEqPreset(EqPreset preset) async {
    _selectedEqPresetName = preset.name;
    _bandLevels = List.from(preset.bandLevelsMilliBels);
    _bassBoostStrength = preset.bassBoostStrength;
    _virtualizerStrength = preset.virtualizerStrength;
    await _equalizerService.applyPreset(preset);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eq_preset_name', preset.name);
  }

  Future<void> updateCustomBandLevel(int bandIndex, int levelMilliBels) async {
    _selectedEqPresetName = 'Custom';
    _bandLevels[bandIndex] = levelMilliBels;
    await _equalizerService.setBandLevel(bandIndex, levelMilliBels);
    notifyListeners();
  }

  Future<void> updateBassBoost(int strength) async {
    _bassBoostStrength = strength;
    await _equalizerService.setBassBoost(strength);
    notifyListeners();
  }

  Future<void> updateVirtualizer(int strength) async {
    _virtualizerStrength = strength;
    await _equalizerService.setVirtualizer(strength);
    notifyListeners();
  }

  // Record listen time into Weekly Rapot SQLite DB
  void _flushListenLog() {
    if (_currentSong != null && _trackPlayStartedAt != null) {
      final elapsedSec = DateTime.now().difference(_trackPlayStartedAt!).inSeconds;
      if (elapsedSec >= 15) {
        _rapotService.recordSongListen(
          _currentSong!,
          elapsedSec.clamp(15, _currentSong!.durationSeconds),
        );
      }
    }
    _trackPlayStartedAt = null;
  }

  Future<WeeklyRapot> getWeeklyRapot() => _rapotService.generateCurrentWeeklyRapot();

  @override
  void dispose() {
    _flushListenLog();
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
