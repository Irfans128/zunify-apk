import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import '../widgets/song_tile_widget.dart';

/// Fitur #1: Halaman Profil Artis Lengkap (Lagu Terpopuler, Album & Single, Bio, Artis Serupa)
class ArtistProfileScreen extends StatefulWidget {
  final String artistName;
  final String? browseId;

  const ArtistProfileScreen({
    super.key,
    required this.artistName,
    this.browseId,
  });

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  ZunifyArtistProfile? _profile;
  bool _isLoading = true;
  bool _bioExpanded = false;
  bool _showAllTopSongs = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final ytm = context.read<PlayerProvider>().ytMusicService;
    final res = await ytm.fetchArtistProfile(
      widget.artistName,
      browseId: widget.browseId,
    );
    if (!mounted) return;
    setState(() {
      _profile = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;
    final profile = _profile;

    return Scaffold(
      backgroundColor: theme.scaffoldBgColor,
      body: _isLoading || profile == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: accent),
                  const SizedBox(height: 14),
                  Text(
                    'Memuat profil ${widget.artistName}...',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Immersive Artist Banner AppBar
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: theme.scaffoldBgColor,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    title: Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (profile.bannerUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: profile.bannerUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.white10,
                            ),
                          )
                        else
                          Container(color: accent.withOpacity(0.25)),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.25),
                                Colors.transparent,
                                theme.scaffoldBgColor.withOpacity(0.85),
                                theme.scaffoldBgColor,
                              ],
                              stops: const [0.0, 0.35, 0.82, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Action Buttons: Putar Semua Populer & Radio Artis
                        if (profile.topSongs.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 22,
                                  ),
                                  label: const Text(
                                    'Putar Populer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  onPressed: () {
                                    player.playSong(
                                      profile.topSongs.first,
                                      customQueue: profile.topSongs,
                                      contextName: profile.name,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.18),
                                    ),
                                    backgroundColor:
                                        Colors.white.withOpacity(0.06),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.sensors_rounded,
                                    color: accent,
                                    size: 19,
                                  ),
                                  label: const Text(
                                    'Radio Artis',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  onPressed: () {
                                    player.playSong(
                                      profile.topSongs.first,
                                      customQueue: const [],
                                      contextName: 'Radio ${profile.name}',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 22),

                        // Lagu Terpopuler
                        if (profile.topSongs.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Lagu Terpopuler',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (profile.topSongs.length > 5)
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _showAllTopSongs = !_showAllTopSongs,
                                  ),
                                  child: Text(
                                    _showAllTopSongs
                                        ? 'Tampilkan Sedikit'
                                        : 'Lihat Semua (${profile.topSongs.length})',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...profile.topSongs
                              .take(_showAllTopSongs ? 15 : 5)
                              .toList()
                              .asMap()
                              .entries
                              .map(
                                (entry) => ZunifySongTile(
                                  song: entry.value,
                                  queueContext: profile.topSongs,
                                  contextName: profile.name,
                                  rank: entry.key + 1,
                                ),
                              ),
                          const SizedBox(height: 24),
                        ],

                        // Album & Single Carousel
                        if (profile.albums.isNotEmpty) ...[
                          const Text(
                            'Album & Single',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 196,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: profile.albums.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, idx) {
                                final alb = profile.albums[idx];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AlbumDetailScreen(album: alb),
                                      ),
                                    );
                                  },
                                  child: SizedBox(
                                    width: 138,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: CachedNetworkImage(
                                            imageUrl: alb.coverUrl,
                                            width: 138,
                                            height: 138,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                              width: 138,
                                              height: 138,
                                              color: Colors.white10,
                                              child: Icon(
                                                Icons.album_rounded,
                                                color: accent,
                                                size: 36,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          alb.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          alb.yearOrSubtitle.isNotEmpty
                                              ? alb.yearOrSubtitle
                                              : 'Album',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.55),
                                            fontSize: 11.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Artis Serupa (Mirip)
                        if (profile.similarArtists.isNotEmpty) ...[
                          const Text(
                            'Penggemar Juga Menyukai',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 146,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: profile.similarArtists.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, idx) {
                                final sim = profile.similarArtists[idx];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ArtistProfileScreen(
                                          artistName: sim.name,
                                          browseId: sim.browseId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: SizedBox(
                                    width: 102,
                                    child: Column(
                                      children: [
                                        ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: sim.avatarUrl,
                                            width: 92,
                                            height: 92,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                              width: 92,
                                              height: 92,
                                              color: Colors.white10,
                                              child: Icon(
                                                Icons.person_rounded,
                                                color: accent,
                                                size: 34,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          sim.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Tentang Artis (Bio)
                        if (profile.description.trim().isNotEmpty) ...[
                          const Text(
                            'Tentang Artis',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _bioExpanded = !_bioExpanded),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.description.trim(),
                                    maxLines: _bioExpanded ? 40 : 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.80),
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _bioExpanded
                                        ? 'Tutup'
                                        : 'Baca selengkapnya...',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Halaman Detail Album / Single (`MPREb_...`)
class AlbumDetailScreen extends StatefulWidget {
  final ZunifyAlbumSummary album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  ZunifyAlbumDetail? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  Future<void> _loadAlbum() async {
    final ytm = context.read<PlayerProvider>().ytMusicService;
    final res = await ytm.fetchAlbumDetail(widget.album);
    if (!mounted) return;
    setState(() {
      _detail = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;
    final tracks = _detail?.tracks ?? const [];

    return Scaffold(
      backgroundColor: theme.scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 19,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.album.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: widget.album.coverUrl,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 200,
                        height: 200,
                        color: Colors.white10,
                        child: Icon(
                          Icons.album_rounded,
                          color: accent,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.album.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArtistProfileScreen(
                          artistName: widget.album.artist,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    '${widget.album.artist} • ${widget.album.yearOrSubtitle.isNotEmpty ? widget.album.yearOrSubtitle : "${tracks.length} lagu"}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (tracks.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: const Text(
                            'Putar Album',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          onPressed: () {
                            player.playSong(
                              tracks.first,
                              customQueue: tracks,
                              contextName: widget.album.title,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.18),
                            ),
                            backgroundColor: Colors.white.withOpacity(0.06),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.shuffle_rounded, size: 18),
                          label: const Text(
                            'Acak',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          onPressed: () {
                            final shuffled = List.of(tracks)..shuffle();
                            player.playSong(
                              shuffled.first,
                              customQueue: shuffled,
                              contextName: widget.album.title,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                ...tracks.asMap().entries.map(
                      (entry) => ZunifySongTile(
                        song: entry.value,
                        queueContext: tracks,
                        contextName: widget.album.title,
                        rank: entry.key + 1,
                      ),
                    ),
              ],
            ),
    );
  }
}
