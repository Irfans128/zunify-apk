import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lite_song.dart';
import '../services/lite_audio_handler.dart';
import '../services/lite_download_service.dart';
import '../services/lite_ytm_service.dart';

/// Ultra-lean State Controller for ZunifyG.
/// Features:
/// 1. Song Search & Playback + Notification Skip/Pause/Play Controls
/// 2. Spotify-style Radio Algorithm (RDAMVM + RD + Taste History + Skip Penalty + Artist Diversity)
/// 3. Local Playlists
/// 4. Private In-App Offline Song Downloader
/// 5. Repeat Mode (Off / All / One)
/// 6. 3-Tier Audio Quality (Low / Standard / High)
class ZunifyGController extends ChangeNotifier {
  static const _kPrefQuality = 'zg_quality_tier';
  static const _kPrefRepeat = 'zg_repeat_mode';
  static const _kPrefAutoRadio = 'zg_auto_radio';
  static const _kPrefPlaylists = 'zg_playlists_v1';
  static const _kPrefDownloads = 'zg_downloads_v1';
  static const _kPrefHistory = 'zg_search_history_v1';
  static const _kPrefLastSong = 'zg_last_song_v1';
  static const _kPrefLastPosMs = 'zg_last_pos_ms';

  static const MethodChannel _sysChannel =
      MethodChannel('com.fannz.zunifyg/system');

  final LiteAudioHandler? _handler;
  late final AudioPlayer _player;
  final LiteYtmService ytm;
  final LiteDownloadService _downloader;

  List<LiteSong> _queue = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  bool _isFetchingRadio = false;
  int _playToken = 0;

  // Spotify-style taste signals
  final List<String> _recentHistoryIds = [];
  final Map<String, int> _artistSkipPenalty = {};
  final Random _rng = Random();

  // Settings
  String _qualityTier = 'low';
  int _repeatMode = 0; // 0 = Off, 1 = Repeat All, 2 = Repeat One
  bool _autoRadioEnabled = true;
  int _activeBitrateKbps = 64;

  // Playlists, Downloads & Search History
  List<LitePlaylist> _playlists = [];
  List<LiteSong> _downloadedSongs = [];
  final Map<String, double> _downloadProgress = {};
  List<String> _searchHistory = [];

  // Resume state
  Duration _savedResumePos = Duration.zero;
  bool _needsInitialLoadForResume = false;
  Timer? _posSaveTimer;

