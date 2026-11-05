import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lyric_model.dart';
import '../models/song_model.dart';
import '../models/weekly_rapot_model.dart';
import '../services/download_service.dart';
import '../services/equalizer_service.dart';
import '../services/lyrics_translation_service.dart';
import '../services/rapot_service.dart';
import '../services/ytmusic_service.dart';
import '../services/zunify_audio_handler.dart';
import 'library_provider.dart';
import 'theme_provider.dart';

/// Where a track in the play queue came from (Spotify-style queue sections).
enum QueueSource {
  /// The playlist / album / list the user started playing from.
  context,

  /// Tracks the user explicitly added ("Tambahkan ke Antrean" / "Putar Berikutnya").
  user,

  /// Smart recommendations appended automatically when the context runs out.
  autoplay,
}

class PlayerProvider extends ChangeNotifier {
  final ZunifyAudioHandler? _audioHandler;
  late final AudioPlayer _audioPlayer;
  final YTMusicService _ytMusicService;
  final LyricsTranslationService _lyricsService;
  final DownloadService _downloadService;
  final EqualizerService _equalizerService;
  final RapotService _rapotService;
  final LibraryProvider _libraryProvider;
  final ThemeProvider _themeProvider;

  // ---------------------------------------------------------------------------
  // Spotify-style Queue State
  // Flat queue layout: [history..., current, user queue..., context..., autoplay...]
  // ---------------------------------------------------------------------------
  ZunifySong? _currentSong;
  List<ZunifySong> _queue = [];
  List<QueueSource> _sources = [];
  int _currentIndex = 0;
  String _contextName = '';
  List<ZunifySong> _originalContextOrder = [];

  bool _autoplayEnabled = true;
  bool _isFetchingAutoplay = false;

  // Lightweight taste signals for the recommendation algorithm
  final List<String> _recentHistoryIds = [];
  final Map<String, int> _artistSkipPenalty = {};
  final Random _random = Random();

  bool _isLoadingTrack = false;
  bool _offlineModeEnabled = false;
  bool _highQualityAudio = true; // true = 160kbps, false = 96kbps (Hemat Kuota)
  bool _autoQualityEnabled = true; // Feature #3: Wi-Fi = 160kbps, Data = 96kbps
  String _detectedNetworkType = 'wifi';
  DateTime? _lastNetCheckAt;

  // Feature #1: Crossfade & Gapless Transition (0 = Off, 3..8s = Smooth Crossfade)
  int _crossfadeSeconds = 4;
  bool _crossfadeTriggeredForCurrent = false;
  Timer? _fadeInTimer;

  static const MethodChannel _nativeChannel =
      MethodChannel('com.fannz.zunify/equalizer');

  // Shuffle & Repeat State (0 = Off, 1 = Repeat Queue, 2 = Repeat One)
  bool _shuffleEnabled = false;
  int _repeatMode = 0;

  // Guards against stale loads when the user skips quickly
  int _playToken = 0;
  bool? _lastNotifiedPlaying;
  ProcessingState? _lastNotifiedProcessing;

  // Synced Lyrics State
  SyncedLyrics? _currentLyrics;
  bool _isLoadingLyrics = false;
  bool _isTranslatingLyrics = false;
  int _activeLyricIndex = -1; // -1 = intro (before the first line)
  bool _showTranslation = false; // Manual translation button (OFF by default)
  int _lyricsOffsetMs = 0; // User adjustable offset (-5000 .. +5000)
  Timer? _lyricsTicker;

  /// Lines light up slightly before they are sung (like Spotify / Apple Music)
  /// so the highlight animation finishes exactly when the vocal starts.
  static const int _lyricsLeadMs = 280;

  // Sleep Timer State
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  bool _stopAfterCurrentSong = false;

  // Hardware Equalizer State (OFF by default, flat "Normal" preset)
  bool _eqEnabled = false;
  String _selectedEqPresetName = 'Normal';
  List<int> _bandLevels = [0, 0, 0, 0, 0];
  int _bassBoostStrength = 0;
  int _virtualizerStrength = 0;

  // Listening Tracker for Weekly Rapot
  DateTime? _trackPlayStartedAt;

