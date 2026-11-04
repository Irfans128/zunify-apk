import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../models/user_profile_model.dart';
import '../services/download_service.dart';
import '../services/playlist_importer_service.dart';

class LibraryProvider extends ChangeNotifier {
  final DownloadService _downloadService;
  final PlaylistImporterService _importerService;

  LocalUserProfile _profile = const LocalUserProfile(
    username: 'Fannz',
    bioTagline: 'Creator & Audiophile • Zunify 🎧',
  );

  List<ZunifySong> _favorites = [];
  List<ZunifySong> _downloadedSongs = [];
  List<ZunifySong> _recentlyPlayed = [];
  List<ZunifyPlaylist> _playlists = [];

  final Map<String, double> _activeDownloadProgress = {};

  LibraryProvider(this._downloadService, this._importerService);

  LocalUserProfile get profile => _profile;
  List<ZunifySong> get favorites => List.unmodifiable(_favorites);
  List<ZunifySong> get downloadedSongs => List.unmodifiable(_downloadedSongs);
  List<ZunifySong> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);
  List<ZunifyPlaylist> get playlists => List.unmodifiable(_playlists);
  Map<String, double> get activeDownloadProgress => _activeDownloadProgress;

  Future<void> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();

    final rawProfile = prefs.getString('local_user_profile');
    if (rawProfile != null) {
      _profile = LocalUserProfile.fromJson(jsonDecode(rawProfile) as Map<String, dynamic>);
    }

    final rawFavs = prefs.getStringList('favorite_songs') ?? [];
    _favorites = rawFavs
        .map((s) => ZunifySong.fromMap(jsonDecode(s) as Map<String, dynamic>))
        .toList();

    final rawDown = prefs.getStringList('downloaded_songs') ?? [];
    _downloadedSongs = rawDown
        .map((s) => ZunifySong.fromMap(jsonDecode(s) as Map<String, dynamic>))
        .toList();

    final rawRecent = prefs.getStringList('recently_played') ?? [];
    _recentlyPlayed = rawRecent
        .map((s) => ZunifySong.fromMap(jsonDecode(s) as Map<String, dynamic>))
        .toList();

    final rawPlaylists = prefs.getStringList('user_playlists') ?? [];
    _playlists = rawPlaylists
        .map((p) => ZunifyPlaylist.fromJson(jsonDecode(p) as Map<String, dynamic>))
        .toList();

    notifyListeners();
  }

  Future<void> updateUserProfile({
    String? username,
    String? bioTagline,
    int? avatarPresetIndex,
    String? customAvatarFilePath,
  }) async {
    _profile = _profile.copyWith(
      username: username,
      bioTagline: bioTagline,
      avatarPresetIndex: avatarPresetIndex,
      customAvatarFilePath: customAvatarFilePath,
    );
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_user_profile', jsonEncode(_profile.toJson()));
  }

  bool isFavorite(String videoId) => _favorites.any((s) => s.videoId == videoId);

  bool isDownloaded(String videoId) => _downloadedSongs.any((s) => s.videoId == videoId);

  ZunifySong? getDownloadedSong(String videoId) {
    for (final s in _downloadedSongs) {
      if (s.videoId == videoId) return s;
    }
    return null;
  }

  Future<void> toggleFavorite(ZunifySong song) async {
    final idx = _favorites.indexWhere((s) => s.videoId == song.videoId);
    if (idx >= 0) {
      _favorites.removeAt(idx);
    } else {
      _favorites.insert(0, song);
    }
    notifyListeners();
    await _saveList('favorite_songs', _favorites.map((e) => e.toMap()).toList());
  }

  Future<void> addToRecentlyPlayed(ZunifySong song) async {
    _recentlyPlayed.removeWhere((s) => s.videoId == song.videoId);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > 25) {
      _recentlyPlayed = _recentlyPlayed.take(25).toList();
    }
    notifyListeners();
    await _saveList('recently_played', _recentlyPlayed.map((e) => e.toMap()).toList());
  }

  /// Downloads song into Private In-App Storage Vault
  Future<bool> downloadSong(ZunifySong song, {required bool highQuality}) async {
    if (isDownloaded(song.videoId) || _activeDownloadProgress.containsKey(song.videoId)) {
      return true;
    }

    _activeDownloadProgress[song.videoId] = 0.01;
    notifyListeners();

    final downloaded = await _downloadService.downloadSongToPrivateVault(
      song,
      highQuality: highQuality,
      onProgress: (p) {
        _activeDownloadProgress[song.videoId] = p;
        notifyListeners();
      },
    );

    _activeDownloadProgress.remove(song.videoId);

    if (downloaded != null) {
      _downloadedSongs.removeWhere((s) => s.videoId == song.videoId);
      _downloadedSongs.insert(0, downloaded);
      notifyListeners();
      await _saveList('downloaded_songs', _downloadedSongs.map((e) => e.toMap()).toList());
      return true;
    }

    notifyListeners();
    return false;
  }

  Future<void> removeDownloadedSong(String videoId) async {
    await _downloadService.deleteDownloadedSong(videoId);
    _downloadedSongs.removeWhere((s) => s.videoId == videoId);
    notifyListeners();
    await _saveList('downloaded_songs', _downloadedSongs.map((e) => e.toMap()).toList());
  }

  /// Create a new local playlist
  Future<void> createLocalPlaylist(String name, String description) async {
    final newPlaylist = ZunifyPlaylist(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      description: description.trim().isEmpty ? 'Playlist Lokal Zunify' : description.trim(),
      origin: PlaylistOrigin.local,
      songs: const [],
      createdAt: DateTime.now(),
    );
    _playlists.insert(0, newPlaylist);
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, ZunifySong song) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;

    final existing = _playlists[idx];
    if (existing.songs.any((s) => s.videoId == song.videoId)) return;

    final updatedSongs = [...existing.songs, song];
    _playlists[idx] = existing.copyWith(
      songs: updatedSongs,
      coverUrl: existing.coverUrl ?? song.highResArtUrl,
    );
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    await _savePlaylists();
  }

  /// Import playlist from Spotify or YouTube Music URL
  Future<ZunifyPlaylist?> importExternalPlaylist(
    String url, {
    ImportProgressCallback? onProgress,
  }) async {
    final imported = await _importerService.importFromUrl(url, onProgress: onProgress);
    if (imported != null) {
      _playlists.insert(0, imported);
      notifyListeners();
      await _savePlaylists();
    }
    return imported;
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, items.map(jsonEncode).toList());
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'user_playlists',
      _playlists.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}
