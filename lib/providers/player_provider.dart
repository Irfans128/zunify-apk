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
  List<ZunifySong> _originalAutoplayOrder = [];
  bool _isRadioSession = false;

  bool _autoplayEnabled = true;
  bool _isFetchingAutoplay = false;
  int _autoplayToken = 0;

  // Lightweight taste signals for the recommendation algorithm
  final List<String> _recentHistoryIds = [];
  final Map<String, int> _artistSkipPenalty = {};
  final Random _random = Random();

  bool _isLoadingTrack = false;
  bool _offlineModeEnabled = false;
  String _audioQualityTier = 'high'; // 'low' = Rendah, 'standard' = Standar, 'high' = Tinggi
  bool _highQualityAudio = true;
  bool _autoQualityEnabled = false;
  String _detectedNetworkType = 'wifi';
  DateTime? _lastNetCheckAt;

  // Feature #1: Crossfade & Gapless Transition (0 = Off, 3..8s = Smooth Crossfade)
  int _crossfadeSeconds = 4;
  bool _crossfadeTriggeredForCurrent = false;
  bool _isCrossfadingHandoff = false;
  Timer? _fadeInTimer;

  // Zunify 2.0 Studio Speed & Pitch + Audio Output Format Badge
  double _playbackSpeed = 1.0;
  double _playbackPitch = 1.0;
  String _activeAudioFormatBadge = 'HI-RES AAC • 160 kbps';

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
  /// so the scroll settles right as the first word starts.
  static const int _lyricsLeadMs = 140;

  // Sleep Timer State
  Timer? _sleepTimer;
  Timer? _sleepFadeTimer;
  DateTime? _sleepTimerEndTime;
  bool _stopAfterCurrentSong = false;
  bool _isSleepFadingOut = false;

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
  YTMusicService get ytMusicService => _ytMusicService;
  Duration get position => _audioPlayer.position;
  Duration get duration =>
      _audioPlayer.duration ??
      Duration(seconds: _currentSong?.durationSeconds ?? 240);
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
  String get audioQualityTier => _audioQualityTier;
  bool get highQualityAudio => _highQualityAudio;
  bool get autoQualityEnabled => _autoQualityEnabled;
  String get detectedNetworkType => _detectedNetworkType;
  int get crossfadeSeconds => _crossfadeSeconds;
  double get playbackSpeed => _playbackSpeed;
  double get playbackPitch => _playbackPitch;
  String get activeAudioFormatBadge => _activeAudioFormatBadge;

  bool get hasCustomSpeedOrPitch =>
      (_playbackSpeed - 1.0).abs() > 0.01 ||
      (_playbackPitch - 1.0).abs() > 0.01;

  String get speedPitchModeLabel {
    if ((_playbackSpeed - 0.86).abs() < 0.03 &&
        (_playbackPitch - 0.88).abs() < 0.04) {
      return 'Slowed';
    }
    if ((_playbackSpeed - 0.92).abs() < 0.03 &&
        (_playbackPitch - 0.92).abs() < 0.04) {
      return 'Daycore';
    }
    if ((_playbackSpeed - 1.20).abs() < 0.03 &&
        (_playbackPitch - 1.20).abs() < 0.04) {
      return 'Nightcore';
    }
    if ((_playbackSpeed - 1.12).abs() < 0.03) {
      return 'Sped Up';
    }
    if (!hasCustomSpeedOrPitch) return '1.0x';
    return '${_playbackSpeed.toStringAsFixed(2)}x';
  }

  String get activeQualityLabel {
    switch (_audioQualityTier) {
      case 'low':
        return 'Rendah';
      case 'standard':
        return 'Standar';
      default:
        return 'Tinggi';
    }
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

  String get formattedRemainingSleepTime {
    if (_stopAfterCurrentSong) return 'Akhir Lagu';
    final rem = remainingSleepTime;
    if (rem == null) return '';
    final totalSecs = (rem.inMilliseconds / 1000).ceil().clamp(0, 86400);
    final hrs = totalSecs ~/ 3600;
    final mins = (totalSecs % 3600) ~/ 60;
    final secs = totalSecs % 60;
    if (hrs > 0) {
      return '$hrs:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
    _audioQualityTier = prefs.getString('audio_quality_tier_v2') ?? 'high';
    _highQualityAudio = _audioQualityTier == 'high';
    _autoQualityEnabled = prefs.getBool('auto_quality_enabled') ?? false;
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

    // Coarse position updates (precise lyric sync runs on its own ticker) + Smooth Crossfade + Doze-safe Sleep Timer check
    _audioPlayer.positionStream.listen((pos) {
      _updateActiveLyricLine(pos);
      _handleCrossfadeTick(pos);
      _checkSleepTimerDeadline(fromStream: true);
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
          unawaited(_audioHandler?.pause() ?? _audioPlayer.pause());
        } else if (_isLoadingTrack || _isCrossfadingHandoff) {
          // Crossfade or manual skip load is already in flight — prevent double-skip
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
    _lyricsTicker = Timer.periodic(const Duration(milliseconds: 45), (_) {
      final lyr = _currentLyrics;
      if (lyr == null || lyr.lines.isEmpty || !lyr.isSynced) return;
      _updateActiveLyricLine(_audioPlayer.position);
    });
  }

  List<SyncedLyrics> get availableLyricsProviders {
    final vid = _currentSong?.videoId;
    if (vid == null) return const [];
    return _lyricsService.getProviderOptionsForVideo(vid);
  }

  void selectLyricsProvider(SyncedLyrics chosen) {
    _currentLyrics = _sanitizeLyrics(chosen);
    _showTranslation = false;
    _isTranslatingLyrics = false;
    _updateActiveLyricLine(_audioPlayer.position);
    _startLyricsTicker();
    notifyListeners();
  }

  void _stopLyricsTicker() {
    _lyricsTicker?.cancel();
    _lyricsTicker = null;
  }

  void _handleCrossfadeTick(Duration pos) {
    if (_crossfadeSeconds <= 0 ||
        !_audioPlayer.playing ||
        _isLoadingTrack ||
        _isCrossfadingHandoff ||
        _isSleepFadingOut ||
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

      if (remainingMs <= 750 && !_crossfadeTriggeredForCurrent) {
        _crossfadeTriggeredForCurrent = true;
        _isCrossfadingHandoff = true;
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

  /// Spotify Smart Shuffle: reshuffles both playlist context AND autoplay radio tracks
  /// with artist spacing (user-queued tracks always stay first).
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

  List<ZunifySong> _smartShuffleWithArtistSpacing(
    List<ZunifySong> items, {
    String? avoidFirstVideoId,
    String? previousArtistKey,
  }) {
    if (items.length <= 1) return List<ZunifySong>.from(items);
    final pool = List<ZunifySong>.from(items)..shuffle(_random);
    final out = <ZunifySong>[];
    String lastArt = previousArtistKey ?? '';

    while (pool.isNotEmpty) {
      int pickIdx = pool.indexWhere((s) {
        final ak = _artistKey(s.artist);
        if (out.isEmpty &&
            avoidFirstVideoId != null &&
            pool.length > 1 &&
            s.videoId == avoidFirstVideoId) {
          return false;
        }
        return ak != lastArt;
      });
      if (pickIdx < 0 && out.isEmpty && avoidFirstVideoId != null) {
        pickIdx = pool.indexWhere((s) => s.videoId != avoidFirstVideoId);
      }
      if (pickIdx < 0) pickIdx = 0;

      final chosen = pool.removeAt(pickIdx);
      out.add(chosen);
      lastArt = _artistKey(chosen.artist);
    }
    return out;
  }

  void _shuffleUpcomingContext() {
    final start = _currentIndex + 1;
    if (start >= _queue.length) return;
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

    final anchorArtist = userItems.isNotEmpty
        ? _artistKey(userItems.last.artist)
        : (_currentSong != null ? _artistKey(_currentSong!.artist) : '');

    final shuffledContext = _smartShuffleWithArtistSpacing(
      contextItems,
      avoidFirstVideoId:
          contextItems.length > 1 ? contextItems.first.videoId : null,
      previousArtistKey: anchorArtist,
    );

    final afterContextArtist = shuffledContext.isNotEmpty
        ? _artistKey(shuffledContext.last.artist)
        : anchorArtist;

    final shuffledAutoplay = _smartShuffleWithArtistSpacing(
      autoplayItems,
      avoidFirstVideoId:
          autoplayItems.length > 1 ? autoplayItems.first.videoId : null,
      previousArtistKey: afterContextArtist,
    );

    _rebuildUpcoming(userItems, shuffledContext, shuffledAutoplay);
  }

  void _restoreContextOrder() {
    if (_currentSong == null) return;
    final start = _currentIndex + 1;
    if (start >= _queue.length) return;
    final userItems = <ZunifySong>[];
    final autoplayItems = <ZunifySong>[];
    final upcomingContextIds = <String>{};
    final upcomingAutoplayIds = <String>{};
    for (int i = start; i < _queue.length; i++) {
      if (_sources[i] == QueueSource.user) {
        userItems.add(_queue[i]);
      } else if (_sources[i] == QueueSource.autoplay) {
        autoplayItems.add(_queue[i]);
        upcomingAutoplayIds.add(_queue[i].videoId);
      } else {
        upcomingContextIds.add(_queue[i].videoId);
      }
    }

    final orderedContext = <ZunifySong>[];
    if (_originalContextOrder.length > 1 && upcomingContextIds.isNotEmpty) {
      final originalPos = _originalContextOrder
          .indexWhere((s) => s.videoId == _currentSong!.videoId);
      if (originalPos >= 0) {
        orderedContext.addAll(
          _originalContextOrder
              .sublist(originalPos + 1)
              .where((s) => upcomingContextIds.contains(s.videoId)),
        );
      }
      for (final s in _originalContextOrder) {
        if (upcomingContextIds.contains(s.videoId) &&
            !orderedContext.any((e) => e.videoId == s.videoId)) {
          orderedContext.add(s);
        }
      }
    }

    List<ZunifySong> orderedAutoplay = autoplayItems;
    if (_originalAutoplayOrder.isNotEmpty && upcomingAutoplayIds.isNotEmpty) {
      final restored = _originalAutoplayOrder
          .where((s) => upcomingAutoplayIds.contains(s.videoId))
          .toList();
      for (final s in autoplayItems) {
        if (!restored.any((e) => e.videoId == s.videoId)) {
          restored.add(s);
        }
      }
      orderedAutoplay = restored;
    }

    _rebuildUpcoming(userItems, orderedContext, orderedAutoplay);
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

  /// Starts playing [song]. If [customQueue] has multiple tracks it becomes the new context
  /// (e.g. a playlist or mood mix) named [contextName]. If [customQueue] is empty or a single
  /// track (e.g. tapped from Search or Quick Picks), it starts a Spotify-style Genre Radio
  /// around [song] while preserving any user-queued tracks.
  Future<void> playSong(
    ZunifySong song, {
    List<ZunifySong>? customQueue,
    String? contextName,
  }) async {
    // Preserve any manually queued user tracks ("Tambahkan ke Antrean" / "Putar Berikutnya")
    final userTracks = <ZunifySong>[];
    for (int i = _currentIndex + 1; i < _queue.length && i < _sources.length; i++) {
      if (_sources[i] == QueueSource.user && _queue[i].videoId != song.videoId) {
        userTracks.add(_queue[i]);
      }
    }

    if (customQueue != null && customQueue.length > 1) {
      final ctx = <ZunifySong>[];
      final seen = <String>{};
      for (final s in customQueue) {
        if (seen.add(s.videoId)) ctx.add(s);
      }
      if (!seen.contains(song.videoId)) ctx.insert(0, song);

      _originalContextOrder = List.from(ctx);
      _originalAutoplayOrder = [];
      _isRadioSession = false;
      _contextName = contextName ?? 'Daftar putar';

      if (_shuffleEnabled) {
        final restRaw = ctx
            .where((s) =>
                s.videoId != song.videoId &&
                !userTracks.any((u) => u.videoId == s.videoId))
            .toList();
        final rest = _smartShuffleWithArtistSpacing(
          restRaw,
          previousArtistKey: _artistKey(song.artist),
        );
        _queue = [song, ...userTracks, ...rest];
        _sources = [
          QueueSource.context,
          ...List.filled(userTracks.length, QueueSource.user),
          ...List.filled(rest.length, QueueSource.context),
        ];
        _currentIndex = 0;
      } else {
        final songIdx = ctx.indexWhere((s) => s.videoId == song.videoId);
        final before = ctx.sublist(0, songIdx + 1);
        final after = ctx
            .sublist(songIdx + 1)
            .where((s) => !userTracks.any((u) => u.videoId == s.videoId))
            .toList();
        _queue = [...before, ...userTracks, ...after];
        _sources = [
          ...List.filled(before.length, QueueSource.context),
          ...List.filled(userTracks.length, QueueSource.user),
          ...List.filled(after.length, QueueSource.context),
        ];
        _currentIndex = before.length - 1;
      }
    } else {
      // Single-song playback (e.g. from Search or Quick Picks):
      // Start fresh Spotify-style Genre & Mood Radio around `song`
      _queue = [song, ...userTracks];
      _sources = [
        QueueSource.context,
        ...List.filled(userTracks.length, QueueSource.user),
      ];
      _currentIndex = 0;
      _originalContextOrder = [song];
      _originalAutoplayOrder = [];
      _isRadioSession = true;
      _contextName = contextName ?? 'Radio ${song.title}';
      _isFetchingAutoplay = false;
      _autoplayToken++;
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

    if (song.highResArtUrl.isNotEmpty) {
      unawaited(
        _themeProvider.updateDynamicColorFromImage(
          CachedNetworkImageProvider(song.highResArtUrl),
        ),
      );
    }

    unawaited(_loadLyricsForSong(song));
    _rememberInHistory(song);
    _maybeFillAutoplay();

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
        _activeAudioFormatBadge = 'Offline • Tinggi';
        await _audioPlayer.setFilePath(offlineCopy.localFilePath!);
      } else {
        if (_offlineModeEnabled) {
          _isLoadingTrack = false;
          notifyListeners();
          return;
        }
        final resolvedStream = await _ytMusicService.resolveAudioStream(
          song.videoId,
          highQuality: _audioQualityTier == 'high',
          qualityTier: _audioQualityTier,
        );
        if (token != _playToken) return; // user already skipped elsewhere
        if (resolvedStream == null) {
          _isLoadingTrack = false;
          notifyListeners();
          return;
        }

        final br = resolvedStream.bitrateKbps > 0
            ? resolvedStream.bitrateKbps
            : (_audioQualityTier == 'high'
                ? 160
                : (_audioQualityTier == 'standard' ? 128 : 64));
        _activeAudioFormatBadge = '$br kbps';

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
      final wasCrossfaded = _crossfadeTriggeredForCurrent || _isCrossfadingHandoff;
      _crossfadeTriggeredForCurrent = false;
      _isCrossfadingHandoff = false;
      if (wasCrossfaded && _crossfadeSeconds > 0 && !_isSleepFadingOut) {
        _startSmoothFadeIn();
      } else if (!_isSleepFadingOut) {
        _fadeInTimer?.cancel();
        _audioPlayer.setVolume(1.0);
      }
      if (hasCustomSpeedOrPitch) {
        unawaited(_audioPlayer.setSpeed(_playbackSpeed));
        unawaited(_audioPlayer.setPitch(_playbackPitch));
      }
      notifyListeners();
      unawaited(_audioPlayer.play());
      unawaited(_libraryProvider.addToRecentlyPlayed(song));

      _prefetchNext();
      _maybeFillAutoplay();
    } catch (_) {
      if (token == _playToken) {
        _isLoadingTrack = false;
        _crossfadeTriggeredForCurrent = false;
        _isCrossfadingHandoff = false;
        if (!_isSleepFadingOut) {
          _audioPlayer.setVolume(1.0);
        }
        notifyListeners();
      }
    }
  }

  void _prefetchNext() {
    if (_offlineModeEnabled) return;
    // Prefetch up to 2 upcoming tracks so consecutive skips & crossfades have 0ms stream wait
    for (int offset = 1; offset <= 2; offset++) {
      if (_currentIndex + offset < _queue.length) {
        final upcoming = _queue[_currentIndex + offset];
        if (!_libraryProvider.isDownloaded(upcoming.videoId)) {
          _ytMusicService.prefetchNextSongStream(
            upcoming.videoId,
            highQuality: _audioQualityTier == 'high',
            qualityTier: _audioQualityTier,
          );
        }
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
      _startLyricsTicker();
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

    _currentLyrics = _sanitizeLyrics(rawLyrics);
    _isLoadingLyrics = false;
    _updateActiveLyricLine(_audioPlayer.position);
    _startLyricsTicker();
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
    // Ensure offline cached lyrics with >= 3.5s intro also have the 3-dot intro row
    if (lyrics.isSynced &&
        cleaned.isNotEmpty &&
        cleaned.first.timestamp.inMilliseconds >= 3500 &&
        !cleaned.first.originalText.contains('•')) {
      cleaned.insert(
        0,
        LyricLine(
          timestamp: Duration.zero,
          endTimeMs: cleaned.first.timestamp.inMilliseconds,
          originalText: '♪ • • • ♪',
        ),
      );
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

    if (!fromCompletion) {
      _crossfadeTriggeredForCurrent = false;
      _isCrossfadingHandoff = false;
      _registerSkipSignal();
    }

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
    _crossfadeTriggeredForCurrent = false;
    _isCrossfadingHandoff = false;
    if (!_isSleepFadingOut) {
      _fadeInTimer?.cancel();
      _audioPlayer.setVolume(1.0);
    }
    await _audioPlayer.seek(position);
    _updateActiveLyricLine(position);
  }

  // ---------------------------------------------------------------------------
  // Spotify-Authentic Genre, Region & Listener Mood Queue Engine
  // ---------------------------------------------------------------------------
  static const Set<String> _indoCoreArtists = {
    'hindia',
    'bernadya',
    'mahalini',
    'tulus',
    'nadin amizah',
    'juicy luicy',
    'sal priadi',
    'pamungkas',
    'feast',
    '.feast',
    'lomba sihir',
    'perunggu',
    'reality club',
    'gangga',
    'ardhito pramono',
    'tiara andini',
    'lyodra',
    'ziva magnolya',
    'rizky febian',
    'keisya levronka',
    'fiersa besari',
    'fourtwnty',
    'payung teduh',
    'float',
    'soegi bornean',
    'daun jatuh',
    'idgitaf',
    'dere',
    'kunto aji',
    'yura yunita',
    'raisa',
    'isyana sarasvati',
    'afgan',
    'rossa',
    'glenn fredly',
    'chrisye',
    'sheila on 7',
    'dewa 19',
    'peterpan',
    'noah',
    'ungu',
    'kerispatih',
    'samsons',
    'ada band',
    'padi',
    'kahitna',
    'maliq',
    'hivi!',
    'hivi',
    'vierratale',
    'vierra',
    'last child',
    'virgoun',
    'armada',
    'd\'masiv',
    'dmasiv',
    'geisha',
    'kotak',
    'nidji',
    'letto',
    'andra and the backbone',
    'slank',
    'iwan fals',
    'for revenge',
    'stand here alone',
    'pee wee gaskins',
    'barasuara',
    'efek rumah kaca',
    'danilla',
    'diskoria',
    'dipha barus',
    'weird genius',
    'ghea indrawari',
    'fabio asher',
    'anggis devaki',
    'nyoman paul',
    'rony parulian',
    'salma salsabil',
    'budi doremi',
    'raim laode',
    'batas senja',
    'meiska',
    'dudy oris',
    'cakra khan',
    'judika',
    'andmesh',
    'bilal indrajaya',
    'teddy adhitya',
    'petra sihombing',
    'rendy pandugo',
    'oslo ibrahim',
    'coldiac',
    'the overtunes',
    'ran',
    'naff',
    'repvblik',
    'utopia',
    'cokelat',
    'gigi',
    'ari lasso',
    'once mekel',
    'bunga citra lestari',
    'maudy ayunda',
    'marion jola',
    'rizwan fadilah',
    'adrian khalif',
    'jkt48',
  };

  static const Set<String> _jpopCoreArtists = {
    'yoasobi',
    'ado',
    'kenshi yonezu',
    'fujii kaze',
    'imase',
    'radwimps',
    'aimyon',
    'official hige dandism',
    'mrs. green apple',
    'vaundy',
    'yorushika',
    'zutomayo',
    'eve',
    'king gnu',
    'creepy nuts',
    'tatsuya kitani',
    'yuuri',
    'back number',
    'one ok rock',
    'kana-boon',
    'bump of chicken',
    'ikimonogakari',
    'utada hikaru',
    'milet',
    'aimer',
    'babymetal',
    'kessoku band',
  };

  static const Set<String> _kpopCoreArtists = {
    'bts',
    'blackpink',
    'newjeans',
    'aespa',
    'ive',
    'le sserafim',
    'twice',
    'stray kids',
    'enhypen',
    'txt',
    'tomorrow x together',
    'exo',
    'nct',
    'red velvet',
    'itzy',
    '(g)i-dle',
    'babymonster',
    'illit',
    'kiss of life',
    'day6',
    'wave to earth',
    'iu',
    'taeyeon',
    'jungkook',
    'jimin',
    'jennie',
    'rosé',
    'jisoo',
    'treasure',
    'ateez',
    'bol4',
    'akmu',
    '10cm',
    'heize',
    'crush',
    'bigbang',
    '2ne1',
    'stayc',
    'nmixx',
  };

  static final RegExp _indoWordsRegex = RegExp(
    r'\b(aku|kamu|kau|kita|yang|dan|dari|untuk|dengan|dalam|tak|tidak|bukan|jangan|sudah|telah|masih|hanya|karena|jika|bila|kalau|saat|ketika|sampai|hingga|cinta|hati|rasa|rindu|luka|pergi|pulang|kembali|hilang|tinggal|kenangan|malam|pagi|senja|hujan|langit|bumi|dunia|hidup|mati|bahagia|sedih|kecewa|maaf|terima kasih|selamat|jalan|rumah|kota|sendiri|bersama|selamanya|tentang|sebuah|kisah|cerita|jiwa|ragu|percaya|harapan|mimpi|bayang|peluk|genggam|langkah|waktu|mengapa|kenapa|bagaimana|tanpa|bersamamu|untukmu|padamu|cintaku|hatiku|diriku|dirimu)\b',
  );

  static final RegExp _cjkRegex = RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]');
  static final RegExp _hangulRegex = RegExp(r'[\uac00-\ud7af]');

  static final RegExp _djRemixRegex = RegExp(
    r'(\bdj\b|jedag\s*jedug|\bjj\b|funkot|full\s*bass|mengpane|slowed|sped\s*up|nightcore|bootleg|thailand\s*style|viral\s*tiktok|remix)',
  );

  static final RegExp _koploRegex = RegExp(
    r'(denny caknan|happy asmara|guyon waton|ndarboy|aftershine|gilga sahid|masdddho|\bndx\b|koplo|campursari|dangdut|ambyar)',
  );

  _VibeProfile _inferVibeProfile(ZunifySong s) {
    final titleLower = s.title.toLowerCase();
    final artistLower = s.artist.toLowerCase();
    final aKey = _artistKey(s.artist);
    final combined = '$titleLower $artistLower ${s.album.toLowerCase()}';

    // 1. Detect specialized pockets first (DJ/Remix & Koplo/Dangdut)
    if (_djRemixRegex.hasMatch(combined)) {
      return const _VibeProfile(
        _MusicRegion.electronicDj,
        _MusicMood.electronicParty,
      );
    }
    if (_koploRegex.hasMatch(combined)) {
      return const _VibeProfile(
        _MusicRegion.koploDangdut,
        _MusicMood.upbeatPop,
      );
    }

    // 2. Detect Region / Language Pocket
    _MusicRegion region = _MusicRegion.western;
    if (_hangulRegex.hasMatch(combined) ||
        _kpopCoreArtists.contains(aKey) ||
        _kpopCoreArtists.any((k) => k.length >= 4 && artistLower.contains(k))) {
      region = _MusicRegion.kpop;
    } else if (_cjkRegex.hasMatch(combined) ||
        _jpopCoreArtists.contains(aKey) ||
        _jpopCoreArtists.any((j) => j.length >= 4 && artistLower.contains(j))) {
      region = _MusicRegion.jpop;
    } else if (_indoCoreArtists.contains(aKey) ||
        _indoCoreArtists.any((id) => id.length >= 5 && artistLower.contains(id)) ||
        _indoWordsRegex.hasMatch(titleLower)) {
      region = _MusicRegion.indo;
    }

    // 3. Detect Mood / Genre Pocket
    _MusicMood mood = _MusicMood.upbeatPop;
    final isGalauLex = RegExp(
      r'\b(galau|luka|pergi|hilang|usai|pisah|kecewa|air mata|menangis|sendiri|hampa|trauma|sial|runtuh|evaluasi|membasuh|untungnya|satu bulan|lama-lama|tak segampang|pesan terakhir|sisa rasa|bohongi hati|mati-matian|heartbreak|sad|lonely|tears|broken|cry|goodbye|miss you|without you|glimpse of us|someone like you|all too well|drivers license|traitor|happier|acoustic|akustik|piano|ballad)\b',
    ).hasMatch(combined);
    final isGalauArtist = const {
      'bernadya',
      'nadin amizah',
      'mahalini',
      'fiersa besari',
      'daun jatuh',
      'soegi bornean',
      'virgoun',
      'last child',
      'kerispatih',
      'rossa',
      'glenn fredly',
      'adele',
      'olivia rodrigo',
      'lewis capaldi',
      'sam smith',
      'conan gray',
      'gracie abrams',
      'phoebe bridgers',
      'cigarettes after sex',
      'joji',
      'fabio asher',
      'anggis devaki',
      'meiska',
      'raisa',
    }.contains(aKey);

    final isIndieChillArtist = const {
      'hindia',
      'pamungkas',
      'sal priadi',
      'kunto aji',
      'payung teduh',
      'fourtwnty',
      'perunggu',
      'lomba sihir',
      'reality club',
      'ardhito pramono',
      'bilal indrajaya',
      'danilla',
      'float',
      'gangga',
      'juicy luicy',
      'wave to earth',
      'daniel caesar',
      'keshi',
      'rex orange county',
      'clairo',
      'beabadoobee',
      'men i trust',
      'mac demarco',
      'arctic monkeys',
      'the 1975',
      'lany',
      'niki',
      'frank ocean',
      'laufey',
    }.contains(aKey);

    final isRockBandArtist = const {
      'sheila on 7',
      'dewa 19',
      'noah',
      'peterpan',
      'padi',
      'gigi',
      'cokelat',
      'kotak',
      'nidji',
      'd\'masiv',
      'dmasiv',
      'armada',
      'ungu',
      'samsons',
      '.feast',
      'feast',
      'barasuara',
      'pee wee gaskins',
      'for revenge',
      'linkin park',
      'green day',
      'my chemical romance',
      'paramore',
      'bring me the horizon',
      'nirvana',
      'queen',
      'oasis',
      'coldplay',
      'imagine dragons',
      'maroon 5',
      'one ok rock',
      'radwimps',
      'day6',
    }.contains(aKey);

    final isRnbGrooveArtist = const {
      'tulus',
      'maliq',
      'ran',
      'hivi!',
      'hivi',
      'diskoria',
      'adrian khalif',
      'rizky febian',
      'marion jola',
      'the weeknd',
      'bruno mars',
      'silk sonic',
      'chris brown',
      'drake',
      'kendrick lamar',
      'travis scott',
      'post malone',
      'sza',
      'ariana grande',
      'justin bieber',
      'khalid',
      'giveon',
      'brent faiyaz',
    }.contains(aKey);

    if (isGalauLex || isGalauArtist) {
      mood = _MusicMood.galauBallad;
    } else if (isIndieChillArtist ||
        RegExp(r'\b(chill|lofi|senja|indie|coffee|malam)\b')
            .hasMatch(combined)) {
      mood = _MusicMood.indieChill;
    } else if (isRockBandArtist ||
        RegExp(r'\b(rock|metal|punk|band|anthem)\b').hasMatch(combined)) {
      mood = _MusicMood.rockBand;
    } else if (isRnbGrooveArtist ||
        RegExp(r'\b(r&b|rnb|soul|groove|hip hop|rap)\b').hasMatch(combined)) {
      mood = _MusicMood.rnbGroove;
    }

    return _VibeProfile(region, mood);
  }

  bool _areMoodsCompatible(_MusicMood a, _MusicMood b) {
    if (a == b) return true;
    if ((a == _MusicMood.galauBallad && b == _MusicMood.indieChill) ||
        (b == _MusicMood.galauBallad && a == _MusicMood.indieChill)) {
      return true;
    }
    if ((a == _MusicMood.indieChill && b == _MusicMood.rnbGroove) ||
        (b == _MusicMood.indieChill && a == _MusicMood.rnbGroove)) {
      return true;
    }
    if ((a == _MusicMood.upbeatPop && b == _MusicMood.rnbGroove) ||
        (b == _MusicMood.upbeatPop && a == _MusicMood.rnbGroove)) {
      return true;
    }
    if ((a == _MusicMood.indieChill && b == _MusicMood.rockBand) ||
        (b == _MusicMood.indieChill && a == _MusicMood.rockBand)) {
      return true;
    }
    return false;
  }

  void _maybeFillAutoplay() {
    if (_offlineModeEnabled || _repeatMode == 1) return;
    if (!_autoplayEnabled && !(_isRadioSession && upcomingCount == 0)) return;
    if (upcomingCount < 6) {
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

  String _titleKey(String title) {
    String s = title.toLowerCase();
    // Strip parentheticals & brackets
    s = s.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ');
    // If title contains "Artist - Song Title", keep the part after '-' when reasonable
    if (s.contains(' - ')) {
      final parts = s.split(' - ');
      if (parts.length >= 2 && parts[1].trim().length >= 3) {
        s = parts[1];
      }
    }
    s = s
        .replaceAll(
          RegExp(
            r'\b(feat|ft|official|music|video|audio|lyric|lyrics|lirik|live|acoustic|akustik|cover|remix|version|versi|karaoke|instrumental|slowed|reverb|sped|up|hd|hq|mv|visualizer)\b.*',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  bool _isDuplicateOrCoverTitle(String candidateKey, Set<String> existingKeys) {
    if (candidateKey.isEmpty) return true;
    for (final ex in existingKeys) {
      if (ex.isEmpty) continue;
      if (candidateKey == ex) return true;
      if (candidateKey.length >= 5 &&
          ex.length >= 5 &&
          (candidateKey.contains(ex) || ex.contains(candidateKey))) {
        return true;
      }
    }
    return false;
  }

  bool _looksLikeNonSong(ZunifySong s) {
    final t = s.title.toLowerCase();
    if (s.durationSeconds > 0 &&
        (s.durationSeconds < 60 || s.durationSeconds > 10 * 60)) {
      return true;
    }
    return t.contains('full album') ||
        t.contains('1 hour') ||
        t.contains('1 jam') ||
        t.contains('playlist') ||
        t.contains('compilation') ||
        t.contains('kompilasi') ||
        t.contains('nonstop') ||
        t.contains('mashup') ||
        t.contains('karaoke') ||
        t.contains('instrumental');
  }

  ZunifySong? _pickMatchingListenerTasteSeed(
    ZunifySong seed,
    _VibeProfile seedVibe,
    Set<String> excludeIds,
  ) {
    final seedArtist = _artistKey(seed.artist);
    final pool = <ZunifySong>[
      ..._libraryProvider.favorites,
      ..._libraryProvider.recentlyPlayed.take(18),
    ];
    final matching = <ZunifySong>[];
    for (final item in pool) {
      if (item.videoId == seed.videoId || excludeIds.contains(item.videoId)) {
        continue;
      }
      final ak = _artistKey(item.artist);
      if (ak == seedArtist) continue;
      if ((_artistSkipPenalty[ak] ?? 0) > 0) continue;
      final v = _inferVibeProfile(item);
      if (v.region == seedVibe.region &&
          _areMoodsCompatible(v.mood, seedVibe.mood)) {
        matching.add(item);
      }
    }
    if (matching.isEmpty) return null;
    final topSlice = matching.take(6).toList();
    return topSlice[_random.nextInt(topSlice.length)];
  }

  Future<void> _appendAutoplayRecommendations() async {
    final seed = _currentSong;
    if (seed == null || _isFetchingAutoplay) return;
    _isFetchingAutoplay = true;
    final myAutoToken = ++_autoplayToken;
    notifyListeners();

    try {
      final excludeIds = <String>{
        ..._queue.map((s) => s.videoId),
        ..._recentHistoryIds.take(40),
      };

      final seedVibe = _inferVibeProfile(seed);
      final tasteSeed =
          _pickMatchingListenerTasteSeed(seed, seedVibe, excludeIds);

      // Fetch pure RDAMVM Song Radio + Personalized Listener Taste Radio in parallel
      final radioBatches = await Future.wait<List<ZunifySong>>([
        _ytMusicService.getRadioRecommendations(
          seed,
          excludeVideoIds: excludeIds,
          tunerMode: 'AUTOMIX_SETTING_NORMAL',
        ),
        if (tasteSeed != null)
          _ytMusicService.getRadioRecommendations(
            tasteSeed,
            excludeVideoIds: excludeIds,
            tunerMode: 'AUTOMIX_SETTING_FAMILIAR',
          ),
      ]);

      if (myAutoToken != _autoplayToken) return;
      if (_currentSong?.videoId != seed.videoId && upcomingCount >= 6) {
        return;
      }

      final primaryRaw = radioBatches[0];
      final tasteRaw =
          radioBatches.length > 1 ? radioBatches[1] : const <ZunifySong>[];

      // Session mood & region profile from the listener's recent 5 tracks
      final recentSession = _libraryProvider.recentlyPlayed.take(5).toList();
      final sessionRegions = <_MusicRegion>{};
      final moodCounts = <_MusicMood, int>{};
      for (final rs in recentSession) {
        final rv = _inferVibeProfile(rs);
        sessionRegions.add(rv.region);
        moodCounts[rv.mood] = (moodCounts[rv.mood] ?? 0) + 1;
      }
      _MusicMood? dominantSessionMood;
      int bestMoodCount = 0;
      moodCounts.forEach((m, cnt) {
        if (cnt > bestMoodCount) {
          bestMoodCount = cnt;
          dominantSessionMood = m;
        }
      });

      final favVideoIds =
          _libraryProvider.favorites.map((s) => s.videoId).toSet();
      final favArtists = _libraryProvider.favorites
          .map((s) => _artistKey(s.artist))
          .toSet();
      final recentArtists = _libraryProvider.recentlyPlayed
          .take(25)
          .map((s) => _artistKey(s.artist))
          .toSet();

      final knownTitleKeys = <String>{
        _titleKey(seed.title),
        ..._queue.map((s) => _titleKey(s.title)),
      };
      final seenCandidateIds = <String>{...excludeIds};
      final candidates = <_ScoredSong>[];

      void scoreBatch(List<ZunifySong> batch, {required bool isPrimary}) {
        for (int i = 0; i < batch.length; i++) {
          final s = batch[i];
          if (!seenCandidateIds.add(s.videoId)) continue;
          if (_looksLikeNonSong(s)) continue;

          final candVibe = _inferVibeProfile(s);

          // Strictly block DJ/Jedag-Jedug/Slowed/Remix & Koplo from regular music queues
          if (candVibe.region == _MusicRegion.electronicDj &&
              seedVibe.region != _MusicRegion.electronicDj) {
            continue;
          }
          if (candVibe.region == _MusicRegion.koploDangdut &&
              seedVibe.region != _MusicRegion.koploDangdut) {
            continue;
          }

          final tKey = _titleKey(s.title);
          if (_isDuplicateOrCoverTitle(tKey, knownTitleKeys)) {
            continue;
          }
          knownTitleKeys.add(tKey);

          final aKey = _artistKey(s.artist);

          // 1. Base RDAMVM acoustic/genre graph similarity rank
          double score = isPrimary
              ? (batch.length - i) * 1.15
              : (batch.length - i) * 0.85;

          // 2. Spotify Region & Genre Continuity
          if (candVibe.region == seedVibe.region) {
            score += 10.0;
          } else if (sessionRegions.contains(candVibe.region)) {
            score -= 2.5;
          } else {
            score -= 9.0;
          }

          // 3. Listener Mood Continuity
          if (candVibe.mood == seedVibe.mood) {
            score += 6.5;
          } else if (_areMoodsCompatible(candVibe.mood, seedVibe.mood)) {
            score += 3.0;
          } else {
            score -= 3.5;
          }

          if (dominantSessionMood != null &&
              candVibe.mood == dominantSessionMood &&
              _areMoodsCompatible(candVibe.mood, seedVibe.mood)) {
            score += 2.5;
          }

          // 4. Personal Library Affinity & Skip Feedback
          if (favVideoIds.contains(s.videoId) &&
              !_recentHistoryIds.take(15).contains(s.videoId)) {
            score += 4.5;
          }
          if (favArtists.contains(aKey)) score += 5.0;
          if (recentArtists.contains(aKey)) score += 2.5;
          score -= (_artistSkipPenalty[aKey] ?? 0) * 6.5;

          // Natural organic radio freshness
          score += _random.nextDouble() * 1.8;

          candidates.add(_ScoredSong(s, score, aKey));
        }
      }

      scoreBatch(primaryRaw, isPrimary: true);
      scoreBatch(tasteRaw, isPrimary: false);

      candidates.sort((a, b) => b.score.compareTo(a.score));

      // Spotify 3-Slot Artist Spacing & Diversity Pass:
      // - Never repeat an artist within the last 2 slots when alternatives exist
      // - Cap any single artist to max 2 tracks per batch (max 1 extra for seed artist early on)
      final picked = <ZunifySong>[];
      final artistCounts = <String, int>{};
      final seedArtistKey = _artistKey(seed.artist);
      artistCounts[seedArtistKey] = 1;

      final recentWindow = <String>[];
      if (_queue.isNotEmpty) {
        recentWindow.add(_artistKey(_queue.last.artist));
        if (_queue.length >= 2) {
          recentWindow.insert(0, _artistKey(_queue[_queue.length - 2].artist));
        }
      } else {
        recentWindow.add(seedArtistKey);
      }

      while (candidates.isNotEmpty && picked.length < 16) {
        // Strict pass: not in recent 2-slot window & < 2 tracks in batch
        int idx = candidates.indexWhere(
          (c) =>
              !recentWindow.contains(c.artistKey) &&
              (artistCounts[c.artistKey] ?? 0) < 2 &&
              !(picked.length < 4 && c.artistKey == seedArtistKey),
        );
        // Relaxed pass 1: not immediate previous artist & < 2 tracks
        if (idx < 0) {
          final immediateLast =
              recentWindow.isNotEmpty ? recentWindow.last : '';
          idx = candidates.indexWhere(
            (c) =>
                c.artistKey != immediateLast &&
                (artistCounts[c.artistKey] ?? 0) < 2,
          );
        }
        // Relaxed pass 2: not immediate previous artist
        if (idx < 0) {
          final immediateLast =
              recentWindow.isNotEmpty ? recentWindow.last : '';
          idx = candidates.indexWhere((c) => c.artistKey != immediateLast);
        }
        if (idx < 0) idx = 0;

        final chosen = candidates.removeAt(idx);
        picked.add(chosen.song);
        artistCounts[chosen.artistKey] =
            (artistCounts[chosen.artistKey] ?? 0) + 1;
        recentWindow.add(chosen.artistKey);
        if (recentWindow.length > 2) {
          recentWindow.removeAt(0);
        }
      }

      if (picked.isNotEmpty && myAutoToken == _autoplayToken) {
        _originalAutoplayOrder.addAll(picked);
        final toAppend = _shuffleEnabled
            ? _smartShuffleWithArtistSpacing(
                picked,
                previousArtistKey: _queue.isNotEmpty
                    ? _artistKey(_queue.last.artist)
                    : seedArtistKey,
              )
            : picked;
        _queue.addAll(toAppend);
        _sources.addAll(List.filled(toAppend.length, QueueSource.autoplay));
        _prefetchNext();
      }
    } catch (_) {
    } finally {
      if (myAutoToken == _autoplayToken) {
        _isFetchingAutoplay = false;
      }
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

  Future<void> setAudioQualityTier(String tier) async {
    final normalized =
        (tier == 'low' || tier == 'standard' || tier == 'high') ? tier : 'high';
    if (_audioQualityTier == normalized) return;
    _audioQualityTier = normalized;
    _highQualityAudio = normalized == 'high';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_quality_tier_v2', normalized);
    await prefs.setBool('high_quality_audio', _highQualityAudio);

    // Immediately switch stream bitrate if currently streaming a song online
    final song = _currentSong;
    if (song != null &&
        !_offlineModeEnabled &&
        !_libraryProvider.isDownloaded(song.videoId)) {
      final savedPos = _audioPlayer.position;
      final wasPlaying = _audioPlayer.playing;
      try {
        final resolvedStream = await _ytMusicService.resolveAudioStream(
          song.videoId,
          highQuality: normalized == 'high',
          qualityTier: normalized,
        );
        if (resolvedStream != null && _currentSong?.videoId == song.videoId) {
          final br = resolvedStream.bitrateKbps > 0
              ? resolvedStream.bitrateKbps
              : (normalized == 'high'
                  ? 160
                  : (normalized == 'standard' ? 128 : 64));
          _activeAudioFormatBadge = '$br kbps';
          await _audioPlayer.setAudioSource(
            AudioSource.uri(
              resolvedStream.url,
              headers: resolvedStream.headers,
            ),
            initialPosition: savedPos,
          );
          if (hasCustomSpeedOrPitch) {
            unawaited(_audioPlayer.setSpeed(_playbackSpeed));
            unawaited(_audioPlayer.setPitch(_playbackPitch));
          }
          if (wasPlaying) {
            unawaited(_audioPlayer.play());
          }
          notifyListeners();
        }
      } catch (_) {}
    }
    _prefetchNext();
  }

  Future<void> setHighQualityAudio(bool highQuality) async {
    await setAudioQualityTier(highQuality ? 'high' : 'low');
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
  // Sleep Timer (Real-Time 1s Countdown + Doze-Safe Stream Check + Smooth Fade-Out)
  // ---------------------------------------------------------------------------
  void setSleepTimerDuration(Duration duration) {
    _sleepTimer?.cancel();
    _sleepFadeTimer?.cancel();
    if (_isSleepFadingOut) {
      _isSleepFadingOut = false;
      _audioPlayer.setVolume(1.0);
    }
    _stopAfterCurrentSong = false;
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkSleepTimerDeadline(fromStream: false);
    });
    notifyListeners();
  }

  void addSleepTimerMinutes(int minutes) {
    if (_sleepTimerEndTime != null) {
      _sleepTimerEndTime = _sleepTimerEndTime!.add(Duration(minutes: minutes));
      notifyListeners();
    } else {
      setSleepTimerDuration(Duration(minutes: minutes));
    }
  }

  void _checkSleepTimerDeadline({required bool fromStream}) {
    final target = _sleepTimerEndTime;
    if (target == null || _isSleepFadingOut) return;
    final remaining = target.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _triggerSleepTimerStop();
    } else if (!fromStream) {
      notifyListeners();
    }
  }

  void _triggerSleepTimerStop() {
    if (_isSleepFadingOut) return;
    _isSleepFadingOut = true;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    _stopAfterCurrentSong = false;
    _fadeInTimer?.cancel();
    notifyListeners();

    if (!_audioPlayer.playing) {
      _isSleepFadingOut = false;
      _audioPlayer.setVolume(1.0);
      return;
    }

    int step = 0;
    const totalSteps = 8;
    _sleepFadeTimer?.cancel();
    _sleepFadeTimer = Timer.periodic(const Duration(milliseconds: 140), (t) async {
      step++;
      final vol = (1.0 - (step / totalSteps)).clamp(0.0, 1.0);
      _audioPlayer.setVolume(vol);
      if (step >= totalSteps) {
        t.cancel();
        _sleepFadeTimer = null;
        try {
          await (_audioHandler?.pause() ?? _audioPlayer.pause());
        } catch (_) {
          try {
            await _audioPlayer.pause();
          } catch (_) {}
        }
        _audioPlayer.setVolume(1.0);
        _isSleepFadingOut = false;
        notifyListeners();
      }
    });
  }

  void setSleepTimerEndOfTrack() {
    cancelSleepTimer();
    _stopAfterCurrentSong = true;
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepFadeTimer?.cancel();
    _sleepFadeTimer = null;
    if (_isSleepFadingOut) {
      _isSleepFadingOut = false;
      _audioPlayer.setVolume(1.0);
    }
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

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.65, 1.50);
    try {
      await _audioPlayer.setSpeed(_playbackSpeed);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setPlaybackPitch(double pitch) async {
    _playbackPitch = pitch.clamp(0.65, 1.50);
    try {
      await _audioPlayer.setPitch(_playbackPitch);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setSpeedPitchPreset(double speed, double pitch) async {
    _playbackSpeed = speed.clamp(0.65, 1.50);
    _playbackPitch = pitch.clamp(0.65, 1.50);
    try {
      await _audioPlayer.setSpeed(_playbackSpeed);
      await _audioPlayer.setPitch(_playbackPitch);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> resetSpeedPitch() async {
    await setSpeedPitchPreset(1.0, 1.0);
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
    _sleepFadeTimer?.cancel();
    _fadeInTimer?.cancel();
    _stopLyricsTicker();
    _audioPlayer.dispose();
    super.dispose();
  }
}

enum _MusicRegion {
  indo,
  western,
  jpop,
  kpop,
  koploDangdut,
  electronicDj,
}

enum _MusicMood {
  galauBallad,
  indieChill,
  upbeatPop,
  rnbGroove,
  rockBand,
  electronicParty,
}

class _VibeProfile {
  final _MusicRegion region;
  final _MusicMood mood;

  const _VibeProfile(this.region, this.mood);
}

class _ScoredSong {
  final ZunifySong song;
  final double score;
  final String artistKey;

  _ScoredSong(this.song, this.score, this.artistKey);
}