  ZunifyGController({
    LiteAudioHandler? handler,
    required this.ytm,
    required LiteDownloadService downloader,
  })  : _handler = handler,
        _downloader = downloader {
    _player = _handler?.player ?? AudioPlayer();
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
  int get activeBitrateKbps => _activeBitrateKbps;
  List<LitePlaylist> get playlists => List.unmodifiable(_playlists);
  List<LiteSong> get downloadedSongs => List.unmodifiable(_downloadedSongs);
  List<String> get searchHistory => List.unmodifiable(_searchHistory);

  bool isDownloaded(String videoId) =>
      _downloadedSongs.any((s) => s.videoId == videoId);

  double? downloadProgressFor(String videoId) => _downloadProgress[videoId];

  LiteSong? _findDownloaded(String videoId) {
    for (final s in _downloadedSongs) {
      if (s.videoId == videoId) return s;
    }
    return null;
  }

  Duration get position =>
      _needsInitialLoadForResume ? _savedResumePos : _player.position;
  Duration get duration =>
      _player.duration ??
      Duration(seconds: currentSong?.durationSeconds ?? 180);

  String get qualityShortLabel {
    switch (_qualityTier) {
      case 'low':
        return '64k';
      case 'standard':
        return '128k';
      default:
        return '160k';
    }
  }

  String get qualityLabelFull {
    switch (_qualityTier) {
      case 'low':
        return 'Hemat (64k)';
      case 'standard':
        return 'Normal (128k)';
      default:
        return 'Tinggi (160k)';
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

    _posSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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

    // Load Downloaded Songs & verify files exist
    final rawDl = prefs.getString(_kPrefDownloads);
    if (rawDl != null && rawDl.isNotEmpty) {
      try {
        final list = jsonDecode(rawDl) as List<dynamic>;
        final verified = <LiteSong>[];
        for (final item in list.whereType<Map>()) {
          final song = LiteSong.fromJson(Map<String, dynamic>.from(item));
          if (song.localPath != null && await File(song.localPath!).exists()) {
            verified.add(song.copyWith(isDownloaded: true));
          }
        }
        _downloadedSongs = verified;
      } catch (_) {}
    }

    _searchHistory = prefs.getStringList(_kPrefHistory) ?? [];

    // Restore last played song
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

  Future<void> requestNotificationPermissionIfNeeded() async {
    try {
      await _sysChannel.invokeMethod('requestNotifPermission');
    } catch (_) {}
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

  void _recordTasteHistory(LiteSong song) {
    _recentHistoryIds.remove(song.videoId);
    _recentHistoryIds.add(song.videoId);
    if (_recentHistoryIds.length > 40) {
      _recentHistoryIds.removeAt(0);
    }
  }

  // ---------------------------------------------------------------------------
  // 1. Playback Controls (Offline-first + Fast Stream)
  // ---------------------------------------------------------------------------
  Future<void> playSong(
    LiteSong song, {
    List<LiteSong>? queueList,
    bool triggerAlgorithm = true,
  }) async {
    _needsInitialLoadForResume = false;
    _savedResumePos = Duration.zero;
    unawaited(requestNotificationPermissionIfNeeded());

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
      unawaited(_appendSpotifyRadioRecommendations(song));
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
      unawaited(_appendSpotifyRadioRecommendations(cur));
    }
  }

  Future<void> _loadAndPlayAt(int index, {Duration? startPosition}) async {
    if (index < 0 || index >= _queue.length) return;
    final rawSong = _queue[index];
    final dlMatch = _findDownloaded(rawSong.videoId);
    final song = dlMatch ?? rawSong;
    final token = ++_playToken;

    _isLoading = true;
    notifyListeners();
    _recordTasteHistory(song);

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
      // Offline playback first (0 KB internet!)
      if (song.localPath != null && await File(song.localPath!).exists()) {
        if (token != _playToken) return;
        await _player.setAudioSource(
          AudioSource.file(song.localPath!),
          initialPosition: startPosition,
        );
        if (token != _playToken) return;
        _isLoading = false;
        notifyListeners();
        unawaited(_player.play());
        unawaited(_persistLastPlayback());
        return;
      }

      // Online stream resolution
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

      if (_currentIndex + 1 < _queue.length) {
        final nextSong = _queue[_currentIndex + 1];
        if (!isDownloaded(nextSong.videoId)) {
          unawaited(ytm.prefetch(nextSong.videoId, qualityTier: _qualityTier));
        }
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
        unawaited(_appendSpotifyRadioRecommendations(currentSong!));
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

  Future<void> playNext({bool userInitiated = true}) async {
    if (_queue.isEmpty) return;

    // Spotify-style skip penalty: skipping within first 25s lowers artist weight
    if (userInitiated && currentSong != null && _player.position.inSeconds < 25) {
      final artKey = currentSong!.artist.toLowerCase();
      _artistSkipPenalty[artKey] = (_artistSkipPenalty[artKey] ?? 0) + 1;
    }

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
        unawaited(_appendSpotifyRadioRecommendations(cur));
      }
    } else if (_repeatMode == 1) {
      _currentIndex = 0;
      await _loadAndPlayAt(0);
    } else if (_autoRadioEnabled && currentSong != null) {
      await _appendSpotifyRadioRecommendations(currentSong!);
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
    unawaited(playNext(userInitiated: false));
  }

  // ---------------------------------------------------------------------------
  // 2. Spotify-Style Radio Algorithm (Taste-Aware Scoring + Artist Diversity)
  // ---------------------------------------------------------------------------
  Future<void> _appendSpotifyRadioRecommendations(LiteSong seed) async {
    if (_isFetchingRadio) return;
    _isFetchingRadio = true;
    notifyListeners();
    try {
      final exclude = <String>{
        ..._queue.map((e) => e.videoId),
        ..._recentHistoryIds,
      };
      final rawRecs = await ytm.getRadioRecommendations(
        seed,
        excludeIds: exclude,
        tunerMode: 'AUTOMIX_SETTING_NORMAL',
      );
      if (rawRecs.isEmpty) return;

      // Score and sort candidates like Spotify Radio:
      // Prefer fresh artists (avoid back-to-back same artist) and penalize skipped artists
      final scored = List<LiteSong>.from(rawRecs);
      scored.sort((a, b) {
        final penA = _artistSkipPenalty[a.artist.toLowerCase()] ?? 0;
        final penB = _artistSkipPenalty[b.artist.toLowerCase()] ?? 0;
        if (penA != penB) return penA.compareTo(penB);
        return _rng.nextInt(3) - 1; // Slight organic jitter among equal scores
      });

      // Interleave so identical artists don't cluster consecutively
      final ordered = <LiteSong>[];
      final deferred = <LiteSong>[];
      String lastArtist = currentSong?.artist.toLowerCase() ?? '';
      for (final item in scored) {
        final art = item.artist.toLowerCase();
        if (art == lastArtist) {
          deferred.add(item);
        } else {
          ordered.add(item);
          lastArtist = art;
        }
      }
      ordered.addAll(deferred);

      _queue.addAll(ordered.take(24));
      if (_queue.length > 48 && _currentIndex > 12) {
        final drop = _currentIndex - 8;
        _queue.removeRange(0, drop);
        _currentIndex -= drop;
      }

      if (_currentIndex + 1 < _queue.length) {
        final next = _queue[_currentIndex + 1];
        if (!isDownloaded(next.videoId)) {
          unawaited(ytm.prefetch(next.videoId, qualityTier: _qualityTier));
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
      unawaited(_appendSpotifyRadioRecommendations(currentSong!));
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Repeat & Quality Controls
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

    if (currentSong != null &&
        !_needsInitialLoadForResume &&
        !isDownloaded(currentSong!.videoId)) {
      final pos = _player.position;
      final wasPlaying = _player.playing;
      await _loadAndPlayAt(_currentIndex, startPosition: pos);
      if (!wasPlaying) await _player.pause();
    }
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length || index == _currentIndex) return;
    _queue.removeAt(index);
    if (index < _currentIndex) _currentIndex--;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 4. Private Offline Song Downloader
  // ---------------------------------------------------------------------------
  Future<void> _saveDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPrefDownloads,
      jsonEncode(_downloadedSongs.map((e) => e.toJson()).toList()),
    );
  }

  Future<bool> downloadSong(LiteSong song) async {
    if (isDownloaded(song.videoId) || _downloadProgress.containsKey(song.videoId)) {
      return true;
    }
    _downloadProgress[song.videoId] = 0.01;
    notifyListeners();

    final saved = await _downloader.downloadSong(
      song,
      qualityTier: _qualityTier,
      onProgress: (p) {
        _downloadProgress[song.videoId] = p;
        notifyListeners();
      },
    );

    _downloadProgress.remove(song.videoId);
    if (saved != null) {
      _downloadedSongs.removeWhere((s) => s.videoId == saved.videoId);
      _downloadedSongs.insert(0, saved);
      notifyListeners();
      await _saveDownloads();
      return true;
    }
    notifyListeners();
    return false;
  }

  Future<void> deleteDownload(String videoId) async {
    _downloadedSongs.removeWhere((s) => s.videoId == videoId);
    notifyListeners();
    await _downloader.deleteSong(videoId);
    await _saveDownloads();
  }

  // ---------------------------------------------------------------------------
  // 5. Local Playlists
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
  // 6. Search History
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