  PlayerProvider({
    ZunifyAudioHandler? audioHandler,
    required YTMusicService ytMusicService,
    required LyricsTranslationService lyricsService,
    required DownloadService downloadService,
    required EqualizerService equalizerService,
    required RapotService rapotService,
    required LibraryProvider libraryProvider,
    required ThemeProvider themeProvider,
  })  : _audioHandler = audioHandler,
        _ytMusicService = ytMusicService,
        _lyricsService = lyricsService,
        _downloadService = downloadService,
        _equalizerService = equalizerService,
        _rapotService = rapotService,
        _libraryProvider = libraryProvider,
        _themeProvider = themeProvider {
    _audioPlayer = _audioHandler?.player ?? AudioPlayer();
    _audioHandler?.onSkipToNextCallback = playNext;
    _audioHandler?.onSkipToPreviousCallback = playPrevious;
    _initAudioListeners();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------
  AudioPlayer get audioPlayer => _audioPlayer;
  ZunifySong? get currentSong => _currentSong;
  List<ZunifySong> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  String get contextName => _contextName;
  bool get autoplayEnabled => _autoplayEnabled;
  bool get autoRadioEnabled => _autoplayEnabled;
  bool get isFetchingAutoplay => _isFetchingAutoplay;

  QueueSource sourceAt(int index) =>
      (index >= 0 && index < _sources.length) ? _sources[index] : QueueSource.context;

  int get upcomingCount =>
      (_queue.length - _currentIndex - 1).clamp(0, _queue.length);

  bool get isPlaying => _audioPlayer.playing;
  bool get isLoadingTrack => _isLoadingTrack;
  bool get offlineModeEnabled => _offlineModeEnabled;
  bool get highQualityAudio => _highQualityAudio;
  bool get autoQualityEnabled => _autoQualityEnabled;
  String get detectedNetworkType => _detectedNetworkType;
  int get crossfadeSeconds => _crossfadeSeconds;

  String get activeQualityLabel {
    if (_autoQualityEnabled) {
      return _detectedNetworkType == 'cellular'
          ? 'Otomatis • Data Seluler (96kbps Hemat)'
          : 'Otomatis • Wi-Fi (160kbps HQ)';
    }
    return _highQualityAudio
        ? '160 kbps High Quality'
        : '96 kbps Hemat Kuota';
  }

  bool get shuffleEnabled => _shuffleEnabled;
  int get repeatMode => _repeatMode;

  SyncedLyrics? get currentLyrics => _currentLyrics;
  bool get isLoadingLyrics => _isLoadingLyrics;
  bool get isTranslatingLyrics => _isTranslatingLyrics;
  int get activeLyricIndex => _activeLyricIndex;
  bool get showTranslation => _showTranslation;
  int get lyricsOffsetMs => _lyricsOffsetMs;

  bool get hasActiveSleepTimer =>
      _sleepTimerEndTime != null || _stopAfterCurrentSong;
  bool get stopAfterCurrentSong => _stopAfterCurrentSong;
  Duration? get remainingSleepTime {
    if (_sleepTimerEndTime == null) return null;
    final diff = _sleepTimerEndTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get eqEnabled => _eqEnabled;
  String get selectedEqPresetName => _selectedEqPresetName;
  List<int> get bandLevels => List.unmodifiable(_bandLevels);
  int get bassBoostStrength => _bassBoostStrength;
  int get virtualizerStrength => _virtualizerStrength;

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------
  Future<void> initPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _highQualityAudio = prefs.getBool('high_quality_audio') ?? true;
    _autoQualityEnabled = prefs.getBool('auto_quality_enabled') ?? true;
    _crossfadeSeconds = prefs.getInt('crossfade_seconds') ?? 4;
    _offlineModeEnabled = prefs.getBool('offline_mode_enabled') ?? false;
    unawaited(_refreshNetworkType());

    // v1.6: Equalizer defaults to OFF + flat (new key so old installs reset too)
    _eqEnabled = prefs.getBool('eq_enabled_v2') ?? false;
    _selectedEqPresetName = prefs.getString('eq_preset_name_v2') ?? 'Normal';
    final preset = EqualizerService.presets.firstWhere(
      (p) => p.name == _selectedEqPresetName,
      orElse: () => EqualizerService.presets.first,
    );
    _selectedEqPresetName = preset.name;
    _bandLevels = List.from(preset.bandLevelsMilliBels);
    _bassBoostStrength = preset.bassBoostStrength;
    _virtualizerStrength = preset.virtualizerStrength;

    _autoplayEnabled = prefs.getBool('autoplay_enabled') ?? true;
    _showTranslation = false;
    _shuffleEnabled = prefs.getBool('shuffle_enabled') ?? false;
    _repeatMode = prefs.getInt('repeat_mode') ?? 0;
    _recentHistoryIds
      ..clear()
      ..addAll(prefs.getStringList('recent_history_ids') ?? const []);
    notifyListeners();
  }

  void _initAudioListeners() {
    // Bind hardware equalizer when the Android audio session becomes active
    _audioPlayer.androidAudioSessionIdStream.listen((sessionId) async {
      if (sessionId != null && sessionId > 0) {
        await _equalizerService.bindAudioSession(sessionId, enabled: _eqEnabled);
        if (_eqEnabled) {
          await _applyCurrentEqLevels();
        } else {
          await _equalizerService.setEnabled(false);
        }
      }
    });

    // Coarse position updates (precise lyric sync runs on its own ticker) + Smooth Crossfade
    _audioPlayer.positionStream.listen((pos) {
      _updateActiveLyricLine(pos);
      _handleCrossfadeTick(pos);
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (state.playing) {
        _startLyricsTicker();
      } else {
        _stopLyricsTicker();
      }

      if (state.processingState == ProcessingState.completed) {
        _flushListenLog();
        if (_stopAfterCurrentSong) {
          cancelSleepTimer();
          _audioPlayer.pause();
        } else if (_repeatMode == 2 && _currentSong != null) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        } else {
          playNext(fromCompletion: true);
        }
      }

      if (_lastNotifiedPlaying != state.playing ||
          _lastNotifiedProcessing != state.processingState) {
        _lastNotifiedPlaying = state.playing;
        _lastNotifiedProcessing = state.processingState;
        notifyListeners();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Precise Lyrics Sync (~60ms ticker + lead time + binary search)
  // ---------------------------------------------------------------------------
  void _startLyricsTicker() {
    if (_lyricsTicker != null) return;
    if (_currentLyrics == null || !_currentLyrics!.isSynced) return;
    _lyricsTicker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      final lyr = _currentLyrics;
      if (lyr == null || !lyr.isSynced || !_audioPlayer.playing) return;
      _updateActiveLyricLine(_audioPlayer.position);
    });
  }

  void _stopLyricsTicker() {
    _lyricsTicker?.cancel();
    _lyricsTicker = null;
  }

  void _handleCrossfadeTick(Duration pos) {
    if (_crossfadeSeconds <= 0 ||
        !_audioPlayer.playing ||
        _isLoadingTrack ||
        _repeatMode == 2 ||
        _stopAfterCurrentSong) {
      return;
    }
    final total = _audioPlayer.duration ?? _currentSong?.duration ?? Duration.zero;
    if (total.inSeconds < 45) return;

    final remainingMs = total.inMilliseconds - pos.inMilliseconds;
    final fadeWindowMs = _crossfadeSeconds * 1000;

    if (remainingMs > 0 && remainingMs <= fadeWindowMs) {
      // Smoothly ramp volume down as the song approaches the crossfade handoff
      final ratio = (remainingMs / fadeWindowMs).clamp(0.18, 1.0);
      _audioPlayer.setVolume(ratio);

      if (remainingMs <= 650 && !_crossfadeTriggeredForCurrent) {
        _crossfadeTriggeredForCurrent = true;
        playNext(fromCompletion: true);
      }
    }
  }

  void _startSmoothFadeIn() {
    _fadeInTimer?.cancel();
    if (_crossfadeSeconds <= 0) {
      _audioPlayer.setVolume(1.0);
      return;
    }
    double vol = 0.22;
    _audioPlayer.setVolume(vol);
    const steps = 12;
    final stepMs = ((_crossfadeSeconds * 320) ~/ steps).clamp(70, 180);
    _fadeInTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
      vol += (1.0 - 0.22) / steps;
      if (vol >= 0.99) {
        _audioPlayer.setVolume(1.0);
        timer.cancel();
      } else {
        _audioPlayer.setVolume(vol.clamp(0.22, 1.0));
      }
    });
  }

