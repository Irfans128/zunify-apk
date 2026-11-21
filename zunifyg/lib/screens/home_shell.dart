import 'dart:async';
import 'package:flutter/material.dart';
import '../app_version.dart';
import '../models/lite_song.dart';
import '../state/zunifyg_controller.dart';

// Crisp AMOLED Ultra-Light Palette (Zero GPU blur, zero shadow bloat)
const Color _kBg = Color(0xFF09090B);
const Color _kCard = Color(0xFF131318);
const Color _kCardAlt = Color(0xFF1C1C24);
const Color _kBorder = Color(0xFF23232D);
const Color _kAccent = Color(0xFF00E676);
const Color _kText = Color(0xFFF4F4F5);
const Color _kTextSub = Color(0xFF8E8E98);

class HomeShell extends StatefulWidget {
  final ZunifyGController controller;

  const HomeShell({super.key, required this.controller});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0; // 0 = Cari, 1 = Playlist

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _suggestDebounce;
  List<String> _suggestions = [];
  List<LiteSong> _searchResults = [];
  bool _searching = false;

  ZunifyGController get _c => widget.controller;

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _suggestDebounce?.cancel();
    final trimmed = val.trim();
    setState(() {
      if (trimmed.isEmpty) {
        _suggestions = [];
        _searchResults = [];
      }
    });
    if (trimmed.isEmpty) return;
    _suggestDebounce = Timer(const Duration(milliseconds: 260), () async {
      final list = await _c.ytm.getSuggestions(trimmed);
      if (!mounted) return;
      setState(() => _suggestions = list);
    });
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    _searchCtrl.text = q;
    setState(() {
      _searching = true;
      _suggestions = [];
    });
    unawaited(_c.addSearchHistory(q));
    final list = await _c.ytm.searchSongs(q, limit: 20);
    if (!mounted) return;
    setState(() {
      _searchResults = list;
      _searching = false;
    });
  }

  void _openQualitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => ListenableBuilder(
        listenable: _c,
        builder: (_, __) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kualitas & Algoritma',
                  style: TextStyle(
                    color: _kText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _qualityRow(
                  ctx,
                  tier: 'low',
                  title: 'Hemat • ~64 kbps',
                  subtitle: 'Paling ringan, ping game aman & file download kecil',
                ),
                const SizedBox(height: 8),
                _qualityRow(
                  ctx,
                  tier: 'standard',
                  title: 'Normal • ~128 kbps',
                  subtitle: 'Suara jernih seimbang & kuota irit',
                ),
                const SizedBox(height: 8),
                _qualityRow(
                  ctx,
                  tier: 'high',
                  title: 'Tinggi • ~160 kbps',
                  subtitle: 'Detail maksimal (disarankan saat pakai Wi-Fi)',
                ),
                const Divider(color: _kBorder, height: 22),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: _kAccent,
                  title: const Text(
                    'Algoritma Radio (Ala Spotify)',
                    style: TextStyle(
                      color: _kText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Otomatis sambung lagu se-vibe saat antrean habis',
                    style: TextStyle(color: _kTextSub, fontSize: 11.5),
                  ),
                  value: _c.autoRadioEnabled,
                  onChanged: (_) => _c.toggleAutoRadio(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _qualityRow(
    BuildContext ctx, {
    required String tier,
    required String title,
    required String subtitle,
  }) {
    final sel = _c.qualityTier == tier;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        _c.setQualityTier(tier);
        Navigator.pop(ctx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _kAccent.withOpacity(0.12) : _kCardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? _kAccent : _kBorder),
        ),
        child: Row(
          children: [
            Icon(
              sel ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: sel ? _kAccent : _kTextSub,
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: sel ? _kAccent : _kText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _kTextSub, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddToPlaylist(LiteSong song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => ListenableBuilder(
        listenable: _c,
        builder: (_, __) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Simpan ke Playlist',
                        style: TextStyle(
                          color: _kText,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showCreatePlaylistDialog(songToAdd: song);
                      },
                      icon: const Icon(Icons.add, color: _kAccent, size: 18),
                      label: const Text(
                        'Baru',
                        style: TextStyle(color: _kAccent, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (_c.playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Belum ada playlist. Tap "+ Baru" untuk membuat.',
                      style: TextStyle(color: _kTextSub, fontSize: 13),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _c.playlists.length,
                      itemBuilder: (_, i) {
                        final pl = _c.playlists[i];
                        final exists = pl.songs.any((s) => s.videoId == song.videoId);
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: const Icon(Icons.queue_music_rounded, color: _kAccent),
                          title: Text(
                            pl.name,
                            style: const TextStyle(
                              color: _kText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${pl.songs.length} lagu',
                            style: const TextStyle(color: _kTextSub, fontSize: 11.5),
                          ),
                          trailing: exists
                              ? const Icon(Icons.check, color: _kAccent, size: 18)
                              : null,
                          onTap: () async {
                            final ok = await _c.addSongToPlaylist(pl.id, song);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: _kCardAlt,
                                  content: Text(
                                    ok
                                        ? 'Ditambahkan ke "${pl.name}"'
                                        : 'Sudah ada di "${pl.name}"',
                                    style: const TextStyle(color: _kText),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog({LiteSong? songToAdd}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text(
          'Playlist Baru',
          style: TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: _kText),
          decoration: InputDecoration(
            hintText: 'Contoh: Push Rank',
            hintStyle: const TextStyle(color: _kTextSub),
            filled: true,
            fillColor: _kCardAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: _kTextSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await _c.createPlaylist(name);
              if (songToAdd != null && _c.playlists.isNotEmpty) {
                await _c.addSongToPlaylist(_c.playlists.first.id, songToAdd);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Buat', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _openOfflineSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        builder: (_, scrollCtrl) => ListenableBuilder(
          listenable: _c,
          builder: (_, __) {
            final songs = _c.downloadedSongs;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.offline_pin_rounded, color: _kAccent, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lagu Offline',
                              style: TextStyle(
                                color: _kText,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${songs.length} lagu siap putar tanpa kuota',
                              style: const TextStyle(color: _kTextSub, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      if (songs.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            _c.playSong(songs.first, queueList: songs);
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text(
                            'Putar',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(color: _kBorder, height: 1),
                Expanded(
                  child: songs.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada lagu tersimpan.\nTap ikon download di lagu mana saja.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _kTextSub, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: songs.length,
                          itemBuilder: (_, i) {
                            final s = songs[i];
                            return _SongRow(
                              song: s,
                              controller: _c,
                              onTap: () => _c.playSong(s, queueList: songs),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: _kTextSub,
                                  size: 20,
                                ),
                                onPressed: () => _c.deleteDownload(s.videoId),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openPlaylistDetail(String playlistId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        builder: (_, scrollCtrl) => ListenableBuilder(
          listenable: _c,
          builder: (_, __) {
            final idx = _c.playlists.indexWhere((p) => p.id == playlistId);
            if (idx < 0) {
              return const Center(
                child: Text('Playlist dihapus', style: TextStyle(color: _kTextSub)),
              );
            }
            final pl = _c.playlists[idx];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pl.name,
                              style: const TextStyle(
                                color: _kText,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${pl.songs.length} lagu',
                              style: const TextStyle(color: _kTextSub, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (pl.songs.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            _c.playSong(pl.songs.first, queueList: pl.songs);
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text(
                            'Putar',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(color: _kBorder, height: 1),
                Expanded(
                  child: pl.songs.isEmpty
                      ? const Center(
                          child: Text(
                            'Playlist masih kosong.\nCari lagu lalu tap ikon "+" untuk menambahkan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _kTextSub, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: pl.songs.length,
                          itemBuilder: (_, i) {
                            final song = pl.songs[i];
                            return _SongRow(
                              song: song,
                              controller: _c,
                              onTap: () => _c.playSong(song, queueList: pl.songs),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: _kTextSub,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _c.removeSongFromPlaylist(pl.id, song.videoId),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openPlayerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NowPlayingSheet(
        controller: _c,
        onAddToPlaylist: _openAddToPlaylist,
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: _kText, fontSize: 14),
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: _runSearch,
            decoration: InputDecoration(
              hintText: 'Cari lagu atau artis...',
              hintStyle: const TextStyle(color: _kTextSub, fontSize: 13.5),
              prefixIcon: const Icon(Icons.search_rounded, color: _kTextSub, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: _kTextSub, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _kCard,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kAccent),
              ),
            ),
          ),
        ),
        Expanded(
          child: _searching
              ? const Center(
                  child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2.5),
                )
              : _suggestions.isNotEmpty
                  ? ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (_, i) {
                        final sug = _suggestions[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.north_west_rounded,
                            color: _kTextSub,
                            size: 17,
                          ),
                          title: Text(
                            sug,
                            style: const TextStyle(color: _kText, fontSize: 13.5),
                          ),
                          onTap: () => _runSearch(sug),
                        );
                      },
                    )
                  : _searchResults.isNotEmpty
                      ? ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (_, i) {
                            final s = _searchResults[i];
                            return _SongRow(
                              song: s,
                              controller: _c,
                              onTap: () => _c.playSong(s),
                              onAddToPlaylist: () => _openAddToPlaylist(s),
                            );
                          },
                        )
                      : ListenableBuilder(
                          listenable: _c,
                          builder: (_, __) {
                            final history = _c.searchHistory;
                            return ListView(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                              children: [
                                if (history.isNotEmpty) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Pencarian Terakhir',
                                        style: TextStyle(
                                          color: _kTextSub,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _c.clearSearchHistory,
                                        child: const Text(
                                          'Bersihkan',
                                          style: TextStyle(
                                            color: _kAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: history
                                        .map(
                                          (h) => ActionChip(
                                            backgroundColor: _kCard,
                                            side: const BorderSide(color: _kBorder),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                            label: Text(
                                              h,
                                              style: const TextStyle(
                                                color: _kText,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            onPressed: () => _runSearch(h),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                  const SizedBox(height: 22),
                                ],
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _kCard,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _kBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: _kAccent.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.bolt_rounded,
                                          color: _kAccent,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Mode Gaming Ultra-Ringan',
                                              style: TextStyle(
                                                color: _kText,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Cari 1 lagu, algoritma radio otomatis mutar lanjutannya tanpa bikin game berat.',
                                              style: TextStyle(
                                                color: _kTextSub,
                                                fontSize: 11.5,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildPlaylistTab() {
    return ListenableBuilder(
      listenable: _c,
      builder: (_, __) => ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
        children: [
          // Offline Downloaded Vault Card
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _openOfflineSheet,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.offline_pin_rounded,
                      color: _kAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lagu Offline (Terdownload)',
                          style: TextStyle(
                            color: _kText,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_c.downloadedSongs.length} lagu • 0 kuota saat main game',
                          style: const TextStyle(color: _kTextSub, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _kTextSub),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Playlist Saya',
                  style: TextStyle(
                    color: _kText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showCreatePlaylistDialog,
                icon: const Icon(Icons.add_rounded, color: _kAccent, size: 19),
                label: const Text(
                  'Buat Baru',
                  style: TextStyle(
                    color: _kAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_c.playlists.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: const Text(
                'Belum ada playlist.\nTap "+ Buat Baru" untuk kumpulkan lagu favoritmu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kTextSub, fontSize: 12.5, height: 1.4),
              ),
            )
          else
            ..._c.playlists.map(
              (pl) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openPlaylistDetail(pl.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _kCardAlt,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.queue_music_rounded,
                            color: _kAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pl.name,
                                style: const TextStyle(
                                  color: _kText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${pl.songs.length} lagu',
                                style: const TextStyle(
                                  color: _kTextSub,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (pl.songs.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: _kAccent,
                              size: 28,
                            ),
                            onPressed: () =>
                                _c.playSong(pl.songs.first, queueList: pl.songs),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: _kTextSub,
                            size: 20,
                          ),
                          onPressed: () => _c.deletePlaylist(pl.id),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 50,
        titleSpacing: 14,
        title: Row(
          children: [
            const Text(
              kZunifyGAppName,
              style: TextStyle(
                color: _kText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'LITE',
                style: TextStyle(
                  color: _kAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: _c,
            builder: (_, __) => GestureDetector(
              onTap: _openQualitySheet,
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.graphic_eq_rounded, color: _kAccent, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      _c.qualityShortLabel,
                      style: const TextStyle(
                        color: _kText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildSearchTab(),
                _buildPlaylistTab(),
              ],
            ),
          ),
          _MiniPlayerBar(controller: _c, onOpenFull: _openPlayerSheet),
        ],
      ),
      bottomNavigationBar: Container(
        height: 54 + MediaQuery.of(context).padding.bottom,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F13),
          border: Border(top: BorderSide(color: _kBorder, width: 1)),
        ),
        child: Row(
          children: [
            _navItem(0, Icons.search_rounded, 'Cari'),
            _navItem(1, Icons.queue_music_rounded, 'Playlist'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int idx, IconData icon, String label) {
    final sel = _tabIndex == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = idx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: sel ? _kAccent : _kTextSub, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: sel ? _kAccent : _kTextSub,
                fontSize: 11,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  final LiteSong song;
  final ZunifyGController controller;
  final VoidCallback onTap;
  final VoidCallback? onAddToPlaylist;
  final Widget? trailing;

  const _SongRow({
    required this.song,
    required this.controller,
    required this.onTap,
    this.onAddToPlaylist,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: controller,
        builder: (_, __) {
          final isActive = controller.currentSong?.videoId == song.videoId;
          final isDl = controller.isDownloaded(song.videoId);
          final dlProg = controller.downloadProgressFor(song.videoId);

          return InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: _kCardAlt,
                      child: song.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              song.thumbnailUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              cacheWidth: 72,
                              cacheHeight: 72,
                              filterQuality: FilterQuality.none,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.music_note_rounded,
                                color: _kTextSub,
                                size: 20,
                              ),
                            )
                          : const Icon(
                              Icons.music_note_rounded,
                              color: _kTextSub,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isActive ? _kAccent : _kText,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (isDl) ...[
                              const Icon(
                                Icons.offline_pin_rounded,
                                color: _kAccent,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                '${song.artist} • ${song.formattedDuration}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _kTextSub,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else ...[
                    if (dlProg != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            value: dlProg > 0.05 ? dlProg : null,
                            color: _kAccent,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          isDl
                              ? Icons.download_done_rounded
                              : Icons.download_for_offline_outlined,
                          color: isDl ? _kAccent : _kTextSub,
                          size: 20,
                        ),
                        onPressed: () {
                          if (!isDl) controller.downloadSong(song);
                        },
                      ),
                    if (onAddToPlaylist != null)
                      IconButton(
                        icon: const Icon(
                          Icons.playlist_add_rounded,
                          color: _kTextSub,
                          size: 21,
                        ),
                        onPressed: onAddToPlaylist,
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  final ZunifyGController controller;
  final VoidCallback onOpenFull;

  const _MiniPlayerBar({
    required this.controller,
    required this.onOpenFull,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: controller,
        builder: (_, __) {
          final song = controller.currentSong;
          if (song == null) return const SizedBox.shrink();
          final offline = controller.isDownloaded(song.videoId);

          return GestureDetector(
            onTap: onOpenFull,
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<Duration>(
                    stream: controller.player.positionStream,
                    builder: (_, snap) {
                      final pos = snap.data ?? controller.position;
                      final total = controller.duration.inMilliseconds;
                      final frac = total > 0
                          ? (pos.inMilliseconds / total).clamp(0.0, 1.0)
                          : 0.0;
                      return LinearProgressIndicator(
                        value: frac,
                        minHeight: 2,
                        backgroundColor: _kBorder,
                        valueColor: const AlwaysStoppedAnimation(_kAccent),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Container(
                            width: 38,
                            height: 38,
                            color: _kCardAlt,
                            child: song.thumbnailUrl.isNotEmpty
                                ? Image.network(
                                    song.thumbnailUrl,
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                    cacheWidth: 72,
                                    cacheHeight: 72,
                                    filterQuality: FilterQuality.none,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.music_note_rounded,
                                      color: _kAccent,
                                      size: 18,
                                    ),
                                  )
                                : const Icon(
                                    Icons.music_note_rounded,
                                    color: _kAccent,
                                    size: 18,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _kText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                offline
                                    ? '${song.artist} • Offline'
                                    : '${song.artist} • ${controller.activeBitrateKbps}k',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _kTextSub,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (controller.isLoading)
                          const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: _kAccent,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: Icon(
                              controller.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: _kAccent,
                              size: 27,
                            ),
                            onPressed: controller.togglePlayPause,
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            color: _kText,
                            size: 24,
                          ),
                          onPressed: controller.playNext,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NowPlayingSheet extends StatefulWidget {
  final ZunifyGController controller;
  final void Function(LiteSong song) onAddToPlaylist;

  const _NowPlayingSheet({
    required this.controller,
    required this.onAddToPlaylist,
  });

  @override
  State<_NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<_NowPlayingSheet> {
  bool _showQueue = false;

  ZunifyGController get _c => widget.controller;

  String _fmt(Duration d) {
    final total = d.inSeconds.clamp(0, 86400);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (_, __) {
        final song = _c.currentSong;
        if (song == null) return const SizedBox.shrink();
        final isDl = _c.isDownloaded(song.videoId);
        final dlProg = _c.downloadProgressFor(song.videoId);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 64,
                        height: 64,
                        color: _kCardAlt,
                        child: song.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                song.thumbnailUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                cacheWidth: 144,
                                cacheHeight: 144,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.music_note_rounded,
                                  color: _kAccent,
                                  size: 28,
                                ),
                              )
                            : const Icon(
                                Icons.music_note_rounded,
                                color: _kAccent,
                                size: 28,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _kText,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _kTextSub, fontSize: 12.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isDl
                                ? 'Mode Offline • 0 Kuota'
                                : '${_c.activeBitrateKbps} kbps • ${_c.qualityLabelFull}',
                            style: const TextStyle(
                              color: _kAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dlProg != null)
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: _kAccent,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          isDl
                              ? Icons.download_done_rounded
                              : Icons.download_for_offline_outlined,
                          color: isDl ? _kAccent : _kText,
                          size: 24,
                        ),
                        onPressed: () {
                          if (!isDl) _c.downloadSong(song);
                        },
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.playlist_add_rounded,
                        color: _kText,
                        size: 24,
                      ),
                      onPressed: () => widget.onAddToPlaylist(song),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                StreamBuilder<Duration>(
                  stream: _c.player.positionStream,
                  builder: (_, snap) {
                    final pos = snap.data ?? _c.position;
                    final dur = _c.duration;
                    final maxMs = dur.inMilliseconds > 0
                        ? dur.inMilliseconds.toDouble()
                        : 1.0;
                    final curMs = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5.5,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 11,
                            ),
                            activeTrackColor: _kAccent,
                            inactiveTrackColor: _kBorder,
                            thumbColor: _kAccent,
                          ),
                          child: Slider(
                            value: curMs,
                            max: maxMs,
                            onChanged: (v) =>
                                _c.seek(Duration(milliseconds: v.round())),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _fmt(pos),
                                style: const TextStyle(
                                  color: _kTextSub,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                _fmt(dur),
                                style: const TextStyle(
                                  color: _kTextSub,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: _c.repeatLabel,
                      icon: Icon(
                        _c.repeatMode == 2
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: _c.repeatMode == 0 ? _kTextSub : _kAccent,
                        size: 23,
                      ),
                      onPressed: _c.cycleRepeatMode,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: _kText,
                        size: 32,
                      ),
                      onPressed: _c.playPrevious,
                    ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: _kAccent,
                        shape: BoxShape.circle,
                      ),
                      child: _c.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(15),
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                _c.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 30,
                              ),
                              onPressed: _c.togglePlayPause,
                            ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: _kText,
                        size: 32,
                      ),
                      onPressed: _c.playNext,
                    ),
                    IconButton(
                      tooltip: 'Algoritma Radio Spotify',
                      icon: Icon(
                        Icons.auto_awesome_rounded,
                        color: _c.autoRadioEnabled ? _kAccent : _kTextSub,
                        size: 22,
                      ),
                      onPressed: _c.toggleAutoRadio,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _tierBtn('low', 'Hemat 64k'),
                    const SizedBox(width: 8),
                    _tierBtn('standard', 'Normal 128k'),
                    const SizedBox(width: 8),
                    _tierBtn('high', 'Tinggi 160k'),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _showQueue = !_showQueue),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.queue_music_rounded,
                          color: _kAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _c.isFetchingRadio
                                ? 'Algoritma sedang menyiapkan antrean...'
                                : 'Antrean Radio (${_c.queue.length} lagu)',
                            style: const TextStyle(
                              color: _kText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          _showQueue
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: _kTextSub,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showQueue) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _c.queue.length,
                      itemBuilder: (_, i) {
                        final qSong = _c.queue[i];
                        final isCur = i == _c.currentIndex;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isCur ? _kAccent : _kTextSub,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          title: Text(
                            qSong.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCur ? _kAccent : _kText,
                              fontWeight:
                                  isCur ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                          subtitle: Text(
                            qSong.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _kTextSub,
                              fontSize: 11,
                            ),
                          ),
                          trailing: isCur
                              ? const Icon(
                                  Icons.graphic_eq_rounded,
                                  color: _kAccent,
                                  size: 18,
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: _kTextSub,
                                    size: 16,
                                  ),
                                  onPressed: () => _c.removeFromQueue(i),
                                ),
                          onTap: () => _c.playAtIndex(i),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tierBtn(String tier, String label) {
    final sel = _c.qualityTier == tier;
    return Expanded(
      child: GestureDetector(
        onTap: () => _c.setQualityTier(tier),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? _kAccent : _kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? _kAccent : _kBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: sel ? Colors.black : _kTextSub,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
