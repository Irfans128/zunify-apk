import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lite_song.dart';
import '../services/lite_audio_handler.dart';
import '../services/lite_ytm_service.dart';

/// Ultra-lean state controller for ZunifyG.
/// Handles ONLY the 6 core features:
/// 1. Song Playback + Background Service + Resume
/// 2. Song Search (+ History)
/// 3. Local Playlists
/// 4. Repeat Mode (Off / All / One)
/// 5. Audio Quality (Low / Standard / High)
/// 6. Smart Radio Algorithm (Auto-Queue)
class ZunifyGController extends ChangeNotifier {
  static const _kPrefQuality = 'zg_quality_tier';
  static const _kPrefRepeat = 'zg_repeat_mode';
  static const _kPrefAutoRadio = 'zg_auto_radio';
  static const _kPrefGamingMix = 'zg_gaming_mix';
  static const _kPrefPlaylists = 'zg_playlists_v1';
  static const _kPrefHistory = 'zg_search_history_v1';
  static const _kPrefLastSong = 'zg_last_song_v1';
  static const _kPrefLastPosMs = 'zg_last_pos_ms';

  final LiteAudioHandler? _handler;
  late final AudioPlayer _player;
  final LiteYtmService ytm;

  List<LiteSong> _queue = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  bool _isFetchingRadio = false;
  int _playToken = 0;

  // Settings (defaults optimized for low-end gaming phones)
  String _qualityTier = 'low'; // 'low' (~64k), 'standard' (~128k), 'high' (~160k)
  int _repeatMode = 0; // 0 = Off, 1 = Repeat All, 2 = Repeat One
  bool _autoRadioEnabled = true; // Smart Algorithm ON by default
  bool _gamingMixMode = true; // Keep playing with game sound
  int _activeBitrateKbps = 64;

  // Playlists & Search History
  List<LitePlaylist> _playlists = [];
  List<String> _searchHistory = [];

  // Resume state
  Duration _savedResumePos = Duration.zero;
  bool _needsInitialLoadForResume = false;
  Timer? _posSaveTimer;

  ZunifyGController({
    LiteAudioHandler? handler,
    required this.ytm,
  }) : _handler = handler {
    _player = _handler?.player ??
        AudioPlayer(
          handleInterruptions: false,
          handleAudioSessionActivation: false,
        );
    _handler?.onNextCallback = playNext;
    _handler?.onPreviousCallback = playPrevious;
    _bindListeners();
  }