  Future<bool> _resolveEffectiveHighQuality() async {
    if (!_autoQualityEnabled) return _highQualityAudio;
    await _refreshNetworkType();
    return _detectedNetworkType != 'cellular';
  }

  Future<void> _refreshNetworkType() async {
    final now = DateTime.now();
    if (_lastNetCheckAt != null &&
        now.difference(_lastNetCheckAt!).inSeconds < 12) {
      return;
    }
    _lastNetCheckAt = now;
    try {
      final net = await _nativeChannel.invokeMethod<String>('getNetworkType');
      if (net != null && net.isNotEmpty && net != _detectedNetworkType) {
        _detectedNetworkType = net;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _updateActiveLyricLine(Duration position) {
    final lyrics = _currentLyrics;
    if (lyrics == null || lyrics.lines.isEmpty || !lyrics.isSynced) {
      if (_activeLyricIndex != -1) {
        _activeLyricIndex = -1;
        notifyListeners();
      }
      return;
    }

    final targetMs = position.inMilliseconds + _lyricsOffsetMs + _lyricsLeadMs;
    final lines = lyrics.lines;

    // Binary search: last line whose timestamp <= targetMs
    int lo = 0, hi = lines.length - 1, found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].timestamp.inMilliseconds <= targetMs) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    if (found != _activeLyricIndex) {
      _activeLyricIndex = found;
      notifyListeners();
    }
  }

  /// Triggered when the user taps the "Terjemahkan" button
  Future<void> toggleTranslationDisplay() async {
    if (_showTranslation) {
      _showTranslation = false;
      notifyListeners();
      return;
    }

    _showTranslation = true;
    notifyListeners();

    final lyrics = _currentLyrics;
    if (lyrics == null ||
        lyrics.isOriginalIndonesian ||
        lyrics.lines.length <= 1) {
      return;
    }

    final alreadyTranslated =
        lyrics.lines.any((l) => l.translatedIndoText != null);
    if (!alreadyTranslated && !_isTranslatingLyrics) {
      _isTranslatingLyrics = true;
      notifyListeners();

      final targetVideoId = lyrics.videoId;
      final translated =
          await _lyricsService.translateLyricsToIndonesian(lyrics);
      if (_currentSong?.videoId == targetVideoId) {
        _currentLyrics = translated;
      }
      _isTranslatingLyrics = false;
      notifyListeners();
    }
  }

  void adjustLyricsOffset(int deltaMs) {
    _lyricsOffsetMs = (_lyricsOffsetMs + deltaMs).clamp(-5000, 5000);
    _updateActiveLyricLine(_audioPlayer.position);
    notifyListeners();
  }

  void resetLyricsOffset() {
    _lyricsOffsetMs = 0;
    _updateActiveLyricLine(_audioPlayer.position);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Spotify-style Queue API
  // ---------------------------------------------------------------------------

  /// "Tambahkan ke Antrean": goes to the end of the user's "Berikutnya di antrean" section.
  void addToQueue(ZunifySong song) {
    if (_currentSong == null || _queue.isEmpty) {
      playSong(song);
      return;
    }
    int pos = _currentIndex + 1;
    while (pos < _queue.length && _sources[pos] == QueueSource.user) {
      pos++;
    }
    _queue.insert(pos, song);
    _sources.insert(pos, QueueSource.user);
    _prefetchNext();
    notifyListeners();
  }

  /// "Putar Berikutnya": plays right after the current song.
  void playNextInQueue(ZunifySong song) {
    if (_currentSong == null || _queue.isEmpty) {
      playSong(song);
      return;
    }
    final insertIdx = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertIdx, song);
    _sources.insert(insertIdx, QueueSource.user);
    _prefetchNext();
    notifyListeners();
  }

  /// Drag & drop reorder. The moved track adopts the section it was dropped into.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, _queue.length - 1);
    if (oldIndex == newIndex) return;

    final currentSongId = _currentSong?.videoId;
    final movedSong = _queue.removeAt(oldIndex);
    _sources.removeAt(oldIndex);
    _queue.insert(newIndex, movedSong);

    // Adopt neighbour's section so sections stay contiguous
    QueueSource adopted = QueueSource.context;
    if (newIndex - 1 >= 0 && newIndex - 1 < _sources.length) {
      adopted = _sources[newIndex - 1];
      if (_queue[newIndex - 1].videoId == currentSongId &&
          newIndex < _sources.length) {
        adopted = _sources[newIndex];
      }
    } else if (newIndex < _sources.length) {
      adopted = _sources[newIndex];
    }
    _sources.insert(newIndex, adopted);

    if (currentSongId != null) {
      final updatedIdx = _queue.indexWhere((s) => s.videoId == currentSongId);
      if (updatedIdx >= 0) _currentIndex = updatedIdx;
    }
    _prefetchNext();
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    if (index == _currentIndex) return; // never remove the playing track
    _queue.removeAt(index);
    _sources.removeAt(index);
    if (index < _currentIndex) _currentIndex--;
    _prefetchNext();
    notifyListeners();
  }

