import 'dart:async';
import 'package:flutter/material.dart';
import '../app_version.dart';
import '../models/lite_song.dart';
import '../state/zunifyg_controller.dart';

// Ultra-flat Gaming Dark Palette (Zero GPU blur, OLED friendly)
const Color _kBg = Color(0xFF0B0C10);
const Color _kSurface = Color(0xFF14161D);
const Color _kSurfaceAlt = Color(0xFF1C1F29);
const Color _kBorder = Color(0xFF252A37);
const Color _kAccent = Color(0xFF00E676);
const Color _kText = Color(0xFFF3F4F6);
const Color _kTextSub = Color(0xFF9CA3AF);

class HomeShell extends StatefulWidget {
  final ZunifyGController controller;

  const HomeShell({super.key, required this.controller});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;

  // Home tab state
  static const _categories = [
    'Gaming',
    'Pop Indo',
    'Pop Barat',
    'Galau',
    'Chill',
    'Anime',
  ];
  String _selectedCategory = 'Gaming';
  List<LiteSong> _homeSongs = [];
  bool _loadingHome = true;

  // Search tab state
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _suggestDebounce;
  List<String> _suggestions = [];
  List<LiteSong> _searchResults = [];
  bool _searching = false;

  ZunifyGController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadCategory(_selectedCategory);
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategory(String cat) async {
    setState(() {
      _selectedCategory = cat;
      _loadingHome = true;
    });
    final list = await _c.ytm.getCategorySongs(cat);
    if (!mounted) return;
    setState(() {
      _homeSongs = list;
      _loadingHome = false;
    });
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
    _suggestDebounce = Timer(const Duration(milliseconds: 280), () async {
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

  void _openQualityModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
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
                  'Kualitas & Mode Gaming',
                  style: TextStyle(
                    color: _kText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _qualityOption(
                  ctx,
                  tier: 'low',
                  title: 'Hemat / Ping Aman (~64 kbps)',
                  subtitle: 'Paling ringan & irit kuota saat push rank',
                ),
                const SizedBox(height: 8),
                _qualityOption(
                  ctx,
                  tier: 'standard',
                  title: 'Normal (~128 kbps)',
                  subtitle: 'Seimbang antara jernih & stabilitas ping',
                ),
                const SizedBox(height: 8),
                _qualityOption(
                  ctx,
                  tier: 'high',
                  title: 'Tinggi (~160 kbps)',
                  subtitle: 'Suara paling jernih (butuh koneksi stabil)',
                ),
                const Divider(color: _kBorder, height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: _kAccent,
                  title: const Text(
                    'Mode Mix Game',
                    style: TextStyle(
                      color: _kText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Musik tidak auto-pause saat suara game muncul',
                    style: TextStyle(color: _kTextSub, fontSize: 12),
                  ),
                  value: _c.gamingMixMode,
                  onChanged: (_) => _c.toggleGamingMixMode(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: _kAccent,
                  title: const Text(
                    'Algoritma Auto-Radio',
                    style: TextStyle(
                      color: _kText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Otomatis lanjut ke lagu se-vibe tanpa keluar game',
                    style: TextStyle(color: _kTextSub, fontSize: 12),
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

  Widget _qualityOption(
    BuildContext ctx, {
    required String tier,
    required String title,
    required String subtitle,
  }) {
    final selected = _c.qualityTier == tier;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        _c.setQualityTier(tier);
        Navigator.pop(ctx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kAccent.withOpacity(0.14) : _kSurfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kAccent : _kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? _kAccent : _kTextSub,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? _kAccent : _kText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _kTextSub, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddToPlaylistModal(LiteSong song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
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
                        'Tambah ke Playlist',
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
                        _showCreatePlaylistDialog(songToAutoAdd: song);
                      },
                      icon: const Icon(Icons.add, color: _kAccent, size: 18),
                      label: const Text(
                        'Baru',
                        style: TextStyle(color: _kAccent, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_c.playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Belum ada playlist. Klik "+ Baru" untuk membuat.',
                      style: TextStyle(color: _kTextSub, fontSize: 13),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _c.playlists.length,
                      itemBuilder: (_, i) {
                        final pl = _c.playlists[i];
                        final exists = pl.songs.any((s) => s.videoId == song.videoId);
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: const Icon(Icons.queue_music, color: _kAccent),
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
                            final added = await _c.addSongToPlaylist(pl.id, song);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: _kSurfaceAlt,
                                  content: Text(
                                    added
                                        ? 'Ditambahkan ke "${pl.name}"'
                                        : 'Lagu sudah ada di "${pl.name}"',
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

  void _showCreatePlaylistDialog({LiteSong? songToAutoAdd}) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        title: const Text(
          'Buat Playlist Baru',
          style: TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: _kText),
          decoration: InputDecoration(
            hintText: 'Contoh: Push Rank MLBB',
            hintStyle: const TextStyle(color: _kTextSub),
            filled: true,
            fillColor: _kSurfaceAlt,
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await _c.createPlaylist(name);
              if (songToAutoAdd != null && _c.playlists.isNotEmpty) {
                await _c.addSongToPlaylist(_c.playlists.first.id, songToAutoAdd);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
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
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
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
                          icon: const Icon(Icons.play_arrow, size: 18),
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
                            'Belum ada lagu di playlist ini.\nCari lagu lalu tap ikon "+" untuk menambahkan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _kTextSub, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: pl.songs.length,
                          itemBuilder: (_, i) {
                            final song = pl.songs[i];
                            return _songTile(
                              song,
                              onTap: () => _c.playSong(song, queueList: pl.songs),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
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

  void _openFullPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CompactPlayerSheet(
        controller: _c,
        onAddToPlaylist: _openAddToPlaylistModal,
      ),
    );
  }

  Widget _songTile(
    LiteSong song, {
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isActive = _c.currentSong?.videoId == song.videoId;
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
                color: _kSurfaceAlt,
                child: song.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        song.thumbnailUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        cacheWidth: 96,
                        cacheHeight: 96,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.music_note,
                          color: _kTextSub,
                          size: 20,
                        ),
                      )
                    : const Icon(Icons.music_note, color: _kTextSub, size: 20),
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
                  Text(
                    '${song.artist} • ${song.formattedDuration}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kTextSub, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            trailing ??
                IconButton(
                  icon: const Icon(Icons.playlist_add, color: _kTextSub, size: 21),
                  tooltip: 'Tambah ke Playlist',
                  onPressed: () => _openAddToPlaylistModal(song),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final sel = cat == _selectedCategory;
              return GestureDetector(
                onTap: () => _loadCategory(cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? _kAccent : _kSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: sel ? _kAccent : _kBorder),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: sel ? Colors.black : _kText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _loadingHome
              ? const Center(
                  child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2.5),
                )
              : _homeSongs.isEmpty
                  ? Center(
                      child: TextButton.icon(
                        onPressed: () => _loadCategory(_selectedCategory),
                        icon: const Icon(Icons.refresh, color: _kAccent),
                        label: const Text(
                          'Muat ulang daftar lagu',
                          style: TextStyle(color: _kText),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _homeSongs.length,
                      itemBuilder: (_, i) {
                        final s = _homeSongs[i];
                        return _songTile(
                          s,
                          onTap: () => _c.playSong(s, queueList: _homeSongs),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: _kText, fontSize: 14),
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: _runSearch,
            decoration: InputDecoration(
              hintText: 'Cari lagu atau artis...',
              hintStyle: const TextStyle(color: _kTextSub),
              prefixIcon: const Icon(Icons.search, color: _kTextSub, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: _kTextSub, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _kSurface,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
                            Icons.search,
                            color: _kTextSub,
                            size: 18,
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
                            return _songTile(
                              s,
                              onTap: () => _c.playSong(s),
                            );
                          },
                        )
                      : _c.searchHistory.isNotEmpty
                          ? ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Riwayat Pencarian',
                                      style: TextStyle(
                                        color: _kTextSub,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _c.clearSearchHistory,
                                      child: const Text(
                                        'Hapus',
                                        style: TextStyle(
                                          color: _kAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                ..._c.searchHistory.map(
                                  (h) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.history,
                                      color: _kTextSub,
                                      size: 18,
                                    ),
                                    title: Text(
                                      h,
                                      style: const TextStyle(
                                        color: _kText,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    onTap: () => _runSearch(h),
                                  ),
                                ),
                              ],
                            )
                          : const Center(
                              child: Text(
                                'Ketik judul lagu untuk mulai memutar',
                                style: TextStyle(color: _kTextSub, fontSize: 13),
                              ),
                            ),
        ),
      ],
    );
  }

  Widget _buildPlaylistTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kAccent,
                side: const BorderSide(color: _kAccent),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(Icons.add, size: 19),
              label: const Text(
                'Buat Playlist Baru',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        Expanded(
          child: _c.playlists.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada playlist lokal.\nBuat playlist favoritmu buat nemenin push rank!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _kTextSub, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  itemCount: _c.playlists.length,
                  itemBuilder: (_, i) {
                    final pl = _c.playlists[i];
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _kSurfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kBorder),
                        ),
                        child: const Icon(Icons.queue_music, color: _kAccent),
                      ),
                      title: Text(
                        pl.name,
                        style: const TextStyle(
                          color: _kText,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${pl.songs.length} lagu',
                        style: const TextStyle(color: _kTextSub, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (pl.songs.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.play_circle_fill,
                                color: _kAccent,
                                size: 28,
                              ),
                              onPressed: () =>
                                  _c.playSong(pl.songs.first, queueList: pl.songs),
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: _kTextSub,
                              size: 20,
                            ),
                            onPressed: () => _c.deletePlaylist(pl.id),
                          ),
                        ],
                      ),
                      onTap: () => _openPlaylistDetail(pl.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMiniPlayer() {
    final song = _c.currentSong;
    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _openFullPlayer,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 40,
                height: 40,
                color: _kSurfaceAlt,
                child: song.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        song.thumbnailUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        cacheWidth: 96,
                        cacheHeight: 96,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.music_note,
                          color: _kAccent,
                          size: 18,
                        ),
                      )
                    : const Icon(Icons.music_note, color: _kAccent, size: 18),
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
                    '${song.artist} • ${_c.activeBitrateKbps}k',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kTextSub, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (_c.isLoading)
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
                  _c.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _kAccent,
                  size: 28,
                ),
                onPressed: _c.togglePlayPause,
              ),
            IconButton(
              icon: const Icon(
                Icons.skip_next_rounded,
                color: _kText,
                size: 24,
              ),
              onPressed: _c.playNext,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (_, __) => Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 14,
          title: Row(
            children: [
              const Text(
                kZunifyGAppName,
                style: TextStyle(
                  color: _kText,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LITE',
                  style: TextStyle(
                    color: _kAccent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            GestureDetector(
              onTap: _openQualityModal,
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune_rounded, color: _kAccent, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      _c.qualityShortLabel,
                      style: const TextStyle(
                        color: _kText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
                  _buildHomeTab(),
                  _buildSearchTab(),
                  _buildPlaylistTab(),
                ],
              ),
            ),
            _buildMiniPlayer(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 58,
          backgroundColor: _kSurface,
          indicatorColor: _kAccent.withOpacity(0.16),
          selectedIndex: _tabIndex,
          onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.music_note_outlined, color: _kTextSub),
              selectedIcon: Icon(Icons.music_note, color: _kAccent),
              label: 'Lagu',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined, color: _kTextSub),
              selectedIcon: Icon(Icons.search, color: _kAccent),
              label: 'Cari',
            ),
            NavigationDestination(
              icon: Icon(Icons.queue_music_outlined, color: _kTextSub),
              selectedIcon: Icon(Icons.queue_music, color: _kAccent),
              label: 'Playlist',
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPlayerSheet extends StatefulWidget {
  final ZunifyGController controller;
  final void Function(LiteSong song) onAddToPlaylist;

  const _CompactPlayerSheet({
    required this.controller,
    required this.onAddToPlaylist,
  });

  @override
  State<_CompactPlayerSheet> createState() => _CompactPlayerSheetState();
}

class _CompactPlayerSheetState extends State<_CompactPlayerSheet> {
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

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 68,
                        height: 68,
                        color: _kSurfaceAlt,
                        child: song.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                song.thumbnailUrl,
                                width: 68,
                                height: 68,
                                fit: BoxFit.cover,
                                cacheWidth: 160,
                                cacheHeight: 160,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.music_note,
                                  color: _kAccent,
                                  size: 28,
                                ),
                              )
                            : const Icon(
                                Icons.music_note,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _kTextSub,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${_c.activeBitrateKbps} kbps • ${_c.qualityDescription}',
                            style: const TextStyle(
                              color: _kAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.playlist_add,
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
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
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
                        size: 24,
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
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: _kAccent,
                        shape: BoxShape.circle,
                      ),
                      child: _c.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(16),
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
                                size: 32,
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
                      tooltip: 'Algoritma Auto-Radio',
                      icon: Icon(
                        Icons.auto_awesome_rounded,
                        color: _c.autoRadioEnabled ? _kAccent : _kTextSub,
                        size: 23,
                      ),
                      onPressed: _c.toggleAutoRadio,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Quick 3-Tier Quality Switcher
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
                // Queue / Algorithm Up-Next Toggle
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _showQueue = !_showQueue),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _kSurface,
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
                                ? 'Algoritma sedang menyiapkan lagu berikutnya...'
                                : 'Antrean & Algoritma (${_c.queue.length} lagu)',
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
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _c.queue.length,
                      itemBuilder: (_, i) {
                        final qSong = _c.queue[i];
                        final isCur = i == _c.currentIndex;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
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
                                  Icons.graphic_eq,
                                  color: _kAccent,
                                  size: 18,
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.close,
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
            color: sel ? _kAccent : _kSurface,
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