  // Getters
  AudioPlayer get player => _player;
  List<LiteSong> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  LiteSong? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _queue.length)
          ? _queue[_currentIndex]
          : null;
  bool get isPlaying => _player.playing;
  bool get isLoading => _isLoading;
  bool get isFetchingRadio => _isFetchingRadio;
  String get qualityTier => _qualityTier;
  int get repeatMode => _repeatMode;
  bool get autoRadioEnabled => _autoRadioEnabled;
  bool get gamingMixMode => _gamingMixMode;
  int get activeBitrateKbps => _activeBitrateKbps;
  List<LitePlaylist> get playlists => List.unmodifiable(_playlists);
  List<String> get searchHistory => List.unmodifiable(_searchHistory);

  Duration get position =>
      _needsInitialLoadForResume ? _savedResumePos : _player.position;
  Duration get duration =>
      _player.duration ??
      Duration(seconds: currentSong?.durationSeconds ?? 180);

  String get qualityShortLabel {
    switch (_qualityTier) {
      case 'low':
        return 'Hemat';
      case 'standard':
        return 'Normal';
      default:
        return 'Tinggi';
    }
  }

  String get qualityDescription {
    switch (_qualityTier) {
      case 'low':
        return '~64 kbps • Ping Aman';
      case 'standard':
        return '~128 kbps • Seimbang';
      default:
        return '~160 kbps • Jernih';
    }
  }

  String get repeatLabel {
    switch (_repeatMode) {
      case 1:
        return 'Ulang Semua';
      case 2:
        return 'Ulang 1 Lagu';
      default:
        return 'Ulang Mati';
    }
  }

  void _bindListeners() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onTrackCompleted();
      }
      notifyListeners();
    });

    // Periodically persist playback position every 8s while playing (super lightweight)
    _posSaveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_player.playing && currentSong != null) {
        unawaited(_persistLastPlayback());
      }
    });
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _qualityTier = prefs.getString(_kPrefQuality) ?? 'low';
    _repeatMode = prefs.getInt(_kPrefRepeat) ?? 0;
    _autoRadioEnabled = prefs.getBool(_kPrefAutoRadio) ?? true;
    _gamingMixMode = prefs.getBool(_kPrefGamingMix) ?? true;
    _handler?.gamingMixMode = _gamingMixMode;

    // Load Playlists
    final rawPl = prefs.getString(_kPrefPlaylists);
    if (rawPl != null && rawPl.isNotEmpty) {
      try {
        final list = jsonDecode(rawPl) as List<dynamic>;
        _playlists = list
            .whereType<Map>()
            .map((e) => LitePlaylist.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    }

    // Load Search History
    _searchHistory = prefs.getStringList(_kPrefHistory) ?? [];

    // Restore last played track (Spotify-style resume)
    final rawLast = prefs.getString(_kPrefLastSong);
    final posMs = prefs.getInt(_kPrefLastPosMs) ?? 0;
    if (rawLast != null && rawLast.isNotEmpty) {
      try {
        final lastSong = LiteSong.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawLast) as Map),
        );
        if (lastSong.videoId.isNotEmpty) {
          _queue = [lastSong];
          _currentIndex = 0;
          _savedResumePos = Duration(milliseconds: posMs);
          _needsInitialLoadForResume = true;
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _persistLastPlayback() async {
    final s = currentSong;
    if (s == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefLastSong, jsonEncode(s.toJson()));
      await prefs.setInt(_kPrefLastPosMs, _player.position.inMilliseconds);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // 1. Playback Controls
  // ---------------------------------------------------------------------------
  Future<void> playSong(
    LiteSong song, {
    List<LiteSong>? queueList,
    bool triggerAlgorithm = true,
  }) async {
    _needsInitialLoadForResume = false;
    _savedResumePos = Duration.zero;

    if (queueList != null && queueList.isNotEmpty) {
      _queue = List<LiteSong>.from(queueList);
      final idx = _queue.indexWhere((e) => e.videoId == song.videoId);
      if (idx >= 0) {
        _currentIndex = idx;
      } else {
        _queue.insert(0, song);
        _currentIndex = 0;
      }
    } else {
      _queue = [song];
      _currentIndex = 0;
    }

    await _loadAndPlayAt(_currentIndex);

    if (triggerAlgorithm && _autoRadioEnabled && _queue.length - _currentIndex <= 3) {
      unawaited(_appendAlgorithmRecommendations(song));
    }
  }

  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _needsInitialLoadForResume = false;
    _savedResumePos = Duration.zero;
    _currentIndex = index;
    await _loadAndPlayAt(index);

    final cur = currentSong;
    if (cur != null && _autoRadioEnabled && _queue.length - _currentIndex <= 3) {
      unawaited(_appendAlgorithmRecommendations(cur));
    }
  }

  Future<void> _loadAndPlayAt(int index, {Duration? startPosition}) async {
    if (index < 0 || index >= _queue.length) return;
    final song = _queue[index];
    final token = ++_playToken;

    _isLoading = true;
    notifyListeners();

    _handler?.updateTrack(
      MediaItem(
        id: song.videoId,
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        artUri: song.thumbnailUrl.isNotEmpty ? Uri.tryParse(song.thumbnailUrl) : null,
      ),
    );

    try {
      final stream = await ytm.resolveStream(
        song.videoId,
        qualityTier: _qualityTier,
      );
      if (token != _playToken) return;
      if (stream == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _activeBitrateKbps = stream.bitrateKbps;

      try {
        await _player.setAudioSource(
          AudioSource.uri(stream.url, headers: stream.headers),
          initialPosition: startPosition,
        );
      } catch (_) {
        if (stream.hlsUrl != null) {
          await _player.setAudioSource(
            AudioSource.uri(stream.hlsUrl!, headers: stream.headers),
            initialPosition: startPosition,
          );
        } else {
          rethrow;
        }
      }

      if (token != _playToken) return;
      _isLoading = false;
      notifyListeners();
      unawaited(_player.play());
      unawaited(_persistLastPlayback());

      // Prefetch next track URL silently for instant gapless switch
      if (_currentIndex + 1 < _queue.length) {
        final nextSong = _queue[_currentIndex + 1];
        unawaited(ytm.prefetch(nextSong.videoId, qualityTier: _qualityTier));
      }
    } catch (_) {
      if (token == _playToken) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (currentSong == null) return;
    if (_needsInitialLoadForResume) {
      _needsInitialLoadForResume = false;
      final resumeAt = _savedResumePos;
      await _loadAndPlayAt(_currentIndex, startPosition: resumeAt);
      if (_autoRadioEnabled && _queue.length <= 2) {
        unawaited(_appendAlgorithmRecommendations(currentSong!));
      }
      return;
    }
    if (_player.playing) {
      await _player.pause();
      unawaited(_persistLastPlayback());
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> seek(Duration pos) async {
    if (_needsInitialLoadForResume) {
      _savedResumePos = pos;
      notifyListeners();
      return;
    }
    await _player.seek(pos);
  }

  Future<void> playNext() async {
    if (_queue.isEmpty) return;

    if (_repeatMode == 2) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
      await _loadAndPlayAt(_currentIndex);
      final cur = currentSong;
      if (cur != null && _autoRadioEnabled && _queue.length - _currentIndex <= 3) {
        unawaited(_appendAlgorithmRecommendations(cur));
      }
    } else if (_repeatMode == 1) {
      _currentIndex = 0;
      await _loadAndPlayAt(0);
    } else if (_autoRadioEnabled && currentSong != null) {
      await _appendAlgorithmRecommendations(currentSong!);
      if (_currentIndex + 1 < _queue.length) {
        _currentIndex++;
        await _loadAndPlayAt(_currentIndex);
      }
    }
  }

  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      await _loadAndPlayAt(_currentIndex);
    } else if (_repeatMode == 1) {
      _currentIndex = _queue.length - 1;
      await _loadAndPlayAt(_currentIndex);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  void _onTrackCompleted() {
    if (_repeatMode == 2) {
      unawaited(_player.seek(Duration.zero).then((_) => _player.play()));
      return;
    }
    unawaited(playNext());
  }

  // ---------------------------------------------------------------------------
  // 2. Smart Radio Algorithm
  // ---------------------------------------------------------------------------
  Future<void> _appendAlgorithmRecommendations(LiteSong seed) async {
    if (_isFetchingRadio) return;
    _isFetchingRadio = true;
    notifyListeners();
    try {
      final existing = _queue.map((e) => e.videoId).toSet();
      final recs = await ytm.getRadioNext(seed, excludeIds: existing);
      if (recs.isNotEmpty) {
        // Keep queue memory-light (cap to 45 items max)
        _queue.addAll(recs);
        if (_queue.length > 45 && _currentIndex > 12) {
          final drop = _currentIndex - 8;
          _queue.removeRange(0, drop);
          _currentIndex -= drop;
        }
        // Prefetch immediate next song
        if (_currentIndex + 1 < _queue.length) {
          unawaited(
            ytm.prefetch(_queue[_currentIndex + 1].videoId, qualityTier: _qualityTier),
          );
        }
      }
    } finally {
      _isFetchingRadio = false;
      notifyListeners();
    }
  }

  Future<void> toggleAutoRadio() async {
    _autoRadioEnabled = !_autoRadioEnabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefAutoRadio, _autoRadioEnabled);

    if (_autoRadioEnabled &&
        currentSong != null &&
        _queue.length - _currentIndex <= 2) {
      unawaited(_appendAlgorithmRecommendations(currentSong!));
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Repeat & Audio Quality & Gaming Mix Controls
  // ---------------------------------------------------------------------------
  Future<void> cycleRepeatMode() async {
    _repeatMode = (_repeatMode + 1) % 3;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefRepeat, _repeatMode);
  }

  Future<void> setQualityTier(String tier) async {
    if (tier != 'low' && tier != 'standard' && tier != 'high') return;
    if (_qualityTier == tier) return;
    _qualityTier = tier;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefQuality, tier);

    // Hot-reload active stream at the exact current second if currently playing
    if (currentSong != null && !_needsInitialLoadForResume) {
      final pos = _player.position;
      final wasPlaying = _player.playing;
      await _loadAndPlayAt(_currentIndex, startPosition: pos);
      if (!wasPlaying) await _player.pause();
    }
  }

  Future<void> toggleGamingMixMode() async {
    _gamingMixMode = !_gamingMixMode;
    _handler?.gamingMixMode = _gamingMixMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefGamingMix, _gamingMixMode);
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length || index == _currentIndex) return;
    _queue.removeAt(index);
    if (index < _currentIndex) _currentIndex--;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 4. Local Playlists Management
  // ---------------------------------------------------------------------------
  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPrefPlaylists,
      jsonEncode(_playlists.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final pl = LitePlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed,
      songs: const [],
    );
    _playlists.insert(0, pl);
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    await _savePlaylists();
  }

  Future<bool> addSongToPlaylist(String playlistId, LiteSong song) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return false;
    final pl = _playlists[idx];
    if (pl.songs.any((s) => s.videoId == song.videoId)) return false;
    _playlists[idx] = pl.copyWith(songs: [...pl.songs, song]);
    notifyListeners();
    await _savePlaylists();
    return true;
  }

  Future<void> removeSongFromPlaylist(String playlistId, String videoId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    final pl = _playlists[idx];
    _playlists[idx] = pl.copyWith(
      songs: pl.songs.where((s) => s.videoId != videoId).toList(),
    );
    notifyListeners();
    await _savePlaylists();
  }

  // ---------------------------------------------------------------------------
  // 5. Search History
  // ---------------------------------------------------------------------------
  Future<void> addSearchHistory(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _searchHistory.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    _searchHistory.insert(0, q);
    if (_searchHistory.length > 8) {
      _searchHistory = _searchHistory.take(8).toList();
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kPrefHistory, _searchHistory);
  }

  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefHistory);
  }

  @override
  void dispose() {
    _posSaveTimer?.cancel();
    super.dispose();
  }
}