  /// Clears only the user-added "Berikutnya di antrean" section (like Spotify).
  void clearUserQueue() {
    for (int i = _queue.length - 1; i > _currentIndex; i--) {
      if (_sources[i] == QueueSource.user) {
        _queue.removeAt(i);
        _sources.removeAt(i);
      }
    }
    notifyListeners();
  }

  /// Clears everything after the current track.
  void clearUpcomingQueue() {
    if (_queue.length <= _currentIndex + 1) return;
    _queue.removeRange(_currentIndex + 1, _queue.length);
    _sources.removeRange(_currentIndex + 1, _sources.length);
    notifyListeners();
  }

  /// Tapping an upcoming track jumps to it; skipped user-queued tracks are consumed.
  Future<void> jumpToQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length || index == _currentIndex) return;
    if (index > _currentIndex) {
      for (int i = index - 1; i > _currentIndex; i--) {
        if (_sources[i] == QueueSource.user) {
          _queue.removeAt(i);
          _sources.removeAt(i);
          index--;
        }
      }
    }
    await _playAt(index);
  }

  Future<void> setAutoplayEnabled(bool enabled) async {
    _autoplayEnabled = enabled;
    if (!enabled) {
      for (int i = _queue.length - 1; i > _currentIndex; i--) {
        if (_sources[i] == QueueSource.autoplay) {
          _queue.removeAt(i);
          _sources.removeAt(i);
        }
      }
    } else {
      _maybeFillAutoplay();
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoplay_enabled', enabled);
  }

  /// Spotify shuffle: reshuffles the upcoming context tracks (user queue stays first).
  void toggleShuffle() async {
    _shuffleEnabled = !_shuffleEnabled;
    if (_queue.isNotEmpty) {
      if (_shuffleEnabled) {
        _shuffleUpcomingContext();
      } else {
        _restoreContextOrder();
      }
    }
    _prefetchNext();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shuffle_enabled', _shuffleEnabled);
  }

  void _shuffleUpcomingContext() {
    final start = _currentIndex + 1;
    final userItems = <ZunifySong>[];
    final contextItems = <ZunifySong>[];
    final autoplayItems = <ZunifySong>[];
    for (int i = start; i < _queue.length; i++) {
      switch (_sources[i]) {
        case QueueSource.user:
          userItems.add(_queue[i]);
          break;
        case QueueSource.context:
          contextItems.add(_queue[i]);
          break;
        case QueueSource.autoplay:
          autoplayItems.add(_queue[i]);
          break;
      }
    }
    contextItems.shuffle(_random);
    _rebuildUpcoming(userItems, contextItems, autoplayItems);
  }

  void _restoreContextOrder() {
    if (_originalContextOrder.isEmpty || _currentSong == null) return;
    final start = _currentIndex + 1;
    final userItems = <ZunifySong>[];
    final autoplayItems = <ZunifySong>[];
    final upcomingContextIds = <String>{};
    for (int i = start; i < _queue.length; i++) {
      if (_sources[i] == QueueSource.user) {
        userItems.add(_queue[i]);
      } else if (_sources[i] == QueueSource.autoplay) {
        autoplayItems.add(_queue[i]);
      } else {
        upcomingContextIds.add(_queue[i].videoId);
      }
    }
    final originalPos = _originalContextOrder
        .indexWhere((s) => s.videoId == _currentSong!.videoId);
    final ordered = <ZunifySong>[];
    if (originalPos >= 0) {
      // Continue from the current track's original position (Spotify behaviour)
      ordered.addAll(_originalContextOrder.sublist(originalPos + 1));
    } else {
      ordered.addAll(
        _originalContextOrder.where((s) => upcomingContextIds.contains(s.videoId)),
      );
    }
    _rebuildUpcoming(userItems, ordered, autoplayItems);
  }

  void _rebuildUpcoming(
    List<ZunifySong> userItems,
    List<ZunifySong> contextItems,
    List<ZunifySong> autoplayItems,
  ) {
    final start = _currentIndex + 1;
    _queue = [
      ..._queue.sublist(0, start),
      ...userItems,
      ...contextItems,
      ...autoplayItems,
    ];
    _sources = [
      ..._sources.sublist(0, start),
      ...List.filled(userItems.length, QueueSource.user),
      ...List.filled(contextItems.length, QueueSource.context),
      ...List.filled(autoplayItems.length, QueueSource.autoplay),
    ];
  }

  void cycleRepeatMode() async {
    _repeatMode = (_repeatMode + 1) % 3;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('repeat_mode', _repeatMode);
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  /// Starts playing [song]. If [customQueue] is given it becomes the new context
  /// (e.g. a playlist, search results, a home section) named [contextName].
  Future<void> playSong(
    ZunifySong song, {
    List<ZunifySong>? customQueue,
    String? contextName,
  }) async {
    if (customQueue != null && customQueue.isNotEmpty) {
      final ctx = <ZunifySong>[];
      final seen = <String>{};
      for (final s in customQueue) {
        if (seen.add(s.videoId)) ctx.add(s);
      }
      if (!seen.contains(song.videoId)) ctx.insert(0, song);

      _originalContextOrder = List.from(ctx);
      _contextName = contextName ?? 'Daftar putar';

      if (_shuffleEnabled) {
        final rest = ctx.where((s) => s.videoId != song.videoId).toList()
          ..shuffle(_random);
        _queue = [song, ...rest];
        _currentIndex = 0;
      } else {
        _queue = ctx;
        _currentIndex = ctx.indexWhere((s) => s.videoId == song.videoId);
      }
      _sources = List.filled(_queue.length, QueueSource.context, growable: true);
    } else {
      final existing = _queue.indexWhere((s) => s.videoId == song.videoId);
      if (existing >= 0) {
        _currentIndex = existing;
      } else {
        _queue = [song];
        _sources = [QueueSource.context];
        _currentIndex = 0;
        _originalContextOrder = [song];
        _contextName = contextName ?? song.artist;
      }
    }
    await _playAt(_currentIndex);
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _startPlayback(_queue[index]);
  }

  Future<void> _startPlayback(ZunifySong song) async {
    _flushListenLog();
    final token = ++_playToken;

    _isLoadingTrack = true;
    _currentSong = song;
    _activeLyricIndex = -1;
    _lyricsOffsetMs = 0;
    notifyListeners();

    unawaited(_loadLyricsForSong(song));
    _rememberInHistory(song);

    try {
      final offlineCopy = _libraryProvider.getDownloadedSong(song.videoId);
      final mediaItemTag = MediaItem(
        id: song.videoId,
        album: song.album.isNotEmpty ? song.album : 'Zunify Music',
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        artUri: offlineCopy?.localArtPath != null
            ? Uri.file(offlineCopy!.localArtPath!)
            : Uri.parse(song.highResArtUrl),
      );
      _audioHandler?.updateNowPlayingMediaItem(mediaItemTag);

      if (offlineCopy != null && offlineCopy.localFilePath != null) {
        await _audioPlayer.setFilePath(offlineCopy.localFilePath!);
      } else {
        if (_offlineModeEnabled) {
          _isLoadingTrack = false;
          notifyListeners();
          return;
        }
        final effectiveHq = await _resolveEffectiveHighQuality();
        final resolvedStream = await _ytMusicService.resolveAudioStream(
          song.videoId,
          highQuality: effectiveHq,
        );
        if (token != _playToken) return; // user already skipped elsewhere
        if (resolvedStream == null) {
          _isLoadingTrack = false;
          notifyListeners();
          return;
        }

        try {
          await _audioPlayer.setAudioSource(
            AudioSource.uri(
              resolvedStream.url,
              headers: resolvedStream.headers,
            ),
          );
        } catch (_) {
          if (resolvedStream.hlsUrl != null) {
            try {
              await _audioPlayer.setAudioSource(
                HlsAudioSource(
                  resolvedStream.hlsUrl!,
                  headers: resolvedStream.headers,
                ),
              );
            } catch (_) {
              await _audioPlayer.setUrl(resolvedStream.url.toString());
            }
          } else {
            await _audioPlayer.setUrl(resolvedStream.url.toString());
          }
        }
      }

      if (token != _playToken) return;

      _isLoadingTrack = false;
      _trackPlayStartedAt = DateTime.now();
      final wasCrossfaded = _crossfadeTriggeredForCurrent;
      _crossfadeTriggeredForCurrent = false;
      if (wasCrossfaded && _crossfadeSeconds > 0) {
        _startSmoothFadeIn();
      } else {
        _fadeInTimer?.cancel();
        _audioPlayer.setVolume(1.0);
      }
      notifyListeners();
      unawaited(_audioPlayer.play());
      unawaited(_libraryProvider.addToRecentlyPlayed(song));

      if (song.highResArtUrl.isNotEmpty) {
        _themeProvider.updateDynamicColorFromImage(
          CachedNetworkImageProvider(song.highResArtUrl),
        );
      }

      _prefetchNext();
      _maybeFillAutoplay();
    } catch (_) {
      if (token == _playToken) {
        _isLoadingTrack = false;
        notifyListeners();
      }
    }
  }

  void _prefetchNext() {
    if (_offlineModeEnabled) return;
    if (_currentIndex + 1 < _queue.length) {
      final next = _queue[_currentIndex + 1];
      if (!_libraryProvider.isDownloaded(next.videoId)) {
        final effectiveHq = _autoQualityEnabled
            ? (_detectedNetworkType != 'cellular')
            : _highQualityAudio;
        _ytMusicService.prefetchNextSongStream(
          next.videoId,
          highQuality: effectiveHq,
        );
      }
    }
  }

  /// Loads synced lyrics (offline cache first). Translation only on button tap.
  Future<void> _loadLyricsForSong(ZunifySong song) async {
    _isLoadingLyrics = true;
    _isTranslatingLyrics = false;
    _showTranslation = false;
    _currentLyrics = null;
    notifyListeners();

    final cached = await _downloadService.getOfflineCachedLyrics(song.videoId);
    if (cached != null && cached.lines.length > 1) {
      if (_currentSong?.videoId != song.videoId) return;
      _currentLyrics = _sanitizeLyrics(cached);
      _isLoadingLyrics = false;
      _updateActiveLyricLine(_audioPlayer.position);
      if (_audioPlayer.playing) _startLyricsTicker();
      notifyListeners();
      return;
    }

    if (_offlineModeEnabled) {
      _isLoadingLyrics = false;
      notifyListeners();
      return;
    }

    final rawLyrics = await _lyricsService.fetchRawLyricsInstant(song);
    if (_currentSong?.videoId != song.videoId) return;

    _currentLyrics = rawLyrics == null ? null : _sanitizeLyrics(rawLyrics);
    _isLoadingLyrics = false;
    _updateActiveLyricLine(_audioPlayer.position);
    if (_audioPlayer.playing) _startLyricsTicker();
    notifyListeners();
  }

  /// Sorts lines by time, trims whitespace and collapses repeated empty gaps,
  /// so the lyric list is always tidy and the binary search stays correct.
  SyncedLyrics _sanitizeLyrics(SyncedLyrics lyrics) {
    final sorted = List<LyricLine>.from(lyrics.lines);
    if (lyrics.isSynced) {
      sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    final cleaned = <LyricLine>[];
    for (final line in sorted) {
      final text = line.originalText.trim();
      final isGap = text.isEmpty;
      if (isGap) {
        if (cleaned.isEmpty || cleaned.last.originalText.isEmpty) continue;
      }
      cleaned.add(line.copyWith(originalText: text));
    }
    while (cleaned.isNotEmpty && cleaned.last.originalText.isEmpty) {
      cleaned.removeLast();
    }
    return lyrics.copyWith(lines: cleaned);
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    notifyListeners();
  }

  /// Next track. [fromCompletion] is true when the song ended naturally;
  /// otherwise it is a user skip, which feeds the taste algorithm.
  Future<void> playNext({bool fromCompletion = false}) async {
    if (_queue.isEmpty) return;

    if (!fromCompletion) _registerSkipSignal();

    if (_currentIndex + 1 < _queue.length) {
      await _playAt(_currentIndex + 1);
      return;
    }

    if (_repeatMode == 1 && _queue.isNotEmpty) {
      await _playAt(0);
      return;
    }

    if (_autoplayEnabled && _currentSong != null && !_offlineModeEnabled) {
      await _appendAutoplayRecommendations();
      if (_currentIndex + 1 < _queue.length) {
        await _playAt(_currentIndex + 1);
        return;
      }
    }

    // End of everything: stop at the beginning of the last track
    await _audioPlayer.pause();
    await _audioPlayer.seek(Duration.zero);
    notifyListeners();
  }

  Future<void> playPrevious() async {
    if (_audioPlayer.position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      await _playAt(_currentIndex - 1);
    } else if (_repeatMode == 1 && _queue.isNotEmpty) {
      await _playAt(_queue.length - 1);
    } else {
      await _audioPlayer.seek(Duration.zero);
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
    _updateActiveLyricLine(position);
  }

  // ---------------------------------------------------------------------------
  // Smart Autoplay / Recommendation Algorithm (Spotify-like)
  // ---------------------------------------------------------------------------
  void _maybeFillAutoplay() {
    if (!_autoplayEnabled || _offlineModeEnabled || _repeatMode == 1) return;
    if (upcomingCount < 3) {
      unawaited(_appendAutoplayRecommendations());
    }
  }

  void _rememberInHistory(ZunifySong song) {
    _recentHistoryIds.remove(song.videoId);
    _recentHistoryIds.insert(0, song.videoId);
    if (_recentHistoryIds.length > 80) {
      _recentHistoryIds.removeRange(80, _recentHistoryIds.length);
    }
    SharedPreferences.getInstance().then(
      (p) => p.setStringList('recent_history_ids', _recentHistoryIds),
    );
  }

  /// Skipping a track within its first 30s lowers that artist's weight a bit.
  void _registerSkipSignal() {
    final song = _currentSong;
    if (song == null) return;
    final listenedSec = _audioPlayer.position.inSeconds;
    if (listenedSec < 30) {
      final key = _artistKey(song.artist);
      _artistSkipPenalty[key] = (_artistSkipPenalty[key] ?? 0) + 1;
    }
  }

  String _artistKey(String artist) => artist
      .toLowerCase()
      .split(RegExp(r',|&| x | feat\.?| ft\.?'))
      .first
      .trim();

  String _titleKey(String title) => title
      .toLowerCase()
      .replaceAll(RegExp(r'[\(\[].*?[\)\]]'), '')
      .replaceAll(RegExp(r'feat\..*|ft\..*'), '')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool _looksLikeNonSong(ZunifySong s) {
    final t = s.title.toLowerCase();
    if (s.durationSeconds > 0 &&
        (s.durationSeconds < 60 || s.durationSeconds > 12 * 60)) {
      return true;
    }
    return t.contains('full album') ||
        t.contains('1 hour') ||
        t.contains('1 jam') ||
        t.contains('playlist') ||
        t.contains('compilation') ||
        t.contains('nonstop') ||
        t.contains('mashup');
  }

  Future<void> _appendAutoplayRecommendations() async {
    final seed = _currentSong;
    if (seed == null || _isFetchingAutoplay) return;
    _isFetchingAutoplay = true;
    notifyListeners();

    try {
      final excludeIds = <String>{
        ..._queue.map((s) => s.videoId),
        ..._recentHistoryIds.take(50),
      };
      final raw = await _ytMusicService.getRadioRecommendations(
        seed,
        excludeVideoIds: excludeIds,
      );
      if (_currentSong?.videoId != seed.videoId &&
          upcomingCount >= 3) {
        return; // user moved on and the queue is already filled
      }

      // Taste signals from the user's own library
      final favArtists = _libraryProvider.favorites
          .map((s) => _artistKey(s.artist))
          .toSet();
      final recentArtists = _libraryProvider.recentlyPlayed
          .map((s) => _artistKey(s.artist))
          .toSet();
      final queuedTitles = _queue.map((s) => _titleKey(s.title)).toSet();

      final candidates = <_ScoredSong>[];
      final seenTitles = <String>{};
      for (int i = 0; i < raw.length; i++) {
        final s = raw[i];
        if (excludeIds.contains(s.videoId)) continue;
        if (_looksLikeNonSong(s)) continue;
        final tKey = _titleKey(s.title);
        if (tKey.isEmpty || queuedTitles.contains(tKey) || !seenTitles.add(tKey)) {
          continue; // drop covers / duplicates of the same song
        }

        final aKey = _artistKey(s.artist);
        double score = (raw.length - i).toDouble(); // keep YT radio relevance
        if (favArtists.contains(aKey)) score += 6;
        if (recentArtists.contains(aKey)) score += 2.5;
        score -= (_artistSkipPenalty[aKey] ?? 0) * 4;
        score += _random.nextDouble() * 1.5; // a little freshness
        candidates.add(_ScoredSong(s, score, aKey));
      }

      candidates.sort((a, b) => b.score.compareTo(a.score));

      // Diversity pass: avoid the same artist back-to-back
      final picked = <ZunifySong>[];
      String lastArtist = _artistKey(_queue.isNotEmpty ? _queue.last.artist : seed.artist);
      while (candidates.isNotEmpty && picked.length < 10) {
        int idx = candidates.indexWhere((c) => c.artistKey != lastArtist);
        if (idx < 0) idx = 0;
        final chosen = candidates.removeAt(idx);
        picked.add(chosen.song);
        lastArtist = chosen.artistKey;
      }

      if (picked.isNotEmpty) {
        _queue.addAll(picked);
        _sources.addAll(List.filled(picked.length, QueueSource.autoplay));
        _prefetchNext();
      }
    } catch (_) {
    } finally {
      _isFetchingAutoplay = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Offline Mode & Audio Quality
  // ---------------------------------------------------------------------------
  Future<void> setOfflineMode(bool enabled) async {
    _offlineModeEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_mode_enabled', enabled);

    if (enabled &&
        _libraryProvider.downloadedSongs.isNotEmpty &&
        _currentSong == null) {
      await playSong(
        _libraryProvider.downloadedSongs.first,
        customQueue: _libraryProvider.downloadedSongs,
        contextName: 'Tersimpan Offline',
      );
    }
  }

  Future<void> setHighQualityAudio(bool highQuality) async {
    _highQualityAudio = highQuality;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('high_quality_audio', highQuality);
  }

  Future<void> setAutoQualityEnabled(bool enabled) async {
    _autoQualityEnabled = enabled;
    if (enabled) await _refreshNetworkType();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_quality_enabled', enabled);
  }

  Future<void> setCrossfadeSeconds(int seconds) async {
    _crossfadeSeconds = seconds.clamp(0, 12);
    if (_crossfadeSeconds == 0) {
      _fadeInTimer?.cancel();
      _audioPlayer.setVolume(1.0);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('crossfade_seconds', _crossfadeSeconds);
  }

  /// Prepares a local M4A audio file for the Story Video+Music Exporter (`ShareCardModal`).
  /// Uses offline vault copy if already downloaded; otherwise downloads lightweight stream to temp cache.
  Future<String?> prepareAudioFileForStory(ZunifySong song) async {
    final offline = _libraryProvider.getDownloadedSong(song.videoId);
    if (offline?.localFilePath != null &&
        File(offline!.localFilePath!).existsSync()) {
      return offline.localFilePath!;
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/zunify_story_audio_${song.videoId}.m4a');
    if (tempFile.existsSync() && tempFile.lengthSync() > 32 * 1024) {
      return tempFile.path;
    }

    final resolved = await _ytMusicService.resolveAudioStream(
      song.videoId,
      highQuality: false, // 96kbps M4A is ~2MB so it downloads in ~1 second
    );
    if (resolved == null) return null;

    final res = await http
        .get(resolved.url, headers: resolved.headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 200 || res.statusCode == 206) {
      await tempFile.writeAsBytes(res.bodyBytes, flush: true);
      return tempFile.path;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Sleep Timer
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Hardware Equalizer
  // ---------------------------------------------------------------------------
  Future<void> _applyCurrentEqLevels() async {
    for (int i = 0; i < _bandLevels.length; i++) {
      await _equalizerService.setBandLevel(i, _bandLevels[i]);
    }
    await _equalizerService.setBassBoost(_bassBoostStrength);
    await _equalizerService.setVirtualizer(_virtualizerStrength);
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    _eqEnabled = enabled;
    await _equalizerService.setEnabled(enabled);
    if (enabled) await _applyCurrentEqLevels();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled_v2', enabled);
  }

  Future<void> selectEqPreset(EqPreset preset) async {
    _selectedEqPresetName = preset.name;
    _bandLevels = List.from(preset.bandLevelsMilliBels);
    _bassBoostStrength = preset.bassBoostStrength;
    _virtualizerStrength = preset.virtualizerStrength;
    if (_eqEnabled) await _equalizerService.applyPreset(preset);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eq_preset_name_v2', preset.name);
  }

  Future<void> updateCustomBandLevel(int bandIndex, int levelMilliBels) async {
    _selectedEqPresetName = 'Custom';
    _bandLevels[bandIndex] = levelMilliBels;
    if (_eqEnabled) {
      await _equalizerService.setBandLevel(bandIndex, levelMilliBels);
    }
    notifyListeners();
  }

  Future<void> updateBassBoost(int strength) async {
    _bassBoostStrength = strength;
    if (_eqEnabled) await _equalizerService.setBassBoost(strength);
    notifyListeners();
  }

  Future<void> updateVirtualizer(int strength) async {
    _virtualizerStrength = strength;
    if (_eqEnabled) await _equalizerService.setVirtualizer(strength);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Weekly Rapot
  // ---------------------------------------------------------------------------
  void _flushListenLog() {
    if (_currentSong != null && _trackPlayStartedAt != null) {
      final elapsedSec =
          DateTime.now().difference(_trackPlayStartedAt!).inSeconds;
      if (elapsedSec >= 15) {
        _rapotService.recordSongListen(
          _currentSong!,
          elapsedSec.clamp(15, max(15, _currentSong!.durationSeconds)),
        );
      }
    }
    _trackPlayStartedAt = null;
  }

  Future<WeeklyRapot> getWeeklyRapot() =>
      _rapotService.generateCurrentWeeklyRapot();

  @override
  void dispose() {
    _flushListenLog();
    _sleepTimer?.cancel();
    _stopLyricsTicker();
    _audioPlayer.dispose();
    super.dispose();
  }
}

class _ScoredSong {
  final ZunifySong song;
  final double score;
  final String artistKey;

  _ScoredSong(this.song, this.score, this.artistKey);
}
